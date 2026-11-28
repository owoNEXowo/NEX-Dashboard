# NEX Dashboard documentation

Free open-source Windows PowerShell dashboard.

- [Installation](#installation)
- [Navigation](#navigation)
- [Monitoring](#monitoring)
- [Personalization](#personalization)
- [Updates and troubleshooting](#updates-and-troubleshooting)
- [Reporting issues](#reporting-issues)

## Installation
Download EasyInstall from the [official releases](https://github.com/owoNEXowo/NEX-Dashboard/releases), extract the archive and run Install.cmd. Review setup prompts. Windows 11 / PowerShell 5.1 is the primary target.

## Navigation
Run dashboard in PowerShell. Use arrow keys, Enter, Tab, mouse, Esc and Ctrl+K for section search. F1 opens contextual help.

## Monitoring
System Monitor displays available CPU, GPU, memory, storage and network metrics. Processes shows CPU, RAM and GPU, not per-process network/disk speed. Network includes optional Ookla Speedtest; first use needs consent. System Health reports available Windows health signals, not a comprehensive hardware test.

## Editor and file management
Open supported text/code files from File Explorer. Use the clickable path segments or P to enter a path. Rename previews preserve extensions. In the editor, Ctrl+O opens a tab, Ctrl+F searches, Ctrl+S/F2 saves, Ctrl+Z/Ctrl+Y undo/redo, and Tab accepts a visible inline completion. Ctrl+plus/minus changes terminal zoom; Ctrl+0 resets it. Windows integration is optional (F7 in File Explorer); it does not set default applications.

## Benchmark Center and large files
Select a CPU, RAM or GPU workload, duration and (where supported) memory budget. Reports include available measurements; reserve memory for Windows. These are bounded synthetic workloads, not a complete hardware stability test. Large-file scanning is read-only, skips links and inaccessible items, and is bounded by item count and time.

## Personalization
Select themes, prompt styles, startup information, animations, sidebar separators, language and icons. Export and restore configuration from Personalization. Dashboard Designer changes monitoring cards; drag card headers to reorder. F6 toggles favorites. Light mode follows the chosen theme. Windows Terminal appearance can apply to all profiles; reopen tabs if needed.

## Updates and troubleshooting
Use Update Center to check official releases. Existing configuration is preserved on normal updates. Some counters depend on hardware, drivers and permissions. If a counter is unavailable, do not interpret it as zero.

## Reporting issues
Use [Issues](https://github.com/owoNEXowo/NEX-Dashboard/issues). Include NEX version, Windows version, PowerShell version, reproduction steps and expected/actual behavior. Remove passwords, tokens, private paths, IP addresses and other personal information from screenshots and logs.
