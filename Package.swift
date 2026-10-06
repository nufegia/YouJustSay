// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "YouJustSay",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "YouJustSay", targets: ["YouJustSay"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .executableTarget(name: "YouJustSay", dependencies: [.product(name: "Sparkle", package: "Sparkle")], resources: [.process("Resources")], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "YouJustSayTests", dependencies: ["YouJustSay"])
    ]
)
