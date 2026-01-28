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
- In Finder, right-click the app and choose **Open** (then confirm), or
- Go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Build locally
Build requirements (only needed when building from source):
- macOS 13+
- Xcode + Command Line Tools
- `xcodegen` (install via Homebrew: `brew install xcodegen`)

```bash
./scripts/gen_project.sh
./scripts/build.sh
./scripts/run.sh
```

Release build locally:
```bash
./scripts/build_release.sh
./scripts/run_release.sh
```

## Build and run locally
```bash
./scripts/gen_project.sh
./scripts/build.sh
./scripts/run.sh
```

For fast iteration:
```bash
./scripts/build_and_run.sh
```

Release build + relaunch:
```bash
./scripts/build_and_run_release.sh
```

## Tests
```bash
./scripts/test.sh
```

## Notes
- The app will request camera permission on first run.
