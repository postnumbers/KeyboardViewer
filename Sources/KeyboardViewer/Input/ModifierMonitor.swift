import AppKit
import CoreGraphics

/// Watches the OS-visible modifiers (⇧ ⌃ ⌥ ⌘ fn) system-wide.
///
/// Two sources, so modifiers still register when the global event monitor
/// gets nothing (permission missing, or granted to an earlier build):
/// - `flagsChanged` event monitors, for an immediate response;
/// - polling the current modifier state 20 times a second. Reading the state
///   doesn't depend on receiving events.
///
/// Changes are debounced: when Karabiner fires a Hyper binding it briefly
/// posts the output's modifiers (e.g. ⌃⌥⇧⌘ for Hyper+W) and temporarily lifts
/// the held ones, which would otherwise make the overlay flicker between layers.
/// After the debounce the live state is read again, so whatever is physically
/// held once things settle is what's shown.
@MainActor
final class ModifierMonitor {
    var onChange: ((Mods) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pollTimer: Timer?
    private var pending: Task<Void, Never>?
    private var current: Mods?
    private var lastPolled: Mods?
    private let debounceNanoseconds: UInt64 = 60_000_000
    private let pollInterval: TimeInterval = 0.05

    func start() {
        // Global monitor: events while another app is frontmost (needs the
        // Device Control and Data Access / Accessibility permission).
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] _ in
            Task { @MainActor in self?.scheduleSettle() }
        }
        // Local monitor: events while the overlay itself is frontmost.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.scheduleSettle() }
            return event
        }
        // Polling fallback.
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        scheduleSettle()
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
        pollTimer?.invalidate()
        pollTimer = nil
        pending?.cancel()
    }

    /// The modifiers held right now, from the combined session state.
    static func liveModifiers() -> Mods {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        var m: Mods = []
        if flags.contains(.maskControl) { m.insert(.control) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        if flags.contains(.maskShift) { m.insert(.shift) }
        if flags.contains(.maskCommand) { m.insert(.command) }
        if flags.contains(.maskSecondaryFn) { m.insert(.fn) }
        return m
    }

    private func poll() {
        let now = Self.liveModifiers()
        guard now != lastPolled else { return }
        lastPolled = now
        scheduleSettle()
    }

    private func scheduleSettle() {
        pending?.cancel()
        pending = Task { [weak self, delay = debounceNanoseconds] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self else { return }
            let settled = Self.liveModifiers()
            guard settled != self.current else { return }
            self.current = settled
            self.onChange?(settled)
        }
    }
}
