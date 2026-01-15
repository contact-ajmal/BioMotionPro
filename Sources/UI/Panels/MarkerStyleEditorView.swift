import SwiftUI

/// Marker style editor panel
struct MarkerStyleEditorView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var styleManager = MarkerStyleManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedMarker: String?
    @State private var editingStyle: MarkerStyle = .default
    @State private var searchText = ""
    
    var filteredMarkers: [String] {
        guard let capture = appState.currentCapture else { return [] }
        if searchText.isEmpty {
            return capture.markers.labels.sorted()
        }
        return capture.markers.labels.filter { $0.localizedCaseInsensitiveContains(searchText) }.sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Marker Styles")
                    .font(.title2.bold())
                
                Spacer()
                
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
            
            Divider()
            
            HSplitView {
                // Left: Marker List
                VStack(spacing: 0) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search markers...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .padding(8)
                    
                    Divider()
                    
                    // Marker List
                    if appState.currentCapture == nil {
                        ContentUnavailableView(
                            "No Capture Loaded",
                            systemImage: "doc.badge.plus",
                            description: Text("Load a motion capture file to edit marker styles")
                        )
                    } else if filteredMarkers.isEmpty {
                        ContentUnavailableView(
                            "No Markers Found",
                            systemImage: "magnifyingglass",
                            description: Text("No markers match your search")
                        )
                    } else {
                        List(filteredMarkers, id: \.self, selection: $selectedMarker) { label in
                            HStack(spacing: 8) {
                                let style = styleManager.currentConfig.style(for: label)
                                
                                Image(systemName: style.shape.iconName)
                                    .foregroundColor(style.color.color)
                                    .frame(width: 20)
                                
                                Text(label)
                                    .font(.system(.body, design: .monospaced))
                                
                                Spacer()
                                
                                if styleManager.currentConfig.markerStyles[label] != nil {
                                    Image(systemName: "paintbrush.pointed.fill")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listStyle(.sidebar)
                    }
                }
                .frame(minWidth: 200, maxWidth: 300)
                
                // Right: Style Editor
                VStack(spacing: 0) {
                    if let marker = selectedMarker {
                        MarkerStyleForm(
                            markerLabel: marker,
                            style: Binding(
                                get: { styleManager.currentConfig.style(for: marker) },
                                set: { styleManager.setStyle($0, forMarker: marker) }
                            ),
                            onReset: { styleManager.resetStyle(forMarker: marker) }
                        )
                    } else {
                        ContentUnavailableView(
                            "Select a Marker",
                            systemImage: "hand.point.up.left",
                            description: Text("Select a marker to edit its style")
                        )
                    }
                }
                .frame(minWidth: 300)
            }
            
            Divider()
            
            // Footer: Preset buttons
            HStack {
                Text("Presets:")
                    .font(.headline)
                
                ForEach(MarkerStyleConfig.presets, id: \.name) { preset in
                    Button(preset.name) {
                        styleManager.apply(preset)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button("Reset All to Default") {
                    styleManager.apply(MarkerStyleConfig())
                }
                .foregroundColor(.red)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 600, minHeight: 500)
        .onChange(of: selectedMarker) { newValue in
            if let label = newValue {
                editingStyle = styleManager.currentConfig.style(for: label)
            }
        }
    }
}

// MARK: - Marker Style Form

struct MarkerStyleForm: View {
    let markerLabel: String
    @Binding var style: MarkerStyle
    let onReset: () -> Void
    
    var body: some View {
        Form {
            Section {
                // Shape picker
                Picker("Shape", selection: $style.shape) {
                    ForEach(MarkerShape.allCases, id: \.self) { shape in
                        Label(shape.displayName, systemImage: shape.iconName)
                            .tag(shape)
                    }
                }
                .pickerStyle(.menu)
                
                // Size slider
                VStack(alignment: .leading) {
                    Text("Size: \(String(format: "%.1f", style.size))x")
                    Slider(value: $style.size, in: 0.3...3.0, step: 0.1)
                }
                
                // Color picker
                ColorPicker("Color", selection: Binding(
                    get: { style.color.color },
                    set: { style.color = CodableColor($0) }
                ))
            } header: {
                HStack {
                    Text(markerLabel)
                        .font(.title3.bold())
                    Spacer()
                }
            }
            
            Section {
                Toggle("Show Label", isOn: $style.showLabel)
                
                if style.showLabel {
                    ColorPicker("Label Color", selection: Binding(
                        get: { style.labelColor.color },
                        set: { style.labelColor = CodableColor($0) }
                    ))
                }
            } header: {
                Text("Label")
            }
            
            Section {
                // Preview
                HStack {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: style.shape.iconName)
                            .font(.system(size: 40 * CGFloat(style.size)))
                            .foregroundColor(style.color.color)
                        
                        if style.showLabel {
                            Text(markerLabel)
                                .font(.caption)
                                .foregroundColor(style.labelColor.color)
                                .offset(y: 35)
                        }
                    }
                    
                    Spacer()
                }
            } header: {
                Text("Preview")
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("Reset to Default", role: .destructive, action: onReset)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    MarkerStyleEditorView()
        .environmentObject(AppState())
}
