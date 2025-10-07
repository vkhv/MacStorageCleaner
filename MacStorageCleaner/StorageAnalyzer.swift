import Foundation
import SwiftUI
import Combine

@MainActor
class StorageAnalyzer: ObservableObject {
    @Published var analysisState = StorageAnalysisState()
    private var isCancelled = false
    private let fileManager = FileManager.default
    private var cancellable: AnyCancellable?
    
    // Ограничения для предотвращения переполнения памяти
    private let maxDepth = 4  // Увеличиваем глубину для более полного анализа
    private let batchSize = 100  // Увеличиваем размер батча для скорости
    private let maxLogs = 300  // Увеличиваем лимит логов
    
    init() {
        // Подписываемся на изменения analysisState и переиздаем их
        cancellable = analysisState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
    
    func startAnalysis() async {
        isCancelled = false
        analysisState.isAnalyzing = true
        analysisState.clearLogs()
        
        // Сбрасываем состояние перед началом
        analysisState.analyzedSize = 0
        analysisState.analyzedPercent = 0
        analysisState.directories = [:]
        analysisState.currentDirectory = ""
        
        analysisState.addLog("🚀 Начинаем анализ диска...")
        
        do {
            // Получаем информацию о диске
            let diskInfo = try await getDiskInfo()
            
            // Обновляем информацию о диске
            analysisState.totalSize = diskInfo.totalSize
            analysisState.usedSize = diskInfo.usedSize
            analysisState.freeSize = diskInfo.availableSize
            
            let usedPercent = diskInfo.totalSize > 0 ? Double(diskInfo.usedSize) / Double(diskInfo.totalSize) * 100 : 0
            
            analysisState.addLog("💾 Общий размер диска: \(ByteCountFormatter.string(fromByteCount: diskInfo.totalSize, countStyle: .file))")
            analysisState.addLog("📊 Используется: \(ByteCountFormatter.string(fromByteCount: diskInfo.usedSize, countStyle: .file)) (\(String(format: "%.1f", usedPercent))%)")
            analysisState.addLog("✅ Свободно: \(ByteCountFormatter.string(fromByteCount: diskInfo.availableSize, countStyle: .file))")
            
            // Используем usedSize для расчёта прогресса вместо totalSize
            analysisState.addLog("🎯 Будем анализировать относительно используемого пространства: \(ByteCountFormatter.string(fromByteCount: diskInfo.usedSize, countStyle: .file))")
            
            // Анализируем основные директории диска
            let userHome = NSHomeDirectory()
            let mainDirs = [
                // Пользовательские директории (глубокий анализ)
                "\(userHome)/Desktop",
                "\(userHome)/Documents", 
                "\(userHome)/Downloads",
                "\(userHome)/Pictures",
                "\(userHome)/Movies",
                "\(userHome)/Music",
                "\(userHome)/Library/Caches",
                "\(userHome)/Library/Application Support",
                "\(userHome)/Library/Logs",
                "\(userHome)/Library/Containers",
                "\(userHome)/Library/Safari",
                "\(userHome)/Library/Mail",
                "\(userHome)/Applications",
                // Системные директории (только поверхностный анализ - depth 1)
                "/Applications",
                "/Library",
                "/usr",
                "/opt",
                "/private/var",
                "/Users/Shared"
            ]
            
            for dir in mainDirs {
                if isCancelled { break }
                
                guard fileManager.fileExists(atPath: dir) else {
                    analysisState.addLog("⚠️ Директория не существует: \(dir)")
                    continue
                }
                
                // Обновляем текущую директорию
                analysisState.currentDirectory = dir
                let startTime = Date()
                analysisState.addLog("📁 Анализируем директорию: \(dir)")
                
                // Определяем глубину анализа: для системных директорий - только 1 уровень
                let isSystemDir = dir.hasPrefix("/") && !dir.hasPrefix(userHome)
                let maxDepthForDir = isSystemDir ? 1 : maxDepth
                
                do {
                    // Создаем Task с тайм-аутом
                    let dirInfo = try await withThrowingTaskGroup(of: DirectoryInfo?.self) { group in
                        group.addTask {
                            try await self.analyzeDirectory(at: dir, depth: 0, maxDepth: maxDepthForDir)
                        }
                        
                        // Добавляем тайм-аут: 60 секунд для системных, 120 для пользовательских
                        let timeout: UInt64 = isSystemDir ? 60_000_000_000 : 120_000_000_000
                        group.addTask {
                            try await Task.sleep(nanoseconds: timeout)
                            return nil
                        }
                        
                        // Берем первый завершившийся результат
                        if let result = try await group.next() {
                            group.cancelAll()
                            return result
                        }
                        
                        return nil
                    }
                    
                    let elapsed = Date().timeIntervalSince(startTime)
                    
                    if let dirInfo = dirInfo {
                        analysisState.addLog("⏱️ Анализ \(dir) занял \(String(format: "%.1f", elapsed)) сек.")
                        
                        // Сохраняем информацию о директории (прогресс уже обновлен внутри analyzeDirectory)
                        analysisState.directories[dir] = dirInfo

                        // Отладочная информация
                        analysisState.addLog("🔧 DEBUG: analyzedSize = \(analysisState.analyzedSize), percent = \(analysisState.analyzedPercent)%")
                        analysisState.addLog("✅ \(dir): \(dirInfo.formattedSize) (\(dirInfo.fileCount) файлов)")
                    } else {
                        // Тайм-аут или директория недоступна
                        analysisState.addLog("⏱️ ТАЙМ-АУТ: \(dir) превысил лимит времени (\(String(format: "%.1f", elapsed)) сек.)")
                        
                        let emptyDirInfo = DirectoryInfo(
                            path: dir,
                            size: 0,
                            fileCount: 0,
                            subdirectories: [],
                            lastModified: nil
                        )

                        analysisState.directories[dir] = emptyDirInfo
                        analysisState.addLog("⚠️ \(dir): пропущена из-за тайм-аута")
                    }
                } catch {
                    analysisState.addLog("⚠️ Ошибка при анализе \(dir): \(error.localizedDescription)")
                }
                
                // Задержка между директориями
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            
            if !isCancelled {
                analysisState.addLog("✅ Анализ завершен успешно")
                analysisState.isAnalyzing = false
            }
            
        } catch {
            analysisState.addLog("❌ Критическая ошибка: \(error.localizedDescription)")
            analysisState.isAnalyzing = false
        }
    }
    
    func cancelAnalysis() {
        isCancelled = true
        analysisState.addLog("⏹️ Анализ отменен пользователем")
        var progress = AnalysisProgress()
        progress.totalSize = analysisState.totalSize
        progress.analyzedSize = analysisState.analyzedSize
        progress.analyzedPercent = analysisState.analyzedPercent
        progress.isAnalyzing = analysisState.isAnalyzing
        progress.currentDirectory = analysisState.currentDirectory
        progress.directories = analysisState.directories
        progress.logs = analysisState.logs
        progress.isAnalyzing = false
        analysisState.updateProgress(progress)
    }
    
    private func getDiskInfo() async throws -> (totalSize: Int64, usedSize: Int64, availableSize: Int64) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let fileManager = FileManager.default
                    let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
                    let totalSize = attributes[.systemSize] as? Int64 ?? 0
                    let freeSize = attributes[.systemFreeSize] as? Int64 ?? 0
                    let usedSize = totalSize - freeSize
                    
                    continuation.resume(returning: (totalSize: totalSize, usedSize: usedSize, availableSize: freeSize))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func analyzeDirectory(at path: String, depth: Int, maxDepth: Int? = nil) async throws -> DirectoryInfo? {
        // Используем переданный maxDepth или дефолтный
        let effectiveMaxDepth = maxDepth ?? self.maxDepth
        
        // Ограничиваем глубину рекурсии
        guard depth < effectiveMaxDepth else {
            analysisState.addLog("⚠️ Пропускаем глубокую директорию: \(path) (глубина \(depth))")
            return DirectoryInfo(path: path, size: 0, fileCount: 0, subdirectories: [], lastModified: nil)
        }
        
        let url = URL(fileURLWithPath: path)
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return DirectoryInfo(path: path, size: 0, fileCount: 0, subdirectories: [], lastModified: nil)
        }
        
        var totalSize: Int64 = 0
        var fileCount = 0
        var subdirectories: [DirectoryInfo] = []
        var currentFiles: [FileInfo] = []
        
        // Обрабатываем файлы батчами
        var batch: [URL] = []
        
        // Собираем все URL в массив для безопасной обработки
        var allURLs: [URL] = []
        let maxFilesToScan = effectiveMaxDepth == 1 ? 10000 : 100000  // Увеличиваем лимиты для более полного анализа
        
        for case let fileURL as URL in enumerator {
            if allURLs.count >= maxFilesToScan { break }
            allURLs.append(fileURL)
        }
        
        if allURLs.count >= maxFilesToScan {
            analysisState.addLog("⚠️ Ограничение файлов достигнуто для: \(path) (\(maxFilesToScan) файлов)")
        }
        
        for fileURL in allURLs {
            if isCancelled { break }
            
            batch.append(fileURL)
            
            if batch.count >= batchSize {
                let (batchSizeResult, batchFileCount, batchFiles) = try await processBatch(batch, resourceKeys: resourceKeys)
                totalSize += batchSizeResult
                fileCount += batchFileCount
                currentFiles.append(contentsOf: batchFiles)
                
                // Обновляем прогресс после каждого батча (напрямую, без промежуточного объекта)
                analysisState.analyzedSize += batchSizeResult
                // Считаем процент от используемого пространства, а не от общего размера диска
                if analysisState.usedSize > 0 {
                    analysisState.analyzedPercent = Double(analysisState.analyzedSize) / Double(analysisState.usedSize) * 100
                }
                
                if fileCount % (batchSize * 2) == 0 {
                    analysisState.addLog("📊 Обработано файлов в \(path): \(fileCount) (\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))")
                }
                
                batch.removeAll()
                
                // Отдаем управление UI для предотвращения зависания
                await Task.yield()
                
                // Задержка между батчами
                try await Task.sleep(nanoseconds: 10_000_000) // 0.01 секунды
            }
        }
        
        // Обрабатываем оставшиеся файлы
        if !batch.isEmpty {
            let (batchSizeResult, batchFileCount, batchFiles) = try await processBatch(batch, resourceKeys: resourceKeys)
            totalSize += batchSizeResult
            fileCount += batchFileCount
            currentFiles.append(contentsOf: batchFiles)
            
            // Обновляем финальный прогресс
            analysisState.analyzedSize += batchSizeResult
            // Считаем процент от используемого пространства, а не от общего размера диска
            if analysisState.usedSize > 0 {
                analysisState.analyzedPercent = Double(analysisState.analyzedSize) / Double(analysisState.usedSize) * 100
            }
        }
        
        return DirectoryInfo(
            path: path,
            size: totalSize,
            fileCount: fileCount,
            subdirectories: subdirectories,
            lastModified: nil
        )
    }
    
    private func processBatch(_ urls: [URL], resourceKeys: [URLResourceKey]) async throws -> (size: Int64, fileCount: Int, files: [FileInfo]) {
        var totalSize: Int64 = 0
        var fileCount = 0
        var files: [FileInfo] = []
        
        for url in urls {
            if isCancelled { break }
            
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    // Для директорий получаем размер рекурсивно (с ограничением)
                    if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                        var directoryURLs: [URL] = []
                        for case let fileURL as URL in enumerator {
                            directoryURLs.append(fileURL)
                        }
                        
                        for fileURL in directoryURLs {
                            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                                totalSize += Int64(fileSize)
                                fileCount += 1
                            }
                        }
                    }
                } else {
                    // Для файлов
                    if let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                        fileCount += 1
                        
                        files.append(FileInfo(
                            path: url.path,
                            size: Int64(fileSize),
                            lastModified: resourceValues.contentModificationDate,
                            isDirectory: false
                        ))
                    }
                }
            } catch {
                // Игнорируем ошибки доступа к файлам
                continue
            }
        }
        
        return (totalSize, fileCount, files)
    }
    
    func deleteFile(at path: String) async throws {
        try fileManager.removeItem(atPath: path)
        analysisState.addLog("🗑️ Удален файл: \(path)")
    }
    
    func deleteDirectory(at path: String) async throws {
        try fileManager.removeItem(atPath: path)
        analysisState.addLog("🗑️ Удалена директория: \(path)")
    }
}
