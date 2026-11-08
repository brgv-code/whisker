import Testing
import WhiskerCore

private let mouse = DeviceID(vendorID: 0x1ea7, productID: 0x0067)
private let copy = KeyCombo(keyCode: 8, modifiers: .command, label: "⌘C")

private func settings(_ buttons: [Int: ButtonBinding] = [:]) -> DeviceSettings {
    DeviceSettings(device: mouse, buttons: buttons)
}

@Suite struct ButtonRemapping {
    @Test func unmappedButtonPassesThrough() {
        var engine = RemapEngine()
        #expect(engine.handle(.button(number: 3, isDown: true), settings: settings(), app: nil) == .pass)
        #expect(engine.handle(.button(number: 3, isDown: false), settings: settings(), app: nil) == .pass)
    }

    @Test func unknownDeviceIsLeftAlone() {
        var engine = RemapEngine()
        #expect(engine.handle(.button(number: 3, isDown: true), settings: nil, app: nil) == .pass)
        #expect(
            engine.handle(.scroll(vertical: 1, horizontal: 0, isContinuous: false), settings: nil, app: nil) == .pass)
    }

    @Test func shortcutFiresOnPressAndSwallowsRelease() {
        var engine = RemapEngine()
        let device = settings([3: .action(.shortcut(combo: copy))])
        #expect(
            engine.handle(.button(number: 3, isDown: true), settings: device, app: nil)
                == .suppress([.perform(.shortcut(combo: copy))]))
        #expect(engine.handle(.button(number: 3, isDown: false), settings: device, app: nil) == .suppress([]))
    }

    @Test func buttonToButtonHoldsUntilRelease() {
        var engine = RemapEngine()
        let device = settings([4: .action(.mouseButton(number: 2))])
        #expect(
            engine.handle(.button(number: 4, isDown: true), settings: device, app: nil)
                == .suppress([.press(button: 2, isDown: true)]))
        #expect(
            engine.handle(.button(number: 4, isDown: false), settings: device, app: nil)
                == .suppress([.press(button: 2, isDown: false)]))
    }

    @Test func disabledButtonDoesNothing() {
        var engine = RemapEngine()
        let device = settings([1: .action(.disabled)])
        #expect(engine.handle(.button(number: 1, isDown: true), settings: device, app: nil) == .suppress([]))
        #expect(engine.handle(.button(number: 1, isDown: false), settings: device, app: nil) == .suppress([]))
    }
}

@Suite struct AppOverrides {
    @Test func overrideAppliesOnlyToItsApp() {
        var device = settings([3: .action(.system(action: .navigateBack))])
        device.appOverrides["com.apple.finder"] = [3: .action(.media(key: .playPause))]
        var engine = RemapEngine()

        #expect(
            engine.handle(.button(number: 3, isDown: true), settings: device, app: "com.apple.finder")
                == .suppress([.perform(.media(key: .playPause))]))
        _ = engine.handle(.button(number: 3, isDown: false), settings: device, app: "com.apple.finder")
        #expect(
            engine.handle(.button(number: 3, isDown: true), settings: device, app: "com.apple.Safari")
                == .suppress([.perform(.system(action: .navigateBack))]))
    }

    @Test func releaseUsesBindingFromPressTime() {
        var device = settings()
        device.appOverrides["com.apple.finder"] = [4: .action(.mouseButton(number: 2))]
        var engine = RemapEngine()

        _ = engine.handle(.button(number: 4, isDown: true), settings: device, app: "com.apple.finder")
        #expect(
            engine.handle(.button(number: 4, isDown: false), settings: device, app: "com.apple.Safari")
                == .suppress([.press(button: 2, isDown: false)]))
    }
}

@Suite struct GestureButton {
    private let device = settings([5: .gesture(.standard)])

    private func swipe(dx: Double, dy: Double) -> Decision {
        var engine = RemapEngine()
        #expect(
            engine.handle(.button(number: 5, isDown: true), settings: device, app: nil)
                == .suppress([.freezePointer(true)]))
        #expect(engine.handle(.moved(dx: dx, dy: dy), settings: device, app: nil) == .suppress([]))
        return engine.handle(.button(number: 5, isDown: false), settings: device, app: nil)
    }

    @Test func smallMovementIsAClick() {
        #expect(swipe(dx: 5, dy: -3) == .suppress([.freezePointer(false), .perform(.system(action: .missionControl))]))
    }

    @Test func dominantAxisPicksDirection() {
        #expect(swipe(dx: 10, dy: 60) == .suppress([.freezePointer(false), .perform(.system(action: .appExpose))]))
        #expect(swipe(dx: -80, dy: 30) == .suppress([.freezePointer(false), .perform(.system(action: .spaceRight))]))
    }

    @Test func passthroughClickReplaysOriginalButton() {
        var bindings = GestureBindings.standard
        bindings.click = .passthrough
        let device = settings([5: .gesture(bindings)])
        var engine = RemapEngine()
        _ = engine.handle(.button(number: 5, isDown: true), settings: device, app: nil)
        #expect(
            engine.handle(.button(number: 5, isDown: false), settings: device, app: nil)
                == .suppress([.freezePointer(false), .press(button: 5, isDown: true), .press(button: 5, isDown: false)])
        )
    }

    @Test func releaseAfterDisablingStillUnfreezesPointer() {
        var engine = RemapEngine()
        _ = engine.handle(.button(number: 5, isDown: true), settings: device, app: nil)
        #expect(
            engine.handle(.button(number: 5, isDown: false), settings: nil, app: nil)
                == .suppress([.freezePointer(false), .perform(.system(action: .missionControl))]))
    }

    @Test func movementOutsideAGesturePasses() {
        var engine = RemapEngine()
        #expect(engine.handle(.moved(dx: 50, dy: 0), settings: device, app: nil) == .pass)
    }
}

@Suite struct Scrolling {
    @Test func defaultScrollPasses() {
        var engine = RemapEngine()
        #expect(
            engine.handle(.scroll(vertical: 1, horizontal: 0, isContinuous: false), settings: settings(), app: nil)
                == .pass)
    }

    @Test func reverseAndSpeedScaleWheelEvents() {
        var device = settings()
        device.scroll = ScrollSettings(reverseVertical: true, speed: 2)
        var engine = RemapEngine()
        #expect(
            engine.handle(.scroll(vertical: 1, horizontal: 0, isContinuous: false), settings: device, app: nil)
                == .scaleScroll(vertical: -2, horizontal: 2))
    }

    @Test func trackpadScrollIsNeverTouched() {
        var device = settings()
        device.scroll = ScrollSettings(reverseVertical: true)
        var engine = RemapEngine()
        #expect(
            engine.handle(.scroll(vertical: 3, horizontal: 0, isContinuous: true), settings: device, app: nil) == .pass)
    }

    @Test func thumbWheelTicksBecomeActions() {
        var device = settings()
        device.thumbWheel = .actions(left: .media(key: .volumeDown), right: .media(key: .volumeUp))
        var engine = RemapEngine()
        #expect(
            engine.handle(.scroll(vertical: 0, horizontal: 1, isContinuous: false), settings: device, app: nil)
                == .suppress([.perform(.media(key: .volumeDown))]))
        #expect(
            engine.handle(.scroll(vertical: 0, horizontal: -2, isContinuous: false), settings: device, app: nil)
                == .suppress([.perform(.media(key: .volumeUp)), .perform(.media(key: .volumeUp))]))
    }

    @Test func thumbWheelActionsLeaveVerticalWheelAlone() {
        var device = settings()
        device.thumbWheel = .actions(left: .media(key: .volumeDown), right: .media(key: .volumeUp))
        var engine = RemapEngine()
        #expect(
            engine.handle(.scroll(vertical: 1, horizontal: 0, isContinuous: false), settings: device, app: nil) == .pass
        )
    }
}
