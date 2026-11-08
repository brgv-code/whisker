public enum InputEvent: Equatable, Sendable {
    case button(number: Int, isDown: Bool)
    case moved(dx: Double, dy: Double)
    /// Deltas in lines. Trackpads and Magic Mouse report continuous scrolls.
    case scroll(vertical: Double, horizontal: Double, isContinuous: Bool)
}

public enum Effect: Equatable, Sendable {
    case perform(Action)
    case press(button: Int, isDown: Bool)
    case freezePointer(Bool)
}

public enum Decision: Equatable, Sendable {
    case pass
    case scaleScroll(vertical: Double, horizontal: Double)
    case suppress([Effect])
}

/// Decides what happens to each pointer event. Confined to the input thread, so it holds plain state.
public struct RemapEngine: Sendable {
    public static let gestureThreshold = 40.0

    private struct Gesture: Sendable {
        var button: Int
        var dx = 0.0
        var dy = 0.0
    }

    // Bindings resolved at press time, so a release still matches if the front app changes mid-click.
    private var held: [Int: ButtonBinding] = [:]
    private var gesture: Gesture?
    private var thumbTravel = 0.0

    public init() {}

    public mutating func handle(_ event: InputEvent, settings: DeviceSettings?, app: String?) -> Decision {
        switch event {
        case .button(let number, isDown: false):
            return release(number)
        case .button(let number, isDown: true):
            guard let settings else { return .pass }
            return press(number, binding: settings.binding(for: number, app: app))
        case .moved(let dx, let dy):
            guard gesture != nil else { return .pass }
            gesture?.dx += dx
            gesture?.dy += dy
            return .suppress([])
        case .scroll(let vertical, let horizontal, let isContinuous):
            guard let settings, !isContinuous else { return .pass }
            return scroll(vertical: vertical, horizontal: horizontal, settings: settings)
        }
    }

    private mutating func press(_ number: Int, binding: ButtonBinding) -> Decision {
        switch binding {
        case .action(.passthrough):
            return .pass
        case .action(let action):
            held[number] = binding
            switch action {
            case .mouseButton(let target): return .suppress([.press(button: target, isDown: true)])
            case .disabled: return .suppress([])
            default: return .suppress([.perform(action)])
            }
        case .gesture:
            held[number] = binding
            gesture = Gesture(button: number)
            return .suppress([.freezePointer(true)])
        }
    }

    private mutating func release(_ number: Int) -> Decision {
        guard let binding = held.removeValue(forKey: number) else { return .pass }
        switch binding {
        case .action(.mouseButton(let target)):
            return .suppress([.press(button: target, isDown: false)])
        case .action:
            return .suppress([])
        case .gesture(let bindings):
            let travel = gesture ?? Gesture(button: number)
            gesture = nil
            return .suppress([.freezePointer(false)] + resolve(travel, bindings))
        }
    }

    private func resolve(_ travel: Gesture, _ bindings: GestureBindings) -> [Effect] {
        let isClick = (travel.dx * travel.dx + travel.dy * travel.dy).squareRoot() < Self.gestureThreshold
        let action: Action
        if isClick {
            action = bindings.click
        } else if abs(travel.dx) > abs(travel.dy) {
            action = travel.dx < 0 ? bindings.left : bindings.right
        } else {
            // Screen coordinates grow downward.
            action = travel.dy < 0 ? bindings.up : bindings.down
        }
        if isClick, action == .passthrough {
            return [.press(button: travel.button, isDown: true), .press(button: travel.button, isDown: false)]
        }
        return action == .passthrough ? [] : [.perform(action)]
    }

    private mutating func scroll(vertical: Double, horizontal: Double, settings: DeviceSettings) -> Decision {
        if case .actions(let left, let right) = settings.thumbWheel, horizontal != 0 {
            // macOS reports positive horizontal deltas for leftward scrolls.
            thumbTravel += horizontal
            var effects: [Effect] = []
            while thumbTravel >= 1 {
                effects.append(.perform(left))
                thumbTravel -= 1
            }
            while thumbTravel <= -1 {
                effects.append(.perform(right))
                thumbTravel += 1
            }
            return .suppress(effects.filter { $0 != .perform(.passthrough) })
        }
        let scroll = settings.scroll
        let verticalFactor = (scroll.reverseVertical ? -1 : 1) * scroll.speed
        let horizontalFactor = (scroll.reverseHorizontal ? -1 : 1) * scroll.speed
        if verticalFactor == 1, horizontalFactor == 1 { return .pass }
        return .scaleScroll(vertical: verticalFactor, horizontal: horizontalFactor)
    }
}
