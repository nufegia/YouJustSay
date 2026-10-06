// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "YouJustSay", platforms: [.macOS(.v14)], products: [.executable(name: "YouJustSay", targets: ["YouJustSay"])], targets: [.executableTarget(name: "YouJustSay", resources: [.process("Resources")]), .testTarget(name: "YouJustSayTests", dependencies: ["YouJustSay"])])
