import SwiftUI
import WhiskerCore

enum Control: Hashable {
    case button(Int)
    case thumbWheel
}

struct ControlRow: Identifiable, Hashable {
    var control: Control
    var label: String
    var summary: String
    var defaultTitle = ""
    var position: DeviceProfile.Point?
    var id: Control { control }
}

struct DeviceCanvas: View {
    let rows: [ControlRow]
    @Binding var selected: Control?

    private static let size = CGSize(width: 720, height: 480)
    private static let mouse = CGRect(x: 250, y: 55, width: 220, height: 330)
    nonisolated private static let calloutWidth = 210.0
    private static let calloutGap = 70.0

    private struct Callout: Identifiable {
        let row: ControlRow
        let anchor: CGPoint
        let isLeft: Bool
        var y: Double
        var id: Control { row.control }
        var edge: CGPoint { CGPoint(x: isLeft ? 10 + DeviceCanvas.calloutWidth : 500, y: y) }
        var center: CGPoint {
            CGPoint(x: isLeft ? 10 + DeviceCanvas.calloutWidth / 2 : 500 + DeviceCanvas.calloutWidth / 2, y: y)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(1, geometry.size.width / Self.size.width, geometry.size.height / Self.size.height)
            ZStack(alignment: .topLeading) {
                ForEach(callouts) { callout in
                    let isSelected = selected == callout.row.control
                    Path { path in
                        path.move(to: callout.anchor)
                        path.addLine(to: callout.edge)
                    }
                    .stroke(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.45), lineWidth: isSelected ? 1.5 : 1)
                }
                MouseIllustration()
                    .frame(width: Self.mouse.width, height: Self.mouse.height)
                    .offset(x: Self.mouse.minX, y: Self.mouse.minY)
                ForEach(callouts.filter { $0.anchor.x < Self.mouse.minX + Self.mouse.width * 0.25 }) { callout in
                    SideDetail(isWheel: callout.row.control == .thumbWheel).position(callout.anchor)
                }
                ForEach(callouts) { callout in
                    hotspot(callout)
                    card(callout)
                }
            }
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
            .scaleEffect(scale)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var callouts: [Callout] {
        let placed = rows.compactMap { row -> Callout? in
            guard let position = row.position else { return nil }
            let anchor = CGPoint(
                x: Self.mouse.minX + position.x * Self.mouse.width, y: Self.mouse.minY + position.y * Self.mouse.height)
            return Callout(row: row, anchor: anchor, isLeft: position.x < 0.5, y: anchor.y)
        }
        return Self.spread(placed.filter(\.isLeft)) + Self.spread(placed.filter { !$0.isLeft })
    }

    private static func spread(_ column: [Callout]) -> [Callout] {
        var sorted = column.sorted { $0.anchor.y < $1.anchor.y }
        var nextFree = 40.0
        for index in sorted.indices {
            sorted[index].y = max(sorted[index].anchor.y, nextFree)
            nextFree = sorted[index].y + calloutGap
        }
        let overflow = (sorted.last?.y ?? 0) - (size.height - 40)
        if overflow > 0 {
            for index in sorted.indices { sorted[index].y -= overflow }
        }
        return sorted
    }

    private func hotspot(_ callout: Callout) -> some View {
        let isSelected = selected == callout.row.control
        return Button {
            selected = callout.row.control
        } label: {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.white)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                .padding(8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(callout.anchor)
        .accessibilityLabel(callout.row.label)
    }

    private func card(_ callout: Callout) -> some View {
        let isSelected = selected == callout.row.control
        return Button {
            selected = callout.row.control
        } label: {
            VStack(alignment: callout.isLeft ? .trailing : .leading, spacing: 2) {
                Text(callout.row.label).font(.caption).foregroundStyle(.secondary)
                Text(callout.row.summary).font(.callout.weight(.semibold)).lineLimit(2)
                    .multilineTextAlignment(callout.isLeft ? .trailing : .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: Self.calloutWidth, alignment: callout.isLeft ? .trailing : .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(callout.center)
    }
}

private struct SideDetail: View {
    let isWheel: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.5), Color(white: 0.28)], startPoint: .leading, endPoint: .trailing)
            )
            .frame(width: isWheel ? 13 : 10, height: isWheel ? 34 : 24)
            .overlay {
                if isWheel {
                    VStack(spacing: 3) {
                        ForEach(0..<6, id: \.self) { _ in Rectangle().fill(.black.opacity(0.3)).frame(height: 1) }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
    }
}

private struct MouseIllustration: View {
    var body: some View {
        ZStack {
            UnitShape(build: Self.body)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.34), Color(white: 0.13)], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .black.opacity(0.3), radius: 18, y: 14)
            UnitShape(build: Self.body)
                .fill(LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center))
            UnitShape { path in
                path.move(to: CGPoint(x: 105, y: 10))
                path.addLine(to: CGPoint(x: 105, y: 112))
                path.move(to: CGPoint(x: 30, y: 116))
                path.addQuadCurve(to: CGPoint(x: 186, y: 116), control: CGPoint(x: 108, y: 132))
            }
            .stroke(.black.opacity(0.35), lineWidth: 1.2)
            UnitShape { path in
                path.addRoundedRect(
                    in: CGRect(x: 97, y: 40, width: 16, height: 48), cornerSize: CGSize(width: 7, height: 7))
            }
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.55), Color(white: 0.25)], startPoint: .leading, endPoint: .trailing))
            UnitShape { path in
                for ridge in stride(from: 46.0, through: 82, by: 6) {
                    path.move(to: CGPoint(x: 99, y: ridge))
                    path.addLine(to: CGPoint(x: 111, y: ridge))
                }
            }
            .stroke(.black.opacity(0.3), lineWidth: 1)
            UnitShape(build: Self.body).stroke(.white.opacity(0.1), lineWidth: 1)
        }
    }

    private static let body: @Sendable (inout Path) -> Void = { path in
        path.move(to: CGPoint(x: 105, y: 8))
        path.addCurve(to: CGPoint(x: 188, y: 120), control1: CGPoint(x: 160, y: 8), control2: CGPoint(x: 190, y: 60))
        path.addCurve(to: CGPoint(x: 150, y: 292), control1: CGPoint(x: 186, y: 200), control2: CGPoint(x: 178, y: 280))
        path.addCurve(to: CGPoint(x: 40, y: 285), control1: CGPoint(x: 115, y: 302), control2: CGPoint(x: 65, y: 300))
        path.addCurve(to: CGPoint(x: 6, y: 190), control1: CGPoint(x: 15, y: 270), control2: CGPoint(x: 0, y: 230))
        path.addCurve(to: CGPoint(x: 28, y: 70), control1: CGPoint(x: 12, y: 150), control2: CGPoint(x: 16, y: 100))
        path.addCurve(to: CGPoint(x: 105, y: 8), control1: CGPoint(x: 40, y: 35), control2: CGPoint(x: 70, y: 8))
        path.closeSubpath()
    }
}

private struct UnitShape: Shape {
    let build: @Sendable (inout Path) -> Void

    func path(in rect: CGRect) -> Path {
        var path = Path()
        build(&path)
        let transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / 200, y: rect.height / 300)
        return path.applying(transform)
    }
}
