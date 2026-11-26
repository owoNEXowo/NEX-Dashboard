# Changelog

See [GitHub Releases](https://github.com/owoNEXowo/NEX-Dashboard/releases) for full release notes.

## 2.6.2 (unreleased)
- Debounce startup viewport changes and repaint positioned rows in one write. Add a first-prompt PSReadLine refresh shortcut (Ctrl+Alt+R) and idle refresh where supported, without replacing the input buffer.
- Persist explicit Ookla terms and privacy acceptance locally across Dashboard restarts and upgrades; request consent again for a changed CLI binary or terms revision. Add a reset option.
- Avoid switching screen buffers on first startup keystroke; repaint the fresh viewport in place.
- Clarify active TCP connection counts and add a shortcut to Windows Resource Monitor for per-process network rates.
- Fit built-in fetch cards to the terminal width and repaint the startup preview on resize until the first keyboard input in interactive Windows consoles. Add layout width regression tests.
- Reorder sidebar by purpose, with optional group separators saved in preferences and portable backups.
- Adaptive information labels and grouped personalization settings.
- Detect local Ethernet/Wi-Fi/mobile adapters automatically; distinguish Windows Update restart status from servicing markers.
- Process GPU engine load, general I/O throughput and established TCP connection counts (where available).
- Prefer a stable release when stable and prerelease versions have the same number.
- Keep native powercfg diagnostics out of the result stream and check its exit code.
- Add Windows PowerShell 5.1 and PowerShell 7 parser checks.

## 2.6.1
- Optional Ookla Speedtest CLI installation and SHA-256 verification.

## 2.6.0
- Dashboard Designer, Startup Manager, global search, built-in widgets and Animation Studio.

## 2.5.0
- Integrated GitHub updates with integrity verification and settings preservation.

## 2.4.9
- Public beta with monitoring, themes, Fastfetch and Windows utilities.
