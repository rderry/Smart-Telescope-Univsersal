#if canImport(AppKit)
import AppKit
#endif
import SwiftUI

struct WindowDisplayFitModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(WindowAccessorView())
    }
}

extension View {
    func fitWindowToActiveDisplay() -> some View {
        modifier(WindowDisplayFitModifier())
    }
}

#if canImport(AppKit)
private struct WindowAccessorView: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowAccessorNSView {
        let view = WindowAccessorNSView()
        view.applyWindowConfigurationWhenReady()
        return view
    }

    func updateNSView(_ nsView: WindowAccessorNSView, context: Context) {
        nsView.applyWindowConfigurationWhenReady()
    }
}

private final class WindowAccessorNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyWindowConfigurationWhenReady()
    }

    func applyWindowConfigurationWhenReady() {
        applyWindowConfiguration()

        DispatchQueue.main.async {
            self.applyWindowConfiguration()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.applyWindowConfiguration()
        }
    }

    private func applyWindowConfiguration() {
        guard let window else { return }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.styleMask.remove(.fullSizeContentView)
        window.toolbar?.isVisible = false

        [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ]
        .forEach { button in
            button?.isHidden = false
            button?.isEnabled = true
            button?.alphaValue = 1
        }

        guard let screen = window.screen ?? NSScreen.main else { return }
        let frame = screen.visibleFrame

        if window.frame.size != frame.size {
            window.setFrame(frame, display: true, animate: false)
        }
    }
}
#else
private struct WindowAccessorView: View {
    var body: some View {
        EmptyView()
    }
}
#endif
