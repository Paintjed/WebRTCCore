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
  ///   - clientId: The client ID for this offer
  ///   - videoSource: The video source identifier
  /// - Returns: WebRTCOffer instance
  func toWebRTCOffer(clientId: String, videoSource: String = "") -> WebRTCOffer {
    return WebRTCOffer(
      sdp: self.sdp,
      type: "offer",
      clientId: clientId,
      videoSource: videoSource
    )
  }

  /// Convert to WebRTCAnswer model (internal use)
  /// - Parameters:
  ///   - clientId: The client ID for this answer
  ///   - videoSource: The video source identifier
  /// - Returns: WebRTCAnswer instance
  func toWebRTCAnswer(clientId: String, videoSource: String = "") -> WebRTCAnswer {
    return WebRTCAnswer(
      sdp: self.sdp,
      type: "answer",
      clientId: clientId,
      videoSource: videoSource
    )
  }
}

// MARK: - RTCIceCandidate Extensions

extension RTCIceCandidate {
  /// Convert to ICECandidate model (internal use)
  /// - Parameter clientId: The client ID for this candidate
  /// - Returns: ICECandidate instance
  func toICECandidate(clientId: String) -> ICECandidate {
    return ICECandidate(
      type: "ice",
      clientId: clientId,
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
