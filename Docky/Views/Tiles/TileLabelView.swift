//
//  TileLabelView.swift
//  Docky
//
//  Centralized iOS-style name label shown under (or around) tile icons
//  when the user opts in via Appearance > Tile Layout. Shared by the
//  dock (`TileView`) and the app-folder popover (`AppFolderPopoverView`)
//  so both surfaces stay in lockstep.
//

import AppKit
import SwiftUI

/// Where the name label sits relative to its icon. One shared setting
/// drives both the dock and app-folder surfaces.
enum TileLabelPlacement: String, CaseIterable, Codable, Identifiable {
    case below
    case above
    case leading
    case trailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .below: String(localized: "Below")
        case .above: String(localized: "Above")
        case .leading: String(localized: "Leading")
        case .trailing: String(localized: "Trailing")
        }
    }
}

/// iOS-style single-line app name. Fixed small medium-weight type,
/// truncated to the tile width so long names (e.g. "Adobe Photoshop 2026")
/// can't stretch the dock.
struct TileLabelView: View {
    let text: String
    @Bindable private var preferences = DockyPreferences.shared

    var body: some View {
        Text(text)
            .font(.system(size: preferences.tileLabelFontSize, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
            .foregroundStyle(labelColor)
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, TileLabelMetrics.labelSideInset)
            .overlay(
                baselineGuide,
                alignment: Alignment(horizontal: .center, vertical: .firstTextBaseline)
            )
            .accessibilityLabel(text)
    }

    private var labelColor: Color {
        guard let dockColor = preferences.tileLabelColor else {
            return .primary
        }
        return Color(nsColor: dockColor.nsColor)
    }

    /// Yellow text-baseline guide, only while the layout overlay is on.
    @ViewBuilder
    private var baselineGuide: some View {
        if preferences.showsLayoutOverlay {
            Rectangle()
                .fill(Color.yellow)
                .frame(height: 1)
        }
    }
}

/// Resolves the dock label text for a tile. Centralizes the gating so
/// `TileView` (rendering) and `TileContainerView.size` (layout math)
/// agree on exactly which tiles are labeled.
enum TileLabelResolver {
    static func dockText(for tile: Tile, preferences: DockyPreferences) -> String? {
        switch tile.content {
        case .app(let app):
            guard app.displayedWidget == nil,
                  preferences.showsDockTileLabels,
                  !app.displayName.isEmpty
            else { return nil }
            return app.displayName
        case .appFolder(let folder):
            guard preferences.showsDockTileLabels,
                  !folder.displayName.isEmpty
            else { return nil }
            return folder.displayName
        case .launchpad(let launchpad):
            guard preferences.showsDockTileLabels else { return nil }
            return launchpad.title
        case .startMenu(let menu):
            guard preferences.showsDockTileLabels else { return nil }
            return menu.title
        case .folder(let folder):
            guard preferences.showsDockTileLabels else { return nil }
            return folder.displayName
        case .minimizedWindow(let window):
            guard preferences.showsDockTileLabels,
                  !window.windowTitle.isEmpty
            else { return nil }
            return window.windowTitle
        case .trash:
            guard preferences.showsDockTileLabels else { return nil }
            return String(localized: "Trash")
        case .widget, .smartStack, .spacer, .flexibleSpacer, .divider:
            return nil
        }
    }
}

/// Wraps an icon with an optional name label at the shared placement.
/// Above/below labels grow the tile by a uniform reserved row, so every
/// tile's icon, indicator, and label rows line up and icons keep their
/// full size. Sideways labels grow only labeled tiles (heights stay
/// uniform, so rows still align) and the label slot fits its text.
struct TileLabeledContent<Content: View>: View {
    let label: String?
    let placement: TileLabelPlacement
    let content: Content
    /// Tile id for debug geometry recording. When set (and debug
    /// logging is on), the measured icon/label sizes are reported to
    /// `TileGeometryService` so the inspector shows real frames.
    let geometryID: String?
    @Bindable private var preferences = DockyPreferences.shared

    init(
        label: String?,
        placement: TileLabelPlacement,
        geometryID: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.placement = placement
        self.geometryID = geometryID
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if let label, !label.isEmpty {
            switch placement {
            case .below:
                VStack(spacing: TileLabelMetrics.spacing) {
                    measured(content, as: .icon)
                        .border(debugColor(.green))
                    measured(
                        TileLabelView(text: label)
                            .frame(height: labelHeight, alignment: .top),
                        as: .label
                    )
                    .border(debugColor(.yellow))
                }
            case .above:
                VStack(spacing: TileLabelMetrics.spacing) {
                    measured(
                        TileLabelView(text: label)
                            .frame(height: labelHeight, alignment: .bottom),
                        as: .label
                    )
                    .border(debugColor(.yellow))
                    measured(content, as: .icon)
                        .border(debugColor(.green))
                }
            case .leading, .trailing:
                GeometryReader { proxy in
                    HStack(spacing: TileLabelMetrics.spacing) {
                        if placement == .leading {
                            measured(
                                TileLabelView(text: label)
                                    .frame(width: sidewaysSlot),
                                as: .label
                            )
                            .border(debugColor(.yellow))
                        }
                        measured(content, as: .icon)
                            .frame(
                                width: max(0, proxy.size.width - sidewaysSlot - TileLabelMetrics.spacing),
                                height: proxy.size.height
                            )
                            .border(debugColor(.green))
                        if placement == .trailing {
                            measured(
                                TileLabelView(text: label)
                                    .frame(width: sidewaysSlot),
                                as: .label
                            )
                            .border(debugColor(.yellow))
                        }
                    }
                }
            }
        } else if reservesRow {
            // Unlabeled tile in a labeled dock: hold the row with empty
            // space so this tile's icon and indicator rows line up with
            // its labeled neighbors instead of staircasing.
            VStack(spacing: TileLabelMetrics.spacing) {
                if placement == .above {
                    Color.clear.frame(height: labelHeight)
                }
                content
                if placement == .below {
                    Color.clear.frame(height: labelHeight)
                }
            }
        } else {
            content
        }
    }

    /// Only vertical placements reserve a row on unlabeled tiles.
    /// Sideways labels don't affect heights, so rows align without it —
    /// and unlabeled tiles keep their compact width.
    private var reservesRow: Bool {
        preferences.showsDockTileLabels && (placement == .above || placement == .below)
    }

    private var labelHeight: CGFloat {
        TileLabelMetrics.labelHeight(fontSize: preferences.tileLabelFontSize)
    }

    private var sidewaysSlot: CGFloat {
        TileLabelMetrics.sidewaysSlot(
            text: label ?? "",
            fontSize: preferences.tileLabelFontSize
        )
    }

    /// Records the final laid-out size for debug inspection. Passthrough
    /// when no geometry id is set (e.g. popover labels).
    private enum MeasuredKind {
        case icon, label
    }

    @ViewBuilder
    private func measured<V: View>(_ view: V, as kind: MeasuredKind) -> some View {
        if let geometryID {
            view.onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                switch kind {
                case .icon:
                    TileGeometryService.shared.recordIcon(id: geometryID, size: size)
                case .label:
                    TileGeometryService.shared.recordLabel(id: geometryID, size: size)
                }
            }
        } else {
            view
        }
    }

    /// Debug outline color, or clear when the overlay is off so the
    /// modifier stays a visual no-op without branching view types.
    private func debugColor(_ color: Color) -> Color {
        preferences.showsLayoutOverlay ? color : .clear
    }
}

/// Tile sizing constants that are compiled in rather than configurable.
/// The inspector documents these, so they live here with the label
/// metrics they are used alongside.
enum TileLayoutMetrics {
    /// Optical inset of the *chrome* tiles (folder, trash, app folder,
    /// widget, smart stack) inside the tile frame, as a fraction of the
    /// tile's size. App tiles deliberately get 0 here: their icons carry
    /// their own transparent margin, so an extra inset would double it.
    static let chromeInsetFraction: CGFloat = 3.0 / 32.0

    /// Resolved chrome inset for a given tile size.
    static func chromeInset(tileSize: CGFloat) -> CGFloat {
        floor(tileSize * chromeInsetFraction)
    }
}

enum TileLabelMetrics {
    /// Gap between the icon and its label.
    static let spacing: CGFloat = 2
    /// Horizontal inset inside the label frame so neighboring labels
    /// never touch, even at zero tile spacing. The text truncates a
    /// little earlier in exchange for a guaranteed gap.
    static let labelSideInset: CGFloat = 2
    /// Optical margin around the app-folder tile visual, as a fraction
    /// of the tile's smaller side. Folder backgrounds otherwise bleed to
    /// the tile edge while app icons carry natural transparent margins.
    static let folderChromeMarginFraction: CGFloat = 0.06

    /// Height of the label text itself for a given point size.
    static func labelHeight(fontSize: CGFloat) -> CGFloat {
        ceil(fontSize * 1.2)
    }

    /// Full row a label occupies: text plus the icon gap.
    static func rowHeight(fontSize: CGFloat) -> CGFloat {
        labelHeight(fontSize: fontSize) + spacing
    }

    /// Width slot for a sideways (leading/trailing) label: just wide
    /// enough for its text, capped so one long name can't stretch the
    /// dock. Must match what `TileContainerView.size` adds to the tile,
    /// both call this.
    static let maxSidewaysLabelWidth: CGFloat = 96

    static func sidewaysSlot(text: String, fontSize: CGFloat) -> CGFloat {
        let measured = (text as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
        ]).width
        return min(ceil(measured), maxSidewaysLabelWidth)
    }

    /// Uniform row every dock tile reserves when dock labels are on.
    /// Uniformity is what keeps icon rows, indicator rows, and label
    /// rows aligned across tile types (apps, folders, widgets alike) —
    /// labeled or not, each tile grows by exactly this amount and icons
    /// stay at their full size instead of shrinking.
    static func dockRowAddition() -> CGFloat {
        let preferences = DockyPreferences.shared
        guard preferences.showsDockTileLabels else { return 0 }
        return rowHeight(fontSize: preferences.tileLabelFontSize)
    }
}
