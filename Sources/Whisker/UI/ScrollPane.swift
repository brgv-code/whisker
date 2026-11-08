import SwiftUI
import WhiskerCore

struct ScrollPane: View {
    let device: DeviceID
    let isAppScope: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        let scroll = model.store.deviceSettings(for: device).scroll
        Form {
            Section {
                Toggle("Reverse wheel", isOn: binding(\.reverseVertical, scroll))
                Toggle("Reverse thumb wheel", isOn: binding(\.reverseHorizontal, scroll))
                LabeledContent("Speed") {
                    HStack {
                        Slider(value: binding(\.speed, scroll), in: 0.25...4, step: 0.25)
                        Text(scroll.speed, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                            .frame(width: 36)
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
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 12)
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
