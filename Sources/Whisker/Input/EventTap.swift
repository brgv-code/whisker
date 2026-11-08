import CoreGraphics
import Foundation
import WhiskerCore

/// Owns the input thread: the CGEvent tap and the HID monitor both run on its run loop.
final class EventTap: @unchecked Sendable {
    private let runtime: RuntimeState
    private let devices: DeviceMonitor
    private let performer = ActionPerformer()
    private let onDetect: @Sendable (DeviceID?, Int) -> Void

    // Confined to the input thread.
    private var engine = RemapEngine()
    private var tap: CFMachPort?
    private var detectedButton: Int?
    private var thread: Thread?

    init(runtime: RuntimeState, devices: DeviceMonitor, onDetect: @escaping @Sendable (DeviceID?, Int) -> Void) {
        self.runtime = runtime
        self.devices = devices
        self.onDetect = onDetect
    }

    /// Returns false when macOS refuses the tap, which means Accessibility is not granted yet.
    func start() -> Bool {
        let mask = [
            CGEventType.rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel,
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
        guard let input = Self.input(type, event) else { return pass }

        let state = runtime.snapshot()
        if state.isDetecting || detectedButton != nil, case .button(let number, let isDown) = input {
            return detect(number, isDown: isDown) ? nil : pass
        }
        // Disabled still runs the engine with no settings, so a gesture held across the toggle releases the pointer.
        let device = state.settings.isEnabled ? devices.lastActive.flatMap(state.settings.settings(for:)) : nil
        switch engine.handle(input, settings: device, app: state.frontmostApp) {
        case .pass:
            return pass
        case .scaleScroll(let vertical, let horizontal):
            Self.scale(event, vertical: vertical, horizontal: horizontal)
            return pass
        case .suppress(let effects):
            for effect in effects { apply(effect, at: event.location) }
            return nil
        }
    }

    /// Swallows the press and its matching release, so detecting a button does not also click it.
    private func detect(_ number: Int, isDown: Bool) -> Bool {
        if isDown, detectedButton == nil {
            detectedButton = number
            onDetect(devices.lastActive, number)
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
            return .button(number: button, isDown: true)
        case .rightMouseUp, .otherMouseUp:
            return .button(number: button, isDown: false)
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
