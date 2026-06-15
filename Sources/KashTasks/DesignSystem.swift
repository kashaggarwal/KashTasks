import SwiftUI
import KashTasksCore

// Small, shared visual vocabulary so the popover and the dashboard feel like one app.
enum Theme {
    static let cardCorner: CGFloat = 12
    static let rowCorner: CGFloat = 9
    static let accent = Color.accentColor
}

extension Priority {
    /// Tuned, slightly desaturated hues so pills read as labels, not alarms.
    var color: Color {
        switch self {
        case .high:   return Color(red: 0.93, green: 0.34, blue: 0.31)
        case .medium: return Color(red: 0.95, green: 0.62, blue: 0.20)
        case .low:    return Color(red: 0.39, green: 0.55, blue: 0.93)
        }
    }
}

/// Press feedback: a subtle, fast scale-down so pressable elements feel alive.
/// (emil-design-eng: scale 0.95–0.98, fast ease-out, never animate from nothing.)
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A filled, tinted action button used for the primary "Add" / "Dashboard" actions.
struct FilledButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = Theme.accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

struct PriorityPill: View {
    let priority: Priority
    var body: some View {
        Text(priority.label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(priority.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priority.color.opacity(0.16), in: Capsule())
    }
}

/// Relative, color-coded due indicator. Red when overdue.
struct DueChip: View {
    let date: Date
    let overdue: Bool

    private var tint: Color { overdue ? Color(red: 0.93, green: 0.34, blue: 0.31) : .secondary }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: overdue ? "exclamationmark.circle.fill" : "clock")
                .font(.system(size: 9, weight: .semibold))
            Text(date.formatted(.relative(presentation: .named)))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.13), in: Capsule())
    }
}

/// A stat tile for the dashboard header (Open / Today / Overdue / Done).
struct StatCard: View {
    let value: Int
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}
