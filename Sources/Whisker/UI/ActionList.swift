import AppKit
import Carbon.HIToolbox
import SwiftUI
import WhiskerCore

/// Every assignable action as an icon list; the selected one is checked.
struct ActionList: View {
    @Binding var action: Action
    var defaultTitle = "Default"
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            group(nil) {
                row(.passthrough, title: defaultTitle)
                row(.disabled)
            }
            ForEach(Action.sections) { section in
                group(section.title) {
                    ForEach(section.actions, id: \.self) { row($0) }
                }
            }
            group("Keyboard shortcut") { shortcutRow }
        }
        .onDisappear { stopRecording() }
    }

    private func group(_ title: String?, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                    .padding(.bottom, 4)
            }
            rows()
        }
    }

    private func row(_ candidate: Action, title: String? = nil) -> some View {
        ActionRow(symbol: candidate.symbol, title: title ?? candidate.title, isSelected: candidate == action) {
            stopRecording()
            action = candidate
        }
    }

    private var shortcutRow: some View {
        let trailing = isRecording ? "Type a shortcut…" : (action.isShortcut ? action.title : nil)
        return ActionRow(
            symbol: "keyboard", title: "Keyboard shortcut", isSelected: isRecording || action.isShortcut,
            trailing: trailing
        ) {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode != UInt16(kVK_Escape) {
                action = .shortcut(combo: KeyCombo(event))
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

private struct ActionRow: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    var trailing: String?
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12)))
                Text(title)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing).foregroundStyle(.secondary).monospaced()
                } else if isSelected {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ? Color.accentColor.opacity(0.1) : isHovered ? Color.primary.opacity(0.05) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
