import SwiftUI

/// Theme selection panel with live preview
struct ThemePickerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Visual Theme")
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
            
            ScrollView {
                VStack(spacing: 20) {
                    // Preset Themes
                    Section {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(Theme.presets) { theme in
                                ThemeCard(
                                    theme: theme,
                                    isSelected: themeManager.currentTheme.name == theme.name,
                                    onSelect: { themeManager.apply(theme) }
                                )
                            }
                        }
                    } header: {
                        HStack {
                            Text("Preset Themes")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    
                    // Custom Themes
                    if !themeManager.customThemes.isEmpty {
                        Section {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(themeManager.customThemes) { theme in
                                    ThemeCard(
                                        theme: theme,
                                        isSelected: themeManager.currentTheme.name == theme.name,
                                        onSelect: { themeManager.apply(theme) },
                                        onDelete: { themeManager.deleteCustomTheme(theme) }
                                    )
                                }
                            }
                        } header: {
                            HStack {
                                Text("Custom Themes")
                                    .font(.headline)
                                Spacer()
                            }
                        }
                    }
                    
                    // Import/Export
                    Section {
                        HStack(spacing: 12) {
                            Button(action: importTheme) {
                                Label("Import Theme", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(action: exportTheme) {
                                Label("Export Current", systemImage: "square.and.arrow.up")
                            }
                        }
                    } header: {
                        HStack {
                            Text("Import / Export")
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 500, minHeight: 450)
    }
    
    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let theme = try themeManager.importTheme(from: url)
                themeManager.apply(theme)
            } catch {
                print("Failed to import theme: \(error)")
            }
        }
    }
    
    private func exportTheme() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(themeManager.currentTheme.name).json"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try themeManager.exportTheme(themeManager.currentTheme, to: url)
            } catch {
                print("Failed to export theme: \(error)")
            }
        }
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let onSelect: () -> Void
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Color Preview
                HStack(spacing: 4) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.backgroundColor.color)
                        .frame(width: 30, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Markers & Skeleton
                    VStack(spacing: 2) {
                        Circle()
                            .fill(theme.markerDefaultColor.color)
                            .frame(width: 12, height: 12)
                        
                        Rectangle()
                            .fill(theme.skeletonLeftLegColor.color)
                            .frame(width: 3, height: 20)
                    }
                    
                    // Body part colors
                    VStack(spacing: 2) {
                        Circle()
                            .fill(theme.skeletonHeadColor.color)
                            .frame(width: 10, height: 10)
                        Rectangle()
                            .fill(theme.skeletonSpineColor.color)
                            .frame(width: 3, height: 14)
                        Circle()
                            .fill(theme.skeletonPelvisColor.color)
                            .frame(width: 8, height: 8)
                    }
                    
                    // Axis colors
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2) {
                            Rectangle().fill(theme.axisXColor.color).frame(width: 12, height: 3)
                            Text("X").font(.system(size: 8)).foregroundColor(theme.axisXColor.color)
                        }
                        HStack(spacing: 2) {
                            Rectangle().fill(theme.axisYColor.color).frame(width: 12, height: 3)
                            Text("Y").font(.system(size: 8)).foregroundColor(theme.axisYColor.color)
                        }
                        HStack(spacing: 2) {
                            Rectangle().fill(theme.axisZColor.color).frame(width: 12, height: 3)
                            Text("Z").font(.system(size: 8)).foregroundColor(theme.axisZColor.color)
                        }
                    }
                }
                .padding(8)
                .background(theme.backgroundColor.color.opacity(0.3))
                .cornerRadius(8)
                
                // Name & Description
                VStack(spacing: 2) {
                    Text(theme.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(theme.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ThemePickerView()
        .environmentObject(ThemeManager.shared)
}
