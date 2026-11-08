import SwiftUI
import WhiskerCore

struct ButtonEditor: View {
    let device: DeviceID
    let button: Int
    let scope: String?
    @Environment(AppModel.self) private var model

    private var settings: DeviceSettings { model.store.deviceSettings(for: device) }

    var body: some View {
        if let scope {
            Toggle(
                "Same as All Apps",
                isOn: Binding(
                    get: { settings.appOverrides[scope]?[button] == nil },
                    set: { isInherited in
                        let inherited = settings.binding(for: button, app: nil)
                        model.store.update(device) {
                            $0.appOverrides[scope, default: [:]][button] = isInherited ? nil : inherited
                        }
                    }))
            if settings.appOverrides[scope]?[button] != nil { editor }
        } else {
            editor
        }
    }

    @ViewBuilder private var editor: some View {
        let binding = settings.binding(for: button, app: scope)
        Picker(
            "Type",
            selection: Binding(
                get: { if case .gesture = binding { true } else { false } },
                set: { isGesture in save(isGesture ? .gesture(.standard) : .action(.passthrough)) })
        ) {
            Text("Action").tag(false)
            Text("Gesture button").tag(true)
        }
        .pickerStyle(.segmented)

        switch binding {
        case .action(let action):
            ActionPicker(title: "Action", action: Binding(get: { action }, set: { save(.action($0)) }))
        case .gesture(let gesture):
            Text("Hold the button, move the mouse, then let go. A press without moving counts as a click.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Self.directions, id: \.title) { direction in
                ActionPicker(
                    title: direction.title,
                    action: Binding(
                        get: { gesture[keyPath: direction.path] },
                        set: { newAction in
                            var updated = gesture
                            updated[keyPath: direction.path] = newAction
                            save(.gesture(updated))
                        }),
                    defaultTitle: direction.path == \.click ? "Normal click" : "Nothing")
            }
        }
    }

    private static let directions: [(title: String, path: WritableKeyPath<GestureBindings, Action>)] = [
        ("Click", \.click), ("Move up", \.up), ("Move down", \.down), ("Move left", \.left), ("Move right", \.right),
    ]

    private func save(_ binding: ButtonBinding) {
        model.store.update(device) { settings in
            if let scope {
                settings.appOverrides[scope, default: [:]][button] = binding
            } else {
                settings.buttons[button] = binding == .action(.passthrough) ? nil : binding
            }
        }
    }
}

struct ThumbWheelEditor: View {
    let device: DeviceID
    @Environment(AppModel.self) private var model

    var body: some View {
        let wheel = model.store.deviceSettings(for: device).thumbWheel
        Picker(
            "Thumb wheel",
            selection: Binding(
                get: { wheel == .scroll },
                set: { isScroll in
                    save(isScroll ? .scroll : .actions(left: .media(key: .volumeDown), right: .media(key: .volumeUp)))
                })
        ) {
            Text("Scroll sideways").tag(true)
            Text("Run actions").tag(false)
        }
        .pickerStyle(.segmented)

        if case .actions(let left, let right) = wheel {
            ActionPicker(
                title: "Scroll left", action: Binding(get: { left }, set: { save(.actions(left: $0, right: right)) }),
                defaultTitle: "Nothing")
            ActionPicker(
                title: "Scroll right", action: Binding(get: { right }, set: { save(.actions(left: left, right: $0)) }),
                defaultTitle: "Nothing")
        }
    }

    private func save(_ wheel: ThumbWheelBinding) {
        model.store.update(device) { $0.thumbWheel = wheel }
    }
}

struct ScrollSection: View {
    let device: DeviceID
    let isAppScope: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        let scroll = model.store.deviceSettings(for: device).scroll
        Section {
            Toggle("Reverse wheel", isOn: binding(\.reverseVertical, scroll))
            Toggle("Reverse thumb wheel", isOn: binding(\.reverseHorizontal, scroll))
            LabeledContent("Speed") {
                HStack {
                    Slider(value: binding(\.speed, scroll), in: 0.25...4, step: 0.25)
                    Text(scroll.speed, format: .number.precision(.fractionLength(2))).monospacedDigit().frame(width: 36)
                }
            }
        } header: {
            Text("Scrolling")
        } footer: {
            Text(
                isAppScope
                    ? "Scrolling settings apply to every app."
                    : "Only this mouse is affected. Your trackpad keeps the Natural Scrolling setting from System Settings."
            )
        }
    }

    private func binding<Value>(_ path: WritableKeyPath<ScrollSettings, Value>, _ scroll: ScrollSettings) -> Binding<
        Value
    > {
        Binding(
            get: { scroll[keyPath: path] },
            set: { newValue in
                model.store.update(device) { $0.scroll[keyPath: path] = newValue }
            })
    }
}
