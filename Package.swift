// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YouTubeToSlide",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "YouTubeToSlide", targets: ["YouTubeToSlide"])
    ],
    targets: [
        .executableTarget(
            name: "YouTubeToSlide",
            path: "Sources/YouTubeToSlide"
        ),
        .testTarget(
            name: "YouTubeToSlideTests",
            dependencies: ["YouTubeToSlide"],
            path: "Tests/YouTubeToSlideTests"
        )
    ]
)
