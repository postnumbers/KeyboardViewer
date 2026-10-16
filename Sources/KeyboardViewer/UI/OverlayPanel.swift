import AppKit
import SwiftUI

/// A floating panel that never takes keyboard focus, so it can sit over
/// whatever you're working in while you hold modifiers.
///
/// It's a titled window with the title bar hidden: that gives native resize
/// edges and rounded corners. Drag it from anywhere; resize it from any edge
/// or corner. It keeps the keyboard's aspect ratio, and its size and position
/// are remembered between launches.
final class OverlayPanel: NSPanel {
    // Bumped whenever the keyboard's proportions change, so a saved frame
    // with the old aspect ratio isn't restored.
    private static let frameName = "KeyboardViewerPanel"

    /// The keyboard's size at scale 1.
    private let naturalSize: NSSize
    private let container: DragContainerView

    /// Called when the pin button on the window is clicked.
    var onPinToggle: (() -> Void)? {
        get { container.onPinToggle }
        set { container.onPinToggle = newValue }
    }

    init<Content: View>(rootView: Content, naturalSize: NSSize) {
        self.naturalSize = naturalSize
        let host = NSHostingView(rootView: rootView)
        host.sizingOptions = []   // the window sets the size, not the SwiftUI content
        self.container = DragContainerView(content: host)
        super.init(
            contentRect: NSRect(origin: .zero, size: naturalSize),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        // Hide the title bar but keep the frame that makes edges resizable.
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false

        contentAspectRatio = naturalSize
        contentMinSize = NSSize(width: naturalSize.width * 0.45, height: naturalSize.height * 0.45)
        contentMaxSize = NSSize(width: naturalSize.width * 2.5, height: naturalSize.height * 2.5)

        contentView = container
        setContentSize(naturalSize)

        if !setFrameUsingName(Self.frameName) {
            placeAtBottomCenter()
        }
        setFrameAutosaveName(Self.frameName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("OverlayPanel is created in code")
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present() {
        guard !isVisible else { return }
        orderFrontRegardless()
    }

    func dismiss() {
        guard isVisible else { return }
        orderOut(nil)
    }

    /// Updates the pin button to match the pinned state.
    func showPinned(_ pinned: Bool) {
        container.setPinned(pinned)
    }

    /// Back to the natural size, centred near the bottom of the main screen.
    func resetFrame() {
        setContentSize(naturalSize)
        placeAtBottomCenter()
        saveFrame(usingName: Self.frameName)
    }

    private func placeAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - frame.width / 2,
            y: visible.minY + 40
        )
        setFrameOrigin(origin)
    }
}

/// Wraps the SwiftUI view so a click anywhere drags the window, and draws
/// the pin button in the top-right corner.
///
/// SwiftUI's hosting view takes mouse-downs itself, so dragging the
/// background wouldn't move the window. This view claims clicks and drags
/// instead (except on the pin button), but lets other events (mouse
/// movement) through, so the key tooltips still appear on hover. The title
/// bar frame still handles resizing at the edges.
final class DragContainerView: NSView {
    var onPinToggle: (() -> Void)?
    private let pinButton = FirstMouseButton()

    init(content: NSView) {
        super.init(frame: .zero)
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        pinButton.isBordered = false
        pinButton.imagePosition = .imageOnly
        pinButton.imageScaling = .scaleProportionallyUpOrDown
        pinButton.target = self
        pinButton.action = #selector(pinClicked)
        addSubview(pinButton)   // added last, so it sits above the SwiftUI content
        setPinned(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("DragContainerView is created in code")
    }

    func setPinned(_ pinned: Bool) {
        pinButton.image = NSImage(
            systemSymbolName: pinned ? "pin.fill" : "pin",
            accessibilityDescription: pinned ? "Unpin keyboard" : "Pin keyboard"
        )
        pinButton.contentTintColor = pinned ? .controlAccentColor : .secondaryLabelColor
        pinButton.toolTip = pinned
            ? "Unpin: hide the keyboard when Hyper is released"
            : "Pin: keep the keyboard on screen without holding Hyper"
    }

    @objc private func pinClicked() {
        onPinToggle?()
    }

    /// Keeps the pin button in the header's top-right corner at any window size.
    override func layout() {
        super.layout()
        let scale = bounds.width / KeyboardMetrics.naturalWidth
        let side = 20 * scale
        let inset = KeyboardMetrics.padding * scale
        pinButton.frame = NSRect(
            x: bounds.width - inset - side,
            y: bounds.height - inset - side,
            width: side,
            height: side
        )
        pinButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13 * scale, weight: .medium)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        if hit === pinButton { return hit }
        switch NSApp.currentEvent?.type {
        case .leftMouseDown?, .leftMouseDragged?, .leftMouseUp?:
            return self
        default:
            return hit
        }
    }

    // The panel is never key, so the first click must count.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

/// The panel is never key, so its button must respond to the first click.
final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
