import CoreGraphics
import Foundation
import WhiskerCore

/// Owns the input thread: the CGEvent tap and the HID monitor both run on its run loop.
final class EventTap: @unchecked Sendable {
    private let runtime: RuntimeState
    private let devices: DeviceMonitor
    private let catalog: DeviceCatalog
    private let performer = ActionPerformer()
    private let onDetect: @Sendable (DeviceID?, Int) -> Void

    // Confined to the input thread.
    private var engine = RemapEngine()
    private var tap: CFMachPort?
    private var detectedButton: Int?
    /// Mouse keystrokes currently held, by key code, so the release finds its button even after modifiers lift.
    private var keyButtonsDown: [UInt16: (button: Int, device: DeviceID)] = [:]
    private var thread: Thread?

    init(
        runtime: RuntimeState, devices: DeviceMonitor, catalog: DeviceCatalog,
        onDetect: @escaping @Sendable (DeviceID?, Int) -> Void
    ) {
        self.runtime = runtime
        self.devices = devices
        self.catalog = catalog
        self.onDetect = onDetect
    }

    /// Returns false when macOS refuses the tap, which means Accessibility is not granted yet.
    func start() -> Bool {
        let mask = [
            CGEventType.rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel, .keyDown, .keyUp,
        ].reduce(CGEventMask(0)) { mask, type in mask | (1 << type.rawValue) }

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                callback: { _, type, event, context in
                    Unmanaged<EventTap>.fromOpaque(context!).takeUnretainedValue().handle(type, event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        self.tap = tap

        // Own thread, not main: a busy UI must never stall the cursor or make macOS disable the tap.
        let thread = Thread { [self] in
            let runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(runLoop, CFMachPortCreateRunLoopSource(nil, self.tap, 0), .commonModes)
            devices.schedule(on: runLoop!)
            CFRunLoopRun()
        }
        thread.name = "Whisker input"
        thread.qualityOfService = .userInteractive
        thread.start()
        self.thread = thread
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        if event.getIntegerValueField(.eventSourceUserData) == ActionPerformer.syntheticMarker { return pass }
        let state = runtime.snapshot()

        if type == .keyDown || type == .keyUp {
            guard let (input, device) = keyButton(type, event, state) else { return pass }
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
            let location = CGEvent(source: nil)?.location ?? .zero
            return process(input, from: device, state: state, at: location, isKey: true) == .swallow ? nil : pass
        }
        guard let input = Self.input(type, event) else { return pass }
        switch process(input, from: devices.lastPointer, state: state, at: event.location, isKey: false) {
        case .swallow:
            return nil
        case .pass:
            return pass
        case .scaleScroll(let vertical, let horizontal):
            Self.scale(event, vertical: vertical, horizontal: horizontal)
            return pass
        }
    }

    private enum Outcome: Equatable {
        case pass
        case swallow
        case scaleScroll(vertical: Double, horizontal: Double)
    }

    /// Maps a keystroke typed by a mouse's firmware back to the button the profile says produced it.
    private func keyButton(
        _ type: CGEventType, _ event: CGEvent, _ state: RuntimeState.Snapshot
    ) -> (InputEvent, DeviceID)? {
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let time = Double(event.timestamp) / 1_000_000_000
        if type == .keyUp {
            guard let held = keyButtonsDown.removeValue(forKey: code) else { return nil }
            return (.button(number: held.button, isDown: false, time: time), held.device)
        }
        if let held = keyButtonsDown[code] {
            return (.button(number: held.button, isDown: true, time: time), held.device)
        }
        guard state.settings.isEnabled, let device = devices.lastKeyboard,
            let button = catalog.profile(for: device)?.button(sending: code, modifiers: Modifiers(event.flags))
        else { return nil }
        keyButtonsDown[code] = (button, device)
        return (.button(number: button, isDown: true, time: time), device)
    }

    private func process(
        _ input: InputEvent, from device: DeviceID?, state: RuntimeState.Snapshot, at location: CGPoint, isKey: Bool
    ) -> Outcome {
        if state.isDetecting || detectedButton != nil, case .button(let number, let isDown, _) = input {
            if detect(number, isDown: isDown, on: device) { return .swallow }
            if !isKey { return .pass }
        }
        // Disabled still runs the engine with no settings, so a gesture held across the toggle releases the pointer.
        let settings = state.settings.isEnabled ? device.flatMap(state.settings.settings(for:)) : nil
        switch engine.handle(input, settings: settings, app: state.frontmostApp) {
        case .pass:
            // A mouse keystroke left on Default becomes the real button it stands for, never the firmware shortcut.
            if isKey, case .button(let number, let isDown, _) = input {
                performer.postMouseButton(number, isDown: isDown, at: location)
                return .swallow
            }
            return .pass
        case .scaleScroll(let vertical, let horizontal):
            return .scaleScroll(vertical: vertical, horizontal: horizontal)
        case .suppress(let effects):
            for effect in effects { apply(effect, at: location) }
            return .swallow
        }
    }

    /// Swallows the press and its matching release, so detecting a button does not also click it.
    private func detect(_ number: Int, isDown: Bool, on device: DeviceID?) -> Bool {
        if isDown, detectedButton == nil {
            detectedButton = number
            onDetect(device, number)
            return true
        }
        if !isDown, detectedButton == number {
            detectedButton = nil
            return true
        }
        return false
    }

    private func apply(_ effect: Effect, at location: CGPoint) {
        switch effect {
        case .perform(let action): performer.perform(action, at: location)
        case .press(let button, let isDown): performer.postMouseButton(button, isDown: isDown, at: location)
        case .freezePointer(let isFrozen): CGAssociateMouseAndMouseCursorPosition(isFrozen ? 0 : 1)
        }
    }

    private static func input(_ type: CGEventType, _ event: CGEvent) -> InputEvent? {
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        switch type {
        case .rightMouseDown, .otherMouseDown:
            return .button(number: button, isDown: true, time: Double(event.timestamp) / 1_000_000_000)
        case .rightMouseUp, .otherMouseUp:
            return .button(number: button, isDown: false, time: Double(event.timestamp) / 1_000_000_000)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            return .moved(
                dx: event.getDoubleValueField(.mouseEventDeltaX), dy: event.getDoubleValueField(.mouseEventDeltaY))
        case .scrollWheel:
            return .scroll(
                vertical: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
                horizontal: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2),
                isContinuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0)
        default:
            return nil
        }
    }

    // Apps read different fields (lines, fixed point, pixels), so all three are scaled together.
    private static func scale(_ event: CGEvent, vertical: Double, horizontal: Double) {
        let axes: [(CGEventField, CGEventField, CGEventField, Double)] = [
            (
                .scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventPointDeltaAxis1,
                vertical
            ),
            (
                .scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2,
                horizontal
            ),
        ]
        for (lineField, fixedField, pointField, factor) in axes {
            let lines = Double(event.getIntegerValueField(lineField))
            var scaledLines = (lines * factor).rounded()
            // Keep slow speeds from rounding a real notch down to nothing.
            if scaledLines == 0, lines != 0 { scaledLines = lines * factor < 0 ? -1 : 1 }
            event.setIntegerValueField(lineField, value: Int64(scaledLines))
            event.setDoubleValueField(fixedField, value: event.getDoubleValueField(fixedField) * factor)
            event.setDoubleValueField(pointField, value: event.getDoubleValueField(pointField) * factor)
        }
    }
}
