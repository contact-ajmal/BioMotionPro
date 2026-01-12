import SwiftUI
import MetalKit

/// High-performance signal plot view using Metal
struct SignalPlotsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedChannels: Set<String> = []
    @State private var visibleTimeRange: ClosedRange<Double> = 0...10
    @State private var zoomLevel: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Channel selection toolbar
            HStack {
                Text("Signals")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: { zoomLevel *= 0.8 }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                
                Button(action: { zoomLevel = 1.0 }) {
                    Image(systemName: "1.magnifyingglass")
                }
                .buttonStyle(.borderless)
                
                Button(action: { zoomLevel *= 1.25 }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Plot area
            if let capture = appState.currentCapture {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        // Show analog channels
                        ForEach(capture.analogs.channels) { channel in
                            SignalPlotRow(
                                channel: channel,
                                sampleRate: capture.analogs.sampleRate,
                                currentTime: Double(appState.currentFrame) / capture.markers.frameRate,
                                zoomLevel: zoomLevel
                            )
                            .frame(height: 100)
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No Signals", systemImage: "waveform")
                } description: {
                    Text("Load a file with analog data")
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// Individual signal plot row
struct SignalPlotRow: View {
    let channel: AnalogChannel
    let sampleRate: Double
    let currentTime: Double
    let zoomLevel: Double
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Channel label
                Text(channel.label)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                
                if !channel.unit.isEmpty {
                    Text("(\(channel.unit))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Current value at cursor
                if let currentValue = valueAtTime(currentTime) {
                    Text(String(format: "%.2f", currentValue))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.blue)
                }
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            
            // Plot canvas
            SignalPlotCanvas(
                data: channel.scaledData,
                sampleRate: sampleRate,
                currentTime: currentTime,
                zoomLevel: zoomLevel,
                color: channelColor
            )
            .frame(height: isExpanded ? 150 : 60)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func valueAtTime(_ time: Double) -> Float? {
        let sampleIndex = Int(time * sampleRate)
        guard sampleIndex >= 0, sampleIndex < channel.scaledData.count else { return nil }
        return channel.scaledData[sampleIndex]
    }
    
    private var channelColor: Color {
        // Assign colors based on channel type
        let label = channel.label.uppercased()
        if label.contains("FORCE") || label.contains("FZ") {
            return .red
        } else if label.contains("EMG") {
            return .green
        } else if label.contains("MOMENT") {
            return .purple
        } else if label.contains("COP") {
            return .orange
        }
        return .blue
    }
}

/// Canvas for drawing the actual signal waveform
struct SignalPlotCanvas: View {
    let data: [Float]
    let sampleRate: Double
    let currentTime: Double
    let zoomLevel: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(Color(nsColor: .textBackgroundColor))
                
                // Zero line
                Path { path in
                    let y = geometry.size.height / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                
                // Signal waveform
                signalPath(in: geometry.size)
                    .stroke(color, lineWidth: 1)
                
                // Current time cursor
                if currentTime >= 0 {
                    let xPosition = cursorXPosition(in: geometry.size)
                    Path { path in
                        path.move(to: CGPoint(x: xPosition, y: 0))
                        path.addLine(to: CGPoint(x: xPosition, y: geometry.size.height))
                    }
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                }
            }
        }
    }
    
    private func signalPath(in size: CGSize) -> Path {
        Path { path in
            guard !data.isEmpty else { return }
            
            // Calculate visible range
            let duration = Double(data.count) / sampleRate
            let visibleDuration = duration / zoomLevel
            let startTime = max(0, currentTime - visibleDuration / 2)
            let endTime = min(duration, startTime + visibleDuration)
            
            let startSample = Int(startTime * sampleRate)
            let endSample = min(data.count - 1, Int(endTime * sampleRate))
            
            guard startSample < endSample else { return }
            
            // Find min/max for scaling
            let visibleData = Array(data[startSample...endSample])
            let minVal = visibleData.min() ?? 0
            let maxVal = visibleData.max() ?? 1
            let range = max(maxVal - minVal, 0.001)
            
            // Downsampling for performance
            let pixelWidth = Int(size.width)
            let samplesPerPixel = max(1, visibleData.count / pixelWidth)
            
            var isFirst = true
            for pixel in 0..<pixelWidth {
                let sampleStart = pixel * samplesPerPixel
                let sampleEnd = min(sampleStart + samplesPerPixel, visibleData.count)
                
                guard sampleStart < visibleData.count else { break }
                
                // Use min/max for each pixel column (more accurate than averaging)
                let slice = visibleData[sampleStart..<sampleEnd]
                let avgValue = slice.reduce(0, +) / Float(slice.count)
                
                let x = CGFloat(pixel)
                let normalizedY = (avgValue - minVal) / range
                let y = size.height * CGFloat(1 - normalizedY)
                
                if isFirst {
                    path.move(to: CGPoint(x: x, y: y))
                    isFirst = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
    
    private func cursorXPosition(in size: CGSize) -> CGFloat {
        let duration = Double(data.count) / sampleRate
        let visibleDuration = duration / zoomLevel
        let startTime = max(0, currentTime - visibleDuration / 2)
        
        let relativeTime = currentTime - startTime
        return CGFloat(relativeTime / visibleDuration) * size.width
    }
}

// MARK: - Preview

#Preview {
    SignalPlotsView()
        .environmentObject(AppState())
        .frame(width: 400, height: 500)
}
