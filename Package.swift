// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftUIBackgroundVideo",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftUIBackgroundVideo",
            targets: ["SwiftUIBackgroundVideo"]
        )
    ],
    targets: [
        .target(
            name: "SwiftUIBackgroundVideo"
        ),
        .testTarget(
            name: "SwiftUIBackgroundVideoTests",
            dependencies: ["SwiftUIBackgroundVideo"]
        )
    ],
    swiftLanguageModes: [.v5]
)
