import Foundation

public struct DeviceID: Hashable, Codable, Sendable, CustomStringConvertible {
    public var vendorID: Int
    public var productID: Int

    public init(vendorID: Int, productID: Int) {
        self.vendorID = vendorID
        self.productID = productID
    }

    public var description: String { String(format: "%04x:%04x", vendorID, productID) }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        let parts = text.split(separator: ":").compactMap { Int($0, radix: 16) }
        guard parts.count == 2 else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Expected vendor:product in hex, got \(text)")
        }
        self.init(vendorID: parts[0], productID: parts[1])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

public struct GestureBindings: Hashable, Codable, Sendable {
    public var click: Action
    public var up: Action
    public var down: Action
    public var left: Action
    public var right: Action

    public init(click: Action, up: Action, down: Action, left: Action, right: Action) {
        self.click = click
        self.up = up
        self.down = down
        self.left = left
        self.right = right
    }

    public static let standard = GestureBindings(
        click: .system(action: .missionControl),
        up: .system(action: .missionControl),
        down: .system(action: .appExpose),
        left: .system(action: .spaceRight),
        right: .system(action: .spaceLeft)
    )
}

public enum ButtonBinding: Hashable, Codable, Sendable {
    case action(Action)
    case tapOrHold(tap: Action, hold: Action)
    case gesture(GestureBindings)
}

public struct ScrollSettings: Hashable, Codable, Sendable {
    public var reverseVertical: Bool
    public var reverseHorizontal: Bool
    public var speed: Double

    public init(reverseVertical: Bool = false, reverseHorizontal: Bool = false, speed: Double = 1) {
        self.reverseVertical = reverseVertical
        self.reverseHorizontal = reverseHorizontal
        self.speed = speed
    }
}

public enum ThumbWheelBinding: Hashable, Codable, Sendable {
    case scroll
    case actions(left: Action, right: Action)
}

public struct DeviceSettings: Hashable, Codable, Sendable {
    public var device: DeviceID
    public var buttons: [Int: ButtonBinding]
    public var scroll: ScrollSettings
    public var thumbWheel: ThumbWheelBinding
    public var appOverrides: [String: [Int: ButtonBinding]]

    public init(
        device: DeviceID,
        buttons: [Int: ButtonBinding] = [:],
        scroll: ScrollSettings = ScrollSettings(),
        thumbWheel: ThumbWheelBinding = .scroll,
        appOverrides: [String: [Int: ButtonBinding]] = [:]
    ) {
        self.device = device
        self.buttons = buttons
        self.scroll = scroll
        self.thumbWheel = thumbWheel
        self.appOverrides = appOverrides
    }

    public func binding(for button: Int, app bundleID: String?) -> ButtonBinding {
        if let bundleID, let override = appOverrides[bundleID]?[button] {
            return override
        }
        return buttons[button] ?? .action(.passthrough)
    }
}

public struct Settings: Hashable, Codable, Sendable {
    public var isEnabled: Bool
    public var devices: [DeviceSettings]

    public init(isEnabled: Bool = true, devices: [DeviceSettings] = []) {
        self.isEnabled = isEnabled
        self.devices = devices
    }

    public func settings(for device: DeviceID) -> DeviceSettings? {
        devices.first { $0.device == device }
    }
}
