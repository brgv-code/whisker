# Service architecture

| Layer | Folder | What lives there | May import |
|---|---|---|---|
| Core | `Sources/WhiskerCore` | Settings model, device profiles, `RemapEngine` (pure decisions) | Foundation only |
| Input | `Sources/Whisker/Input` | Event tap, HID device monitor, synthetic event posting, permissions | Core, CoreGraphics, IOKit, AppKit |
| Store | `Sources/Whisker/Store` | Settings file, bundled profiles, lock-shared runtime state | Core, Foundation |
| UI | `Sources/Whisker/UI` | SwiftUI views | Core, Store, AppModel |
| Wiring | `Sources/Whisker/AppModel.swift` | Creates and connects everything above | all |

Dependency direction: UI > AppModel > Input/Store > Core. Core never imports AppKit, CoreGraphics or SwiftUI; the separate module is what enforces it.

## Threads

- The input thread runs the CGEvent tap and the IOHIDManager on one run loop. `RemapEngine` and `DeviceMonitor.lastActive` live only there.
- The main thread runs the UI and `SettingsStore`.
- `RuntimeState` is the only shared state: an immutable snapshot behind one lock, written by main, read per event by the input thread.

## Adding a feature

1. New behavior on an event: add a case to `Action` or a rule to `RemapEngine`, with a test in `Tests/WhiskerCoreTests`.
2. New side effect: add it to `ActionPerformer`.
3. New setting: add it to `DeviceSettings`, then a control in `UI/Editors.swift`.
