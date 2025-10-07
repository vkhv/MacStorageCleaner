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
                            StatItem(icon: "clock.fill", title: "Изменено", value: formatRelativeDate(lastModified))
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
                            
                            // Risk indicator and actions
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("Уровень риска:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Circle()
                                        .fill(riskColor(rec.risk))
                                        .frame(width: 10, height: 10)
                                    
                                    Text(rec.risk.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(riskColor(rec.risk))
                                }
                                
                                Spacer()
                                
                                // Action buttons
                                if rec.isDeletable {
                                    Button(action: {
                                        deleteDirectory(directory.path)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash")
                                            Text("Удалить")
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundColor(.red)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: {
                                        openInFinder(directory.path)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "folder")
                                            Text("Открыть")
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    Button(action: {
                                        openInFinder(directory.path)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "folder")
                                            Text("Проверить")
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
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
                            
                            // Показываем топ-5 подкаталогов с рекомендациями
                            let topSubdirs = directory.subdirectories
                                .sorted { $0.size > $1.size }
                                .prefix(5)
                            
                            ForEach(Array(topSubdirs.enumerated()), id: \.element.id) { subIndex, subdir in
                                SubdirectoryCard(
                                    subdirectory: subdir,
                                    index: subIndex + 1
                                )
                                .padding(.horizontal, 12)
                            }
                            
                            if directory.subdirectories.count > 5 {
                                Text("и еще \(directory.subdirectories.count - 5) подкаталогов...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .cornerRadius(12)
                .padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
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
    
    func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func deleteDirectory(_ path: String) {
        // Проверяем права доступа
        if !FileManager.default.isWritableFile(atPath: path) {
            let alert = NSAlert()
            alert.messageText = "Требуются права администратора"
            alert.informativeText = "Для удаления этой директории требуются права администратора.\n\nПуть: \(path)\n\nОткройте Finder и удалите через Корзину или используйте Терминал с sudo."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Открыть в Finder")
            alert.addButton(withTitle: "Отмена")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openInFinder(path)
            }
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Подтверждение удаления"
        alert.informativeText = "Вы уверены, что хотите удалить:\n\n\(path)\n\nРазмер: \(directory.formattedSize)\n\nЭто действие нельзя отменить!"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Удалить")
        alert.addButton(withTitle: "Отмена")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            do {
                // Пробуем удалить через Trash для безопасности
                if #available(macOS 10.8, *) {
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                    
                    let successAlert = NSAlert()
                    successAlert.messageText = "Перемещено в Корзину"
                    successAlert.informativeText = "Директория \(path) была перемещена в Корзину.\n\nРазмер: \(directory.formattedSize)\n\nВы можете восстановить файлы из Корзины, если понадобится."
                    successAlert.alertStyle = .informational
                    successAlert.runModal()
                } else {
                    try FileManager.default.removeItem(atPath: path)
                    
                    let successAlert = NSAlert()
                    successAlert.messageText = "Успешно удалено"
                    successAlert.informativeText = "Директория \(path) была удалена.\n\nОсвобождено: \(directory.formattedSize)"
                    successAlert.alertStyle = .informational
                    successAlert.runModal()
                }
            } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Ошибка удаления"
                errorAlert.informativeText = "Не удалось удалить \(path):\n\n\(error.localizedDescription)\n\nПопробуйте:\n1. Открыть в Finder и удалить вручную\n2. Проверить права доступа\n3. Закрыть приложения, использующие эти файлы"
                errorAlert.alertStyle = .critical
                errorAlert.addButton(withTitle: "OK")
                errorAlert.addButton(withTitle: "Открыть в Finder")
                
                let response = errorAlert.runModal()
                if response == .alertSecondButtonReturn {
                    openInFinder(path)
                }
            }
        }
    }
    
    func openInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
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

// MARK: - Subdirectory Card with Recommendations
struct SubdirectoryCard: View {
    let subdirectory: DirectoryInfo
    let index: Int
    @State private var isExpanded = false
    
    var recommendations: [CleanupRecommendation] {
        CleanupAnalyzer.analyzeDirectory(subdirectory)
    }
    
    var mainRecommendation: CleanupRecommendation? {
        recommendations.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main subdirectory row
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 8) {
                    // Index and icon
                    HStack(spacing: 4) {
                        Text("\(index).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        
                        Image(systemName: "folder.fill")
                            .foregroundColor(iconColor)
                            .font(.caption)
                    }
                    
                    // Name and path
                    VStack(alignment: .leading, spacing: 2) {
                        Text(subdirectory.displayName)
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        if let rec = mainRecommendation {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(riskColor(rec.risk))
                                    .frame(width: 6, height: 6)
                                
                                Text(rec.category.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Size and status
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(subdirectory.formattedSize)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        if let rec = mainRecommendation {
                            if rec.isDeletable {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption2)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption2)
                            }
                        }
                    }
                    
                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded recommendation
            if isExpanded, let rec = mainRecommendation {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 8)
                    
                    // Recommendation details
                    HStack(spacing: 8) {
                        Image(systemName: rec.category.icon)
                            .foregroundColor(categoryColor(rec.category))
                            .font(.caption)
                        
                        Text(rec.reason)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    
                    // Risk level and actions
                    HStack(spacing: 6) {
                        Circle()
                            .fill(riskColor(rec.risk))
                            .frame(width: 8, height: 8)
                        
                        Text(rec.risk.rawValue)
                            .font(.caption2)
                            .foregroundColor(riskColor(rec.risk))
                        
                        Spacer()
                        
                        Text("\(subdirectory.fileCount) файлов")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    
                    // Action buttons for subdirectory
                    HStack(spacing: 8) {
                        if rec.isDeletable {
                            Button(action: {
                                deleteSubdirectory(subdirectory.path)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "trash")
                                    Text("Удалить")
                                }
                                .font(.caption2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Button(action: {
                            openInFinder(subdirectory.path)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "folder")
                                Text(rec.isDeletable ? "Открыть" : "Проверить")
                            }
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .cornerRadius(8)
                .padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
    }
    
    var iconColor: Color {
        guard let rec = mainRecommendation else { return .blue }
        return rec.isDeletable ? .green : .orange
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
    
    func deleteSubdirectory(_ path: String) {
        // Проверяем права доступа
        if !FileManager.default.isWritableFile(atPath: path) {
            let alert = NSAlert()
            alert.messageText = "Требуются права администратора"
            alert.informativeText = "Для удаления этой директории требуются права администратора.\n\nПуть: \(path)\n\nОткройте Finder и удалите через Корзину."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Открыть в Finder")
            alert.addButton(withTitle: "Отмена")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openInFinder(path)
            }
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Подтверждение удаления"
        alert.informativeText = "Вы уверены, что хотите удалить:\n\n\(path)\n\nРазмер: \(subdirectory.formattedSize)\n\nЭто действие нельзя отменить!"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Удалить")
        alert.addButton(withTitle: "Отмена")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            do {
                // Удаляем через Trash для безопасности
                if #available(macOS 10.8, *) {
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                    
                    let successAlert = NSAlert()
                    successAlert.messageText = "Перемещено в Корзину"
                    successAlert.informativeText = "Директория \(path) была перемещена в Корзину.\n\nРазмер: \(subdirectory.formattedSize)\n\nВы можете восстановить файлы из Корзины."
                    successAlert.alertStyle = .informational
                    successAlert.runModal()
                } else {
                    try FileManager.default.removeItem(atPath: path)
                    
                    let successAlert = NSAlert()
                    successAlert.messageText = "Успешно удалено"
                    successAlert.informativeText = "Директория \(path) была удалена.\n\nОсвобождено: \(subdirectory.formattedSize)"
                    successAlert.alertStyle = .informational
                    successAlert.runModal()
                }
            } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Ошибка удаления"
                errorAlert.informativeText = "Не удалось удалить \(path):\n\n\(error.localizedDescription)\n\nПопробуйте открыть в Finder и удалить вручную."
                errorAlert.alertStyle = .critical
                errorAlert.addButton(withTitle: "OK")
                errorAlert.addButton(withTitle: "Открыть в Finder")
                
                let response = errorAlert.runModal()
                if response == .alertSecondButtonReturn {
                    openInFinder(path)
                }
            }
        }
    }
    
    func openInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
