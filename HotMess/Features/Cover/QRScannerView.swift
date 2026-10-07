//
//  QRScannerView.swift
//  HotMess
//

@preconcurrency import AVFoundation
import SwiftUI
import UIKit

/// Whether the app can use the camera.
enum CameraAccess: Sendable {
    case unknown
    case granted
    case denied
    /// No camera, e.g. the simulator.
    case unavailable

    /// Asks the first time; afterwards reports what the user chose.
    static func request() async -> CameraAccess {
        guard AVCaptureDevice.default(for: .video) != nil else { return .unavailable }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .granted
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        default:
            return .denied
        }
    }
}

/// The camera, full bleed, reporting each QR code it reads.
struct QRScannerView: UIViewRepresentable {
    let onCode: @MainActor (String) -> Void

    func makeCoordinator() -> QRCaptureSession {
        QRCaptureSession()
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = context.coordinator.session
        context.coordinator.onCode = onCode
        context.coordinator.start()
        return view
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) {
        context.coordinator.onCode = onCode
    }

    static func dismantleUIView(_ view: CameraPreviewView, coordinator: QRCaptureSession) {
        coordinator.onCode = nil
        coordinator.stop()
    }
}

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClass guarantees the type.
        layer as! AVCaptureVideoPreviewLayer
    }
}

/// Runs the capture session off the main thread, as AVFoundation asks, and
/// hands QR codes to the main actor.
final class QRCaptureSession: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()

    /// Called with each code read. Set and called on the main actor.
    @MainActor var onCode: (@MainActor (String) -> Void)?

    /// Touched only on `queue`.
    private var isConfigured = false
    private let queue = DispatchQueue(label: "social.hotmess.door.camera")

    func start() {
        queue.async { [self] in
            if !isConfigured {
                configure()
                isConfigured = true
            }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        if output.availableMetadataObjectTypes.contains(.qr) {
            output.metadataObjectTypes = [.qr]
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let codes = metadataObjects.compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
        guard let code = codes.first else { return }

        // The delegate queue is the main queue.
        MainActor.assumeIsolated {
            onCode?(code)
        }
    }
}
