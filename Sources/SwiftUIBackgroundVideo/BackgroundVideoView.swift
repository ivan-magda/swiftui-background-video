import SwiftUI

public struct BackgroundVideoView: UIViewRepresentable {
    public let resourceName: String
    public let resourceType: String

    public var onStateChanged: ((VideoPlayerState) -> Void)?

    public static func dismantleUIView(_ uiView: BackgroundVideoUIView, coordinator: Void) {
        uiView.stateDidChange = nil
        uiView.removeObservers()
        uiView.cleanupPlayer()
    }

    public func makeUIView(context: Context) -> BackgroundVideoUIView {
        BackgroundVideoUIView(resourceName: resourceName, resourceType: resourceType)
    }

    public func updateUIView(_ uiView: BackgroundVideoUIView, context: Context) {
        uiView.stateDidChange = onStateChanged
        uiView.prepareAndPlayVideo(with: resourceName, ofType: resourceType)
    }
}
