// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyboardViewer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KeyboardViewer",
            path: "Sources/KeyboardViewer"
        )
    ]
)
