import AVFoundation
import UIKit

final class VideoAssetCache {
    private static let maxCacheSize: Int = 3

    static let shared = VideoAssetCache()

    private let cache = NSCache<NSString, AVAsset>()

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

    func asset(forKey key: String) -> AVAsset? {
        cache.object(forKey: key as NSString)
    }

    func set(asset: AVAsset, forKey key: String) {
        cache.setObject(asset, forKey: key as NSString)
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    @objc
    private func handleMemoryWarning() {
        clearCache()
    }
}
