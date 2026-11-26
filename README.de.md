<div align="center">

# NEX Dashboard

**Dein Terminal. Dein Stil. Deine Kontrolle.**

![Version](https://img.shields.io/github/v/release/owoNEXowo/NEX-Dashboard?include_prereleases&sort=semver&label=Version&color=F5BDE6&style=for-the-badge)
![Windows](https://img.shields.io/badge/Windows-11-89B4FA?style=for-the-badge)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-CBA6F7?style=for-the-badge)
![License: MIT](https://img.shields.io/badge/License-MIT-A6E3A1?style=for-the-badge)
![Downloads](https://img.shields.io/github/downloads/owoNEXowo/NEX-Dashboard/total?style=for-the-badge&color=94E2D5&label=Downloads)

[![Download](https://img.shields.io/badge/Download-Releases-A6E3A1?style=for-the-badge)](https://github.com/owoNEXowo/NEX-Dashboard/releases)

[English](README.md) · [Русский](README.ru.md) · **Deutsch**

</div>

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

## Neuerungen in 2.6.2

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
