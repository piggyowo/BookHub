// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StudyCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "StudyCore", targets: ["StudyCore"])],
    targets: [.target(name: "StudyCore", path: "Core"), .testTarget(name: "StudyCoreTests", dependencies: ["StudyCore"])]
)
