import Foundation
import Accelerate
import simd

/// Biomechanics computation engine using Apple's Accelerate framework
public actor BiomechanicsEngine {
    
    // MARK: - Signal Processing
    
    /// Apply a Butterworth low-pass filter to signal data
    public func butterworthLowpass(
        data: [Float],
        sampleRate: Double,
        cutoffFrequency: Double,
        order: Int = 4
    ) -> [Float] {
        guard data.count > order * 2 else { return data }
        
        // Normalized cutoff (Nyquist = sampleRate/2)
        let wn = cutoffFrequency / (sampleRate / 2.0)
        
        // Design filter coefficients (simplified 2nd order cascade)
        let coefficients = designButterworthCoefficients(cutoff: wn, order: order)
        
        // Apply filter (forward-backward for zero phase)
        var filtered = applyIIRFilter(data: data, coefficients: coefficients)
        filtered = applyIIRFilter(data: filtered.reversed(), coefficients: coefficients).reversed()
        
        return Array(filtered)
    }
    
    /// Apply a bandpass filter (common for EMG: 20-450 Hz)
    public func bandpassFilter(
        data: [Float],
        sampleRate: Double,
        lowCutoff: Double,
        highCutoff: Double
    ) -> [Float] {
        // High-pass first
        let highPassed = butterworthHighpass(data: data, sampleRate: sampleRate, cutoffFrequency: lowCutoff)
        
        // Then low-pass
        return butterworthLowpass(data: highPassed, sampleRate: sampleRate, cutoffFrequency: highCutoff)
    }
    
    private func butterworthHighpass(
        data: [Float],
        sampleRate: Double,
        cutoffFrequency: Double
    ) -> [Float] {
        // Compute as: highpass = original - lowpass
        let lowpassed = butterworthLowpass(data: data, sampleRate: sampleRate, cutoffFrequency: cutoffFrequency)
        
        var result = [Float](repeating: 0, count: data.count)
        vDSP_vsub(lowpassed, 1, data, 1, &result, 1, vDSP_Length(data.count))
        
        return result
    }
    
    private func designButterworthCoefficients(cutoff: Double, order: Int) -> BiquadCoefficients {
        // Simplified 2nd order Butterworth design
        let w0 = tan(.pi * cutoff)
        let w0sq = w0 * w0
        let q = sqrt(2.0)  // Q factor for Butterworth
        
        let norm = 1.0 / (1.0 + w0 / q + w0sq)
        
        return BiquadCoefficients(
            b0: Float(w0sq * norm),
            b1: Float(2.0 * w0sq * norm),
            b2: Float(w0sq * norm),
            a1: Float(2.0 * (w0sq - 1.0) * norm),
            a2: Float((1.0 - w0 / q + w0sq) * norm)
        )
    }
    
    private func applyIIRFilter(data: [Float], coefficients: BiquadCoefficients) -> [Float] {
        var output = [Float](repeating: 0, count: data.count)
        var z1: Float = 0
        var z2: Float = 0
        
        for i in 0..<data.count {
            let input = data[i]
            let result = coefficients.b0 * input + z1
            z1 = coefficients.b1 * input - coefficients.a1 * result + z2
            z2 = coefficients.b2 * input - coefficients.a2 * result
            output[i] = result
        }
        
        return output
    }
    
    // MARK: - EMG Processing
    
    /// Full EMG processing pipeline
    public func processEMG(
        raw: [Float],
        sampleRate: Double,
        bandpassLow: Double = 20,
        bandpassHigh: Double = 450,
        notchFrequency: Double? = 60,  // 50Hz in Europe
        rectify: Bool = true,
        envelopeCutoff: Double = 6
    ) -> [Float] {
        // 1. Bandpass filter
        var processed = bandpassFilter(
            data: raw,
            sampleRate: sampleRate,
            lowCutoff: bandpassLow,
            highCutoff: bandpassHigh
        )
        
        // 2. Notch filter for power line noise (optional)
        if let notch = notchFrequency {
            processed = notchFilter(data: processed, sampleRate: sampleRate, frequency: notch)
        }
        
        // 3. Full-wave rectification
        if rectify {
            vDSP_vabs(processed, 1, &processed, 1, vDSP_Length(processed.count))
        }
        
        // 4. Low-pass envelope
        processed = butterworthLowpass(data: processed, sampleRate: sampleRate, cutoffFrequency: envelopeCutoff)
        
        return processed
    }
    
    private func notchFilter(data: [Float], sampleRate: Double, frequency: Double, bandwidth: Double = 2.0) -> [Float] {
        // Simple notch using IIR
        let w0 = 2.0 * .pi * frequency / sampleRate
        let q = frequency / bandwidth
        let alpha = sin(w0) / (2.0 * q)
        
        let b0 = Float(1.0)
        let b1 = Float(-2.0 * cos(w0))
        let b2 = Float(1.0)
        let a0 = Float(1.0 + alpha)
        let a1 = Float(-2.0 * cos(w0))
        let a2 = Float(1.0 - alpha)
        
        let coefficients = BiquadCoefficients(
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0
        )
        
        return applyIIRFilter(data: data, coefficients: coefficients)
    }
    
    // MARK: - Kinematics
    
    /// Compute numerical derivatives (velocity, acceleration) with filtering
    public func computeDerivatives(
        positions: [[SIMD3<Float>?]],
        sampleRate: Double,
        filterCutoff: Double = 6.0
    ) -> (velocity: [[SIMD3<Float>?]], acceleration: [[SIMD3<Float>?]]) {
        let dt = Float(1.0 / sampleRate)
        var velocities: [[SIMD3<Float>?]] = []
        var accelerations: [[SIMD3<Float>?]] = []
        
        let markerCount = positions.first?.count ?? 0
        let frameCount = positions.count
        
        // For each marker, extract time series and differentiate
        for markerIdx in 0..<markerCount {
            var x: [Float] = []
            var y: [Float] = []
            var z: [Float] = []
            var validMask: [Bool] = []
            
            for frame in 0..<frameCount {
                if let pos = positions[frame][markerIdx] {
                    x.append(pos.x)
                    y.append(pos.y)
                    z.append(pos.z)
                    validMask.append(true)
                } else {
                    x.append(0)
                    y.append(0)
                    z.append(0)
                    validMask.append(false)
                }
            }
            
            // Central difference for velocity
            let vx = centralDifference(x, dt: dt)
            let vy = centralDifference(y, dt: dt)
            let vz = centralDifference(z, dt: dt)
            
            // Central difference for acceleration
            let ax = centralDifference(vx, dt: dt)
            let ay = centralDifference(vy, dt: dt)
            let az = centralDifference(vz, dt: dt)
            
            // Store (expanding arrays as needed)
            for frame in 0..<frameCount {
                if velocities.count <= frame {
                    velocities.append(Array(repeating: nil, count: markerCount))
                    accelerations.append(Array(repeating: nil, count: markerCount))
                }
                
                if validMask[frame] {
                    velocities[frame][markerIdx] = SIMD3(vx[frame], vy[frame], vz[frame])
                    accelerations[frame][markerIdx] = SIMD3(ax[frame], ay[frame], az[frame])
                }
            }
        }
        
        return (velocities, accelerations)
    }
    
    private func centralDifference(_ data: [Float], dt: Float) -> [Float] {
        guard data.count >= 3 else { return Array(repeating: 0, count: data.count) }
        
        var result = [Float](repeating: 0, count: data.count)
        
        // Forward difference for first point
        result[0] = (data[1] - data[0]) / dt
        
        // Central difference for middle points
        for i in 1..<(data.count - 1) {
            result[i] = (data[i + 1] - data[i - 1]) / (2.0 * dt)
        }
        
        // Backward difference for last point
        result[data.count - 1] = (data[data.count - 1] - data[data.count - 2]) / dt
        
        return result
    }
    
    // MARK: - Joint Angles
    
    /// Compute angle between three markers (returns angle at middle marker)
    public func computeAngle(
        proximal: SIMD3<Float>,
        center: SIMD3<Float>,
        distal: SIMD3<Float>
    ) -> Float {
        let v1 = normalize(proximal - center)
        let v2 = normalize(distal - center)
        let dotProduct = simd_dot(v1, v2)
        return acos(simd_clamp(dotProduct, -1, 1)) * 180 / .pi
    }
    
    /// Compute joint angles over time for a given joint definition
    public func computeJointAngleTimeSeries(
        markers: MarkerData,
        proximalLabel: String,
        centerLabel: String,
        distalLabel: String
    ) -> [Float?] {
        guard let proxIdx = markers.markerIndex(for: proximalLabel),
              let centIdx = markers.markerIndex(for: centerLabel),
              let distIdx = markers.markerIndex(for: distalLabel) else {
            return []
        }
        
        var angles: [Float?] = []
        
        for frame in 0..<markers.frameCount {
            guard let prox = markers.position(marker: proxIdx, frame: frame),
                  let cent = markers.position(marker: centIdx, frame: frame),
                  let dist = markers.position(marker: distIdx, frame: frame) else {
                angles.append(nil)
                continue
            }
            
            angles.append(computeAngle(proximal: prox, center: cent, distal: dist))
        }
        
        return angles
    }
    
    // MARK: - Gait Analysis
    
    /// Detect gait events from vertical ground reaction force
    public func detectGaitEventsFromGRF(
        verticalForce: [Float],
        sampleRate: Double,
        threshold: Float = 20  // Newtons
    ) -> [GaitEvent] {
        var events: [GaitEvent] = []
        var wasLoaded = false
        
        for (i, force) in verticalForce.enumerated() {
            let isLoaded = force > threshold
            
            if isLoaded && !wasLoaded {
                // Foot strike (heel strike)
                let time = Double(i) / sampleRate
                events.append(GaitEvent(type: .heelStrike, time: time, sampleIndex: i))
            } else if !isLoaded && wasLoaded {
                // Toe off
                let time = Double(i) / sampleRate
                events.append(GaitEvent(type: .toeOff, time: time, sampleIndex: i))
            }
            
            wasLoaded = isLoaded
        }
        
        return events
    }
    
    /// Compute spatiotemporal gait parameters
    public func computeSpatiotemporalParameters(
        events: [GaitEvent],
        heelMarkerPositions: [SIMD3<Float>?],
        sampleRate: Double
    ) -> SpatiotemporalParameters? {
        // Find heel strike pairs
        let heelStrikes = events.filter { $0.type == .heelStrike }
        let toeOffs = events.filter { $0.type == .toeOff }
        
        guard heelStrikes.count >= 2, !toeOffs.isEmpty else { return nil }
        
        // Stride time (consecutive heel strikes of same foot)
        var strideTimes: [Double] = []
        for i in 0..<(heelStrikes.count - 1) {
            strideTimes.append(heelStrikes[i + 1].time - heelStrikes[i].time)
        }
        
        // Stance time (heel strike to toe off)
        var stanceTimes: [Double] = []
        for hs in heelStrikes {
            if let to = toeOffs.first(where: { $0.time > hs.time }) {
                stanceTimes.append(to.time - hs.time)
            }
        }
        
        // Calculate stride length from marker positions
        var strideLengths: [Float] = []
        for i in 0..<(heelStrikes.count - 1) {
            let idx1 = heelStrikes[i].sampleIndex
            let idx2 = heelStrikes[i + 1].sampleIndex
            
            if idx1 < heelMarkerPositions.count, idx2 < heelMarkerPositions.count,
               let pos1 = heelMarkerPositions[idx1],
               let pos2 = heelMarkerPositions[idx2] {
                let distance = simd_length(pos2 - pos1)
                strideLengths.append(distance)
            }
        }
        
        let avgStrideTime = strideTimes.isEmpty ? 0 : strideTimes.reduce(0, +) / Double(strideTimes.count)
        let avgStanceTime = stanceTimes.isEmpty ? 0 : stanceTimes.reduce(0, +) / Double(stanceTimes.count)
        let avgStrideLength = strideLengths.isEmpty ? 0 : strideLengths.reduce(0, +) / Float(strideLengths.count)
        
        return SpatiotemporalParameters(
            cadence: avgStrideTime > 0 ? 60.0 / avgStrideTime : 0,
            strideLength: Double(avgStrideLength) / 1000.0,  // Convert mm to m
            gaitSpeed: avgStrideTime > 0 ? Double(avgStrideLength) / 1000.0 / avgStrideTime : 0,
            stancePhase: avgStrideTime > 0 ? (avgStanceTime / avgStrideTime) * 100 : 0,
            swingPhase: avgStrideTime > 0 ? ((avgStrideTime - avgStanceTime) / avgStrideTime) * 100 : 0
        )
    }
}

// MARK: - Supporting Types

struct BiquadCoefficients {
    let b0, b1, b2: Float
    let a1, a2: Float
}

public struct GaitEvent: Sendable {
    public enum EventType: Sendable {
        case heelStrike
        case toeOff
        case footFlat
        case midSwing
    }
    
    public let type: EventType
    public let time: Double
    public let sampleIndex: Int
}

public struct SpatiotemporalParameters: Sendable {
    public let cadence: Double           // steps/min
    public let strideLength: Double      // meters
    public let gaitSpeed: Double         // m/s
    public let stancePhase: Double       // % of gait cycle
    public let swingPhase: Double        // % of gait cycle
}
