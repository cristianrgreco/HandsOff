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

    func trigger(alertType: AlertType) {
        switch alertType {
        case .off:
            return
        case .chime:
            NSSound.beep()
        case .banner:
            postBanner()
        case .both:
            NSSound.beep()
            postBanner()
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
