Hands Off (Mac) - Dev Notes

This repo contains the Swift source files for the macOS menu bar app.

Quick setup in Xcode
1) File -> New -> Project -> App (macOS).
2) Name: HandsOff (or your preferred name). Interface: SwiftUI. Language: Swift.
3) Set Deployment Target to macOS 13.0.
4) Add the files from `HandsOff/` into the Xcode project.
5) Set the app's Info.plist to include `NSCameraUsageDescription`
   (see `HandsOff/Supporting/Info.plist`).
6) Enable App Sandbox + Camera in Signing & Capabilities
   (see `HandsOff/Supporting/HandsOff.entitlements`).
7) Build and run.

Useful CLI commands
- Generate the Xcode project: `xcodegen`
- Build the app: `xcodebuild -project HandsOff.xcodeproj -scheme HandsOff -configuration Debug -destination 'platform=macOS' -derivedDataPath .build build`
- Launch the built app: `open .build/Build/Products/Debug/HandsOff.app`
- Relaunch (kill + open): `killall HandsOff || true` then `open .build/Build/Products/Debug/HandsOff.app`
- Always rebuild + relaunch after changes: run the build command, then the relaunch command above.
- One-time Xcode setup (if xcodebuild fails): `sudo xcodebuild -runFirstLaunch`
