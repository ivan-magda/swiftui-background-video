import Foundation

/// Errors that can occur during video player operations.
///
/// Use these error cases to handle failures when loading or playing
/// background videos. Each case represents a distinct failure mode
/// that requires different handling strategies.
///
/// ```swift
/// do {
///     let asset = try await loadAsset(resourceName: "intro", resourceType: "mp4")
/// } catch VideoPlayerError.resourceNotFound {
///     print("Video file not found in bundle")
/// } catch VideoPlayerError.invalidResource {
///     print("Video file cannot be played")
/// } catch {
///     print("Playback failed: \(error)")
/// }
/// ```
public enum VideoPlayerError: Error, Sendable {
    /// The specified video resource could not be found in the app bundle.
    ///
    /// This error occurs when `Bundle.main.path(forResource:ofType:)` returns `nil`,
    /// indicating the video file is not included in the app's resources.
    ///
    /// Verify that:
    /// - The file name and extension are spelled correctly
    /// - The file is added to the app target's "Copy Bundle Resources" build phase
    case resourceNotFound

    /// The video resource exists but cannot be played.
    ///
    /// This error occurs when the `AVAsset.isPlayable` property returns `false`,
    /// indicating the file format is unsupported or the file is corrupted.
    case invalidResource

    /// Video playback failed after loading.
    ///
    /// This error indicates a runtime failure during video playback,
    /// such as a decoder error or hardware limitation.
    case playbackFailed
}
