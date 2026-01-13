import SwiftUI
import AppKit
import Combine
import Foundation
import Darwin

/// Logs a message to stderr to ensure it appears in system logs/console immediately
public func logDebug(_ message: String) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let output = "[\(timestamp)] [DEBUG] \(message)\n"
    fputs(output, stderr)
}

// MARK: - Focused Value Key for AppState

struct AppStateFocusedValueKey: FocusedValueKey {
    typealias Value = AppState
}

extension FocusedValues {
    var appState: AppState? {
        get { self[AppStateFocusedValueKey.self] }
        set { self[AppStateFocusedValueKey.self] = newValue }
    }
}

/// BioMotion Pro - Next-generation biomechanics visualization and analysis
@main
struct BioMotionProApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        logDebug("🚀 BioMotionPro App Started")
    }
    
    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .focusedSceneValue(\.appState, appState)
                .preferredColorScheme(.dark)
        }
        .commands {
            BioMotionCommands()
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        
        #if DEBUG
        Window("Debug Console", id: "debug") {
            DebugConsoleView()
        }
        #endif
        
        Settings {
            SettingsView()
        }
        
        WindowGroup("Data Editor", id: "data-editor") {
            DataEditorView()
                .environmentObject(appState)
                .focusedSceneValue(\.appState, appState)
        }
        
        WindowGroup("Skeleton Designer", id: "skeleton-designer") {
            SkeletonDesignerView()
                .environmentObject(appState)
                .focusedSceneValue(\.appState, appState)
        }
        .defaultSize(width: 900, height: 600)
    }
}

// MARK: - Shared Camera Configuration

class CameraConfiguration: ObservableObject {
    @Published var orbitRadius: Float = 5.0
    @Published var orbitTheta: Float = 0.5
    @Published var orbitPhi: Float = 0.3
    @Published var target = SIMD3<Float>(0, 1, 0)
    
    func reset() {
        orbitRadius = 5.0
        orbitTheta = 0.5
        orbitPhi = 0.3
        target = SIMD3(0, 1, 0)
    }
}

/// Global application state with playback timer
@MainActor
class AppState: ObservableObject {
    @Published var currentCapture: MotionCapture?
    @Published var currentFrame: Int = 0
    @Published var isPlaying: Bool = false
    @Published var playbackSpeed: Double = 1.0
    @Published var selectedMarkers: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    @Published var activeSheet: SheetType?
    @Published var followSubject: Bool = false
    @Published var forcedSkeletonModel: SkeletonModel? = nil
    @Published var comparisonCaptures: [MotionCapture] = []
    
    @Published var cameraConfig = CameraConfiguration()
    
    // Comparison State
    var isComparing: Bool {
        !comparisonCaptures.isEmpty
    }
    
    private var playbackTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    enum SheetType: String, Identifiable {
        case computeAngle
        case processEMG
        case gaitDetection
        case batchProcessing
        case videoPlayer
        case compareTrials
        
        var id: String { rawValue }
    }
    
    init() {
        // Watch for playback state changes
        $isPlaying
            .sink { [weak self] playing in
                if playing {
                    self?.startPlayback()
                } else {
                    self?.stopPlayback()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - File Loading
    
    func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "c3d")!,
            .init(filenameExtension: "trc")!,
            .init(filenameExtension: "mot")!,
            .init(filenameExtension: "sto")!
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select a motion capture file"
        panel.prompt = "Open"
        
        if panel.runModal() == .OK, let url = panel.url {
            print("📁 File selected: \(url.path)")
            Task { @MainActor in
                await self.loadFile(at: url)
            }
        }
    }
    
    func loadFile(at url: URL) async {
        print("🔄 Loading file: \(url.path)")
        isLoading = true
        errorMessage = nil
        
        do {
            let ext = url.pathExtension.lowercased()
            print("📂 File extension: \(ext)")
            
            switch ext {
            case "c3d":
                let parser = C3DParser()
                currentCapture = try await parser.parse(from: url)
            case "trc":
                let parser = TRCParser()
                currentCapture = try await parser.parse(from: url)
            case "mot", "sto":
                let parser = MOTParser()
                currentCapture = try await parser.parse(from: url)
            default:
                throw ParseError.invalidFormat("Unsupported file format: .\(ext)")
            }
            
            if let capture = currentCapture {
                print("✅ Successfully loaded: \(capture.markers.markerCount) markers, \(capture.markers.frameCount) frames")
            }
            
            currentFrame = 0
            isPlaying = false
        } catch {
            print("❌ Error loading file: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addComparisonCapture(at url: URL) async {
        isLoading = true
        do {
             let ext = url.pathExtension.lowercased()
             let capture: MotionCapture
             
             switch ext {
             case "c3d":
                 let parser = C3DParser()
                 capture = try await parser.parse(from: url)
             case "trc":
                 let parser = TRCParser()
                 capture = try await parser.parse(from: url)
             case "mot", "sto":
                 let parser = MOTParser()
                 capture = try await parser.parse(from: url)
             default:
                 throw ParseError.invalidFormat("Unsupported file format: .\(ext)")
             }
            
            comparisonCaptures.append(capture)
            print("✅ Added comparison capture: \(capture.metadata.filename)")
            
        } catch {
            print("❌ Error adding comparison capture: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func removeComparisonCapture(at index: Int) {
        guard index >= 0 && index < comparisonCaptures.count else { return }
        comparisonCaptures.remove(at: index)
    }
    
    // MARK: - Playback Control
    
    func togglePlayback() {
        isPlaying.toggle()
    }
    
    func stepFrame(by delta: Int) {
        guard let capture = currentCapture else { return }
        let newFrame = currentFrame + delta
        currentFrame = max(0, min(capture.frameCount - 1, newFrame))
    }
    
    func seekToFrame(_ frame: Int) {
        guard let capture = currentCapture else { return }
        currentFrame = max(0, min(capture.frameCount - 1, frame))
    }
    
    func seekToTime(_ time: Double) {
        guard let capture = currentCapture else { return }
        let frame = Int(time * capture.markers.frameRate)
        seekToFrame(frame)
    }
    
    func goToStart() {
        currentFrame = 0
    }
    
    func goToEnd() {
        guard let capture = currentCapture else { return }
        currentFrame = capture.frameCount - 1
    }
    
    private func startPlayback() {
        guard let capture = currentCapture else {
            isPlaying = false
            return
        }
        
        // Calculate timer interval based on frame rate and playback speed
        let interval = 1.0 / (capture.markers.frameRate * playbackSpeed)
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceFrame()
            }
        }
    }
    
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func advanceFrame() {
        guard let capture = currentCapture else { return }
        
        if currentFrame < capture.frameCount - 1 {
            currentFrame += 1
        } else {
            // Loop back to start or stop
            currentFrame = 0
        }
    }
    
    // MARK: - Marker Selection
    
    func selectMarker(_ label: String) {
        selectedMarkers.insert(label)
    }
    
    func deselectMarker(_ label: String) {
        selectedMarkers.remove(label)
    }
    
    func toggleMarkerSelection(_ label: String) {
        if selectedMarkers.contains(label) {
            selectedMarkers.remove(label)
        } else {
            selectedMarkers.insert(label)
        }
    }
    
    func selectAllMarkers() {
        guard let capture = currentCapture else { return }
        selectedMarkers = Set(capture.markers.labels)
    }
    
    func deselectAllMarkers() {
        selectedMarkers.removeAll()
    }
}

/// Custom menu commands for biomechanics operations
struct BioMotionCommands: Commands {
    @FocusedValue(\.appState) var appState
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open C3D File...") {
                appState?.openFileDialog()
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Divider()
            
            Button("Import TRC...") { 
                appState?.openFileDialog() // Reuse general loader
            }
            Button("Import MOT...") { 
                appState?.openFileDialog()
            }
            
            Divider()
            
            Button("Close") {
                appState?.currentCapture = nil
                appState?.currentFrame = 0
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(appState?.currentCapture == nil)
            
            Divider()
            
            Menu("Export Data") {
                Button("Export Markers to CSV...") {
                    exportMarkersToCSV()
                }
                Button("Export Analogs to CSV...") {
                    exportAnalogsToCSV()
                }
                Divider()
                Button("Generate HTML Report...") {
                    generateReport()
                }
            }
            .disabled(appState?.currentCapture == nil)
            
            Divider()
            
            Button("Batch Process...") {
                showBatchProcessingSheet()
            }
            
            Button("Compare Trials...") {
                appState?.activeSheet = .compareTrials
            }
        }
        
        CommandGroup(after: .textEditing) {
            // ... (keep existing)
            Button("Select All Markers") {
                appState?.selectAllMarkers()
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(appState?.currentCapture == nil)
            
            Button("Deselect All") {
                appState?.deselectAllMarkers()
            }
            .keyboardShortcut("d", modifiers: .command)
        }
        
        // ... (keep Playback)

        CommandMenu("Analysis") {
            Button("Compute Joint Angles") { 
                if appState?.currentCapture == nil {
                    showNoFileLoadedAlert()
                } else {
                    appState?.activeSheet = .computeAngle
                }
            }
            .keyboardShortcut("j", modifiers: [.command, .shift])
            
            Button("Process EMG") { 
                if appState?.currentCapture == nil {
                    showNoFileLoadedAlert()
                } else {
                    appState?.activeSheet = .processEMG
                }
            }
            
            Button("Detect Gait Events") { 
                if appState?.currentCapture == nil {
                     showNoFileLoadedAlert()
                } else {
                     appState?.activeSheet = .gaitDetection
                }
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Fill Marker Gaps") {
                fillMarkerGaps()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(appState?.currentCapture == nil)
            
            Divider()
            
            Button("Run Python Script...") { 
                showFeatureNotImplementedAlert("Run Python Script")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }
        
        CommandMenu("View") {
            Button("Reset Camera") { 
                print("DEBUG: Executing Reset Camera Command")
                NotificationCenter.default.post(name: .resetCamera, object: nil)
            }
            .keyboardShortcut("0", modifiers: .command)
            
            Divider()
            
            Button("Show 3D View") {
                print("DEBUG: Executing Show 3D View Command")
                NotificationCenter.default.post(name: .show3DView, object: nil)
            }
            .keyboardShortcut("1", modifiers: .command)
            
            Button("Show Video Player") {
                appState?.activeSheet = .videoPlayer
            }
            .keyboardShortcut("4", modifiers: .command)
            
            Button("Show Signal Plots") {
                let current = UserDefaults.standard.bool(forKey: "showPlots")
                UserDefaults.standard.set(!current, forKey: "showPlots")
                print("DEBUG: Toggled showPlots to \(!current)")
            }
            .keyboardShortcut("2", modifiers: .command)
            
            Button("Show Data Inspector") {
                let current = UserDefaults.standard.bool(forKey: "showInspector")
                UserDefaults.standard.set(!current, forKey: "showInspector")
                print("DEBUG: Toggled showInspector to \(!current)")
            }
            .keyboardShortcut("3", modifiers: .command)
        }
    }
    
    // MARK: - Export Functions
    
    private func exportMarkersToCSV() {
        guard let appState = appState, let capture = appState.currentCapture else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(capture.metadata.filename)_markers.csv"
        
        if panel.runModal() == .OK, let url = panel.url {
            let csv = DataExporter.exportMarkersToCSV(capture: capture)
            do {
                try DataExporter.saveToFile(csv, url: url)
                showSuccessAlert("Export Complete", "Saved to \(url.lastPathComponent)")
            } catch {
                showErrorAlert("Export Failed", error.localizedDescription)
            }
        }
    }
    
    private func exportAnalogsToCSV() {
        guard let appState = appState, let capture = appState.currentCapture else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(capture.metadata.filename)_analogs.csv"
        
        if panel.runModal() == .OK, let url = panel.url {
            let csv = DataExporter.exportAnalogsToCSV(capture: capture)
            do {
                try DataExporter.saveToFile(csv, url: url)
                showSuccessAlert("Export Complete", "Saved to \(url.lastPathComponent)")
            } catch {
                showErrorAlert("Export Failed", error.localizedDescription)
            }
        }
    }
    
    private func generateReport() {
        guard let appState = appState, let capture = appState.currentCapture else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\(capture.metadata.filename)_report.html"
        
        if panel.runModal() == .OK, let url = panel.url {
            let html = ReportGenerator.generateHTMLReport(capture: capture)
            do {
                try DataExporter.saveToFile(html, url: url)
                showSuccessAlert("Report Generated", "Saved to \(url.lastPathComponent)")
                NSWorkspace.shared.open(url)  // Open in browser
            } catch {
                showErrorAlert("Report Failed", error.localizedDescription)
            }
        }
    }
    
    private func showBatchProcessingSheet() {
        appState?.activeSheet = .batchProcessing
    }
    
    private func showSuccessAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    private func showErrorAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
    
    private func fillMarkerGaps() {
        guard let appState = appState, let capture = appState.currentCapture else { return }
        
        // Count gaps before
        var gapsBefore = 0
        for frame in 0..<capture.markers.frameCount {
            for marker in 0..<capture.markers.markerCount {
                if capture.markers.position(marker: marker, frame: frame) == nil {
                    gapsBefore += 1
                }
            }
        }
        
        // Fill gaps
        let filledMarkers = capture.markers.withFilledGaps(maxGapSize: 10)
        
        // Count gaps after
        var gapsAfter = 0
        for frame in 0..<filledMarkers.frameCount {
            for marker in 0..<filledMarkers.markerCount {
                if filledMarkers.position(marker: marker, frame: frame) == nil {
                    gapsAfter += 1
                }
            }
        }
        
        let newCapture = MotionCapture(
            metadata: CaptureMetadata(
                filename: capture.metadata.filename + " (GapFilled)",
                subject: capture.metadata.subject,
                description: capture.metadata.description,
                captureDate: capture.metadata.captureDate,
                manufacturer: capture.metadata.manufacturer,
                softwareVersion: capture.metadata.softwareVersion
            ),
            markers: filledMarkers,
            analogs: capture.analogs,
            events: capture.events,
            segments: capture.segments
        )
        
        appState.currentCapture = newCapture
        
        showSuccessAlert("Gap Filling Complete", "Filled \(gapsBefore - gapsAfter) gaps. \(gapsAfter) gaps remaining (too large to interpolate).")
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    // resetCamera, toggleFullscreen defined in Scene3DView.swift
    static let show3DView = Notification.Name("show3DView")
    static let showSignalPlots = Notification.Name("showSignalPlots")
    static let showInspector = Notification.Name("showInspector")
}

// MARK: - Alerts

func showFeatureNotImplementedAlert(_ feature: String) {
    let alert = NSAlert()
    alert.messageText = "Feature Not Implemented"
    alert.informativeText = "The feature '\(feature)' is coming in a future update."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

func showNoFileLoadedAlert() {
    let alert = NSAlert()
    alert.messageText = "No File Loaded"
    alert.informativeText = "Please open a motion capture file (C3D, TRC, MOT) to use this feature."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

// MARK: - Placeholder Views

struct DebugConsoleView: View {
    var body: some View {
        Text("Debug Console")
            .frame(minWidth: 400, minHeight: 300)
    }
}

struct SettingsView: View {
    @AppStorage("markerSize") private var markerSize: Double = 10
    @AppStorage("showGrid") private var showGrid: Bool = true
    @AppStorage("showAxes") private var showAxes: Bool = true
    @AppStorage("gridSize") private var gridSize: Double = 5
    @AppStorage("defaultFilterCutoff") private var filterCutoff: Double = 6
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            
            VisualizationSettingsView(
                markerSize: $markerSize,
                showGrid: $showGrid,
                showAxes: $showAxes,
                gridSize: $gridSize
            )
            .tabItem { Label("Visualization", systemImage: "cube") }
            
            ProcessingSettingsView(filterCutoff: $filterCutoff)
                .tabItem { Label("Processing", systemImage: "waveform") }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("autoPlayOnOpen") private var autoPlay: Bool = false
    @AppStorage("loopPlayback") private var loopPlayback: Bool = true
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-play on file open", isOn: $autoPlay)
                Toggle("Loop playback", isOn: $loopPlayback)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct VisualizationSettingsView: View {
    @Binding var markerSize: Double
    @Binding var showGrid: Bool
    @Binding var showAxes: Bool
    @AppStorage("showForcePlates") private var showForcePlates: Bool = true
    @Binding var gridSize: Double
    
    var body: some View {
        Form {
            Section("3D View") {
                Slider(value: $markerSize, in: 5...30, step: 1) {
                    Text("Marker Size: \(Int(markerSize))")
                }
                Toggle("Show Grid", isOn: $showGrid)
                Toggle("Show Axes", isOn: $showAxes)
                Toggle("Show Force Plates", isOn: $showForcePlates)
                Slider(value: $gridSize, in: 1...20, step: 0.5) {
                    Text("Grid Size: \(String(format: "%.1f", gridSize))m")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ProcessingSettingsView: View {
    @Binding var filterCutoff: Double
    
    var body: some View {
        Form {
            Section("Signal Processing") {
                Slider(value: $filterCutoff, in: 1...20, step: 0.5) {
                    Text("Filter Cutoff: \(String(format: "%.1f", filterCutoff)) Hz")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Analysis Sheets

// MARK: - Joint Angle Computation

struct ComputeAngleSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var proximalMarker: String = ""
    @State private var centerMarker: String = ""
    @State private var distalMarker: String = ""
    @State private var resultName: String = "New Angle"
    @State private var isComputing = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section("Select Markers") {
                if let capture = appState.currentCapture {
                    let markers = capture.markers.labels.sorted()
                    
                    Picker("Proximal (Thigh)", selection: $proximalMarker) {
                        Text("Select...").tag("")
                        ForEach(markers, id: \.self) { Text($0).tag($0) }
                    }
                    
                    Picker("Center (Knee)", selection: $centerMarker) {
                        Text("Select...").tag("")
                        ForEach(markers, id: \.self) { Text($0).tag($0) }
                    }
                    
                    Picker("Distal (Shank)", selection: $distalMarker) {
                        Text("Select...").tag("")
                        ForEach(markers, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            
            Section("Output") {
                TextField("Channel Name", text: $resultName)
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                
                Spacer()
                
                Button("Compute") {
                    compute()
                }
                .buttonStyle(.borderedProminent)
                .disabled(proximalMarker.isEmpty || centerMarker.isEmpty || distalMarker.isEmpty || resultName.isEmpty || isComputing)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
        .navigationTitle("Compute Joint Angle")
    }
    
    private func compute() {
        guard let capture = appState.currentCapture else { return }
        isComputing = true
        errorMessage = nil
        
        Task {
            do {
                let engine = BiomechanicsEngine()
                
                // Compute angles
                let angles = await engine.computeJointAngleTimeSeries(
                    markers: capture.markers,
                    proximalLabel: proximalMarker,
                    centerLabel: centerMarker,
                    distalLabel: distalMarker
                )
                
                // Convert [Float?] to [Float] (fill gaps with linear interpolation or 0)
                var filledAngles: [Float] = []
                var lastVal: Float = 0
                
                for val in angles {
                    if let v = val {
                        filledAngles.append(v)
                        lastVal = v
                    } else {
                        filledAngles.append(lastVal) // Zero-order hold
                    }
                }
                
                // Create new Analog Channel
                let newChannel = AnalogChannel(
                    label: resultName,
                    unit: "deg",
                    data: filledAngles
                )
                
                // Append to existing channels
                var newChannels = capture.analogs.channels
                newChannels.append(newChannel)
                
                let newAnalogData = AnalogData(
                    channels: newChannels,
                    sampleRate: capture.analogs.sampleRate > 0 ? capture.analogs.sampleRate : capture.markers.frameRate
                )
                
                // Update Capture
                let newCapture = MotionCapture(
                    metadata: capture.metadata,
                    markers: capture.markers,
                    analogs: newAnalogData,
                    events: capture.events,
                    segments: capture.segments
                )
                
                await MainActor.run {
                    appState.currentCapture = newCapture
                    isComputing = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Computation failed: \(error.localizedDescription)"
                    isComputing = false
                }
            }
        }
    }
}

// MARK: - EMG Processing

struct EMGProcessingSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedChannelID: UUID?
    @State private var resultSuffix: String = "_Env"
    
    // Parameters
    @State private var bandpassLow: Double = 20
    @State private var bandpassHigh: Double = 450
    @State private var removeMainsNoise: Bool = false
    @State private var mainsFreq: Double = 50 // Default to 50Hz (toggled to 60 via picker)
    @State private var rectify: Bool = true
    @State private var envelopeCutoff: Double = 6.0
    
    @State private var isComputing = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section("Input") {
                if let capture = appState.currentCapture {
                    Picker("Source Channel", selection: $selectedChannelID) {
                        Text("Select...").tag(UUID?.none)
                        ForEach(capture.analogs.channels) { channel in
                            Text(channel.label).tag(channel.id as UUID?)
                        }
                    }
                }
            }
            
            Section("Filtering") {
                VStack(alignment: .leading) {
                    Text("Bandpass Filter: \(Int(bandpassLow)) - \(Int(bandpassHigh)) Hz")
                    RangeSlider(lower: $bandpassLow, upper: $bandpassHigh, in: 0...1000)
                }
                
                Toggle("Remove Mains Hum (Notch)", isOn: $removeMainsNoise)
                if removeMainsNoise {
                    Picker("Mains Frequency", selection: $mainsFreq) {
                        Text("50 Hz (EU/Asia)").tag(50.0)
                        Text("60 Hz (US)").tag(60.0)
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            Section("Processing") {
                Toggle("Full-Wave Rectification", isOn: $rectify)
                
                VStack(alignment: .leading) {
                    Text("Linear Envelope Cutoff: \(String(format: "%.1f", envelopeCutoff)) Hz")
                    Slider(value: $envelopeCutoff, in: 1...20, step: 0.5)
                }
            }
            
            Section("Output") {
                TextField("Suffix (e.g. _Env)", text: $resultSuffix)
            }
            
            if let error = errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
            
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Process") {
                    process()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedChannelID == nil || isComputing)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 450, minHeight: 500)
        .navigationTitle("Process EMG Signal")
    }
    
    private func process() {
        guard let capture = appState.currentCapture,
              let channelID = selectedChannelID,
              let channel = capture.analogs.channels.first(where: { $0.id == channelID }) else { return }
        
        isComputing = true
        errorMessage = nil
        
        Task {
            let engine = BiomechanicsEngine()
            
            let processedData = await engine.processEMG(
                raw: channel.data,
                sampleRate: capture.analogs.sampleRate,
                bandpassLow: bandpassLow,
                bandpassHigh: bandpassHigh,
                notchFrequency: removeMainsNoise ? mainsFreq : nil,
                rectify: rectify,
                envelopeCutoff: envelopeCutoff
            )
            
            let newChannel = AnalogChannel(
                label: channel.label + resultSuffix,
                unit: channel.unit, // Keeps unit (e.g. V or mV)
                data: processedData
            )
            
            var newChannels = capture.analogs.channels
            newChannels.append(newChannel)
            
            let newAnalogData = AnalogData(
                channels: newChannels,
                sampleRate: capture.analogs.sampleRate
            )
            
            let newCapture = MotionCapture(
                metadata: capture.metadata,
                markers: capture.markers,
                analogs: newAnalogData,
                events: capture.events,
                segments: capture.segments
            )
            
            await MainActor.run {
                appState.currentCapture = newCapture
                isComputing = false
                dismiss()
            }
        }
    }
}

// Simple Range Slider for Bandpass (simplified as two sliders for MVP)
struct RangeSlider: View {
    @Binding var lower: Double
    @Binding var upper: Double
    let bounds: ClosedRange<Double>
    
    init(lower: Binding<Double>, upper: Binding<Double>, in bounds: ClosedRange<Double>) {
        self._lower = lower
        self._upper = upper
        self.bounds = bounds
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Low: \(Int(lower))")
                Slider(value: $lower, in: bounds.lowerBound...upper)
            }
            HStack {
                Text("High: \(Int(upper))")
                Slider(value: $upper, in: lower...bounds.upperBound)
            }
        }
    }
}

// MARK: - Gait Event Detection

struct GaitDetectionSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedChannelID: UUID?
    @State private var forceThreshold: Double = 20.0
    @State private var clearExistingEvents: Bool = true
    
    @State private var isComputing = false
    @State private var errorMessage: String?
    @State private var detectedCount: Int = 0
    
    var body: some View {
        Form {
            Section("Input") {
                if let capture = appState.currentCapture {
                    Picker("Vertical Force Channel", selection: $selectedChannelID) {
                        Text("Select...").tag(UUID?.none)
                        ForEach(capture.analogs.channels) { channel in
                            Text(channel.label).tag(channel.id as UUID?)
                        }
                    }
                    Text("Select the vertical Ground Reaction Force (GRF) channel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Parameters") {
                VStack(alignment: .leading) {
                    Text("Force Threshold: \(Int(forceThreshold)) N")
                    Slider(value: $forceThreshold, in: 5...100, step: 1)
                }
                
                Toggle("Clear Existing Events", isOn: $clearExistingEvents)
            }
            
            if let error = errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
            
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Detect Events") {
                    detect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedChannelID == nil || isComputing)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
        .navigationTitle("Detect Gait Events")
    }
    
    private func detect() {
        guard let capture = appState.currentCapture,
              let channelID = selectedChannelID,
              let channel = capture.analogs.channels.first(where: { $0.id == channelID }) else { return }
        
        isComputing = true
        errorMessage = nil
        
        Task {
            let engine = BiomechanicsEngine()
            
            // Detect raw events
            let rawEvents = await engine.detectGaitEventsFromGRF(
                verticalForce: channel.data,
                sampleRate: capture.analogs.sampleRate,
                threshold: Float(forceThreshold)
            )
            
            // Convert app Event model
            let newEvents = rawEvents.map { event -> MotionEvent in
                let label = (event.type == .heelStrike) ? "Heel Strike" : "Toe Off"
                let frame = Int(event.time * capture.markers.frameRate)
                
                return MotionEvent(
                    label: label,
                    time: event.time,
                    frame: frame
                )
            }
            
            // Update Capture
            var finalEvents = clearExistingEvents ? [] : capture.events
            finalEvents.append(contentsOf: newEvents)
            
            finalEvents.sort { $0.frame < $1.frame }
            
            let newCapture = MotionCapture(
                metadata: capture.metadata,
                markers: capture.markers,
                analogs: capture.analogs,
                events: finalEvents,
                segments: capture.segments
            )
            
            await MainActor.run {
                appState.currentCapture = newCapture
                isComputing = false
                dismiss()
            }
        }
    }
}
