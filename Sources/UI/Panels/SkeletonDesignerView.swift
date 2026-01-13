import SwiftUI

/// Interactive skeleton designer for building custom bone connections
struct SkeletonDesignerView: View {
    @EnvironmentObject var appState: AppState
    
    // Editing State
    @State private var bones: [EditableBone] = []
    @State private var selectedStartMarker: String? = nil
    @State private var selectedBoneID: UUID? = nil
    @State private var showingSavePanel = false
    @State private var showingLoadPanel = false
    @State private var configName: String = "My Skeleton"
    
    /// Editable bone connection
    struct EditableBone: Identifiable, Hashable {
        let id = UUID()
        var from: String
        var to: String
        var bodyPart: BodyPart = .other
    }
    
    var body: some View {
        HSplitView {
            // Left: Marker List & Preview
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Markers")
                        .font(.headline)
                    Spacer()
                    if let start = selectedStartMarker {
                        Text("Start: \(start)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Cancel") { selectedStartMarker = nil }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(.bar)
                
                Divider()
                
                // Marker Grid
                if let capture = appState.currentCapture {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(capture.markers.labels, id: \.self) { label in
                                MarkerButton(
                                    label: label,
                                    isStart: selectedStartMarker == label,
                                    isConnected: isMarkerConnected(label),
                                    action: { handleMarkerClick(label) }
                                )
                            }
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "No Capture Loaded",
                        systemImage: "cube.transparent",
                        description: Text("Load a motion capture file to start designing a skeleton.")
                    )
                }
            }
            .frame(minWidth: 300)
            
            // Right: Bone List & Controls
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Bones (\(bones.count))")
                        .font(.headline)
                    Spacer()
                    Button(action: { bones = [] }) {
                        Image(systemName: "trash")
                    }
                    .help("Clear All Bones")
                    .disabled(bones.isEmpty)
                }
                .padding()
                .background(.bar)
                
                Divider()
                
                // Bone List
                if bones.isEmpty {
                    ContentUnavailableView(
                        "No Bones",
                        systemImage: "line.diagonal",
                        description: Text("Click two markers to create a bone connection.")
                    )
                } else {
                    List(selection: $selectedBoneID) {
                        ForEach(bones) { bone in
                            HStack {
                                Circle()
                                    .fill(Color(bone.bodyPart.swiftUIColor))
                                    .frame(width: 12, height: 12)
                                
                                Text("\(bone.from)")
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                Text("\(bone.to)")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                // Body Part Picker
                                Menu {
                                    ForEach(BodyPart.allCases, id: \.self) { part in
                                        Button(part.rawValue.capitalized) {
                                            updateBodyPart(for: bone.id, to: part)
                                        }
                                    }
                                } label: {
                                    Text(bone.bodyPart.rawValue.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.quaternary)
                                        .cornerRadius(4)
                                }
                                .menuStyle(.borderlessButton)
                            }
                            .tag(bone.id)
                        }
                        .onDelete(perform: deleteBones)
                    }
                }
                
                Divider()
                
                // Actions
                VStack(spacing: 12) {
                    // Config Name
                    TextField("Configuration Name", text: $configName)
                        .textFieldStyle(.roundedBorder)
                    
                    // Save/Load Buttons
                    HStack {
                        Button(action: { showingSavePanel = true }) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .disabled(bones.isEmpty)
                        
                        Button(action: { showingLoadPanel = true }) {
                            Label("Load", systemImage: "square.and.arrow.up")
                        }
                    }
                    
                    Divider()
                    
                    // Apply to Current Capture
                    Button(action: applyToCapture) {
                        Label("Apply to Capture", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(bones.isEmpty)
                }
                .padding()
            }
            .frame(minWidth: 280, idealWidth: 320)
        }
        .fileExporter(
            isPresented: $showingSavePanel,
            document: SkeletonConfigDocument(configuration: buildConfiguration()),
            contentType: .json,
            defaultFilename: "\(configName).json"
        ) { result in
            if case .failure(let error) = result {
                print("Save error: \(error)")
            }
        }
        .fileImporter(
            isPresented: $showingLoadPanel,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            loadConfiguration(from: result)
        }
        .onAppear {
            // Load existing skeleton if available
            if let model = appState.forcedSkeletonModel {
                bones = model.bones.map { bone in
                    EditableBone(from: bone.startMarker, to: bone.endMarker, bodyPart: bone.bodyPart)
                }
                configName = model.name
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleMarkerClick(_ label: String) {
        if let start = selectedStartMarker {
            // Create bone
            if start != label {
                let newBone = EditableBone(from: start, to: label)
                // Check for duplicates
                if !bones.contains(where: { ($0.from == start && $0.to == label) || ($0.from == label && $0.to == start) }) {
                    bones.append(newBone)
                }
            }
            selectedStartMarker = nil
        } else {
            // Start selection
            selectedStartMarker = label
        }
    }
    
    private func isMarkerConnected(_ label: String) -> Bool {
        bones.contains { $0.from == label || $0.to == label }
    }
    
    private func updateBodyPart(for boneID: UUID, to part: BodyPart) {
        if let index = bones.firstIndex(where: { $0.id == boneID }) {
            bones[index].bodyPart = part
        }
    }
    
    private func deleteBones(at offsets: IndexSet) {
        bones.remove(atOffsets: offsets)
    }
    
    private func buildConfiguration() -> SkeletonConfiguration {
        SkeletonConfiguration(
            name: configName,
            coordinateSystem: "Y-up",
            bones: bones.map { bone in
                SkeletonConfiguration.BoneConfig(
                    from: bone.from,
                    to: bone.to,
                    bodyPart: bone.bodyPart.rawValue
                )
            }
        )
    }
    
    private func applyToCapture() {
        let config = buildConfiguration()
        let model = SkeletonModel.createFromConfiguration(config)
        appState.forcedSkeletonModel = model
        print("✅ Applied skeleton: \(model.name) with \(model.bones.count) bones")
    }
    
    private func loadConfiguration(from result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(SkeletonConfiguration.self, from: data)
            
            configName = config.name
            bones = config.bones.map { boneConfig in
                EditableBone(
                    from: boneConfig.from,
                    to: boneConfig.to,
                    bodyPart: BodyPart(rawValue: boneConfig.bodyPart ?? "other") ?? .other
                )
            }
            print("✅ Loaded skeleton config: \(config.name)")
        } catch {
            print("❌ Failed to load config: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct MarkerButton: View {
    let label: String
    let isStart: Bool
    let isConnected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .foregroundStyle(isStart ? .white : .primary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isConnected ? Color.green : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if isStart {
            return .accentColor
        } else if isConnected {
            return Color.green.opacity(0.2)
        } else {
            return Color.secondary.opacity(0.1)
        }
    }
}

// MARK: - File Document for Export

struct SkeletonConfigDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var configuration: SkeletonConfiguration
    
    init(configuration: SkeletonConfiguration) {
        self.configuration = configuration
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.configuration = try JSONDecoder().decode(SkeletonConfiguration.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self.configuration)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Extensions

extension BodyPart: CaseIterable {
    public static var allCases: [BodyPart] {
        [.head, .spine, .leftArm, .rightArm, .leftLeg, .rightLeg, .pelvis, .other]
    }
    
    var swiftUIColor: Color {
        switch self {
        case .head: return .yellow
        case .spine: return .green
        case .leftArm: return .red
        case .rightArm: return .blue
        case .leftLeg: return .orange
        case .rightLeg: return .cyan
        case .pelvis: return .purple
        case .other: return .gray
        }
    }
}

import UniformTypeIdentifiers

#Preview {
    SkeletonDesignerView()
        .environmentObject(AppState())
        .frame(width: 800, height: 500)
}
