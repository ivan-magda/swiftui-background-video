import Foundation

public enum VideoPlayerState {
    case idle
    case loading
    case playing
    case paused
    case failed(Error)
}
