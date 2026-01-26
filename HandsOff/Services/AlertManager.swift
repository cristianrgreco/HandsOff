import AppKit
import Foundation
import UserNotifications

final class AlertManager {
    private let notificationCenter = UNUserNotificationCenter.current()

    func ensureNotificationAuthorization() {
        notificationCenter.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                self.notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }

    func trigger(alertType: AlertType, alertSound: AlertSound) {
        switch alertType {
        case .off:
            return
        case .chime:
            playSound(alertSound)
        case .banner:
            postBanner()
        case .both:
            playSound(alertSound)
            postBanner()
        }
    }

    private func playSound(_ sound: AlertSound) {
        if let systemSound = NSSound(named: NSSound.Name(sound.systemSoundName)) {
            systemSound.stop()
            systemSound.currentTime = 0
            systemSound.play()
        } else {
            NSSound.beep()
        }
    }

    private func postBanner() {
        let content = UNMutableNotificationContent()
        content.title = "Hands Off"
        content.body = "Hands near face."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )

        notificationCenter.add(request, withCompletionHandler: nil)
    }
}
