// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Notely",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Notely", path: "Sources/Notely")
    ]
)
