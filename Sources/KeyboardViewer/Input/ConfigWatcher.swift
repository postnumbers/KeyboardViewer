import Foundation

/// Calls `onChange` (debounced) when karabiner.json changes.
///
/// Two watches are needed to catch every way the file gets saved:
/// - the directory, for saves that replace the file (Karabiner's own writes,
///   editors with atomic save), which orphan a watch on the old file;
/// - the file itself, for in-place writes, which don't touch the directory.
/// The file watch is re-armed after every event so it follows replacements.
final class ConfigWatcher {
    private let fileURL: URL
    private let onChange: @MainActor () -> Void
    private var directorySource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    init(fileURL: URL, onChange: @escaping @MainActor () -> Void) {
        self.fileURL = fileURL
        self.onChange = onChange
    }

    deinit { stop() }

    func start() {
        directorySource = watch(
            path: fileURL.deletingLastPathComponent().path,
            events: [.write, .rename, .delete]
        )
        armFileWatch()
    }

    func stop() {
        directorySource?.cancel()
        directorySource = nil
        fileSource?.cancel()
        fileSource = nil
        pending?.cancel()
    }

    private func armFileWatch() {
        fileSource?.cancel()
        // resolvingSymlinksInPath so a dotfiles symlink watches the real file.
        fileSource = watch(
            path: fileURL.resolvingSymlinksInPath().path,
            events: [.write, .extend, .rename, .delete]
        )
    }

    private func watch(path: String, events: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: events, queue: .main)
        source.setEventHandler { [weak self] in self?.scheduleReload() }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }

    private func scheduleReload() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.armFileWatch()
            let callback = self.onChange
            Task { @MainActor in callback() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
