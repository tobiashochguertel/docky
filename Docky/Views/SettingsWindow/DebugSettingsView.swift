//
//  DebugSettingsView.swift
//  Docky
//

import SwiftUI

struct DebugSettingsView: View {
    @Bindable private var preferences = DockyPreferences.shared
    @State private var loggingEnabled = DockyDebugLogging.isEnabled
    @State private var isRecordingShortcut = false

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

                    Text("Paints a blue tile frame, green icon bounds, and yellow label bounds with a baseline guide over every dock tile, plus a metric readout. Updates live.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ShortcutRecorderControl(
                        shortcut: preferences.debugOverlayShortcut,
                        isRecording: $isRecordingShortcut,
                        resetShortcut: KeyboardShortcut(keyCode: 2, modifierFlags: [.command, .option])
                    ) { shortcut in
                        preferences.debugOverlayShortcut = shortcut
                    }

                    Text("Global shortcut that toggles the overlay from anywhere, even while Docky's panel never holds keyboard focus. Clear it to disable the hotkey.")
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
