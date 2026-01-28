import Foundation

enum StatusTone: Equatable {
    case red
    case orange
    case green
    case secondary
}

struct MenuBarStatus {
    static func statusText(
        isMonitoring: Bool,
        isStarting: Bool,
        isAwaitingCamera: Bool,
        isSnoozed: Bool,
        isCameraStalled: Bool
    ) -> String {
        if isCameraStalled {
            return "Camera not responding"
        }
        if isStarting || isAwaitingCamera {
            return "Starting..."
        }
        if isMonitoring {
            return isSnoozed ? "Monitoring snoozed" : "Monitoring on"
        }
        return "Monitoring off"
    }

    static func statusTone(
        isMonitoring: Bool,
        isStarting: Bool,
        isAwaitingCamera: Bool,
        isSnoozed: Bool,
        isCameraStalled: Bool
    ) -> StatusTone {
        if isCameraStalled {
            return .red
        }
        if isStarting || isAwaitingCamera {
            return .orange
        }
        if isMonitoring {
            return isSnoozed ? .orange : .green
        }
        return .secondary
    }

    static func headerSymbolName(
        isMonitoring: Bool,
        isStarting: Bool,
        isAwaitingCamera: Bool
    ) -> String {
        if isStarting || isAwaitingCamera {
            return "hand.raised"
        }
        if isMonitoring {
            return "hand.raised.fill"
        }
        return "hand.raised.slash"
    }

    static func menuBarSymbolName(
        isMonitoring: Bool,
        isStarting: Bool,
        isAwaitingCamera: Bool,
        isSnoozed: Bool
    ) -> String {
        if isStarting || isAwaitingCamera {
            return "hand.raised"
        }
        if !isMonitoring {
            return "hand.raised.slash"
        }
        if isSnoozed {
            return "hand.raised.slash.fill"
        }
        return "hand.raised.fill"
    }

    static func primaryActionTitle(isMonitoring: Bool, isStarting: Bool) -> String {
        if isMonitoring || isStarting {
            return isMonitoring ? "Stop" : "Cancel"
        }
        return "Start"
    }

    static func previewPlaceholderText(
        isMonitoring: Bool,
        isStarting: Bool,
        isAwaitingCamera: Bool,
        hasPreviewImage: Bool
    ) -> String? {
        if isMonitoring {
            if hasPreviewImage {
                return nil
            }
            return isAwaitingCamera ? "Starting camera..." : "Waiting for camera..."
        }
        if isStarting {
            return "Starting camera..."
        }
        return "Start monitoring to show the camera feed."
    }

    static func shouldEnablePreview(isMonitoring: Bool, isAwaitingCamera: Bool) -> Bool {
        isMonitoring && !isAwaitingCamera
    }

    static func shouldShowOpenCameraSettings(error: DetectionStartError?) -> Bool {
        error == .permissionDenied
    }
}
