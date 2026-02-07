//
//  CameraManager.swift
//  StudySessionApp
//
//  Created by Max Finch on 2/7/26.
//


import AVFoundation
import Vision
import Combine

final class CameraManager: NSObject, ObservableObject {

    @Published var faceDetected: Bool = false

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let visionQueue = DispatchQueue(label: "vision.queue")

    private var lastVisionRun = Date.distantPast

    override init() {
        super.init()
        configure()
    }

    // MARK: - Camera Setup (macOS-safe, modern)

    private func configure() {
        session.sessionPreset = .medium

        guard
            let camera = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            print("❌ Camera unavailable")
            return
        }

        session.addInput(input)

        // REQUIRED on macOS
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]

        output.setSampleBufferDelegate(self, queue: visionQueue)

        guard session.canAddOutput(output) else {
            print("❌ Cannot add video output")
            return
        }

        session.addOutput(output)

        // ✅ Modern rotation API (no warnings)
        if let connection = output.connection(with: .video) {
            connection.isEnabled = true
            connection.videoRotationAngle = 90
        }

        print("✅ Camera configured")
    }

    func start() {
        checkPermissionAndStart()
    }

    private func checkPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            session.startRunning()
            print("✅ Camera running")

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.session.startRunning()
                        print("✅ Camera running (after permission)")
                    }
                }
            }

        default:
            print("❌ Camera permission denied")
        }
    }
}

// MARK: - Frame Processing

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Throttle Vision (macOS stability)
        let now = Date()
        guard now.timeIntervalSince(lastVisionRun) > 0.5 else { return }
        lastVisionRun = now

        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            DispatchQueue.main.async {
                let count = request.results?.count ?? 0
                print("Vision ran. Faces:", count)
                self?.faceDetected = count > 0
            }
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: buffer,
            orientation: .leftMirrored,
            options: [:]
        )

        try? handler.perform([request])
    }
}
