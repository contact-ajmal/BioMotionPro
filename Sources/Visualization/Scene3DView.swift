import SwiftUI
import MetalKit
import simd

/// Metal-based 3D visualization for motion capture data
/// Wrapper with floating controls
struct Scene3DView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("showGrid") private var showGrid: Bool = true
    @AppStorage("showAxes") private var showAxes: Bool = true
    @AppStorage("showForcePlates") private var showForcePlates: Bool = true
    @AppStorage("markerSize") private var markerSize: Double = 10
    
    @Environment(\.openWindow) private var openWindow
    
    var capture: MotionCapture? = nil // Explicit capture to render (for side-by-side)
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Toolbar
            topToolbar
            
            // MARK: - 3D Scene
            InternalScene3DView(capture: capture)
            
            // MARK: - Bottom Playback
            playbackBar
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private var topToolbar: some View {
        HStack(spacing: 16) {
            // Data Info
            if let c = capture ?? appState.currentCapture {
                Text("\(c.markers.labels.count) Markers")
                    .font(.caption.monospaced())
                Text("•")
                    .foregroundStyle(.secondary)
                Text(appState.forcedSkeletonModel?.name ?? "Auto Skeleton")
                    .font(.caption.monospaced())
            }
            
            Spacer()
            
            // Show Data Button
            Button(action: { openWindow(id: "data-editor") }) {
                Label("Data", systemImage: "tablecells")
            }
            .help("Show Data Editor")
            
            // Skeleton Options
            Menu {
                Text("Skeleton Model")
                
                Button("Auto-Detect") { print("Auto-detect requested") }
                Divider()
                Button("🧠 Auto-Identify by Position") { applySpatialSkeletonIdentification() }
                Button("🔗 Auto-Connect (Distance)") { applyDistanceBasedSkeleton() }
                Divider()
                Button("📊 Debug: Print Marker Bounds") { debugPrintMarkerBounds() }
                Button("🔄 Swap Y↔Z (Coordinate Fix)") { swapYZCoordinates() }
                Divider()
                Button("➖ Simple Lines (Connect All)") { applySimpleLinesSkeleton() }
                Divider()
                Button("📂 Load Skeleton Config...") { loadSkeletonConfig() }
                Button("💾 Save Current Config...") { saveSkeletonConfig() }
                
            } label: {
                Label("Skeleton", systemImage: "figure.walk")
            }
            .menuStyle(.borderlessButton)
            .help("Skeleton Settings")
            
            // Edit Skeleton (opens designer window)
            Button(action: { openWindow(id: "skeleton-designer") }) {
                Label("Edit", systemImage: "pencil.and.outline")
            }
            .help("Open Skeleton Designer")
            
            // View Options
            Menu {
                Toggle("Show Grid", isOn: $showGrid)
                Toggle("Show Axes", isOn: $showAxes)
                Toggle("Show Force Plates", isOn: $showForcePlates)
                Divider()
                Text("Marker Size")
                Slider(value: $markerSize, in: 2...20) { Text("Marker Size") }
            } label: {
                Label("View", systemImage: "eye")
            }
            .menuStyle(.borderlessButton)
            .help("View Settings")
            
            Divider()
                .frame(height: 20)
            
            // Camera Controls
            HStack(spacing: 4) {
                Button(action: { NotificationCenter.default.post(name: .zoomOut, object: nil) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom Out")
                
                Button(action: { NotificationCenter.default.post(name: .resetCamera, object: nil) }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset Camera")
                
                Button(action: { NotificationCenter.default.post(name: .zoomIn, object: nil) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom In")
            }
            
            Divider()
                .frame(height: 20)
            
            // Fullscreen
            Button(action: { NotificationCenter.default.post(name: .toggleFullscreen, object: nil) }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Fullscreen")
            
            // Follow Subject
            Button(action: { appState.followSubject.toggle() }) {
                Image(systemName: appState.followSubject ? "video.fill" : "video")
                    .foregroundStyle(appState.followSubject ? Color.red : Color.primary)
            }
            .help("Follow Subject")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
    
    @ViewBuilder
    private var playbackBar: some View {
        if let capture = appState.currentCapture {
            HStack(spacing: 16) {
                // Frame Controls
                Button(action: { appState.stepFrame(by: -1) }) {
                    Image(systemName: "backward.frame.fill")
                }
                
                Button(action: { appState.togglePlayback() }) {
                    Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button(action: { appState.stepFrame(by: 1) }) {
                    Image(systemName: "forward.frame.fill")
                }
                
                // Slider
                Slider(value: Binding(
                    get: { Double(appState.currentFrame) },
                    set: { appState.currentFrame = Int($0) }
                ), in: 0...Double(capture.frameCount - 1))
                .tint(AppTheme.accent)
                
                // Frame Counter
                Text("\(appState.currentFrame + 1) / \(capture.frameCount)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
    
    private func applySkeletonOverride(labels: [String], model: SkeletonModel) {
        guard let capture = appState.currentCapture else { return }
        
        var newLabels = capture.markers.labels
        let limit = min(newLabels.count, labels.count)
        
        for i in 0..<limit {
            newLabels[i] = labels[i]
        }
        
        let newMarkers = MarkerData(
            labels: newLabels,
            frameRate: capture.markers.frameRate,
            positions: capture.markers.positions,
            residuals: capture.markers.residuals
        )
        
        // Create new metadata with modified ID/filename to trigger updates
        let newMetadata = CaptureMetadata(
            filename: capture.metadata.filename + " (Override)",
            subject: capture.metadata.subject,
            description: capture.metadata.description,
            captureDate: capture.metadata.captureDate,
            manufacturer: capture.metadata.manufacturer,
            softwareVersion: capture.metadata.softwareVersion
        )

        let newCapture = MotionCapture(
            metadata: newMetadata,
            markers: newMarkers,
            analogs: capture.analogs,
            events: capture.events,
            segments: capture.segments
        )
        
        // Update AppState
        appState.forcedSkeletonModel = model // Force the selected model
        appState.currentCapture = newCapture
        print("🦴 Skeleton Override applied: Renamed \(limit) markers & Forced \(model.name).")
        
        // Debug: Print marker positions at frame 0 to help identify correct ordering
        print("\n📍 MARKER POSITIONS AT FRAME 0 (sorted by Y-height, highest first):")
        let positions = capture.markers.positions(at: 0)
        var markerInfo: [(index: Int, original: String, renamed: String, y: Float)] = []
        
        for (i, pos) in positions.enumerated() {
            let origLabel = (i < capture.markers.labels.count ? capture.markers.labels[i] : nil) ?? "?"
            let newLabel = (i < newLabels.count ? newLabels[i] : nil) ?? "?"
            let yPos = pos?.y ?? -9999
            markerInfo.append((i, origLabel, newLabel, yPos))
        }
        
        // Sort by Y position (descending - head at top)
        markerInfo.sort { $0.y > $1.y }
        
        for info in markerInfo {
            print("  [\(String(format: "%02d", info.index))] Y=\(String(format: "%7.1f", info.y)) | \(info.original) → \(info.renamed)")
        }
    }
    
    private func applySpatialSkeletonIdentification() {
        guard let capture = appState.currentCapture else { return }
        
        // Get positions at frame 0
        let positions = capture.markers.positions(at: 0)
        
        // Use spatial analysis to identify markers
        let identifiedLabels = SkeletonModel.identifyMarkersBySpatialPosition(positions: positions)
        
        let newMarkers = MarkerData(
            labels: identifiedLabels,
            frameRate: capture.markers.frameRate,
            positions: capture.markers.positions,
            residuals: capture.markers.residuals
        )
        
        // Create new metadata with modified ID/filename to trigger updates
        let newMetadata = CaptureMetadata(
            filename: capture.metadata.filename + " (Spatial)",
            subject: capture.metadata.subject,
            description: capture.metadata.description,
            captureDate: capture.metadata.captureDate,
            manufacturer: capture.metadata.manufacturer,
            softwareVersion: capture.metadata.softwareVersion
        )

        let newCapture = MotionCapture(
            metadata: newMetadata,
            markers: newMarkers,
            analogs: capture.analogs,
            events: capture.events,
            segments: capture.segments
        )
        
        // Update AppState
        appState.forcedSkeletonModel = .pitching29
        appState.currentCapture = newCapture
        print("🧠 Spatial skeleton identification applied!")
        
        // Print the mapping
        print("\n📍 SPATIAL IDENTIFICATION RESULTS:")
        for (i, label) in identifiedLabels.enumerated() {
            let pos = (i < positions.count ? positions[i] : nil) ?? nil
            let yStr = pos != nil ? String(format: "%.1f", pos!.y) : "N/A"
            print("  [\(String(format: "%02d", i))] Y=\(yStr) → \(label)")
        }
    }
    
    private func applyDistanceBasedSkeleton() {
        guard let capture = appState.currentCapture else { return }
        
        // Get positions at frame 0
        let positions = capture.markers.positions(at: 0)
        
        // Build skeleton from distances (uses Minimum Spanning Tree algorithm)
        let autoSkeleton = SkeletonModel.buildFromDistances(
            positions: positions,
            labels: capture.markers.labels,
            maxBoneLength: 600.0  // Increased for longer limb segments
        )
        
        // Store the generated skeleton for rendering
        appState.forcedSkeletonModel = autoSkeleton
        
        // Trigger refresh by updating capture metadata
        let newMetadata = CaptureMetadata(
            filename: capture.metadata.filename + " (AutoConnect)",
            subject: capture.metadata.subject,
            description: capture.metadata.description,
            captureDate: capture.metadata.captureDate,
            manufacturer: capture.metadata.manufacturer,
            softwareVersion: capture.metadata.softwareVersion
        )
        
        let newCapture = MotionCapture(
            metadata: newMetadata,
            markers: capture.markers,
            analogs: capture.analogs,
            events: capture.events,
            segments: capture.segments
        )
        
        appState.currentCapture = newCapture
        print("🔗 Distance-based skeleton applied with \(autoSkeleton.bones.count) bones!")
    }
    
    private func debugPrintMarkerBounds() {
        guard let capture = appState.currentCapture else {
            // Show alert dialog
            let alert = NSAlert()
            alert.messageText = "No File Loaded"
            alert.informativeText = "Please open a C3D file first using File → Open (⌘+O)"
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        let positions = capture.markers.positions(at: 0)
        
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minY: Float = .greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        var validCount = 0
        
        for pos in positions {
            guard let p = pos, p.x.isFinite else { continue }
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
            minZ = min(minZ, p.z); maxZ = max(maxZ, p.z)
            validCount += 1
        }
        
        // Build info string
        let xSpan = maxX - minX
        let ySpan = maxY - minY
        let zSpan = maxZ - minZ
        
        var verticalAxis = "Y"
        if zSpan > xSpan && zSpan > ySpan {
            verticalAxis = "Z (Try 'Swap Y↔Z'!)"
        } else if xSpan > ySpan && xSpan > zSpan {
            verticalAxis = "X (unusual)"
        }
        
        let info = """
        Valid Markers: \(validCount) / \(positions.count)
        
        X Range: \(String(format: "%.1f", minX)) to \(String(format: "%.1f", maxX))
        Y Range: \(String(format: "%.1f", minY)) to \(String(format: "%.1f", maxY))
        Z Range: \(String(format: "%.1f", minZ)) to \(String(format: "%.1f", maxZ))
        
        Likely Vertical Axis: \(verticalAxis)
        """
        
        // Show alert with info
        let alert = NSAlert()
        alert.messageText = "Marker Data Analysis"
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    private func swapYZCoordinates() {
        guard let capture = appState.currentCapture else { return }
        
        // Swap Y and Z for all frames and markers
        var newPositions: [[SIMD3<Float>?]] = []
        
        for frame in 0..<capture.markers.frameCount {
            var framePositions: [SIMD3<Float>?] = []
            for marker in 0..<capture.markers.markerCount {
                if let pos = capture.markers.position(marker: marker, frame: frame) {
                    // Swap Y and Z, and potentially negate Z to fix handedness
                    framePositions.append(SIMD3<Float>(pos.x, pos.z, -pos.y))
                } else {
                    framePositions.append(nil)
                }
            }
            newPositions.append(framePositions)
        }
        
        let newMarkers = MarkerData(
            labels: capture.markers.labels,
            frameRate: capture.markers.frameRate,
            positions: newPositions,
            residuals: capture.markers.residuals
        )
        
        let newMetadata = CaptureMetadata(
            filename: capture.metadata.filename + " (Y↔Z)",
            subject: capture.metadata.subject,
            description: capture.metadata.description,
            captureDate: capture.metadata.captureDate,
            manufacturer: capture.metadata.manufacturer,
            softwareVersion: capture.metadata.softwareVersion
        )
        
        let newCapture = MotionCapture(
            metadata: newMetadata,
            markers: newMarkers,
            analogs: capture.analogs,
            events: capture.events,
            segments: capture.segments
        )
        
        appState.currentCapture = newCapture
        print("🔄 Swapped Y↔Z coordinates. Try Auto-Connect again!")
    }
    
    private func applySimpleLinesSkeleton() {
        guard let capture = appState.currentCapture else { return }
        
        // Build skeleton using distance-based nearest neighbors (creates proper skeleton shape)
        let positions = capture.markers.positions(at: 0)
        let skeleton = SkeletonModel.buildFromDistances(
            positions: positions,
            labels: capture.markers.labels,
            maxBoneLength: 600.0
        )
        
        appState.forcedSkeletonModel = skeleton
        
        // Trigger refresh
        let newMetadata = CaptureMetadata(
            filename: capture.metadata.filename + " (SimpleLines)",
            subject: capture.metadata.subject,
            description: capture.metadata.description,
            captureDate: capture.metadata.captureDate,
            manufacturer: capture.metadata.manufacturer,
            softwareVersion: capture.metadata.softwareVersion
        )
        
        let newCapture = MotionCapture(
            metadata: newMetadata,
            markers: capture.markers,
            analogs: capture.analogs,
            events: capture.events,
            segments: capture.segments
        )
        
        appState.currentCapture = newCapture
        
        let alert = NSAlert()
        alert.messageText = "Simple Lines Applied"
        alert.informativeText = "Connected \(skeleton.bones.count) bones sequentially."
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    private func loadSkeletonConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .xml]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a skeleton configuration file (JSON or XML)"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let config: SkeletonConfiguration
                
                if url.pathExtension.lowercased() == "xml" {
                    config = try SkeletonConfiguration.parseFromXML(data)
                } else {
                    config = try JSONDecoder().decode(SkeletonConfiguration.self, from: data)
                }
                
                // Apply the configuration
                let skeleton = SkeletonModel.createFromConfiguration(config)
                appState.forcedSkeletonModel = skeleton
                
                // Handle coordinate system swap if needed
                if let capture = appState.currentCapture, config.coordinateSystem == "Z-up" {
                    swapYZCoordinates()
                } else if let capture = appState.currentCapture {
                    // Just trigger refresh
                    let newMetadata = CaptureMetadata(
                        filename: capture.metadata.filename + " (Config)",
                        subject: capture.metadata.subject,
                        description: capture.metadata.description,
                        captureDate: capture.metadata.captureDate,
                        manufacturer: capture.metadata.manufacturer,
                        softwareVersion: capture.metadata.softwareVersion
                    )
                    
                    let newCapture = MotionCapture(
                        metadata: newMetadata,
                        markers: capture.markers,
                        analogs: capture.analogs,
                        events: capture.events,
                        segments: capture.segments
                    )
                    appState.currentCapture = newCapture
                }
                
                let alert = NSAlert()
                alert.messageText = "Config Loaded"
                alert.informativeText = "Loaded '\(config.name)' with \(skeleton.bones.count) bones."
                alert.alertStyle = .informational
                alert.runModal()
                
            } catch {
                let alert = NSAlert()
                alert.messageText = "Error Loading Config"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }
    
    private func saveSkeletonConfig() {
        guard let skeleton = appState.forcedSkeletonModel else {
            let alert = NSAlert()
            alert.messageText = "No Skeleton to Save"
            alert.informativeText = "Apply a skeleton first, then save it."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(skeleton.name.replacingOccurrences(of: " ", with: "_")).json"
        panel.message = "Save skeleton configuration as JSON"
        
        if panel.runModal() == .OK, let url = panel.url {
            let config = SkeletonConfiguration(
                name: skeleton.name,
                coordinateSystem: "Y-up",
                bones: skeleton.bones.map { 
                    SkeletonConfiguration.BoneConfig(from: $0.startMarker, to: $0.endMarker, bodyPart: $0.bodyPart.rawValue)
                }
            )
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(config)
                try data.write(to: url)
                
                let alert = NSAlert()
                alert.messageText = "Config Saved"
                alert.informativeText = "Saved to \(url.lastPathComponent)"
                alert.alertStyle = .informational
                alert.runModal()
                
            } catch {
                let alert = NSAlert()
                alert.messageText = "Error Saving Config"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }
}



/// Metal-based 3D visualization for motion capture data
struct InternalScene3DView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState
    var capture: MotionCapture? // Explicit capture
    
    @AppStorage("showGrid") private var showGrid: Bool = true
    @AppStorage("showAxes") private var showAxes: Bool = true
    @AppStorage("showForcePlates") private var showForcePlates: Bool = true
    @AppStorage("markerSize") private var markerSize: Double = 10
    
    func makeNSView(context: Context) -> InteractiveMetalView {
        let mtkView = InteractiveMetalView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        // Set up renderer reference for mouse handling
        mtkView.renderer = context.coordinator
        
        return mtkView
    }
    
    func updateNSView(_ nsView: InteractiveMetalView, context: Context) {
        context.coordinator.updateState(appState, explicitCapture: capture)
        context.coordinator.showGrid = showGrid
        context.coordinator.showAxes = showAxes
        context.coordinator.showForcePlates = showForcePlates
        context.coordinator.markerSize = Float(markerSize)
    }
    
    func makeCoordinator() -> SceneRenderer {
        let renderer = SceneRenderer(appState: appState)
        // Observe reset notification
        NotificationCenter.default.addObserver(forName: .resetCamera, object: nil, queue: .main) { _ in
            renderer.resetCamera()
        }
        // Observe zoom notifications
        NotificationCenter.default.addObserver(forName: .zoomIn, object: nil, queue: .main) { _ in
            renderer.zoom(delta: 1.0)
        }
        NotificationCenter.default.addObserver(forName: .zoomOut, object: nil, queue: .main) { _ in
            renderer.zoom(delta: -1.0)
        }
        return renderer
    }
}

// MARK: - Interactive Metal View (Mouse/Scroll)

class InteractiveMetalView: MTKView {
    weak var renderer: SceneRenderer?
    
    private var lastMouseLocation: CGPoint = .zero
    private var isRotating = false
    private var isPanning = false
    
    override var acceptsFirstResponder: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        logDebug("🖱️ Mouse Down at \(event.locationInWindow)")
        self.window?.makeFirstResponder(self)
        
        lastMouseLocation = event.locationInWindow
        if event.modifierFlags.contains(.option) {
            isPanning = true
        } else {
            isRotating = true
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isRotating = false
        isPanning = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = event.locationInWindow
        let deltaX = Float(location.x - lastMouseLocation.x)
        let deltaY = Float(location.y - lastMouseLocation.y)
        lastMouseLocation = location
        
        // logDebug("🖱️ Drag: dX=\(deltaX), dY=\(deltaY)")
        
        if isRotating {
            renderer?.rotate(deltaX: deltaX * 0.01, deltaY: deltaY * 0.01)
        } else if isPanning {
            renderer?.pan(deltaX: deltaX * 0.01, deltaY: deltaY * 0.01)
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        let delta = Float(event.deltaY)
        renderer?.zoom(delta: delta * 0.1)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        lastMouseLocation = event.locationInWindow
        isPanning = true
    }
    
    override func rightMouseUp(with event: NSEvent) {
        isPanning = false
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        let location = event.locationInWindow
        let deltaX = Float(location.x - lastMouseLocation.x)
        let deltaY = Float(location.y - lastMouseLocation.y)
        lastMouseLocation = location
        renderer?.pan(deltaX: deltaX * 0.01, deltaY: deltaY * 0.01)
    }
}

// MARK: - Scene Renderer

@MainActor
class SceneRenderer: NSObject, MTKViewDelegate {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var linePipelineState: MTLRenderPipelineState!
    private var markerPipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    // Embedded shader source for runtime compilation fallback
    private static let embeddedShaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    
    struct VertexIn {
        float3 position [[attribute(0)]];
        float4 color [[attribute(1)]];
    };
    
    struct VertexOut {
        float4 position [[position]];
        float4 color;
        float2 pointCoord;
    };
    
    struct Uniforms {
        float4x4 modelMatrix;
        float4x4 viewMatrix;
        float4x4 projectionMatrix;
    };
    
    vertex VertexOut vertexShader(
        VertexIn in [[stage_in]],
        constant Uniforms &uniforms [[buffer(1)]]
    ) {
        VertexOut out;
        float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
        float4 viewPosition = uniforms.viewMatrix * worldPosition;
        out.position = uniforms.projectionMatrix * viewPosition;
        out.color = in.color;
        out.pointCoord = float2(0, 0);
        return out;
    }
    
    fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
        return in.color;
    }
    
    struct MarkerInstance {
        float3 position;
        float4 color;
        float size;
    };
    
    vertex VertexOut markerVertexShader(
        uint vertexID [[vertex_id]],
        uint instanceID [[instance_id]],
        constant MarkerInstance *markers [[buffer(0)]],
        constant Uniforms &uniforms [[buffer(1)]]
    ) {
        VertexOut out;
        float2 quadVertices[6] = {
            float2(-1, -1), float2(1, -1), float2(-1, 1),
            float2(-1, 1), float2(1, -1), float2(1, 1)
        };
        MarkerInstance marker = markers[instanceID];
        float2 quadPos = quadVertices[vertexID] * marker.size;
        float4 viewPos = uniforms.viewMatrix * uniforms.modelMatrix * float4(marker.position, 1.0);
        viewPos.xy += quadPos;
        out.position = uniforms.projectionMatrix * viewPos;
        out.color = marker.color;
        out.pointCoord = quadVertices[vertexID];
        return out;
    }
    
    fragment float4 markerFragmentShader(VertexOut in [[stage_in]]) {
        float distSq = dot(in.pointCoord, in.pointCoord);
        if (distSq > 1.0) { discard_fragment(); }
        return in.color;
    }
    """
    
    // ...
    // MARK: - Metal Setup
    
    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        // Try multiple ways to load the Metal library
        var library: MTLLibrary?
        
        // Method 1: Default library from main bundle
        library = device.makeDefaultLibrary()
        
        // Method 2: Try from specific bundle
        if library == nil {
            if let bundleURL = Bundle.main.url(forResource: "default", withExtension: "metallib") {
                library = try? device.makeLibrary(URL: bundleURL)
            }
        }
        
        // Method 3: Compile shaders from source at runtime (fallback)
        if library == nil {
            print("⚠️ Loading shaders from embedded source (runtime compilation)...")
            let shaderSource = Self.embeddedShaderSource
            do {
                library = try device.makeLibrary(source: shaderSource, options: nil)
                print("✅ Shaders compiled from source successfully")
            } catch {
                print("❌ Failed to compile shaders: \(error)")
            }
        }
        
        guard let lib = library else {
            print("❌ CRITICAL: All shader loading methods failed!")
            return
        }
        
        // Verify shader functions exist
        guard let vertexFunc = lib.makeFunction(name: "vertexShader") else {
            print("❌ Failed to find vertexShader function in library")
            return
        }
        guard let fragmentFunc = lib.makeFunction(name: "fragmentShader") else {
            print("❌ Failed to find fragmentShader function in library")
            return
        }
        guard let markerVertexFunc = lib.makeFunction(name: "markerVertexShader") else {
            print("❌ Failed to find markerVertexShader function in library")
            return
        }
        guard let markerFragmentFunc = lib.makeFunction(name: "markerFragmentShader") else {
            print("❌ Failed to find markerFragmentShader function in library")
            return
        }
        
        print("✅ Metal shaders loaded successfully")
        
        // 1. Line Pipeline (Grid, Skeleton)
        let lineDescriptor = MTLRenderPipelineDescriptor()
        lineDescriptor.vertexFunction = vertexFunc
        lineDescriptor.fragmentFunction = fragmentFunc
        lineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        lineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        // Vertex Descriptor for Lines
        let lineVertexDescriptor = MTLVertexDescriptor()
        lineVertexDescriptor.attributes[0].format = .float3
        lineVertexDescriptor.attributes[0].offset = 0
        lineVertexDescriptor.attributes[0].bufferIndex = 0
        lineVertexDescriptor.attributes[1].format = .float4
        lineVertexDescriptor.attributes[1].offset = 16
        lineVertexDescriptor.attributes[1].bufferIndex = 0
        lineVertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        lineDescriptor.vertexDescriptor = lineVertexDescriptor
        
        do {
            linePipelineState = try device.makeRenderPipelineState(descriptor: lineDescriptor)
        } catch {
             logDebug("❌ Failed to create line pipeline: \(error)")
        }
        
        // 2. Marker Pipeline (Instanced)
        let markerDescriptor = MTLRenderPipelineDescriptor()
        markerDescriptor.vertexFunction = markerVertexFunc
        // Use separate fragment shader for circular cutouts
        markerDescriptor.fragmentFunction = markerFragmentFunc
        markerDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        markerDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        // No vertex descriptor needed for marker shader as it reads from buffers manually via index
        // But we need to ensure blending if we want transparent sprites (optional)
        markerDescriptor.colorAttachments[0].isBlendingEnabled = true
        markerDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        markerDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            markerPipelineState = try device.makeRenderPipelineState(descriptor: markerDescriptor)
        } catch {
             logDebug("❌ Failed to create marker pipeline: \(error)")
        }
        
        // Depth stencil state
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
        
        // Create buffers
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: .storageModeShared)
        
        markerVertexBuffer = device.makeBuffer(length: maxMarkerVertices * MemoryLayout<MarkerInstance>.stride, options: .storageModeShared)
        skeletonVertexBuffer = device.makeBuffer(length: maxSkeletonVertices * MemoryLayout<Vertex>.stride, options: .storageModeShared)
        
        // Create grid
        createGrid()
    }
    
    private func createGrid() {
        var vertices: [Vertex] = []
        let gridSize: Float = 5.0
        let gridSpacing: Float = 0.5
        let gridColor = SIMD4<Float>(0.2, 0.2, 0.25, 1.0)
        
        // Grid lines along X
        var z: Float = -gridSize
        while z <= gridSize {
            vertices.append(Vertex(position: SIMD3<Float>(-gridSize, 0, z), color: gridColor))
            vertices.append(Vertex(position: SIMD3<Float>(gridSize, 0, z), color: gridColor))
            z += gridSpacing
        }
        
        // Grid lines along Z
        var x: Float = -gridSize
        while x <= gridSize {
            vertices.append(Vertex(position: SIMD3<Float>(x, 0, -gridSize), color: gridColor))
            vertices.append(Vertex(position: SIMD3<Float>(x, 0, gridSize), color: gridColor))
            x += gridSpacing
        }
        
        gridVertexCount = vertices.count
        
        // Axis lines
        let axisLength: Float = 1.0
        vertices.append(Vertex(position: SIMD3<Float>(0, 0.001, 0), color: SIMD4<Float>(1, 0.3, 0.3, 1)))
        vertices.append(Vertex(position: SIMD3<Float>(axisLength, 0.001, 0), color: SIMD4<Float>(1, 0.3, 0.3, 1)))
        vertices.append(Vertex(position: SIMD3<Float>(0, 0, 0), color: SIMD4<Float>(0.3, 1, 0.3, 1)))
        vertices.append(Vertex(position: SIMD3<Float>(0, axisLength, 0), color: SIMD4<Float>(0.3, 1, 0.3, 1)))
        vertices.append(Vertex(position: SIMD3<Float>(0, 0.001, 0), color: SIMD4<Float>(0.3, 0.3, 1, 1)))
        vertices.append(Vertex(position: SIMD3<Float>(0, 0.001, axisLength), color: SIMD4<Float>(0.3, 0.3, 1, 1)))
        
        gridVertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        )
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Update uniforms
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        var uniforms = Uniforms(
            modelMatrix: matrix_identity_float4x4,
            viewMatrix: lookAt(eye: cameraPosition, center: cameraConfig.target, up: SIMD3(0, 1, 0)),
            projectionMatrix: perspective(fovY: radians(fieldOfView), aspect: aspectRatio, near: 0.1, far: 5000.0)
        )
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)
        
        renderEncoder.setDepthStencilState(depthState)
        
        // 1. Draw Grid (Lines)
        if showGrid, let gridBuffer = gridVertexBuffer, let pipeline = linePipelineState {
            renderEncoder.setRenderPipelineState(pipeline)
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            renderEncoder.setVertexBuffer(gridBuffer, offset: 0, index: 0)
            
            renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: gridVertexCount)
            if showAxes {
                renderEncoder.drawPrimitives(type: .line, vertexStart: gridVertexCount, vertexCount: 6)
            }
        }
        
        // 2. Draw Data
        if let capture = currentCapture {
            // Draw Skeleton (Lines)
            if let pipeline = linePipelineState {
                renderEncoder.setRenderPipelineState(pipeline)
                renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
                drawSkeleton(capture: capture, frame: currentFrame, encoder: renderEncoder)
                
                if showForcePlates {
                    drawForcePlates(capture: capture, frame: currentFrame, encoder: renderEncoder)
                }
            }
            
            // Draw Markers (Instanced Triangles)
            if let pipeline = markerPipelineState {
                renderEncoder.setRenderPipelineState(pipeline)
                renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1) // Uniforms at 1 matches shader
                drawMarkers(capture: capture, frame: currentFrame, encoder: renderEncoder)
            }
        }
        
        // 3. Comparison Trials [REMOVED]
        // Side-by-side view handles this now by instantiating separate Scene3DViews.
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    // Buffers
    private var uniformBuffer: MTLBuffer!
    private var gridVertexBuffer: MTLBuffer!
    private var gridVertexCount: Int = 0
    
    // Dynamic buffers (persistent to avoid allocation per frame)
    private var markerVertexBuffer: MTLBuffer!
    private var skeletonVertexBuffer: MTLBuffer!
    private let maxMarkerVertices = 2000 * 6 // Support up to 2000 markers
    private let maxSkeletonVertices = 200 * 2 // Support up to 200 bones
    
    // Shared Camera Config
    private var cameraConfig: CameraConfiguration { appState.cameraConfig }
    
    private var fieldOfView: Float = 60.0
    
    // Settings
    var showGrid: Bool = true
    var showAxes: Bool = true
    var showForcePlates: Bool = true
    var markerSize: Float = 10.0
    
    // State
    private var appState: AppState
    private var currentCapture: MotionCapture?
    private var currentFrame: Int = 0
    private var detectedSkeleton: SkeletonModel?
    private var unitScale: Float = 1.0
    
    // Camera Features
    // followSubject is in appState
    
    var cameraPosition: SIMD3<Float> {
        let x = cameraConfig.orbitRadius * cos(cameraConfig.orbitPhi) * sin(cameraConfig.orbitTheta)
        let y = cameraConfig.orbitRadius * sin(cameraConfig.orbitPhi)
        let z = cameraConfig.orbitRadius * cos(cameraConfig.orbitPhi) * cos(cameraConfig.orbitTheta)
        return cameraConfig.target + SIMD3(x, y, z)
    }
    
    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupMetal()
    }

    func updateState(_ appState: AppState, explicitCapture: MotionCapture? = nil) {
        self.appState = appState
        
        let targetCapture = explicitCapture ?? appState.currentCapture
        
        // Detect skeleton on capture change
        if globalCapturesAreDifferent(targetCapture, currentCapture) {
            currentCapture = targetCapture
            
            if let capture = currentCapture {
                // Priority: Forced Model > Auto Detect
                if let forced = appState.forcedSkeletonModel {
                    detectedSkeleton = forced
                    logDebug("🦴 Forced Skeleton Model: \(forced.name)")
                } else {
                    detectedSkeleton = SkeletonModel.autoDetect(from: capture.markers.labels)
                    if let skeleton = detectedSkeleton {
                        logDebug("🦴 Skeleton Auto-Detected: \(skeleton.name) with \(skeleton.bones.count) bones")
                    } else {
                        logDebug("⚠️ No Skeleton Detected. Markers available: \(capture.markers.labels.count)")
                    }
                }

                calculateUnitScale(capture: capture)
                // Only reset camera if it's the primary view (no explicit capture) OR if it's the first load
                if explicitCapture == nil {
                   resetCamera()
                }
            } else {
                detectedSkeleton = nil
            }
        }
        
        // Also update if forced model changes dynamically (e.g. from UI)
        if let forced = appState.forcedSkeletonModel, forced.name != detectedSkeleton?.name {
            detectedSkeleton = forced
            logDebug("🦴 Skeleton Model changed to: \(forced.name)")
        }
                

        
        self.currentFrame = appState.currentFrame
        
        // Auto-Center / Follow Logic
        if appState.followSubject, let capture = currentCapture {
            let positions = capture.markers.positions(at: currentFrame)
            var center = SIMD3<Float>(0, 0, 0)
            var count: Float = 0
            
            for pos in positions {
                guard let p = pos, p.x.isFinite else { continue }
                center += p * unitScale
                count += 1
            }
            
            if count > 0 {
                let centroid = center / count
                // Smooth interpolation could be added here
                cameraConfig.target = centroid
            }
        }
    }
    
    private func calculateUnitScale(capture: MotionCapture) {
        // Heuristic: If values are large (> 100), assume mm and scale to meters. 
        // If small (< 10), assume meters or similar.
        // We check the first frame's valid markers.
        var maxVal: Float = 0
        let positions = capture.markers.positions(at: 0)
        
        for pos in positions {
            guard let p = pos, p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            maxVal = max(maxVal, abs(p.x), abs(p.y), abs(p.z))
        }
        
        if maxVal > 100.0 {
            unitScale = 0.001 // Convert mm to meters
            logDebug("📏 Auto-detected units: mm (scaling by 0.001)")
        } else {
            unitScale = 1.0   // Keep as is
            logDebug("📏 Auto-detected units: meters/other (scale 1.0)")
        }
    }
    
    // MARK: - Camera Control
    
    func rotate(deltaX: Float, deltaY: Float) {
        cameraConfig.orbitTheta += deltaX
        cameraConfig.orbitPhi = min(max(cameraConfig.orbitPhi + deltaY, -Float.pi / 2 + 0.1), Float.pi / 2 - 0.1)
    }
    
    func pan(deltaX: Float, deltaY: Float) {
        // Calculate pan vectors in world space
        let forward = normalize(cameraConfig.target - cameraPosition)
        let right = normalize(cross(forward, SIMD3(0, 1, 0)))
        let up = cross(right, forward)
        
        cameraConfig.target += right * (-deltaX) + up * deltaY
    }
    
    func zoom(delta: Float) {
        cameraConfig.orbitRadius = max(0.1, min(100, cameraConfig.orbitRadius - delta))
    }
    
    func resetCamera() {
        guard let capture = currentCapture else {
            cameraConfig.reset()
            return
        }
        
        // Calculate bounding box of first frame
        var minBounds = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxBounds = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        var hasPoints = false
        
        let positions = capture.markers.positions(at: 0)
        for pos in positions {
            guard let p = pos, p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            let scaledP = p * unitScale
            minBounds = min(minBounds, scaledP)
            maxBounds = max(maxBounds, scaledP)
            hasPoints = true
        }
        
        if hasPoints {
            let center = (minBounds + maxBounds) / 2.0
            let size = maxBounds - minBounds
            let maxDim = max(size.x, size.y, size.z)
            
            cameraConfig.target = center
            cameraConfig.orbitRadius = max(maxDim * 1.5, 2.0) // Fit to view
            cameraConfig.orbitTheta = 0.5
            cameraConfig.orbitPhi = 0.2
            
            logDebug("🎥 Camera centered at: \(center), Radius: \(cameraConfig.orbitRadius)")
        } else {
            // Default if no points found
            cameraConfig.reset()
        }
    }
    
    // MARK: - MTKViewDelegate
    


    // MARK: - Drawing
    
    private func drawMarkers(capture: MotionCapture, frame: Int, encoder: MTLRenderCommandEncoder, colorOverride: SIMD4<Float>? = nil) {
        let positions = capture.markers.positions(at: frame)
        var instances: [MarkerInstance] = []
        
        for (i, pos) in positions.enumerated() {
            guard let p = pos, p.x.isFinite else { continue }
            
            // Determine color
            let color = colorOverride ?? SIMD4<Float>(0.8, 0.9, 1.0, 1.0) 
            
            instances.append(MarkerInstance(
                position: p * unitScale,
                color: color,
                size: markerSize * 0.002 // Scale down for rendering
            ))
        }
        
        guard !instances.isEmpty else { return }
        
        // Copy to buffer
        let byteLength = instances.count * MemoryLayout<MarkerInstance>.stride
        if byteLength > markerVertexBuffer.length {
            // Reallocate if needed (simplified: just cap for now)
             logDebug("⚠️ Too many markers to render")
             return
        }
        
        memcpy(markerVertexBuffer.contents(), instances, byteLength)
        
        encoder.setVertexBuffer(markerVertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instances.count)
    }
    
    private func drawSkeleton(capture: MotionCapture, frame: Int, encoder: MTLRenderCommandEncoder, colorOverride: SIMD4<Float>? = nil) {
        // Use forced model or auto-detected (fallback to primary detection if simple lines)
        // For comparison, we try to use the PRIMARY skeleton definition if the markers match, 
        // to ensure consistent drawing.
        let skeletonToUse = detectedSkeleton ?? SkeletonModel.autoDetect(from: capture.markers.labels)
        
        guard let skeleton = skeletonToUse else { return }
        
        let positions = capture.markers.positions(at: frame)
        var vertexCount = 0
        let ptr = skeletonVertexBuffer.contents().bindMemory(to: Vertex.self, capacity: maxSkeletonVertices)
        
        var validBones = 0
        var missingMarkers = Set<String>()
        
        for bone in skeleton.bones {
            if vertexCount + 2 > maxSkeletonVertices { break }
            
            guard let startIdx = capture.markers.markerIndex(for: bone.startMarker),
                  let endIdx = capture.markers.markerIndex(for: bone.endMarker) else {
                missingMarkers.insert(bone.startMarker)
                missingMarkers.insert(bone.endMarker)
                continue
            }
            
            guard let startPos = (startIdx < positions.count ? positions[startIdx] : nil) ?? nil,
                  let endPos = (endIdx < positions.count ? positions[endIdx] : nil) ?? nil else {
                // Occluded
                continue
            }
            
            let scaledStart = startPos * unitScale
            let scaledEnd = endPos * unitScale
            
            // Use BodyPart color or override
            let color = colorOverride ?? bone.bodyPart.color
            
            ptr[vertexCount + 0] = Vertex(position: scaledStart, color: color)
            ptr[vertexCount + 1] = Vertex(position: scaledEnd, color: color)
            
            vertexCount += 2
            validBones += 1
        }
        
        // Debug Log (Throttle this in production, but helpful now)
        if frame % 60 == 0 { // Log once per second approx
             print("🦴 DrawSkeleton: \(skeleton.name) -> Drawn Bones: \(validBones)/\(skeleton.bones.count). Vertices: \(vertexCount)")
             if !missingMarkers.isEmpty {
                 let missingList = missingMarkers.subtracting(Set(capture.markers.labels)) // Only show truly missing labels
                 if !missingList.isEmpty {
                    print("⚠️ Missing Bone Markers: \(missingList.prefix(5))...")
                 }
             }
        }
        
        guard vertexCount > 0 else { return }
        
        encoder.setVertexBuffer(skeletonVertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
    }
    

    private func drawForcePlates(capture: MotionCapture, frame: Int, encoder: MTLRenderCommandEncoder) {
        guard !capture.analogs.channels.isEmpty else { return }
        
        let ptr = skeletonVertexBuffer.contents().bindMemory(to: Vertex.self, capacity: maxSkeletonVertices)
        var vertexCount = 0
        
        // Simple heuristic: Look for triplets of channels ending in X, Y, Z (e.g., Fx1, Fy1, Fz1)
        // Or just draw raw vectors from origin if "Force" or "F" is in name
        
        // Group by prefix
        var forces: [String: (x: Float, y: Float, z: Float)] = [:]
        
        // Get sample index from frame (assuming sync)
        // Analog sample rate might be higher than marker frame rate
        let ratio = capture.analogs.sampleRate / capture.markers.frameRate
        let sampleIdx = Int(Double(frame) * ratio)
        guard sampleIdx < capture.analogs.sampleCount else { return }
        
        for channel in capture.analogs.channels {
            let label = channel.label
            guard label.contains("F") || label.contains("Force") else { continue }
            
            // Extract component
            var component = "X"
            if label.hasSuffix("X") || label.hasSuffix("x") { component = "X" }
            else if label.hasSuffix("Y") || label.hasSuffix("y") { component = "Y" }
            else if label.hasSuffix("Z") || label.hasSuffix("z") { component = "Z" }
            else { continue }
            
            // Extract base name (remove coordinate suffix)
            let baseName = String(label.dropLast(1))
            
            let value = channel.data[sampleIdx]
            
            if forces[baseName] == nil {
                forces[baseName] = (0, 0, 0)
            }
            
            if component == "X" { forces[baseName]?.x = value }
            else if component == "Y" { forces[baseName]?.y = value }
            else if component == "Z" { forces[baseName]?.z = value }
        }
        
        // Draw vectors
        let scale: Float = 0.002 // Scale force to mm/units (N -> mm)
        let origin = SIMD3<Float>(0, 0, 0) // Draw at origin
        
        for (_, force) in forces {
            // Filter noise
            if abs(force.x) < 5 && abs(force.y) < 5 && abs(force.z) < 5 { continue }
            
            let vector = SIMD3<Float>(force.x, force.y, force.z) * scale
            let end = origin + vector
            
            // Yellow for force
            let color = SIMD4<Float>(1.0, 1.0, 0.0, 1.0)
            
            if vertexCount + 2 <= maxSkeletonVertices {
                ptr[vertexCount] = Vertex(position: origin, color: color)
                ptr[vertexCount + 1] = Vertex(position: end, color: color)
                vertexCount += 2
            }
        }
        
        guard vertexCount > 0 else { return }
        
        encoder.setVertexBuffer(skeletonVertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
    }

}



// MARK: - Notifications
extension Notification.Name {
    static let resetCamera = Notification.Name("ResetCamera")
    static let zoomIn = Notification.Name("ZoomIn")
    static let zoomOut = Notification.Name("ZoomOut")
    static let toggleFullscreen = Notification.Name("ToggleFullscreen")
    static let openDataEditor = Notification.Name("OpenDataEditor")
}

// MARK: - Shader Types

struct Vertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

struct MarkerInstance {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
    var size: Float
    // Padding to match Metal 16-byte alignment (Total 48 bytes)
    var _pad1: Float = 0
    var _pad2: Float = 0
    var _pad3: Float = 0
}

struct Uniforms {
    var modelMatrix: float4x4
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
}

// MARK: - Math Utilities

func radians(_ degrees: Float) -> Float {
    degrees * .pi / 180.0
}

func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
    let z = normalize(eye - center)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    
    return float4x4(columns: (
        SIMD4<Float>(x.x, y.x, z.x, 0),
        SIMD4<Float>(x.y, y.y, z.y, 0),
        SIMD4<Float>(x.z, y.z, z.z, 0),
        SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
    ))
}

func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
    let yScale = 1 / tan(fovY * 0.5)
    let xScale = yScale / aspect
    let zRange = far - near
    let zScale = -(far + near) / zRange
    let wzScale = -2 * far * near / zRange
    
    return float4x4(columns: (
        SIMD4<Float>(xScale, 0, 0, 0),
        SIMD4<Float>(0, yScale, 0, 0),
        SIMD4<Float>(0, 0, zScale, -1),
        SIMD4<Float>(0, 0, wzScale, 0)
    ))
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// MARK: - Capture Comparison Helper

func globalCapturesAreDifferent(_ lhs: MotionCapture?, _ rhs: MotionCapture?) -> Bool {
    lhs?.metadata.filename != rhs?.metadata.filename
}

// MARK: - Preview

#Preview {
    Scene3DView()
        .environmentObject(AppState())
        .frame(width: 600, height: 400)
}


// Removed duplicate extension
