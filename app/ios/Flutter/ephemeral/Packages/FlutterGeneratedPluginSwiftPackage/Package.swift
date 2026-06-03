// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "flutter_native_splash", path: "../.packages/flutter_native_splash-2.4.6"),
        .package(name: "webview_flutter_wkwebview", path: "../.packages/webview_flutter_wkwebview-3.25.1"),
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6.3.3"),
        .package(name: "sqflite_darwin", path: "../.packages/sqflite_darwin-2.4.2"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.4"),
        .package(name: "share_plus", path: "../.packages/share_plus-11.0.0"),
        .package(name: "path_provider_foundation", path: "../.packages/path_provider_foundation-2.4.1"),
        .package(name: "sentry_flutter", path: "../.packages/sentry_flutter-9.21.0"),
        .package(name: "package_info_plus", path: "../.packages/package_info_plus-8.3.1"),
        .package(name: "in_app_purchase_storekit", path: "../.packages/in_app_purchase_storekit-0.4.8+1"),
        .package(name: "google_sign_in_ios", path: "../.packages/google_sign_in_ios-5.9.0"),
        .package(name: "gal", path: "../.packages/gal-2.3.2"),
        .package(name: "connectivity_plus", path: "../.packages/connectivity_plus-6.1.4"),
        .package(name: "clarity_flutter", path: "../.packages/clarity_flutter-1.9.0"),
        .package(name: "chottu_link", path: "../.packages/chottu_link-1.1.0"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "flutter-native-splash", package: "flutter_native_splash"),
                .product(name: "webview-flutter-wkwebview", package: "webview_flutter_wkwebview"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "sqflite-darwin", package: "sqflite_darwin"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "path-provider-foundation", package: "path_provider_foundation"),
                .product(name: "sentry-flutter", package: "sentry_flutter"),
                .product(name: "package-info-plus", package: "package_info_plus"),
                .product(name: "in-app-purchase-storekit", package: "in_app_purchase_storekit"),
                .product(name: "google-sign-in-ios", package: "google_sign_in_ios"),
                .product(name: "gal", package: "gal"),
                .product(name: "connectivity-plus", package: "connectivity_plus"),
                .product(name: "clarity-flutter", package: "clarity_flutter"),
                .product(name: "chottu-link", package: "chottu_link"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
