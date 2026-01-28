# Hands Off (Mac)

Hands Off is a macOS **menu bar** app that detects when your hand approaches your face and nudges you to stop touching your face.

https://github.com/user-attachments/assets/54b25e97-0729-4edf-95ea-c16abf4e68fd

## What it does
- Runs in the menu bar and monitors when enabled.
- Detects face + hands locally using the webcam.
- Alerts via sound, notification banner, and/or a flashing red screen.
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
- `./scripts/build.sh` — build Debug
- `./scripts/run.sh` — run Debug
- `./scripts/build_and_run.sh` — build + relaunch Debug
- `./scripts/build_release.sh` — build Release
- `./scripts/run_release.sh` — run Release
- `./scripts/build_and_run_release.sh` — build + relaunch Release
- `./scripts/test.sh` — run tests

## Notes
- The app will request camera permission on first run.
