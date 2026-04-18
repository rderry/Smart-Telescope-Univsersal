import SwiftUI

enum WorkspaceBackgroundStyle {
    case image
    case metallicBlue
    case midnightBlue
    case lightMetallicBlue
    case metallicGreen
    case metallicRed
}

struct MetallicBlueBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.12, blue: 0.24),
                    Color(red: 0.10, green: 0.27, blue: 0.46),
                    Color(red: 0.03, green: 0.10, blue: 0.21)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    .clear,
                    Color.black.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.overlay)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.28),
                    .clear
                ],
                center: UnitPoint(x: 0.18, y: 0.02),
                startRadius: 18,
                endRadius: 420
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color(red: 0.62, green: 0.83, blue: 1.0).opacity(0.20),
                    .clear
                ],
                center: UnitPoint(x: 0.82, y: 0.22),
                startRadius: 28,
                endRadius: 360
            )
            .blendMode(.screen)
        }
        .clipped()
    }
}

struct MidnightBlueBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.00, green: 0.01, blue: 0.08),
                    Color(red: 0.01, green: 0.05, blue: 0.18),
                    Color(red: 0.00, green: 0.01, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.20, blue: 0.55).opacity(0.28),
                    .clear,
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.overlay)

            RadialGradient(
                colors: [
                    Color(red: 0.76, green: 0.86, blue: 1.0).opacity(0.32),
                    .clear
                ],
                center: UnitPoint(x: 0.16, y: 0.05),
                startRadius: 26,
                endRadius: 420
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.38, blue: 0.96).opacity(0.34),
                    .clear
                ],
                center: UnitPoint(x: 0.84, y: 0.22),
                startRadius: 42,
                endRadius: 400
            )
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    .clear,
                    Color(red: 0.08, green: 0.16, blue: 0.46).opacity(0.22),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .blendMode(.screen)
        }
        .clipped()
    }
}

struct LightMetallicBlueBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.62, green: 0.78, blue: 0.93),
                    Color(red: 0.78, green: 0.88, blue: 0.98),
                    Color(red: 0.55, green: 0.72, blue: 0.89)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.52),
                    .clear,
                    Color(red: 0.18, green: 0.30, blue: 0.44).opacity(0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.58),
                    .clear
                ],
                center: UnitPoint(x: 0.22, y: 0.02),
                startRadius: 12,
                endRadius: 420
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color(red: 0.90, green: 0.97, blue: 1.0).opacity(0.44),
                    .clear
                ],
                center: UnitPoint(x: 0.84, y: 0.20),
                startRadius: 24,
                endRadius: 400
            )
            .blendMode(.screen)
        }
        .clipped()
    }
}

struct MetallicGreenBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.21, blue: 0.17),
                    Color(red: 0.12, green: 0.42, blue: 0.31),
                    Color(red: 0.03, green: 0.17, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.20),
                    .clear,
                    Color.black.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.overlay)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.24),
                    .clear
                ],
                center: UnitPoint(x: 0.16, y: 0.04),
                startRadius: 18,
                endRadius: 400
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color(red: 0.56, green: 0.94, blue: 0.76).opacity(0.22),
                    .clear
                ],
                center: UnitPoint(x: 0.84, y: 0.18),
                startRadius: 28,
                endRadius: 340
            )
            .blendMode(.screen)
        }
        .clipped()
    }
}

struct MetallicRedBackgroundView: View {
    var body: some View {
        Color(red: 0.36, green: 0.06, blue: 0.08)
            .clipped()
    }
}

struct AppBackgroundImageView: View {
    var body: some View {
        ZStack {
            Image("ic405-background", bundle: AppResourceBundle.current)
                .resizable()
                .scaledToFill()
                .saturation(0.96)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.34),
                            Color(red: 0.03, green: 0.02, blue: 0.06).opacity(0.56),
                            Color.black.opacity(0.48)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.78, blue: 0.38).opacity(0.10),
                    .clear
                ],
                center: UnitPoint(x: 0.76, y: 0.34),
                startRadius: 24,
                endRadius: 340
            )
            .blendMode(.screen)
        }
        .clipped()
    }
}

private struct WorkspaceBackgroundView: View {
    let style: WorkspaceBackgroundStyle

    var body: some View {
        switch style {
        case .image:
            AppBackgroundImageView()
        case .metallicBlue:
            MetallicBlueBackgroundView()
        case .midnightBlue:
            MidnightBlueBackgroundView()
        case .lightMetallicBlue:
            LightMetallicBlueBackgroundView()
        case .metallicGreen:
            MetallicGreenBackgroundView()
        case .metallicRed:
            MetallicRedBackgroundView()
        }
    }
}

private struct WorkspacePageBackgroundModifier: ViewModifier {
    let style: WorkspaceBackgroundStyle

    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            WorkspaceBackgroundView(style: style)
                .ignoresSafeArea()
                .tahoeBackgroundExtension()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

extension View {
    func workspacePageBackground(style: WorkspaceBackgroundStyle = .image) -> some View {
        modifier(WorkspacePageBackgroundModifier(style: style))
    }
}
