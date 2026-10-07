//
//  DebugSettingsView.swift
//  Docky
//

import SwiftUI

struct DebugSettingsView: View {
    @Bindable private var preferences = DockyPreferences.shared
    @State private var loggingEnabled = DockyDebugLogging.isEnabled

    var body: some View {
        Form {
            Section("Logging") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Write Debug Log File", isOn: $loggingEnabled)
                        .font(.headline)
                        .onChange(of: loggingEnabled) { enabled in
                            DockyDebugLogging.isEnabled = enabled
                        }

                    Text("Appends diagnostics to ~/Library/Logs/Docky/docky-debug.log, including per-tile geometry whenever the dock layout changes. Takes effect immediately, no restart needed.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button("Reveal in Finder") {
                            DockyDebugService.shared.revealInFinder()
                        }

                        Button("Clear Log", role: .destructive) {
                            DockyDebugService.shared.clearLog()
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Layout Overlay") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show Technical Overlay", isOn: $preferences.showsLayoutOverlay)
                        .font(.headline)

                    Text("Paints a cyan frame plus a readout (rendered size, vertical and icon padding, resolved label) over every dock tile. Updates live.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loggingEnabled = DockyDebugLogging.isEnabled
        }
    }
}
