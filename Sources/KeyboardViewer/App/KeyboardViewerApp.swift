import AppKit
import SwiftUI

@main
struct KeyboardViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("KeyboardViewer", systemImage: "keyboard") {
            MenuContent(controller: appDelegate.controller, state: appDelegate.controller.state)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon, no app switcher entry.
        // (The bundled .app also sets LSUIElement; this covers `swift run`.)
        NSApp.setActivationPolicy(.accessory)
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }
}

private struct MenuContent: View {
    let controller: AppController
    @ObservedObject var state: OverlayState

    var body: some View {
        Toggle(label("Pin Keyboard", AppController.pinShortcut, hyper: "Hyper /"), isOn: $state.pinned)
        Toggle(label("Show App & System Shortcuts", AppController.appShortcutsShortcut, hyper: "Hyper ⇧ /"),
               isOn: $state.appShortcutsEnabled)
            .disabled(!state.hyperAvailable)   // always on without a Hyper key

        Divider()

        Toggle("Show While ⌘ ⌥ ⌃ Are Held", isOn: $state.showWhileModifiersHeld)
        Toggle("Show While Hyper Is Held", isOn: $state.autoShowOnHyper)
            .disabled(!state.hyperAvailable)
        Picker("Caps Lock Label", selection: $state.capsLockLabel) {
            ForEach(CapsLockLabel.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        Toggle("Built-in Shortcuts (\(AppController.pinShortcut.display), \(AppController.appShortcutsShortcut.display))",
               isOn: $state.builtInShortcutsEnabled)
        Button("Reset Size and Position") { controller.resetPanelFrame() }

        Divider()

        Button("Open Permission Settings…") {
            // Opens "Device Control and Data Access" on macOS 27, "Accessibility" before.
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        // Always available, so installing Karabiner later is picked up.
        Button("Reload karabiner.json") { controller.reloadConfig() }
        if state.karabinerAvailable {
            Button("Open karabiner.json") {
                NSWorkspace.shared.open(AppController.configURL)
            }
        }

        if let message = state.statusMessage {
            Divider()
            Text(message)
        }
        if let note = state.appShortcutsNote {
            Divider()
            Text(note)   // why the frontmost app's menu shortcuts are missing
        }

        Divider()

        Button("Quit KeyboardViewer") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// "Pin Keyboard    ⌃⌥⇧K · Hyper /" — lists the shortcuts that are active.
    private func label(_ title: String, _ shortcut: GlobalHotKeys.Shortcut, hyper: String) -> String {
        var keys: [String] = []
        if state.builtInShortcutsEnabled { keys.append(shortcut.display) }
        if state.hyperAvailable { keys.append(hyper) }
        return keys.isEmpty ? title : "\(title)    \(keys.joined(separator: " · "))"
    }
}
