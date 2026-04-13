import SwiftUI
import Combine
import AVFoundation
import Vision

// MARK: - FormCheckerView

struct FormCheckerView: View {
    let exerciseName: String
    @StateObject private var model = FormCheckerModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if let session = model.captureSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
                    .id(model.sessionID)
            } else {
                Color.black.ignoresSafeArea()
            }

            SkeletonOverlayView(joints: model.joints)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top bar
                HStack(alignment: .center) {
                    Button {
                        model.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 3)
                    }

                    Spacer()

                    // Joint count indicator
                    if model.detectedJointCount > 0 {
                        Label("\(model.detectedJointCount)/19 joints", systemImage: "figure.stand")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(model.detectedJointCount >= 10 ? Color.green.opacity(0.7) : Color.orange.opacity(0.7))
                            .clipShape(Capsule())
                    } else {
                        Label("Place phone sideways", systemImage: "rectangle.landscape.rotate")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.45))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button { model.flipCamera() } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                VStack(spacing: 6) {
                    Text(exerciseName.uppercased())
                        .font(.caption2.bold())
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(model.feedback)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(model.feedbackBgColor.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.4), radius: 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
                .animation(.easeInOut(duration: 0.25), value: model.feedback)
            }
        }
        .onAppear { model.start(exerciseName: exerciseName) }
        .onDisappear { model.stop() }
        .statusBarHidden()
    }
}

// MARK: - FormCheckerModel

@MainActor
final class FormCheckerModel: ObservableObject {
    @Published var feedback: String = "Getting ready…"
    @Published var feedbackBgColor: Color = .gray
    @Published var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var detectedJointCount: Int = 0
    @Published private(set) var captureSession: AVCaptureSession?
    @Published private(set) var sessionID = UUID()

    private var currentPosition: AVCaptureDevice.Position = .back
    private var captureDelegate: VideoCaptureDelegate?
    private var currentExercise: String = ""
    private var orientationObserver: NSObjectProtocol?

    func start(exerciseName: String) {
        currentExercise = exerciseName
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.pushOrientation() }
        setupCamera(position: .back)
    }

    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        captureDelegate = nil
        if let obs = orientationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    func flipCamera() {
        currentPosition = currentPosition == .back ? .front : .back
        setupCamera(position: currentPosition)
    }

    /// Converts current UIDevice orientation → CGImagePropertyOrientation for Vision.
    private func visionOrientation(for deviceOrientation: UIDeviceOrientation,
                                   position: AVCaptureDevice.Position) -> CGImagePropertyOrientation {
        // The rear camera sensor's "natural" output is landscape-right (.up).
        // Front camera mirrors horizontally on top of that.
        switch deviceOrientation {
        case .portrait:
            return position == .front ? .leftMirrored : .right
        case .portraitUpsideDown:
            return position == .front ? .rightMirrored : .left
        case .landscapeLeft:      // home button on the RIGHT
            return position == .front ? .downMirrored : .up
        case .landscapeRight:     // home button on the LEFT
            return position == .front ? .upMirrored : .down
        default:
            return position == .front ? .leftMirrored : .right
        }
    }

    private func pushOrientation() {
        let ori = visionOrientation(for: UIDevice.current.orientation, position: currentPosition)
        captureDelegate?.imageOrientation = ori
    }

    private func setupCamera(position: AVCaptureDevice.Position) {
        captureSession?.stopRunning()

        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            feedback = "Camera unavailable on this device"
            return
        }
        session.addInput(input)

        // Initial orientation
        let initialOrientation = visionOrientation(for: UIDevice.current.orientation, position: position)

        let exercise = currentExercise
        let delegate = VideoCaptureDelegate(
            exerciseName: exercise,
            initialOrientation: initialOrientation
        ) { [weak self] fb, color, jts, count in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.feedback = fb
                self.feedbackBgColor = color
                self.joints = jts
                self.detectedJointCount = count
            }
        }
        captureDelegate = delegate

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(
            delegate,
            queue: DispatchQueue(label: "formchecker.video", qos: .userInteractive)
        )

        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        captureSession = session
        sessionID = UUID()

        let s = session
        Task.detached(priority: .userInitiated) { s.startRunning() }
    }
}

// MARK: - VideoCaptureDelegate

final class VideoCaptureDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let exerciseName: String
    private let exerciseType: ExerciseType
    // One stateful analyser per session (retains previous frame for deadlift)
    private let formAnalyzer = FormAnalyzer()
    // Updated from main thread on device rotation
    nonisolated(unsafe) var imageOrientation: CGImagePropertyOrientation

    private let onUpdate: (String, Color, [VNHumanBodyPoseObservation.JointName: CGPoint], Int) -> Void

    init(
        exerciseName: String,
        initialOrientation: CGImagePropertyOrientation,
        onUpdate: @escaping (String, Color, [VNHumanBodyPoseObservation.JointName: CGPoint], Int) -> Void
    ) {
        self.exerciseName    = exerciseName
        self.exerciseType    = ExerciseType.from(exerciseName)
        self.imageOrientation = initialOrientation
        self.onUpdate        = onUpdate
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: imageOrientation,
                                            options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first else {
            onUpdate("Stand fully in frame", .gray, [:], 0)
            return
        }

        guard let allPoints = try? observation.recognizedPoints(.all) else { return }

        // Skeleton display uses a loose threshold (0.1); FormAnalyzer uses its own gate (0.25)
        var screenJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var count = 0
        for (name, point) in allPoints where point.confidence > 0.1 {
            // Flip y: Vision origin is bottom-left, SwiftUI Canvas is top-left
            screenJoints[name] = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
            count += 1
        }

        let results  = formAnalyzer.analyzeForm(for: exerciseType, points: allPoints)
        let top      = results.topFeedback
        let message  = top?.message ?? "Analyzing your form…"
        let color    = top?.color   ?? .gray
        onUpdate(message, color, screenJoints, count)
    }
}

// MARK: - CameraPreviewView

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

// MARK: - SkeletonOverlayView

struct SkeletonOverlayView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]

    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .root),
        (.neck, .leftShoulder),  (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow),   (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.root, .leftHip),  (.root, .rightHip), (.leftHip, .rightHip),
        (.leftHip, .leftKnee),   (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.neck, .nose)
    ]

    var body: some View {
        Canvas { ctx, size in
            // Bones
            for (j1, j2) in connections {
                guard let p1 = joints[j1], let p2 = joints[j2] else { continue }
                let s1 = CGPoint(x: p1.x * size.width, y: p1.y * size.height)
                let s2 = CGPoint(x: p2.x * size.width, y: p2.y * size.height)
                var line = Path()
                line.move(to: s1)
                line.addLine(to: s2)
                ctx.stroke(line, with: .color(.green.opacity(0.9)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            // Joints
            for pt in joints.values {
                let sp = CGPoint(x: pt.x * size.width, y: pt.y * size.height)
                let r: CGFloat = 5
                let oval = Path(ellipseIn: CGRect(x: sp.x - r, y: sp.y - r, width: 2*r, height: 2*r))
                ctx.fill(oval, with: .color(.yellow.opacity(0.9)))
                ctx.stroke(oval, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
            }
        }
    }
}
