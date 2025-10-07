import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var analyzer = StorageAnalyzer()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationSplitView {
            SidebarView(analyzer: analyzer)
        } detail: {
            TabView(selection: $selectedTab) {
                AnalysisView(analyzer: analyzer)
                    .tabItem {
                        Image(systemName: "chart.pie")
                        Text("Анализ")
                    }
                    .tag(0)
                
                CleanupView(analyzer: analyzer)
                    .tabItem {
                        Image(systemName: "trash.circle")
                        Text("Очистка")
                    }
                    .tag(1)
                
                DirectoryView(analyzer: analyzer)
                    .tabItem {
                        Image(systemName: "folder")
                        Text("Директории")
                    }
                    .tag(2)
                
                LogsView(analyzer: analyzer)
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("Логи")
                    }
                    .tag(3)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
    }
}

struct SidebarView: View {
    @ObservedObject var analyzer: StorageAnalyzer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Анализатор хранилища")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "externaldrive")
                        .foregroundColor(.blue)
                    Text("Общий размер диска")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: analyzer.analysisState.totalSize, countStyle: .file))
                        .fontWeight(.medium)
                }
                
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.red)
                    Text("Используется")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ByteCountFormatter.string(fromByteCount: analyzer.analysisState.usedSize, countStyle: .file))
                            .fontWeight(.medium)
                        if analyzer.analysisState.totalSize > 0 {
                            Text("\(Int(Double(analyzer.analysisState.usedSize) / Double(analyzer.analysisState.totalSize) * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                    Text("Свободно")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ByteCountFormatter.string(fromByteCount: analyzer.analysisState.freeSize, countStyle: .file))
                            .fontWeight(.medium)
                        if analyzer.analysisState.totalSize > 0 {
                            Text("\(Int(Double(analyzer.analysisState.freeSize) / Double(analyzer.analysisState.totalSize) * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.purple)
                    Text("Проанализировано")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: analyzer.analysisState.analyzedSize, countStyle: .file))
                        .fontWeight(.medium)
                }
                
                HStack {
                    Image(systemName: "percent")
                        .foregroundColor(.orange)
                    Text("Прогресс")
                    Spacer()
                    Text("\(Int(analyzer.analysisState.analyzedPercent))%")
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            VStack(spacing: 8) {
                if analyzer.analysisState.isAnalyzing {
                    Button("Остановить анализ") {
                        analyzer.cancelAnalysis()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                Button("Начать анализ") {
                    Task {
                        await analyzer.startAnalysis()
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                Button("Очистить логи") {
                    analyzer.analysisState.clearLogs()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical)
    }
}

struct AnalysisView: View {
    @ObservedObject var analyzer: StorageAnalyzer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Анализ хранилища")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if analyzer.analysisState.isAnalyzing {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Прогресс анализа:")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(analyzer.analysisState.analyzedPercent))%")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: analyzer.analysisState.analyzedPercent / 100.0)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    HStack {
                        Text("Проанализировано:")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: analyzer.analysisState.analyzedSize, countStyle: .file))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text("Анализируем: \(analyzer.analysisState.currentDirectory)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // График использования диска
            if !analyzer.analysisState.directories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Использование диска по директориям")
                        .font(.headline)
                    
                    Chart {
                        ForEach(Array(analyzer.analysisState.directories.values), id: \.path) { directory in
                            SectorMark(
                                angle: .value("Size", directory.size),
                                innerRadius: .ratio(0.4),
                                angularInset: 2
                            )
                            .foregroundStyle(by: .value("Directory", directory.displayName))
                        }
                    }
                    .frame(height: 300)
                }
            }
            
            // Список директорий
            if !analyzer.analysisState.directories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Детализация по директориям")
                        .font(.headline)
                    
                    List {
                        ForEach(Array(analyzer.analysisState.directories.values.sorted { $0.size > $1.size }), id: \.path) { directory in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(directory.displayName)
                                        .fontWeight(.medium)
                                    Text(directory.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text(directory.formattedSize)
                                        .fontWeight(.medium)
                                    Text("\(directory.fileCount) файлов")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct DirectoryView: View {
    @ObservedObject var analyzer: StorageAnalyzer
    @State private var selectedDirectory: DirectoryInfo?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Управление файлами")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if analyzer.analysisState.directories.isEmpty {
                Text("Запустите анализ для просмотра директорий")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(analyzer.analysisState.directories.values.sorted { $0.size > $1.size }), id: \.path) { directory in
                        DirectoryRowView(directory: directory, analyzer: analyzer)
                    }
                }
                .listStyle(.plain)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct DirectoryRowView: View {
    let directory: DirectoryInfo
    @ObservedObject var analyzer: StorageAnalyzer
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(directory.displayName)
                    .fontWeight(.medium)
                Text(directory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(directory.formattedSize)
                    .fontWeight(.medium)
                Text("\(directory.fileCount) файлов")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Удалить") {
                showingDeleteAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .alert("Удалить директорию?", isPresented: $showingDeleteAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    Task {
                        do {
                            try await analyzer.deleteDirectory(at: directory.path)
                        } catch {
                            analyzer.analysisState.addLog("❌ Ошибка удаления: \(error.localizedDescription)")
                        }
                    }
                }
            } message: {
                Text("Это действие нельзя отменить. Директория \(directory.displayName) будет удалена навсегда.")
            }
        }
        .padding(.vertical, 4)
    }
}

struct LogsView: View {
    @ObservedObject var analyzer: StorageAnalyzer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Логи анализа")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Очистить") {
                    analyzer.analysisState.clearLogs()
                }
                .buttonStyle(.bordered)
            }
            
            if analyzer.analysisState.logs.isEmpty {
                Text("Логи пусты")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(analyzer.analysisState.logs.enumerated()), id: \.offset) { index, log in
                            HStack(alignment: .top) {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                                
                                Text(log)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
