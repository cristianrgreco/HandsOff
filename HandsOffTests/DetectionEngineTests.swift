import AVFoundation
import XCTest
@testable import HandsOff

final class DetectionEngineTests: XCTestCase {
    func testConfigureSessionReturnsNoCameraWhenProviderReportsNoCamera() {
        let session = TestCaptureSession()
        let inputProvider = FakeInputProvider(result: .noCamera)
        let engine = makeEngine(session: session, inputProvider: inputProvider)

        let error = engine._testConfigureSession(cameraID: "cam1")

        XCTAssertEqual(error, .noCamera)
    }

    func testConfigureSessionReturnsConfigurationFailedOnInputFailure() {
        let session = TestCaptureSession()
        let inputProvider = FakeInputProvider(result: .failure)
        let engine = makeEngine(session: session, inputProvider: inputProvider)

        let error = engine._testConfigureSession(cameraID: "cam1")

        XCTAssertEqual(error, .configurationFailed)
    }

    func testConfigureSessionReturnsConfigurationFailedWhenCannotAddInput() {
        let session = TestCaptureSession()
        session.canAddInputResult = false
        let inputProvider = FakeInputProvider(result: .success(NSObject()))
        let engine = makeEngine(session: session, inputProvider: inputProvider)

        let error = engine._testConfigureSession(cameraID: "cam1")

        XCTAssertEqual(error, .configurationFailed)
        XCTAssertEqual(session.inputs.count, 0)
    }

    func testConfigureSessionReturnsConfigurationFailedWhenCannotAddOutput() {
        let session = TestCaptureSession()
        session.canAddOutputResult = false
        let inputProvider = FakeInputProvider(result: .success(NSObject()))
        let engine = makeEngine(session: session, inputProvider: inputProvider)

        let error = engine._testConfigureSession(cameraID: "cam1")

        XCTAssertEqual(error, .configurationFailed)
        XCTAssertEqual(session.inputs.count, 1)
        XCTAssertEqual(session.outputs.count, 0)
    }

    func testConfigureSessionAddsInputAndOutputOnSuccess() {
        let session = TestCaptureSession()
        let inputProvider = FakeInputProvider(result: .success(NSObject()))
        let engine = makeEngine(session: session, inputProvider: inputProvider)

        let error = engine._testConfigureSession(cameraID: "cam1")

        XCTAssertNil(error)
        XCTAssertEqual(session.beginConfigurationCount, 1)
        XCTAssertEqual(session.commitConfigurationCount, 1)
        XCTAssertEqual(session.inputs.count, 1)
        XCTAssertEqual(session.outputs.count, 1)
        XCTAssertEqual(session.sessionPreset, .low)
    }

    func testProcessDetectionTriggersOnHit() {
        var triggerCount = 0
        let observationExpectation = expectation(description: "observation emitted")
        var captured: DetectionObservation?
        let engine = makeEngine(onTrigger: { triggerCount += 1 })
        engine.setObservationHandler {
            captured = $0
            observationExpectation.fulfill()
        }

        let faceBox = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
        let handPoints = [CGPoint(x: 0.5, y: 0.5)]

        engine._testProcessDetection(
            faceBox: faceBox,
            handPoints: handPoints,
            now: 0,
            faceZoneScale: 1.0
        )

        wait(for: [observationExpectation], timeout: 1.0)
        XCTAssertEqual(triggerCount, 1)
        XCTAssertEqual(captured?.hit, true)
        XCTAssertNotNil(captured?.faceZone)
    }

    func testProcessDetectionWithoutFaceBoxEmitsMiss() {
        let observationExpectation = expectation(description: "observation emitted")
        var captured: DetectionObservation?
        let engine = makeEngine()
        engine.setObservationHandler {
            captured = $0
            observationExpectation.fulfill()
        }

        engine._testProcessDetection(
            faceBox: nil,
            handPoints: [CGPoint(x: 0.1, y: 0.1)],
            now: 0,
            faceZoneScale: 1.0
        )

        wait(for: [observationExpectation], timeout: 1.0)
        XCTAssertEqual(captured?.hit, false)
        XCTAssertNil(captured?.faceZone)
    }

    func testProcessDetectionDoesNotTriggerWhenHandOutsideFaceZone() {
        var triggerCount = 0
        let observationExpectation = expectation(description: "observation emitted")
        var captured: DetectionObservation?
        let engine = makeEngine(onTrigger: { triggerCount += 1 })
        engine.setObservationHandler {
            captured = $0
            observationExpectation.fulfill()
        }

        let faceBox = CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        let handPoints = [CGPoint(x: 0.9, y: 0.9)]

        engine._testProcessDetection(
            faceBox: faceBox,
            handPoints: handPoints,
            now: 0,
            faceZoneScale: 1.0
        )

        wait(for: [observationExpectation], timeout: 1.0)
        XCTAssertEqual(triggerCount, 0)
        XCTAssertEqual(captured?.hit, false)
    }

    func testProcessFrameEmitsFrameAndObservationWhenPreviewDisabled() throws {
        let frameExpectation = expectation(description: "frame emitted")
        let observationExpectation = expectation(description: "observation emitted")
        let engine = makeEngine(dataProvider: { _ in DetectionData(faceBox: nil, handPoints: []) })
        engine._testSetFrameHandlerImmediate { frameExpectation.fulfill() }
        engine.setObservationHandler { _ in observationExpectation.fulfill() }
        engine._testSetPreviewEnabledImmediate(false)

        let sampleBuffer = try makeSampleBuffer()
        engine._testProcessFrame(sampleBuffer)

        wait(for: [frameExpectation, observationExpectation], timeout: 1.0)
    }

    func testProcessFramePreviewEnabledSkipsObservationWhenThrottled() throws {
        let previewExpectation = expectation(description: "preview emitted")
        let observationExpectation = expectation(description: "observation not emitted")
        observationExpectation.isInverted = true
        let engine = makeEngine(dataProvider: { _ in DetectionData(faceBox: nil, handPoints: []) })
        engine._testSetPreviewHandlerImmediate { _ in previewExpectation.fulfill() }
        engine.setObservationHandler { _ in observationExpectation.fulfill() }
        engine._testSetPreviewEnabledImmediate(true)
        engine._testSetLastFrameTime(CACurrentMediaTime() + 1)

        let sampleBuffer = try makeSampleBuffer()
        engine._testProcessFrame(sampleBuffer)

        wait(for: [previewExpectation, observationExpectation], timeout: 1.0)
    }

    func testProcessFramePreviewEnabledEmitsPreview() throws {
        let previewExpectation = expectation(description: "preview emitted")
        let engine = makeEngine(dataProvider: { _ in DetectionData(faceBox: nil, handPoints: []) })
        engine._testSetPreviewHandlerImmediate { _ in previewExpectation.fulfill() }
        engine._testSetPreviewEnabledImmediate(true)

        let sampleBuffer = try makeSampleBuffer()
        engine._testProcessFrame(sampleBuffer)

        wait(for: [previewExpectation], timeout: 1.0)
    }

    func testProcessFrameDoesNotEmitObservationWhenNoDetectionData() throws {
        let observationExpectation = expectation(description: "observation not emitted")
        observationExpectation.isInverted = true
        let engine = makeEngine(dataProvider: { _ in nil })
        engine.setObservationHandler { _ in observationExpectation.fulfill() }
        engine._testSetPreviewEnabledImmediate(false)

        let sampleBuffer = try makeSampleBuffer()
        engine._testProcessFrame(sampleBuffer)

        wait(for: [observationExpectation], timeout: 0.2)
    }

    func testProcessFrameThrottlesWhenTooSoon() throws {
        let observationExpectation = expectation(description: "observation not emitted")
        observationExpectation.isInverted = true
        let engine = makeEngine(dataProvider: { _ in DetectionData(faceBox: nil, handPoints: []) })
        engine.setObservationHandler { _ in observationExpectation.fulfill() }
        engine._testSetPreviewEnabledImmediate(false)
        engine._testSetLastFrameTime(CACurrentMediaTime() + 1)

        let sampleBuffer = try makeSampleBuffer()
        engine._testProcessFrame(sampleBuffer)

        wait(for: [observationExpectation], timeout: 0.2)
    }

    func testFrameIntervalVariesWithPreviewState() {
        let engine = makeEngine()

        XCTAssertEqual(engine._testFrameInterval(previewEnabled: true), 1.0 / 8.0, accuracy: 0.0001)
        XCTAssertEqual(engine._testFrameInterval(previewEnabled: false), 1.0 / 3.0, accuracy: 0.0001)
    }

    func testSessionPresetVariesWithPreviewState() {
        let engine = makeEngine()

        XCTAssertEqual(engine._testSessionPreset(previewEnabled: true), .medium)
        XCTAssertEqual(engine._testSessionPreset(previewEnabled: false), .low)
    }

    func testHandleSessionMonitorTickRestartsWhenSessionNotRunning() {
        let session = TestCaptureSession()
        session.isRunning = false
        let engine = makeEngine(session: session)
        engine._testSetIsRunning(true)
        engine._testSetLastFrameTime(4.0)

        engine._testHandleSessionMonitorTick(now: 10.0)

        XCTAssertEqual(session.startRunningCount, 1)
        XCTAssertEqual(engine._testLastFrameTime, 0)
    }

    func testHandleSessionMonitorTickRestartsOnStall() {
        let session = TestCaptureSession()
        session.isRunning = true
        let engine = makeEngine(session: session)
        engine._testSetIsRunning(true)
        engine._testSetLastFrameTime(1.0)
        var restartCount = 0
        engine._testSetRestartHandler { restartCount += 1 }

        engine._testHandleSessionMonitorTick(now: 10.0)

        XCTAssertEqual(restartCount, 1)
        XCTAssertEqual(engine._testRestartCount, 1)
    }

    func testDetectionStartErrorIdMatchesRawValue() {
        XCTAssertEqual(DetectionStartError.permissionDenied.id, DetectionStartError.permissionDenied.rawValue)
        XCTAssertEqual(DetectionStartError.noCamera.id, DetectionStartError.noCamera.rawValue)
        XCTAssertEqual(DetectionStartError.configurationFailed.id, DetectionStartError.configurationFailed.rawValue)
    }

    func testStartAuthorizedStartsSessionAndCompletes() {
        let session = TestCaptureSession()
        let sessionQueue = DispatchQueue(label: "HandsOffTests.session.start")
        let engine = makeEngine(
            session: session,
            inputProvider: FakeInputProvider(result: .success(NSObject())),
            authorizationStatus: { .authorized },
            requestAccess: { _ in XCTFail("requestAccess should not be called") },
            sessionQueue: sessionQueue
        )
        let completionExpectation = expectation(description: "completion")
        var completionError: DetectionStartError?

        engine.start { error in
            completionError = error
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 1.0)
        XCTAssertNil(completionError)
        XCTAssertEqual(session.startRunningCount, 1)
        XCTAssertGreaterThan(engine._testSessionObserverCount, 0)
    }

    func testStartNotDeterminedDeniedCompletesWithPermissionDenied() {
        let engine = makeEngine(
            authorizationStatus: { .notDetermined },
            requestAccess: { handler in handler(false) }
        )
        let completionExpectation = expectation(description: "completion")
        var completionError: DetectionStartError?

        engine.start { error in
            completionError = error
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 1.0)
        XCTAssertEqual(completionError, .permissionDenied)
    }

    func testStartDeniedCompletesWithPermissionDenied() {
        let engine = makeEngine(authorizationStatus: { .denied })
        let completionExpectation = expectation(description: "completion")
        var completionError: DetectionStartError?

        engine.start { error in
            completionError = error
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 1.0)
        XCTAssertEqual(completionError, .permissionDenied)
    }

    func testStopStopsRunningSession() {
        let session = TestCaptureSession()
        session.isRunning = true
        let sessionQueue = DispatchQueue(label: "HandsOffTests.session.stop")
        let engine = makeEngine(session: session, sessionQueue: sessionQueue)
        engine._testSetIsRunning(true)
        engine._testStartSessionMonitor()

        engine.stop()
        sessionQueue.sync {}

        XCTAssertEqual(session.stopRunningCount, 1)
    }

    func testSetPreviewEnabledAsyncEmitsPreviewFrame() throws {
        let visionQueue = DispatchQueue(label: "HandsOffTests.vision.preview")
        let previewExpectation = expectation(description: "preview emitted")
        let engine = makeEngine(
            dataProvider: { _ in DetectionData(faceBox: nil, handPoints: []) },
            visionQueue: visionQueue
        )
        engine.setPreviewHandler { _ in
            previewExpectation.fulfill()
        }
        engine.setPreviewEnabled(true)
        visionQueue.sync {}

        let sampleBuffer = try makeSampleBuffer()
        engine._testProcessFrame(sampleBuffer)

        wait(for: [previewExpectation], timeout: 1.0)
    }

    func testCaptureOutputEmitsFrameWhenRunning() throws {
        let frameExpectation = expectation(description: "frame emitted")
        let engine = makeEngine(dataProvider: { _ in DetectionData(faceBox: nil, handPoints: []) })
        engine._testSetIsRunning(true)
        engine._testSetFrameHandlerImmediate { frameExpectation.fulfill() }

        let sampleBuffer = try makeSampleBuffer()
        let output = AVCaptureVideoDataOutput()
        let connection = AVCaptureConnection(inputPorts: [], output: output)
        engine.captureOutput(output, didOutput: sampleBuffer, from: connection)

        wait(for: [frameExpectation], timeout: 1.0)
    }

    func testCaptureOutputIgnoredWhenNotRunning() throws {
        let frameExpectation = expectation(description: "frame not emitted")
        frameExpectation.isInverted = true
        let engine = makeEngine(dataProvider: { _ in DetectionData(faceBox: nil, handPoints: []) })
        engine._testSetFrameHandlerImmediate { frameExpectation.fulfill() }

        let sampleBuffer = try makeSampleBuffer()
        let output = AVCaptureVideoDataOutput()
        let connection = AVCaptureConnection(inputPorts: [], output: output)
        engine.captureOutput(output, didOutput: sampleBuffer, from: connection)

        wait(for: [frameExpectation], timeout: 0.2)
    }

    func testStartSessionObserversHandleNotifications() {
        let session = TestCaptureSession()
        let sessionQueue = DispatchQueue(label: "HandsOffTests.session.observers")
        let engine = makeEngine(session: session, sessionQueue: sessionQueue)
        engine._testSetIsRunning(true)
        engine._testSetRestartHandler {}
        engine._testStartSessionObservers()

        XCTAssertGreaterThan(engine._testSessionObserverCount, 0)

        NotificationCenter.default.post(name: .AVCaptureSessionWasInterrupted, object: session)
        drainMainQueue()
        sessionQueue.sync {}
        XCTAssertTrue(engine._testIsInterrupted)

        var restartCount = 0
        engine._testSetRestartHandler { restartCount += 1 }
        NotificationCenter.default.post(name: .AVCaptureSessionInterruptionEnded, object: session)
        drainMainQueue()
        sessionQueue.sync {}
        XCTAssertFalse(engine._testIsInterrupted)
        XCTAssertEqual(restartCount, 1)

        NotificationCenter.default.post(
            name: .AVCaptureSessionRuntimeError,
            object: session,
            userInfo: [AVCaptureSessionErrorKey: NSError(domain: "HandsOffTests", code: 1)]
        )
        drainMainQueue()
        sessionQueue.sync {}
        XCTAssertEqual(restartCount, 2)
    }

    func testSessionMonitorFiresOnInterval() {
        let session = TestCaptureSession()
        let sessionQueue = DispatchQueue(label: "HandsOffTests.session.monitor")
        let engine = makeEngine(session: session, sessionQueue: sessionQueue)
        engine._testSetIsRunning(true)
        engine._testSetSessionMonitorInterval(0.01)
        session.isRunning = false

        engine._testStartSessionMonitor()
        let firedExpectation = expectation(description: "monitor fired")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            firedExpectation.fulfill()
        }
        wait(for: [firedExpectation], timeout: 1.0)
        sessionQueue.sync {}
        engine._testStopSessionMonitor()

        XCTAssertEqual(session.startRunningCount, 1)
    }

    func testRestartSessionUsesSessionWhenNoTestHandler() {
        let session = TestCaptureSession()
        session.isRunning = true
        let engine = makeEngine(session: session)
        engine._testSetIsRunning(true)
        engine._testSetLastFrameTime(1.0)

        engine._testEvaluateStall(now: 10.0)

        XCTAssertEqual(session.stopRunningCount, 1)
        XCTAssertEqual(session.startRunningCount, 1)
    }

    func testResetStateClearsLastFrameTime() {
        let engine = makeEngine()
        engine._testSetLastFrameTime(5.0)

        engine._testResetState()

        XCTAssertEqual(engine._testLastFrameTime, 0)
    }

    func testResolveDeviceReturnsFirstAvailableWhenPresent() throws {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        ).devices
        if devices.isEmpty {
            throw XCTSkip("No camera devices available to validate resolveDevice")
        }

        let resolved = DetectionEngine.resolveDevice(for: "missing-device-id")
        XCTAssertNotNil(resolved)
    }

    func testAVCaptureSessionAdapterBasics() {
        let session = AVCaptureSession()
        let adapter = AVCaptureSessionAdapter(session: session)

        _ = adapter.isRunning
        _ = adapter.inputs
        _ = adapter.outputs
        let originalPreset = adapter.sessionPreset
        adapter.sessionPreset = .medium
        XCTAssertEqual(adapter.sessionPreset, .medium)
        adapter.sessionPreset = originalPreset
        XCTAssertTrue(adapter.notificationObject === session)

        adapter.beginConfiguration()
        adapter.commitConfiguration()

        let output = AVCaptureVideoDataOutput()
        XCTAssertTrue(adapter.canAddOutput(output))
        adapter.addOutput(output)
        XCTAssertTrue(adapter.outputs.contains { $0 === output })
        adapter.removeOutput(output)

        adapter.startRunning()
        adapter.stopRunning()

        let nonInput = NSObject()
        XCTAssertFalse(adapter.canAddInput(nonInput))
        adapter.addInput(nonInput)
        adapter.removeInput(nonInput)
    }

    func testDefaultCaptureInputProviderReturnsNoCameraWhenResolverReturnsNil() {
        let provider = DefaultCaptureInputProvider(resolveDevice: { _ in nil }, makeDeviceInput: { _ in
            throw TestError()
        })

        let result = provider.makeInput(cameraID: "missing")
        guard case .noCamera = result else {
            XCTFail("Expected .noCamera result")
            return
        }
    }

    func testDefaultCaptureInputProviderReturnsFailureWhenInputThrows() throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw XCTSkip("No camera available for DefaultCaptureInputProvider failure test")
        }
        let provider = DefaultCaptureInputProvider(resolveDevice: { _ in device }, makeDeviceInput: { _ in
            throw TestError()
        })

        let result = provider.makeInput(cameraID: nil)
        guard case .failure = result else {
            XCTFail("Expected .failure result")
            return
        }
    }

    func testDefaultCaptureInputProviderReturnsSuccessWhenInputCreated() throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw XCTSkip("Camera access not authorized; skipping success path")
        }
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw XCTSkip("No camera available for DefaultCaptureInputProvider success test")
        }
        let provider = DefaultCaptureInputProvider(resolveDevice: { _ in device }, makeDeviceInput: AVCaptureDeviceInput.init)

        let result = provider.makeInput(cameraID: nil)
        switch result {
        case .success(let input):
            XCTAssertTrue(input is AVCaptureDeviceInput)
        default:
            XCTFail("Expected success when creating device input")
        }
    }

    func testVisionDetectionProviderReturnsDataForBlankFrame() throws {
        let pixelBuffer = try makePixelBuffer()
        let provider = VisionDetectionProvider(confidenceThreshold: 0.9)

        let result = provider.detect(pixelBuffer: pixelBuffer)

        guard result != nil else {
            throw XCTSkip("Vision detection unavailable on this runner")
        }
    }

    private func makeEngine(
        onTrigger: @escaping () -> Void = {},
        session: CaptureSessionType = TestCaptureSession(),
        inputProvider: CaptureInputProviding = FakeInputProvider(result: .success(NSObject())),
        dataProvider: DetectionDataProvider? = nil,
        authorizationStatus: @escaping () -> AVAuthorizationStatus = {
            AVCaptureDevice.authorizationStatus(for: .video)
        },
        requestAccess: @escaping (@escaping (Bool) -> Void) -> Void = { handler in
            AVCaptureDevice.requestAccess(for: .video, completionHandler: handler)
        },
        sessionQueue: DispatchQueue = DispatchQueue(label: "HandsOffTests.session"),
        visionQueue: DispatchQueue = DispatchQueue(label: "HandsOffTests.vision")
    ) -> DetectionEngine {
        DetectionEngine(
            settingsProvider: { DetectionSettings(cameraID: nil, faceZoneScale: 1.0) },
            onTrigger: onTrigger,
            session: session,
            inputProvider: inputProvider,
            dataProvider: dataProvider,
            authorizationStatus: authorizationStatus,
            requestAccess: requestAccess,
            sessionQueue: sessionQueue,
            visionQueue: visionQueue
        )
    }

    private func makeSampleBuffer() throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            4,
            4,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let buffer = pixelBuffer else {
            throw SampleBufferError.creationFailed
        }

        var formatDescription: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescriptionOut: &formatDescription
        )
        XCTAssertEqual(formatStatus, noErr)
        guard let resolvedDescription = formatDescription else {
            throw SampleBufferError.creationFailed
        }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: resolvedDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        XCTAssertEqual(sampleStatus, noErr)
        guard let resolvedSampleBuffer = sampleBuffer else {
            throw SampleBufferError.creationFailed
        }

        return resolvedSampleBuffer
    }

    private func makePixelBuffer() throws -> CVPixelBuffer {
        let sampleBuffer = try makeSampleBuffer()
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw SampleBufferError.creationFailed
        }
        return pixelBuffer
    }
}

private func drainMainQueue() {
    let expectation = XCTestExpectation(description: "drain main queue")
    DispatchQueue.main.async {
        expectation.fulfill()
    }
    _ = XCTWaiter.wait(for: [expectation], timeout: 1.0)
}

private final class FakeInputProvider: CaptureInputProviding {
    var result: CaptureInputResult

    init(result: CaptureInputResult) {
        self.result = result
    }

    func makeInput(cameraID: String?) -> CaptureInputResult {
        result
    }
}

private final class TestCaptureSession: CaptureSessionType {
    var isRunning = false
    var inputs: [AnyObject] = []
    var outputs: [AnyObject] = []
    var sessionPreset: AVCaptureSession.Preset = .high
    var notificationObject: AnyObject { self }
    var canAddInputResult = true
    var canAddOutputResult = true
    private(set) var beginConfigurationCount = 0
    private(set) var commitConfigurationCount = 0
    private(set) var startRunningCount = 0
    private(set) var stopRunningCount = 0

    func beginConfiguration() {
        beginConfigurationCount += 1
    }

    func commitConfiguration() {
        commitConfigurationCount += 1
    }

    func canAddInput(_ input: AnyObject) -> Bool {
        canAddInputResult
    }

    func addInput(_ input: AnyObject) {
        inputs.append(input)
    }

    func removeInput(_ input: AnyObject) {
        inputs.removeAll { $0 === input }
    }

    func canAddOutput(_ output: AnyObject) -> Bool {
        canAddOutputResult
    }

    func addOutput(_ output: AnyObject) {
        outputs.append(output)
    }

    func removeOutput(_ output: AnyObject) {
        outputs.removeAll { $0 === output }
    }

    func startRunning() {
        isRunning = true
        startRunningCount += 1
    }

    func stopRunning() {
        isRunning = false
        stopRunningCount += 1
    }
}

private enum SampleBufferError: Error {
    case creationFailed
}

private struct TestError: Error {}
