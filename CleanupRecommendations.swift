import Foundation

// MARK: - Cleanup Recommendations
struct CleanupRecommendation: Identifiable {
    let id = UUID()
    let path: String
    let size: Int64
    let isDeletable: Bool
    let reason: String
    let category: CleanupCategory
    let risk: RiskLevel
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum CleanupCategory: String, CaseIterable {
    case cache = "Кеш"
    case logs = "Логи"
    case downloads = "Загрузки"
    case duplicates = "Дубликаты"
    case temporary = "Временные файлы"
    case oldFiles = "Старые файлы"
    case applications = "Приложения"
    case other = "Другое"
    
    var icon: String {
        switch self {
        case .cache: return "arrow.3.trianglepath"
        case .logs: return "doc.text"
        case .downloads: return "arrow.down.circle"
        case .duplicates: return "doc.on.doc"
        case .temporary: return "clock"
        case .oldFiles: return "calendar"
        case .applications: return "app"
        case .other: return "folder"
        }
    }
    
    var color: String {
        switch self {
        case .cache: return "blue"
        case .logs: return "gray"
        case .downloads: return "green"
        case .duplicates: return "orange"
        case .temporary: return "purple"
        case .oldFiles: return "red"
        case .applications: return "cyan"
        case .other: return "secondary"
        }
    }
}

enum RiskLevel: String {
    case safe = "Безопасно"
    case low = "Низкий риск"
    case medium = "Средний риск"
    case high = "Высокий риск"
    case critical = "Не удалять!"
    
    var color: String {
        switch self {
        case .safe: return "green"
        case .low: return "blue"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Cleanup Analyzer
class CleanupAnalyzer {
    static func analyzeDirectory(_ dirInfo: DirectoryInfo) -> [CleanupRecommendation] {
        var recommendations: [CleanupRecommendation] = []
        let path = dirInfo.path
        let pathLower = path.lowercased()
        
        // Кеш-файлы
        if pathLower.contains("/caches") || pathLower.contains("/cache") {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: true,
                reason: "Кеш-файлы можно безопасно удалить. Приложения создадут их заново при необходимости.",
                category: .cache,
                risk: .safe
            ))
        }
        
        // Логи
        else if pathLower.contains("/logs") || pathLower.hasSuffix(".log") {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: true,
                reason: "Старые логи можно удалить для освобождения места.",
                category: .logs,
                risk: .safe
            ))
        }
        
        // Загрузки
        else if pathLower.contains("/downloads") {
            let isOld = isOlderThan(dirInfo, days: 30)
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: isOld,
                reason: isOld ? "Старые загрузки (>30 дней). Проверьте перед удалением." : "Недавние загрузки. Проверьте вручную.",
                category: .downloads,
                risk: isOld ? .low : .medium
            ))
        }
        
        // Временные файлы
        else if pathLower.contains("/tmp") || pathLower.contains("/temp") || pathLower.contains("/.trash") {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: true,
                reason: "Временные файлы и корзина могут быть удалены.",
                category: .temporary,
                risk: .safe
            ))
        }
        
        // Xcode DerivedData
        else if pathLower.contains("/deriveddata") {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: true,
                reason: "Xcode DerivedData можно безопасно удалить. Xcode пересоберет при необходимости.",
                category: .cache,
                risk: .safe
            ))
        }
        
        // node_modules
        else if pathLower.contains("/node_modules") {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: true,
                reason: "node_modules можно удалить и восстановить через 'npm install'.",
                category: .cache,
                risk: .low
            ))
        }
        
        // Pods (CocoaPods)
        else if pathLower.contains("/pods") && !pathLower.contains("podcast") {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: true,
                reason: "CocoaPods можно удалить и восстановить через 'pod install'.",
                category: .cache,
                risk: .low
            ))
        }
        
        // Simulators
        else if pathLower.contains("/devices") && pathLower.contains("/coresimulator") {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: true,
                reason: "Старые данные симуляторов iOS. Можно удалить через Xcode.",
                category: .cache,
                risk: .safe
            ))
        }
        
        // Safari
        else if pathLower.contains("/safari") && (pathLower.contains("/cache") || pathLower.contains("/history")) {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: true,
                reason: "История и кеш Safari можно очистить.",
                category: .cache,
                risk: .low
            ))
        }
        
        // Mail Attachments
        else if pathLower.contains("/mail") && pathLower.contains("/attachments") {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: false,
                reason: "Вложения почты. Проверьте вручную перед удалением.",
                category: .other,
                risk: .high
            ))
        }
        
        // Application Support (осторожно)
        else if pathLower.contains("/application support") {
            let isSafe = pathLower.contains("/cache") || pathLower.contains("/logs")
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: isSafe,
                reason: isSafe ? "Кеш приложений можно удалить." : "Данные приложений. Удаление может привести к потере настроек.",
                category: isSafe ? .cache : .other,
                risk: isSafe ? .safe : .high
            ))
        }
        
        // System directories (не трогать!)
        else if pathLower.hasPrefix("/system") || pathLower.hasPrefix("/library") || pathLower.hasPrefix("/usr") {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: false,
                reason: "Системные файлы. НЕ УДАЛЯЙТЕ!",
                category: .other,
                risk: .critical
            ))
        }
        
        // Desktop/Documents/Pictures (только предупреждение)
        else if pathLower.contains("/desktop") || pathLower.contains("/documents") || pathLower.contains("/pictures") {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: false,
                reason: "Личные файлы. Управляйте вручную.",
                category: .other,
                risk: .critical
            ))
        }
        
        // Большие одиночные файлы (>1GB)
        else if dirInfo.fileCount == 1 && dirInfo.size > 1_000_000_000 {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: false,
                reason: "Большой файл (>1GB). Проверьте необходимость хранения.",
                category: .oldFiles,
                risk: .medium
            ))
        }
        
        // Остальное - проверить вручную
        else {
            recommendations.append(CleanupRecommendation(
                path: path,
                size: dirInfo.size,
                isDeletable: false,
                reason: "Проверьте содержимое вручную.",
                category: .other,
                risk: .medium
            ))
        }
        
        return recommendations
    }
    
    private static func isOlderThan(_ dirInfo: DirectoryInfo, days: Int) -> Bool {
        guard let lastModified = dirInfo.lastModified else { return false }
        let threshold = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        return lastModified < threshold
    }
    
    static func getTopDirectories(_ directories: [String: DirectoryInfo], count: Int = 10) -> [DirectoryInfo] {
        return directories.values
            .sorted { $0.size > $1.size }
            .prefix(count)
            .map { $0 }
    }
}

