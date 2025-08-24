//
//  RTCExtensions.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/18.
//

import Foundation
import WebRTC

// MARK: - RTCSessionDescription Extensions

extension RTCSessionDescription {
  /// Convert to WebRTCOffer model (internal use)
  /// - Parameters:
  ///   - from: The sender client ID
  ///   - to: The receiver client ID
  ///   - videoSource: The video source identifier
  /// - Returns: WebRTCOffer instance
  func toWebRTCOffer(from: String, to: String, videoSource: String = "") -> WebRTCOffer {
    return WebRTCOffer(
      sdp: self.sdp,
      type: "offer",
      from: from,
      to: to,
      videoSource: videoSource
    )
  }

  /// Convert to WebRTCAnswer model (internal use)
  /// - Parameters:
  ///   - from: The sender client ID
  ///   - to: The receiver client ID
  ///   - videoSource: The video source identifier
  /// - Returns: WebRTCAnswer instance
  func toWebRTCAnswer(from: String, to: String, videoSource: String = "") -> WebRTCAnswer {
    return WebRTCAnswer(
      sdp: self.sdp,
      type: "answer",
      from: from,
      to: to,
      videoSource: videoSource
    )
  }
}

// MARK: - RTCIceCandidate Extensions

extension RTCIceCandidate {
  /// Convert to ICECandidate model (internal use)
  /// - Parameters:
  ///   - from: The sender client ID
  ///   - to: The receiver client ID
  /// - Returns: ICECandidate instance
  func toICECandidate(from: String, to: String) -> ICECandidate {
    return ICECandidate(
      type: "ice",
      from: from,
      to: to,
      candidate: ICECandidate.Candidate(
        candidate: self.sdp,
        sdpMLineIndex: Int(self.sdpMLineIndex),
        sdpMid: self.sdpMid
      )
    )
  }
}

// MARK: - Model to WebRTC Extensions

extension WebRTCOffer {
  /// Convert to RTCSessionDescription
  /// - Returns: RTCSessionDescription for offer
  public func toRTCSessionDescription() -> RTCSessionDescription {
    return RTCSessionDescription(type: .offer, sdp: self.sdp)
  }
}

extension WebRTCAnswer {
  /// Convert to RTCSessionDescription
  /// - Returns: RTCSessionDescription for answer
  public func toRTCSessionDescription() -> RTCSessionDescription {
    return RTCSessionDescription(type: .answer, sdp: self.sdp)
  }
}

extension ICECandidate {
  /// Convert to RTCIceCandidate
  /// - Returns: RTCIceCandidate instance
  public func toRTCIceCandidate() -> RTCIceCandidate {
    return RTCIceCandidate(
      sdp: self.candidate.candidate,
      sdpMLineIndex: Int32(self.candidate.sdpMLineIndex),
      sdpMid: self.candidate.sdpMid
    )
  }
}

// MARK: - RTCPeerConnectionState Extensions (internal use)

extension RTCPeerConnectionState {
  /// Human readable description
  var description: String {
    switch self {
    case .new:
      return "New"
    case .connecting:
      return "Connecting"
    case .connected:
      return "Connected"
    case .disconnected:
      return "Disconnected"
    case .failed:
      return "Failed"
    case .closed:
      return "Closed"
    @unknown default:
      return "Unknown"
    }
  }

  /// Whether the connection is in a stable connected state
  var isConnected: Bool {
    return self == .connected
  }

  /// Whether the connection is in a failed or disconnected state
  var isDisconnected: Bool {
    return self == .failed || self == .disconnected || self == .closed
  }
}

// MARK: - RTCIceConnectionState Extensions (internal use)

extension RTCIceConnectionState {
  /// Human readable description
  var description: String {
    switch self {
    case .new:
      return "New"
    case .checking:
      return "Checking"
    case .connected:
      return "Connected"
    case .completed:
      return "Completed"
    case .failed:
      return "Failed"
    case .disconnected:
      return "Disconnected"
    case .closed:
      return "Closed"
    case .count:
      return "Count"
    @unknown default:
      return "Unknown"
    }
  }

  /// Whether the ICE connection is in a connected state
  var isConnected: Bool {
    return self == .connected || self == .completed
  }
}
