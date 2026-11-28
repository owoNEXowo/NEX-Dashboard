# NEX Dashboard — 2.7.0 regression checklist

Archived maintainer test notes for 2.7.0. Use the checklist for release validation.

## Full PC scan
Open Quick Tools → Full PC scan (V). Windows device status, installed memory, drive health, PnP problem codes, gateway configuration, Defender protection, recent System events, Windows Update restart status DISM component store health and SFC system-file verification are checked in sequence. Green means the particular query found no issue, not a hardware stress test. Unknown means the check was unavailable. K stops after the current check; B returns to tools. Actions open the relevant native Windows screen. Restart checks Windows Update again and asks for confirmation; save work first. DISM ScanHealth and SFC /verifyonly require administrator rights, may take time, and do not repair Windows. Unrecognized SFC output is displayed without claiming a successful integrity result. Memory diagnostics is a separate Windows tool. The RAM check now reads the most recent completed Windows memory test (date and event ID), where available. System event history is informational and is never cleared automatically. Click a check for details and available actions. DISM/SFC skipped without elevation can be retried from a separate administrator PowerShell window.

## Light mode
Personalization → Light interface (W). The selected accent theme remains selected. NEX derives a tinted light background and hue-preserving accent inks. The light palette is contrast-tested against its background. The native terminal default background is used rather than an opaque RGB canvas, allowing existing opacity and acrylic settings to remain in effect. Selected rows and swatches may still use solid backgrounds. Windows Terminal palette changes follow the existing shared-profile behavior; reopen a tab if necessary. Native title bar appearance and external Fastfetch configurations are not controlled.

## Reset
Personalization → Reset Dashboard to defaults (Delete). Confirm only after exporting your settings if you want to restore them. NEX preferences, restored Fastfetch config, consent and local event acknowledgement are reset; a local reset-backup folder is retained. The NEX palette, opacity, acrylic and cursor settings are returned to defaults. Installed tools, other Windows settings, user files and external Fastfetch configs are not removed. Does not undo Windows changes (DNS, power plans, etc.).

## Test checklist
- Install from branch ZIP using installer/Install.cmd; keep all files in their relative locations.
- Test scan in a normal session; unavailable admin-only checks must not display success.
- Check scanning progress, stop after current check, navigation, and clickable actions. Cancel any restart unless you actually want to restart.
- Toggle light mode for multiple themes and resize/reopen Windows Terminal.
- Export preferences, confirm reset, then restore preferences if desired.
- Report screenshots with personal details hidden.

See [2.7.0 release notes](release-notes/2.7.0.md) for the public release information.

Light backgrounds now use a more visible pastel tint derived from the accent. Event history details include Windows' original description, timestamp, and relevant review hints; no logs are deleted and no automatic repairs are performed.

The native Windows Terminal window theme now follows NEX light/dark mode and the selected palette. Applying the shared theme replaces profile tab-color overrides and preserves opacity and Acrylic settings. Actual transparency depends on Windows composition: disable Acrylic for unblurred transparency. The active tab is solid by Windows Terminal design. Reopen tabs or the terminal if native appearance does not update immediately.

## Administrator mode and Windows checks
F8 or the top-right shield opens a new Windows Terminal window at the same Dashboard page, with the opposite privilege level. Elevation uses the normal Windows UAC confirmation; returning to standard mode requests a launch through the interactive Explorer shell. The new process verifies its actual privilege level before opening Dashboard. The original PowerShell session exits only when the replacement Dashboard acknowledges its first render with the requested privilege level. On cancellation, timeout or launch failure, the original stays open. Other tabs and panes are never closed by NEX. The replacement uses the original window position and console dimensions where available, or maximized mode. Geometry is best-effort because Terminal controls final placement. In-memory shell state is not transferred; save work first. A diagnostic view is reopened with a fresh scan. The elevated diagnostic action opens the scan in the new window. A running scan must finish before switching. SFC output is now read as bytes and decoded with UTF-16/UTF-8/OEM handling; unknown output does not imply a successful integrity check. DISM ScanHealth may take several minutes and does not repair the image.

## FIX14 maintainer test (2026-11-28)

- Disk Analyzer: large-file and folder search with a browsable location picker.
- Benchmark Center: CPU, RAM and GPU tests, selectable memory budgets and reports; memory cleanup on completion or cancellation.
- Dashboard personalization: favorites, adaptive sidebar, compact layout, home-card visibility and drag-and-drop feedback; additional status modules.
- File Explorer: clickable path breadcrumbs, extension-preserving rename with preview, and optional Windows Open with registration with NEX editor icon.
- Terminal Editor: syntax coloring, search, mouse selection, clipboard shortcuts, undo/redo, zoom indicator and reset, tabs, auto-pairing, indentation, inline completion and matching brackets.
- NEX Update Center: background update check and animated availability/check feedback.

### Installation from this source ZIP
Extract the complete archive and launch `installer/Install.cmd`. It uses `src/NexDashboard.ps1`; no public release download is required for this installation. The release source archive preserves this layout. The separate clean-test reset script is a local maintenance tool, not part of this source distribution.

### Additional regression checks
- Install in a clean Windows PowerShell 5.1 session, then reopen the terminal; verify existing preferences survive a normal reinstall.
- Repeat and cancel each benchmark; check memory release, available sensor reporting and error handling. Benchmark results are not a certification of system stability.
- Check card dragging, favorites, compact layout, translations and status refresh at narrow and wide window sizes.
- Verify path navigation, rename preview and optional editor registration without changing default file associations.
- Open multiple files; test selection, clipboard, undo/redo, search, completion, bracket highlighting, zoom and scroll. Check unsaved-file prompts and per-tab state.
- Verify update status and animation before publishing a release.

Existing CI and test scripts are retained. The FIX14 package has not been validated by a new Windows CI run as part of this repackaging.
