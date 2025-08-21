//
//  WebRTCFeatureTests.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/20.
//

import ComposableArchitecture
import CustomDump
import Testing
@preconcurrency import WebRTC

@testable import WebRTCCore

@MainActor
struct WebRTCFeatureTests {

  @Test
  func task_startsListening() async {
    let eventstream = AsyncStream.makeStream(of: WebRTCEvent.self)
    let store = TestStore(initialState: WebRTCFeature.State()) {
      WebRTCFeature()
    } withDependencies: {
      $0.webRTCEngine.events = { eventstream.stream }
    }

    await store.send(\.view, .task)
    await store.receive(\.startListening) {
      $0.isListening = true
    }

    eventstream.continuation.finish()

    await store.finish()
  }

  @Test
  func handleRemoteOffer_success_automaticallyCreatesConnectionAndSendsAnswer() async {
    let mockOffer = WebRTCOffer(
      sdp: "mock-offer-sdp",
      type: "offer",
      clientId: "user123",
      videoSource: "camera"
    )
    let mockAnswer = WebRTCAnswer(
      sdp: "mock-answer-sdp",
      type: "answer",
      clientId: "user123",
      videoSource: "camera"
    )

    let store = TestStore(initialState: WebRTCFeature.State()) {
      WebRTCFeature()
    } withDependencies: {
      $0.webRTCEngine.setRemoteOffer = { _, _ in mockAnswer }
    }

    await store.send(\.view, .handleRemoteOffer(mockOffer, userId: "user123"))

    // Should automatically create peer connection and send answer via delegate
    await store.receive(.remoteOfferHandled("user123", mockAnswer)) {
      $0.connectedPeers = [
        WebRTCFeature.PeerState(id: "user123", connectionState: .connecting)
      ]
    }
    await store.receive(\.delegate, .answerGenerated(sdp: "mock-answer-sdp", userId: "user123"))
  }

  @Test
  func handleRemoteOffer_failure() async {
    let mockOffer = WebRTCOffer(
      sdp: "mock-offer-sdp",
      type: "offer",
      clientId: "user123",
      videoSource: "camera"
    )

    let store = TestStore(initialState: WebRTCFeature.State()) {
      WebRTCFeature()
    } withDependencies: {
      $0.webRTCEngine.setRemoteOffer = { _, _ in throw WebRTCError.failedToSetDescription }
    }

    await store.send(\.view, .handleRemoteOffer(mockOffer, userId: "user123"))
    await store.receive(.errorOccurred(WebRTCError.failedToSetDescription, "user123")) {
      $0.error = .failedToSetDescription
    }
    await store.receive(\.delegate, .errorOccurred(.failedToSetDescription, userId: "user123"))
  }

  @Test
  func handleICECandidate_success() async {
    let mockCandidate = ICECandidate(
      type: "ice",
      clientId: "user123",
      candidate: ICECandidate.Candidate(
        candidate: "candidate:mock",
        sdpMLineIndex: 0,
        sdpMid: "0"
      )
    )

    let store = TestStore(initialState: WebRTCFeature.State()) {
      WebRTCFeature()
    } withDependencies: {
      $0.webRTCEngine.addIceCandidate = { _, _ in }
    }

    await store.send(\.view, .handleICECandidate(mockCandidate, userId: "user123"))
    await store.receive(\.iceCandidateAdded, "user123")
  }

  @Test
  func handleICECandidate_failure() async {
    let mockCandidate = ICECandidate(
      type: "ice",
      clientId: "user123",
      candidate: ICECandidate.Candidate(
        candidate: "candidate:mock",
        sdpMLineIndex: 0,
        sdpMid: "0"
      )
    )

    let store = TestStore(initialState: WebRTCFeature.State()) {
      WebRTCFeature()
    } withDependencies: {
      $0.webRTCEngine.addIceCandidate = { _, _ in throw WebRTCError.failedToAddCandidate }
    }

    await store.send(\.view, .handleICECandidate(mockCandidate, userId: "user123"))
    await store.receive(.errorOccurred(WebRTCError.failedToAddCandidate, "user123")) {
      $0.error = .failedToAddCandidate
    }
    await store.receive(\.delegate, .errorOccurred(.failedToAddCandidate, userId: "user123"))
  }

  @Test
  func disconnectPeer_removesConnection() async {
    let store = TestStore(
      initialState: WebRTCFeature.State(
        connectedPeers: [
          WebRTCFeature.PeerState(id: "user123", connectionState: .connected)
        ]
      )
    ) {
      WebRTCFeature()
    } withDependencies: {
      $0.webRTCEngine.removePeerConnection = { _ in }
    }

    await store.send(\.view, .disconnectPeer(userId: "user123"))
    await store.receive(\.peerDisconnected, "user123") {
      $0.connectedPeers = []
    }
    await store.receive(\.delegate, .videoTrackRemoved(userId: "user123"))
  }

  @Test
  func dismissError() async {
    let store = TestStore(
      initialState: WebRTCFeature.State(error: .peerConnectionNotFound)
    ) {
      WebRTCFeature()
    }

    await store.send(\.view, .dismissError) {
      $0.error = nil
    }
  }

  @Test
  func webRTCEvent_offerGenerated() async {
    let store = TestStore(initialState: WebRTCFeature.State()) {
      WebRTCFeature()
    }

    let event = WebRTCEvent.offerGenerated(sdp: "mock-sdp", userId: "user123")
    await store.send(\.webRTCEvent, event)
    await store.receive(\.delegate, .offerGenerated(sdp: "mock-sdp", userId: "user123"))
  }

  @Test
  func webRTCEvent_videoTrackAdded() async {
    let store = TestStore(initialState: WebRTCFeature.State()) {
      WebRTCFeature()
    }

    let trackInfo = VideoTrackInfo(id: "track1", userId: "user123", track: nil)
    let event = WebRTCEvent.videoTrackAdded(trackInfo: trackInfo)

    await store.send(\.webRTCEvent, event) {
      $0.connectedPeers = [
        WebRTCFeature.PeerState(
          id: "user123",
          videoTrack: trackInfo,
          connectionState: .connected
        )
      ]
    }
    await store.receive(\.delegate, .videoTrackAdded(trackInfo))
  }

  @Test
  func webRTCEvent_connectionStateChanged() async {
    let store = TestStore(
      initialState: WebRTCFeature.State(
        connectedPeers: [
          WebRTCFeature.PeerState(id: "user123", connectionState: .connecting)
        ]
      )
    ) {
      WebRTCFeature()
    }

    let event = WebRTCEvent.connectionStateChanged(state: "connected", userId: "user123")

    await store.send(\.webRTCEvent, event) {
      $0.connectedPeers[id: "user123"]?.connectionState = .connected
    }
    await store.receive(
      \.delegate, .connectionStateChanged(userId: "user123", state: .connected))
  }

  @Test
  func completeWebRTCFlow_offerToVideoTrack() async {
    let eventstream = AsyncStream.makeStream(of: WebRTCEvent.self)
    let mockOffer = WebRTCOffer(
      sdp: "mock-offer-sdp",
      type: "offer",
      clientId: "user123",
      videoSource: "camera"
    )
    let mockAnswer = WebRTCAnswer(
      sdp: "mock-answer-sdp",
      type: "answer",
      clientId: "user123",
      videoSource: "camera"
    )

    let store = TestStore(initialState: WebRTCFeature.State()) {
      WebRTCFeature()
    } withDependencies: {
      $0.webRTCEngine.events = { eventstream.stream }
      $0.webRTCEngine.setRemoteOffer = { _, _ in mockAnswer }
      $0.webRTCEngine.addIceCandidate = { _, _ in }
    }

    // 1. Start WebRTC
    await store.send(\.view, .task)
    await store.receive(\.startListening) {
      $0.isListening = true
    }

    // 2. Handle remote offer - automatically creates connection and sends answer
    await store.send(\.view, .handleRemoteOffer(mockOffer, userId: "user123"))
    await store.receive(.remoteOfferHandled("user123", mockAnswer)) {
      $0.connectedPeers = [
        WebRTCFeature.PeerState(id: "user123", connectionState: .connecting)
      ]
    }
    await store.receive(\.delegate, .answerGenerated(sdp: "mock-answer-sdp", userId: "user123"))

    // 3. ICE candidates exchanged
    let iceCandidate = ICECandidate(
      type: "ice",
      clientId: "user123",
      candidate: ICECandidate.Candidate(
        candidate: "candidate:test",
        sdpMLineIndex: 0,
        sdpMid: "0"
      )
    )
    await store.send(\.view, .handleICECandidate(iceCandidate, userId: "user123"))
    await store.receive(\.iceCandidateAdded, "user123")

    // 4. Connection established and video track added
    let trackInfo = VideoTrackInfo(id: "track1", userId: "user123", track: nil)
    eventstream.continuation.yield(.videoTrackAdded(trackInfo: trackInfo))

    await store.receive(\.webRTCEvent, .videoTrackAdded(trackInfo: trackInfo)) {
      $0.connectedPeers[id: "user123"]?.videoTrack = trackInfo
      $0.connectedPeers[id: "user123"]?.connectionState = .connected
    }
    await store.receive(\.delegate, .videoTrackAdded(trackInfo))

    eventstream.continuation.finish()
    await store.finish()
  }
}
