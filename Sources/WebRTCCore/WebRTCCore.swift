//
//  WebRTCCore.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/18.
//

import Foundation

// MARK: - Public Exports

// This file serves as the main entry point for the WebRTCCore package
// All public APIs are automatically available when importing WebRTCCore

// The following types are publicly available for client usage:

// TCA Integration:
// - WebRTCFeature (main TCA feature)
// - WebRTCDependency (TCA dependency)

// Models & Events:
// - VideoTrackInfo (video track information)
// - WebRTCEvent (event types from WebRTC engine)
// - WebRTCError (error types)

// Signaling Models (for client signaling implementation):
// - WebRTCOffer (SDP offer format)
// - WebRTCAnswer (SDP answer format)
// - ICECandidate (ICE candidate format)

// Extensions for signaling model conversions:
// - WebRTCOffer.toRTCSessionDescription()
// - WebRTCAnswer.toRTCSessionDescription()
// - ICECandidate.toRTCIceCandidate()
