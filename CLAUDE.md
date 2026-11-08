# Whisker

macOS mouse customizer (SwiftUI menu bar app, Swift Package).

- Build: `swift build`. Test: `swift test`. Format: `swift format -i -r Sources Tests`. App: `./scripts/bundle.sh`.
- Architecture and threading rules: `agent_docs/service_architecture.md`. Read it before adding a layer or touching `Input/`.
- Any change to remapping behavior goes into `RemapEngine` with a test first. Keep `WhiskerCore` free of AppKit and CoreGraphics.
- Never ship a device profile with IDs or button numbers that were not read from real hardware.
