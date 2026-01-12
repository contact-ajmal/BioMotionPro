import SwiftUI

/// Data inspector panel showing detailed information about the capture and selected items
struct DataInspectorView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let capture = appState.currentCapture {
                        // File info section
                        InspectorSection(title: "File Info", icon: "doc.text") {
                            InfoRow(label: "Filename", value: capture.metadata.filename)
                            if let subject = capture.metadata.subject {
                                InfoRow(label: "Subject", value: subject)
                            }
                            InfoRow(label: "Duration", value: String(format: "%.2f s", capture.duration))
                            InfoRow(label: "Frames", value: "\(capture.frameCount)")
                            InfoRow(label: "Frame Rate", value: String(format: "%.1f Hz", capture.markers.frameRate))
                        }
                        
                        // Markers section
                        InspectorSection(title: "Markers", icon: "circle.circle") {
                            InfoRow(label: "Count", value: "\(capture.markers.markerCount)")
                            
                            if !appState.selectedMarkers.isEmpty {
                                Divider()
                                Text("Selected:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                ForEach(Array(appState.selectedMarkers), id: \.self) { label in
                                    if let index = capture.markers.markerIndex(for: label),
                                       let position = capture.markers.position(marker: index, frame: appState.currentFrame) {
                                        MarkerInfoRow(
                                            label: label,
                                            position: position
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Analog section
                        if capture.analogs.channelCount > 0 {
                            InspectorSection(title: "Analog", icon: "waveform.path.ecg") {
                                InfoRow(label: "Channels", value: "\(capture.analogs.channelCount)")
                                InfoRow(label: "Sample Rate", value: String(format: "%.0f Hz", capture.analogs.sampleRate))
                                InfoRow(label: "Samples", value: "\(capture.analogs.sampleCount)")
                            }
                        }
                        
                        // Events section
                        if !capture.events.isEmpty {
                            InspectorSection(title: "Events", icon: "flag") {
                                ForEach(capture.events) { event in
                                    EventInfoRow(event: event, isCurrentFrame: event.frame == appState.currentFrame)
                                }
                            }
                        }
                        
                        // Current frame info
                        InspectorSection(title: "Current Frame", icon: "clock") {
                            InfoRow(label: "Frame", value: "\(appState.currentFrame + 1)")
                            let time = Double(appState.currentFrame) / capture.markers.frameRate
                            InfoRow(label: "Time", value: String(format: "%.3f s", time))
                            
                            // Count visible markers
                            let visibleCount = capture.markers.positions(at: appState.currentFrame)
                                .compactMap { $0 }.count
                            InfoRow(label: "Visible Markers", value: "\(visibleCount) / \(capture.markers.markerCount)")
                        }
                        
                    } else {
                        ContentUnavailableView {
                            Label("No Data", systemImage: "doc")
                        } description: {
                            Text("Open a C3D file to inspect its contents")
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 250)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Inspector Section

struct InspectorSection<Content: View>: View {
    let title: String
    var icon: String = "info.circle"
    @ViewBuilder let content: Content
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.smooth) { isExpanded.toggle() } }) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    content
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Info Rows

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}

struct MarkerInfoRow: View {
    let label: String
    let position: SIMD3<Float>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            
            HStack(spacing: 8) {
                Text("X:")
                    .foregroundStyle(.red)
                Text(String(format: "%.1f", position.x))
                
                Text("Y:")
                    .foregroundStyle(.green)
                Text(String(format: "%.1f", position.y))
                
                Text("Z:")
                    .foregroundStyle(.blue)
                Text(String(format: "%.1f", position.z))
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct EventInfoRow: View {
    let event: MotionEvent
    let isCurrentFrame: Bool
    
    var body: some View {
        HStack {
            Image(systemName: event.iconName)
                .font(.caption)
                .foregroundStyle(contextColor)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(event.label)
                    .font(.caption.weight(.medium))
                Text(String(format: "%.3f s", event.time))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let context = event.context {
                Text(context)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .background(isCurrentFrame ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
    }
    
    private var contextColor: Color {
        switch event.context?.lowercased() {
        case "left":
            return .red
        case "right":
            return .blue
        default:
            return .yellow
        }
    }
}

// MARK: - Preview

#Preview {
    DataInspectorView()
        .environmentObject(AppState())
        .frame(width: 280, height: 600)
}
