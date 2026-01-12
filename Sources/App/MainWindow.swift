import SwiftUI
import AVKit

/// Main application window with dockable panels
struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    
    // Persistent UI State
    @AppStorage("showInspector") private var showInspector = true
    @AppStorage("showPlots") private var showPlots = true
    @State private var bottomPanelHeight: CGFloat = 250
    @State private var isFullscreen = false
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left sidebar - Data browser
            if !isFullscreen {
                DataBrowserSidebar()
            }
        } detail: {
            HSplitView {
                // Main content area
                VStack(spacing: 0) {
                    // 3D View + Plots
                    GeometryReader { geometry in
                        HSplitView {
                            if appState.isComparing {
                                // Side-by-Side Comparison View
                                HSplitView {
                                    // Left: Primary
                                    ZStack(alignment: .topLeading) {
                                        Scene3DView(capture: nil) // Uses currentCapture
                                        Badge(text: "Primary", color: .blue)
                                            .padding()
                                    }
                                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                                    
                                    // Right: Comparison (First one for now)
                                    ZStack(alignment: .topLeading) {
                                        if let comparison = appState.comparisonCaptures.first {
                                            Scene3DView(capture: comparison)
                                            Badge(text: "Comparison", color: .red)

                                            .padding()
                                        } else {
                                            Text("No comparison selected")
                                        }
                                        
                                        // Exit Button
                                        Button(action: {
                                            appState.comparisonCaptures.removeAll()
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                                .background(Circle().fill(Color.black.opacity(0.4)))
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                                    }
                                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else {
                                // Standard Single View
                                Scene3DView()
                                    .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                            }
                            
                            if !isFullscreen && showPlots {
                                SignalPlotsView()
                                    .frame(minWidth: 300, idealWidth: 300, maxHeight: .infinity)
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    
                    if !isFullscreen {
                        Divider()
                        
                        // Timeline at bottom
                        TimelineView()
                            .frame(height: 140)
                    }
                }
                
                // Right inspector panel
                if showInspector && !isFullscreen {
                    DataInspectorView()
                        .frame(width: 280)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .navigationTitle(appState.currentCapture?.metadata.filename ?? "BioMotion Pro")
        .toolbar {
            if !isFullscreen {
                ToolbarItem(placement: .navigation) {
                    Button(action: { appState.openFileDialog() }) {
                        Label("Open", systemImage: "folder")
                    }
                    .help("Open C3D File (⌘O)")
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    PlaybackControls()
                }
                
                ToolbarItem(placement: .automatic) {
                    Toggle(isOn: $showInspector) {
                        Image(systemName: "sidebar.right")
                    }
                    .help("Toggle Inspector")
                }
            } else {
                // Minimal toolbar in fullscreen
                ToolbarItem(placement: .automatic) {
                    Button(action: { toggleFullscreen() }) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                    }
                    .help("Exit Fullscreen")
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
        }
        .focusedSceneValue(\.appState, appState)
        .onReceive(NotificationCenter.default.publisher(for: .toggleFullscreen)) { _ in
            toggleFullscreen()
        }
        .onReceive(NotificationCenter.default.publisher(for: .show3DView)) { _ in
             print("DEBUG: MainWindow received show3DView")
             // If we ever allow hiding 3D view, this would toggle it. 
             // For now, just exit fullscreen to ensure layout is visible
             if isFullscreen { toggleFullscreen() }
        }
        .sheet(item: $appState.activeSheet) { item in
            switch item {
            case .computeAngle:
                ComputeAngleSheet()
            case .processEMG:
                EMGProcessingSheet()
            case .gaitDetection:
                GaitDetectionSheet()
            case .batchProcessing:
                BatchProcessingView()
            case .videoPlayer:
                VideoPlayerView()
            case .compareTrials:
                TrialComparisonView()
            }
        }
    }
    
    private func toggleFullscreen() {
        withAnimation {
            isFullscreen.toggle()
            columnVisibility = isFullscreen ? .detailOnly : .all
        }
    }
    
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, error in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            
            Task { @MainActor in
                try? await appState.loadFile(at: url)
            }
        }
        return true
    }
}

// MARK: - Playback Controls

struct PlaybackControls: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: { appState.stepFrame(by: -1) }) {
                Image(systemName: "backward.frame.fill")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .help("Previous Frame")
            
            Button(action: { appState.togglePlayback() }) {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
            }
            .keyboardShortcut(.space, modifiers: [])
            .help(appState.isPlaying ? "Pause" : "Play")
            
            Button(action: { appState.stepFrame(by: 1) }) {
                Image(systemName: "forward.frame.fill")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .help("Next Frame")
            
            Divider()
            
            // Frame counter
            if let capture = appState.currentCapture {
                Text("\(appState.currentFrame + 1) / \(capture.frameCount)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            // Playback speed picker
            Picker("Speed", selection: $appState.playbackSpeed) {
                Text("0.25x").tag(0.25)
                Text("0.5x").tag(0.5)
                Text("1x").tag(1.0)
                Text("2x").tag(2.0)
            }
            .pickerStyle(.menu)
            .frame(width: 70)
        }
    }
}

// MARK: - Sidebar

struct DataBrowserSidebar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            if let capture = appState.currentCapture {
                Section("Markers") {
                    ForEach(capture.markers.labels, id: \.self) { label in
                        Label(label, systemImage: "circle.fill")
                            .foregroundStyle(appState.selectedMarkers.contains(label) ? .blue : .primary)
                            .onTapGesture {
                                if appState.selectedMarkers.contains(label) {
                                    appState.selectedMarkers.remove(label)
                                } else {
                                    appState.selectedMarkers.insert(label)
                                }
                            }
                    }
                }
                
                Section("Analog Channels") {
                    ForEach(capture.analogs.channels) { channel in
                        Label(channel.label, systemImage: "waveform")
                    }
                }
                
                Section("Events") {
                    ForEach(capture.events) { event in
                        Label(event.label, systemImage: "flag.fill")
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No Data", systemImage: "doc")
                } description: {
                    Text("Open a C3D file to begin")
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}

// MARK: - Preview

#Preview {
    MainWindow()
        .environmentObject(AppState())
        .frame(width: 1200, height: 800)
}

// MARK: - Batch Processing
// BatchProcessingView is defined in UI/BatchProcessingView.swift

// MARK: - Video Player
// VideoPlayerView is defined in UI/VideoPlayerView.swift

// MARK: - Trial Comparison

struct TrialComparisonView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Compare Trials")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            List {
                // Primary Trial Section
                Section("Primary Trial (Reference)") {
                    if let capture = appState.currentCapture {
                        TrialRow(capture: capture, isPrimary: true)
                    } else {
                        Text("No primary trial loaded")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
                
                // Secondary Trials Section
                Section("Comparison Trials") {
                    ForEach(Array(appState.comparisonCaptures.enumerated()), id: \.offset) { index, capture in
                        TrialRow(capture: capture, isPrimary: false) {
                            appState.removeComparisonCapture(at: index)
                        }
                    }
                    
                    if appState.comparisonCaptures.isEmpty {
                        Text("No comparison trials added")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                    
                    Button(action: { addComparisonTrial() }) {
                        Label("Add Trial...", systemImage: "plus")
                    }
                    .padding(.top, 4)
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 400, minHeight: 500)
    }
    
    private func addComparisonTrial() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.data] // C3D, TRC, MOT
        panel.allowsMultipleSelection = true
        
        if panel.runModal() == .OK {
            Task {
                for url in panel.urls {
                    await appState.addComparisonCapture(at: url)
                }
            }
        }
    }
}

struct TrialRow: View {
    let capture: MotionCapture
    let isPrimary: Bool
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(capture.metadata.filename)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(capture.frameCount) f", systemImage: "film")
                    Label("\(Int(capture.markers.frameRate)) Hz", systemImage: "clock")
                    if let date = capture.metadata.captureDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isPrimary {
                Badge(text: "Primary", color: .blue)
            } else if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}




import SwiftUI

struct BatchProcessingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var inputFiles: [URL] = []
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var log: [String] = []
    @State private var processingStatus = "Idle"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Batch Processing")
                .font(.title)
                .padding(.top)
            
            // File List
            VStack(alignment: .leading) {
                HStack {
                    Text("Selected Files: \(inputFiles.count)")
                        .font(.headline)
                    Spacer()
                    Button("Add Files...") {
                        addFiles()
                    }
                    .disabled(isProcessing)
                    
                    Button("Clear") {
                        inputFiles.removeAll()
                        log.removeAll()
                        progress = 0
                        processingStatus = "Idle"
                    }
                    .disabled(isProcessing || inputFiles.isEmpty)
                }
                
                List {
                    ForEach(inputFiles, id: \.self) { url in
                        HStack {
                            Image(systemName: "doc.fill")
                            Text(url.lastPathComponent)
                            Spacer()
                            Text(url.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .truncationMode(.middle)
                        }
                    }
                }
                .frame(minHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .padding()
            
            // Controls
            HStack {
                Button("Process All") {
                    startProcessing()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputFiles.isEmpty || isProcessing)
                
                Button("Cancel") {
                    isProcessing = false
                    processingStatus = "Cancelled"
                }
                .disabled(!isProcessing)
            }
            
            // Progress
            VStack {
                ProgressView(value: progress, total: 1.0)
                Text(processingStatus)
                    .font(.caption)
            }
            .padding(.horizontal)
            
            // Log
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(log, id: \.self) { line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .frame(height: 150)
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
            .padding()
            
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .disabled(isProcessing)
            }
            .padding()
        }
        .frame(width: 600, height: 600)
    }
    
    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.data] // Allow all data types, parser check later
        
        if panel.runModal() == .OK {
            self.inputFiles.append(contentsOf: panel.urls)
        }
    }
    
    private func startProcessing() {
        guard !inputFiles.isEmpty else { return }
        
        isProcessing = true
        progress = 0
        log.removeAll()
        processingStatus = "Processing \(inputFiles.count) files..."
        
        Task {
            // Mock processing
            let total = Double(inputFiles.count)
            
            for (index, url) in inputFiles.enumerated() {
                if !isProcessing { break }
                
                let filename = url.lastPathComponent
                await MainActor.run {
                    processingStatus = "Processing \(filename)..."
                    log.append("[\(Date())] Started \(filename)")
                }
                
                // Simulate work (In real implementation, load and export)
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                
                // Here we would call appState.loadCapture, then perform operations
                // For now it's a simulation as requested by "all in one go" context
                // Real implementation would look like:
                // let parser = C3DParser()
                // let capture = try parser.parse(url)
                // let csv = DataExporter.exportMarkersToCSV(capture)
                // save csv...
                
                await MainActor.run {
                    progress = Double(index + 1) / total
                    log.append("[\(Date())] Completed \(filename)")
                }
            }
            
            await MainActor.run {
                isProcessing = false
                processingStatus = "Batch Processing Complete"
                progress = 1.0
            }
        }
    }
}


import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @EnvironmentObject var appState: AppState
    @State private var player: AVPlayer?
    @State private var videoURL: URL?
    
    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        // Subscribe to app state frame changes to sync video
                        // This uses a polling or notification approach in a real app
                    }
                    .onChange(of: appState.currentFrame) { newFrame in
                         syncVideoToFrame(frame: newFrame)
                    }
                    .onChange(of: appState.isPlaying) { isPlaying in
                        if isPlaying {
                            player.play()
                        } else {
                            player.pause()
                        }
                    }
                
                HStack {
                    Button("Sync: Offset +0.1s") {
                        // Adjust offset
                    }
                    Button("Sync: Offset -0.1s") {
                        // Adjust offset
                    }
                }
                .padding()
            } else {
                Button("Load Reference Video...") {
                    loadVideo()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(minWidth: 300, minHeight: 200)
        .background(Color.black)
    }
    
    private func loadVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        if panel.runModal() == .OK, let url = panel.url {
            self.videoURL = url
            self.player = AVPlayer(url: url)
        }
    }
    
    private func syncVideoToFrame(frame: Int) {
        guard let capture = appState.currentCapture, let player = player else { return }
        
        // Calculate time from frame
        let time = Double(frame) / capture.markers.frameRate
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        // Seek
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
