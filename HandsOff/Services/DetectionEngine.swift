import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import QuartzCore
import Vision

struct DetectionSettings {
    let cameraID: String?
    let faceZoneScale: CGFloat
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
    private let stateLock = NSLock()

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
    private var hasActiveTrigger = false
    private let ciContext = CIContext()
    private let sensitivity: Sensitivity = .low

    private let confidenceThreshold: Float = 0.25
    private let hairTopMargin: CGFloat = 0.25
    private let frameInterval: CFTimeInterval = 1.0 / 12.0
    private let staleFrameThreshold: CFTimeInterval = 1.0
    private let faceCacheDuration: CFTimeInterval = 2.0

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
            self.withStateLock {
                self.isRunning = false
                self.isInterrupted = false
            }
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

            self.visionQueue.sync {
                self.resetState()
            }
            self.withStateLock {
                self.isRunning = true
                self.isInterrupted = false
            }
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
        lastFaceBoundingBox = nil
        lastFaceTime = 0
        lastFrameTime = 0
        hasActiveTrigger = false
    }

    private func startSessionMonitor() {
        sessionMonitor?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let isRunning = self.withStateLock { self.isRunning }
            guard isRunning else { return }
            let isInterrupted = self.withStateLock { self.isInterrupted }
            guard !isInterrupted else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                self.resetFrameClock()
                return
            }
            let now = CACurrentMediaTime()
            let lastFrameTime = self.withStateLock { self.lastFrameTime }
            if lastFrameTime > 0, now - lastFrameTime > 2.5 {
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
                    guard let self else { return }
                    self.withStateLock {
                        self.isInterrupted = false
                    }
                    self.restartSession()
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
        withStateLock {
            isInterrupted = true
        }
    }

    private func handleSessionRuntimeError(_ notification: Notification) {
        guard notification.userInfo?[AVCaptureSessionErrorKey] as? NSError != nil else {
            return
        }
        restartSession()
    }

    private func restartSession() {
        let isRunning = withStateLock { self.isRunning }
        guard isRunning else { return }
        session.stopRunning()
        session.startRunning()
        resetFrameClock()
    }

    private func resetFrameClock() {
        withStateLock {
            lastFrameTime = 0
        }
    }

    private func complete(_ error: DetectionStartError?, completion: @escaping (DetectionStartError?) -> Void) {
        DispatchQueue.main.async {
            completion(error)
        }
    }

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        let now = CACurrentMediaTime()
        let previewIsEnabled = previewEnabled

        let previousFrameTime = withStateLock { lastFrameTime }
        if previousFrameTime > 0 && now - previousFrameTime > staleFrameThreshold {
            // Reset trigger state after long gaps.
            hasActiveTrigger = false
        }
        let shouldProcess = withStateLock { () -> Bool in
            if lastFrameTime > 0 && now - lastFrameTime < frameInterval {
                return false
            }
            lastFrameTime = now
            return true
        }
        if previewIsEnabled {
            // When the preview is open, render every incoming frame.
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            emitPreview(pixelBuffer)
            guard shouldProcess else { return }
            detect(on: pixelBuffer, now: now)
            return
        }

        // When the preview is closed, avoid extra work on throttled frames.
        guard shouldProcess else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        detect(on: pixelBuffer, now: now)
    }

    private func updateHit(_ hit: Bool) {
        if hit {
            if !hasActiveTrigger {
                hasActiveTrigger = true
                onTrigger()
            }
        } else {
            hasActiveTrigger = false
        }
    }

    private func detect(on pixelBuffer: CVPixelBuffer, now: CFTimeInterval) {
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
        let detectionSettings = settingsProvider()
        let faceBox = resolveFaceBox(
            face: faceRequest.results?.first,
            handPoints: points,
            now: now,
            faceZoneScale: detectionSettings.faceZoneScale
        )

        guard let faceBox else {
            updateHit(false)
            emitObservation(faceZone: nil, hit: false)
            return
        }

        let faceZone = faceZone(for: faceBox, scale: detectionSettings.faceZoneScale)
        let hit = points.contains { faceZone.contains($0) }
        updateHit(hit)
        emitObservation(faceZone: faceZone, hit: hit)
    }

    private func emitPreview(_ pixelBuffer: CVPixelBuffer) {
        guard previewEnabled else { return }
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

    private func scaledRect(_ rect: CGRect, scale: CGFloat) -> CGRect {
        guard scale != 1 else { return rect }
        let centerX = rect.midX
        let centerY = rect.midY
        let scaledWidth = rect.width * scale
        let scaledHeight = rect.height * scale
        let originX = centerX - scaledWidth / 2
        let originY = centerY - scaledHeight / 2
        return expandedRect(
            CGRect(x: originX, y: originY, width: scaledWidth, height: scaledHeight),
            by: 0
        )
    }

    private func rectIncludingHair(_ rect: CGRect) -> CGRect {
        let extraHeight = rect.height * hairTopMargin
        let expanded = CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.width,
            height: rect.height + extraHeight
        )
        return expandedRect(expanded, by: 0)
    }

    private func faceZone(for faceBox: CGRect, scale: CGFloat) -> CGRect {
        let scaledFace = scaledRect(faceBox, scale: scale)
        let hairFace = rectIncludingHair(scaledFace)
        return expandedRect(hairFace, by: sensitivity.zoneExpansion)
    }

    private func emitObservation(faceZone: CGRect?, hit: Bool) {
        DispatchQueue.main.async {
            self.onObservation(DetectionObservation(hit: hit, faceZone: faceZone))
        }
    }

    private func resolveFaceBox(
        face: VNFaceObservation?,
        handPoints: [CGPoint],
        now: CFTimeInterval,
        faceZoneScale: CGFloat
    ) -> CGRect? {
        if let face {
            lastFaceBoundingBox = face.boundingBox
            lastFaceTime = now
            return face.boundingBox
        }

        guard let cached = lastFaceBoundingBox else { return nil }
        let cachedZone = faceZone(for: cached, scale: faceZoneScale)
        if handPoints.contains(where: cachedZone.contains) {
            // Keep cached face while the hand still overlaps the last zone.
            lastFaceTime = now
            return cached
        }

        guard now - lastFaceTime <= faceCacheDuration else { return nil }
        return cached
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }
}

extension DetectionEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let isRunning = withStateLock { self.isRunning }
        guard isRunning else { return }
        guard !isProcessing else { return }

        isProcessing = true
        defer { isProcessing = false }

        processFrame(sampleBuffer)
    }
}
