# MacStorageCleaner 🧹

Native macOS application for analyzing disk storage usage with real-time progress tracking and beautiful visualizations.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-green.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

## ✨ Features

- 📊 **Real-time Progress Tracking** - Watch your disk analysis progress in real-time with percentage updates
- 💾 **Disk Usage Statistics** - See total, used, and free space at a glance
- 🎯 **Smart Analysis** - Deep analysis for user directories (4 levels) and shallow analysis for system directories (1 level)
- 📈 **Interactive Charts** - Beautiful pie charts showing directory size distribution
- ⚡ **Memory Efficient** - Batch processing with async/await for smooth performance
- 🛡️ **Safe & Reliable** - Timeout mechanisms prevent hanging on large directories
- 📝 **Detailed Logging** - Track analysis progress with file counts and sizes
- 🎨 **Modern UI** - Clean SwiftUI interface with dark mode support

## 🖼️ Screenshots

### Main Analysis View
The main interface shows disk usage statistics, analysis progress, and interactive controls.

![Main View](screenshots/main-view.png)

*Features sidebar with disk statistics, real-time progress bar, and control buttons*

### Analysis Results
View detailed breakdown of directory sizes with interactive pie chart visualization.

![Analysis Results](screenshots/analysis-results.png)

*Interactive pie chart showing directory size distribution and detailed file counts*

### Live Logging
Monitor the analysis process in real-time with detailed logs.

![Live Logs](screenshots/logs-view.png)

*Real-time logging shows current directory being analyzed, file counts, and any warnings*

## 🚀 Getting Started

### Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Installation

1. Clone the repository:
```bash
git clone https://github.com/vkhv/MacStorageCleaner.git
cd MacStorageCleaner
```

2. Open the project in Xcode:
```bash
open MacStorageCleaner.xcodeproj
```

3. Build and run the project:
   - Press `Cmd + R` or click the Run button in Xcode
   - The app will request necessary permissions to access your files

### Building from Source

```bash
xcodebuild -project MacStorageCleaner.xcodeproj \
           -scheme MacStorageCleaner \
           -configuration Release \
           build
```

The compiled app will be located in:
```
~/Library/Developer/Xcode/DerivedData/MacStorageCleaner-.../Build/Products/Release/
```

## 🎯 How It Works

### Analysis Algorithm

1. **Disk Info Retrieval** - Gets total, used, and free space from the file system
2. **Directory Scanning** - Analyzes specified directories with configurable depth
3. **Batch Processing** - Processes files in batches (100 files per batch) for memory efficiency
4. **Progress Updates** - Updates UI after each batch with size and percentage
5. **Timeout Protection** - Applies timeouts (60s for system, 120s for user directories)

### Analyzed Directories

**User Directories (Deep Analysis - 4 levels):**
- Desktop, Documents, Downloads
- Pictures, Movies, Music
- Library/Caches, Library/Application Support, Library/Logs
- Library/Containers, Library/Safari, Library/Mail
- Applications

**System Directories (Shallow Analysis - 1 level):**
- /Applications
- /Library
- /usr, /opt
- /private/var
- /Users/Shared

## 💡 Technical Highlights

### Performance Optimizations

- **Async/await** - Modern Swift concurrency for non-blocking operations
- **Task.yield()** - Prevents UI freezing during heavy processing
- **Batch Processing** - Limits memory usage with configurable batch sizes
- **Smart Limits** - Different scan limits for system (10K files) vs user directories (100K files)
- **Combine Framework** - Reactive state updates for real-time UI synchronization

### Architecture

```
MacStorageCleaner/
├── StorageAnalyzer.swift      # Core analysis engine with async processing
├── StorageModel.swift         # Data models (DirectoryInfo, FileInfo, State)
├── ContentView.swift          # SwiftUI views (Sidebar, Charts, Logs)
├── MacStorageCleanerApp.swift # App entry point
└── Assets.xcassets/           # App icons and resources
```

### Key Components

- **StorageAnalyzer** - Main analysis engine with timeout handling
- **StorageAnalysisState** - Observable state with @Published properties
- **DirectoryInfo** - Recursive directory structure with size calculations
- **FileInfo** - Individual file metadata

## 🔧 Configuration

Adjust analysis parameters in `StorageAnalyzer.swift`:

```swift
private let maxDepth = 4        // Maximum recursion depth
private let batchSize = 100     // Files per batch
private let maxLogs = 300       // Maximum log entries
```

Timeout settings:
```swift
let timeout: UInt64 = isSystemDir ? 60_000_000_000 : 120_000_000_000
```

## 📊 Performance

- **Memory Usage** - ~200-300 MB during analysis
- **Analysis Speed** - ~10-15 GB/minute on SSD
- **UI Responsiveness** - Smooth updates with <16ms frame time

## 🛠️ Development

### Running Tests

```bash
xcodebuild test -project MacStorageCleaner.xcodeproj \
                -scheme MacStorageCleaner \
                -destination 'platform=macOS'
```

### Debug Mode

Enable verbose logging by uncommenting debug statements in `StorageAnalyzer.swift`:

```swift
analysisState.addLog("🔧 DEBUG: analyzedSize = \(analysisState.analyzedSize)")
```

## 🐛 Known Limitations

- Some system directories may require additional permissions
- Very large directories (>1M files) may trigger timeouts
- Progress calculation is based on used space, not total files

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Uses Swift's modern concurrency features
- Inspired by disk analysis tools like DaisyDisk and GrandPerspective

## 📧 Contact

- GitHub: [@vkhv](https://github.com/vkhv)
- Repository: [MacStorageCleaner](https://github.com/vkhv/MacStorageCleaner)

---

**Made with ❤️ for macOS**

