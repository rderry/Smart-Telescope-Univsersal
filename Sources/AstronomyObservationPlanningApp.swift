import SwiftData
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@main
struct AstronomyObservationPlanningApp: App {
    private let modelContainer: ModelContainer
    private let launchMode: AppLaunchMode
    @State private var runtimeState: AppRuntimeState

    init() {
        launchMode = AppLaunchMode(arguments: ProcessInfo.processInfo.arguments)
        let bootstrap = ModelContainerFactory.makeSharedContainerBootstrap()
        modelContainer = bootstrap.container
        _runtimeState = State(initialValue: AppRuntimeState(storageWarning: bootstrap.storageWarning))
    }

    var body: some Scene {
        Window("Smart Scope Observation Planner", id: "main") {
            switch launchMode {
            case .normal:
                AppShellView()
                    .environment(runtimeState)
                    .font(AppTypography.body)
                    .appTextOverflowGuard()
                    .frame(minWidth: 1240, minHeight: 820)
                    .fitWindowToActiveDisplay()
            case .exportHomeJPG(let url):
                LandingPagePreviewExportRunnerView(
                    exportURL: url,
                    modelContainer: modelContainer,
                    runtimeState: runtimeState
                )
                .frame(width: 10, height: 10)
            case .exportEquipmentJPG(let url):
                EquipmentPagePreviewExportRunnerView(
                    exportURL: url,
                    modelContainer: modelContainer,
                    runtimeState: runtimeState
                )
                .frame(width: 10, height: 10)
            }
        }
        .modelContainer(modelContainer)
    }
}

private enum AppLaunchMode {
    case normal
    case exportHomeJPG(URL)
    case exportEquipmentJPG(URL)

    init(arguments: [String]) {
        if let exportFlagIndex = arguments.firstIndex(of: "--export-home-jpg") {
            let outputPathIndex = arguments.index(after: exportFlagIndex)
            guard arguments.indices.contains(outputPathIndex) else {
                self = .normal
                return
            }

            self = .exportHomeJPG(URL(fileURLWithPath: arguments[outputPathIndex]))
            return
        }

        if let exportFlagIndex = arguments.firstIndex(of: "--export-equipment-jpg") {
            let outputPathIndex = arguments.index(after: exportFlagIndex)
            guard arguments.indices.contains(outputPathIndex) else {
                self = .normal
                return
            }

            self = .exportEquipmentJPG(URL(fileURLWithPath: arguments[outputPathIndex]))
            return
        }

        guard arguments.firstIndex(of: "--export-home-jpg") == nil else {
            self = .normal
            return
        }
        self = .normal
    }
}

private struct LandingPagePreviewExportRunnerView: View {
    let exportURL: URL
    let modelContainer: ModelContainer
    let runtimeState: AppRuntimeState
    @State private var exportStarted = false

    var body: some View {
        Color.clear
            .task {
                guard !exportStarted else { return }
                exportStarted = true
                await runExport()
            }
    }

    @MainActor
    private func runExport() async {
        do {
            try LandingPagePreviewExportService.exportCurrentHomePageJPG(
                to: exportURL,
                modelContainer: modelContainer,
                runtimeState: runtimeState
            )
            print("Exported landing page JPG to \(exportURL.path)")
        } catch {
            fputs("Landing page export failed: \(error.localizedDescription)\n", stderr)
        }

        #if canImport(AppKit)
        NSApplication.shared.terminate(nil)
        #endif
    }
}

private struct EquipmentPagePreviewExportRunnerView: View {
    let exportURL: URL
    let modelContainer: ModelContainer
    let runtimeState: AppRuntimeState
    @State private var exportStarted = false

    var body: some View {
        Color.clear
            .task {
                guard !exportStarted else { return }
                exportStarted = true
                await runExport()
            }
    }

    @MainActor
    private func runExport() async {
        do {
            try EquipmentPagePreviewExportService.exportEquipmentPageJPG(
                to: exportURL,
                modelContainer: modelContainer,
                runtimeState: runtimeState
            )
            print("Exported equipment page JPG to \(exportURL.path)")
        } catch {
            fputs("Equipment page export failed: \(error.localizedDescription)\n", stderr)
        }

        #if canImport(AppKit)
        NSApplication.shared.terminate(nil)
        #endif
    }
}
