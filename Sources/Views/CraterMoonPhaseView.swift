import SwiftUI

/// Renders a crater-textured moon disk with an illumination mask derived from the moon phase.
/// The goal is a "realistic enough" moon at small icon sizes without shipping large texture assets.
struct CraterMoonPhaseView: View {
    let phaseDegrees: Double

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let diskRect = rect.insetBy(dx: 1, dy: 1)
            let diskPath = Path(ellipseIn: diskRect)

            var diskContext = context
            diskContext.clip(to: diskPath)

            drawDarkSide(into: &diskContext, rect: diskRect)

            var litContext = diskContext
            let litMask = MoonIlluminationMask(phaseDegrees: phaseDegrees).path(in: diskRect)
            litContext.clip(to: litMask)
            drawLitSide(into: &litContext, rect: diskRect)

            // Subtle limb shading for a more spherical look.
            let limbGradient = Gradient(colors: [
                Color.white.opacity(0.06),
                Color.black.opacity(0.22)
            ])
            diskContext.fill(
                diskPath,
                with: .radialGradient(
                    limbGradient,
                    center: CGPoint(x: diskRect.midX * 0.82, y: diskRect.midY * 0.74),
                    startRadius: min(diskRect.width, diskRect.height) * 0.12,
                    endRadius: min(diskRect.width, diskRect.height) * 0.64
                )
            )

            let outlineContext = context
            outlineContext.stroke(diskPath, with: .color(.white.opacity(0.22)), lineWidth: 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .drawingGroup()
    }

    private func drawDarkSide(into context: inout GraphicsContext, rect: CGRect) {
        var fillPath = Path()
        fillPath.addRect(rect)
        context.fill(fillPath, with: .color(Color(red: 0.10, green: 0.11, blue: 0.14)))
        MoonSurfaceRenderer.drawMare(into: &context, rect: rect, intensity: 0.28)
        MoonSurfaceRenderer.drawCraters(into: &context, rect: rect, intensity: 0.28)
    }

    private func drawLitSide(into context: inout GraphicsContext, rect: CGRect) {
        var fillPath = Path()
        fillPath.addRect(rect)
        context.fill(fillPath, with: .color(Color(red: 0.82, green: 0.83, blue: 0.86)))
        MoonSurfaceRenderer.drawMare(into: &context, rect: rect, intensity: 0.60)
        MoonSurfaceRenderer.drawCraters(into: &context, rect: rect, intensity: 0.64)
    }
}

/// Compact moon icon used in the "moon/bortle" blocks.
struct CraterMoonPhaseIconButton: View {
    let snapshot: MoonPhaseSnapshot
    let backgroundStyle: WorkspaceBackgroundStyle
    let size: CGFloat
    let locationName: String?
    let bortleText: String?

    @State private var isPresented = false

    init(
        snapshot: MoonPhaseSnapshot,
        backgroundStyle: WorkspaceBackgroundStyle,
        size: CGFloat = 58,
        locationName: String? = nil,
        bortleText: String? = nil
    ) {
        self.snapshot = snapshot
        self.backgroundStyle = backgroundStyle
        self.size = size
        self.locationName = locationName
        self.bortleText = bortleText
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.32))

                CraterMoonPhaseView(phaseDegrees: snapshot.phaseDegrees)
                    .padding(size * 0.13)

                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .help("Open Moon Details")
        .sheet(isPresented: $isPresented) {
            MoonDetailSheet(
                snapshot: snapshot,
                locationName: locationName,
                bortleText: bortleText,
                backgroundStyle: backgroundStyle
            )
            .presentationBackground(.clear)
        }
    }
}

private struct MoonDetailSheet: View {
    let snapshot: MoonPhaseSnapshot
    let locationName: String?
    let bortleText: String?
    let backgroundStyle: WorkspaceBackgroundStyle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            backgroundView
                .ignoresSafeArea()
                .tahoeBackgroundExtension()

            VStack(spacing: 14) {
                MoonSheetStopLightBar {
                    dismiss()
                }

                CraterMoonPhaseView(phaseDegrees: snapshot.phaseDegrees)
                    .frame(width: 240, height: 240)

                VStack(spacing: 6) {
                    Text(snapshot.phaseName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.yellow)
                        .multilineTextAlignment(.center)

                    if let locationName, !locationName.isEmpty {
                        Text(locationName)
                            .font(AppTypography.bodyEmphasized)
                            .foregroundStyle(.white.opacity(0.92))
                            .multilineTextAlignment(.center)
                    }

                    if let bortleText, !bortleText.isEmpty {
                        Text(bortleText)
                            .font(AppTypography.body)
                            .foregroundStyle(.white.opacity(0.86))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 22, y: 12)
            .padding(22)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch backgroundStyle {
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

private struct MoonSheetStopLightBar: View {
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.37, blue: 0.33))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(.black.opacity(0.18), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Circle()
                .fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(.black.opacity(0.18), lineWidth: 0.5)
                )
                .accessibilityLabel("Minimize (not available)")

            Circle()
                .fill(Color(red: 0.18, green: 0.78, blue: 0.35))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(.black.opacity(0.18), lineWidth: 0.5)
                )
                .accessibilityLabel("Zoom (not available)")

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MoonIlluminationMask: Shape {
    let phaseDegrees: Double

    func path(in rect: CGRect) -> Path {
        let normalized = normalizedDegrees(phaseDegrees)
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let phaseRadians = normalized * .pi / 180
        let cosPhase = cos(phaseRadians)
        let k = abs(cosPhase)
        let waxing = normalized < 180

        let outerSign: Double = waxing ? 1 : -1

        let terminatorSign: Double = switch (waxing, cosPhase >= 0) {
        case (true, true):
            1 // waxing crescent: terminator is the right side of the ellipse
        case (true, false):
            -1 // waxing gibbous: terminator is the left side of the ellipse
        case (false, true):
            -1 // waning crescent: terminator is the left side of the ellipse
        case (false, false):
            1 // waning gibbous: terminator is the right side of the ellipse
        }

        let steps = 90
        var points: [CGPoint] = []
        points.reserveCapacity((steps + 1) * 2)

        // Limb boundary: top -> bottom along the lit-side semicircle.
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let theta = (-Double.pi / 2) + (Double.pi * t)
            let x = outerSign * cos(theta) * Double(radius)
            let y = sin(theta) * Double(radius)
            points.append(CGPoint(x: center.x + CGFloat(x), y: center.y + CGFloat(y)))
        }

        // Terminator boundary: bottom -> top along the phase ellipse side.
        for step in stride(from: steps, through: 0, by: -1) {
            let t = Double(step) / Double(steps)
            let theta = (-Double.pi / 2) + (Double.pi * t)
            let x = terminatorSign * cos(theta) * Double(radius) * k
            let y = sin(theta) * Double(radius)
            points.append(CGPoint(x: center.x + CGFloat(x), y: center.y + CGFloat(y)))
        }

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func normalizedDegrees(_ value: Double) -> Double {
        var adjusted = value.truncatingRemainder(dividingBy: 360)
        if adjusted < 0 { adjusted += 360 }
        return adjusted
    }
}

private enum MoonSurfaceRenderer {
    private struct MarePatch: Hashable {
        let x: Double
        let y: Double
        let radius: Double
        let opacity: Double
    }

    private struct Crater: Hashable {
        let x: Double
        let y: Double
        let radius: Double
        let depth: Double
        let rim: Double
    }

    private static let mare: [MarePatch] = makeMare(seed: 0xBEE5, count: 9)
    private static let craters: [Crater] = makeCraters(seed: 0xC0FFEE, count: 110)

    static func drawMare(into context: inout GraphicsContext, rect: CGRect, intensity: Double) {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        for patch in mare {
            let patchCenter = CGPoint(
                x: center.x + CGFloat(patch.x) * radius,
                y: center.y + CGFloat(patch.y) * radius
            )
            let patchRadius = CGFloat(patch.radius) * radius
            let mareRect = CGRect(
                x: patchCenter.x - patchRadius,
                y: patchCenter.y - patchRadius,
                width: patchRadius * 2,
                height: patchRadius * 2
            )
            let path = Path(ellipseIn: mareRect)
            let alpha = min(max(patch.opacity * intensity, 0), 1)
            context.fill(path, with: .color(Color.black.opacity(alpha * 0.22)))
        }
    }

    static func drawCraters(into context: inout GraphicsContext, rect: CGRect, intensity: Double) {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        for crater in craters {
            let craterCenter = CGPoint(
                x: center.x + CGFloat(crater.x) * radius,
                y: center.y + CGFloat(crater.y) * radius
            )
            let craterRadius = CGFloat(crater.radius) * radius
            let craterRect = CGRect(
                x: craterCenter.x - craterRadius,
                y: craterCenter.y - craterRadius,
                width: craterRadius * 2,
                height: craterRadius * 2
            )
            let path = Path(ellipseIn: craterRect)

            let depthAlpha = min(max(crater.depth * intensity, 0), 1)
            let rimAlpha = min(max(crater.rim * intensity, 0), 1)

            let shading = Gradient(colors: [
                Color.black.opacity(0.28 * depthAlpha),
                Color.black.opacity(0.10 * depthAlpha),
                Color.black.opacity(0.18 * depthAlpha)
            ])

            context.fill(
                path,
                with: .radialGradient(
                    shading,
                    center: CGPoint(
                        x: craterCenter.x - craterRadius * 0.18,
                        y: craterCenter.y - craterRadius * 0.18
                    ),
                    startRadius: craterRadius * 0.05,
                    endRadius: craterRadius
                )
            )

            if craterRadius > 2 {
                context.stroke(path, with: .color(Color.white.opacity(0.10 * rimAlpha)), lineWidth: 0.85)
                context.stroke(path, with: .color(Color.black.opacity(0.14 * rimAlpha)), lineWidth: 0.45)
            }
        }
    }

    private static func makeMare(seed: UInt64, count: Int) -> [MarePatch] {
        var generator = SeededRandomNumberGenerator(seed: seed)
        var patches: [MarePatch] = []
        patches.reserveCapacity(count)

        while patches.count < count {
            let x = generator.nextDouble(in: -0.55...0.55)
            let y = generator.nextDouble(in: -0.55...0.55)
            let distance = (x * x + y * y).squareRoot()
            guard distance <= 0.70 else { continue }
            patches.append(
                MarePatch(
                    x: x,
                    y: y,
                    radius: generator.nextDouble(in: 0.14...0.28),
                    opacity: generator.nextDouble(in: 0.28...0.78)
                )
            )
        }

        return patches
    }

    private static func makeCraters(seed: UInt64, count: Int) -> [Crater] {
        var generator = SeededRandomNumberGenerator(seed: seed)
        var craters: [Crater] = []
        craters.reserveCapacity(count)

        while craters.count < count {
            let x = generator.nextDouble(in: -0.85...0.85)
            let y = generator.nextDouble(in: -0.85...0.85)
            let distance = (x * x + y * y).squareRoot()
            guard distance <= 0.95 else { continue }

            let radius = generator.nextDouble(in: 0.02...0.11)
            let depth = generator.nextDouble(in: 0.35...0.92)
            let rim = generator.nextDouble(in: 0.28...0.74)

            craters.append(
                Crater(
                    x: x,
                    y: y,
                    radius: radius,
                    depth: depth,
                    rim: rim
                )
            )
        }

        return craters
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid a zero state for the LCG.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let maxValue = Double(UInt64.max)
        let unit = Double(next()) / maxValue
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}
