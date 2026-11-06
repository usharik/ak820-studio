// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AK820Studio",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AK820Studio", targets: ["AK820Studio"]),
        .executable(name: "ak820ctl", targets: ["ak820ctl"]),
    ],
    targets: [
        .target(name: "AK820Kit", linkerSettings: [.linkedFramework("IOKit")]),
        .executableTarget(name: "AK820Studio", dependencies: ["AK820Kit"]),
        .executableTarget(name: "ak820ctl", dependencies: ["AK820Kit"]),
    ]
)
