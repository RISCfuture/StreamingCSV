// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "StreamingCSV",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
    .tvOS(.v16),
    .watchOS(.v9),
    .visionOS(.v1),
    .macCatalyst(.v16)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "StreamingCSV",
      targets: ["StreamingCSV"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.1"),
    .package(url: "https://github.com/stackotter/swift-macro-toolkit", from: "0.6.1"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3")
  ],
  targets: [
    // Macro implementation
    .macro(
      name: "StreamingCSVMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "MacroToolkit", package: "swift-macro-toolkit")
      ]
    ),
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "StreamingCSV",
      dependencies: [
        "StreamingCSVMacros"
      ],
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "StreamingCSVTests",
      dependencies: ["StreamingCSV"],
      resources: [.copy("Fixtures")]
    )
  ],
  swiftLanguageModes: [.v6]
)
