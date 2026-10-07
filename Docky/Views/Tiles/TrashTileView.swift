//
//  TrashTileView.swift
//  Docky
//

import AppKit
import SwiftUI

struct TrashTileView: View {
    var isDropTarget: Bool = false
    var debugGeometryID: String? = nil
    @ObservedObject private var trash = TrashService.shared
    @Bindable private var preferences = DockyPreferences.shared

    var body: some View {
        GeometryReader { proxy in
            debugPaint(
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(overridePadding(in: proxy.size))
                    .brightness(isDropTarget ? -0.35 : 0)
                    .scaleEffect(isDropTarget ? 1.1 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDropTarget)
            )
        }
    }

    private func overridePadding(in size: CGSize) -> CGFloat {
        let state: TrashIconState = trash.isEmpty ? .empty : .full
        guard preferences.effectiveTrashIconOverrideURL(forState: state) != nil else {
            return 0
        }
        return preferences.trashIconOverridePadding(forState: state) * min(size.width, size.height)
    }

    private var icon: NSImage {
        let state: TrashIconState = trash.isEmpty ? .empty : .full

        if let overrideURL = preferences.effectiveTrashIconOverrideURL(forState: state),
           let overrideImage = IconCacheService.shared.image(forImageFileURL: overrideURL) {
            return overrideImage
        }

        return NSImage(named: state.systemImageName)
            ?? NSImage(named: TrashIconState.empty.systemImageName)
            ?? NSImage()
    }

    /// Records the painted icon extent for debug inspection.
    @ViewBuilder
    private func debugPaint<V: View>(_ view: V) -> some View {
        if let debugGeometryID {
            view.onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                TileGeometryService.shared.recordPainted(id: debugGeometryID, size: size)
            }
        } else {
            view
        }
    }
}
