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
            .accessibilityLabel(text)
    }

    private var labelColor: Color {
        guard let dockColor = preferences.tileLabelColor else {
            return .primary
        }
        return Color(nsColor: dockColor.nsColor)
    }
}

/// Wraps an icon with an optional name label at the shared placement.
/// `label` is `nil` when the surface's toggle is off — renders just the icon.
struct TileLabeledContent<Content: View>: View {
    let label: String?
    let placement: TileLabelPlacement
    let content: Content

    init(label: String?, placement: TileLabelPlacement, @ViewBuilder content: () -> Content) {
        self.label = label
        self.placement = placement
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if let label, !label.isEmpty {
            switch placement {
            case .below:
                VStack(spacing: TileLabelMetrics.spacing) {
                    content
                    TileLabelView(text: label)
                }
            case .above:
                VStack(spacing: TileLabelMetrics.spacing) {
                    TileLabelView(text: label)
                    content
                }
            case .leading:
                HStack(spacing: TileLabelMetrics.spacing) {
                    TileLabelView(text: label)
                    content
                }
            case .trailing:
                HStack(spacing: TileLabelMetrics.spacing) {
                    content
                    TileLabelView(text: label)
                }
            }
        } else {
            content
        }
    }
}

enum TileLabelMetrics {
    /// Gap between the icon and its label.
    static let spacing: CGFloat = 2
    /// Extra height a popover grid cell needs once its label is visible.
    static let popoverLabelHeight: CGFloat = 18
}
