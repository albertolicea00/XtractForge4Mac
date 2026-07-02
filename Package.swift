// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "XtractForge",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: models, downloaders, engine. No SwiftUI.
        .target(name: "XtractForgeCore", path: "Sources/XtractForgeCore"),
        // The app: SwiftUI views + @main entry point.
        .executableTarget(
            name: "XtractForge",
            dependencies: ["XtractForgeCore"],
            path: "Sources/XtractForge"
        ),
        .testTarget(
            name: "XtractForgeCoreTests",
            dependencies: ["XtractForgeCore"],
            path: "Tests/XtractForgeCoreTests"
        ),
    ]
)
