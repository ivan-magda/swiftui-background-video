# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

This is an iOS-only package. Use xcodebuild for building and testing.

## Architecture

This is a Swift Package providing a looping background video component for SwiftUI and UIKit iOS apps.

**Key Components:**

- `BackgroundVideoView` - SwiftUI wrapper using `UIViewRepresentable` that delegates to the UIKit implementation
- `BackgroundVideoUIView` - Core UIKit implementation using `AVQueuePlayer` + `AVPlayerLooper` for seamless looping
- `VideoAssetCache` - Singleton `NSCache`-based cache (max 3 assets) with automatic memory warning cleanup
- `VideoPlayerState` - Enum representing player states: idle, loading, playing, paused, failed(Error)
- `VideoPlayerError` - Error types: resourceNotFound, invalidResource, playbackFailed

**Player Lifecycle:**

The UIView handles app lifecycle automatically via NotificationCenter observers:
- Pauses on `didEnterBackground`
- Resumes on `willEnterForeground`
- Handles audio session interruptions

**Asset Loading:**

Assets load asynchronously with iOS 15+ using `asset.load(.isPlayable)` and a fallback for earlier iOS versions using `loadValuesAsynchronously`.

## Package Configuration

- Swift tools version: 6.0
- Swift language mode: 5
- Minimum iOS: 13.0
