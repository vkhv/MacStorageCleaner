import SwiftUI
import Charts

struct SystemAnalysisView: View {
    let directory: DirectoryInfo
    @State private var analysis: SystemFolderAnalysis?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(directory.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(directory.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Закрыть") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding()
                
                if let analysis = analysis {
                    // Summary Cards
                    HStack(spacing: 16) {
                        SummaryCard(
                            title: "Общий размер",
                            value: analysis.formattedTotalSize,
                            icon: "externaldrive",
                            color: .blue
                        )
                        
                        SummaryCard(
                            title: "Можно удалить",
                            value: analysis.formattedDeletableSize,
                            icon: "trash.circle.fill",
                            color: .green,
                            subtitle: "\(analysis.deletablePercent)%"
                        )
                        
                        SummaryCard(
                            title: "Элементов",
                            value: "\(analysis.recommendations.count)",
                            icon: "folder.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Detailed Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Детальная информация")
                            .font(.headline)
                        
                        Text(analysis.detailedInfo)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // File Breakdown Chart
                    if !analysis.fileBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Распределение по типам")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(analysis.fileBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { item in
                                SectorMark(
                                    angle: .value("Size", item.value),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 2
                                )
                                .foregroundStyle(by: .value("Category", item.key))
                            }
                            .frame(height: 250)
                            .padding(.horizontal)
                            
                            // Legend
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                                ForEach(analysis.fileBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { item in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .frame(width: 10, height: 10)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.key)
                                                .font(.caption)
                                            Text(ByteCountFormatter.string(fromByteCount: item.value, countStyle: .file))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    
                    // Recommendations List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Детальные рекомендации")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(analysis.recommendations) { recommendation in
                            RecommendationRow(recommendation: recommendation)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            analysis = SystemFolderAnalyzer.analyzeSystemFolder(directory.path, dirInfo: directory)
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(color)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct RecommendationRow: View {
    let recommendation: DetailedRecommendation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 12) {
                    // Impact indicator
                    Circle()
                        .fill(impactColor)
                        .frame(width: 12, height: 12)
                    
                    // Title and size
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(recommendation.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text(recommendation.impact.rawValue)
                                .font(.caption)
                                .foregroundColor(impactColor)
                        }
                    }
                    
                    Spacer()
                    
                    // Deletable indicator
                    if recommendation.isDeletable {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                    
                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded description
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 8)
                    
                    Text(recommendation.description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: recommendation.path)
                        }) {
                            Label("Открыть в Finder", systemImage: "folder")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if recommendation.isDeletable {
                            Button(action: {
                                // TODO: Implement delete functionality
                                let alert = NSAlert()
                                alert.messageText = "Удаление недоступно"
                                alert.informativeText = "Функция удаления будет реализована в следующей версии. Пока используйте Finder для удаления файлов."
                                alert.alertStyle = .informational
                                alert.addButton(withTitle: "OK")
                                alert.runModal()
                            }) {
                                Label("Удалить", systemImage: "trash")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    var impactColor: Color {
        switch recommendation.impact {
        case .safe: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

