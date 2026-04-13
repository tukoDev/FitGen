import Foundation
import SwiftUI
import Vision

// MARK: - FormFeedback

struct FormFeedback {
    enum Severity { case good, warning, error }

    let severity: Severity
    let message: String

    var color: Color {
        switch severity {
        case .good:    return .green
        case .warning: return .yellow
        case .error:   return .orange
        }
    }
}

extension [FormFeedback] {
    /// Returns the highest-priority feedback: error > warning > good.
    var topFeedback: FormFeedback? {
        first(where: { $0.severity == .error })
            ?? first(where: { $0.severity == .warning })
            ?? first(where: { $0.severity == .good })
    }
}

// MARK: - ExerciseType

enum ExerciseType {
    case squat
    case deadlift
    case pushUp
    case shoulderPress
    case lateralRaise
    case bicepCurl
    case unsupported

    static func from(_ name: String) -> ExerciseType {
        let n = name.lowercased()
        if n.contains("squat")                          { return .squat }
        if n.contains("deadlift")                       { return .deadlift }
        if n.contains("push") || n.contains("push-up")  { return .pushUp }
        if n.contains("shoulder press")                 { return .shoulderPress }
        if n.contains("lateral raise")                  { return .lateralRaise }
        if n.contains("bicep") || n.contains("curl")    { return .bicepCurl }
        return .unsupported
    }
}

// MARK: - FormAnalyzer

/// Stateful pose analyser. One instance per camera session — retains the previous
/// frame for exercises that need temporal comparisons (e.g. deadlift).
final class FormAnalyzer {

    typealias JointMap = [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]

    // Stored for deadlift temporal analysis
    private var previousPoints: JointMap?

    // ─── Temporal state ────────────────────────────────────────────────────────

    /// EMA-smoothed angle cache. Key = "exercise.angleName", e.g. "sq.knee".
    private var smoothedAngles: [String: Double] = [:]
    private let emaAlpha: Double = 0.45

    /// Returned when joints are briefly missing — avoids empty/flickering output.
    private var lastValidFeedback: [FormFeedback] = []

    // Squat phase state machine
    private enum SquatPhase { case top, descending, bottom, ascending }
    private var squatPhase: SquatPhase = .top
    private var squatHipYHistory: [Double] = []
    private let sqPhaseMotionThreshold: Double = 0.008

    // ─── Thresholds ────────────────────────────────────────────────────────────

    // Bicep Curl
    private let bcFullContractionAngle: Double  = 50
    private let bcTopRangeAngle: Double         = 95
    private let bcFullExtensionAngle: Double    = 155

    // Squat
    private let sqTooDeepAngle: Double          = 70
    private let sqNotDeepEnoughAngle: Double    = 110
    private let sqGoodMin: Double               = 80
    private let sqGoodMax: Double               = 100
    private let sqKneeCaveThreshold: Double     = 0.06
    private let sqForwardLeanAngle: Double      = 40

    // Deadlift
    private let dlBackAngle: Double             = 45
    private let dlKneeAngle: Double             = 80
    private let dlBarDrift: Double              = 0.09
    private let dlHipRiseNoiseFloor: Double     = 0.01

    // Push-up
    private let puGoodDepthAngle: Double        = 45
    private let puTooShallowAngle: Double       = 90
    private let puHipSagThreshold: Double       = 0.08
    private let puHeadDropThreshold: Double     = 0.12

    // Shoulder Press
    private let spElbowTooLowAngle: Double      = 80
    private let spWristAlignThreshold: Double   = 0.13
    private let spTorsoLeanThreshold: Double    = 0.20
    private let spShrugThreshold: Double        = 0.04

    // Lateral Raise
    private let lrElbowBendAngle: Double        = 150
    private let lrTorsoSwayThreshold: Double    = 0.08
    private let lrShrugThreshold: Double        = 0.07

    // ─── Dispatcher ────────────────────────────────────────────────────────────

    func analyzeForm(
        for exerciseType: ExerciseType,
        points: JointMap
    ) -> [FormFeedback] {
        defer { previousPoints = points }
        let results: [FormFeedback]
        switch exerciseType {
        case .bicepCurl:     results = analyzeBicepCurl(points: points)
        case .squat:         results = analyzeSquat(points: points)
        case .deadlift:      results = analyzeDeadlift(points: points)
        case .pushUp:        results = analyzePushUp(points: points)
        case .shoulderPress: results = analyzeShoulderPress(points: points)
        case .lateralRaise:  results = analyzeLateralRaise(points: points)
        default:             return []
        }
        // Stability: hold last valid feedback when joints are briefly missing
        if results.isEmpty { return lastValidFeedback }
        lastValidFeedback = results
        return results
    }

    // ─── Reference implementation ──────────────────────────────────────────────

    /// Bicep Curl — reference pattern. All other analysers follow this exact structure.
    private func analyzeBicepCurl(points: JointMap) -> [FormFeedback] {
        guard points.count >= 10 else { return [] }
        guard
            let shoulder = bestPoint(points, left: .leftShoulder, right: .rightShoulder),
            let elbow    = bestPoint(points, left: .leftElbow,    right: .rightElbow),
            let wrist    = bestPoint(points, left: .leftWrist,    right: .rightWrist)
        else { return [] }

        var results: [FormFeedback] = []
        let curlAngle = angle(a: shoulder, b: elbow, c: wrist)

        if curlAngle < bcFullContractionAngle {
            results.append(FormFeedback(severity: .good,    message: "Tam kasılma! ✅"))
        } else if curlAngle < bcTopRangeAngle {
            results.append(FormFeedback(severity: .warning, message: "Daha yukarı kıvır!"))
        } else if curlAngle > bcFullExtensionAngle {
            results.append(FormFeedback(severity: .good,    message: "Tam uzatma ✅"))
        }

        return results
    }

    // ─── Exercise analysers ────────────────────────────────────────────────────

    private func analyzeSquat(points: JointMap) -> [FormFeedback] {
        guard points.count >= 10 else { return [] }
        guard
            let hip   = bestPoint(points, left: .leftHip,   right: .rightHip),
            let knee  = bestPoint(points, left: .leftKnee,  right: .rightKnee),
            let ankle = bestPoint(points, left: .leftAnkle, right: .rightAnkle)
        else { return [] }

        // Drive phase state machine with current hip.y
        updateSquatPhase(hipY: Double(hip.y))

        var results: [FormFeedback] = []

        // Knee angle — smoothed, evaluated only at BOTTOM
        let kneeAngle = smooth("sq.knee", value: angle(a: hip, b: knee, c: ankle))
        if squatPhase == .bottom {
            if kneeAngle < sqTooDeepAngle {
                results.append(FormFeedback(severity: .error,
                    message: "Çok derine iniyorsun, eklemlerine dikkat et"))
            } else if kneeAngle > sqNotDeepEnoughAngle {
                results.append(FormFeedback(severity: .warning,
                    message: "Daha derine in, paralel geç"))
            } else if kneeAngle >= sqGoodMin && kneeAngle <= sqGoodMax {
                results.append(FormFeedback(severity: .good,
                    message: "Güzel derinlik ✅"))
            }
        }

        // Shoulder needed for body scale + forward lean
        guard let shoulder = bestPoint(points, left: .leftShoulder, right: .rightShoulder)
        else { return results }

        let scale = bodyScale(shoulder: shoulder, hip: hip)

        // Improved knee cave — knee.x vs hip.x alignment, body-scaled threshold.
        // Evaluated during ASCENDING where valgus is most visible.
        if squatPhase == .ascending {
            let kneeDeviation = Double(abs(knee.x - hip.x))
            if kneeDeviation > sqKneeCaveThreshold * scale {
                results.append(FormFeedback(severity: .warning,
                    message: "Dizlerin içe çöküyor, dışa it"))
            }
        }

        // Forward lean — smoothed, always evaluated
        let leanAngle = smooth("sq.lean", value: verticalAngle(from: shoulder, to: hip))
        if leanAngle > sqForwardLeanAngle {
            results.append(FormFeedback(severity: .error,
                message: "Gövden çok öne eğiliyor, sırtını dik tut"))
        }

        return results
    }

    private func analyzeDeadlift(points: JointMap) -> [FormFeedback] {
        guard points.count >= 10 else { return [] }
        guard
            let shoulder = bestPoint(points, left: .leftShoulder, right: .rightShoulder),
            let hip      = bestPoint(points, left: .leftHip,      right: .rightHip),
            let knee     = bestPoint(points, left: .leftKnee,     right: .rightKnee)
        else { return [] }

        var results: [FormFeedback] = []

        // Back angle — smoothed
        let backAngle = smooth("dl.back", value: verticalAngle(from: shoulder, to: hip))
        if backAngle > dlBackAngle {
            results.append(FormFeedback(severity: .error,
                message: "Lockout'ta sırtın eğik, tam dik ol"))
        }

        // Knee angle at setup — smoothed
        guard let ankle = bestPoint(points, left: .leftAnkle, right: .rightAnkle)
        else { return results }
        let kneeAngle = smooth("dl.knee", value: angle(a: hip, b: knee, c: ankle))
        if kneeAngle < dlKneeAngle {
            results.append(FormFeedback(severity: .warning,
                message: "Çok çömüyorsun, bu squat değil deadlift"))
        }

        // Bar drift (wrist horizontal vs hip)
        guard let wrist = bestPoint(points, left: .leftWrist, right: .rightWrist)
        else { return results }
        if abs(wrist.x - hip.x) > dlBarDrift {
            results.append(FormFeedback(severity: .warning,
                message: "Bar vücudundan uzaklaşıyor, yakın tut"))
        }

        // Hip vs shoulder rise (temporal — requires previous frame)
        if let prev = previousPoints,
           let prevHip      = bestPoint(prev, left: .leftHip,      right: .rightHip),
           let prevShoulder = bestPoint(prev, left: .leftShoulder,  right: .rightShoulder) {
            let hipRise      = Double(hip.y      - prevHip.y)
            let shoulderRise = Double(shoulder.y - prevShoulder.y)
            if hipRise > shoulderRise + dlHipRiseNoiseFloor {
                results.append(FormFeedback(severity: .error,
                    message: "Kalçan omzundan önce kalkıyor, bacaklarınla it"))
            }
        }

        return results
    }

    private func analyzePushUp(points: JointMap) -> [FormFeedback] {
        guard points.count >= 10 else { return [] }
        guard
            let shoulder = bestPoint(points, left: .leftShoulder, right: .rightShoulder),
            let elbow    = bestPoint(points, left: .leftElbow,    right: .rightElbow),
            let wrist    = bestPoint(points, left: .leftWrist,    right: .rightWrist)
        else { return [] }

        var results: [FormFeedback] = []

        // Elbow angle — smoothed
        let elbowAngle = smooth("pu.elbow", value: angle(a: shoulder, b: elbow, c: wrist))
        if elbowAngle < puGoodDepthAngle {
            results.append(FormFeedback(severity: .good,    message: "Full derinlik ✅"))
        } else if elbowAngle > puTooShallowAngle {
            results.append(FormFeedback(severity: .warning, message: "Daha derine in"))
        }

        // Hip sag / pike — body-scaled threshold
        guard
            let hip   = bestPoint(points, left: .leftHip,   right: .rightHip),
            let ankle = bestPoint(points, left: .leftAnkle, right: .rightAnkle)
        else { return results }

        let scaledHipSag = puHipSagThreshold * bodyScale(shoulder: shoulder, hip: hip)
        let midY = (shoulder.y + ankle.y) / 2
        if hip.y < midY - scaledHipSag {
            results.append(FormFeedback(severity: .error,
                message: "Kalçan düşüyor, core'unu sıkıştır"))
        } else if hip.y > midY + scaledHipSag {
            results.append(FormFeedback(severity: .error,
                message: "Kalçan çok yukarıda, vücudunu düzelt"))
        }

        // Head drop
        guard let nose = singlePoint(points, .nose) else { return results }
        if nose.y < shoulder.y - puHeadDropThreshold {
            results.append(FormFeedback(severity: .warning,
                message: "Başın düşüyor, nötr pozisyonda tut"))
        }

        return results
    }

    private func analyzeShoulderPress(points: JointMap) -> [FormFeedback] {
        guard points.count >= 10 else { return [] }
        guard
            let shoulder = bestPoint(points, left: .leftShoulder, right: .rightShoulder),
            let elbow    = bestPoint(points, left: .leftElbow,    right: .rightElbow),
            let wrist    = bestPoint(points, left: .leftWrist,    right: .rightWrist)
        else { return [] }

        var results: [FormFeedback] = []

        // Elbow angle — smoothed
        let elbowAngle = smooth("sp.elbow", value: angle(a: shoulder, b: elbow, c: wrist))
        if elbowAngle < spElbowTooLowAngle {
            results.append(FormFeedback(severity: .warning,
                message: "Dirseklerin çok aşağı, omuz stresi var"))
        }

        // Wrist alignment (wrist.x vs elbow.x)
        if abs(wrist.x - elbow.x) > spWristAlignThreshold {
            results.append(FormFeedback(severity: .warning,
                message: "Bileklerin hizasız, düzelt"))
        }

        // Torso lean (shoulder.x vs hip.x) — only when hip is clearly visible
        let hipRaw = points[.leftHip] ?? points[.rightHip]
        guard let hipRaw, hipRaw.confidence > 0.4 else { return results }
        let hip = hipRaw.location
        if abs(shoulder.x - hip.x) > spTorsoLeanThreshold {
            results.append(FormFeedback(severity: .error,
                message: "Gövdeni geriye yaslama, core sıkı tut"))
        }

        // Shrug (ear.y ≈ shoulder.y)
        guard let ear = bestPoint(points, left: .leftEar, right: .rightEar)
        else { return results }
        if abs(ear.y - shoulder.y) < spShrugThreshold {
            results.append(FormFeedback(severity: .warning,
                message: "Boyun sıkışıyor, omuzları aşağı çek"))
        }

        return results
    }

    private func analyzeLateralRaise(points: JointMap) -> [FormFeedback] {
        guard points.count >= 10 else { return [] }
        guard
            let shoulder = bestPoint(points, left: .leftShoulder, right: .rightShoulder),
            let elbow    = bestPoint(points, left: .leftElbow,    right: .rightElbow),
            let wrist    = bestPoint(points, left: .leftWrist,    right: .rightWrist)
        else { return [] }

        var results: [FormFeedback] = []

        // Elbow above shoulder (Vision y increases upward)
        if elbow.y > shoulder.y {
            results.append(FormFeedback(severity: .warning,
                message: "Çok yukarı kaldırıyorsun, omuz hizasında dur"))
        }

        // Elbow bend (shoulder → elbow → wrist) — smoothed
        let elbowAngle = smooth("lr.elbow", value: angle(a: shoulder, b: elbow, c: wrist))
        if elbowAngle < lrElbowBendAngle {
            results.append(FormFeedback(severity: .warning,
                message: "Dirseklerin çok kırık, hile yapıyorsun"))
        }

        // Torso sway (shoulder.x vs hip.x)
        guard let hip = bestPoint(points, left: .leftHip, right: .rightHip)
        else { return results }
        if abs(shoulder.x - hip.x) > lrTorsoSwayThreshold {
            results.append(FormFeedback(severity: .error,
                message: "Gövdeni sallama, momentum kullanma"))
        }

        // Shrug (shoulder.y ≈ ear.y)
        guard let ear = bestPoint(points, left: .leftEar, right: .rightEar)
        else { return results }
        if abs(shoulder.y - ear.y) < lrShrugThreshold {
            results.append(FormFeedback(severity: .warning,
                message: "Omuzlarını kaldırma, aşağı bas"))
        }

        return results
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    /// Angle in degrees at vertex B for chain A→B→C using vector dot-product.
    ///
    ///     angle = arccos( (AB · CB) / (|AB| * |CB|) )
    private func angle(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let ab = CGPoint(x: a.x - b.x, y: a.y - b.y)
        let cb = CGPoint(x: c.x - b.x, y: c.y - b.y)
        let dot  = Double(ab.x * cb.x + ab.y * cb.y)
        let magAB = sqrt(Double(ab.x * ab.x + ab.y * ab.y))
        let magCB = sqrt(Double(cb.x * cb.x + cb.y * cb.y))
        guard magAB > 1e-5, magCB > 1e-5 else { return 0 }
        return acos(max(-1, min(1, dot / (magAB * magCB)))) * 180 / .pi
    }

    /// Angle in degrees between the segment (top → bottom) and the vertical axis.
    /// 0° = perfectly vertical, 90° = horizontal.
    private func verticalAngle(from top: CGPoint, to bottom: CGPoint) -> Double {
        let dx = abs(Double(top.x - bottom.x))
        let dy = abs(Double(top.y - bottom.y))
        guard dy > 1e-5 else { return 90 }
        return atan2(dx, dy) * 180 / .pi
    }

    /// Returns the location of the higher-confidence side (left preferred when equal).
    /// Returns nil if the winning point has confidence ≤ 0.25.
    private func bestPoint(
        _ points: JointMap,
        left: VNHumanBodyPoseObservation.JointName,
        right: VNHumanBodyPoseObservation.JointName
    ) -> CGPoint? {
        let l = points[left]
        let r = points[right]
        let winner: VNRecognizedPoint?
        switch (l, r) {
        case let (lp?, rp?): winner = lp.confidence >= rp.confidence ? lp : rp
        case let (lp?, nil): winner = lp
        case let (nil, rp?): winner = rp
        default:             winner = nil
        }
        guard let w = winner, w.confidence > 0.25 else { return nil }
        return w.location
    }

    // ─── Temporal helpers ──────────────────────────────────────────────────────

    /// Exponential moving average smoother.
    /// `key` namespaces values per exercise+angle so separate analysers don't bleed.
    private func smooth(_ key: String, value: Double) -> Double {
        let prev = smoothedAngles[key] ?? value
        let smoothed = emaAlpha * value + (1 - emaAlpha) * prev
        smoothedAngles[key] = smoothed
        return smoothed
    }

    /// Normalisation scale based on shoulder-to-hip distance.
    /// Returns a multiplier relative to a 0.25-unit reference distance,
    /// clamped to [0.5, 2.0] so extreme poses don't explode thresholds.
    private func bodyScale(shoulder: CGPoint, hip: CGPoint) -> Double {
        let dx = Double(shoulder.x - hip.x)
        let dy = Double(shoulder.y - hip.y)
        let dist = sqrt(dx * dx + dy * dy)
        return max(0.5, min(2.0, dist / 0.25))
    }

    /// Updates the squat phase state machine from successive hip.y readings.
    /// Vision y increases upward, so a *decreasing* hip.y means the person is descending.
    private func updateSquatPhase(hipY: Double) {
        squatHipYHistory.append(hipY)
        if squatHipYHistory.count > 3 { squatHipYHistory.removeFirst() }
        guard squatHipYHistory.count == 3 else { return }
        let trend = squatHipYHistory[2] - squatHipYHistory[0]
        switch squatPhase {
        case .top:
            if trend < -sqPhaseMotionThreshold { squatPhase = .descending }
        case .descending:
            if trend > sqPhaseMotionThreshold  { squatPhase = .bottom }
        case .bottom:
            if trend > sqPhaseMotionThreshold  { squatPhase = .ascending }
        case .ascending:
            if trend < -sqPhaseMotionThreshold        { squatPhase = .descending }
            else if abs(trend) < sqPhaseMotionThreshold { squatPhase = .top }
        }
    }

    /// Single-joint lookup with confidence gate.
    private func singlePoint(
        _ points: JointMap,
        _ name: VNHumanBodyPoseObservation.JointName
    ) -> CGPoint? {
        guard let p = points[name], p.confidence > 0.25 else { return nil }
        return p.location
    }
}
