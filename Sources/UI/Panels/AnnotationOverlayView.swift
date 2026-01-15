import SwiftUI

/// Annotation drawing overlay that sits on top of the 3D view
struct AnnotationOverlayView: View {
    @StateObject private var annotationLayer = AnnotationLayer.shared
    @EnvironmentObject var appState: AppState
    
    @State private var dragStart: CGPoint?
    @State private var showTextInput = false
    @State private var textInputLocation: CGPoint = .zero
    @State private var textAnnotationInput = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Existing annotations
                ForEach(annotationLayer.annotations(forFrame: appState.currentFrame)) { annotation in
                    AnnotationShape(annotation: annotation)
                }
                
                // Current drawing annotation (preview while dragging)
                if let current = annotationLayer.currentAnnotation {
                    AnnotationShape(annotation: current)
                }
                
                // Drawing gesture area (only when drawing mode is on)
                if annotationLayer.isDrawing {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(drawingGesture)
                }
            }
        }
        .allowsHitTesting(annotationLayer.isDrawing)
        .sheet(isPresented: $showTextInput) {
            TextInputPopup(
                text: $textAnnotationInput,
                onSubmit: {
                    if !textAnnotationInput.isEmpty {
                        annotationLayer.addTextAnnotation(
                            text: textAnnotationInput,
                            at: textInputLocation,
                            frame: appState.currentFrame
                        )
                    }
                    showTextInput = false
                    textAnnotationInput = ""
                }
            )
        }
    }
    
    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // For text tool, just record the start position - don't draw
                if annotationLayer.currentTool == .text {
                    if dragStart == nil {
                        dragStart = value.startLocation
                    }
                    return
                }
                
                // For other tools, start/continue drawing
                if dragStart == nil {
                    dragStart = value.startLocation
                    annotationLayer.startDrawing(
                        at: value.startLocation,
                        frame: appState.currentFrame
                    )
                }
                annotationLayer.continueDrawing(to: value.location)
            }
            .onEnded { value in
                // For text tool, detect tap (short distance = tap)
                if annotationLayer.currentTool == .text {
                    let distance = sqrt(
                        pow(value.location.x - value.startLocation.x, 2) +
                        pow(value.location.y - value.startLocation.y, 2)
                    )
                    // If distance < 10 pixels, treat as tap
                    if distance < 10 {
                        textInputLocation = value.startLocation
                        textAnnotationInput = ""
                        showTextInput = true
                    }
                    dragStart = nil
                    return
                }
                
                // For other tools, finish drawing
                annotationLayer.finishDrawing()
                dragStart = nil
            }
    }
}

// MARK: - Text Input Popup

struct TextInputPopup: View {
    @Binding var text: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "textformat")
                    .foregroundColor(.accentColor)
                Text("Add Text Annotation")
                    .font(.headline)
                Spacer()
            }
            
            TextField("Enter text...", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 250)
                .onSubmit {
                    onSubmit()
                }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add") {
                    onSubmit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(minWidth: 300)
    }
}

// MARK: - Annotation Shape Drawing

struct AnnotationShape: View {
    let annotation: Annotation
    
    var body: some View {
        switch annotation.type {
        case .line:
            LineShape(start: annotation.startPoint, end: annotation.endPoint)
                .stroke(annotation.color.color, lineWidth: CGFloat(annotation.lineWidth))
            
        case .arrow:
            ArrowShape(start: annotation.startPoint, end: annotation.endPoint)
                .stroke(annotation.color.color, lineWidth: CGFloat(annotation.lineWidth))
            
        case .circle:
            CircleAnnotationShape(center: annotation.startPoint, edge: annotation.endPoint)
                .stroke(annotation.color.color, lineWidth: CGFloat(annotation.lineWidth))
            
        case .rectangle:
            RectangleAnnotationShape(start: annotation.startPoint, end: annotation.endPoint)
                .stroke(annotation.color.color, lineWidth: CGFloat(annotation.lineWidth))
            
        case .text, .markerLabel:
            if let text = annotation.text {
                Text(text)
                    .font(.system(size: CGFloat(annotation.lineWidth * 5)))
                    .foregroundColor(annotation.color.color)
                    .position(annotation.startPoint)
            }
            
        case .highlight:
            RectangleAnnotationShape(start: annotation.startPoint, end: annotation.endPoint)
                .fill(annotation.color.color.opacity(0.3))
                .overlay(
                    RectangleAnnotationShape(start: annotation.startPoint, end: annotation.endPoint)
                        .stroke(annotation.color.color, lineWidth: CGFloat(annotation.lineWidth))
                )
                
        case .measurement:
            ZStack {
                LineShape(start: annotation.startPoint, end: annotation.endPoint)
                    .stroke(annotation.color.color, lineWidth: CGFloat(annotation.lineWidth))
                
                // Show Distance
                let midPoint = CGPoint(
                    x: (annotation.startPoint.x + annotation.endPoint.x) / 2,
                    y: (annotation.startPoint.y + annotation.endPoint.y) / 2
                )
                let distance = sqrt(pow(annotation.endPoint.x - annotation.startPoint.x, 2) + pow(annotation.endPoint.y - annotation.startPoint.y, 2))
                
                Text(String(format: "%.1f px", distance))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .position(midPoint)
            }
            
        case .angle:
            ZStack {
                // Draw lines from center to end points
                if let mid = annotation.midPoint {
                    Path { path in
                        path.move(to: annotation.startPoint)
                        path.addLine(to: mid)
                        path.addLine(to: annotation.endPoint)
                    }
                    .stroke(annotation.color.color, lineWidth: CGFloat(annotation.lineWidth))
                    
                    // Show Angle Label
                    Text("∠")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .position(mid)
                }
            }
        }
    }
}

// MARK: - Shape Primitives

struct LineShape: Shape {
    let start: CGPoint
    let end: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

struct ArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        
        // Arrow head
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        let arrowPoint1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let arrowPoint2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        path.move(to: end)
        path.addLine(to: arrowPoint1)
        path.move(to: end)
        path.addLine(to: arrowPoint2)
        
        return path
    }
}

struct CircleAnnotationShape: Shape {
    let center: CGPoint
    let edge: CGPoint
    
    var radius: CGFloat {
        sqrt(pow(edge.x - center.x, 2) + pow(edge.y - center.y, 2))
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        return path
    }
}

struct RectangleAnnotationShape: Shape {
    let start: CGPoint
    let end: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ))
        return path
    }
}

#Preview {
    AnnotationOverlayView()
        .environmentObject(AppState())
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.3))
}
