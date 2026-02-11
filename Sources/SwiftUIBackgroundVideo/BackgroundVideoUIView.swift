@preconcurrency import AVFoundation
import UIKit

/// A UIKit view that displays a seamlessly looping background video.
///
/// This view uses `AVQueuePlayer` with `AVPlayerLooper` to play video content
/// in an infinite loop without visible seams between iterations. The video
/// fills the view using aspect-fill scaling with the audio muted by default.
///
/// The view automatically handles app lifecycle events:
/// - Pauses playback when the app enters the background
/// - Resumes playback when the app returns to the foreground
/// - Responds to audio session interruptions appropriately
///
/// For SwiftUI applications, use ``BackgroundVideoView`` instead, which wraps
/// this class via `UIViewRepresentable`.
///
/// ```swift
/// let videoView = BackgroundVideoUIView(
///     frame: view.bounds,
///     resourceName: "background",
///     resourceType: "mp4"
/// )
/// videoView.stateDidChange = { state in
///     print("Player state: \(state)")
/// }
/// view.addSubview(videoView)
/// ```
public final class BackgroundVideoUIView: UIView {
    /// The name of the currently loaded video resource.
    ///
    /// This value is updated when ``prepareAndPlayVideo(with:ofType:)`` is called
    /// and is used to avoid reloading the same video.
    var currentResourceName: String?

    /// The file extension of the currently loaded video resource.
    ///
    /// Common values include "mp4", "mov", and "m4v".
    var currentResourceType: String?

    /// The current playback state of the video player.
    ///
    /// Observe state changes using the ``stateDidChange`` callback. The state
    /// transitions through ``VideoPlayerState/loading`` while the asset loads,
    /// then to ``VideoPlayerState/playing`` on success or
    /// ``VideoPlayerState/failed(_:)`` on error.
    private(set) var playerState: VideoPlayerState = .idle {
        didSet {
            if playerState != oldValue {
                stateDidChange?(playerState)
            }
        }
    }

    /// A closure called whenever the player state changes.
    ///
    /// Use this callback to update your UI in response to state changes,
    /// such as showing a loading indicator or handling errors.
    ///
    /// ```swift
    /// videoView.stateDidChange = { state in
    ///     switch state {
    ///     case .loading:
    ///         self.showSpinner()
    ///     case .playing:
    ///         self.hideSpinner()
    ///     case .failed(let error):
    ///         self.showError(error)
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    var stateDidChange: ((VideoPlayerState) -> Void)?

    /// The layer used to display video content.
    private var playerLayer: AVPlayerLayer?

    /// The looper that enables seamless video repetition.
    private var playerLooper: AVPlayerLooper?

    /// The queue player that handles video playback.
    private var player: AVQueuePlayer?

    /// The current asset loading task.
    ///
    /// Marked `nonisolated(unsafe)` to allow cancellation from `deinit`.
    /// This is safe because `Task.cancel()` is thread-safe.
    /// TODO: Replace with `isolated deinit` when targeting Swift 6.2+ (iOS 18.4+).
    nonisolated(unsafe) private var loadAssetTask: Task<Void, Never>?

    /// A Boolean value indicating whether the video is currently playing.
    private var isPlaying: Bool {
        player?.rate != 0 && player?.error == nil
    }

    /// Creates a new background video view.
    ///
    /// If both `resourceName` and `resourceType` are provided, the video
    /// begins loading immediately. Otherwise, call
    /// ``prepareAndPlayVideo(with:ofType:)`` to start playback later.
    ///
    /// ```swift
    /// // Immediate playback
    /// let videoView = BackgroundVideoUIView(
    ///     frame: bounds,
    ///     resourceName: "intro",
    ///     resourceType: "mp4"
    /// )
    ///
    /// // Deferred playback
    /// let videoView = BackgroundVideoUIView(frame: bounds)
    /// // Later...
    /// videoView.prepareAndPlayVideo(with: "intro", ofType: "mp4")
    /// ```
    ///
    /// - Parameters:
    ///   - frame: The frame rectangle for the view.
    ///   - resourceName: The name of the video file in the app bundle (without extension).
    ///   - resourceType: The file extension of the video (e.g., "mp4").
    public init(frame: CGRect = .zero, resourceName: String? = nil, resourceType: String? = nil) {
        super.init(frame: frame)

        setupObservers()

        if let resourceName, let resourceType {
            prepareAndPlayVideo(with: resourceName, ofType: resourceType)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        removeObservers()
        loadAssetTask?.cancel()
    }

    /// Updates the player layer frame to match the view bounds.
    override public func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    // MARK: - Public API

    /// Stops playback and releases all player resources.
    ///
    /// Call this method when you no longer need video playback to free
    /// memory and system resources. This method:
    /// - Cancels any in-progress asset loading
    /// - Pauses and releases the player
    /// - Removes the player layer from the view hierarchy
    ///
    /// After calling this method, you can start playback again by calling
    /// ``prepareAndPlayVideo(with:ofType:)``.
    func cleanupPlayer() {
        loadAssetTask?.cancel()
        loadAssetTask = nil

        player?.pause()
        playerLooper = nil
        player = nil

        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    /// Loads and plays a video from the app bundle.
    ///
    /// This method handles the complete video loading lifecycle:
    /// 1. Checks if the same video is already loaded (no-op if so)
    /// 2. Cleans up any existing player
    /// 3. Loads the asset asynchronously (with caching)
    /// 4. Sets up the player and begins playback
    ///
    /// The ``playerState`` property is updated throughout the process,
    /// and the ``stateDidChange`` callback is invoked on each transition.
    ///
    /// ```swift
    /// videoView.prepareAndPlayVideo(with: "background", ofType: "mp4")
    /// ```
    ///
    /// - Parameters:
    ///   - resourceName: The name of the video file in the app bundle (without extension).
    ///   - type: The file extension of the video (e.g., "mp4", "mov").
    func prepareAndPlayVideo(with resourceName: String, ofType type: String) {
        guard !playerState.isLoading else {
            return
        }

        guard currentResourceName != resourceName || currentResourceType != type else {
            return play()
        }

        playerState = .loading
        currentResourceName = resourceName
        currentResourceType = type

        cleanupPlayer()

        loadAssetTask = Task { [weak self] in
            guard let self else { return }

            do {
                let asset = try await self.loadAsset(
                    resourceName: resourceName,
                    resourceType: type
                )

                guard !Task.isCancelled else { return }

                self.setupPlayer(with: asset)
            } catch is CancellationError {
                return
            } catch {
                self.currentResourceName = nil
                self.currentResourceType = nil
                self.playerState = .failed(error)
            }
        }
    }

    /// Loads a video asset, using a cached version if available.
    ///
    /// This method first checks ``VideoAssetCache`` for a previously loaded
    /// asset. If not found, it loads the asset from the bundle and validates
    /// that it can be played before caching it.
    ///
    /// - Parameters:
    ///   - resourceName: The name of the video file in the app bundle (without extension).
    ///   - resourceType: The file extension of the video (e.g., "mp4").
    /// - Returns: A playable `AVAsset` instance.
    /// - Throws: ``VideoPlayerError/resourceNotFound`` if the file doesn't exist,
    ///   or ``VideoPlayerError/invalidResource`` if the file can't be played.
    func loadAsset(resourceName: String, resourceType: String) async throws -> AVAsset {
        let cacheKey = "\(resourceName).\(resourceType)"

        if let cachedAsset = VideoAssetCache.shared.asset(forKey: cacheKey) {
            return cachedAsset
        }

        try Task.checkCancellation()

        guard let path = Bundle.main.path(forResource: resourceName, ofType: resourceType) else {
            throw VideoPlayerError.resourceNotFound
        }

        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)

        let isPlayable = try await loadPlayableStatus(for: asset)

        try Task.checkCancellation()

        if !isPlayable {
            throw VideoPlayerError.invalidResource
        }

        VideoAssetCache.shared.set(asset: asset, forKey: cacheKey)
        return asset
    }

    // MARK: - Private API

    /// Asynchronously loads and returns the playable status of an asset.
    ///
    /// On iOS 15 and later, this uses the modern `load(_:)` API. On earlier
    /// versions, it falls back to `loadValuesAsynchronously(forKeys:)`.
    ///
    /// - Parameter asset: The asset to check.
    /// - Returns: `true` if the asset can be played, `false` otherwise.
    /// - Throws: An error if loading the playable status fails.
    func loadPlayableStatus(for asset: AVAsset) async throws -> Bool {
        if #available(iOS 15, *) {
            return try await asset.load(.isPlayable)
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                asset.loadValuesAsynchronously(forKeys: ["playable"]) {
                    var error: NSError?
                    let status = asset.statusOfValue(forKey: "playable", error: &error)
                    switch status {
                    case .loaded:
                        continuation.resume(returning: asset.isPlayable)
                    case .failed, .cancelled:
                        continuation.resume(
                            throwing: error ?? VideoPlayerError.invalidResource
                        )
                    default:
                        continuation.resume(throwing: VideoPlayerError.invalidResource)
                    }
                }
            }
        }
    }

    /// Configures the player with a loaded asset and begins playback.
    ///
    /// This method creates the player stack: `AVQueuePlayer` → `AVPlayerLooper` → `AVPlayerLayer`.
    /// The video is muted and uses aspect-fill scaling to cover the entire view.
    ///
    /// - Parameter asset: A validated, playable `AVAsset`.
    private func setupPlayer(with asset: AVAsset) {
        let playerItem = AVPlayerItem(asset: asset)

        let player = AVQueuePlayer(playerItem: playerItem)
        self.player = player
        player.isMuted = true

        let playerLayer = AVPlayerLayer(player: player)
        self.playerLayer = playerLayer
        playerLayer.videoGravity = .resizeAspectFill

        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)

        layer.sublayers?
            .filter { $0 is AVPlayerLayer }
            .forEach { $0.removeFromSuperlayer() }
        layer.addSublayer(playerLayer)

        play()
    }

    /// Starts video playback if not already playing.
    ///
    /// Updates ``playerState`` to ``VideoPlayerState/playing``.
    private func play() {
        guard !isPlaying else {
            return
        }

        player?.play()
        playerState = .playing
    }

    /// Pauses video playback if currently playing.
    ///
    /// Updates ``playerState`` to ``VideoPlayerState/paused``.
    private func pause() {
        guard isPlaying else {
            return
        }

        player?.pause()
        playerState = .paused
    }
}

// MARK: - BackgroundVideoUIView (NotificationCenter) -

/// Extension handling app lifecycle and audio session notifications.
extension BackgroundVideoUIView {
    /// Removes all notification observers from this view.
    ///
    /// Called automatically in `deinit` and by ``BackgroundVideoView/dismantleUIView(_:coordinator:)``.
    nonisolated func removeObservers() {
        // swiftlint:disable:next notification_center_detachment
        NotificationCenter.default.removeObserver(self)
    }

    /// Registers observers for app lifecycle and audio session events.
    ///
    /// The view observes:
    /// - `willEnterForegroundNotification`: Resumes playback
    /// - `didEnterBackgroundNotification`: Pauses playback
    /// - `interruptionNotification`: Handles audio interruptions (e.g., phone calls)
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    /// Resumes video playback when the app returns to the foreground.
    @objc
    private func handleApplicationWillEnterForeground() {
        play()
    }

    /// Pauses video playback when the app enters the background.
    @objc
    private func handleApplicationDidEnterBackground() {
        pause()
    }

    /// Handles audio session interruptions (e.g., incoming phone calls).
    ///
    /// Pauses playback when an interruption begins and resumes when it ends
    /// (if the system indicates resumption is appropriate).
    @objc
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            if isPlaying {
                pause()
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }
}
