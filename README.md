# SwiftUIBackgroundVideo

[![Swift](https://img.shields.io/badge/Swift-5.5+-orange?style=flat-square)](https://img.shields.io/badge/Swift-5.5+-orange?style=flat-square)
[![Platforms](https://img.shields.io/badge/Platforms-iOS-yellowgreen?style=flat-square)](https://img.shields.io/badge/Platforms-iOS-green?style=flat-square)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)

A Swift package for easily adding looping background videos to your iOS apps with SwiftUI.

## Features

- Simple SwiftUI integration
- Asset caching for improved performance
- Automatic lifecycle management (app background/foreground)
- Proper audio session handling
- Memory management with auto-cleanup

## Requirements

- iOS 13.0+
- Swift 5.5+

## Installation

### Swift Package Manager

Add SwiftUIBackgroundVideo to your project by adding it as a dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/ivan-magda/swiftui-background-video.git", from: "1.0.0")
]
```

Or add it directly through Xcode:
1. Go to File > Add Packages...
2. Enter package repository URL: `https://github.com/ivan-magda/swiftui-background-video.git`
3. Click "Add Package"

## Usage

### SwiftUI

```swift
import SwiftUI
import SwiftUIBackgroundVideo

struct ContentView: View {
    var body: some View {
        ZStack {
            BackgroundVideoView(
                resourceName: "background_video", 
                resourceType: "mp4"
            )
            
            VStack {
                Text("Hello, World!")
                    .foregroundColor(.white)
                    .font(.largeTitle)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
            }
        }
    }
}
```

### UIKit

```swift
import UIKit
import SwiftUIBackgroundVideo

class ViewController: UIViewController {
    
    private var videoView: BackgroundVideoUIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create and add the video view
        videoView = BackgroundVideoUIView( 
            resourceName: "background_video", 
            resourceType: "mp4"
        )
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(videoView)
        
        // Monitor state changes if needed
        videoView.stateDidChange = { state in
            print("Video state changed to: \(state)")
        }
        
        // Add content on top
        let label = UILabel()
        label.text = "Hello, World!"
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40)
        ])
    }
}
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
