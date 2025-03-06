import SwiftUI

public struct BackgroundVideoView: UIViewRepresentable {
    let resourceName: String
    let resourceType: String

    var onStateChanged: ((VideoPlayerState) -> Void)?

    public init(
        resourceName: String,
        resourceType: String,
        onStateChanged: ((VideoPlayerState) -> Void)? = nil
    ) {
        self.resourceName = resourceName
        self.resourceType = resourceType
        self.onStateChanged = onStateChanged
    }

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
