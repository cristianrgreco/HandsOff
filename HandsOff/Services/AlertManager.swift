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

    func prepareContinuous() {
        tonePlayer.prepare()
    }

    func shutdownContinuous() {
        tonePlayer.shutdown()
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
    private var isPrepared = false
    private var isPlaying = false
    private var phase: Float = 0
    private let frequency: Float = 880
    private let amplitude: Float = 0.12
    private var gain: Float = 0
    private var idleShutdownWorkItem: DispatchWorkItem?
    private let idleShutdownDelay: TimeInterval = 1.0

    func prepare() {
        guard !isPrepared else { return }
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }
        let node = makeSourceNode(sampleRate: sampleRate)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.0
        sourceNode = node
        isPrepared = true
        gain = 0
    }

    func start() {
        guard !isPlaying else { return }
        prepare()
        guard isPrepared else { return }
        idleShutdownWorkItem?.cancel()
        idleShutdownWorkItem = nil
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return
            }
        }
        engine.mainMixerNode.outputVolume = 1.0
        gain = 1
        isPlaying = true
    }

    func stop() {
        guard isPrepared else { return }
        engine.mainMixerNode.outputVolume = 0.0
        gain = 0
        isPlaying = false
        scheduleIdleShutdown()
    }

    func shutdown() {
        idleShutdownWorkItem?.cancel()
        idleShutdownWorkItem = nil
        guard isPrepared else { return }
        gain = 0
        isPlaying = false
        engine.stop()
        if let sourceNode {
            engine.detach(sourceNode)
        }
        sourceNode = nil
        isPrepared = false
    }

    private func scheduleIdleShutdown() {
        idleShutdownWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isPlaying else { return }
            self.engine.mainMixerNode.outputVolume = 0.0
            self.engine.stop()
        }
        idleShutdownWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + idleShutdownDelay, execute: workItem)
    }

    private func makeSourceNode(sampleRate: Double) -> AVAudioSourceNode {
        AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let delta = 2 * Float.pi * self.frequency / Float(sampleRate)
            let currentGain = self.gain

            for frame in 0..<Int(frameCount) {
                let sample = sin(self.phase) * self.amplitude * currentGain
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
    }
}
