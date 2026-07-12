// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "claude-usage-bar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "claude-usage-bar",
            path: "Sources/ClaudeUsageBar"
        )
    ]
)
