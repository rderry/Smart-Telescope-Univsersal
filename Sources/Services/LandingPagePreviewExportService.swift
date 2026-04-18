import SwiftData
import SwiftUI

#if canImport(AppKit)
import AppKit

enum LandingPagePreviewExportService {
    @MainActor
    static func exportCurrentHomePageJPG(
        to url: URL,
        modelContainer: ModelContainer,
        runtimeState: AppRuntimeState
    ) throws {
        let renderSize = NSSize(width: 1440, height: 980)

        let rootView = MainLandingPageView(selectedSection: .constant(.home))
            .environment(runtimeState)
            .modelContainer(modelContainer)
            .font(AppTypography.body)
            .appTextOverflowGuard()
            .frame(width: renderSize.width, height: renderSize.height, alignment: .top)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: renderSize)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView = hostingView
        window.displayIfNeeded()

        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw LandingPagePreviewExportError.bitmapCreationFailed
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let jpegData = bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.92]
        ) else {
            throw LandingPagePreviewExportError.jpegEncodingFailed
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try jpegData.write(to: url, options: .atomic)
        window.orderOut(nil)
    }
}

enum EquipmentPagePreviewExportService {
    @MainActor
    static func exportEquipmentPageJPG(
        to url: URL,
        modelContainer: ModelContainer,
        runtimeState: AppRuntimeState
    ) throws {
        let renderSize = NSSize(width: 1440, height: 980)

        let rootView = ProfilesWorkspaceView(selectedSection: .constant(.profiles))
            .workspacePageBackground(style: .metallicRed)
            .environment(runtimeState)
            .modelContainer(modelContainer)
            .font(AppTypography.body)
            .appTextOverflowGuard()
            .frame(width: renderSize.width, height: renderSize.height, alignment: .top)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: renderSize)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView = hostingView
        window.displayIfNeeded()

        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw LandingPagePreviewExportError.bitmapCreationFailed
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let jpegData = bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.92]
        ) else {
            throw LandingPagePreviewExportError.jpegEncodingFailed
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try jpegData.write(to: url, options: .atomic)
        window.orderOut(nil)
    }
}

enum LandingPagePreviewExportError: LocalizedError {
    case bitmapCreationFailed
    case jpegEncodingFailed

    var errorDescription: String? {
        switch self {
        case .bitmapCreationFailed:
            "Could not create a bitmap for the landing page preview."
        case .jpegEncodingFailed:
            "Could not encode the landing page preview as a JPG."
        }
    }
}
#endif
