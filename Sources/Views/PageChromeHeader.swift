import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct PageChromeHeader: View {
    var title: String? = nil
    var titleFont: Font = AppTypography.bodyEmphasized
    var titleColor: Color = .secondary
    var showsHomeButton = false
    var onHome: (() -> Void)? = nil

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                headerTitle

                Spacer(minLength: 0)

                trailingControls
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    headerTitle
                    Spacer(minLength: 12)
                    trailingControls
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var headerTitle: some View {
        if let title {
            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var trailingControls: some View {
        HStack(spacing: 10) {
            if showsHomeButton, let onHome {
                Button {
                    onHome()
                } label: {
                    Label("Home", systemImage: "house")
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            betaBadge
        }
    }

    private var betaBadge: some View {
        BuildBadgeView()
    }
}

struct WindowControlCluster: View {
    var body: some View {
        HStack(spacing: 6) {
            WindowControlDot(color: Color(red: 1.0, green: 0.37, blue: 0.33)) {
                WindowCommand.close.perform()
            }

            WindowControlDot(color: Color(red: 1.0, green: 0.74, blue: 0.18)) {
                WindowCommand.minimize.perform()
            }

            WindowControlDot(color: Color(red: 0.18, green: 0.78, blue: 0.35)) {
                WindowCommand.zoom.perform()
            }
        }
    }
}

private struct WindowControlDot: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(.black.opacity(0.18), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

private enum WindowCommand {
    case close
    case minimize
    case zoom

    @MainActor
    func perform() {
        #if canImport(AppKit)
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }

        switch self {
        case .close:
            window.performClose(nil)
        case .minimize:
            window.performMiniaturize(nil)
        case .zoom:
            window.performZoom(nil)
        }
        #endif
    }
}

struct BuildBadgeView: View {
    var body: some View {
        if !AppBuildInfo.releaseLabel.isEmpty {
            Text(AppBuildInfo.releaseLabel)
                .font(.system(size: 12.8, weight: .regular, design: .rounded))
                .foregroundStyle(appBrandRed)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(appBrandRed.opacity(0.42), lineWidth: 1)
                )
        }
    }
}

struct FooterCreditView: View {
    var body: some View {
        Text(AppBuildInfo.footerCredit)
            .font(.system(size: 12.8, weight: .regular, design: .rounded))
            .foregroundStyle(appBrandRed)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(appBrandRed.opacity(0.42), lineWidth: 1)
            )
    }
}

private let appBrandRed = Color(red: 1.0, green: 0.12, blue: 0.12)
