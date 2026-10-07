//
//  DockyVersion.swift
//  Docky
//
//  Single source for the running build's version strings.
//

import Foundation

enum DockyVersion {
    static var short: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "?"
    }

    /// e.g. "Docky 0.8.0 (202607010)".
    static var menuHeader: String {
        "Docky \(short) (\(build))"
    }
}
