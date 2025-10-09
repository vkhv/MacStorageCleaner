import SwiftUI

struct CleanupView: View {
    @ObservedObject var analyzer: StorageAnalyzer
    @State private var selectedRecommendation: CleanupRecommendation?
    @State private var expandedDirectories: Set<String> = []
    
    var topDirectories: [DirectoryInfo] {
        CleanupAnalyzer.getTopDirectories(analyzer.analysisState.directories, count: 10)
    }
    
    var allRecommendations: [CleanupRecommendation] {
        topDirectories.flatMap { CleanupAnalyzer.analyzeDirectory($0) }
    }
    
    var totalDeletableSize: Int64 {
        allRecommendations
            .filter { $0.isDeletable }
            .reduce(0) { $0 + $1.size }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Рекомендации по очистке")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if !allRecommendations.isEmpty {
                            Text("Можно освободить до \(ByteCountFormatter.string(fromByteCount: totalDeletableSize, countStyle: .file))")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    if !allRecommendations.isEmpty {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(allRecommendations.filter { $0.isDeletable }.count) безопасных")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("\(allRecommendations.filter { !$0.isDeletable }.count) требуют проверки")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                
                Divider()
                
                if analyzer.analysisState.directories.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Сначала запустите анализ диска")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Перейдите на вкладку \"Анализ\" и нажмите \"Начать анализ\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else {
                    // Top 10 Directories
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Топ-10 самых больших директорий")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ForEach(Array(topDirectories.enumerated()), id: \.element.id) { index, directory in
                            DirectoryDetailCard(
                                directory: directory,
                                index: index + 1,
                                isExpanded: expandedDirectories.contains(directory.path),
                                onToggle: {
                                    if expandedDirectories.contains(directory.path) {
                                        expandedDirectories.remove(directory.path)
                                    } else {
                                        expandedDirectories.insert(directory.path)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct DirectoryDetailCard: View {
    let directory: DirectoryInfo
    let index: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    
    @State private var showingSystemAnalysis = false
    
    var recommendations: [CleanupRecommendation] {
        CleanupAnalyzer.analyzeDirectory(directory)
    }
    
    var mainRecommendation: CleanupRecommendation? {
        recommendations.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card
            Button(action: onToggle) {
                HStack(spacing: 16) {
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(rankColor)
                            .frame(width: 40, height: 40)
                        
                        Text("\(index)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    // Directory info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(directory.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(directory.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Size and status
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(directory.formattedSize)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        if let rec = mainRecommendation {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(riskColor(rec.risk))
                                    .frame(width: 8, height: 8)
                                
                                Text(rec.risk.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Expand icon
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Statistics
                    HStack(spacing: 20) {
                        StatItem(icon: "doc.text.fill", title: "Файлов", value: "\(directory.fileCount)")
                        
                        if let lastModified = directory.lastModified {
                            let formatter = RelativeDateTimeFormatter()
                            formatter.unitsStyle = .short
                            let relativeDate = formatter.localizedString(for: lastModified, relativeTo: Date())
                            StatItem(icon: "clock.fill", title: "Изменено", value: relativeDate)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Recommendations
                    if let rec = mainRecommendation {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: rec.category.icon)
                                    .foregroundColor(categoryColor(rec.category))
                                
                                Text(rec.category.rawValue)
                                    .font(.headline)
                                
                                Spacer()
                                
                                if rec.isDeletable {
                                    Label("Можно удалить", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Label("Требует проверки", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Text(rec.reason)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Risk indicator
                            HStack(spacing: 8) {
                                Text("Уровень риска:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(riskColor(rec.risk))
                                        .frame(width: 10, height: 10)
                                    
                                    Text(rec.risk.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(riskColor(rec.risk))
                                }
                                
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Subdirectories if any
                    if !directory.subdirectories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Подкаталоги (\(directory.subdirectories.count))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            ForEach(directory.subdirectories.prefix(5)) { subdir in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    
                                    Text(subdir.displayName)
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text(subdir.formattedSize)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            if directory.subdirectories.count > 5 {
                                Text("и еще \(directory.subdirectories.count - 5)...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            showingSystemAnalysis = true
                        }) {
                            Label("Детальный анализ", systemImage: "chart.bar.doc.horizontal")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directory.path)
                        }) {
                            Label("Открыть в Finder", systemImage: "folder")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .padding(.bottom, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .cornerRadius(12)
                .padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .sheet(isPresented: $showingSystemAnalysis) {
            SystemAnalysisView(directory: directory)
        }
    }
    
    var rankColor: Color {
        switch index {
        case 1: return Color.red
        case 2: return Color.orange
        case 3: return Color.yellow
        default: return Color.blue
        }
    }
    
    func riskColor(_ risk: RiskLevel) -> Color {
        switch risk {
        case .safe: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    func categoryColor(_ category: CleanupCategory) -> Color {
        switch category {
        case .cache: return .blue
        case .logs: return .gray
        case .downloads: return .green
        case .duplicates: return .orange
        case .temporary: return .purple
        case .oldFiles: return .red
        case .applications: return .cyan
        case .other: return .secondary
        }
    }
}

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
    }
}



