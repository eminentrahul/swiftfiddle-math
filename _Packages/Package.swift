// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "_Packages",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "_Packages", type: .dynamic, targets: ["_Packages"]),
    ],
    dependencies: [
        .package(url: "https://github.com/taketo1024/swm-core.git", from:"1.2.8"),
        .package(url: "https://github.com/taketo1024/swm-homology.git", from: "1.3.3"),
        .package(url: "https://github.com/taketo1024/swm-khovanov.git", from: "1.1.6"),
        .package(url: "https://github.com/taketo1024/swm-knots.git", from: "1.2.0"),
        .package(url: "https://github.com/taketo1024/swm-kr.git", from: "0.4.3"),
    ],
    targets: [
        .target(
            name: "_Packages",
            dependencies: [
                .product(name: "SwmCore", package: "swm-core"),
                .product(name: "SwmHomology", package: "swm-homology"),
                .product(name: "SwmKhovanov", package: "swm-khovanov"),
                .product(name: "SwmKnots", package: "swm-knots"),
                .product(name: "SwmKR", package: "swm-kr"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
    ]
)
