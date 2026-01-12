import SwiftUI

/// Professional Timeline View with Zoom, Pan, and Events
struct TimelineView: View {
    @EnvironmentObject var appState: AppState
    
    // View State
    @State private var zoomLevel: Double = 1.0 // 1.0 = Default (e.g. 100px per second)
    @State private var scrollOffset: CGFloat = 0
    @State private var isDraggingPlayhead: Bool = false
    
    // Constants
    private let basePixelsPerSecond: Double = 100.0
    private let rulerHeight: CGFloat = 28
    private let trackHeight: CGFloat = 30
    private let playheadWidth: CGFloat = 12
    
    // Computed
    private var pixelsPerSecond: Double { basePixelsPerSecond * zoomLevel }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            // Toolbar
            HStack {
                // Time Display
                if let capture = appState.currentCapture {
                    let time = Double(appState.currentFrame) / capture.markers.frameRate
                    Text(formatTime(time))
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(.white)
                    
                    Text("/ \(formatTime(capture.duration))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("--:--:---")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Zoom Controls
                HStack(spacing: 12) {
                    Button(action: { adjustZoom(by: 0.5) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    
                    // Reset / Fit
                    Button(action: { zoomLevel = 1.0 }) {
                        Text("\(Int(zoomLevel * 100))%")
                            .font(.caption.monospaced())
                            .frame(width: 40)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { adjustZoom(by: 2.0) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Timeline Content
            GeometryReader { geo in
                if let capture = appState.currentCapture {
                    let contentWidth = max(geo.size.width, CGFloat(capture.duration * pixelsPerSecond))
                    
                    ScrollView(.horizontal, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            
                            // 1. Ruler Background
                            Color(nsColor: .controlBackgroundColor)
                                .frame(height: rulerHeight + trackHeight + 20)
                            
                            // 2. Ticks & Labels (Ruler)
                            TimelineRuler(
                                duration: capture.duration,
                                pixelsPerSecond: pixelsPerSecond,
                                height: rulerHeight
                            )
                            .frame(width: contentWidth, height: rulerHeight)
                            
                            // 3. Events Track
                            if !capture.events.isEmpty {
                                ZStack(alignment: .leading) {
                                    ForEach(capture.events) { event in
                                        EventMarker(event: event)
                                            .position(
                                                x: CGFloat(event.time * pixelsPerSecond),
                                                y: trackHeight / 2
                                            )
                                    }
                                }
                                .frame(width: contentWidth, height: trackHeight)
                                .offset(y: rulerHeight)
                            }
                            
                            // 4. Playhead (Full Height Line)
                            Rectangle()
                                .fill(AppTheme.accent)
                                .frame(width: 1)
                                .frame(height: geo.size.height) // Full height of container
                                .offset(x: timeToX(
                                    Double(appState.currentFrame) / capture.markers.frameRate
                                ))
                            
                            // 5. Playhead Handle (Draggable)
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.accent)
                                .offset(x: timeToX(
                                    Double(appState.currentFrame) / capture.markers.frameRate
                                ) - 7) // Center the 14px icon
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            isDraggingPlayhead = true
                                            let time = xToTime(value.location.x)
                                            appState.seekToTime(time)
                                        }
                                        .onEnded { _ in isDraggingPlayhead = false }
                                )
                        }
                        .frame(width: contentWidth, height: geo.size.height)
                        // Tap to Seek on background
                        .onTapGesture { location in
                            let time = xToTime(location.x)
                            appState.seekToTime(time)
                        }
                    }
                } else {
                    ContentUnavailableView("No Timeline", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .frame(minHeight: 100)
        .background(AppTheme.background)
    }
    
    // MARK: - Helpers
    
    private func adjustZoom(by factor: Double) {
        if factor > 1 {
            zoomLevel = min(10.0, zoomLevel * 1.5)
        } else {
            zoomLevel = max(0.1, zoomLevel * 0.75)
        }
    }
    
    private func timeToX(_ time: Double) -> CGFloat {
        CGFloat(time * pixelsPerSecond)
    }
    
    private func xToTime(_ x: CGFloat) -> Double {
        Double(x) / pixelsPerSecond
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%03d", minutes, secs, millis)
    }
}

// MARK: - Subcomponents

struct TimelineRuler: View {
    let duration: Double
    let pixelsPerSecond: Double
    let height: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let tickColor = Color.white.opacity(0.4)
            let labelColor = Color.white.opacity(0.7)
            
            // Adaptive Tick Spacing
            // If zoomed out (low pixels/sec), show every 1s, 5s, 10s
            // If zoomed in, show every 0.1s
            
            let majorInterval: Double
            if pixelsPerSecond < 20 { majorInterval = 10.0 }
            else if pixelsPerSecond < 50 { majorInterval = 5.0 }
            else if pixelsPerSecond < 150 { majorInterval = 1.0 }
            else { majorInterval = 0.5 }
            
            let minorDivisions = 5
            let minorInterval = majorInterval / Double(minorDivisions)
            
            let startTime = 0.0
            let endTime = duration
            
            // Draw Ticks
            var t = startTime
            while t <= endTime {
                let x = t * pixelsPerSecond
                guard x < size.width else { break }
                
                let isMajor = abs(t.truncatingRemainder(dividingBy: majorInterval)) < 0.001
                
                let tickHeight = isMajor ? height * 0.6 : height * 0.3
                // Draw tick
                var path = Path()
                let xPos = CGFloat(x)
                path.move(to: CGPoint(x: xPos, y: height))
                path.addLine(to: CGPoint(x: xPos, y: height - tickHeight))
                
                context.stroke(path, with: .color(tickColor), lineWidth: 1)
                
                // Draw Label for Major
                if isMajor {
                    let text = Text(String(format: "%.1fs", t))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(labelColor)
                    
                    context.draw(text, at: CGPoint(x: CGFloat(x) + 2, y: height - tickHeight - 8), anchor: .topLeading)
                }
                
                t += minorInterval
            }
        }
    }
}

struct EventMarker: View {
    let event: MotionEvent
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: event.iconName)
                .font(.system(size: 10))
                .foregroundStyle(eventColor)
            
            // Optional Label
            // Text(event.label).font(.caption2)
        }
        .padding(4)
        .background(eventColor.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help("\(event.label) (\(event.context ?? "General")) at \(String(format: "%.3f", event.time))s")
    }
    
    var eventColor: Color {
        switch event.context?.lowercased() {
        case "left": return .red
        case "right": return .blue
        default: return .yellow
        }
    }
}
