# WebRTCCore 簡化 API 使用範例

## 簡化後的客戶端使用方式

### 1. 初始化 WebRTC Feature

```swift
import WebRTCCore
import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State {
        var webRTC = WebRTCFeature.State()
    }
    
    enum Action {
        case webRTC(WebRTCFeature.Action)
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.webRTC, action: \.webRTC) {
            WebRTCFeature()
        }
    }
}
```

### 2. 在 SwiftUI View 中使用

```swift
struct ContentView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    var body: some View {
        VStack {
            // 顯示連線狀態
            Text("Connected peers: \(store.webRTC.connectedPeers.count)")
            
            // 顯示視訊畫面
            ForEach(store.webRTC.connectedPeers) { peer in
                if let videoTrack = peer.videoTrack {
                    VideoView(track: videoTrack.track)
                        .frame(width: 320, height: 240)
                }
            }
            
            // 錯誤顯示
            if let error = store.webRTC.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                Button("Dismiss") {
                    store.send(.webRTC(.view(.dismissError)))
                }
            }
        }
        .task {
            // 啟動 WebRTC 監聽
            store.send(.webRTC(.view(.task)))
        }
    }
}
```

### 3. 處理 Signaling Server 的訊息

```swift
extension AppFeature {
    func handleSignalingMessage(_ message: SignalingMessage) -> Effect<Action> {
        switch message {
        case let .offer(offer, userId):
            // 收到 offer，自動建立連線並回覆 answer
            return .send(.webRTC(.view(.handleRemoteOffer(offer, userId: userId))))
            
        case let .iceCandidate(candidate, userId):
            // 處理 ICE candidate
            return .send(.webRTC(.view(.handleICECandidate(candidate, userId: userId))))
            
        default:
            return .none
        }
    }
}
```

### 4. 監聽 WebRTC 事件

```swift
extension AppFeature {
    var body: some ReducerOf<Self> {
        Scope(state: \.webRTC, action: \.webRTC) {
            WebRTCFeature()
        }
        
        Reduce { state, action in
            switch action {
            case let .webRTC(.delegate(.answerGenerated(sdp, userId))):
                // 自動產生的 answer，發送到 signaling server
                let answer = WebRTCAnswer(sdp: sdp, type: "answer", clientId: userId, videoSource: "")
                return sendToSignalingServer(answer, userId: userId)
                
            case let .webRTC(.delegate(.iceCandidateGenerated(candidate, sdpMLineIndex, sdpMid, userId))):
                // ICE candidate，發送到 signaling server
                let iceCandidate = ICECandidate(
                    type: "ice",
                    clientId: userId,
                    candidate: ICECandidate.Candidate(
                        candidate: candidate,
                        sdpMLineIndex: sdpMLineIndex,
                        sdpMid: sdpMid
                    )
                )
                return sendToSignalingServer(iceCandidate, userId: userId)
                
            case let .webRTC(.delegate(.videoTrackAdded(trackInfo))):
                // 視訊軌道已添加，UI 會自動更新
                print("Video track added for user: \(trackInfo.userId)")
                return .none
                
            case let .webRTC(.delegate(.connectionStateChanged(userId, state))):
                print("Connection state changed for \(userId): \(state)")
                return .none
                
            default:
                return .none
            }
        }
    }
}
```

## 核心 API 總結

### ViewActions (客戶端需要的)
- `.task` - 啟動 WebRTC 監聽
- `.handleRemoteOffer(WebRTCOffer, userId: String)` - 處理收到的 offer，自動回覆 answer
- `.handleICECandidate(ICECandidate, userId: String)` - 處理 ICE candidate
- `.disconnectPeer(userId: String)` - 主動斷開某個 peer
- `.dismissError` - 清除錯誤

### Delegate Actions (自動事件)
- `.answerGenerated(sdp: String, userId: String)` - 自動產生 answer，客戶端發送到 signaling server
- `.iceCandidateGenerated(...)` - ICE candidate 產生，客戶端發送到 signaling server
- `.videoTrackAdded(VideoTrackInfo)` - 視訊軌道添加，客戶端顯示畫面
- `.connectionStateChanged(userId: String, state: ConnectionState)` - 連線狀態變化
- `.errorOccurred(WebRTCError, userId: String?)` - 錯誤發生

## 使用流程

1. **啟動**: `store.send(.webRTC(.view(.task)))`
2. **收到 offer**: `store.send(.webRTC(.view(.handleRemoteOffer(offer, userId))))`
3. **監聽 delegate**: 自動收到 `answerGenerated`，發送到 signaling server
4. **處理 ICE**: `store.send(.webRTC(.view(.handleICECandidate(candidate, userId))))`
5. **自動連線**: WebRTC 內部自動處理連線建立
6. **視訊畫面**: 自動收到 `videoTrackAdded`，UI 顯示畫面

整個過程完全自動化，客戶端只需要處理 signaling 訊息的傳遞。