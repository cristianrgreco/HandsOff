import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import QuartzCore
import Vision

struct DetectionSettings {
    let sensitivity: Sensitivity
    let cooldownSeconds: Double
    let cameraID: String?
}

struct DetectionObservation {
    let hit: Bool
    let faceZone: CGRect?
}

enum DetectionStartError: String, Error, Identifiable, Equatable {
    case permissionDenied = "Camera access is denied. Enable it in System Settings."
    case noCamera = "No camera found."
    case configurationFailed = "Camera setup failed."

    var id: String { rawValue }
}

final class DetectionEngine: NSObject {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "HandsOff.CaptureSession")
    private let visionQueue = DispatchQueue(label: "HandsOff.Vision")

    private let output = AVCaptureVideoDataOutput()
    private let settingsProvider: () -> DetectionSettings
    private let onTrigger: () -> Void
    private var onObservation: (DetectionObservation) -> Void = { _ in }
    private var onPreviewFrame: ((CGImage) -> Void)?
    private var sessionMonitor: DispatchSourceTimer?
    private var sessionObservers: [NSObjectProtocol] = []

    private var isConfigured = false
    private var isRunning = false
    private var isProcessing = false
    private var isInterrupted = false
    private var previewEnabled = false
    private var activeCameraID: String?
    private var lastFaceBoundingBox: CGRect?
    private var lastFaceTime: CFTimeInterval = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var lastTriggerTime: CFTimeInterval = 0
    private var lastPreviewTime: CFTimeInterval = 0
    private var recentHits: [Bool] = []
    private let ciContext = CIContext()

    private let confidenceThreshold: Float = 0.25
    private let frameInterval: CFTimeInterval = 1.0 / 12.0
    private let staleFrameThreshold: CFTimeInterval = 1.0
    private let faceCacheDuration: CFTimeInterval = 2.0
    private let previewInterval: CFTimeInterval = 1.0 / 12.0

    init(
        settingsProvider: @escaping () -> DetectionSettings,
        onTrigger: @escaping () -> Void
    ) {
        self.settingsProvider = settingsProvider
        self.onTrigger = onTrigger
        super.init()
    }

    func setObservationHandler(_ handler: @escaping (DetectionObservation) -> Void) {
        onObservation = handler
    }

    func setPreviewHandler(_ handler: @escaping (CGImage) -> Void) {
        visionQueue.async {
            self.onPreviewFrame = handler
        }
    }

    func setPreviewEnabled(_ enabled: Bool) {
        visionQueue.async {
            self.previewEnabled = enabled
            if !enabled {
                self.lastPreviewTime = 0
            }
        }
    }

    func start(completion: @escaping (DetectionStartError?) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            startSession(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.startSession(completion: completion)
                } else {
                    self.complete(.permissionDenied, completion: completion)
                }
            }
        default:
            complete(.permissionDenied, completion: completion)
        }
    }

    func stop() {
        sessionQueue.async {
            self.isRunning = false
            self.stopSessionMonitor()
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func startSession(completion: @escaping (DetectionStartError?) -> Void) {
        sessionQueue.async {
            let desiredCameraID = self.settingsProvider().cameraID
            if !self.isConfigured || desiredCameraID != self.activeCameraID {
                if let error = self.configureSession(cameraID: desiredCameraID) {
                    self.complete(error, completion: completion)
                    return
                }
                self.activeCameraID = desiredCameraID
                self.isConfigured = true
            }

            self.resetState()
            self.isRunning = true
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.startSessionObservers()
            self.startSessionMonitor()
            self.complete(nil, completion: completion)
        }
    }

    private func configureSession(cameraID: String?) -> DetectionStartError? {
        guard let device = resolveDevice(for: cameraID) else {
            return .noCamera
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .medium

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                return .configurationFailed
            }
        } catch {
            return .configurationFailed
        }

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: visionQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            return .configurationFailed
        }

        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }

        return nil
    }

    private func resetState() {
        recentHits.removeAll()
        lastFaceBoundingBox = nil
        lastFaceTime = 0
        lastFrameTime = 0
        lastTriggerTime = 0
        lastPreviewTime = 0
    }

    private func startSessionMonitor() {
        sessionMonitor?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            guard let self, self.isRunning else { return }
            guard !self.isInterrupted else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                self.resetFrameClock()
                return
            }
            let now = CACurrentMediaTime()
            if self.lastFrameTime > 0, now - self.lastFrameTime > 2.5 {
                self.restartSession()
            }
        }
        timer.resume()
        sessionMonitor = timer
    }

    private func stopSessionMonitor() {
        sessionMonitor?.cancel()
        sessionMonitor = nil
    }

    private func startSessionObservers() {
        guard sessionObservers.isEmpty else { return }
        let center = NotificationCenter.default
        sessionObservers.append(
            center.addObserver(
                forName: .AVCaptureSessionWasInterrupted,
                object: session,
                queue: .main
            ) { [weak self] notification in
                self?.sessionQueue.async {
                    self?.handleSessionInterrupted(notification)
                }
            }
        )
        sessionObservers.append(
            center.addObserver(
                forName: .AVCaptureSessionInterruptionEnded,
                object: session,
                queue: .main
            ) { [weak self] _ in
                self?.sessionQueue.async {
                    self?.isInterrupted = false
                    self?.restartSession()
                }
            }
        )
        sessionObservers.append(
            center.addObserver(
                forName: .AVCaptureSessionRuntimeError,
                object: session,
                queue: .main
            ) { [weak self] notification in
                self?.sessionQueue.async {
                    self?.handleSessionRuntimeError(notification)
                }
            }
        )
    }

    private func handleSessionInterrupted(_ notification: Notification) {
        isInterrupted = true
    }

    private func handleSessionRuntimeError(_ notification: Notification) {
        guard notification.userInfo?[AVCaptureSessionErrorKey] as? NSError != nil else {
            return
        }
        restartSession()
    }

    private func restartSession() {
        guard isRunning else { return }
        session.stopRunning()
        session.startRunning()
        resetFrameClock()
    }

    private func resetFrameClock() {
        lastFrameTime = 0
    }

    private func complete(_ error: DetectionStartError?, completion: @escaping (DetectionStartError?) -> Void) {
        DispatchQueue.main.async {
            completion(error)
        }
    }

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        let now = CACurrentMediaTime()
        if lastFrameTime > 0 && now - lastFrameTime > staleFrameThreshold {
            // Clear stale hits after long gaps to avoid delayed triggers.
            recentHits.removeAll()
        }
        guard now - lastFrameTime >= frameInterval else { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        emitPreview(pixelBuffer, now: now)

        let settings = settingsProvider()
        let faceRequest = VNDetectFaceLandmarksRequest()
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([faceRequest, handRequest])
        } catch {
            return
        }

        let points = handPoints(from: handRequest.results)
        let faceBox = resolveFaceBox(
            face: faceRequest.results?.first,
            handPoints: points,
            settings: settings,
            now: now
        )

        guard let faceBox else {
            updateHit(false, settings: settings)
            emitObservation(faceZone: nil, hit: false)
            return
        }

        let faceZone = expandedRect(faceBox, by: settings.sensitivity.zoneExpansion)
        let hit = points.contains { faceZone.contains($0) }
        updateHit(hit, settings: settings)
        emitObservation(faceZone: faceZone, hit: hit)
    }

    private func updateHit(_ hit: Bool, settings: DetectionSettings) {
        recentHits.append(hit)
        if recentHits.count > settings.sensitivity.debounceWindow {
            recentHits.removeFirst()
        }

        let hits = recentHits.filter { $0 }.count
        guard hits >= settings.sensitivity.hitThreshold else { return }
        guard hit else { return }

        let now = CACurrentMediaTime()
        guard now - lastTriggerTime >= settings.cooldownSeconds else { return }
        lastTriggerTime = now

        onTrigger()
    }

    private func emitPreview(_ pixelBuffer: CVPixelBuffer, now: CFTimeInterval) {
        guard previewEnabled else { return }
        guard now - lastPreviewTime >= previewInterval else { return }
        lastPreviewTime = now
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return }
        DispatchQueue.main.async {
            self.onPreviewFrame?(cgImage)
        }
    }

    private func handPoints(from observations: [VNHumanHandPoseObservation]?) -> [CGPoint] {
        guard let observations else { return [] }
        var points: [CGPoint] = []

        for observation in observations {
            guard let recognizedPoints = try? observation.recognizedPoints(.all) else { continue }
            for point in recognizedPoints.values where point.confidence >= confidenceThreshold {
                points.append(point.location)
            }
        }

        return points
    }

    private func resolveDevice(for cameraID: String?) -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        let devices = discovery.devices

        if let cameraID, let match = devices.first(where: { $0.uniqueID == cameraID }) {
            return match
        }
        if let external = devices.first(where: { $0.deviceType == .externalUnknown }) {
            return external
        }
        return devices.first
    }

    private func expandedRect(_ rect: CGRect, by expansion: CGFloat) -> CGRect {
        let dx = rect.width * expansion
        let dy = rect.height * expansion
        var expanded = rect.insetBy(dx: -dx, dy: -dy)
        expanded.origin.x = max(0, expanded.origin.x)
        expanded.origin.y = max(0, expanded.origin.y)
        expanded.size.width = min(1 - expanded.origin.x, expanded.size.width)
        expanded.size.height = min(1 - expanded.origin.y, expanded.size.height)
        return expanded
    }

    private func emitObservation(faceZone: CGRect?, hit: Bool) {
        DispatchQueue.main.async {
            self.onObservation(DetectionObservation(hit: hit, faceZone: faceZone))
        }
    }

    private func resolveFaceBox(
        face: VNFaceObservation?,
        handPoints: [CGPoint],
        settings: DetectionSettings,
        now: CFTimeInterval
    ) -> CGRect? {
        if let face {
            lastFaceBoundingBox = face.boundingBox
            lastFaceTime = now
            return face.boundingBox
        }

        guard let cached = lastFaceBoundingBox else { return nil }
        let cachedZone = expandedRect(cached, by: settings.sensitivity.zoneExpansion)
        if handPoints.contains(where: cachedZone.contains) {
            // Keep cached face while the hand still overlaps the last zone.
            lastFaceTime = now
            return cached
        }

        guard now - lastFaceTime <= faceCacheDuration else { return nil }
        return cached
    }
}

extension DetectionEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isRunning else { return }
        guard !isProcessing else { return }

        isProcessing = true
        defer { isProcessing = false }

        processFrame(sampleBuffer)
    }
}
