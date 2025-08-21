# WebRTCCore

A simplified Swift Package for receiving WebRTC connections with The Composable Architecture (TCA), designed for iOS and macOS applications.

## Features

- 🎯 **Receive-Only Focus**: Optimized for receiving WebRTC video/audio streams
- 🤖 **Automated Flow**: Auto-handles connection setup and SDP exchange
- 🏗️ **TCA Integration**: Clean integration with The Composable Architecture
- 🔄 **AsyncStream Events**: Modern async/await event handling
- 🧪 **Swift Testing**: Comprehensive test coverage with Swift Testing framework
- 🚀 **Swift 6.0**: Full Swift 6 strict concurrency compliance
- 📱 **Multi-Platform**: iOS 17+ and macOS 14+ support
- 🔌 **Standard Signaling**: Uses standardized signaling models for interoperability

## Architecture

```mermaid
graph TD
    A[Client App] -->|ViewAction| B[WebRTCFeature]
    A -->|Signaling Server| S[WebRTCOffer/Answer/ICE]
    
    B -->|Public API| C[WebRTCDependency]
    C -->|Internal| D[WebRTCEngine]
    D -->|Native WebRTC| E[RTCPeerConnection]
    
    B -->|Auto State Updates| F[WebRTCFeature.State]
    F -->|Peer Management| G[IdentifiedArray PeerState]
    F -->|Connection Tracking| H[ConnectionState]
    F -->|Error Handling| I[WebRTCError]
    
    D -->|AsyncStream| J[WebRTCEvent]
    J -->|Auto Events| K[Video Track Added]
    J -->|Auto Events| L[Connection State]
    J -->|Auto Events| M[Error Events]
    
    B -->|Delegate| N[Auto-Generated Responses]
    N -->|answerGenerated| O[Send to Signaling Server]
    N -->|videoTrackAdded| P[Display Video]
    
    style A fill:#e3f2fd
    style B fill:#f3e5f5
    style C fill:#e8f5e8
    style S fill:#fff3e0
    style D fill:#fafafa
    style E fill:#ffebee
```

## Core Components

### 🎯 WebRTCFeature
The main TCA reducer with simplified receive-only API:
- **5 Essential ViewActions**: `task`, `handleRemoteOffer`, `handleICECandidate`, `disconnectPeer`, `dismissError`
- **Automated Flow**: Receiving offers automatically creates connections and generates answers
- **Delegate Events**: Auto-generated answers, video tracks, and connection updates
- **State Management**: Tracks connected peers with automatic state updates

### 🔧 WebRTCDependency (Public API)
Clean TCA dependency interface using standardized signaling models:
- **Signaling Models**: Uses `WebRTCOffer`, `WebRTCAnswer`, `ICECandidate` instead of WebRTC native types
- **Automatic Conversion**: Internal conversion between signaling models and WebRTC types
- **Test Support**: Mock implementations for comprehensive testing
- **Sendable Compliance**: Full Swift 6 concurrency safety

### 🔒 WebRTCEngine (Internal)
Internal actor-based engine (not exposed to clients):
- Peer connection lifecycle management
- SDP negotiation handling
- ICE candidate processing
- Media track management
- Event streaming via AsyncStream

### 📊 Signaling Models
Standard interoperable data models:
- `WebRTCOffer`: SDP offer with client metadata
- `WebRTCAnswer`: SDP answer with client metadata  
- `ICECandidate`: ICE candidate with structured data
- `VideoTrackInfo`: Video track information with Sendable compliance
- `WebRTCEvent`: Unified event system for automated WebRTC operations

## Installation

### Swift Package Manager

Add WebRTCCore to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/WebRTCCore", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version requirements

## Usage

### Basic Setup

```swift
import ComposableArchitecture
import WebRTCCore

// 1. Add to your parent feature's state
struct AppFeature: Reducer {
    struct State {
        var webRTC = WebRTCFeature.State()
    }
    
    enum Action {
        case webRTC(WebRTCFeature.Action)
        case signalingMessage(SignalingMessage) // Your signaling system
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.webRTC, action: \.webRTC) {
            WebRTCFeature()
        }
        Reduce { state, action in
            switch action {
            // Auto-generated answer from WebRTC - send to signaling server
            case let .webRTC(.delegate(.answerGenerated(sdp, userId))):
                let answer = WebRTCAnswer(sdp: sdp, type: "answer", clientId: userId, videoSource: "")
                return sendToSignalingServer(answer, userId: userId)
                
            // ICE candidate generated - send to signaling server  
            case let .webRTC(.delegate(.iceCandidateGenerated(candidate, sdpMLineIndex, sdpMid, userId))):
                let iceCandidate = ICECandidate(
                    type: "ice", clientId: userId,
                    candidate: ICECandidate.Candidate(
                        candidate: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid
                    )
                )
                return sendToSignalingServer(iceCandidate, userId: userId)
                
            // Video track added - display in UI
            case let .webRTC(.delegate(.videoTrackAdded(trackInfo))):
                print("📺 Video track added for user: \(trackInfo.userId)")
                return .none
                
            // Handle incoming signaling messages
            case let .signalingMessage(.offer(offer, userId)):
                // Automatically handle offer and generate answer
                return .send(.webRTC(.view(.handleRemoteOffer(offer, userId: userId))))
                
            case let .signalingMessage(.iceCandidate(candidate, userId)):
                return .send(.webRTC(.view(.handleICECandidate(candidate, userId: userId))))
                
            default:
                return .none
            }
        }
    }
}
```

### SwiftUI Integration

Create your custom UI (WebRTCView is internal):

```swift
import SwiftUI
import ComposableArchitecture
import WebRTCCore

struct VideoCallView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    var body: some View {
        VStack {
            // Connection status
            HStack {
                Circle()
                    .fill(store.webRTC.isListening ? .green : .gray)
                    .frame(width: 12, height: 12)
                Text("\(store.webRTC.connectedPeers.count) connected")
            }
            
            // Video feeds
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                ForEach(store.webRTC.connectedPeers) { peer in
                    if let videoTrack = peer.videoTrack {
                        VideoView(track: videoTrack.track) // Your video renderer
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(alignment: .bottomLeading) {
                                Text(peer.id)
                                    .padding(4)
                                    .background(.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                    }
                }
            }
            
            // Error display
            if let error = store.webRTC.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error.localizedDescription)
                    Button("Dismiss") {
                        store.send(.webRTC(.view(.dismissError)))
                    }
                }
                .foregroundColor(.red)
            }
        }
        .task {
            // Start WebRTC listening
            store.send(.webRTC(.view(.task)))
        }
    }
}
```

### Complete Flow Example

```swift
// 1. Start WebRTC
store.send(.webRTC(.view(.task)))

// 2. When you receive an offer from signaling server
let offer = WebRTCOffer(sdp: sdpString, type: "offer", clientId: userId, videoSource: "camera")
store.send(.webRTC(.view(.handleRemoteOffer(offer, userId: userId))))

// 3. WebRTC automatically generates answer - send it back via signaling
// (handled in your reducer's delegate case)

// 4. When you receive ICE candidates from signaling server
let candidate = ICECandidate(
    type: "ice", clientId: userId,
    candidate: ICECandidate.Candidate(candidate: candidateString, sdpMLineIndex: 0, sdpMid: "0")
)
store.send(.webRTC(.view(.handleICECandidate(candidate, userId: userId))))

// 5. Video tracks are automatically added to state and delegate events fired
```

### Testing

WebRTCCore uses Swift Testing for comprehensive test coverage:

```swift
import Testing
import ComposableArchitecture
@testable import WebRTCCore

@MainActor
struct MyWebRTCTests {
    @Test
    func handleRemoteOffer_automaticallyCreatesConnectionAndSendsAnswer() async {
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
        await store.receive(.remoteOfferHandled("user123", mockAnswer)) {
            $0.connectedPeers = [
                WebRTCFeature.PeerState(id: "user123", connectionState: .connecting)
            ]
        }
        await store.receive(\.delegate, .answerGenerated(sdp: "mock-answer-sdp", userId: "user123"))
    }
}
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

## Dependencies

- [WebRTC](https://github.com/stasel/WebRTC): WebRTC framework
- [ComposableArchitecture](https://github.com/pointfreeco/swift-composable-architecture): TCA framework
- [CustomDump](https://github.com/pointfreeco/swift-custom-dump): Testing utilities

## Development

### Running Tests

```bash
swift test
```

### Code Formatting

```bash
swift-format --in-place Sources/ Tests/
```

### Building

```bash
swift build
```

## Event Flow

```mermaid
sequenceDiagram
    participant App as Client App
    participant Sig as Signaling Server
    participant F as WebRTCFeature
    participant D as WebRTCDependency
    participant E as WebRTCEngine
    participant W as WebRTC Framework
    
    Note over App,W: 1. Start WebRTC
    App->>F: .view(.task)
    F->>F: startListening
    F->>E: events()
    
    Note over App,W: 2. Receive Offer (Auto-Handle)
    Sig->>App: WebRTCOffer
    App->>F: .view(.handleRemoteOffer)
    F->>D: setRemoteOffer(offer, userId)
    D->>E: setRemoteOffer(offer, userId)
    E->>W: setRemoteDescription(offer)
    E->>W: createAnswer()
    W-->>E: SDP Answer
    E-->>D: WebRTCAnswer
    D-->>F: WebRTCAnswer
    F->>F: Update State (add peer)
    F->>App: .delegate(.answerGenerated)
    App->>Sig: Send Answer
    
    Note over App,W: 3. ICE Candidates
    Sig->>App: ICECandidate
    App->>F: .view(.handleICECandidate)
    F->>D: addIceCandidate(candidate, userId)
    D->>E: addIceCandidate(candidate, userId)
    E->>W: add(iceCandidate)
    
    Note over App,W: 4. Connection Established & Video
    E->>F: WebRTCEvent.videoTrackAdded
    F->>F: Update Peer State
    F->>App: .delegate(.videoTrackAdded)
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Follow the coding standards in `CLAUDE.md`
4. Ensure all tests pass: `swift test`
5. Format code: `swift-format --in-place Sources/ Tests/`
6. Commit changes: `git commit -m 'feat: add amazing feature'`
7. Push to branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
- WebRTC functionality powered by [WebRTC Framework](https://github.com/stasel/WebRTC)
- Follows Swift 6 concurrency best practices