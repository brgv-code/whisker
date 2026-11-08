# Whisker

Customize the buttons, wheels and gestures of any mouse on macOS, the way Logitech Options does for Logitech mice.

Whisker started because the ISY IWN-5000-1 ships with extra buttons and a thumb wheel but no software to change what they do. It works with other mice too: if macOS sees a button, Whisker can remap it.

## What it does

- **Remap any button** to a keyboard shortcut, Mission Control, App Exposé, Show Desktop, switching desktops, back and forward, media keys, another mouse button, or nothing.
- **Gesture button.** Hold a button and move the mouse up, down, left or right to run a different action for each direction. A press without moving is a click.
- **Thumb wheel.** Keep it as sideways scrolling, or turn each notch into an action (volume, switching tabs, anything above).
- **Scrolling for the mouse only.** Reverse the wheel or change its speed without touching your trackpad's Natural Scrolling.
- **Per-app settings.** Give a button a different job in a specific app.
- **Several mice.** Each mouse keeps its own settings, matched by its USB or Bluetooth ID.

Everything runs on your Mac. Whisker never writes to the mouse's own memory.

## Install

Requires macOS 14 or later and Xcode command line tools.

```sh
git clone <this repo>
cd whisker
./scripts/bundle.sh
open build/Whisker.app
```

Whisker lives in the menu bar. On first launch it asks for two permissions in **System Settings > Privacy & Security**:

| Permission | Why |
|---|---|
| Accessibility | To change what buttons and wheels do. |
| Input Monitoring | To tell which mouse an event came from, so settings for one mouse never affect another. |

`bundle.sh` signs with your Apple Development certificate when you have one. With ad-hoc signing macOS forgets both permissions after every rebuild, so you will need to remove and re-add Whisker in System Settings.

## Add your mouse

Whisker works with any mouse without a profile: pick it in the sidebar, click **Detect Button**, press a button, and it appears in the list.

A profile adds names and a diagram. Profiles live in [`devices/`](devices/), one JSON file per model:

```json
{
  "name": "ISY IWN-5000-1",
  "devices": ["1ea7:0067"],
  "buttons": [
    { "number": 3, "label": "Back", "position": { "x": 0.1, "y": 0.66 } }
  ],
  "thumbWheel": { "x": 0.1, "y": 0.46 }
}
```

- `devices`: vendor and product ID in hex. Whisker shows them under the mouse name in the sidebar. A model with a receiver and Bluetooth has two.
- `number`: the macOS button number. 1 is right click, 2 the wheel, 3 back, 4 forward. Use **Detect Button** to find the rest: a button shown as "Button 6" has number 5.
- `position`: where the hotspot sits on the diagram, 0 to 1 from the top left.

Run `swift test` before opening a pull request. It checks every profile in `devices/`.

## Development

```sh
swift build            # compile
swift test             # engine and profile tests
swift format -i -r Sources Tests
./scripts/bundle.sh    # build the .app
```

The remapping logic lives in `Sources/WhiskerCore` and has no macOS UI dependencies, so it is fully unit tested. See [`agent_docs/service_architecture.md`](agent_docs/service_architecture.md) for how the pieces fit.

## Known limits

- Remapping happens on the Mac, so it only works while Whisker runs. DPI and polling rate live in the mouse firmware and are not supported.
- macOS does not say which mouse sent an event, so Whisker follows the mouse that moved last. Switching mice and clicking within the same instant can apply the wrong mouse's settings to that one click.
- Buttons the mouse handles internally (often the DPI button) never reach macOS and cannot be remapped.

## License

MIT
