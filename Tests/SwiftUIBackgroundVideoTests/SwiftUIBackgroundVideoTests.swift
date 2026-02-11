import Testing
@testable import SwiftUIBackgroundVideo
@preconcurrency import AVFoundation

@Suite(.serialized) @MainActor
struct SwiftUIBackgroundVideoTests {
    @Test
    func cacheReturnsNilForUnknownKey() {
        let unknownKey = "doesNotExist"
        let result = VideoAssetCache.shared.asset(forKey: unknownKey)
        #expect(result == nil)
    }

    @Test
    func cacheStoresAndRetrievesAsset() {
        let testURL = URL(fileURLWithPath: "/dev/null") // Fake URL
        let asset = AVAsset(url: testURL)

        let key = "TestAssetKey"
        VideoAssetCache.shared.set(asset: asset, forKey: key)

        let cachedAsset = VideoAssetCache.shared.asset(forKey: key)
        #expect(cachedAsset != nil)
        #expect(cachedAsset == asset)
    }

    @Test
    func loadAssetThrowsResourceNotFound() async throws {
        let fakeView = BackgroundVideoUIView()

        let error = try await #require(throws: VideoPlayerError.self) {
            try await fakeView.loadTestAsset(resourceName: "NonExistent", resourceType: "mp4")
        }
        #expect(error == .resourceNotFound)
    }

    @Test
    func loadAssetThrowsInvalidResource() async throws {
        let fakeView = BackgroundVideoUIView()
        let bogusURL = URL(fileURLWithPath: "/dev/null")

        let error = try await #require(throws: VideoPlayerError.self) {
            try await fakeView.loadTestAsset(url: bogusURL)
        }
        #expect(error == .invalidResource)
    }

    @Test
    func failedLoadAllowsRetryWithSameResource() async {
        let view = BackgroundVideoUIView()

        // First attempt: load a non-existent resource, which will fail
        view.prepareAndPlayVideo(with: "NonExistent", ofType: "mp4")

        // Wait for the async task to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        #expect(view.playerState == .failed(VideoPlayerError.resourceNotFound))

        // Verify the root cause fix: resource tracking is reset on failure
        #expect(view.currentResourceName == nil)
        #expect(view.currentResourceType == nil)

        // Second attempt: retry the same resource
        view.prepareAndPlayVideo(with: "NonExistent", ofType: "mp4")

        #expect(view.playerState == .loading)

        // Cancel the pending task to clean up
        view.cleanupPlayer()
    }

    // MARK: - VideoPlayerState Equatable

    @Test(arguments: [
        VideoPlayerState.idle,
        VideoPlayerState.loading,
        VideoPlayerState.playing,
        VideoPlayerState.paused
    ])
    func playerStateEqualsSelf(state: VideoPlayerState) {
        #expect(state == state)
    }

    @Test
    func failedCasesAreAlwaysEqual() {
        let state1 = VideoPlayerState.failed(VideoPlayerError.resourceNotFound)
        let state2 = VideoPlayerState.failed(VideoPlayerError.invalidResource)
        #expect(state1 == state2)
    }

    @Test(arguments: zip(
        [VideoPlayerState.idle, .playing, .idle],
        [VideoPlayerState.loading, .paused, .failed(VideoPlayerError.resourceNotFound)]
    ))
    func differentPlayerStatesAreNotEqual(lhs: VideoPlayerState, rhs: VideoPlayerState) {
        #expect(lhs != rhs)
    }

    // MARK: - Cancellation

    @Test
    func cancelledLoadDoesNotSetFailedState() async {
        let view = BackgroundVideoUIView()
        var states: [VideoPlayerState] = []
        view.stateDidChange = { state in
            states.append(state)
        }

        view.prepareAndPlayVideo(with: "NonExistent", ofType: "mp4")
        #expect(view.playerState == .loading)

        // Immediately cancel via cleanupPlayer
        view.cleanupPlayer()

        // Give the cancelled task time to settle
        try? await Task.sleep(nanoseconds: 500_000_000)

        let hasFailed = states.contains {
            if case .failed = $0 {
                return true
            }
            return false
        }
        #expect(!hasFailed)
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
        guard isPlayable else { throw VideoPlayerError.invalidResource }
        return asset
    }
}
