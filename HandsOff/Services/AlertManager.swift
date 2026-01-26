import AVFoundation
import Foundation
import UserNotifications

final class AlertManager {
    private let notificationCenter = UNUserNotificationCenter.current()
    private let tonePlayer = TonePlayer()

    func ensureNotificationAuthorization() {
        notificationCenter.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                self.notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }

    func startContinuous() {
        tonePlayer.start()
    }

    func stopContinuous() {
        tonePlayer.stop()
    }

    func postBanner() {
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

private final class TonePlayer {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var isPlaying = false
    private var phase: Float = 0
    private let frequency: Float = 880
    private let amplitude: Float = 0.12

    func start() {
        guard !isPlaying else { return }
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let delta = 2 * Float.pi * self.frequency / Float(sampleRate)

            for frame in 0..<Int(frameCount) {
                let sample = sin(self.phase) * self.amplitude
                self.phase += delta
                if self.phase > 2 * Float.pi {
                    self.phase -= 2 * Float.pi
                }
                for buffer in abl {
                    let pointer = buffer.mData?.assumingMemoryBound(to: Float.self)
                    pointer?[frame] = sample
                }
            }
            return noErr
        }

        guard let format else { return }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0

        do {
            try engine.start()
            self.sourceNode = sourceNode
            isPlaying = true
        } catch {
            engine.detach(sourceNode)
        }
    }

    func stop() {
        guard isPlaying else { return }
        engine.stop()
        if let sourceNode {
            engine.detach(sourceNode)
        }
        sourceNode = nil
        isPlaying = false
    }
}
