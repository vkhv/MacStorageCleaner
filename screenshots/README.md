# Screenshots

Please add the following screenshots to this directory:

## Required Screenshots

### 1. main-view.png
Main interface showing:
- Sidebar with disk statistics (Total, Used, Free)
- Progress indicator
- Start/Stop buttons
- Current analysis status

**How to capture:**
1. Open MacStorageCleaner app
2. Make sure sidebar is visible
3. Press `Cmd + Shift + 4` and select the main window
4. Save as `main-view.png`

### 2. analysis-results.png
Analysis results view showing:
- Interactive pie chart with directory colors
- Legend with directory names
- Detailed directory list with sizes and file counts

**How to capture:**
1. Complete an analysis
2. Switch to "Анализ" tab
3. Press `Cmd + Shift + 4` and select the window
4. Save as `analysis-results.png`

### 3. logs-view.png
Logs view showing:
- Real-time log messages
- Progress updates
- Directory analysis status
- File counts and sizes

**How to capture:**
1. During or after analysis
2. Switch to "Логи" tab
3. Press `Cmd + Shift + 4` and select the window
4. Save as `logs-view.png`

## Screenshot Guidelines

- **Format:** PNG
- **Size:** Full window capture (recommended ~1400x900px or larger)
- **Background:** Default macOS background or clean desktop
- **Theme:** Dark mode preferred for consistency
- **Quality:** Retina quality (@2x) if possible

## Adding Screenshots

After capturing the screenshots, place them in this directory:
```
MacStorageCleaner/
└── screenshots/
    ├── main-view.png
    ├── analysis-results.png
    └── logs-view.png
```

Then commit and push:
```bash
git add screenshots/*.png
git commit -m "docs: Add application screenshots"
git push origin main
```



