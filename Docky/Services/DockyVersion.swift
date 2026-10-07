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

    /// Short git SHA baked in at build time (`docky.py build` stamps
    /// `DockyGitSHA` into the bundle; official builds omit it). Includes
    /// a `-dirty` suffix when the worktree had uncommitted changes.
    static var gitSHA: String? {
        guard let sha = Bundle.main.object(forInfoDictionaryKey: "DockyGitSHA") as? String,
              !sha.isEmpty
        else { return nil }
        return sha
    }

    /// e.g. "Docky 0.8.0 (202607010) · a399c20".
    static var menuHeader: String {
        let base = "Docky \(short) (\(build))"
        guard let sha = gitSHA else { return base }
        return "\(base) · \(sha)"
    }
}
