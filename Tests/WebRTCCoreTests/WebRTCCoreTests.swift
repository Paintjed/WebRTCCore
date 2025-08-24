//
//  WebRTCCoreTests.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/18.
//

import Testing

@testable import WebRTCCore

@Suite("WebRTC Core Models Tests")
struct WebRTCCoreTests {

  // WebRTCEngine is now internal, so we don't test it directly

  @Test("VideoTrackInfo Equality")
  func videoTrackInfoEquality() {
    let track1 = VideoTrackInfo(id: "1", userId: "user1", track: nil)
    let track2 = VideoTrackInfo(id: "1", userId: "user1", track: nil)
    let track3 = VideoTrackInfo(id: "2", userId: "user1", track: nil)

    #expect(track1 == track2)
    #expect(track1 != track3)
  }

  @Test("WebRTC Error Descriptions")
  func webRTCErrorDescriptions() {
    #expect(WebRTCError.peerConnectionNotFound.errorDescription == "Peer connection not found")
    #expect(WebRTCError.failedToCreateOffer.errorDescription == "Failed to create offer")
    #expect(WebRTCError.failedToCreateAnswer.errorDescription == "Failed to create answer")
    #expect(
      WebRTCError.failedToSetDescription.errorDescription
        == "Failed to set session description")
    #expect(WebRTCError.failedToAddCandidate.errorDescription == "Failed to add ICE candidate")
    #expect(
      WebRTCError.factoryInitializationFailed.errorDescription
        == "Failed to initialize peer connection factory")
  }

  @Test("ICE Candidate Model")
  func iceCandidateModel() {
    let candidate = ICECandidate(
      type: "ice",
      from: "client-1",
      to: "client-2",
      candidate: ICECandidate.Candidate(
        candidate: "test-candidate",
        sdpMLineIndex: 0,
        sdpMid: "0"
      )
    )

    #expect(candidate.type == "ice")
    #expect(candidate.from == "client-1")
    #expect(candidate.to == "client-2")
    #expect(candidate.candidate.candidate == "test-candidate")
    #expect(candidate.candidate.sdpMLineIndex == 0)
    #expect(candidate.candidate.sdpMid == "0")
  }

  @Test("WebRTC Event Equality")
  func webRTCEventEquality() {
    let event1 = WebRTCEvent.offerGenerated(sdp: "test-sdp", userId: "user1")
    let event2 = WebRTCEvent.offerGenerated(sdp: "test-sdp", userId: "user1")
    let event3 = WebRTCEvent.offerGenerated(sdp: "different-sdp", userId: "user1")

    #expect(event1 == event2)
    #expect(event1 != event3)
  }

  @Test("WebRTC Event Types")
  func webRTCEventTypes() {
    let offerEvent = WebRTCEvent.offerGenerated(sdp: "test-sdp", userId: "user1")
    let answerEvent = WebRTCEvent.answerGenerated(sdp: "test-sdp", userId: "user1")
    let iceEvent = WebRTCEvent.iceCandidateGenerated(
      candidate: "test", sdpMLineIndex: 0, sdpMid: "0", userId: "user1")
    let errorEvent = WebRTCEvent.errorOccurred(error: .peerConnectionNotFound, userId: "user1")

    #expect(offerEvent != answerEvent)
    #expect(iceEvent != errorEvent)

    switch offerEvent {
    case let .offerGenerated(sdp, userId):
      #expect(sdp == "test-sdp")
      #expect(userId == "user1")
    default:
      Issue.record("Expected offerGenerated event")
    }
  }

  @Test("WebRTC Offer Model")
  func webRTCOfferModel() {
    let offer = WebRTCOffer(
      sdp: "test-sdp",
      type: "offer",
      from: "client123",
      to: "client456",
      videoSource: "camera"
    )

    #expect(offer.sdp == "test-sdp")
    #expect(offer.type == "offer")
    #expect(offer.from == "client123")
    #expect(offer.to == "client456")
    #expect(offer.videoSource == "camera")
  }

  @Test("WebRTC Answer Model")
  func webRTCAnswerModel() {
    let answer = WebRTCAnswer(
      sdp: "test-answer-sdp",
      type: "answer",
      from: "client456",
      to: "client123",
      videoSource: "screen"
    )

    #expect(answer.sdp == "test-answer-sdp")
    #expect(answer.type == "answer")
    #expect(answer.from == "client456")
    #expect(answer.to == "client123")
    #expect(answer.videoSource == "screen")
  }

  // PeerConnectionInfo is now internal, so we don't test it directly
}
