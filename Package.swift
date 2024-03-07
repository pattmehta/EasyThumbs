// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let packageName = "EasyThumbs"

let package = Package(
    name: packageName,
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: packageName,
            targets: [packageName]),
    ],
    targets: [
        .target(name: packageName)
    ]
)
