import Foundation

/// The current state of the video player.
///
/// Use this enum to track and respond to state changes in ``BackgroundVideoView``
/// or ``BackgroundVideoUIView``. The player transitions through these states
/// during its lifecycle.
///
/// ```swift
/// BackgroundVideoView(resourceName: "background", resourceType: "mp4") { state in
///     switch state {
///     case .idle:
///         print("Player initialized")
///     case .loading:
///         showLoadingIndicator()
///     case .playing:
///         hideLoadingIndicator()
///     case .paused:
///         print("Video paused")
///     case .failed(let error):
///         handleError(error)
///     }
/// }
/// ```
///
/// Marked `@unchecked Sendable` because all simple cases are value types
/// and the associated `Error` is only stored, never mutated concurrently.
/// The primary error type (`VideoPlayerError`) is already `Sendable`.
///
/// Consider migrating to `any Error & Sendable` in a future breaking API change.
public enum VideoPlayerState: @unchecked Sendable, Equatable {
    /// The player has been initialized but no video has been loaded.
    ///
    /// This is the initial state before any video resource is requested.
    case idle

    /// The player is loading the video asset asynchronously.
    ///
    /// During this state, the video file is being read from the bundle
    /// and validated for playback. Display a loading indicator while
    /// in this state.
    case loading

    /// The video is actively playing.
    ///
    /// The player enters this state after successful asset loading
    /// and automatically loops the video content.
    case playing

    /// The video playback is paused.
    ///
    /// The player automatically pauses when the app enters the background
    /// and during audio session interruptions. It resumes playback when
    /// the app returns to the foreground.
    case paused

    /// Video loading or playback failed with an error.
    ///
    /// Check the associated ``VideoPlayerError`` to determine the cause
    /// and display an appropriate error message to the user.
    ///
    /// - Parameter error: The error that caused the failure.
    case failed(Error)

    public static func == (lhs: VideoPlayerState, rhs: VideoPlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.playing, .playing), (.paused, .paused):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }

    /// A Boolean value indicating whether the player is currently loading.
    ///
    /// Use this property to check if the player is in the loading state
    /// without pattern matching.
    ///
    /// ```swift
    /// if playerState.isLoading {
    ///     showSpinner()
    /// }
    /// ```
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}
