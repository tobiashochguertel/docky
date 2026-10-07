//
//  TileGeometryService.swift
//  Docky
//
//  Records measured icon/label sub-frames per tile for debug tooling.
//  Writes only happen while debug logging is on, so release and
//  normal-debug rendering pay nothing.
//

import CoreGraphics
import Foundation

struct TileSubFrames {
    var icon: CGSize?
    var label: CGSize?
    var painted: CGSize?
}

final class TileGeometryService {
    static let shared = TileGeometryService()

    private let lock = NSLock()
    private var frames: [String: TileSubFrames] = [:]
    private var lastPost = Date.distantPast

    private init() {}

    private var recording: Bool {
        DockyDebugLogging.isEnabled
    }

    func recordIcon(id: String, size: CGSize) {
        guard recording else { return }
        lock.withLock {
            frames[id, default: TileSubFrames()].icon = size
        }
        postThrottled()
    }

    func recordLabel(id: String, size: CGSize) {
        guard recording else { return }
        lock.withLock {
            frames[id, default: TileSubFrames()].label = size
        }
        postThrottled()
    }

    /// Painted visual extent inside the icon slot (folder mosaic,
    /// minimized card, raw icon image). Same gating as the rest.
    func recordPainted(id: String, size: CGSize) {
        guard recording else { return }
        lock.withLock {
            frames[id, default: TileSubFrames()].painted = size
        }
        postThrottled()
    }

    func frames(for id: String) -> TileSubFrames? {
        lock.withLock { frames[id] }
    }

    /// Drops entries for tiles that no longer exist.
    func prune(keeping ids: Set<String>) {
        lock.withLock {
            frames = frames.filter { ids.contains($0.key) }
        }
    }

    /// Nudges the container to re-render (and re-report) once geometry
    /// lands, throttled — geometry callbacks don't invalidate views
    /// themselves since the service isn't observed.
    private func postThrottled() {
        let now = Date()
        let shouldPost: Bool = lock.withLock {
            guard now.timeIntervalSince(lastPost) >= 1 else { return false }
            lastPost = now
            return true
        }
        guard shouldPost else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .tileGeometryUpdated, object: nil)
        }
    }
}

extension Notification.Name {
    static let tileGeometryUpdated = Notification.Name("docky.tileGeometryUpdated")
}
