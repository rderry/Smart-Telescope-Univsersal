import SwiftUI

struct AppTextOverflowGuard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .lineLimit(3)
            .truncationMode(.tail)
            .allowsTightening(true)
    }
}

extension View {
    func appTextOverflowGuard() -> some View {
        modifier(AppTextOverflowGuard())
    }
}
