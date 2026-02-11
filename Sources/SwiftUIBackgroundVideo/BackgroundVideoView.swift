import SwiftUI

/// A SwiftUI view that displays a seamlessly looping background video.
///
/// Use this view to add ambient video backgrounds to your SwiftUI interfaces.
/// The video plays automatically, loops infinitely, and handles app lifecycle
/// events (pausing when backgrounded, resuming when foregrounded).
///
/// The video fills the view using aspect-fill scaling with audio muted,
/// making it ideal for decorative backgrounds that don't interfere with
/// your app's audio.
///
/// ```swift
/// struct ContentView: View {
///     var body: some View {
///         ZStack {
///             BackgroundVideoView(
///                 resourceName: "background",
///                 resourceType: "mp4"
///             ) { state in
///                 if case .failed(let error) = state {
///                     print("Video error: \(error)")
///                 }
///             }
///             .ignoresSafeArea()
///
///             // Your content here
///             Text("Welcome")
///                 .font(.largeTitle)
///                 .foregroundStyle(.white)
///         }
///     }
/// }
/// ```
///
/// For UIKit applications, use ``BackgroundVideoUIView`` directly.
public struct BackgroundVideoView: UIViewRepresentable {
    /// The name of the video file in the app bundle (without extension).
    let resourceName: String

    /// The file extension of the video (e.g., "mp4", "mov", "m4v").
    let resourceType: String

    /// A closure called whenever the player state changes.
    var onStateChanged: ((VideoPlayerState) -> Void)?

    /// Creates a new background video view.
    ///
    /// The video begins loading immediately when the view appears and
    /// starts playing automatically once loaded.
    ///
    /// ```swift
    /// BackgroundVideoView(
    ///     resourceName: "intro",
    ///     resourceType: "mp4"
    /// ) { state in
    ///     switch state {
    ///     case .loading:
    ///         showLoadingIndicator = true
    ///     case .playing:
    ///         showLoadingIndicator = false
    ///     case .failed(let error):
    ///         errorMessage = error.localizedDescription
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceName: The name of the video file in the app bundle (without extension).
    ///   - resourceType: The file extension of the video (e.g., "mp4").
    ///   - onStateChanged: An optional closure called when the player state changes.
    public init(
        resourceName: String,
        resourceType: String,
        onStateChanged: ((VideoPlayerState) -> Void)? = nil
    ) {
        self.resourceName = resourceName
        self.resourceType = resourceType
        self.onStateChanged = onStateChanged
    }

    /// Cleans up resources when the view is removed from the hierarchy.
    ///
    /// This method ensures proper cleanup of the video player, observers,
    /// and callbacks to prevent memory leaks.
    ///
    /// - Parameters:
    ///   - uiView: The underlying UIKit view being dismantled.
    ///   - coordinator: The coordinator (unused).
    public static func dismantleUIView(_ uiView: BackgroundVideoUIView, coordinator: Void) {
        uiView.stateDidChange = nil
        uiView.removeObservers()
        uiView.cleanupPlayer()
    }

    /// Creates the underlying UIKit view.
    ///
    /// - Parameter context: The context containing environment and coordinator info.
    /// - Returns: A configured ``BackgroundVideoUIView`` instance.
    public func makeUIView(context: Context) -> BackgroundVideoUIView {
        BackgroundVideoUIView(resourceName: resourceName, resourceType: resourceType)
    }

    /// Updates the underlying UIKit view when SwiftUI state changes.
    ///
    /// This method is called when the view's properties change. It updates
    /// the state callback and triggers video loading if the resource changed.
    ///
    /// - Parameters:
    ///   - uiView: The underlying UIKit view to update.
    ///   - context: The context containing environment and coordinator info.
    public func updateUIView(_ uiView: BackgroundVideoUIView, context: Context) {
        uiView.stateDidChange = onStateChanged
        uiView.prepareAndPlayVideo(with: resourceName, ofType: resourceType)
    }
}
