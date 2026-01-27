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

## Requirements
- macOS 13+
- Xcode + Command Line Tools
- `xcodegen` (install via Homebrew: `brew install xcodegen`)

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

## Notes
- The app will request camera permission on first run.
