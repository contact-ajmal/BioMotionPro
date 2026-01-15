import SwiftUI

struct AngleAnalysisView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAngleKey: String?
    @State private var isCalculating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Professional Header
            headerView
            
            Divider()
            
            // MARK: - Main Content
            if let capture = appState.currentCapture, let angles = capture.calculatedAngles, !angles.isEmpty {
                contentView(angles: angles)
            } else {
                emptyStateView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: appState.currentFrame) { _ in }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 16) {
            // Icon and Title
            Image(systemName: "angle")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Joint Kinematics Analysis")
                    .font(.title2.bold())
                
                if let capture = appState.currentCapture {
                    Text(capture.metadata.filename)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action Buttons
            if let capture = appState.currentCapture {
                if isCalculating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                    Text("Calculating...")
                        .foregroundColor(.secondary)
                } else if capture.calculatedAngles == nil {
                    Button(action: calculateAngles) {
                        Label("Calculate Angles", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(action: calculateAngles) {
                        Label("Recalculate", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Divider()
                .frame(height: 24)
            
            // Close Button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Content (Split View)
    @ViewBuilder
    private func contentView(angles: [String: JointAngleSeries]) -> some View {
        HSplitView {
            // Left Panel: Joint List + Stats
            leftPanel(angles: angles)
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 350)
            
            // Right Panel: Chart
            rightPanel(angles: angles)
        }
    }
    
    // MARK: - Left Panel (List + Stats)
    private func leftPanel(angles: [String: JointAngleSeries]) -> some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("COMPUTED ANGLES")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(angles.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // List
            List(selection: $selectedAngleKey) {
                ForEach(angles.keys.sorted(), id: \.self) { key in
                    JointRowView(
                        name: key,
                        series: angles[key]!,
                        isSelected: selectedAngleKey == key
                    )
                    .tag(key)
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Statistics Panel
            if let key = selectedAngleKey ?? angles.keys.sorted().first,
               let series = angles[key] {
                statisticsPanel(series: series)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Statistics Panel
    private func statisticsPanel(series: JointAngleSeries) -> some View {
        let validValues = series.values.compactMap { $0 }
        let minVal = validValues.min() ?? 0
        let maxVal = validValues.max() ?? 0
        let meanVal = validValues.isEmpty ? 0 : validValues.reduce(0, +) / Float(validValues.count)
        let rangeVal = maxVal - minVal
        
        return VStack(spacing: 12) {
            Text("STATISTICS")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Min", value: minVal, unit: "°", color: .blue)
                StatCard(title: "Max", value: maxVal, unit: "°", color: .red)
                StatCard(title: "Mean", value: meanVal, unit: "°", color: .green)
                StatCard(title: "Range", value: rangeVal, unit: "°", color: .orange)
            }
            
            // Current Frame Value
            if appState.currentFrame < series.values.count,
               let currentVal = series.values[appState.currentFrame] {
                HStack {
                    Text("Current Value:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f°", currentVal))
                        .font(.title3.monospacedDigit().bold())
                        .foregroundColor(.accentColor)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Right Panel (Chart)
    private func rightPanel(angles: [String: JointAngleSeries]) -> some View {
        VStack(spacing: 0) {
            if let key = selectedAngleKey ?? angles.keys.sorted().first,
               let series = angles[key] {
                // Chart Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(series.name)
                            .font(.title3.bold())
                        Text("Unit: \(series.unit) • \(series.values.count) frames")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    // Frame indicator
                    VStack(alignment: .trailing) {
                        Text("Frame \(appState.currentFrame + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                        if appState.currentFrame < series.values.count,
                           let val = series.values[appState.currentFrame] {
                            Text(String(format: "%.1f°", val))
                                .font(.headline.monospacedDigit())
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Chart
                ImprovedLineChart(values: series.values, currentFrame: appState.currentFrame)
                    .padding(20)
                    .background(Color(NSColor.textBackgroundColor))
            } else {
                Text("Select a joint from the list to view its angle curve")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Kinematic Data")
                .font(.title2.bold())
            
            Text("Run the kinematics solver to calculate joint angles\nfrom your motion capture data.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if appState.currentCapture != nil {
                Button(action: calculateAngles) {
                    Label("Run Kinematics Solver", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("Load a motion capture file first.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Calculate Angles
    private func calculateAngles() {
        guard let capture = appState.currentCapture else { return }
        
        isCalculating = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let calculated = KinematicsSolver.calculateAngles(capture: capture, skeleton: appState.forcedSkeletonModel)
            
            var newCapture = capture
            newCapture.calculatedAngles = calculated
            
            DispatchQueue.main.async {
                appState.currentCapture = newCapture
                isCalculating = false
                
                if selectedAngleKey == nil {
                    selectedAngleKey = calculated.keys.sorted().first
                }
            }
        }
    }
}

// MARK: - Joint Row View
struct JointRowView: View {
    let name: String
    let series: JointAngleSeries
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                
                let validValues = series.values.compactMap { $0 }
                let minVal = validValues.min() ?? 0
                let maxVal = validValues.max() ?? 0
                
                Text("Range: \(String(format: "%.0f", minVal))° – \(String(format: "%.0f", maxVal))°")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: Float
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(String(format: "%.1f%@", value, unit))
                .font(.system(.body, design: .monospaced).bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Improved Line Chart
struct ImprovedLineChart: View {
    let values: [Float?]
    let currentFrame: Int
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            let validValues = values.compactMap { $0 }
            
            if validValues.isEmpty {
                Text("No Data Points")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let minVal = validValues.min() ?? 0
                let maxVal = validValues.max() ?? 180
                let range = max(1.0, maxVal - minVal)
                let padding: CGFloat = 50
                let chartWidth = width - padding
                let chartHeight = height - 40
                
                ZStack(alignment: .topLeading) {
                    // Y-Axis Labels & Grid
                    ForEach(0..<5) { i in
                        let yValue = minVal + (range * Float(4 - i) / 4.0)
                        let yPos = 20 + (CGFloat(i) / 4.0) * chartHeight
                        
                        // Grid line
                        Path { path in
                            path.move(to: CGPoint(x: padding, y: yPos))
                            path.addLine(to: CGPoint(x: width, y: yPos))
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        
                        // Label
                        Text(String(format: "%.0f°", yValue))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                            .position(x: padding / 2, y: yPos)
                    }
                    
                    // Line Chart Path
                    Path { path in
                        var started = false
                        for (index, value) in values.enumerated() {
                            guard let val = value else { continue }
                            
                            let x = padding + (CGFloat(index) / CGFloat(max(1, values.count - 1))) * chartWidth
                            let normalizedY = (CGFloat(val) - CGFloat(minVal)) / CGFloat(range)
                            let y = 20 + chartHeight - (normalizedY * chartHeight)
                            
                            if !started {
                                path.move(to: CGPoint(x: x, y: y))
                                started = true
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                    
                    // Current Frame Indicator
                    let cursorX = padding + (CGFloat(currentFrame) / CGFloat(max(1, values.count - 1))) * chartWidth
                    
                    Path { path in
                        path.move(to: CGPoint(x: cursorX, y: 20))
                        path.addLine(to: CGPoint(x: cursorX, y: 20 + chartHeight))
                    }
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    
                    // Current Value Dot
                    if currentFrame < values.count, let val = values[currentFrame] {
                        let normalizedY = (CGFloat(val) - CGFloat(minVal)) / CGFloat(range)
                        let dotY = 20 + chartHeight - (normalizedY * chartHeight)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .position(x: cursorX, y: dotY)
                        
                        // Value Tooltip
                        Text(String(format: "%.1f°", val))
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .position(
                                x: min(width - 40, max(padding + 30, cursorX)),
                                y: max(40, dotY - 25)
                            )
                    }
                }
            }
        }
    }
}
