import SwiftUI

struct FrameRow: Identifiable {
    let id: Int
    let time: Double
    let markers: [SIMD3<Float>?]
}

struct DataEditorView: View {
    @EnvironmentObject var appState: AppState
    @State private var timeSearchText: String = ""
    @State private var selectedFrame: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Toolbar
            VStack(spacing: 12) {
                HStack {
                    Text("Data Editor")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Time Search
                    TextField("Time (s)", text: $timeSearchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onSubmit {
                            if let time = Double(timeSearchText), let capture = appState.currentCapture {
                                let frame = Int(time * capture.markers.frameRate)
                                appState.currentFrame = max(0, min(frame, capture.frameCount - 1))
                            }
                        }
                        .help("Jump to time (Enter to submit)")
                    
                    if let capture = appState.currentCapture {
                        Text("\(capture.frameCount) Frames")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Playback Controls
                if let capture = appState.currentCapture {
                    HStack(spacing: 12) {
                        Button(action: { appState.togglePlayback() }) {
                            Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                        }
                        .keyboardShortcut(.space, modifiers: []) // Allow spacebar in this window too
                        
                        Slider(value: Binding(
                            get: { Double(appState.currentFrame) },
                            set: { appState.currentFrame = Int($0) }
                        ), in: 0...Double(capture.frameCount - 1))
                        
                        Text(String(format: "%.2fs", Double(appState.currentFrame) / capture.markers.frameRate))
                            .monospacedDigit()
                            .font(.caption)
                            .frame(width: 50)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
            if let capture = appState.currentCapture {
                CaptureDataList(capture: capture, selection: $selectedFrame)
                    .onChange(of: appState.currentFrame) { newFrame in
                        selectedFrame = newFrame
                    }
                    .onChange(of: selectedFrame) { newSelection in
                        if let newSelection = newSelection, newSelection != appState.currentFrame {
                            appState.currentFrame = newSelection
                        }
                    }
            } else {
                ContentUnavailableView("No Data", systemImage: "list.dash")
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(AppTheme.background)
    }
}

// Custom Grid-like List implementation to support 2D scrolling and all markers
struct CaptureDataList: View {
    let capture: MotionCapture
    @Binding var selection: Int?
    
    // Column Widths
    private let wFrame: CGFloat = 60
    private let wTime: CGFloat = 80
    private let wVis: CGFloat = 60
    private let wMarker: CGFloat = 180
    
    // Computed total width to ensure row fills space
    private var totalWidth: CGFloat {
        wFrame + wTime + wVis + (CGFloat(capture.markers.labels.count) * (wMarker + 8))
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section(header: headerView) {
                            // Scrollable Rows
                            ForEach(0..<capture.frameCount, id: \.self) { index in
                                DataRowView(
                                    index: index,
                                    capture: capture,
                                    widths: (wFrame, wTime, wVis, wMarker),
                                    isSelected: selection == index
                                )
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selection = index
                                }
                            }
                        }
                    }
                    .frame(minWidth: totalWidth, alignment: .leading)
                }
                .onChange(of: selection) { newSelection in
                    if let target = newSelection {
                        // Scroll to center without animation for performance during rapid playback
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
    }
    
    var headerView: some View {
        HStack(spacing: 0) {
            Text("Frame").frame(width: wFrame, alignment: .leading)
            Divider()
            Text("Time").frame(width: wTime, alignment: .leading).padding(.leading, 8)
            Divider()
            Text("Vis").frame(width: wVis, alignment: .center)
            Divider()
            
            // Show ALL markers
            ForEach(capture.markers.labels.indices, id: \.self) { idx in
                Text("\(capture.markers.labels[idx])")
                    .frame(width: wMarker, alignment: .leading)
                    .padding(.leading, 8)
                    .lineLimit(1)
                Divider()
            }
            Spacer()
        }
        .font(.caption.bold())
        .frame(height: 28)
        .padding(.horizontal, 8)
        .background(AppTheme.background) // Solid background for sticky header
        .border(Color.white.opacity(0.1), width: 1)
    }
}

struct DataRowView: View {
    let index: Int
    let capture: MotionCapture
    let widths: (CGFloat, CGFloat, CGFloat, CGFloat)
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Frame
            Text("\(index + 1)")
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: widths.0, alignment: .leading)
            
            Divider()
            
            // Time
            Text(String(format: "%.3f", Double(index) / capture.markers.frameRate))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: widths.1, alignment: .leading)
                .padding(.leading, 8)
            
            Divider()
            
            // Visible
            let visible = capture.markers.positions(at: index).compactMap { $0 }.count
            Text("\(visible)")
                .foregroundStyle(.white)
                .frame(width: widths.2, alignment: .center)
            
            Divider()
            
            // Markers (ALL)
            ForEach(capture.markers.labels.indices, id: \.self) { mIdx in
                if let pos = capture.markers.position(marker: mIdx, frame: index) {
                    Text(String(format: "%.1f, %.1f, %.1f", pos.x, pos.y, pos.z))
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: widths.3, alignment: .leading)
                        .padding(.leading, 8)
                } else {
                    Text("-")
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: widths.3, alignment: .leading)
                        .padding(.leading, 8)
                }
                Divider()
            }
            Spacer()
        }
        .frame(height: 24)
        .padding(.horizontal, 8)
        .background(isSelected ? AppTheme.accent.opacity(0.25) : Color.clear)
        .contentShape(Rectangle()) // Ensure full row is tappable
    }
}
