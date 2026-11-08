import SwiftUI
import WhiskerCore

struct Inspector: View {
    let device: DeviceID
    let row: ControlRow?
    let scope: String?

    var body: some View {
        Group {
            switch row?.control {
            case .button(let number):
                ButtonInspector(
                    device: device, button: number, title: row?.label ?? "", defaultName: row?.defaultTitle ?? "",
                    scope: scope
                )
                .id(number)
            case .thumbWheel:
                ThumbWheelInspector(device: device)
            case nil:
                Text("Select a control on the mouse.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 330)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
    }
}

private enum Slot: Hashable {
    case tap, hold, click, up, down, left, right

    var gesturePath: WritableKeyPath<GestureBindings, Action>? {
        switch self {
        case .click: \.click
        case .up: \.up
        case .down: \.down
        case .left: \.left
        case .right: \.right
        case .tap, .hold: nil
        }
    }

    var title: String {
        switch self {
        case .tap: "Tap"
        case .hold: "Hold"
        case .click: "Click"
        case .up: "Move up"
        case .down: "Move down"
        case .left: "Move left"
        case .right: "Move right"
        }
    }
}

private enum Kind: Hashable {
    case action, tapOrHold, gesture

    init(_ binding: ButtonBinding) {
        switch binding {
        case .action: self = .action
        case .tapOrHold: self = .tapOrHold
        case .gesture: self = .gesture
        }
    }
}

private struct ButtonInspector: View {
    let device: DeviceID
    let button: Int
    let title: String
    let defaultName: String
    let scope: String?
    @Environment(AppModel.self) private var model
    @State private var slot = Slot.tap

    private var settings: DeviceSettings { model.store.deviceSettings(for: device) }
    private var binding: ButtonBinding { settings.binding(for: button, app: scope) }
    private var isInherited: Bool { scope.map { settings.appOverrides[$0]?[button] == nil } ?? false }

    private var activeSlot: Slot {
        switch Kind(binding) {
        case .action: .tap
        case .tapOrHold: slot == .hold ? .hold : .tap
        case .gesture: slot.gesturePath == nil ? .click : slot
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold))
                Text(binding.summary(default: defaultName)).foregroundStyle(.secondary)
            }
            if let scope {
                Toggle("Same as All Apps", isOn: inheritance(scope)).toggleStyle(.switch)
            }
            if !isInherited {
                Picker("Type", selection: kind) {
                    Text("Action").tag(Kind.action)
                    Text("Tap & hold").tag(Kind.tapOrHold)
                    Text("Gesture button").tag(Kind.gesture)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                slotPicker
                ScrollView {
                    ActionList(action: slotAction, defaultTitle: defaultTitle).padding(.bottom, 20)
                }
            }
        }
        .padding(20)
    }

    @ViewBuilder private var slotPicker: some View {
        switch Kind(binding) {
        case .action:
            EmptyView()
        case .tapOrHold:
            Picker("Slot", selection: $slot) {
                Text(Slot.tap.title).tag(Slot.tap)
                Text(Slot.hold.title).tag(Slot.hold)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("Hold the button for a moment, then let go.").font(.caption).foregroundStyle(.secondary)
        case .gesture:
            HStack(alignment: .center, spacing: 16) {
                DirectionPad(slot: $slot, active: activeSlot)
                VStack(alignment: .leading, spacing: 4) {
                    Text(activeSlot.title).font(.headline)
                    Text("Hold the button, move the mouse, then let go. A press without moving counts as a click.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var defaultTitle: String {
        switch activeSlot {
        case .tap, .hold, .click: "Default (\(defaultName))"
        case .up, .down, .left, .right: "Nothing"
        }
    }

    private var kind: Binding<Kind> {
        Binding(
            get: { Kind(binding) },
            set: { newKind in
                switch newKind {
                case .action: save(.action(.passthrough))
                case .tapOrHold: save(.tapOrHold(tap: .passthrough, hold: .passthrough))
                case .gesture: save(.gesture(.standard))
                }
                slot = newKind == .gesture ? .click : .tap
            })
    }

    private var slotAction: Binding<Action> {
        let slot = activeSlot
        return Binding(
            get: {
                switch binding {
                case .action(let action): action
                case .tapOrHold(let tap, let hold): slot == .hold ? hold : tap
                case .gesture(let gesture): gesture[keyPath: slot.gesturePath ?? \.click]
                }
            },
            set: { newAction in
                switch binding {
                case .action:
                    save(.action(newAction))
                case .tapOrHold(let tap, let hold):
                    save(slot == .hold ? .tapOrHold(tap: tap, hold: newAction) : .tapOrHold(tap: newAction, hold: hold))
                case .gesture(var gesture):
                    gesture[keyPath: slot.gesturePath ?? \.click] = newAction
                    save(.gesture(gesture))
                }
            })
    }

    private func inheritance(_ scope: String) -> Binding<Bool> {
        Binding(
            get: { isInherited },
            set: { shouldInherit in
                let inherited = settings.binding(for: button, app: nil)
                model.store.update(device) {
                    $0.appOverrides[scope, default: [:]][button] = shouldInherit ? nil : inherited
                }
            })
    }

    private func save(_ newBinding: ButtonBinding) {
        model.store.update(device) { settings in
            if let scope {
                settings.appOverrides[scope, default: [:]][button] = newBinding
            } else {
                settings.buttons[button] = newBinding == .action(.passthrough) ? nil : newBinding
            }
        }
    }
}

private struct DirectionPad: View {
    @Binding var slot: Slot
    let active: Slot

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Color.clear.frame(width: 34, height: 34)
                cell(.up, symbol: "arrow.up")
                Color.clear.frame(width: 34, height: 34)
            }
            GridRow {
                cell(.left, symbol: "arrow.left")
                cell(.click, symbol: "circle.fill")
                cell(.right, symbol: "arrow.right")
            }
            GridRow {
                Color.clear.frame(width: 34, height: 34)
                cell(.down, symbol: "arrow.down")
                Color.clear.frame(width: 34, height: 34)
            }
        }
    }

    private func cell(_ target: Slot, symbol: String) -> some View {
        let isActive = active == target
        return Button {
            slot = target
        } label: {
            Image(systemName: symbol)
                .font(.system(size: target == .click ? 8 : 12, weight: .bold))
                .frame(width: 34, height: 34)
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(isActive ? Color.accentColor : Color.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(target.title)
    }
}

private struct ThumbWheelInspector: View {
    let device: DeviceID
    @Environment(AppModel.self) private var model
    @State private var isRight = false

    var body: some View {
        let wheel = model.store.deviceSettings(for: device).thumbWheel
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Thumb wheel").font(.title3.weight(.semibold))
                Text(wheel == .scroll ? "Scroll sideways" : "Run actions").foregroundStyle(.secondary)
            }
            Picker(
                "Thumb wheel",
                selection: Binding(
                    get: { wheel == .scroll },
                    set: { isScroll in
                        save(
                            isScroll ? .scroll : .actions(left: .media(key: .volumeDown), right: .media(key: .volumeUp))
                        )
                    })
            ) {
                Text("Scroll sideways").tag(true)
                Text("Run actions").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if case .actions(let left, let right) = wheel {
                Picker("Direction", selection: $isRight) {
                    Text("Scroll left").tag(false)
                    Text("Scroll right").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                ScrollView {
                    ActionList(
                        action: Binding(
                            get: { isRight ? right : left },
                            set: { save(isRight ? .actions(left: left, right: $0) : .actions(left: $0, right: right)) }),
                        defaultTitle: "Nothing"
                    )
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(20)
    }

    private func save(_ wheel: ThumbWheelBinding) {
        model.store.update(device) { $0.thumbWheel = wheel }
    }
}
