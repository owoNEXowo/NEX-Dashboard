<div align="center">

# NEX Dashboard

**Dein Terminal. Dein Stil. Deine Kontrolle.**

![Version](https://img.shields.io/github/v/release/owoNEXowo/NEX-Dashboard?sort=semver&label=Version&color=F5BDE6&style=for-the-badge)
![Windows](https://img.shields.io/badge/Windows-11-89B4FA?style=for-the-badge)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-CBA6F7?style=for-the-badge)
![License: MIT](https://img.shields.io/badge/License-MIT-A6E3A1?style=for-the-badge)
![Downloads](https://img.shields.io/github/downloads/owoNEXowo/NEX-Dashboard/total?style=for-the-badge&color=94E2D5&label=Downloads)

[![Download](https://img.shields.io/badge/Download-Releases-A6E3A1?style=for-the-badge)](https://github.com/owoNEXowo/NEX-Dashboard/releases)

[English](README.md) · [Русский](README.ru.md) · **Deutsch**

</div>

## Neuerungen in 2.7.2

Öffnen Sie **F1 → Hilfe und Feedback** oder suchen Sie mit Ctrl+K. Die Funktion ist auch im NEX Update-Center verfügbar. GitHub öffnet sich im Browser; Daten werden nicht automatisch gesendet.

[Fehler melden](https://github.com/owoNEXowo/NEX-Dashboard/issues/new?template=bug_report.md) · [Funktion vorschlagen](https://github.com/owoNEXowo/NEX-Dashboard/issues/new?template=feature_request.md) · [Feedback geben](https://github.com/owoNEXowo/NEX-Dashboard/issues/new?template=feedback.md)

[2.7.2](docs/release-notes/2.7.2.md)

## Neuerungen in 2.7.1

- Das Update-Center zeigt Downloadgröße, Live-Fortschritt und den SHA-256-Prüfstatus.

[2.7.1](docs/release-notes/2.7.1.md)

## Neuerungen in 2.7.0

- **Integrierter Terminal-Editor:** Tabs, Syntaxfarben, Suche mit Treffernavigation, Mausauswahl, Zwischenablage, Rückgängig/Wiederholen, automatische Klammerpaare und Einrückung, lokale Inline-Vervollständigung, Klammerhervorhebung und Zoom/Reset.
- **Dateimanager:** Anklickbare Pfadsegmente, Umbenennung mit Dateiendung und Live-Vorschau sowie optionale Registrierung unter „Öffnen mit“ mit NEX-Symbol.
- **Benchmarks und Laufwerke:** Zeitbegrenzte CPU-, RAM- und GPU-Tests mit wählbarem Speicherbudget und Berichten; schreibgeschützte Suche nach großen Dateien und Ordnern.
- **Personalisierung und Monitoring:** Designbasierter Hellmodus, Favoriten (F6), adaptive Seitenleiste, Kompaktlayout, Startblöcke, verschiebbare Monitorkarten, sanftere Anzeigen und neue Status-Widgets.
- **Diagnose und Updates:** Schreibgeschützte PC-Diagnose, Einstellungsreset mit Sicherung, F8-Berechtigungswechsel über ein Ersatz-Terminalfenster, Hintergrundprüfung und animierte Update-Anzeigen.

Benchmarks ersetzen keinen vollständigen Stabilitätstest. Sensoren und sichere Speicherbudgets hängen von Hardware und Treibern ab. Die Vervollständigung basiert auf Wörterbüchern, nicht auf einem vollständigen Sprachserver. Zoom und Berechtigungswechsel hängen von Windows Terminal ab; F8 nutzt UAC und ersetzt die Sitzung, daher vorher speichern.

[2.7.0 release notes](docs/release-notes/2.7.0.md) · [Website](https://owonexowo.github.io/NEX-Dashboard/)


## Vorschau auf 2.7.0

Screenshots des finalen FIX14-Testbuilds; die öffentliche Version hat dieselbe Oberfläche ohne TEST-Kennzeichnung.

| Benchmark-Center | Pink im Hellmodus |
| :---: | :---: |
| ![Benchmark-Center](benchmark-center.png) | ![Pink im Hellmodus](theme-light-pink.png) |

<details>
<summary>Vorschau auf 2.7.0 — Datei in Editor-Tab öffnen</summary>

### Große Dateien und Ordner

![Große Dateien und Ordner](large-files.png)

### Umbenennungsvorschau

![Umbenennungsvorschau](rename-preview.png)

### Inline-Codevervollständigung

![Inline-Codevervollständigung](editor-completion.png)

### Datei in Editor-Tab öffnen

![Datei in Editor-Tab öffnen](editor-open-tab.png)

### Midnight Aurora im Hellmodus

![Midnight Aurora im Hellmodus](theme-light-aurora.png)

</details>


## Vorschau

![Overview](overview.png)

*Screenshots älterer Versionen; die aktuelle Oberfläche kann abweichen.*

<details>
<summary>Dashboard 2.6.0</summary>

### Systemmonitor
![Systemmonitor](system-monitor.png)

### Personalisierung
![Personalisierung](personalization.png)

### Update-Center
![Update-Center](update-center.png)

</details>

<details>
<summary>Weitere Funktionen — Screenshots aus Version 2.4.9</summary>

### Systeminformationen
![System Info](system-info.png)

### Netzwerk
![Network](network.png)

### Dateimanager
![File Explorer](file-explorer.png)

### Systemzustand
![System Health](system-health.png)

</details>


<details>
<summary>Fastfetch-Designs</summary>

### Karten

![Fastfetch Cards](fastfetch-cards.png)

### Systemübersicht

![Fastfetch System Overview](fastfetch-classic.png)

### Layout-Auswahl

![Fetch preset selector](fetch-presets.png)

</details>

<details>
<summary>Farbdesigns</summary>

### Mint & Glacier (2.4.9)

| Mint | Glacier |
| :---: | :---: |
| ![Mint theme](theme-mint.png) | ![Glacier theme](theme-glacier.png) |

### Design-Auswahl

![Built-in color themes](theme-selector.png)

</details>

## Über NEX Dashboard

Ein anpassbares Dashboard für Windows PowerShell mit Hardware- und Netzwerküberwachung, 32 Farboptionen, Fastfetch-Layouts, Nerd-Font-Symbolen, Gaming-Modus, Energiesparplanverwaltung, Anwendungsstarter, Dateimanager, Systemdiagnose, Windows-Updates und Konfigurationssicherung.

## Vorherige Version: Neuerungen in 2.6.2

- Neu geordnetes Seitenmenü mit optionalen Trennlinien und gruppierten Personalisierungseinstellungen.
- Adaptive Beschriftungen und verbesserte Größenanpassung der Startkarten in unterstützten Konsolen.
- CPU-, RAM- und GPU-Metriken pro Prozess sowie eine Verknüpfung zum Windows-Ressourcenmonitor.
- Automatische Erkennung des lokalen Netzwerkadapters; Ookla-Zustimmung bleibt bei Dashboard-Updates erhalten.
- Getrennte Neustartanzeigen für Windows Update und Wartung.
- Automatische Syntax-, Layout- und Zustimmungstests für PowerShell 5.1 und 7.

Die Größenanpassung hängt von der Konsole und der PSReadLine-Version ab; lange oder mehrzeilige Eingaben werden nicht neu gezeichnet. Datenträger- und Netzwerkraten pro Prozess sind nicht enthalten.

## Neue Funktionen in 2.6.0

- **Dashboard-Designer:** Monitorkarten neu anordnen oder ausblenden, zwischen einer und zwei Spalten wählen und das Layout in der Vorschau ansehen.
- **Autostart-Manager:** Autostart-Programme und ihre Befehle anzeigen sowie die Windows-Autostart-Einstellungen öffnen.
- **Globale Suche:** mit `Ctrl+K` Dashboard-Bereiche und wichtige Aktionen finden.
- **Plugin-Manager:** integrierte Widgets für Akkustand, Sitzungsdauer und Schnellzugriffe aktivieren. Externe Skripte werden nicht ausgeführt.
- **Animationsstudio:** fünf Ladeanimationen, einstellbare Geschwindigkeit und Vorschau.
- **Kontexthilfe:** Erläuterungen in Einstellungsdialogen, Hilfe über `F1` und gepunktete Trennlinien in den Einstellungen.

**Installation:** EasyInstall-ZIP unter [Releases](https://github.com/owoNEXowo/NEX-Dashboard/releases) herunterladen, entpacken und `Install.cmd` starten. Dem Assistenten folgen.

**Updates:** ab Version 2.5.0 können kompatible veröffentlichte Releases über das Update-Center gesucht und installiert werden. Lokale `.ps1`-Updates bleiben möglich.

Öffentliche Version: Die Kompatibilität kann je nach PC und Terminal variieren. Installer nur aus vertrauenswürdigen Quellen ausführen.

---

[Fehler melden](https://github.com/owoNEXowo/NEX-Dashboard/issues)

Erstellt von **NEX**.

## Quellcode

[PowerShell-Quellcode](src/NexDashboard.ps1) · [Repository-Installer](installer/Install.cmd) · [Versionshistorie](CHANGELOG.md). Fertige Pakete sind unter [Releases](https://github.com/owoNEXowo/NEX-Dashboard/releases) verfügbar. Der NEX Dashboard-Quellcode steht unter der [MIT-Lizenz](LICENSE). Für Drittsoftware, Schriftarten und Logos gelten weiterhin ihre jeweiligen Lizenzen.
