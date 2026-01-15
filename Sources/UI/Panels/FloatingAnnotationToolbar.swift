import SwiftUI

/// Professional floating annotation toolbar
struct FloatingAnnotationToolbar: View {
    @StateObject private var annotationLayer = AnnotationLayer.shared
    @EnvironmentObject var appState: AppState
    
    @State private var isExpanded = true
    @State private var showColorPicker = false
    @State private var customColor = Color.red
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.scribble")
                    .foregroundColor(.accentColor)
                
                if isExpanded {
                    Text("Annotations")
                        .font(.caption.bold())
                    
                    Spacer()
                    
                    Text("\(annotationLayer.annotations.count)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.3))
                        .cornerRadius(4)
                }
                
                Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
            
            if isExpanded {
                Divider()
                
                VStack(spacing: 12) {
                    // Drawing Mode Toggle
                    Toggle(isOn: $annotationLayer.isDrawing) {
                        HStack(spacing: 6) {
                            Image(systemName: annotationLayer.isDrawing ? "pencil.circle.fill" : "pencil.circle")
                                .foregroundColor(annotationLayer.isDrawing ? .orange : .secondary)
                            Text(annotationLayer.isDrawing ? "Drawing ON" : "Drawing OFF")
                                .font(.caption.bold())
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.orange)
                    
                    if annotationLayer.isDrawing {
                        Divider()
                        
                        // Tools Section
                        toolsSection
                        
                        Divider()
                        
                        // Style Section
                        styleSection
                        
                        Divider()
                        
                        // Actions Section
                        actionsSection
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
            }
        }
        .frame(width: isExpanded ? 200 : 50)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Tools Section
    
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOOLS")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 6) {
                ForEach(AnnotationType.allCases, id: \.self) { tool in
                    ToolButton(
                        icon: tool.iconName,
                        label: tool.displayName,
                        isSelected: annotationLayer.currentTool == tool
                    ) {
                        annotationLayer.currentTool = tool
                    }
                }
            }
        }
    }
    
    // MARK: - Style Section
    
    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STYLE")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            // Color Palette
            VStack(alignment: .leading, spacing: 4) {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(ColorOption.allCases) { option in
                        ColorButton(
                            color: option.color,
                            isSelected: isColorMatch(option.hex),
                            action: { annotationLayer.currentColor = CodableColor(hex: option.hex) }
                        )
                    }
                    
                    // Custom color picker
                    ColorPicker("", selection: $customColor)
                        .labelsHidden()
                        .frame(width: 24, height: 24)
                        .onChange(of: customColor) { newColor in
                            annotationLayer.currentColor = CodableColor(newColor)
                        }
                }
            }
            
            // Line Width
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Stroke")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(annotationLayer.currentLineWidth)) pt")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $annotationLayer.currentLineWidth, in: 1...12, step: 1)
                    .tint(.accentColor)
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIONS")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            // Undo/Redo/Clear row
            HStack(spacing: 8) {
                ActionButton(
                    icon: "arrow.uturn.backward",
                    label: "Undo",
                    isEnabled: annotationLayer.canUndo,
                    action: { annotationLayer.undo() }
                )
                
                ActionButton(
                    icon: "arrow.uturn.forward",
                    label: "Redo",
                    isEnabled: annotationLayer.canRedo,
                    action: { annotationLayer.redo() }
                )
                
                Spacer()
                
                ActionButton(
                    icon: "trash",
                    label: "Clear",
                    isEnabled: !annotationLayer.annotations.isEmpty,
                    isDestructive: true,
                    action: { annotationLayer.clearAll() }
                )
            }
            
            Divider()
            
            // Selection Mode
            Text("EDIT")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            Toggle(isOn: $annotationLayer.isSelectMode) {
                HStack(spacing: 4) {
                    Image(systemName: "cursorarrow.click.2")
                    Text("Select Mode")
                        .font(.caption)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.blue)
            
            // Scale buttons (when annotation selected)
            if annotationLayer.selectedAnnotation != nil {
                HStack(spacing: 8) {
                    Button(action: { annotationLayer.scaleSelected(by: 0.9) }) {
                        HStack(spacing: 2) {
                            Image(systemName: "minus.magnifyingglass")
                            Text("Shrink")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: { annotationLayer.scaleSelected(by: 1.1) }) {
                        HStack(spacing: 2) {
                            Image(systemName: "plus.magnifyingglass")
                            Text("Grow")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Button(action: { annotationLayer.deleteSelected() }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Divider()
            
            // Frame & Export row
            HStack(spacing: 8) {
                Button(action: { annotationLayer.clearFrame(appState.currentFrame) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                        Text("Clear Frame")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(annotationLayer.annotations(forFrame: appState.currentFrame).isEmpty)
                
                Spacer()
                
                // Snapshot button
                Button(action: { captureSnapshot() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                        Text("Snapshot")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Snapshot
    
    private func captureSnapshot() {
        // Post notification so Scene3DView can capture
        NotificationCenter.default.post(name: .captureSnapshot, object: nil)
    }
    
    private func isColorMatch(_ hex: String) -> Bool {
        let r = Int(annotationLayer.currentColor.red * 255)
        let g = Int(annotationLayer.currentColor.green * 255)
        let b = Int(annotationLayer.currentColor.blue * 255)
        let currentHex = String(format: "%02X%02X%02X", r, g, b)
        return currentHex.uppercased() == hex.uppercased()
    }
}

// MARK: - Color Options

enum ColorOption: String, CaseIterable, Identifiable {
    case red, orange, yellow, green, cyan, blue, purple, white
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .cyan: return .cyan
        case .blue: return .blue
        case .purple: return .purple
        case .white: return .white
        }
    }
    
    var hex: String {
        switch self {
        case .red: return "FF3B30"
        case .orange: return "FF9500"
        case .yellow: return "FFCC00"
        case .green: return "34C759"
        case .cyan: return "5AC8FA"
        case .blue: return "007AFF"
        case .purple: return "AF52DE"
        case .white: return "FFFFFF"
        }
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
        .help(label)
    }
}

// MARK: - Color Button

struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String
    let isEnabled: Bool
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 44, height: 36)
            .foregroundColor(isDestructive && isEnabled ? .red : (isEnabled ? .primary : .secondary))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .help(label)
    }
}

#Preview {
    FloatingAnnotationToolbar()
        .environmentObject(AppState())
        .padding()
        .background(Color.gray.opacity(0.3))
}
