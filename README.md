# Hands Off (Mac)

Hands Off is a macOS **menu bar** app that detects when your hand approaches your face and nudges you to stop.

https://github.com/user-attachments/assets/1e74f34b-ca11-4589-bf58-7ac76c2fe794

## What it does
- Runs in the menu bar and monitors when enabled.
- Detects face + hands locally using the webcam.
- Alerts via sound, notification banner, and/or a flashing red screen.
- Automatically reduces detection frequency on battery/low power to conserve CPU and battery.
- Shows simple stats for recent touches.

## Privacy
- On-device processing only.
- No video/images are stored or uploaded.

## Installation
**Recommended:** download the latest release DMG from GitHub Releases and drag `HandsOff.app` to Applications.

Gatekeeper warning (if macOS blocks the app):
- Go to **System Settings → Privacy & Security** and click **Open Anyway**.

## Local development
Build requirements (only needed when building from source):
- macOS 13+
- Xcode + Command Line Tools
- `xcodegen` (install via Homebrew: `brew install xcodegen`)

Scripts:
- `./scripts/gen_project.sh` — generate the Xcode project
- `./scripts/build.sh DEBUG|RELEASE` — build Debug or Release
- `./scripts/run.sh DEBUG|RELEASE` — run Debug or Release
- `./scripts/relaunch.sh DEBUG|RELEASE` — relaunch Debug or Release
- `./scripts/build_and_run.sh DEBUG|RELEASE` — build + relaunch Debug or Release
- `./scripts/test.sh` — run tests

## Notes
- The app will request camera permission on first run.
