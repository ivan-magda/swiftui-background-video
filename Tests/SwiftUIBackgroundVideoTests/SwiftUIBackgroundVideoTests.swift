import XCTest
@testable import SwiftUIBackgroundVideo
@preconcurrency import AVFoundation

final class SwiftUIBackgroundVideoTests: XCTestCase {
    @MainActor
    func test_CacheReturnsNilForUnknownKey() {
        let unknownKey = "doesNotExist"
        let result = VideoAssetCache.shared.asset(forKey: unknownKey)
        XCTAssertNil(result, "Cache should return nil for an unknown key.")
    }

    @MainActor
    func test_CacheStoresAndRetrievesAsset() {
        let testURL = URL(fileURLWithPath: "/dev/null") // Fake URL
        let asset = AVAsset(url: testURL)

        let key = "TestAssetKey"
        VideoAssetCache.shared.set(asset: asset, forKey: key)

        let cachedAsset = VideoAssetCache.shared.asset(forKey: key)
        XCTAssertNotNil(cachedAsset, "Cache should return the stored asset.")
        XCTAssertEqual(cachedAsset, asset, "Retrieved asset should match the one stored.")
    }

    @MainActor
    func test_loadAssetThrowsResourceNotFound() async throws {
        let fakeView = BackgroundVideoUIView()

        do {
            _ = try await fakeView.loadTestAsset(resourceName: "NonExistent", resourceType: "mp4")
            XCTFail("loadTestAsset should throw an error for non-existent resource.")
        } catch {
            // We expect a resourceNotFound error
            guard let videoError = error as? VideoPlayerError else {
                XCTFail("Expected VideoPlayerError, got \(error)")
                return
            }
            XCTAssertEqual(videoError, .resourceNotFound)
        }
    }

    @MainActor
    func test_loadAssetThrowsInvalidResource() async throws {
        let fakeView = BackgroundVideoUIView()
        let bogusURL = URL(fileURLWithPath: "/dev/null")
        do {
            _ = try await fakeView.loadTestAsset(url: bogusURL)
            XCTFail("Loading an unplayable asset should throw .invalidResource.")
        } catch {
            guard let videoError = error as? VideoPlayerError else {
                XCTFail("Expected VideoPlayerError, got \(error)")
                return
            }
            XCTAssertEqual(videoError, .invalidResource)
        }
    }
    @MainActor
    func test_failedLoadAllowsRetryWithSameResource() async {
        let view = BackgroundVideoUIView()

        // First attempt: load a non-existent resource, which will fail
        view.prepareAndPlayVideo(with: "NonExistent", ofType: "mp4")

        // Wait for the async task to complete
        // The task sets .failed state on error
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(
            view.playerState,
            .failed(VideoPlayerError.resourceNotFound),
            "State should be .failed after loading a non-existent resource."
        )

        // Verify the root cause fix: resource tracking is reset on failure
        XCTAssertNil(
            view.currentResourceName,
            "currentResourceName should be nil after failure so retry is not blocked."
        )
        XCTAssertNil(
            view.currentResourceType,
            "currentResourceType should be nil after failure so retry is not blocked."
        )

        // Second attempt: retry the same resource
        // This should NOT be blocked by the currentResourceName/Type guard
        view.prepareAndPlayVideo(with: "NonExistent", ofType: "mp4")

        XCTAssertEqual(
            view.playerState,
            .loading,
            "Retrying the same resource after failure should transition to .loading, not stay .failed."
        )

        // Cancel the pending task to clean up
        view.cleanupPlayer()
    }
    // MARK: - VideoPlayerState Equatable

    @MainActor
    func test_VideoPlayerState_equalitySameCases() {
        XCTAssertEqual(VideoPlayerState.idle, .idle)
        XCTAssertEqual(VideoPlayerState.loading, .loading)
        XCTAssertEqual(VideoPlayerState.playing, .playing)
        XCTAssertEqual(VideoPlayerState.paused, .paused)
    }

    @MainActor
    func test_VideoPlayerState_failedCasesAreAlwaysEqual() {
        let state1 = VideoPlayerState.failed(VideoPlayerError.resourceNotFound)
        let state2 = VideoPlayerState.failed(VideoPlayerError.invalidResource)
        XCTAssertEqual(state1, state2, ".failed cases should be equal regardless of the associated error.")
    }

    @MainActor
    func test_VideoPlayerState_differentCasesAreNotEqual() {
        XCTAssertNotEqual(VideoPlayerState.idle, .loading)
        XCTAssertNotEqual(VideoPlayerState.playing, .paused)
        XCTAssertNotEqual(VideoPlayerState.idle, .failed(VideoPlayerError.resourceNotFound))
    }

    // MARK: - Cancellation

    @MainActor
    func test_cancelledLoadDoesNotSetFailedState() async {
        let view = BackgroundVideoUIView()
        var states: [VideoPlayerState] = []
        view.stateDidChange = { state in
            states.append(state)
        }

        view.prepareAndPlayVideo(with: "NonExistent", ofType: "mp4")
        XCTAssertEqual(view.playerState, .loading)

        // Immediately cancel via cleanupPlayer
        view.cleanupPlayer()

        // Give the cancelled task time to settle
        try? await Task.sleep(nanoseconds: 500_000_000)

        let hasFailed = states.contains {
            if case .failed = $0 { return true }
            return false
        }
        XCTAssertFalse(hasFailed, "Cancellation should not produce a .failed state.")
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
