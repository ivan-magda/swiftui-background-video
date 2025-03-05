@preconcurrency import AVFoundation
import AVKit
import UIKit
import Combine

public class BackgroundVideoUIView: UIView {
    var currentResourceName: String?
    var currentResourceType: String?

    private(set) var playerState: VideoPlayerState = .idle {
        didSet {
            stateDidChange?(playerState)
        }
    }

    var stateDidChange: ((VideoPlayerState) -> Void)?

    private var playerLayer: AVPlayerLayer?
    private var playerLooper: AVPlayerLooper?
    private var player: AVQueuePlayer?
    private var cancellables = Set<AnyCancellable>()

    private var loadAssetTask: Task<Void, Never>?

    private var isPlaying: Bool {
        player?.rate != 0 && player?.error == nil
    }

    init(frame: CGRect = .zero, resourceName: String? = nil, resourceType: String? = nil) {
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
        cleanupPlayer()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    // MARK: Public API

    func cleanupPlayer() {
        loadAssetTask?.cancel()
        loadAssetTask = nil

        cancellables.removeAll()

        player?.pause()
        playerLooper = nil
        player = nil

        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    func prepareAndPlayVideo(with resourceName: String, ofType type: String) {
        guard currentResourceName != resourceName || currentResourceType != type else {
            return
        }

        playerState = .loading
        currentResourceName = resourceName
        currentResourceType = type

        cleanupPlayer()

        loadAssetTask = Task {
            do {
                let asset = try await loadAsset(resourceName: resourceName, resourceType: type)

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    setupPlayer(with: asset)
                }
            } catch {
                await MainActor.run {
                    playerState = .failed(error)
                }
            }
        }
    }

    /// Loads an `AVAsset`, returning a cached version if available, otherwise loading from disk.
    func loadAsset(resourceName: String, resourceType: String) async throws -> AVAsset {
        let cacheKey = "\(resourceName).\(resourceType)"

        if let cachedAsset = VideoAssetCache.shared.asset(forKey: cacheKey) {
            return cachedAsset
        }

        guard let path = Bundle.main.path(forResource: resourceName, ofType: resourceType) else {
            throw VideoPlayerError.resourceNotFound
        }

        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)

        let isPlayable = try await loadPlayableStatus(for: asset)
        if !isPlayable {
            throw VideoPlayerError.invalidResource
        }

        VideoAssetCache.shared.set(asset: asset, forKey: cacheKey)

        return asset
    }

    // MARK: Private API

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

        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self else {
                    return
                }

                switch status {
                case .readyToPlay:
                    self.play()
                case .failed:
                    self.playerState = .failed(playerItem.error ?? VideoPlayerError.playbackFailed)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func play() {
        guard !isPlaying else {
            return
        }

        player?.play()
        playerState = .playing
    }

    private func pause() {
        guard isPlaying else {
            return
        }

        player?.pause()
        playerState = .paused
    }
}

// MARK: - BackgroundVideoUIView (NotificationCenter) -

extension BackgroundVideoUIView {
    func removeObservers() {
        // swiftlint:disable:next notification_center_detachment
        NotificationCenter.default.removeObserver(self)
    }

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

    @objc
    private func handleApplicationWillEnterForeground() {
        play()
    }

    @objc
    private func handleApplicationDidEnterBackground() {
        pause()
    }

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
