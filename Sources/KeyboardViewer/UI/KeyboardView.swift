import SwiftUI

/// Base measurements at scale 1. Everything in the keyboard (keys, gaps,
/// fonts, padding) is multiplied by one scale factor, so the window can be
/// resized and the layout stays crisp rather than being stretched as a bitmap.
enum KeyboardMetrics {
    static let unit: CGFloat = 60      // width of a 1u key
    static let gap: CGFloat = 5
    static let padding: CGFloat = 14

    /// Every row is 14.5 key units wide (see KeyboardLayout), and a row of
    /// total width W spans W * unit + (W - 1) * gap.
    static let rowWidth = 14.5 * unit + 13.5 * gap
    static let naturalWidth = rowWidth + 2 * padding
}

/// What the panel shows: the keyboard, scaled to the window's width.
/// The panel keeps its aspect ratio, so width alone sets the scale.
struct KeyboardView: View {
    @ObservedObject var state: OverlayState

    var body: some View {
        GeometryReader { geo in
            KeyboardContent(
                state: state,
                scale: max(geo.size.width / KeyboardMetrics.naturalWidth, 0.1)
            )
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(.regularMaterial)
        .ignoresSafeArea()
    }
}

/// The keyboard at a given scale. At scale 1 its size is the panel's
/// natural size, which the panel measures to set its aspect ratio.
struct KeyboardContent: View {
    @ObservedObject var state: OverlayState
    let scale: CGFloat

    private var unit: CGFloat { KeyboardMetrics.unit * scale }
    private var gap: CGFloat { KeyboardMetrics.gap * scale }

    var body: some View {
        let layer = state.currentLayer
        let actionCount = layer.values.filter { !$0.isTypedCharacter }.count

        VStack(alignment: .leading, spacing: gap) {
            header(bindingCount: actionCount)
                .frame(width: KeyboardMetrics.rowWidth * scale)

            ForEach(Array(KeyboardLayout.rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: gap) {
                    ForEach(row) { slot in
                        slotView(slot, layer: layer, height: rowIndex == 0 ? unit * 0.7 : unit)
                    }
                }
            }

            // Section legend on its own row, so long rule names have room.
            legend
                .frame(width: KeyboardMetrics.rowWidth * scale, height: 16 * scale)
                .padding(.top, 3 * scale)
        }
        .padding(KeyboardMetrics.padding * scale)
        .fixedSize()
    }

    /// One line, always, so the content's height never changes and the
    /// panel's aspect ratio stays right. Status messages appear here too.
    private func header(bindingCount: Int) -> some View {
        HStack(spacing: 10 * scale) {
            Text(state.layerTitle)
                .font(.system(size: 15 * scale, weight: .semibold))
            if let message = state.statusMessage {
                Text(message)
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else if !state.showsHyperLayer, let note = state.appShortcutsNote {
                Text(note)
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else if !state.showsHyperLayer && state.heldMods.isEmpty {
                Text(hint)
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(.secondary)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
            Text("\(bindingCount) bindings")
                .font(.system(size: 12 * scale).monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
            // Room for the pin button, which the panel draws in this corner.
            Color.clear.frame(width: 24 * scale, height: 1)
        }
        .lineLimit(1)
        .padding(.bottom, 2 * scale)
    }

    private var legend: some View {
        HStack(spacing: 16 * scale) {
            ForEach(SectionPalette.present(in: state.legendBindings), id: \.name) { section in
                HStack(spacing: 5 * scale) {
                    Circle()
                        .fill(section.base)
                        .frame(width: 9 * scale, height: 9 * scale)
                    Text(section.name)
                        .font(.system(size: 12 * scale, weight: .medium))
                        .foregroundStyle(section.text)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private func slotView(_ slot: KeySlot, layer: [String: KeyBinding], height: CGFloat) -> some View {
        switch slot {
        case .key(let def):
            KeyCapView(
                def: def,
                legend: state.legend(for: def),
                binding: layer[def.code],
                size: CGSize(width: width(def.width), height: height),
                scale: scale,
                isActive: isActive(def),
                isDimmed: isPreview
            )
        case .stacked(let top, let bottom):
            let half = (unit - gap) / 2
            VStack(spacing: gap) {
                KeyCapView(def: top, legend: top.legend, binding: layer[top.code],
                           size: CGSize(width: unit, height: half), scale: scale,
                           isActive: false, isDimmed: isPreview, compact: true)
                KeyCapView(def: bottom, legend: bottom.legend, binding: layer[bottom.code],
                           size: CGSize(width: unit, height: half), scale: scale,
                           isActive: false, isDimmed: isPreview, compact: true)
            }
        }
    }

    /// A key `w` units wide also spans the gaps it replaces, so rows line up.
    private func width(_ w: CGFloat) -> CGFloat {
        w * unit + (w - 1) * gap
    }

    /// Nothing is drawn as a preview any more: keys always show what they do now.
    private let isPreview = false

    /// Shown when nothing is held.
    private var hint: String {
        switch (state.hyperAvailable, state.appShortcutsActive) {
        case (true, true): return "Hold \(state.hyperKeyName) for Hyper, or ⌘ ⌥ ⌃ ⇧ for this app"
        case (true, false): return "Hold \(state.hyperKeyName) for Hyper"
        default: return "Hold ⌘ ⌥ ⌃ ⇧ to see what they do in this app"
        }
    }

    private func isActive(_ def: KeyDef) -> Bool {
        if state.isHyperKey(def.code) { return state.isHyperKeyActive(def.code) }
        if let m = def.modifier { return state.heldMods.contains(m) }
        return false
    }
}

struct KeyCapView: View {
    let def: KeyDef
    let legend: String   // def.legend, or "Hyper"
    let binding: KeyBinding?
    let size: CGSize
    let scale: CGFloat
    let isActive: Bool
    let isDimmed: Bool
    var compact = false

    /// Medium grey for held modifier keys (⇧ ⌃ ⌥ ⌘ fn and Hyper).
    static let activeModifierFill = Color(nsColor: NSColor(srgbRed: 142.0 / 255, green: 142.0 / 255, blue: 147.0 / 255, alpha: 1))

    var body: some View {
        // The key name sits at a fixed height on every key, so names line up
        // across a row; the description fills the space below it, centred.
        // The keystroke a binding sends is left out here; it's in the tooltip.
        VStack(alignment: .center, spacing: 1 * scale) {
            Text(legend)
                .font(.system(size: (compact ? 11 : 14) * scale, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Color.primary.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: (compact ? 13 : 17) * scale)

            if let b = binding, !compact, let symbol = b.symbol {
                // Scaled to the space under the key name, with a margin, so it
                // fits the short function-row keys at any window size.
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.medium)
                    .foregroundStyle(section?.text ?? Color.primary)
                    .padding(.vertical, 2.5 * scale)
                    .frame(maxWidth: 26 * scale, maxHeight: .infinity, alignment: .center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let b = binding, !compact {
                Text(b.isCharacter ? b.title : LabelFormatter.format(b.title))
                    .font(.system(size: (b.isCharacter ? 20 : 12.5) * scale,
                                  weight: b.isCharacter ? .regular : .semibold))
                    .foregroundStyle(section?.text ?? Color.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 3 * scale)
        .padding(.top, (compact ? 1 : 4) * scale)
        .padding(.bottom, (compact ? 1 : 3) * scale)
        .frame(width: size.width, height: size.height, alignment: compact ? .center : .top)
        .background(RoundedRectangle(cornerRadius: 6 * scale, style: .continuous).fill(fill))
        .overlay(
            RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                .strokeBorder(
                    stroke,
                    style: StrokeStyle(
                        lineWidth: hasAction ? 1 : 0.5,
                        // Dashed: an unconditional rule that fires with or without Hyper.
                        dash: binding?.isGlobal == true ? [3 * scale, 2 * scale] : []
                    )
                )
        )
        .opacity(isDimmed && binding != nil ? 0.9 : 1)
        .help(tooltip)
    }

    /// The colour of the karabiner.json section this binding comes from.
    private var section: SectionStyle? {
        binding.flatMap { SectionPalette.style(for: $0) }
    }

    /// A key that only types a character is drawn like a key with no action.
    private var hasAction: Bool {
        binding.map { !$0.isTypedCharacter } ?? false
    }

    private var fill: Color {
        if isActive { return Self.activeModifierFill }
        guard hasAction else { return Color.primary.opacity(0.04) }
        return (section?.base ?? .gray).opacity(0.18)
    }

    private var stroke: Color {
        guard hasAction else { return Color.primary.opacity(0.10) }
        return (section?.base ?? .gray).opacity(0.6)
    }

    private var tooltip: String {
        guard let b = binding else { return legend }
        let scope = b.isGlobal ? "\nApplies with or without Hyper" : ""
        return "\(b.title)\n\(b.detail)\nRule: \(b.ruleName)\(scope)"
    }
}
