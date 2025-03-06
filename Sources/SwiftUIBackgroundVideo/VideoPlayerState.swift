import Foundation

public enum VideoPlayerState {
    case idle
    case loading
    case playing
    case paused
    case failed(Error)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}
