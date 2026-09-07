// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ListExcel",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "ListExcel", targets: ["ListExcel"])
    ],
    targets: [
        .target(
            name: "ListExcel",
            path: "Sources/ListExcel",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ListExcelTests",
            dependencies: ["ListExcel"],
            path: "Tests/ListExcelTests"
        )
    ]
)
