import AppKit
import ApplicationServices
import Combine
import SwiftUI

/// Wires the pieces together: config → index, Karabiner messages → Hyper
/// state, modifier monitor → held modifiers, state → panel visibility.
@MainActor
final class AppController {
    // nonisolated: plain constants, used from property initializers and views.
    // Keeps its original name (from when the app was "Hyper Overlay") so
    // existing karabiner.json rules that send to it keep working.
    nonisolated static let socketPath = "/tmp/hyper-overlay.sock"
    nonisolated static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/karabiner", isDirectory: true)
    nonisolated static let configURL = configDirectory.appendingPathComponent("karabiner.json")

    /// How long Hyper must be held before the overlay pops up, so a quick
    /// Caps Lock tap (which Karabiner turns into Escape) doesn't flash it.
    private let hyperShowDelayNanoseconds: UInt64 = 180_000_000
    /// How long ⌘ ⌥ ⌃ must be held before the overlay pops up (when "Show
    /// While ⌘ ⌥ ⌃ Are Held" is on), so ordinary shortcuts don't flash it.
    private let modifierShowDelayNanoseconds: UInt64 = 600_000_000

    /// Built-in shortcuts, independent of Karabiner. None of the ⌃⌥⇧ letter
    /// combinations are sent by the Karabiner rules this app was built around.
    nonisolated static let pinShortcut = GlobalHotKeys.Shortcut(keyCode: 0x28, modifiers: [.control, .option, .shift])          // ⌃⌥⇧K
    nonisolated static let appShortcutsShortcut = GlobalHotKeys.Shortcut(keyCode: 0x25, modifiers: [.control, .option, .shift]) // ⌃⌥⇧L
    private let hotKeys = GlobalHotKeys()

    let state = OverlayState()
    private lazy var panel: OverlayPanel = {
        // Measure the keyboard at scale 1; the panel uses it as its default
        // size and aspect ratio.
        let naturalSize = NSHostingView(rootView: KeyboardContent(state: state, scale: 1)).fittingSize
        let panel = OverlayPanel(rootView: KeyboardView(state: state), naturalSize: naturalSize)
        panel.onPinToggle = { [weak self] in self?.togglePinned() }
        return panel
    }()
    private let modifierMonitor = ModifierMonitor()
    private let receiver = UserCommandReceiver(path: AppController.socketPath)
    private var configWatcher: ConfigWatcher?
    private var showTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // Frontmost-app menu shortcuts
    private var keyMap = KeyCharacterMap()
    private var menuReadTask: Task<Void, Never>?
    private var lastMenuRead: (pid: pid_t, at: Date)?
    private var observers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []

    func start() {
        requestAccessibilityIfNeeded()
        reloadConfig()

        modifierMonitor.onChange = { [weak self] mods in
            self?.state.heldMods = mods
        }
        modifierMonitor.start()

        receiver.onMessage = { [weak self] message in
            self?.handle(message)
        }
        do {
            try receiver.start()
        } catch {
            state.statusMessage = "Can't listen for Karabiner: \(error.localizedDescription)"
        }

        configWatcher = ConfigWatcher(fileURL: Self.configURL) { [weak self] in
            self?.reloadConfig()
        }
        configWatcher?.start()

        startSystemShortcuts()

        // Re-evaluate visibility whenever anything it depends on changes.
        // @Published emits before the property changes; delivering on the
        // main queue runs the check after the new values are in place.
        Publishers.MergeMany(
            state.$pinned.map { _ in () }.eraseToAnyPublisher(),
            state.$hyperHeld.map { _ in () }.eraseToAnyPublisher(),
            state.$heldMods.map { _ in () }.eraseToAnyPublisher(),
            state.$autoShowOnHyper.map { _ in () }.eraseToAnyPublisher(),
            state.$showWhileModifiersHeld.map { _ in () }.eraseToAnyPublisher(),
            state.$appShortcutsEnabled.map { _ in () }.eraseToAnyPublisher(),
            state.$karabinerAvailable.map { _ in () }.eraseToAnyPublisher(),
            state.$index.map { _ in () }.eraseToAnyPublisher()   // a Hyper key added or removed
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.refreshVisibility() }
        .store(in: &cancellables)

        // Built-in shortcuts: (re)register when switched on or off.
        state.$builtInShortcutsEnabled
            .sink { [weak self] enabled in self?.applyBuiltInShortcuts(enabled) }
            .store(in: &cancellables)
    }

    func stop() {
        modifierMonitor.stop()
        receiver.stop()
        configWatcher?.stop()
        menuReadTask?.cancel()
        hotKeys.unregisterAll()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        distributedObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }

    // MARK: - System, app and character shortcuts

    private func startSystemShortcuts() {
        reloadKeyboardLayout()
        state.systemShortcuts = SystemShortcuts.read()

        // Hyperkey and similar apps launched or quit: relabel Caps Lock.
        state.hyperKeyApp = HyperKeyApps.running()
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.state.hyperKeyApp = HyperKeyApps.running() }
            })
        }

        // A different app became frontmost: read its menus.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in self?.readMenus(of: app) }
        })

        // Keyboard layout changed: characters and key positions change with it.
        distributedObservers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reloadKeyboardLayout() }
        })

        // "Use F1, F2, etc. keys as standard function keys" switched.
        distributedObservers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.keyboard.fnstatedidchange"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.state.standardFunctionKeys = FunctionKeys.standardFunctionKeys() }
        })

        // Shortcuts edited in System Settings.
        distributedObservers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.symbolichotkeys.changed"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.state.systemShortcuts = SystemShortcuts.read() }
        })

        // Holding modifiers without Hyper shows the app's shortcuts; refresh
        // them if they're more than a few seconds old, since menus change.
        state.$heldMods
            .combineLatest(state.$hyperHeld)
            .sink { [weak self] mods, hyper in
                guard let self, !hyper, !mods.isEmpty else { return }
                if let last = self.lastMenuRead, Date().timeIntervalSince(last.at) < 5 { return }
                self.readMenus(of: NSWorkspace.shared.frontmostApplication)
            }
            .store(in: &cancellables)

        // Switched back on: read the current app's menus straight away.
        state.$appShortcutsEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard enabled, let self else { return }
                // @Published emits before the change lands; read on the next turn.
                Task { @MainActor in
                    self.lastMenuRead = nil
                    self.readMenus(of: NSWorkspace.shared.frontmostApplication)
                }
            }
            .store(in: &cancellables)

        readMenus(of: NSWorkspace.shared.frontmostApplication)
    }

    private func reloadKeyboardLayout() {
        state.standardFunctionKeys = FunctionKeys.standardFunctionKeys()
        keyMap = KeyboardLayoutReader.characterMap()
        state.optionCharacters = KeyboardLayoutReader.optionCharacterBindings()
        state.typedCharacters = KeyboardLayoutReader.typedCharacterBindings()
        lastMenuRead = nil   // menu shortcuts are placed using the layout
        readMenus(of: NSWorkspace.shared.frontmostApplication)
    }

    private func readMenus(of app: NSRunningApplication?) {
        guard state.appShortcutsActive,
              let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        let pid = app.processIdentifier
        let bundleID = app.bundleIdentifier
        let name = app.localizedName ?? "App"
        let keys = keyMap
        lastMenuRead = (pid, Date())

        menuReadTask?.cancel()
        menuReadTask = Task { [weak self] in
            // Reading a big app's menus takes a moment; do it off the main thread.
            // An app that's busy as it comes to the front may not answer, or
            // may still be building its menus, so try again a few times.
            var result: Result<MenuShortcutReader.Report, MenuShortcutReader.Failure> = .failure(.noMenuBar(0))
            for delay: UInt64 in [0, 400_000_000, 1_200_000_000] {
                if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
                guard !Task.isCancelled else { return }
                result = await Task.detached(priority: .utility) {
                    MenuShortcutReader.read(pid: pid, appName: name, keys: keys)
                }.value
                let done: Bool
                switch result {
                case .success(let report): done = !report.bindings.isEmpty
                case .failure(.notTrusted): done = true
                case .failure(.noMenuBar): done = false
                }
                if done { break }
            }
            guard !Task.isCancelled, let self else { return }
            self.state.frontAppName = name
            // Shortcuts set in System Settings come first: they replace the
            // app's own, and also cover submenus that can't be read.
            let custom = UserKeyEquivalents.bindings(bundleID: bundleID, appName: name, keys: keys)
            switch result {
            case .success(let report):
                self.state.appShortcuts = custom + report.bindings
                self.state.appShortcutsNote = report.summary(appName: name)
            case .failure(.notTrusted):
                self.state.appShortcuts = custom
                self.state.appShortcutsNote = "Menu shortcuts need Device Control and Data Access permission"
            case .failure(.noMenuBar(let code)):
                self.state.appShortcuts = custom
                // Apps without a menu bar (menu bar extras) report "no value";
                // anything else means the app didn't answer properly.
                let noMenuBar = [AXError.noValue.rawValue, AXError.attributeUnsupported.rawValue]
                self.state.appShortcutsNote = noMenuBar.contains(code)
                    ? nil : "\(name) didn't hand over its menus (AX error \(code))"
            }
        }
    }

    func reloadConfig() {
        // No karabiner.json: run as an app and system shortcut viewer.
        guard FileManager.default.fileExists(atPath: Self.configURL.path) else {
            state.index = BindingIndex()
            state.karabinerAvailable = false
            if state.statusMessage?.hasPrefix("Config:") == true {
                state.statusMessage = nil
            }
            return
        }
        state.karabinerAvailable = true
        do {
            let config = try KarabinerConfig.load(from: Self.configURL)
            state.index = BindingIndex.build(from: config)
            if state.statusMessage?.hasPrefix("Config:") == true {
                state.statusMessage = nil
            }
        } catch {
            // Keep the last good index; Karabiner may be mid-write.
            state.statusMessage = "Config: \(error.localizedDescription)"
        }
    }

    func togglePinned() {
        state.pinned.toggle()
    }

    func toggleAppShortcuts() {
        state.appShortcutsEnabled.toggle()
    }

    /// Restores the default size and position, and shows the panel so the
    /// result is visible.
    func resetPanelFrame() {
        panel.resetFrame()
        state.pinned = true
    }

    // MARK: - Messages from Karabiner

    private func handle(_ message: UserCommandReceiver.Message) {
        switch message {
        case .hyper(let down):
            state.hyperHeld = down
        case .command("toggle"):
            togglePinned()
        case .command("show"):
            state.pinned = true
        case .command("hide"):
            state.pinned = false
        case .command("reload"):
            reloadConfig()
        case .command("app-shortcuts"):
            toggleAppShortcuts()
        case .command:
            break
        }
    }

    // MARK: - Visibility

    /// Shown when pinned; while Hyper is held (after a short delay); and,
    /// if that option is on, while ⌘ ⌥ ⌃ are held (after a longer delay).
    private func refreshVisibility() {
        panel.showPinned(state.pinned)

        if state.pinned {
            showTask?.cancel()
            panel.present()
            return
        }

        guard let delay = showDelay() else {
            showTask?.cancel()
            showTask = nil
            panel.dismiss()
            return
        }

        // Already up, or about to be: leave it, so adding a modifier while
        // holding doesn't restart the delay.
        if panel.isVisible || showTask != nil { return }

        showTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            // A cancelled task must not clear a newer task's reference.
            guard !Task.isCancelled, let self else { return }
            self.showTask = nil
            guard self.showDelay() != nil else { return }
            self.panel.present()
        }
    }

    /// How long to wait before showing, or nil if the window shouldn't show.
    private func showDelay() -> UInt64? {
        if state.hyperHeld && state.autoShowOnHyper {
            return hyperShowDelayNanoseconds
        }
        // ⇧ alone doesn't count, or the window would appear while typing capitals.
        let triggering = state.heldMods.subtracting([.shift, .fn])
        if state.showWhileModifiersHeld && state.appShortcutsActive && !state.hyperHeld && !triggering.isEmpty {
            return modifierShowDelayNanoseconds
        }
        return nil
    }

    // MARK: - Built-in shortcuts

    private func applyBuiltInShortcuts(_ enabled: Bool) {
        hotKeys.unregisterAll()
        if state.statusMessage?.hasPrefix("Shortcut:") == true { state.statusMessage = nil }
        guard enabled else { return }

        var taken: [String] = []
        if !hotKeys.register(Self.pinShortcut, action: { [weak self] in
            Task { @MainActor in self?.togglePinned() }
        }) { taken.append(Self.pinShortcut.display) }
        if !hotKeys.register(Self.appShortcutsShortcut, action: { [weak self] in
            Task { @MainActor in self?.toggleAppShortcuts() }
        }) { taken.append(Self.appShortcutsShortcut.display) }

        if !taken.isEmpty {
            state.statusMessage = "Shortcut: \(taken.joined(separator: ", ")) is already used by another app"
        }
    }

    // MARK: - Permissions

    private func requestAccessibilityIfNeeded() {
        // The value of kAXTrustedCheckOptionPrompt; its Swift import type has
        // changed between SDKs, so the string is used directly.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            // macOS 27 renamed the "Accessibility" pane to "Device Control and Data Access".
            state.statusMessage = "Allow KeyboardViewer in Privacy & Security › Device Control and Data Access (Accessibility before macOS 27), then relaunch."
        }
    }
}
