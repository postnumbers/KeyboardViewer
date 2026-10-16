import Foundation

/// A UNIX domain datagram server that receives Karabiner `send_user_command`
/// payloads. Karabiner sends each payload as JSON-serialized data.
///
/// Messages the overlay understands:
///   {"hyper": true} / {"hyper": false}         Hyper pressed / released
///   {"command": "toggle" | "show" | "hide" | "reload"}
final class UserCommandReceiver {
    enum Message {
        case hyper(Bool)
        case command(String)
    }

    let path: String
    var onMessage: (@MainActor (Message) -> Void)?

    private var fd: Int32 = -1
    private var source: DispatchSourceRead?

    init(path: String) {
        self.path = path
    }

    deinit { stop() }

    func start() throws {
        unlink(path) // remove a stale socket from a previous run

        fd = socket(AF_UNIX, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw SocketError.posix("socket") }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard path.utf8.count < capacity else { throw SocketError.pathTooLong(path) }
        withUnsafeMutablePointer(to: &addr.sun_path) { tuple in
            tuple.withMemoryRebound(to: CChar.self, capacity: capacity) { buffer in
                _ = path.withCString { strncpy(buffer, $0, capacity - 1) }
            }
        }

        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, length) }
        }
        guard result == 0 else {
            close(fd)
            fd = -1
            throw SocketError.posix("bind \(path)")
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .userInteractive))
        source.setEventHandler { [weak self] in self?.readDatagram() }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
        if fd >= 0 {
            close(fd)
            fd = -1
            unlink(path)
        }
    }

    private func readDatagram() {
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let count = recv(fd, &buffer, buffer.count, 0)
        guard count > 0 else { return }
        let data = Data(buffer[0..<count])
        guard let message = Self.parse(data) else { return }
        let handler = onMessage
        Task { @MainActor in handler?(message) }
    }

    static func parse(_ data: Data) -> Message? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        if let dict = json as? [String: Any] {
            if let hyper = dict["hyper"] as? Bool { return .hyper(hyper) }
            if let command = dict["command"] as? String { return .command(command) }
        }
        if let command = json as? String { return .command(command) }
        return nil
    }

    enum SocketError: LocalizedError {
        case posix(String)
        case pathTooLong(String)

        var errorDescription: String? {
            switch self {
            case .posix(let call): return "\(call) failed: \(String(cString: strerror(errno)))"
            case .pathTooLong(let path): return "Socket path is too long: \(path)"
            }
        }
    }
}
