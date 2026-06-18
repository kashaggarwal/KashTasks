import SwiftUI
import AppKit

/// The drifting deep-green aurora, used as the FILL of a card (clip it yourself
/// to a rounded rect). On macOS 15+ it's a true `MeshGradient`; older systems
/// get a static layered fallback that reads the same at a glance.
struct AuroraMesh: View {
    var body: some View {
        ZStack {
            Theme.auroraBase   // solid base so there's never a transparent flash
            if #available(macOS 15.0, *) {
                DriftingMesh()
            } else {
                StaticAurora()
            }
        }
    }
}

/// A 3×3 mesh whose interior control points ease around on slow sines, so the
/// light pools shift like a real aurora without ever drawing attention.
@available(macOS 15.0, *)
private struct DriftingMesh: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate)
            let a: Float = 0.07  // drift amplitude — small on purpose
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0],
                    [0.5 + a * sin(t * 0.21), 0],
                    [1, 0],
                    [0, 0.5 + a * cos(t * 0.18)],
                    [0.5 + a * sin(t * 0.13), 0.5 + a * cos(t * 0.17)],
                    [1, 0.5 + a * sin(t * 0.15)],
                    [0, 1],
                    [0.5 + a * cos(t * 0.16), 1],
                    [1, 1],
                ],
                colors: Theme.auroraMesh
            )
        }
    }
}

/// Pre-15 fallback: overlapping radial pools approximate the mesh.
private struct StaticAurora: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [Theme.auroraMoss, .clear],
                           center: .init(x: 0.25, y: 0.2), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Theme.auroraTeal, .clear],
                           center: .init(x: 0.85, y: 0.65), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Theme.auroraDeep.opacity(0.9), .clear],
                           center: .init(x: 0.6, y: 1.0), startRadius: 0, endRadius: 360)
        }
        .blur(radius: 40)
    }
}

/// The dark canvas the aurora cards float on, plus window chrome: hidden title
/// bar, content under the traffic lights, dark controls, fully opaque.
struct DashboardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Theme.canvas, Theme.canvasDeep],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        .background(WindowConfigurator())
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(Theme.canvas)
        }
    }
}

/// A reusable card: rounded, hairline, soft shadow. `dark` swaps the vibrant
/// aurora fill for a subdued dark-green gradient (used for the hero so the list
/// panel below stays the highlighted, aurora-filled focus).
struct AuroraCard<Content: View>: View {
    var cornerRadius: CGFloat = 26
    var dim: Double = 0          // darken the aurora to push a card back
    var dark: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                ZStack {
                    if dark {
                        LinearGradient(colors: [Theme.heroTop, Theme.heroBottom],
                                       startPoint: .top, endPoint: .bottom)
                    } else {
                        AuroraMesh()
                        if dim > 0 { Color.black.opacity(dim) }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.38), radius: 22, x: 0, y: 12)
    }
}
