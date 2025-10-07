import Foundation
import SwiftUI

// MARK: - Storage Models
struct DirectoryInfo: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: Int64
    let fileCount: Int
    let subdirectories: [DirectoryInfo]
    let lastModified: Date?
    
    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct FileInfo: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: Int64
    let lastModified: Date?
    let isDirectory: Bool
    
    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct AnalysisProgress: Equatable {
    var isAnalyzing: Bool = false
    var currentDirectory: String = ""
    var totalSize: Int64 = 0
    var analyzedSize: Int64 = 0
    var analyzedPercent: Double = 0
    var directories: [String: DirectoryInfo] = [:]
    var currentFiles: [FileInfo] = []
    var logs: [String] = []
    var error: String? = nil
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var formattedAnalyzedSize: String {
        ByteCountFormatter.string(fromByteCount: analyzedSize, countStyle: .file)
    }
}

// MARK: - Analysis State
@MainActor
class StorageAnalysisState: ObservableObject {
    @Published var totalSize: Int64 = 0
    @Published var usedSize: Int64 = 0
    @Published var freeSize: Int64 = 0
    @Published var analyzedSize: Int64 = 0
    @Published var analyzedPercent: Double = 0
    @Published var isAnalyzing = false
    @Published var currentDirectory: String = ""
    @Published var directories: [String: DirectoryInfo] = [:]
    @Published var logs: [String] = []
    @Published var selectedDirectory: DirectoryInfo?
    
    func updateProgress(_ newProgress: AnalysisProgress) {
        print("🔄 StorageAnalysisState.updateProgress: totalSize=\(newProgress.totalSize), analyzedSize=\(newProgress.analyzedSize), percent=\(newProgress.analyzedPercent)")
        
        totalSize = newProgress.totalSize
        analyzedSize = newProgress.analyzedSize
        analyzedPercent = newProgress.analyzedPercent
        isAnalyzing = newProgress.isAnalyzing
        currentDirectory = newProgress.currentDirectory
        directories = newProgress.directories
        logs = newProgress.logs
        
        print("🔄 UI обновлен: totalSize=\(self.totalSize), analyzedSize=\(self.analyzedSize), formattedTotalSize=\(ByteCountFormatter.string(fromByteCount: self.totalSize, countStyle: .file))")
        
        // Принудительно уведомляем об изменениях
        objectWillChange.send()
    }
    
    func addLog(_ message: String) {
        logs.append(message)
        // Ограничиваем количество логов
        if logs.count > 100 {
            logs.removeFirst(logs.count - 100)
        }
        objectWillChange.send()
    }
    
    func clearLogs() {
        logs.removeAll()
        objectWillChange.send()
    }
}
