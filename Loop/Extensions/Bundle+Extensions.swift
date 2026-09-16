//
//  Bundle+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import Foundation

extension Bundle {
    static let personalTestBundleIdentifier = "com.tenda96.LoopAdjacentTest"

    var isPersonalTestBuild: Bool {
        bundleID == Self.personalTestBundleIdentifier
    }

    var appName: String {
        getInfo("CFBundleName") ?? "⚠️"
    }

    var displayName: String {
        getInfo("CFBundleDisplayName") ?? "⚠️"
    }

    var bundleID: String {
        getInfo("CFBundleIdentifier") ?? Bundle.main.bundleIdentifier ?? "com.MrKai77.loop"
    }

    var copyright: String {
        getInfo("NSHumanReadableCopyright") ?? "⚠️"
    }

    var appBuild: Int? {
        Int(getInfo("CFBundleVersion") ?? "")
    }

    var appVersion: String? {
        getInfo("CFBundleShortVersionString")
    }

    var bundleURL: URL {
        URL(fileURLWithPath: bundlePath)
    }

    func getInfo(_ str: String) -> String? {
        infoDictionary?[str] as? String
    }
}
