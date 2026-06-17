import AVFoundation
import Vision

// MARK: - Detection Result

/// Raw output from one Vision frame analysis.
struct FaceDetectionResult {
    let hasFace: Bool
    let leftEyeAR: Double    // eye aspect ratio — ~0.30 open, ~0.05 closed
    let rightEyeAR: Double
    let yaw: Double           // radians; 0 = straight, ±π/2 = full side-turn
    let pitch: Double         // radians; 0 = straight, + = tilted up

    static let noFace = FaceDetectionResult(
        hasFace: false, leftEyeAR: 0, rightEyeAR: 0, yaw: 0, pitch: 0
    )
}

// MARK: - Camera Service

/// Manages the AVCaptureSession and feeds Vision face-landmark results
/// to the `onResult` callback (called on a background thread — hop to
/// MainActor before touching SwiftUI state).
final class FocusCameraService: NSObject {

    // Expose session so SwiftUI can attach an AVCaptureVideoPreviewLayer.
    let session = AVCaptureSession()

    /// Called on `analysisQueue` — NOT main thread.
    var onResult: ((FaceDetectionResult) -> Void)?

    private let sessionQueue  = DispatchQueue(label: "focus.camera.session",  qos: .userInitiated)
    private let analysisQueue = DispatchQueue(label: "focus.camera.analysis", qos: .userInitiated)

    // Throttle Vision to ≈ 3 fps so we don't hammer the CPU.
    private var lastAnalysisTime: TimeInterval = 0
    private let analysisInterval: TimeInterval = 0.34

    // Re-use a single request object (thread-safe after iOS 12).
    private lazy var landmarksRequest = VNDetectFaceLandmarksRequest()

    // MARK: - Lifecycle

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSession()
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Session Configuration

    private func configureSession() {
        // Guard against calling twice.
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = .medium

        // Front camera
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video, position: .front),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // Video data output — raw frames for Vision
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: analysisQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            if let conn = videoOutput.connection(with: .video) {
                if conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
                if conn.isVideoMirroringSupported {
                    conn.isVideoMirrored = true
                }
            }
        }

        session.commitConfiguration()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension FocusCameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        // Throttle
        let now = CACurrentMediaTime()
        guard now - lastAnalysisTime >= analysisInterval else { return }
        lastAnalysisTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Front camera in portrait → raw buffer orientation is leftMirrored
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .leftMirrored,
                                            options: [:])
        do {
            try handler.perform([landmarksRequest])
        } catch {
            onResult?(.noFace)
            return
        }

        guard
            let faces = landmarksRequest.results, !faces.isEmpty,
            let face  = faces.max(by: { $0.boundingBox.area < $1.boundingBox.area })
        else {
            onResult?(.noFace)
            return
        }

        let leftEAR  = FocusAnalyzer.eyeAspectRatio(from: face.landmarks?.leftEye)
        let rightEAR = FocusAnalyzer.eyeAspectRatio(from: face.landmarks?.rightEye)
        let yaw      = face.yaw?.doubleValue   ?? 0.0
        let pitch    = face.pitch?.doubleValue ?? 0.0

        onResult?(FaceDetectionResult(
            hasFace:    true,
            leftEyeAR:  leftEAR,
            rightEyeAR: rightEAR,
            yaw:        yaw,
            pitch:      pitch
        ))
    }
}

// MARK: - Helpers

private extension CGRect {
    var area: CGFloat { width * height }
}
