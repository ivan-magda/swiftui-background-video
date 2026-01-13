import AVFoundation
import UIKit

/// A singleton cache for storing loaded video assets.
///
/// This class provides an `NSCache`-backed storage for `AVAsset` instances
/// to avoid repeatedly loading the same video files from disk. The cache
/// automatically clears when the app receives a memory warning.
///
/// The cache is limited to a maximum of 3 assets to balance memory usage
/// with performance benefits.
///
/// ```swift
/// // Retrieve a cached asset
/// if let asset = VideoAssetCache.shared.asset(forKey: "intro.mp4") {
///     // Use cached asset
/// }
///
/// // Store an asset
/// VideoAssetCache.shared.set(asset: loadedAsset, forKey: "intro.mp4")
/// ```
final class VideoAssetCache {
    /// The maximum number of assets to keep in the cache.
    private static let maxCacheSize: Int = 3

    /// The shared singleton instance.
    ///
    /// Use this property to access the cache throughout the app.
    static let shared = VideoAssetCache()

    /// The underlying cache storage.
    private let cache = NSCache<NSString, AVAsset>()

    /// Creates a new cache instance.
    ///
    /// This initializer is private to enforce the singleton pattern.
    /// The cache is configured with a count limit and registers for
    /// memory warning notifications.
    private init() {
        cache.countLimit = Self.maxCacheSize

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Retrieves a cached asset for the specified key.
    ///
    /// The key should be formatted as "resourceName.resourceType"
    /// (e.g., "background.mp4").
    ///
    /// - Parameter key: The cache key identifying the asset.
    /// - Returns: The cached `AVAsset`, or `nil` if not found.
    func asset(forKey key: String) -> AVAsset? {
        cache.object(forKey: key as NSString)
    }

    /// Stores an asset in the cache.
    ///
    /// If the cache is at capacity, the least recently used asset
    /// is automatically evicted.
    ///
    /// - Parameters:
    ///   - asset: The `AVAsset` to cache.
    ///   - key: The cache key identifying the asset.
    func set(asset: AVAsset, forKey key: String) {
        cache.setObject(asset, forKey: key as NSString)
    }

    /// Removes all cached assets.
    ///
    /// Call this method to free memory when video playback is no longer
    /// needed. This method is also called automatically when the app
    /// receives a memory warning.
    func clearCache() {
        cache.removeAllObjects()
    }

    /// Handles memory warning notifications by clearing the cache.
    @objc
    private func handleMemoryWarning() {
        clearCache()
    }
}
