import Foundation

enum AppBuildInfo {
    static let footerCredit = "© BigSkyAstro 2026"

    static var releaseLabel: String {
        guard let marketingVersion = bundleValue(for: "CFBundleShortVersionString") else {
            return ""
        }

        guard let buildVersion = bundleValue(for: "CFBundleVersion"),
              buildVersion != marketingVersion else {
            return "Version \(marketingVersion)"
        }

        return "Version \(marketingVersion) (\(buildVersion))"
    }

    private static func bundleValue(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
