# NEX Dashboard — test 2.7.0

This branch is for maintainer testing only. Do not publish a release or merge to main yet.

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

Public stable release remains 2.6.2.

Light backgrounds now use a more visible pastel tint derived from the accent. Event history details include Windows' original description, timestamp, and relevant review hints; no logs are deleted and no automatic repairs are performed.
