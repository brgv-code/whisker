import SwiftUI
import WhiskerCore

struct MouseDiagram: View {
    let rows: [ControlRow]
    let thumbWheel: DeviceProfile.Point?
    @Binding var selected: Control?

    private let size = CGSize(width: 200, height: 300)

    var body: some View {
        ZStack(alignment: .topLeading) {
            MouseShape().fill(.quaternary)
            MouseShape().stroke(.secondary, lineWidth: 1.5)
            Path { path in
                path.move(to: CGPoint(x: 105, y: 10))
                path.addLine(to: CGPoint(x: 105, y: 110))
            }
            .stroke(.secondary.opacity(0.6), lineWidth: 1)
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(0.5))
                .frame(width: 14, height: 44)
                .position(x: 105, y: 66)

            ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                if let position = row.position {
                    hotspot(index + 1, control: .button(row.number), at: position)
                }
            }
            if let thumbWheel {
                hotspot(rows.count + 1, control: .thumbWheel, at: thumbWheel)
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mouse diagram")
    }

    private func hotspot(_ index: Int, control: Control, at point: DeviceProfile.Point) -> some View {
        let isSelected = selected == control
        return Button {
            selected = control
        } label: {
            Text("\(index)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(Circle().fill(isSelected ? Color.accentColor : Color(nsColor: .windowBackgroundColor)))
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .position(x: point.x * size.width, y: point.y * size.height)
    }
}

/// A generic ergonomic mouse seen from above, with the thumb rest on the left.
private struct MouseShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 200
        let scaleY = rect.height / 300
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }
        var path = Path()
        path.move(to: point(105, 8))
        path.addCurve(to: point(188, 120), control1: point(160, 8), control2: point(190, 60))
        path.addCurve(to: point(150, 292), control1: point(186, 200), control2: point(178, 280))
        path.addCurve(to: point(40, 285), control1: point(115, 302), control2: point(65, 300))
        path.addCurve(to: point(6, 190), control1: point(15, 270), control2: point(0, 230))
        path.addCurve(to: point(28, 70), control1: point(12, 150), control2: point(16, 100))
        path.addCurve(to: point(105, 8), control1: point(40, 35), control2: point(70, 8))
        path.closeSubpath()
        return path
    }
}
