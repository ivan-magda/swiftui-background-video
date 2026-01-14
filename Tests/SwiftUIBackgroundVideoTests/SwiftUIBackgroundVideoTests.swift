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
