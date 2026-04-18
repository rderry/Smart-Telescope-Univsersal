import SwiftUI

enum AppTypography {
    static let body = Font.system(size: 16)
    static let bodyEmphasized = Font.system(size: 16, weight: .semibold)
    static let bodyStrong = Font.system(size: 16, weight: .bold)
    static let sectionTitle = Font.system(size: 16, weight: .semibold)
    static let screenTitle = Font.system(size: 32, weight: .bold, design: .rounded)
}
