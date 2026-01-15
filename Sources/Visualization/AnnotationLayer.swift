import SwiftUI
import simd

// MARK: - Annotation Types

/// Types of annotations that can be drawn on the 3D view
public enum AnnotationType: String, Codable, CaseIterable, Sendable {
    case line
    case arrow
    case circle
    case rectangle
    case text
    case highlight
    case measurement  // Distance measurement between two points
    case angle        // Angle measurement (3 points)
    case markerLabel  // Label attached to a marker
    
    public var displayName: String {
        switch self {
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .circle: return "Circle"
        case .rectangle: return "Rectangle"
        case .text: return "Text"
        case .highlight: return "Highlight Zone"
        case .measurement: return "Measure Distance"
        case .angle: return "Measure Angle"
        case .markerLabel: return "Marker Label"
        }
    }
    
    public var iconName: String {
        switch self {
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        case .highlight: return "highlighter"
        case .measurement: return "ruler"
        case .angle: return "angle"
        case .markerLabel: return "tag"
        }
    }
}

// MARK: - Annotation

/// A single annotation on the 3D view
public struct Annotation: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var type: AnnotationType
    public var color: CodableColor
    public var lineWidth: Float
    public var text: String?
    
    // 2D screen coordinates (for overlay rendering)
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var midPoint: CGPoint?  // Third point for angle annotations
    
    // Optional: Frame-specific annotation (nil = global)
    public var frameIndex: Int?
    
    // Optional: 3D coordinates (for world-space annotations)
    public var worldStart: SIMD3<Float>?
    public var worldEnd: SIMD3<Float>?
    public var worldMid: SIMD3<Float>?  // For angle measurements
    
    // Measurement values (calculated)
    public var measurementValue: Double?  // Distance in units or angle in degrees
    
    // Locked to 3D space (moves with camera)
    public var isLockedTo3D: Bool = false
    
    public var isGlobal: Bool { frameIndex == nil }
    
    public init(
        type: AnnotationType,
        color: CodableColor = CodableColor(hex: "FF6B6B"),
        lineWidth: Float = 3.0,
        text: String? = nil,
        startPoint: CGPoint = .zero,
        endPoint: CGPoint = .zero,
        frameIndex: Int? = nil,
        isLockedTo3D: Bool = false
    ) {
        self.type = type
        self.color = color
        self.lineWidth = lineWidth
        self.text = text
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.frameIndex = frameIndex
        self.isLockedTo3D = isLockedTo3D
    }
}

// MARK: - Annotation Layer State

/// Manages all annotations for a capture
@MainActor
public class AnnotationLayer: ObservableObject {
    public static let shared = AnnotationLayer()
    
    @Published public var annotations: [Annotation] = []
    @Published public var isDrawing: Bool = false
    @Published public var currentTool: AnnotationType = .line
    @Published public var currentColor: CodableColor = CodableColor(hex: "FF6B6B")
    @Published public var currentLineWidth: Float = 3.0
    @Published public var currentAnnotation: Annotation?
    
    // Selection mode
    @Published public var isSelectMode: Bool = false
    @Published public var selectedAnnotationId: UUID?
    
    // Lock to 3D world space
    @Published public var lockTo3D: Bool = false
    
    // Undo/Redo stacks
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    
    public var selectedAnnotation: Annotation? {
        guard let id = selectedAnnotationId else { return nil }
        return annotations.first { $0.id == id }
    }
    
    private init() {}
    
    // MARK: - Drawing
    
    /// Start drawing a new annotation
    public func startDrawing(at point: CGPoint, frame: Int?) {
        currentAnnotation = Annotation(
            type: currentTool,
            color: currentColor,
            lineWidth: currentLineWidth,
            startPoint: point,
            endPoint: point,
            frameIndex: frame
        )
    }
    
    /// Continue drawing (update end point)
    public func continueDrawing(to point: CGPoint) {
        currentAnnotation?.endPoint = point
    }
    
    /// Finish drawing and add annotation
    public func finishDrawing() {
        guard let annotation = currentAnnotation else { return }
        
        // Save state for undo
        saveStateForUndo()
        
        annotations.append(annotation)
        currentAnnotation = nil
        
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    /// Cancel current drawing
    public func cancelDrawing() {
        currentAnnotation = nil
    }
    
    // MARK: - Text Annotations
    
    /// Add a text annotation at a point
    public func addTextAnnotation(text: String, at point: CGPoint, frame: Int?) {
        saveStateForUndo()
        
        var annotation = Annotation(
            type: .text,
            color: currentColor,
            lineWidth: currentLineWidth,
            text: text,
            startPoint: point,
            endPoint: point,
            frameIndex: frame
        )
        annotation.text = text
        annotations.append(annotation)
        
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    // MARK: - Editing
    
    /// Delete an annotation
    public func delete(_ annotation: Annotation) {
        saveStateForUndo()
        annotations.removeAll { $0.id == annotation.id }
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    /// Clear all annotations
    public func clearAll() {
        saveStateForUndo()
        annotations.removeAll()
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    /// Clear annotations for a specific frame
    public func clearFrame(_ frame: Int) {
        saveStateForUndo()
        annotations.removeAll { $0.frameIndex == frame }
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    // MARK: - Undo/Redo
    
    private func saveStateForUndo() {
        undoStack.append(annotations)
        redoStack.removeAll()
        
        // Limit undo stack size
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
    
    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    // MARK: - Filtering
    
    /// Get annotations for a specific frame (including global)
    public func annotations(forFrame frame: Int) -> [Annotation] {
        annotations.filter { $0.isGlobal || $0.frameIndex == frame }
    }
    
    // MARK: - Persistence
    
    /// Save annotations to data
    public func save() -> Data? {
        try? JSONEncoder().encode(annotations)
    }
    
    /// Load annotations from data
    public func load(from data: Data) {
        guard let loaded = try? JSONDecoder().decode([Annotation].self, from: data) else { return }
        annotations = loaded
        undoStack.removeAll()
        redoStack.removeAll()
    }
    
    /// Export to file
    public func exportAnnotations(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(annotations)
        try data.write(to: url)
    }
    
    /// Import from file
    public func importAnnotations(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let imported = try JSONDecoder().decode([Annotation].self, from: data)
        saveStateForUndo()
        annotations.append(contentsOf: imported)
    }
    
    // MARK: - Selection
    
    /// Select an annotation at a point
    public func selectAnnotation(at point: CGPoint, tolerance: CGFloat = 10) {
        for annotation in annotations.reversed() {
            if hitTest(annotation: annotation, at: point, tolerance: tolerance) {
                selectedAnnotationId = annotation.id
                return
            }
        }
        selectedAnnotationId = nil
    }
    
    /// Deselect current selection
    public func deselect() {
        selectedAnnotationId = nil
    }
    
    /// Delete the selected annotation
    public func deleteSelected() {
        guard let id = selectedAnnotationId else { return }
        saveStateForUndo()
        annotations.removeAll { $0.id == id }
        selectedAnnotationId = nil
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    /// Move the selected annotation by a delta
    public func moveSelected(by delta: CGSize) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        
        saveStateForUndo()
        annotations[index].startPoint.x += delta.width
        annotations[index].startPoint.y += delta.height
        annotations[index].endPoint.x += delta.width
        annotations[index].endPoint.y += delta.height
        if annotations[index].midPoint != nil {
            annotations[index].midPoint!.x += delta.width
            annotations[index].midPoint!.y += delta.height
        }
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    /// Scale the selected annotation by a factor
    public func scaleSelected(by factor: CGFloat) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        
        saveStateForUndo()
        
        // Calculate center
        let centerX = (annotations[index].startPoint.x + annotations[index].endPoint.x) / 2
        let centerY = (annotations[index].startPoint.y + annotations[index].endPoint.y) / 2
        
        // Scale from center
        annotations[index].startPoint.x = centerX + (annotations[index].startPoint.x - centerX) * factor
        annotations[index].startPoint.y = centerY + (annotations[index].startPoint.y - centerY) * factor
        annotations[index].endPoint.x = centerX + (annotations[index].endPoint.x - centerX) * factor
        annotations[index].endPoint.y = centerY + (annotations[index].endPoint.y - centerY) * factor
        
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    /// Update the color of selected annotation
    public func updateSelectedColor(_ color: CodableColor) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        
        saveStateForUndo()
        annotations[index].color = color
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    /// Update the line width of selected annotation
    public func updateSelectedLineWidth(_ width: Float) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        
        saveStateForUndo()
        annotations[index].lineWidth = width
        NotificationCenter.default.post(name: .annotationsDidChange, object: nil)
    }
    
    // MARK: - Hit Testing
    
    private func hitTest(annotation: Annotation, at point: CGPoint, tolerance: CGFloat) -> Bool {
        switch annotation.type {
        case .line, .arrow, .measurement:
            return distanceToLine(from: point, lineStart: annotation.startPoint, lineEnd: annotation.endPoint) < tolerance
        case .circle:
            let center = annotation.startPoint
            let radius = sqrt(pow(annotation.endPoint.x - center.x, 2) + pow(annotation.endPoint.y - center.y, 2))
            let dist = sqrt(pow(point.x - center.x, 2) + pow(point.y - center.y, 2))
            return abs(dist - radius) < tolerance
        case .rectangle, .highlight:
            let rect = CGRect(
                x: min(annotation.startPoint.x, annotation.endPoint.x),
                y: min(annotation.startPoint.y, annotation.endPoint.y),
                width: abs(annotation.endPoint.x - annotation.startPoint.x),
                height: abs(annotation.endPoint.y - annotation.startPoint.y)
            )
            return rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .text, .markerLabel:
            let rect = CGRect(x: annotation.startPoint.x - 50, y: annotation.startPoint.y - 20, width: 100, height: 40)
            return rect.contains(point)
        case .angle:
            // Check if near any of the three points
            let d1 = sqrt(pow(point.x - annotation.startPoint.x, 2) + pow(point.y - annotation.startPoint.y, 2))
            let d2 = sqrt(pow(point.x - annotation.endPoint.x, 2) + pow(point.y - annotation.endPoint.y, 2))
            let d3 = annotation.midPoint.map { sqrt(pow(point.x - $0.x, 2) + pow(point.y - $0.y, 2)) } ?? tolerance * 2
            return min(d1, d2, d3) < tolerance
        }
    }
    
    private func distanceToLine(from point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let length = sqrt(dx * dx + dy * dy)
        if length == 0 { return sqrt(pow(point.x - lineStart.x, 2) + pow(point.y - lineStart.y, 2)) }
        
        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (length * length)))
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy
        return sqrt(pow(point.x - projX, 2) + pow(point.y - projY, 2))
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let annotationsDidChange = Notification.Name("BioMotionPro.AnnotationsDidChange")
    static let captureSnapshot = Notification.Name("BioMotionPro.CaptureSnapshot")
}

// MARK: - CGPoint Codable Extension

extension CGPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}
