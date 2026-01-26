Hands Off (Mac) - MVP Spec

Overview
- Menu bar macOS app that detects hands approaching the face via webcam and nudges users to stop face-touching.
- Local-only processing using AVFoundation + Vision; no video storage.

Goals
- Reduce unconscious face-touching during computer sessions.
- Provide gentle, configurable nudges with minimal disruption.
- Be privacy-forward and lightweight.

Non-goals
- Medical diagnostics or health advice.
- Cross-platform support.
- Long-term behavior coaching beyond basic streaks and stats.

Target users
- Mac users who work at a desk and want to reduce face-touching habits.

Primary user stories
- As a user, I can start/stop detection from the menu bar.
- As a user, I get a subtle alert when my hand approaches my face.
- As a user, I can tune sensitivity and alert type.
- As a user, I can see daily stats and streaks.

MVP feature set
- Menu bar app with start/stop and status indicator.
- Camera access permission flow (AVFoundation).
- Face detection + hand pose detection (Vision).
- Dynamic face zone and hand-to-face proximity check.
- Alert options: soft chime, on-screen banner, or both.
- Cooldown to avoid repeated alerts (e.g., 5-15 seconds).
- Daily stats: alerts count, total monitoring time, streak.
- Privacy panel stating on-device processing and no storage.

User experience flow
1) First launch -> welcome + permission request.
2) Menu bar icon shows status (active/inactive).
3) When active, app monitors; on proximity, a brief alert fires.
4) Stats view accessible from menu bar dropdown.

Detection approach
- Use AVFoundation to capture frames at a modest FPS (e.g., 10-15).
- Vision requests:
  - Face landmarks for face bounding box.
  - Hand pose for keypoints (wrist, fingertips).
- Define a "face zone" from face bounding box:
  - Expand the box by a margin (e.g., 15-25%) to allow for jitter.
  - Optionally weight forehead/mouth area if landmarks available.
- Trigger alert if any hand keypoint enters face zone for N frames
  (e.g., 2 of last 3 frames) to reduce false positives.

Settings
- Sensitivity: Low / Medium / High (zone size + debounce).
- Alert type: Chime, Banner, Both, or Off.
- Cooldown: 5s / 10s / 15s / 30s.
- Run at login toggle.

Privacy and security
- Camera frames processed in memory only.
- No video/images stored or uploaded.
- Clear copy in settings and onboarding.

Data storage
- Local preferences for settings.
- Local stats aggregate per day (no raw frames).

Technical architecture (high-level)
- App shell: Swift/SwiftUI.
- Capture pipeline: AVFoundation -> CMSampleBuffer.
- Vision pipeline: VNDetectFaceLandmarksRequest, VNDetectHumanHandPoseRequest.
- Alert system: NSSound for chime; NSUserNotification or in-app banner.
- Menu bar: NSStatusItem with menu items and mini stats.

Performance targets
- CPU usage reasonable during monitoring (<10% on modern MacBooks).
- Low latency alerts (<200ms after hand enters zone).

Risks and mitigations
- False positives (e.g., gestures near face): mitigate with debounce and sensitivity.
- Camera privacy concerns: mitigate with clear messaging and local-only processing.
- Lighting variability: provide tips and fallback to lower sensitivity.

Open questions
- Do we want an optional "preview overlay" window to show detected zones?
- Do we include a "practice mode" with coaching tips?
- What default alert type is least disruptive for most users?

Milestones
- M1: Menu bar shell + permissions.
- M2: Vision pipeline + face/hand detection.
- M3: Alert logic + cooldown.
- M4: Settings + stats.
- M5: Privacy copy + polish.
