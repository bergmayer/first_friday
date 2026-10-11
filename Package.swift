// swift-tools-version: 6.0
import PackageDescription

// Test the Apple TV networking and metadata code on macOS without a simulator.
let package = Package(
    name: "FirstFridayCore",
    platforms: [.macOS(.v14)],
    dependencies: [.package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")],
    targets: [
        .target(name: "FirstFridayCore", dependencies: [.product(name: "Yams", package: "Yams")],
                path: "first_friday", exclude: [".DS_Store", "AppSettings.swift", "Assets.xcassets", "AudioPlayer.swift", "BuiltinArt", "BuiltinPaintings.swift", "ContentView.swift", "CoolStationPickerView.swift", "CoolStations.swift", "FilenameView.swift", "ImageIndex.swift", "Info.plist", "Keychain.swift", "SettingsView.swift", "SlideshowView.swift", "first_fridayApp.swift"]),
        .testTarget(name: "FirstFridayCoreTests", dependencies: ["FirstFridayCore"], path: "Tests")
    ]
)
