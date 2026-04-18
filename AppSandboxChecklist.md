# App Sandbox Checklist

This project includes a native macOS 15 app target at [`AstronomyObservationPlanning.xcodeproj`](/Users/rderry/Documents/Smart%20Scope%20macos15/AstronomyObservationPlanning.xcodeproj) in addition to the Swift package build. App data is stored in `Application Support/SmartScopeObservationPlanner`, and the app gracefully falls back to in-memory storage if the persistent container cannot be opened.

Before shipping the macOS app from Xcode:

1. Open [`AstronomyObservationPlanning.xcodeproj`](/Users/rderry/Documents/Smart%20Scope%20macos15/AstronomyObservationPlanning.xcodeproj) and select the `AstronomyObservationPlanning` target.
2. Set your Apple Developer team for signing. The target already points at [`AstronomyObservationPlanning.entitlements`](/Users/rderry/Documents/Smart%20Scope%20macos15/AstronomyObservationPlanning.entitlements).
3. Keep `App Sandbox` enabled.
4. Keep `Outgoing Connections (Client)` enabled because the app uses:
   - OpenNGC catalog refresh
   - JPL comet feed refresh
   - MET Norway moon phase lookup
   - reverse geocoding for observation country lookup
5. Verify the app data container is writable and that the app can create:
   - `Application Support/SmartScopeObservationPlanner/SmartScopeObservationPlanner.store`
6. If you later add export/save panels for user-selected files, also enable the matching user-selected file access entitlement.

Notes:

- Printing uses the standard macOS print panel and does not require a custom file-system entitlement in the current design.
- Intel compatibility is intentionally enabled by building standard macOS architectures with `ONLY_ACTIVE_ARCH=NO`. Use `./script/build_and_run.sh --verify-intel` to build a Release x86_64 binary, or `./script/build_and_run.sh --verify-universal` to build and verify both `arm64` and `x86_64`.
- The Swift package build still does not apply entitlements on its own; sandbox behavior is enforced through the Xcode app target.
