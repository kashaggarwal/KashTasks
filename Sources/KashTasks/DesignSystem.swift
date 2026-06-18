import SwiftUI
import KashTasksCore

// Small, shared visual vocabulary so the popover and the dashboard feel like one app.
enum Theme {
    static let cardCorner: CGFloat = 18
    static let rowCorner: CGFloat = 12
    static let accent = Color(red: 0.30, green: 0.85, blue: 0.55)  // mint/moss

    // MARK: Canvas (the dark base the aurora cards float on)
    static let canvas = Color(red: 0.02, green: 0.07, blue: 0.05)
    static let canvasDeep = Color(red: 0.01, green: 0.04, blue: 0.03)

    // MARK: Hero card (the subdued dark panel above the highlighted list)
    static let heroTop = Color(red: 0.06, green: 0.17, blue: 0.13)
    static let heroBottom = Color(red: 0.03, green: 0.09, blue: 0.07)

    // MARK: Aurora palette (deep, moody greens)
    static let auroraBase = Color(red: 0.02, green: 0.11, blue: 0.08)
    static let auroraDeep = Color(red: 0.04, green: 0.24, blue: 0.18)
    static let auroraTeal = Color(red: 0.05, green: 0.42, blue: 0.34)
    static let auroraMoss = Color(red: 0.18, green: 0.66, blue: 0.42)

    /// 9 colors (row-major) for the 3×3 aurora mesh.
    static let auroraMesh: [Color] = [
        auroraDeep, auroraTeal, auroraBase,
        auroraTeal, auroraMoss, auroraDeep,
        auroraBase, auroraDeep, auroraTeal,
    ]

    /// Translucent surfaces that float on the aurora.
    static let surface = Color.black.opacity(0.22)
    static let surfaceStroke = Color.white.opacity(0.10)
    static let softShadow = Color.black.opacity(0.28)
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

/// One stat in the inline header strip (icon · big number · label), styled
/// after the reference card's Rating/Posts/Followers row.
struct StatItem: View {
    let value: Int
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.bottom, 2)
            Text("\(value)")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


/// The signature CTA from the design reference: a dark gradient pill with a
/// circular arrow badge. Used for the dashboard's primary "Add" action.
struct GradientPillButton: View {
    let title: String
    var systemImage: String = "arrow.right"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(.white)
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                }
                .frame(width: 24, height: 24)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 6)
            .padding(.trailing, 16)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.92), Theme.auroraDeep],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}
