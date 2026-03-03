import Testing
@testable import SwiftUIBackgroundVideo
@preconcurrency import AVFoundation

// MARK: - VideoPlayerState Equatable

@Suite("VideoPlayerState Equatable")
struct VideoPlayerStateTests {
    @Test("Each state equals itself", arguments: [
        VideoPlayerState.idle,
        VideoPlayerState.loading,
        VideoPlayerState.playing,
        VideoPlayerState.paused,
        VideoPlayerState.failed(VideoPlayerError.resourceNotFound)
    ])
    func equalsSelf(state: VideoPlayerState) {
        #expect(state == state)
    }

    @Test("Failed cases are equal regardless of error")
    func failedCasesAreAlwaysEqual() {
        let state1 = VideoPlayerState.failed(VideoPlayerError.resourceNotFound)
        let state2 = VideoPlayerState.failed(VideoPlayerError.invalidResource)
        #expect(state1 == state2)
    }

    @Test("Different states are not equal", arguments: zip(
        [VideoPlayerState.idle, .playing, .idle],
        [VideoPlayerState.loading, .paused, .failed(VideoPlayerError.resourceNotFound)]
    ))
    func notEqual(lhs: VideoPlayerState, rhs: VideoPlayerState) {
        #expect(lhs != rhs)
    }
}

// MARK: - VideoAssetCache

@Suite("VideoAssetCache", .serialized)
@MainActor
struct VideoAssetCacheTests {
    @Test("Returns nil for unknown key")
    func returnsNilForUnknownKey() {
        let result = VideoAssetCache.shared.asset(forKey: "doesNotExist")
        #expect(result == nil)
    }

    @Test("Stores and retrieves asset")
    func storesAndRetrievesAsset() {
        let asset = AVAsset(url: URL(fileURLWithPath: "/dev/null"))
        let key = "TestAssetKey"

        VideoAssetCache.shared.set(asset: asset, forKey: key)
        defer { VideoAssetCache.shared.clearCache() }

        let cached = VideoAssetCache.shared.asset(forKey: key)
        #expect(cached == asset)
    }

    @Test("clearCache removes all entries")
    func clearCacheRemovesAllEntries() {
        for i in 0..<3 {
            let asset = AVAsset(url: URL(fileURLWithPath: "/dev/null"))
            VideoAssetCache.shared.set(asset: asset, forKey: "key\(i)")
        }

        VideoAssetCache.shared.clearCache()

        for i in 0..<3 {
            #expect(VideoAssetCache.shared.asset(forKey: "key\(i)") == nil)
        }
    }
}

// MARK: - Asset Loading

@Suite("Asset loading", .serialized)
@MainActor
struct AssetLoadingTests {
    @Test("Throws resourceNotFound for missing bundle resource")
    func throwsResourceNotFound() async throws {
        let view = BackgroundVideoUIView()

        let error = try await #require(throws: VideoPlayerError.self) {
            try await view.loadTestAsset(resourceName: "NonExistent", resourceType: "mp4")
        }
        #expect(error == .resourceNotFound)
    }

    @Test("Throws invalidResource for unplayable file")
    func throwsInvalidResource() async throws {
        let view = BackgroundVideoUIView()
        let bogusURL = URL(fileURLWithPath: "/dev/null")

        let error = try await #require(throws: VideoPlayerError.self) {
            try await view.loadTestAsset(url: bogusURL)
        }
        #expect(error == .invalidResource)
    }
}

// MARK: - Player Behavior

@Suite("Player behavior", .serialized)
@MainActor
struct PlayerBehaviorTests {
    @Test("Failed load allows retry with same resource")
    func failedLoadAllowsRetry() async {
        let view = BackgroundVideoUIView()

        view.prepareAndPlayVideo(with: "NonExistent", ofType: "mp4")
        await view.awaitState(.failed(VideoPlayerError.resourceNotFound))

        #expect(view.playerState == .failed(VideoPlayerError.resourceNotFound))

        // Verify resource tracking is reset on failure
        #expect(view.currentResourceName == nil)
        #expect(view.currentResourceType == nil)
        #expect(view.currentBundle == nil)

        // Retry the same resource — should accept it (not short-circuit)
        view.prepareAndPlayVideo(with: "NonExistent", ofType: "mp4")
        #expect(view.playerState == .loading)

        view.cleanupPlayer()
    }

    @Test("Cancelled load does not set failed state")
    func cancelledLoadDoesNotSetFailedState() async {
        let view = BackgroundVideoUIView()
        var didFail = false
        view.stateDidChange = { state in
            if case .failed = state { didFail = true }
        }

        view.prepareAndPlayVideo(with: "NonExistent", ofType: "mp4")
        #expect(view.playerState == .loading)

        // Immediately cancel via cleanupPlayer
        view.cleanupPlayer()

        // Brief wait for the cancelled task to settle
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(!didFail)
    }
}

// MARK: - Test Helpers

extension BackgroundVideoUIView {
    @MainActor
    func loadTestAsset(resourceName: String, resourceType: String) async throws -> AVAsset {
        try await loadAsset(resourceName: resourceName, resourceType: resourceType)
    }

    @MainActor
    func loadTestAsset(url: URL) async throws -> AVAsset {
        let asset = AVAsset(url: url)
        let isPlayable = try await loadPlayableStatus(for: asset)

        guard isPlayable else {
            throw VideoPlayerError.invalidResource
        }

        return asset
    }

    @MainActor
    func awaitState(_ target: VideoPlayerState) async {
        guard playerState != target else {
            return
        }

        await withCheckedContinuation { continuation in
            var resumed = false
            let previous = stateDidChange
            stateDidChange = { [weak self] state in
                previous?(state)
                if state == target, !resumed {
                    resumed = true
                    self?.stateDidChange = previous
                    continuation.resume()
                }
            }
        }
    }
}
