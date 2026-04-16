// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MRFileBrowser",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "MRFileBrowser",
            targets: ["MRFileBrowser"]
        )
    ],
    targets: [
        .target(
            name: "MRFileBrowser",
            path: "MRFileBrowser/Sources/MRFileBrowser"
        ),
        .testTarget(
            name: "MRFileBrowserTests",
            dependencies: ["MRFileBrowser"],
            path: "MRFileBrowserTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
