import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import QuartzCore
import Vision
import os

struct DetectionSettings {
    let cameraID: String?
    let faceZoneScale: CGFloat
}

struct DetectionObservation {
    let hit: Bool
    let faceZone: CGRect?
    let handPoints: [CGPoint]
}

struct DetectionData {
    let faceBox: CGRect?
    let handPoints: [CGPoint]
}

typealias DetectionDataProvider = (_ pixelBuffer: CVPixelBuffer) -> DetectionData?

enum DetectionStartError: String, Error, Identifiable, Equatable {
    case permissionDenied = "Camera access is denied. Enable it in System Settings."
    case noCamera = "No camera found."
    case configurationFailed = "Camera setup failed."

    var id: String { rawValue }
}

struct DetectionGeometry {
    static func expandedRect(_ rect: CGRect, by expansion: CGFloat) -> CGRect {
        let dx = rect.width * expansion
        let dy = rect.height * expansion
        var expanded = rect.insetBy(dx: -dx, dy: -dy)
        expanded.origin.x = max(0, expanded.origin.x)
        expanded.origin.y = max(0, expanded.origin.y)
        expanded.size.width = min(1 - expanded.origin.x, expanded.size.width)
        expanded.size.height = min(1 - expanded.origin.y, expanded.size.height)
        return expanded
    }

    static func scaledRect(_ rect: CGRect, scale: CGFloat) -> CGRect {
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

    static func rectIncludingHair(_ rect: CGRect, hairTopMargin: CGFloat) -> CGRect {
        let extraHeight = rect.height * hairTopMargin
        let expanded = CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.width,
            height: rect.height + extraHeight
        )
        return expandedRect(expanded, by: 0)
    }

    static func faceZone(
        faceBox: CGRect,
        scale: CGFloat,
        sensitivityExpansion: CGFloat,
        hairTopMargin: CGFloat
    ) -> CGRect {
        let scaledFace = scaledRect(faceBox, scale: scale)
        let hairFace = rectIncludingHair(scaledFace, hairTopMargin: hairTopMargin)
        return expandedRect(hairFace, by: sensitivityExpansion)
    }
}

struct DetectionTriggerState {
    private(set) var isActive = false

    mutating func update(hit: Bool) -> Bool {
        if hit {
            if !isActive {
                isActive = true
                return true
            }
            return false
        }
        isActive = false
        return false
    }

    mutating func reset() {
        isActive = false
    }
}

struct DetectionFrameThrottle {
    static func evaluate(
        now: CFTimeInterval,
        lastFrameTime: CFTimeInterval,
        frameInterval: CFTimeInterval,
        staleFrameThreshold: CFTimeInterval
    ) -> (shouldProcess: Bool, newLastFrameTime: CFTimeInterval, resetTrigger: Bool) {
        if lastFrameTime > 0 && now - lastFrameTime > staleFrameThreshold {
            return (true, now, true)
        }
        if lastFrameTime > 0 && now - lastFrameTime < frameInterval {
            return (false, lastFrameTime, false)
        }
        return (true, now, false)
    }
}

struct DetectionFaceCache {
    static func resolve(
        faceBox: CGRect?,
        handPoints: [CGPoint],
        now: CFTimeInterval,
        faceZoneScale: CGFloat,
        lastFaceBox: CGRect?,
        lastFaceTime: CFTimeInterval,
        sensitivityExpansion: CGFloat,
        hairTopMargin: CGFloat,
        faceCacheDuration: CFTimeInterval
    ) -> (faceBox: CGRect?, lastFaceBox: CGRect?, lastFaceTime: CFTimeInterval) {
        if let faceBox {
            return (faceBox, faceBox, now)
        }

        guard let cached = lastFaceBox else {
            return (nil, nil, lastFaceTime)
        }

        let cachedZone = DetectionGeometry.faceZone(
            faceBox: cached,
            scale: faceZoneScale,
            sensitivityExpansion: sensitivityExpansion,
            hairTopMargin: hairTopMargin
        )
        if handPoints.contains(where: cachedZone.contains) {
            return (cached, cached, now)
        }

        guard now - lastFaceTime <= faceCacheDuration else {
            return (nil, cached, lastFaceTime)
        }

        return (cached, cached, lastFaceTime)
    }
}

struct DetectionSessionHealth {
    static func shouldRestartForStall(
        lastFrameTime: CFTimeInterval,
        now: CFTimeInterval,
        stallThreshold: CFTimeInterval
    ) -> Bool {
        lastFrameTime > 0 && now - lastFrameTime > stallThreshold
    }

    static func shouldRestartForRuntimeError(_ notification: Notification) -> Bool {
        notification.userInfo?[AVCaptureSessionErrorKey] as? NSError != nil
    }
}

protocol CaptureSessionType: AnyObject {
    var isRunning: Bool { get }
    var inputs: [AnyObject] { get }
    var outputs: [AnyObject] { get }
    var sessionPreset: AVCaptureSession.Preset { get set }
    var notificationObject: AnyObject { get }

    func beginConfiguration()
    func commitConfiguration()
    func canAddInput(_ input: AnyObject) -> Bool
    func addInput(_ input: AnyObject)
    func removeInput(_ input: AnyObject)
    func canAddOutput(_ output: AnyObject) -> Bool
    func addOutput(_ output: AnyObject)
    func removeOutput(_ output: AnyObject)
    func startRunning()
    func stopRunning()
}

final class AVCaptureSessionAdapter: CaptureSessionType {
    private let session: AVCaptureSession

    init(session: AVCaptureSession = AVCaptureSession()) {
        self.session = session
    }

    var isRunning: Bool { session.isRunning }
    var inputs: [AnyObject] { session.inputs as [AnyObject] }
    var outputs: [AnyObject] { session.outputs as [AnyObject] }
    var sessionPreset: AVCaptureSession.Preset {
        get { session.sessionPreset }
        set { session.sessionPreset = newValue }
    }
    var notificationObject: AnyObject { session }

    func beginConfiguration() {
        session.beginConfiguration()
    }

    func commitConfiguration() {
        session.commitConfiguration()
    }

    func canAddInput(_ input: AnyObject) -> Bool {
        guard let input = input as? AVCaptureInput else {
            return false
        }
        return session.canAddInput(input)
    }

    func addInput(_ input: AnyObject) {
        guard let input = input as? AVCaptureInput else { return }
        session.addInput(input)
    }

    func removeInput(_ input: AnyObject) {
        guard let input = input as? AVCaptureInput else { return }
        session.removeInput(input)
    }

    func canAddOutput(_ output: AnyObject) -> Bool {
        guard let output = output as? AVCaptureOutput else {
            return false
        }
        return session.canAddOutput(output)
    }

    func addOutput(_ output: AnyObject) {
        guard let output = output as? AVCaptureOutput else { return }
        session.addOutput(output)
    }

    func removeOutput(_ output: AnyObject) {
        guard let output = output as? AVCaptureOutput else { return }
        session.removeOutput(output)
    }

    func startRunning() {
        session.startRunning()
    }

    func stopRunning() {
        session.stopRunning()
    }
}

enum CaptureInputResult {
    case success(AnyObject)
    case noCamera
    case failure
}

protocol CaptureInputProviding {
    func makeInput(cameraID: String?) -> CaptureInputResult
}

struct DefaultCaptureInputProvider: CaptureInputProviding {
    private let resolveDevice: (String?) -> AVCaptureDevice?
    private let makeDeviceInput: (AVCaptureDevice) throws -> AVCaptureDeviceInput

    init(
        resolveDevice: @escaping (String?) -> AVCaptureDevice? = DetectionEngine.resolveDevice(for:),
        makeDeviceInput: @escaping (AVCaptureDevice) throws -> AVCaptureDeviceInput = AVCaptureDeviceInput.init
    ) {
        self.resolveDevice = resolveDevice
        self.makeDeviceInput = makeDeviceInput
    }

    func makeInput(cameraID: String?) -> CaptureInputResult {
        guard let device = resolveDevice(cameraID) else {
            return .noCamera
        }

        do {
            let input = try makeDeviceInput(device)
            return .success(input)
        } catch {
            return .failure
        }
    }
}

struct VisionDetectionProvider {
    let confidenceThreshold: Float

    func detect(pixelBuffer: CVPixelBuffer) -> DetectionData? {
        let faceRequest = VNDetectFaceRectanglesRequest()
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([faceRequest, handRequest])
        } catch {
            return nil
        }

        let points = handPoints(from: handRequest.results)
        let faceBox = faceRequest.results?.first?.boundingBox
        return DetectionData(faceBox: faceBox, handPoints: points)
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
}

final class DetectionEngine: NSObject {
    private let session: CaptureSessionType
    private let inputProvider: CaptureInputProviding
    private let dataProvider: DetectionDataProvider
    private let authorizationStatus: () -> AVAuthorizationStatus
    private let requestAccess: (@escaping (Bool) -> Void) -> Void
    private let sessionQueue: DispatchQueue
    private let visionQueue: DispatchQueue

    private let output = AVCaptureVideoDataOutput()
    private let settingsProvider: () -> DetectionSettings
    private let onTrigger: () -> Void
    private var onObservation: (DetectionObservation) -> Void = { _ in }
    private var onPreviewFrame: ((CGImage) -> Void)?
    private var onFrame: (() -> Void)?
    private var sessionMonitor: DispatchSourceTimer?
    private var sessionObservers: [NSObjectProtocol] = []

    private var isConfigured = false
    private let isRunningLock = OSAllocatedUnfairLock(initialState: false)
    private var isProcessing = false
    private var isInterrupted = false
    private let previewEnabledLock = OSAllocatedUnfairLock(initialState: false)
    private var activeCameraID: String?
    private var lastFaceBoundingBox: CGRect?
    private var lastFaceTime: CFTimeInterval = 0
    private let lastFrameTimeLock = OSAllocatedUnfairLock(initialState: CFTimeInterval(0))
    private var triggerState = DetectionTriggerState()
    private let ciContext = CIContext()
    private let sensitivity: Sensitivity = .low

    private let confidenceThreshold: Float = 0.75
    private let hairTopMargin: CGFloat = 0.25
    private let frameIntervalLock = OSAllocatedUnfairLock(initialState: CFTimeInterval(1.0 / 10.0))
    private let sessionPresetValue: AVCaptureSession.Preset = .low
    private let staleFrameThreshold: CFTimeInterval = 1.0
    private let faceCacheDuration: CFTimeInterval = 2.0
#if DEBUG
    private var testRestartHandler: (() -> Void)?
    private var testRestartCount = 0
    private var testSessionMonitorInterval: TimeInterval?
#endif

    init(
        settingsProvider: @escaping () -> DetectionSettings,
        onTrigger: @escaping () -> Void,
        session: CaptureSessionType = AVCaptureSessionAdapter(),
        inputProvider: CaptureInputProviding = DefaultCaptureInputProvider(),
        dataProvider: DetectionDataProvider? = nil,
        authorizationStatus: @escaping () -> AVAuthorizationStatus = {
            AVCaptureDevice.authorizationStatus(for: .video)
        },
        requestAccess: @escaping (@escaping (Bool) -> Void) -> Void = { handler in
            AVCaptureDevice.requestAccess(for: .video, completionHandler: handler)
        },
        sessionQueue: DispatchQueue = DispatchQueue(label: "HandsOff.CaptureSession"),
        visionQueue: DispatchQueue = DispatchQueue(label: "HandsOff.Vision")
    ) {
        self.settingsProvider = settingsProvider
        self.onTrigger = onTrigger
        self.session = session
        self.inputProvider = inputProvider
        self.sessionQueue = sessionQueue
        self.visionQueue = visionQueue
        self.dataProvider = dataProvider ?? VisionDetectionProvider(confidenceThreshold: confidenceThreshold).detect
        self.authorizationStatus = authorizationStatus
        self.requestAccess = requestAccess
        super.init()
    }

    private var isRunning: Bool {
        get { isRunningLock.withLock { $0 } }
        set { isRunningLock.withLock { $0 = newValue } }
    }

    private var previewEnabled: Bool {
        get { previewEnabledLock.withLock { $0 } }
        set { previewEnabledLock.withLock { $0 = newValue } }
    }

    private var lastFrameTime: CFTimeInterval {
        get { lastFrameTimeLock.withLock { $0 } }
        set { lastFrameTimeLock.withLock { $0 = newValue } }
    }

    private var frameIntervalValue: CFTimeInterval {
        get { frameIntervalLock.withLock { $0 } }
        set { frameIntervalLock.withLock { $0 = newValue } }
    }

    func setObservationHandler(_ handler: @escaping (DetectionObservation) -> Void) {
        onObservation = handler
    }

    func setPreviewHandler(_ handler: @escaping (CGImage) -> Void) {
        visionQueue.async {
            self.onPreviewFrame = handler
        }
    }

    func setFrameHandler(_ handler: @escaping () -> Void) {
        visionQueue.async {
            self.onFrame = handler
        }
    }

    func setPreviewEnabled(_ enabled: Bool) {
        previewEnabled = enabled
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured else { return }
            self.updateSessionPreset(previewEnabled: enabled)
        }
    }

    func setFrameInterval(_ interval: CFTimeInterval) {
        frameIntervalValue = max(0.05, interval)
    }

    func start(completion: @escaping (DetectionStartError?) -> Void) {
        let status = authorizationStatus()
        switch status {
        case .authorized:
            startSession(completion: completion)
        case .notDetermined:
            requestAccess { [weak self] granted in
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
        let inputResult = inputProvider.makeInput(cameraID: cameraID)
        let input: AnyObject
        switch inputResult {
        case .noCamera:
            return .noCamera
        case .failure:
            return .configurationFailed
        case .success(let resolvedInput):
            input = resolvedInput
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = sessionPreset(previewEnabled: previewEnabled)

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        if session.canAddInput(input) {
            session.addInput(input)
        } else {
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
        triggerState.reset()
    }

    private func startSessionMonitor() {
        sessionMonitor?.cancel()
        let interval: TimeInterval
#if DEBUG
        interval = testSessionMonitorInterval ?? 2
#else
        interval = 2
#endif
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self, self.isRunning else { return }
            self.handleSessionMonitorTick(now: CACurrentMediaTime())
        }
        timer.resume()
        sessionMonitor = timer
    }

    private func stopSessionMonitor() {
        sessionMonitor?.cancel()
        sessionMonitor = nil
    }

    private func handleSessionMonitorTick(now: CFTimeInterval) {
        guard !isInterrupted else { return }
        if !session.isRunning {
            session.startRunning()
            resetFrameClock()
            return
        }
        if DetectionSessionHealth.shouldRestartForStall(
            lastFrameTime: lastFrameTime,
            now: now,
            stallThreshold: 2.5
        ) {
            restartSession()
        }
    }

    private func startSessionObservers() {
        guard sessionObservers.isEmpty else { return }
        let center = NotificationCenter.default
        sessionObservers.append(
            center.addObserver(
                forName: .AVCaptureSessionWasInterrupted,
                object: session.notificationObject,
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
                object: session.notificationObject,
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
                object: session.notificationObject,
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
        guard DetectionSessionHealth.shouldRestartForRuntimeError(notification) else { return }
        restartSession()
    }

    private func restartSession() {
        guard isRunning else { return }
#if DEBUG
        if let testRestartHandler {
            testRestartCount += 1
            testRestartHandler()
            resetFrameClock()
            return
        }
#endif
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
        emitFrame()
        let now = CACurrentMediaTime()
        let previewIsEnabled = previewEnabled

        let frameInterval = frameInterval(previewEnabled: previewIsEnabled)
        let throttle = DetectionFrameThrottle.evaluate(
            now: now,
            lastFrameTime: lastFrameTime,
            frameInterval: frameInterval,
            staleFrameThreshold: staleFrameThreshold
        )
        if throttle.resetTrigger {
            triggerState.reset()
        }
        let shouldProcess = throttle.shouldProcess
        if shouldProcess {
            lastFrameTime = throttle.newLastFrameTime
        }
        if previewIsEnabled {
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

    private func frameInterval(previewEnabled _: Bool) -> CFTimeInterval {
        frameIntervalValue
    }


    private func sessionPreset(previewEnabled: Bool) -> AVCaptureSession.Preset {
        sessionPresetValue
    }

    private func updateSessionPreset(previewEnabled: Bool) {
        let desiredPreset = sessionPreset(previewEnabled: previewEnabled)
        guard session.sessionPreset != desiredPreset else { return }
        session.beginConfiguration()
        session.sessionPreset = desiredPreset
        session.commitConfiguration()
    }

    private func updateHit(_ hit: Bool) {
        if triggerState.update(hit: hit) {
            onTrigger()
        }
    }

    private func detect(on pixelBuffer: CVPixelBuffer, now: CFTimeInterval) {
        guard let detection = dataProvider(pixelBuffer) else { return }
        let points = detection.handPoints
        let detectionSettings = settingsProvider()
        processDetection(
            faceBox: detection.faceBox,
            handPoints: points,
            now: now,
            faceZoneScale: detectionSettings.faceZoneScale
        )
    }

    private func processDetection(
        faceBox: CGRect?,
        handPoints: [CGPoint],
        now: CFTimeInterval,
        faceZoneScale: CGFloat
    ) {
        let resolvedFaceBox = resolveFaceBox(
            faceBox: faceBox,
            handPoints: handPoints,
            now: now,
            faceZoneScale: faceZoneScale
        )

        guard let resolvedFaceBox else {
            updateHit(false)
            emitObservation(faceZone: nil, hit: false, handPoints: handPoints)
            return
        }

        let faceZone = DetectionGeometry.faceZone(
            faceBox: resolvedFaceBox,
            scale: faceZoneScale,
            sensitivityExpansion: sensitivity.zoneExpansion,
            hairTopMargin: hairTopMargin
        )
        let hit = handPoints.contains { faceZone.contains($0) }
        updateHit(hit)
        emitObservation(faceZone: faceZone, hit: hit, handPoints: handPoints)
    }

    private func emitPreview(_ pixelBuffer: CVPixelBuffer) {
        guard previewEnabled else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return }
        DispatchQueue.main.async {
            self.onPreviewFrame?(cgImage)
        }
    }

    private func emitFrame() {
        guard onFrame != nil else { return }
        DispatchQueue.main.async {
            self.onFrame?()
        }
    }

    static func resolveDevice(for cameraID: String?) -> AVCaptureDevice? {
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

    private func emitObservation(faceZone: CGRect?, hit: Bool, handPoints: [CGPoint]) {
        DispatchQueue.main.async {
            self.onObservation(DetectionObservation(hit: hit, faceZone: faceZone, handPoints: handPoints))
        }
    }

    private func resolveFaceBox(
        faceBox: CGRect?,
        handPoints: [CGPoint],
        now: CFTimeInterval,
        faceZoneScale: CGFloat
    ) -> CGRect? {
        let result = DetectionFaceCache.resolve(
            faceBox: faceBox,
            handPoints: handPoints,
            now: now,
            faceZoneScale: faceZoneScale,
            lastFaceBox: lastFaceBoundingBox,
            lastFaceTime: lastFaceTime,
            sensitivityExpansion: sensitivity.zoneExpansion,
            hairTopMargin: hairTopMargin,
            faceCacheDuration: faceCacheDuration
        )
        lastFaceBoundingBox = result.lastFaceBox
        lastFaceTime = result.lastFaceTime
        return result.faceBox
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

#if DEBUG
extension DetectionEngine {
    func _testStartSession(completion: @escaping (DetectionStartError?) -> Void) {
        startSession(completion: completion)
    }

    func _testStartSessionMonitor() {
        startSessionMonitor()
    }

    func _testStopSessionMonitor() {
        stopSessionMonitor()
    }

    func _testStartSessionObservers() {
        startSessionObservers()
    }

    func _testConfigureSession(cameraID: String?) -> DetectionStartError? {
        configureSession(cameraID: cameraID)
    }

    func _testProcessFrame(_ sampleBuffer: CMSampleBuffer) {
        processFrame(sampleBuffer)
    }

    func _testProcessDetection(
        faceBox: CGRect?,
        handPoints: [CGPoint],
        now: CFTimeInterval,
        faceZoneScale: CGFloat
    ) {
        processDetection(
            faceBox: faceBox,
            handPoints: handPoints,
            now: now,
            faceZoneScale: faceZoneScale
        )
    }

    func _testHandleSessionMonitorTick(now: CFTimeInterval) {
        handleSessionMonitorTick(now: now)
    }

    func _testSetIsRunning(_ value: Bool) {
        isRunning = value
    }

    func _testSetLastFrameTime(_ value: CFTimeInterval) {
        lastFrameTime = value
    }

    var _testLastFrameTime: CFTimeInterval {
        lastFrameTime
    }

    func _testSetRestartHandler(_ handler: @escaping () -> Void) {
        testRestartHandler = handler
    }

    var _testRestartCount: Int {
        testRestartCount
    }

    func _testSetSessionMonitorInterval(_ interval: TimeInterval) {
        testSessionMonitorInterval = interval
    }

    var _testIsInterrupted: Bool {
        isInterrupted
    }

    var _testSessionObserverCount: Int {
        sessionObservers.count
    }

    func _testResetState() {
        resetState()
    }

    func _testSetPreviewEnabledImmediate(_ enabled: Bool) {
        previewEnabled = enabled
    }

    func _testSetPreviewHandlerImmediate(_ handler: @escaping (CGImage) -> Void) {
        onPreviewFrame = handler
    }

    func _testSetFrameHandlerImmediate(_ handler: @escaping () -> Void) {
        onFrame = handler
    }

    func _testFrameInterval(previewEnabled: Bool) -> CFTimeInterval {
        frameInterval(previewEnabled: previewEnabled)
    }

    func _testSessionPreset(previewEnabled: Bool) -> AVCaptureSession.Preset {
        sessionPreset(previewEnabled: previewEnabled)
    }

    func _testHandleRuntimeError(_ notification: Notification) {
        handleSessionRuntimeError(notification)
    }

    func _testHandleSessionInterrupted(_ notification: Notification) {
        handleSessionInterrupted(notification)
    }

    func _testEvaluateStall(now: CFTimeInterval, stallThreshold: CFTimeInterval = 2.5) {
        if DetectionSessionHealth.shouldRestartForStall(
            lastFrameTime: lastFrameTime,
            now: now,
            stallThreshold: stallThreshold
        ) {
            restartSession()
        }
    }

    func _testUpdateHit(_ hit: Bool) {
        updateHit(hit)
    }
}
#endif
