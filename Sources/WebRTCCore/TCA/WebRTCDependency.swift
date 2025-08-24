//
//  WebRTCDependency.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/18.
//

import ComposableArchitecture
import Foundation
@preconcurrency import WebRTC

// MARK: - WebRTC Dependency

/// Modern TCA dependency for WebRTC functionality
/// Uses AsyncStream for event handling instead of delegate pattern
@DependencyClient
public struct WebRTCDependency: Sendable {

  // MARK: - Core Operations

  /// Create a peer connection for a user
  public var createPeerConnection: @Sendable (String) async -> Bool = { _ in false }

  /// Remove a peer connection for a user
  public var removePeerConnection: @Sendable (String) async -> Void

  /// Create an offer for a user
  public var createOffer: @Sendable (String) async throws -> Void

  /// Set remote offer and return generated answer
  public var setRemoteOffer: @Sendable (WebRTCOffer) async throws -> WebRTCAnswer

  /// Set remote answer
  public var setRemoteAnswer: @Sendable (WebRTCAnswer) async throws -> Void

  /// Add ICE candidate
  public var addIceCandidate: @Sendable (ICECandidate) async throws -> Void

  // MARK: - Event Stream (replaces delegate pattern)

  /// Stream of WebRTC events for modern async handling
  /// All state changes (video tracks, connection states, etc.) are communicated through this stream
  public var events: @Sendable () -> AsyncStream<WebRTCEvent> = { AsyncStream.never }
}

// MARK: - Dependency Keys

extension WebRTCDependency: TestDependencyKey {
  public static let testValue = Self()
}

extension WebRTCDependency: DependencyKey {
  public static let liveValue: Self = {
    let engine = WebRTCEngine()

    return WebRTCDependency(
      createPeerConnection: { userId in
        await engine.createPeerConnection(for: userId)
      },
      removePeerConnection: { userId in
        await engine.removePeerConnection(for: userId)
      },
      createOffer: { userId in
        try await engine.createOffer(for: userId)
      },
      setRemoteOffer: { offer in
        let userId = offer.from
        let rtcOffer = offer.toRTCSessionDescription()
        let rtcAnswer = try await engine.setRemoteOffer(rtcOffer, for: userId)
        return rtcAnswer.toWebRTCAnswer(from: userId, to: offer.from)
      },
      setRemoteAnswer: { answer in
        let userId = answer.from
        let rtcAnswer = answer.toRTCSessionDescription()
        try await engine.setRemoteAnswer(rtcAnswer, for: userId)
      },
      addIceCandidate: { candidate in
        let userId = candidate.from
        let rtcCandidate = candidate.toRTCIceCandidate()
        try await engine.addIceCandidate(rtcCandidate, for: userId)
      },
      events: {
        engine.events
      }
    )
  }()
}

// MARK: - Dependency Values Extension

extension DependencyValues {
  public var webRTCEngine: WebRTCDependency {
    get { self[WebRTCDependency.self] }
    set { self[WebRTCDependency.self] = newValue }
  }
}
