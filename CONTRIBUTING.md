# Contributing

Thanks for helping. The most useful contribution is a profile for a mouse you own.

## Add a mouse profile

1. Build and run Whisker (see the README), then grant both permissions.
2. Pick your mouse at the top of the window. Its ID, such as `1ea7:0067`, shows next to "Connected" in the header.
3. Click **Detect Button** and press each button. A button shown as "Button 6" has `number` 5.
4. If a button does something like switching desktops or going full screen instead of showing up in Detect, the mouse types a shortcut for it. Note which shortcut and add it as `sends` (see the README). The key codes are the `kVK_` constants in Carbon's `Events.h`.
5. Copy `devices/isy-iwn-5000-1.json` to `devices/<brand>-<model>.json`, fill in what you found, and place each hotspot on the drawing by adjusting `position`.
6. Run `swift test`. It checks that every profile decodes, lists no button twice, and never remaps the left button.
7. Open a pull request with the mouse name, how it connects (receiver or Bluetooth), and a note on anything that did not work.

Only include IDs and button numbers you read from the real mouse. A guessed profile is worse than none.

## Code changes

- Behavior changes go in `Sources/WhiskerCore/RemapEngine.swift` with a test in `Tests/WhiskerCoreTests` first.
- Keep `WhiskerCore` free of AppKit, CoreGraphics and SwiftUI.
- Run `swift format -i -r Sources Tests` and `swift test` before pushing. CI runs the same checks.
- No code comments. Explain the reasoning in the pull request.
- Keep pull requests to one change.

## Reporting bugs

Open an issue with your macOS version, the mouse, how it connects, and what you expected versus what happened.
