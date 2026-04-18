import Foundation

enum AppResourceBundle {
    static var current: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }
}
