//
//  WebRTCFeature.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/20.
//

import ComposableArchitecture
import Foundation
import OSLog
@preconcurrency import WebRTC

// MARK: - WebRTC Feature

@Reducer
public struct WebRTCFeature {

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    public var connectedPeers: IdentifiedArrayOf<PeerState> = []
    public var localConnectionState: ConnectionState = .disconnected
    public var error: WebRTCError?
    public var isListening = false

    public init(
      connectedPeers: IdentifiedArrayOf<PeerState> = [],
      localConnectionState: ConnectionState = .disconnected,
      error: WebRTCError? = nil,
      isListening: Bool = false
    ) {
      self.connectedPeers = connectedPeers
      self.localConnectionState = localConnectionState
      self.error = error
      self.isListening = isListening
    }
  }

  // MARK: - Peer State

  @ObservableState
  public struct PeerState: Equatable, Identifiable {
    public let id: String
    public var videoTrack: VideoTrackInfo?
    public var connectionState: ConnectionState = .connecting

    public init(
      id: String, videoTrack: VideoTrackInfo? = nil,
      connectionState: ConnectionState = .connecting
    ) {
      self.id = id
      self.videoTrack = videoTrack
      self.connectionState = connectionState
    }
  }

  // MARK: - Connection State

  public enum ConnectionState: String, Equatable, CaseIterable {
    case disconnected
    case connecting
    case connected
    case failed
    case closed

    public var isConnected: Bool {
      self == .connected
    }
  }

  // MARK: - Actions

  @CasePathable
  public enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
    case view(ViewAction)
    case binding(BindingAction<State>)
    case delegate(Delegate)

    case startListening
    case stopListening
    case webRTCEvent(WebRTCEvent)
    case remoteOfferHandled(String, WebRTCAnswer)
    case iceCandidateAdded(String)
    case peerDisconnected(String)
    case errorOccurred(WebRTCError, String?)
  }

  // MARK: - View Actions

  @CasePathable
  public enum ViewAction: Equatable {
    case task
    case handleRemoteOffer(WebRTCOffer)
    case handleICECandidate(ICECandidate)
    case disconnectPeer(userId: String)
    case dismissError
  }

  // MARK: - Delegate Actions

  @CasePathable
  public enum Delegate: Equatable {
    case offerGenerated(sdp: String, userId: String)
    case answerGenerated(sdp: String, userId: String)
    case iceCandidateGenerated(
      candidate: String, sdpMLineIndex: Int, sdpMid: String?, userId: String)
    case videoTrackAdded(VideoTrackInfo)
    case videoTrackRemoved(userId: String)
    case connectionStateChanged(userId: String, state: ConnectionState)
    case errorOccurred(WebRTCError, userId: String?)
  }

  // MARK: - Dependencies

  private let logger = Logger(subsystem: "WebRTCCore", category: "WebRTCFeature")

  // MARK: - Reducer Body

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce(core)
  }

  public func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case let .view(viewAction):
      return handleViewAction(viewAction, state: &state)

    case .startListening:
      state.isListening = true
      return .run { send in
        @Dependency(\.webRTCEngine) var webRTCEngine
        for await event in webRTCEngine.events() {
          await send(.webRTCEvent(event))
        }
      }
      .cancellable(id: CancelID.webRTCEvents)

    case .stopListening:
      state.isListening = false
      return .cancel(id: CancelID.webRTCEvents)

    case let .webRTCEvent(event):
      return handleWebRTCEvent(event, state: &state)

    case let .remoteOfferHandled(userId, answer):
      logger.info("✅ WebRTCFeature: Remote offer handled for \(userId), sending answer")
      // Automatically add peer to state when offer is handled successfully
      let peerState = PeerState(id: userId, connectionState: .connecting)
      state.connectedPeers.updateOrAppend(peerState)
      // Send answer back to client via delegate
      return .send(.delegate(.answerGenerated(sdp: answer.sdp, userId: userId)))

    case let .iceCandidateAdded(userId):
      logger.info("✅ WebRTCFeature: ICE candidate added for \(userId)")
      return .none

    case let .peerDisconnected(userId):
      state.connectedPeers.remove(id: userId)
      return .send(.delegate(.videoTrackRemoved(userId: userId)))

    case let .errorOccurred(error, userId):
      state.error = error
      logger.error(
        "❌ WebRTCFeature: Error occurred: \(error.localizedDescription), userId: \(userId ?? "nil")"
      )
      return .send(.delegate(.errorOccurred(error, userId: userId)))

    case .binding:
      return .none

    case .delegate:
      return .none
    }
  }

  // MARK: - Private Methods

  private func handleViewAction(_ viewAction: ViewAction, state: inout State) -> Effect<Action> {
    switch viewAction {
    case .task:
      guard !state.isListening else {
        return .none
      }
      return .send(.startListening)

    case let .handleRemoteOffer(offer):
      let userId = offer.from
      return .run { send in
        @Dependency(\.webRTCEngine) var webRTCEngine
        do {
          // Automatically create peer connection and handle offer
          let answer = try await webRTCEngine.setRemoteOffer(offer)
          await send(.remoteOfferHandled(userId, answer))
        } catch let error as WebRTCError {
          await send(.errorOccurred(error, userId))
        } catch {
          await send(.errorOccurred(.failedToSetDescription, userId))
        }
      }

    case let .handleICECandidate(candidate):
      let userId = candidate.from
      return .run { send in
        @Dependency(\.webRTCEngine) var webRTCEngine
        do {
          try await webRTCEngine.addIceCandidate(candidate)
          await send(.iceCandidateAdded(userId))
        } catch let error as WebRTCError {
          await send(.errorOccurred(error, userId))
        } catch {
          await send(.errorOccurred(.failedToAddCandidate, userId))
        }
      }

    case let .disconnectPeer(userId):
      return .run { send in
        @Dependency(\.webRTCEngine) var webRTCEngine
        await webRTCEngine.removePeerConnection(userId)
        await send(.peerDisconnected(userId))
      }

    case .dismissError:
      state.error = nil
      return .none
    }
  }

  private func handleWebRTCEvent(_ event: WebRTCEvent, state: inout State) -> Effect<Action> {
    switch event {
    case let .offerGenerated(sdp, userId):
      return .send(.delegate(.offerGenerated(sdp: sdp, userId: userId)))

    case let .answerGenerated(sdp, userId):
      return .send(.delegate(.answerGenerated(sdp: sdp, userId: userId)))

    case let .iceCandidateGenerated(candidate, sdpMLineIndex, sdpMid, userId):
      return .send(
        .delegate(
          .iceCandidateGenerated(
            candidate: candidate,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid,
            userId: userId
          )))

    case let .connectionStateChanged(stateString, userId):
      let connectionState =
        ConnectionState(rawValue: stateString.lowercased()) ?? .disconnected

      if var peer = state.connectedPeers[id: userId] {
        peer.connectionState = connectionState
        state.connectedPeers.updateOrAppend(peer)
      }

      return .send(.delegate(.connectionStateChanged(userId: userId, state: connectionState)))

    case let .iceConnectionStateChanged(stateString, userId):
      let connectionState =
        ConnectionState(rawValue: stateString.lowercased()) ?? .disconnected

      if var peer = state.connectedPeers[id: userId] {
        peer.connectionState = connectionState
        state.connectedPeers.updateOrAppend(peer)
      }

      return .send(.delegate(.connectionStateChanged(userId: userId, state: connectionState)))

    case let .videoTrackAdded(trackInfo):
      if var peer = state.connectedPeers[id: trackInfo.userId] {
        peer.videoTrack = trackInfo
        peer.connectionState = .connected
        state.connectedPeers.updateOrAppend(peer)
      } else {
        let peerState = PeerState(
          id: trackInfo.userId,
          videoTrack: trackInfo,
          connectionState: .connected
        )
        state.connectedPeers.append(peerState)
      }

      return .send(.delegate(.videoTrackAdded(trackInfo)))

    case let .videoTrackRemoved(userId):
      if var peer = state.connectedPeers[id: userId] {
        peer.videoTrack = nil
        peer.connectionState = .disconnected
        state.connectedPeers.updateOrAppend(peer)
      }

      return .send(.delegate(.videoTrackRemoved(userId: userId)))

    case let .errorOccurred(error, userId):
      return .send(.errorOccurred(error, userId))
    }
  }

  // MARK: - Cancel IDs

  private enum CancelID: Hashable {
    case webRTCEvents
  }
}

// MARK: - Helpers

extension IdentifiedArrayOf where Element == WebRTCFeature.PeerState, ID == String {
  mutating func updateOrAppend(_ element: Element) {
    if self[id: element.id] != nil {
      self[id: element.id] = element
    } else {
      self.append(element)
    }
  }
}
