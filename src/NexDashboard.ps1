param([switch]$Install,[switch]$Uninstall)
# Public Edition: user-local settings and optional official Terminal/font installation.
if ($Install -or $Uninstall) {
    $ErrorActionPreference='Stop'
    $profileDir=Split-Path -Parent $PROFILE
    $target=Join-Path $profileDir 'NexDashboard.ps1'
    $enc=New-Object System.Text.UTF8Encoding($true)
    $stateDir=Join-Path $env:LOCALAPPDATA 'NexDashboard'
    $state=Join-Path $stateDir 'preferences.json'
    $original=Join-Path $stateDir 'profile-original.ps1'
    $installedHash=Join-Path $stateDir 'profile-installed.sha256'
    $originalDash=Join-Path $stateDir 'dashboard-original.ps1'
    $dashHash=Join-Path $stateDir 'dashboard-installed.sha256'
    $begin='# BEGIN NEX PUBLIC EDITION'; $end='# END NEX PUBLIC EDITION'
    $pattern='(?ms)^# BEGIN NEX PUBLIC EDITION\r?\n.*?^# END NEX PUBLIC EDITION[^\r\n]*(?:\r?\n)?'
    $old=if (Test-Path -LiteralPath $PROFILE -PathType Leaf) {[IO.File]::ReadAllText($PROFILE)} else {''}
    if ($Uninstall) {
        if ($old -match $pattern) {
            if ((Test-Path -LiteralPath $original) -and (Test-Path -LiteralPath $installedHash) -and ((Get-FileHash -LiteralPath $PROFILE).Hash -eq [IO.File]::ReadAllText($installedHash).Trim())) {
                $restored=[IO.File]::ReadAllText($original)
            } else {
                $restored=[regex]::Replace($old,$pattern,'')
                Write-Warning 'Profile was edited after installation. Only the managed block was removed; older NEX startup can be restored from your profile backup if desired.'
            }
            [IO.File]::WriteAllText($PROFILE,$restored,$enc)
        }
        if ((Test-Path -LiteralPath $target) -and (Test-Path -LiteralPath $dashHash) -and ((Get-FileHash -LiteralPath $target).Hash -eq [IO.File]::ReadAllText($dashHash).Trim())) {
            if (Test-Path -LiteralPath $originalDash) {Copy-Item -LiteralPath $originalDash -Destination $target -Force}
            else {Remove-Item -LiteralPath $target -Force}
        } else {Write-Warning 'Dashboard file was changed or absent; not removed automatically.'}
        if (Test-Path -LiteralPath $state) { Remove-Item -LiteralPath $state -Force }
        $eventCheckpoint=Join-Path $stateDir 'events-cleared.utc'
        if (Test-Path -LiteralPath $eventCheckpoint) {Remove-Item -LiteralPath $eventCheckpoint -Force}
        foreach ($item in @($original,$originalDash,$installedHash,$dashHash)) {if (Test-Path -LiteralPath $item) {Move-Item -LiteralPath $item -Destination ($item+'.uninstalled-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')) -Force}}
        foreach ($shortcutName in @('NEX Dashboard.lnk','NEX Dashboard Public.lnk')) {
            $shortcut=Join-Path ([Environment]::GetFolderPath('Programs')) $shortcutName
            if (Test-Path -LiteralPath $shortcut) {
                try { $ws=New-Object -ComObject WScript.Shell; $lnk=$ws.CreateShortcut($shortcut); if ($lnk.Arguments -like '*7e499cb9-0e64-4c22-9bb5-f4e4db932221*') {Remove-Item -LiteralPath $shortcut -Force} } catch {}
            }
        }
        Write-Host 'Public Edition detached. Existing scripts and terminal settings were retained. Reopen PowerShell.'
        return
    }
    $wasConfigured=Test-Path -LiteralPath $state -PathType Leaf
    $null=New-Item -ItemType Directory -Path $profileDir,$stateDir -Force
    $src=[IO.File]::ReadAllText($PSCommandPath)
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseInput($src,[ref]$tokens,[ref]$errors)
    if ($errors.Count) {throw ($errors | Out-String)}
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    if (Test-Path -LiteralPath $target) {Copy-Item -LiteralPath $target -Destination "$target.public-$stamp.bak"}
    if (Test-Path -LiteralPath $PROFILE) {Copy-Item -LiteralPath $PROFILE -Destination "$PROFILE.public-$stamp.bak"}
    if (-not (Test-Path -LiteralPath $original)) {
        [IO.File]::WriteAllText($original,$old,$enc)
        if (Test-Path -LiteralPath $target) {Copy-Item -LiteralPath $target -Destination $originalDash -Force}
    }
    $new=[regex]::Replace($old,$pattern,'')
    $new=[regex]::Replace($new,'(?m)^\$global:NexPromptReady = \$true\r?\n','')
    # Only known legacy NEX startup blocks and loader are migrated; other code remains.
    $new=[regex]::Replace($new,'(?ms)^# NEX_EARLY_SCREEN\r?\n.*?(?=^\$esc = \[char\]27\s*$)','')
    $new=[regex]::Replace($new,'(?m)^\s*\.\s*\(Join-Path\s+\(Split-Path\s+\$PROFILE\)\s+["'']NexDashboard\.ps1["'']\)\s*$','')
    # Keep the old NexShell functions, but suppress its first-prompt startup.
    if ($new -match 'NexShell\.ps1') {
        $new='$global:NexPromptReady = $true'+"`r`n"+$new
    }
    $loader=@'
# BEGIN NEX PUBLIC EDITION
. (Join-Path (Split-Path $PROFILE) 'NexDashboard.ps1')
Initialize-NexPublic
# END NEX PUBLIC EDITION
'@
    $new=$new.TrimEnd()+"`r`n`r`n"+$loader+"`r`n"
    $tokens=$null;$errors=$null
    $null=[Management.Automation.Language.Parser]::ParseInput($new,[ref]$tokens,[ref]$errors)
    if ($errors.Count) {throw 'Profile syntax validation failed. No scripts replaced.'}
    [IO.File]::WriteAllText($target,$src,$enc)
    [IO.File]::WriteAllText($PROFILE,$new,$enc)
    [IO.File]::WriteAllText($installedHash,(Get-FileHash -LiteralPath $PROFILE).Hash,$enc)
    [IO.File]::WriteAllText($dashHash,(Get-FileHash -LiteralPath $target).Hash,$enc)
    . $target
    if (-not (Test-Path -LiteralPath $state)) { NexSetup -SkipTerminalSync }
    if (-not $wasConfigured -and -not (Get-NexSpeedtest)) {
        $answer=Read-Host ((NexL 'Install optional Ookla Speedtest CLI for personal use?')+' [y/N]')
        if ($answer -match '^(?i:y|yes|д|да|j|ja)$') {
            Write-Host (NexL 'Downloading and verifying Ookla Speedtest...') -ForegroundColor Cyan
            try {$null=Install-NexSpeedtest;Write-Host (NexL 'Ookla Speedtest installed.') -ForegroundColor Green}
            catch {Write-Warning ((NexL 'Speedtest installation failed')+': '+$_.Exception.Message)}
        }
    }
    Write-Host '[OK] NEX Dashboard 2.6.2 Public Edition installed.' -ForegroundColor Green
    $hostInfo=Get-NexTerminalHost
    if (-not $wasConfigured -or -not $hostInfo -or -not (Test-Path -LiteralPath $hostInfo.Settings -PathType Leaf) -or ($global:NexPublicSettings.Icons -and -not (Test-NexNerdFont))) {
        $null=Initialize-NexAppearance
    } else {Write-Host (NexL 'Update installed. Open Dashboard to see the new version.') -ForegroundColor Green}
    Initialize-NexPublic
    return
}

$nexTranslationEntries = @'
[{"key":"Overview","ru":"Обзор","de":"Übersicht"},{"key":"System Monitor","ru":"Монитор системы","de":"Systemmonitor"},{"key":"Processes","ru":"Процессы","de":"Prozesse"},{"key":"Network","ru":"Сеть","de":"Netzwerk"},{"key":"File Explorer","ru":"Проводник","de":"Dateimanager"},{"key":"System Info","ru":"О системе","de":"Systeminfo"},{"key":"Windows Update","ru":"Обновления Windows","de":"Windows Update"},{"key":"Quick Tools","ru":"Инструменты","de":"Werkzeuge"},{"key":"System Logs","ru":"Журналы системы","de":"Systemprotokolle"},{"key":"Terminal Settings","ru":"Настройки терминала","de":"Terminal-Einstellungen"},{"key":"Personalization","ru":"Персонализация","de":"Personalisierung"},{"key":"Computer","ru":"Компьютер","de":"Computer"},{"key":"User","ru":"Пользователь","de":"Benutzer"},{"key":"Memory","ru":"Память","de":"Speicher"},{"key":"Uptime","ru":"Время работы","de":"Laufzeit"},{"key":"Language","ru":"Язык","de":"Sprache"},{"key":"Display name","ru":"Отображаемое имя","de":"Anzeigename"},{"key":"Theme","ru":"Тема","de":"Design"},{"key":"Custom accent","ru":"Свой цвет","de":"Eigene Akzentfarbe"},{"key":"Startup screen","ru":"Экран загрузки","de":"Startanimation"},{"key":"Startup info","ru":"Информация при запуске","de":"Startinformationen"},{"key":"Fetch preset","ru":"Стиль информации","de":"Info-Vorlage"},{"key":"Prompt style","ru":"Стиль строки ввода","de":"Prompt-Stil"},{"key":"Icons","ru":"Иконки","de":"Symbole"},{"key":"Prediction","ru":"Подсказки","de":"Vorschläge"},{"key":"Access type","ru":"Тип подключения","de":"Anschlussart"},{"key":"Apply terminal palette","ru":"Применить тему ко всем профилям","de":"Design auf alle Profile anwenden"},{"key":"Setup wizard","ru":"Мастер настройки","de":"Einrichtung"},{"key":"Preview fetch","ru":"Предпросмотр","de":"Info-Vorschau"},{"key":"Enabled","ru":"Включено","de":"An"},{"key":"Disabled","ru":"Выключено","de":"Aus"},{"key":"Automatic","ru":"Автоматически","de":"Automatisch"},{"key":"Unknown","ru":"Неизвестно","de":"Unbekannt"},{"key":"Ready","ru":"Готово","de":"Bereit"},{"key":"Complete","ru":"Завершено","de":"Fertig"},{"key":"Checking","ru":"Проверка","de":"Prüfung"},{"key":"Failed","ru":"Ошибка","de":"Fehlgeschlagen"},{"key":"Never","ru":"Никогда","de":"Nie"},{"key":"Not sampled","ru":"Нет измерений","de":"Nicht gemessen"},{"key":"Not detected","ru":"Не определено","de":"Nicht erkannt"},{"key":"Not reported","ru":"Нет данных","de":"Keine Angabe"},{"key":"Unavailable","ru":"Недоступно","de":"Nicht verfügbar"},{"key":"Stopped","ru":"Остановлено","de":"Beendet"},{"key":"Folder","ru":"Папка","de":"Ordner"},{"key":"This PC / Drives","ru":"Этот компьютер / Диски","de":"Dieser PC / Laufwerke"},{"key":"Preview","ru":"Просмотр","de":"Vorschau"},{"key":"Navigation","ru":"Навигация","de":"Navigation"},{"key":"Status","ru":"Статус","de":"Status"},{"key":"Last checked","ru":"Последняя проверка","de":"Letzte Prüfung"},{"key":"Windows version","ru":"Версия Windows","de":"Windows-Version"},{"key":"Test server","ru":"Сервер теста","de":"Testserver"},{"key":"ISP (Ookla)","ru":"Провайдер (Ookla)","de":"Anbieter (Ookla)"},{"key":"Latency","ru":"Задержка","de":"Latenz"},{"key":"Ping target","ru":"Адрес пинга","de":"Ping-Ziel"},{"key":"Opacity","ru":"Прозрачность","de":"Deckkraft"},{"key":"Acrylic","ru":"Размытие","de":"Acryl"},{"key":"Cursor","ru":"Курсор","de":"Cursor"},{"key":"Color scheme","ru":"Цветовая схема","de":"Farbschema"},{"key":"Profile","ru":"Профиль","de":"Profil"},{"key":"Back","ru":"Назад","de":"Zurück"},{"key":"Menu","ru":"Меню","de":"Menü"},{"key":"Save","ru":"Сохранить","de":"Speichern"},{"key":"Exit","ru":"Выход","de":"Beenden"},{"key":"Cancel","ru":"Отмена","de":"Abbrechen"},{"key":"Confirm","ru":"Подтвердить","de":"Bestätigen"},{"key":"Discard","ru":"Не сохранять","de":"Verwerfen"},{"key":"Save & exit","ru":"Сохранить и выйти","de":"Speichern & Ende"},{"key":"New file","ru":"Новый файл","de":"Neue Datei"},{"key":"Edit","ru":"Редактировать","de":"Bearbeiten"},{"key":"Trash","ru":"В корзину","de":"Papierkorb"},{"key":"Drives","ru":"Диски","de":"Laufwerke"},{"key":"Path","ru":"Путь","de":"Pfad"},{"key":"Find","ru":"Поиск","de":"Suchen"},{"key":"Parent","ru":"Выше","de":"Übergeordnet"},{"key":"Copy","ru":"Копировать","de":"Kopieren"},{"key":"Cut","ru":"Вырезать","de":"Ausschneiden"},{"key":"Paste","ru":"Вставить","de":"Einfügen"},{"key":"Rename","ru":"Переименовать","de":"Umbenennen"},{"key":"View","ru":"Просмотр","de":"Ansehen"},{"key":"Details","ru":"Свойства","de":"Details"},{"key":"Sort","ru":"Сортировка","de":"Sortierung"},{"key":"Hidden","ru":"Скрытые","de":"Versteckte"},{"key":"Clear","ru":"Очистить","de":"Leeren"},{"key":"Refresh","ru":"Обновить","de":"Aktualisieren"},{"key":"Task mgr","ru":"Диспетчер","de":"Task-Manager"},{"key":"Task Manager","ru":"Диспетчер задач","de":"Task-Manager"},{"key":"Disk health","ru":"Состояние дисков","de":"Laufwerkszustand"},{"key":"DNS servers","ru":"DNS-серверы","de":"DNS-Server"},{"key":"Service status","ru":"Службы","de":"Dienste"},{"key":"IP configuration","ru":"Настройки IP","de":"IP-Konfiguration"},{"key":"Event Viewer","ru":"Просмотр событий","de":"Ereignisanzeige"},{"key":"App","ru":"Приложения","de":"Anwendung"},{"key":"System","ru":"Система","de":"System"},{"key":"Export","ru":"Экспорт","de":"Export"},{"key":"Explorer","ru":"Проводник","de":"Explorer"},{"key":"Clear filter","ru":"Сброс поиска","de":"Filter löschen"},{"key":"Stop ping","ru":"Стоп пинг","de":"Ping stoppen"},{"key":"PROCESS","ru":"ПРОЦЕСС","de":"PROZESS"},{"key":"DOWNLOAD","ru":"ЗАГРУЗКА","de":"DOWNLOAD"},{"key":"UPLOAD","ru":"ОТДАЧА","de":"UPLOAD"},{"key":"APPEARANCE & INPUT","ru":"ОФОРМЛЕНИЕ И ВВОД","de":"DARSTELLUNG & EINGABE"},{"key":"WINDOWS UPDATE CENTER","ru":"ЦЕНТР ОБНОВЛЕНИЯ WINDOWS","de":"WINDOWS UPDATE CENTER"},{"key":"HARDWARE / SOFTWARE","ru":"ОБОРУДОВАНИЕ / ПО","de":"HARDWARE / SOFTWARE"},{"key":"READ-ONLY DIAGNOSTICS","ru":"ДИАГНОСТИКА (ЧТЕНИЕ)","de":"DIAGNOSE (NUR LESEN)"},{"key":"NETWORK TRAFFIC","ru":"СЕТЕВОЙ ТРАФИК","de":"NETZWERKVERKEHR"},{"key":"Smoothed","ru":"Сглажено","de":"Geglättet"},{"key":"Welcome","ru":"Добро пожаловать","de":"Willkommen"},{"key":"Loading Windows counters...","ru":"Загрузка счётчиков Windows...","de":"Windows-Zähler werden geladen..."},{"key":"Reading system information...","ru":"Чтение сведений о системе...","de":"Systeminformationen werden gelesen..."},{"key":"No active physical adapters.","ru":"Нет активных физических адаптеров.","de":"Keine aktiven physischen Adapter."},{"key":"Waiting for adapter counters...","ru":"Ожидание сетевых счётчиков...","de":"Warte auf Netzwerkzähler..."},{"key":"On demand only. Measures available internet speed.","ru":"По запросу: измеряет доступную скорость.","de":"Nur auf Anfrage: misst verfügbare Geschwindigkeit."},{"key":"Empty, inaccessible or no matches.","ru":"Пусто, нет доступа или совпадений.","de":"Leer, kein Zugriff oder keine Treffer."},{"key":"No events loaded / matching events.","ru":"Нет подходящих событий.","de":"Keine passenden Ereignisse."},{"key":"Check for updates","ru":"Проверить обновления","de":"Nach Updates suchen"},{"key":"Checking Windows Update ...","ru":"Проверка обновлений Windows ...","de":"Windows-Updates werden geprüft ..."},{"key":"Start test","ru":"Начать тест","de":"Test starten"},{"key":"Cancel test","ru":"Отменить тест","de":"Test abbrechen"},{"key":"Filter","ru":"Фильтр","de":"Filter"},{"key":"Peak","ru":"Пик","de":"Spitze"},{"key":"Type a value, or click a choice. Esc cancels.","ru":"Введите значение или выберите мышью. Esc — отмена.","de":"Wert eingeben oder auswählen. Esc bricht ab."},{"key":"Save changes before leaving?","ru":"Сохранить изменения перед выходом?","de":"Änderungen vor dem Schließen speichern?"},{"key":"MOVE TO RECYCLE BIN?","ru":"ПЕРЕМЕСТИТЬ В КОРЗИНУ?","de":"IN DEN PAPIERKORB VERSCHIEBEN?"},{"key":"Windows may show a further confirmation.","ru":"Windows может запросить подтверждение.","de":"Windows kann erneut nachfragen."},{"key":"Choose language","ru":"Выберите язык","de":"Sprache wählen"},{"key":"Choose theme","ru":"Выберите тему","de":"Design wählen"},{"key":"Choose prompt style","ru":"Выберите стиль строки ввода","de":"Prompt-Stil wählen"},{"key":"Choose fetch preset","ru":"Выберите пресет информации","de":"Info-Vorlage wählen"},{"key":"Preferences saved.","ru":"Настройки сохранены.","de":"Einstellungen gespeichert."},{"key":"Apply colors to selected Windows Terminal profile?","ru":"Применить цвета к выбранному профилю?","de":"Farben auf gewähltes Profil anwenden?"},{"key":"Use Windows account name","ru":"Использовать имя Windows","de":"Windows-Benutzername verwenden"},{"key":"Enter display name","ru":"Введите отображаемое имя","de":"Anzeigename eingeben"},{"key":"Choose access type","ru":"Выберите тип подключения","de":"Anschlussart wählen"},{"key":"Appearance, startup and language","ru":"Оформление, запуск и язык","de":"Darstellung, Start und Sprache"},{"key":"Open personalization","ru":"Открыть персонализацию","de":"Personalisierung öffnen"},{"key":"CPU load","ru":"Нагрузка CPU","de":"CPU-Last"},{"key":"GPU engine load","ru":"Нагрузка движков GPU","de":"GPU-Engine-Last"},{"key":"RAM usage","ru":"Использование RAM","de":"RAM-Nutzung"},{"key":"Physical memory","ru":"Физическая память","de":"Arbeitsspeicher"},{"key":"Storage","ru":"Накопители","de":"Laufwerke"},{"key":"Graphics adapters","ru":"Видеоадаптеры","de":"Grafikadapter"},{"key":"No GPU counter","ru":"Нет счётчика GPU","de":"Kein GPU-Zähler"},{"key":"Processor","ru":"Процессор","de":"Prozessor"},{"key":"Graphics","ru":"Графика","de":"Grafik"},{"key":"Hardware","ru":"Оборудование","de":"Hardware"},{"key":"Software","ru":"Программы","de":"Software"},{"key":"Welcome back","ru":"С возвращением","de":"Willkommen zurück"},{"key":"Loading","ru":"Загрузка","de":"Laden"},{"key":"Settings saved with a backup.","ru":"Настройки сохранены с резервной копией.","de":"Einstellungen mit Sicherung gespeichert."},{"key":"No regular software updates found by this scan.","ru":"Обычные обновления не найдены.","de":"Keine regulären Updates gefunden."},{"key":"Regular software updates","ru":"Обычные обновления","de":"Reguläre Updates"},{"key":"Optional software updates","ru":"Необязательные обновления","de":"Optionale Updates"},{"key":"Microsoft Defender updates","ru":"Обновления Microsoft Defender","de":"Microsoft-Defender-Updates"},{"key":"Unclassified software updates","ru":"Другие обновления","de":"Nicht klassifizierte Updates"},{"key":"Installed Defender signatures","ru":"Установленные базы Defender","de":"Installierte Defender-Signaturen"},{"key":"Defender last updated","ru":"Обновление баз Defender","de":"Letztes Defender-Update"},{"key":"No changes made.","ru":"Без изменений.","de":"Keine Änderungen."},{"key":"Tab: sidebar/content | Esc: back or exit","ru":"Tab: меню/содержимое · Esc: назад/выход","de":"Tab: Menü/Inhalt · Esc: zurück/Ende"},{"key":"Tab: sidebar  |  Esc: overview / exit","ru":"Tab: меню · Esc: обзор/выход","de":"Tab: Menü · Esc: Übersicht/Ende"},{"key":"S Speedtest | K Cancel | P Ping host | X Stop ping | Esc Overview","ru":"S тест | K отмена | P адрес пинга | X стоп | Esc обзор","de":"S Test | K Abbruch | P Ping-Ziel | X Stopp | Esc Übersicht"},{"key":"N New file | M New folder | E Edit | Del Trash | Enter Open | D Drives | P Path","ru":"N Файл · M Папка · E Правка · Del Корзина · Enter Открыть · D Диски · P Путь","de":"N Datei · M Ordner · E Edit · Del Papierkorb · Enter Öffnen · D Laufwerke · P Pfad"},{"key":"F2 Rename | F3 Details | F4 Sort | H Hidden | O Explorer | R Clear | Double-click Open","ru":"F2 Имя · F3 Свойства · F4 Сортировка · H Скрытые · O Проводник · R Сброс","de":"F2 Name · F3 Details · F4 Sortieren · H Versteckte · O Explorer · R Reset"},{"key":"Click values | G Profile | O Opacity | J JSON | Ctrl+, Native settings","ru":"Клик по значениям · G Профиль · O Прозрачность · J JSON · Ctrl+, настройки","de":"Werte anklicken · G Profil · O Deckkraft · J JSON · Ctrl+, Einstellungen"},{"key":"Click a tool | D/N/S/I Query | E/T Native tools | Up/Down scroll","ru":"Выберите инструмент · ↑↓ прокрутка","de":"Werkzeug wählen · ↑↓ scrollen"},{"key":"C / Enter Check | Up/Down scroll | Esc Overview","ru":"C / Enter — проверка | ↑↓ прокрутка | Esc обзор","de":"C / Enter prüfen | ↑↓ scrollen | Esc Übersicht"},{"key":"WUA software scan only; Defender and optional updates listed separately.","ru":"Проверка WUA; Defender и необязательные обновления отдельно.","de":"WUA-Prüfung; Defender und optionale Updates separat."},{"key":"Enter Details | A Application | S System | B Export | Del Archive + clear","ru":"Enter Подробнее · A Приложения · S Система · B Экспорт · Del Архив и очистка","de":"Enter Details · A Anwendung · S System · B Export · Del Archiv & leeren"},{"key":"Clear requires admin. Backup is saved in NexLogBackups.","ru":"Очистка требует прав администратора; архив в NexLogBackups.","de":"Leeren benötigt Adminrechte; Archiv in NexLogBackups."},{"key":"C CPU | M RAM | F Find | R Clear | Up/Down scroll | T Task Manager","ru":"C CPU · M RAM · F Поиск · R Сброс · ↑↓ · T Диспетчер","de":"C CPU · M RAM · F Suche · R Reset · ↑↓ · T Task-Manager"},{"key":"Up/Down scroll | R Refresh | Esc Overview","ru":"↑↓ прокрутка | R обновить | Esc обзор","de":"↑↓ scrollen | R aktualisieren | Esc Übersicht"},{"key":"Enter: open  |  Tab: content  |  Esc: exit","ru":"Enter: открыть · Tab: содержимое · Esc: выход","de":"Enter: öffnen · Tab: Inhalt · Esc: Ende"},{"key":"Up/Down: scroll  |  Esc: back","ru":"↑↓ прокрутка · Esc назад","de":"↑↓ scrollen · Esc zurück"},{"key":"Choose an existing color scheme","ru":"Выберите цветовую схему","de":"Farbschema auswählen"},{"key":"Choose cursor shape","ru":"Выберите форму курсора","de":"Cursorform wählen"},{"key":"Opacity 0-100 (%)","ru":"Прозрачность 0–100 (%)","de":"Deckkraft 0–100 (%)"},{"key":"Process name","ru":"Имя процесса","de":"Prozessname"},{"key":"Enter folder path","ru":"Введите путь папки","de":"Ordnerpfad eingeben"},{"key":"New file name","ru":"Имя нового файла","de":"Neuer Dateiname"},{"key":"New folder name","ru":"Имя новой папки","de":"Neuer Ordnername"},{"key":"Select profile","ru":"Выберите профиль","de":"Profil wählen"},{"key":"Profile identified. Click a value or preset.","ru":"Профиль найден. Нажмите на значение.","de":"Profil erkannt. Wert anklicken."},{"key":"Values on disk. Reopen tab if appearance differs.","ru":"Значения сохранены. При необходимости откройте вкладку заново.","de":"Gespeicherte Werte. Tab ggf. neu öffnen."},{"key":"Defaults: affects profiles without overrides.","ru":"Defaults: действует на профили без переопределений.","de":"Defaults: gilt für Profile ohne eigene Werte."},{"key":"Win+X: profile is inferred. G selects Defaults.","ru":"Win+X: профиль предполагается. G — выбор Defaults.","de":"Win+X: Profil geschätzt. G wählt Defaults."},{"key":"Terminal palette","ru":"Палитра терминала","de":"Terminalpalette"},{"key":"Keep existing","ru":"Оставить текущий","de":"Beibehalten"},{"key":"No startup screen","ru":"Без экрана загрузки","de":"Ohne Startanimation"},{"key":"No startup info","ru":"Без информации","de":"Ohne Startinformationen"},{"key":"Personal settings are stored locally.","ru":"Настройки сохраняются локально.","de":"Einstellungen werden lokal gespeichert."},{"key":"Nerd Font icons need a compatible font.","ru":"Для иконок нужен совместимый шрифт Nerd Font.","de":"Symbole benötigen einen Nerd Font."},{"key":"Theme saved.","ru":"Тема сохранена.","de":"Design gespeichert."},{"key":"Classic monitor","ru":"Классический монитор","de":"Klassischer Monitor"},{"key":"Choose terminal color","ru":"Выбрать цвет терминала","de":"Terminalfarbe wählen"},{"key":"Background","ru":"Фон","de":"Hintergrund"},{"key":"Foreground","ru":"Текст","de":"Text"},{"key":"Cursor color","ru":"Цвет курсора","de":"Cursorfarbe"},{"key":"Selection color","ru":"Цвет выделения","de":"Auswahlfarbe"},{"key":"Cards","ru":"Карточки","de":"Karten"},{"key":"Compact","ru":"Компактный","de":"Kompakt"},{"key":"Minimal","ru":"Минимальный","de":"Minimal"},{"key":"Rounded","ru":"Закруглённый","de":"Abgerundet"},{"key":"Powerline","ru":"Powerline","de":"Powerline"},{"key":"Classic","ru":"Классический","de":"Klassisch"},{"key":"Fastfetch classic","ru":"Fastfetch классический","de":"Fastfetch klassisch"},{"key":"Fastfetch custom","ru":"Fastfetch свой конфиг","de":"Fastfetch eigene Konfig."},{"key":"Pink","ru":"Сакура","de":"Sakura"},{"key":"Lavender","ru":"Лавандовый сон","de":"Lavendeltraum"},{"key":"Blue","ru":"Лазурное небо","de":"Azurhimmel"},{"key":"Mint","ru":"Мятный бриз","de":"Minzbrise"},{"key":"Amber","ru":"Янтарный свет","de":"Bernsteinlicht"},{"key":"Mono","ru":"Лунный монохром","de":"Mond-Monochrom"},{"key":"Custom","ru":"Своя","de":"Benutzerdefiniert"},{"key":"None","ru":"Нет","de":"Keine"},{"key":"History","ru":"История","de":"Verlauf"},{"key":"Fiber / Glasfaser","ru":"Оптоволокно","de":"Glasfaser"},{"key":"Mobile","ru":"Мобильная сеть","de":"Mobilfunk"},{"key":"Cable","ru":"Кабель","de":"Kabel"},{"key":"Other","ru":"Другой","de":"Andere"},{"key":"Click values / keys | Esc Overview","ru":"Клик по значениям · Esc Обзор","de":"Werte anklicken · Esc Übersicht"},{"key":"Esc Overview","ru":"Esc Обзор","de":"Esc Übersicht"},{"key":"Saved","ru":"Сохранено","de":"Gespeichert"},{"key":"Already saved.","ru":"Уже сохранено.","de":"Bereits gespeichert."},{"key":"Unsaved","ru":"Не сохранено","de":"Ungespeichert"},{"key":"Created.","ru":"Создано.","de":"Erstellt."},{"key":"Renamed.","ru":"Переименовано.","de":"Umbenannt."},{"key":"Removed via Windows Recycle Bin.","ru":"Перемещено в корзину Windows.","de":"In Windows-Papierkorb verschoben."},{"key":"Operation completed.","ru":"Операция завершена.","de":"Vorgang abgeschlossen."},{"key":"Folder not found","ru":"Папка не найдена","de":"Ordner nicht gefunden"},{"key":"ARCHIVE AND CLEAR LOG?","ru":"АРХИВИРОВАТЬ И ОЧИСТИТЬ?","de":"ARCHIVIEREN UND LEEREN?"},{"key":"All events in this log; EVTX backup first.","ru":"Сначала архив EVTX, затем очистка журнала.","de":"Zuerst EVTX-Archiv, dann Protokoll leeren."},{"key":"Windows Terminal settings will be backed up.","ru":"Настройки терминала будут скопированы.","de":"Terminal-Einstellungen werden gesichert."},{"key":"Please enlarge terminal to 26 rows.","ru":"Увеличьте высоту терминала до 26 строк.","de":"Terminal auf 26 Zeilen vergrößern."},{"key":"All profiles share appearance. Reopen tabs if needed.","ru":"Общее оформление всех профилей. При необходимости откройте вкладки заново.","de":"Gemeinsames Design aller Profile. Tabs ggf. neu öffnen."},{"key":"All profiles share appearance.","ru":"Единое оформление всех профилей.","de":"Gemeinsames Design aller Profile."},{"key":"Install Fastfetch","ru":"Установить Fastfetch","de":"Fastfetch installieren"},{"key":"Fastfetch is not installed.","ru":"Fastfetch не установлен.","de":"Fastfetch ist nicht installiert."},{"key":"Fastfetch failed; showing built-in Cards.","ru":"Ошибка Fastfetch; показаны встроенные карточки.","de":"Fastfetch-Fehler; integrierte Karten werden angezeigt."},{"key":"Fastfetch ready.","ru":"Fastfetch готов.","de":"Fastfetch ist bereit."},{"key":"Fastfetch missing; showing built-in Cards.","ru":"Fastfetch не установлен; показаны встроенные карточки.","de":"Fastfetch fehlt; integrierte Karten werden angezeigt."},{"key":"Use built-in fallback","ru":"Использовать встроенный вариант","de":"Integrierte Alternative verwenden"},{"key":"Install official Fastfetch now?","ru":"Установить официальный Fastfetch сейчас?","de":"Offizielles Fastfetch jetzt installieren?"},{"key":"No custom config found; using themed Fastfetch.","ru":"Свой конфиг не найден; используется цветной пресет Fastfetch.","de":"Keine eigene Konfiguration; farbiges Fastfetch-Design."},{"key":"New shells use the saved preset.","ru":"Новые окна используют сохранённый пресет.","de":"Neue Fenster verwenden die gespeicherte Vorlage."},{"key":"Installed","ru":"Установлен","de":"Installiert"},{"key":"Not installed","ru":"Не установлен","de":"Nicht installiert"},{"key":"Build","ru":"Сборка","de":"Build"},{"key":"Terminal","ru":"Терминал","de":"Terminal"},{"key":"Shell","ru":"Оболочка","de":"Shell"},{"key":"Disk","ru":"Диск","de":"Laufwerk"},{"key":"Neon Frame","ru":"Неоновые рамки","de":"Neon-Rahmen"},{"key":"Color Labels","ru":"Цветные подписи","de":"Farbige Labels"},{"key":"Tree Layout","ru":"Дерево","de":"Baumansicht"},{"key":"Studio","ru":"Студия без логотипа","de":"Studio ohne Logo"},{"key":"Editor","ru":"Редактор","de":"Editor"},{"key":"CPU","ru":"CPU","de":"CPU"},{"key":"GPU","ru":"GPU","de":"GPU"},{"key":"RAM","ru":"RAM","de":"RAM"},{"key":"System overview","ru":"Обзор системы","de":"Systemübersicht"},{"key":"Disks","ru":"Диски","de":"Laufwerke"},{"key":"DNS","ru":"DNS-серверы","de":"DNS-Server"},{"key":"Services","ru":"Службы","de":"Dienste"},{"key":"IP","ru":"Настройки IP","de":"IP-Konfiguration"},{"key":"Health","ru":"Состояние","de":"Zustand"},{"key":"Healthy","ru":"Исправен","de":"Fehlerfrei"},{"key":"Warning","ru":"Предупреждение","de":"Warnung"},{"key":"Unhealthy","ru":"Неисправен","de":"Fehlerhaft"},{"key":"OK","ru":"Норма","de":"OK"},{"key":"Running","ru":"Работает","de":"Läuft"},{"key":"StartPending","ru":"Запускается","de":"Wird gestartet"},{"key":"StopPending","ru":"Останавливается","de":"Wird beendet"},{"key":"Paused","ru":"Приостановлено","de":"Pausiert"},{"key":"Gateway","ru":"Шлюз","de":"Gateway"},{"key":"Reading...","ru":"Чтение...","de":"Wird gelesen..."},{"key":"Change DNS","ru":"Изменить DNS","de":"DNS ändern"},{"key":"Choose network adapter","ru":"Выберите сетевой адаптер","de":"Netzwerkadapter wählen"},{"key":"Choose DNS mode","ru":"Выберите режим DNS","de":"DNS-Modus wählen"},{"key":"Custom DNS","ru":"Свои DNS-адреса","de":"Eigene DNS-Adressen"},{"key":"Automatic DNS (DHCP)","ru":"Автоматический DNS (DHCP)","de":"Automatischer DNS (DHCP)"},{"key":"Enter IPv4 DNS addresses separated by commas","ru":"Введите IPv4 DNS через запятую","de":"IPv4-DNS-Adressen mit Komma eingeben"},{"key":"Invalid IPv4 DNS address.","ru":"Некорректный IPv4 DNS-адрес.","de":"Ungültige IPv4-DNS-Adresse."},{"key":"DNS changes require administrator rights.","ru":"Для изменения DNS нужны права администратора.","de":"DNS-Änderungen erfordern Administratorrechte."},{"key":"APPLY DNS SETTINGS?","ru":"ПРИМЕНИТЬ НАСТРОЙКИ DNS?","de":"DNS-EINSTELLUNGEN ANWENDEN?"},{"key":"Only the selected adapter will be changed.","ru":"Изменится только выбранный адаптер.","de":"Nur der gewählte Adapter wird geändert."},{"key":"DNS settings updated.","ru":"Настройки DNS обновлены.","de":"DNS-Einstellungen aktualisiert."},{"key":"Diagnostics & network settings","ru":"Диагностика и настройки сети","de":"Diagnose und Netzwerkeinstellungen"},{"key":"Click a tool | Up/Down scroll","ru":"Выберите инструмент мышью · ↑↓ прокрутка","de":"Werkzeug anklicken · ↑↓ scrollen"},{"key":"Fetch animation","ru":"Анимация появления информации","de":"Info-Einblendung"},{"key":"Date","ru":"Дата","de":"Datum"},{"key":"LIVE","ru":"В РЕАЛЬНОМ ВРЕМЕНИ","de":"LIVE"},{"key":"Smoothed display","ru":"Плавные показания","de":"Geglättete Anzeige"},{"key":"8 s history","ru":"История 8 с","de":"8 s Verlauf"},{"key":"log scale","ru":"лог. шкала","de":"Log-Skala"},{"key":"150 ms target","ru":"интервал ~150 мс","de":"Zielintervall 150 ms"},{"key":"standard sampling","ru":"обычный опрос","de":"Standardabfrage"},{"key":"Down","ru":"Загрузка","de":"Download"},{"key":"Up","ru":"Отдача","de":"Upload"},{"key":"items","ru":"объектов","de":"Einträge"},{"key":"True","ru":"Да","de":"Ja"},{"key":"False","ru":"Нет","de":"Nein"},{"key":"Name","ru":"Имя","de":"Name"},{"key":"Size","ru":"Размер","de":"Größe"},{"key":"Date modified","ru":"Дата изменения","de":"Änderungsdatum"},{"key":"PC","ru":"Компьютер","de":"Computer"},{"key":"Cores / threads","ru":"Ядра / потоки","de":"Kerne / Threads"},{"key":"Motherboard","ru":"Материнская плата","de":"Mainboard"},{"key":"Usable RAM","ru":"Доступная RAM","de":"Nutzbarer RAM"},{"key":"Driver","ru":"Драйвер","de":"Treiber"},{"key":"Last 7 days","ru":"Последние 7 дней","de":"Letzte 7 Tage"},{"key":"Error / warning","ru":"Ошибки / предупреждения","de":"Fehler / Warnungen"},{"key":"Application","ru":"Приложения","de":"Anwendung"},{"key":"Windows does not report scan percentage.","ru":"Windows не сообщает процент проверки.","de":"Windows meldet keinen Prüffortschritt."},{"key":"A query is running. Try again shortly.","ru":"Выполняется запрос. Повторите чуть позже.","de":"Eine Abfrage läuft. Bitte erneut versuchen."},{"key":"Query failed or access denied.","ru":"Запрос не выполнен или нет доступа.","de":"Abfrage fehlgeschlagen oder Zugriff verweigert."},{"key":"Not configured","ru":"Не настроено","de":"Nicht eingerichtet"},{"key":"Custom IPv4 DNS","ru":"Ручной IPv4 DNS","de":"Manueller IPv4-DNS"},{"key":"Current DNS","ru":"Текущий DNS","de":"Aktueller DNS"},{"key":"Enter OK  |  Esc Cancel  |  Ctrl+V Paste","ru":"Enter — ОК | Esc — отмена | Ctrl+V — вставить","de":"Enter OK | Esc Abbrechen | Ctrl+V Einfügen"},{"key":"Click / Left / Right / Enter / Esc","ru":"Мышь / ← / → / Enter / Esc","de":"Maus / ← / → / Enter / Esc"},{"key":"Enlarge terminal (58 x 16 min).","ru":"Увеличьте терминал (мин. 58 × 16).","de":"Terminal vergrößern (mind. 58 × 16)."},{"key":"Please enlarge terminal to 27 rows.","ru":"Увеличьте высоту терминала до 27 строк.","de":"Terminal auf 27 Zeilen vergrößern."},{"key":"Enlarge the window or press Esc.","ru":"Увеличьте окно или нажмите Esc.","de":"Fenster vergrößern oder Esc drücken."},{"key":"max, all adapters","ru":"макс., все адаптеры","de":"max., alle Adapter"},{"key":"session","ru":"сеанс","de":"Sitzung"},{"key":"Theme applied to all profiles.","ru":"Тема применена ко всем профилям.","de":"Design auf alle Profile angewendet."},{"key":"Dashboard theme saved.","ru":"Тема Dashboard сохранена.","de":"Dashboard-Design gespeichert."},{"key":"Install the official Ookla CLI first.","ru":"Сначала установите официальный Ookla CLI.","de":"Zuerst die offizielle Ookla CLI installieren."},{"key":"Select a supported text file.","ru":"Выберите поддерживаемый текстовый файл.","de":"Unterstützte Textdatei auswählen."},{"key":"Editor limit: 256 KiB. Use external editor for large files.","ru":"Лимит редактора: 256 КиБ. Для больших файлов нужен внешний редактор.","de":"Editorlimit: 256 KiB. Große Dateien extern bearbeiten."},{"key":"Editing links is not supported.","ru":"Редактирование ссылок не поддерживается.","de":"Bearbeiten von Links wird nicht unterstützt."},{"key":"File saved.","ru":"Файл сохранён.","de":"Datei gespeichert."},{"key":"Folder path","ru":"Путь к папке","de":"Ordnerpfad"},{"key":"Filter names (empty cancels)","ru":"Фильтр имён (пусто — отмена)","de":"Namen filtern (leer = Abbruch)"},{"key":"Copied to dashboard clipboard; navigate and press V.","ru":"Скопировано. Перейдите в нужную папку и нажмите V.","de":"Kopiert. Zielordner wählen und V drücken."},{"key":"Marked to move; navigate and press V.","ru":"Отмечено для переноса. Выберите папку и нажмите V.","de":"Zum Verschieben markiert. Zielordner wählen und V drücken."},{"key":"Select a text file to preview.","ru":"Выберите текстовый файл для просмотра.","de":"Textdatei für Vorschau auswählen."},{"key":"Preview supports text files only.","ru":"Просмотр доступен только для текстовых файлов.","de":"Vorschau nur für Textdateien."},{"key":"Unsupported log.","ru":"Журнал не поддерживается.","de":"Protokoll wird nicht unterstützt."},{"key":"Wait for current log query.","ru":"Дождитесь завершения запроса журнала.","de":"Laufende Protokollabfrage abwarten."},{"key":"Clearing requires an administrator PowerShell.","ru":"Для очистки нужны права администратора.","de":"Leeren erfordert Administratorrechte."},{"key":"Choose Windows Terminal profile","ru":"Выберите профиль Windows Terminal","de":"Windows-Terminal-Profil auswählen"},{"key":"Invalid profile number.","ru":"Неверный номер профиля.","de":"Ungültige Profilnummer."},{"key":"Defaults selected for display. Changes apply to all profiles.","ru":"Выбраны общие настройки. Изменения для всех профилей.","de":"Allgemeine Einstellungen gewählt. Änderungen für alle Profile."},{"key":"Enter a number from 0 to 100.","ru":"Введите число от 0 до 100.","de":"Zahl von 0 bis 100 eingeben."},{"key":"Unsupported cursor shape.","ru":"Неизвестная форма курсора.","de":"Nicht unterstützte Cursorform."},{"key":"Choose a listed scheme.","ru":"Выберите схему из списка.","de":"Farbschema aus der Liste wählen."},{"key":"Settings file not identified.","ru":"Файл настроек не найден.","de":"Einstellungsdatei nicht gefunden."},{"key":"Settings refreshed.","ru":"Настройки обновлены.","de":"Einstellungen aktualisiert."},{"key":"Ping host or IP address (e.g. 1.1.1.1)","ru":"Имя узла или IP для пинга","de":"Hostname oder IP für Ping"},{"key":"Invalid host.","ru":"Неверный адрес узла.","de":"Ungültiger Host."},{"key":"Waiting...","ru":"Ожидание...","de":"Warten..."},{"key":"Unreachable / DNS error","ru":"Узел недоступен / ошибка DNS","de":"Nicht erreichbar / DNS-Fehler"},{"key":"HDD","ru":"HDD","de":"HDD"},{"key":"SSD","ru":"SSD","de":"SSD"},{"key":"Choose a file","ru":"Выберите файл","de":"Datei auswählen"},{"key":"Temperature","ru":"Температура","de":"Temperatur"},{"key":"Power","ru":"Мощность","de":"Leistung"},{"key":"Clock","ru":"Частота","de":"Takt"},{"key":"Fans","ru":"Вентиляторы","de":"Lüfter"},{"key":"Reported clock","ru":"Частота по WMI","de":"Gemeldeter Takt"},{"key":"Free","ru":"Свободно","de":"Frei"},{"key":"VRAM","ru":"Видеопамять","de":"VRAM"},{"key":"NVIDIA sensors","ru":"Датчики NVIDIA","de":"NVIDIA-Sensoren"},{"key":"GPU load: max of all adapters","ru":"GPU: максимум всех адаптеров","de":"GPU: Maximum aller Adapter"},{"key":"No dedicated VRAM sensor","ru":"Нет датчика выделенной VRAM","de":"Kein Sensor für dedizierten VRAM"},{"key":"Download","ru":"Загрузка","de":"Download"},{"key":"Upload","ru":"Отдача","de":"Upload"},{"key":"Time","ru":"Время","de":"Zeit"},{"key":"Physical adapters","ru":"Физические адаптеры","de":"Physische Adapter"},{"key":"Up/Down scroll | Tab Menu | Esc Overview","ru":"↑↓ прокрутка · Tab меню · Esc обзор","de":"↑↓ scrollen · Tab Menü · Esc Übersicht"},{"key":"Scroll for more","ru":"Прокрутите для просмотра","de":"Scrollen für mehr"},{"key":"GPU telemetry unavailable","ru":"Датчики GPU недоступны","de":"GPU-Sensoren nicht verfügbar"},{"key":"Load history","ru":"История нагрузки","de":"Lastverlauf"},{"key":"Other adapters","ru":"Другие адаптеры","de":"Weitere Adapter"},{"key":"No storage data","ru":"Нет данных о дисках","de":"Keine Laufwerksdaten"},{"key":"CPU temperature unavailable","ru":"Температура CPU недоступна","de":"CPU-Temperatur nicht verfügbar"},{"key":"Rows","ru":"Строки","de":"Zeilen"},{"key":"Temp.","ru":"Темп.","de":"Temp."},{"key":"GPU load: NVIDIA sensor","ru":"GPU: датчик NVIDIA","de":"GPU: NVIDIA-Sensor"},{"key":"Custom logo","ru":"Свой логотип","de":"Eigenes Logo"},{"key":"Default logo","ru":"Стандартный логотип","de":"Standardlogo"},{"key":"Custom logo saved.","ru":"Логотип сохранён.","de":"Eigenes Logo gespeichert."},{"key":"Default logo restored.","ru":"Стандартный логотип восстановлен.","de":"Standardlogo wiederhergestellt."},{"key":"Paste art | Ctrl+A selects all | Empty + Save = default","ru":"Вставьте рисунок | Ctrl+A — всё | Пусто + сохранить = стандартный","de":"Grafik einfügen | Ctrl+A alles | Leer + Speichern = Standard"},{"key":"All text selected","ru":"Весь текст выделен","de":"Alles ausgewählt"},{"key":"Logo limit: 80 lines, 120 characters per line.","ru":"Лимит логотипа: 80 строк, 120 символов в строке.","de":"Logo-Limit: 80 Zeilen, 120 Zeichen pro Zeile."},{"key":"Logo must contain printable text only.","ru":"Логотип должен содержать только печатные символы.","de":"Logo darf nur druckbare Zeichen enthalten."},{"key":"Restore","ru":"Восстановить","de":"Wiederherstellen"},{"key":"Export configuration","ru":"Экспорт настроек","de":"Konfiguration exportieren"},{"key":"Restore configuration","ru":"Восстановление настроек","de":"Konfiguration wiederherstellen"},{"key":"Restore configuration?","ru":"Восстановить настройки?","de":"Konfiguration wiederherstellen?"},{"key":"Replace appearance; allow official dependency downloads?","ru":"Заменить оформление? Разрешить загрузку компонентов?","de":"Design ersetzen und offizielle Downloads erlauben?"},{"key":"Restoring configuration...","ru":"Восстановление настроек...","de":"Konfiguration wird wiederhergestellt..."},{"key":"Invalid configuration file.","ru":"Некорректный файл настроек.","de":"Ungültige Konfigurationsdatei."},{"key":"Light/dark scheme pairs are not supported by export.","ru":"Парные светлые/тёмные схемы не поддерживаются.","de":"Helle/dunkle Schemapaare werden nicht unterstützt."},{"key":"Configuration exported.","ru":"Настройки экспортированы.","de":"Konfiguration exportiert."},{"key":"Configuration exported. External Fastfetch assets/options were omitted.","ru":"Настройки сохранены. Внешние ресурсы Fastfetch пропущены.","de":"Exportiert. Externe Fastfetch-Ressourcen wurden ausgelassen."},{"key":"Configuration exported with default terminal appearance.","ru":"Настройки сохранены с оформлением терминала по умолчанию.","de":"Mit Standarddesign des Terminals exportiert."},{"key":"Windows Terminal setup incomplete.","ru":"Установка Windows Terminal не завершена.","de":"Windows Terminal nicht vollständig eingerichtet."},{"key":"Nerd Font could not be restored.","ru":"Не удалось восстановить Nerd Font.","de":"Nerd Font konnte nicht wiederhergestellt werden."},{"key":"Selected external font must be installed separately.","ru":"Выбранный сторонний шрифт нужно установить отдельно.","de":"Die externe Schriftart muss separat installiert werden."},{"key":"Fastfetch could not be restored.","ru":"Не удалось восстановить Fastfetch.","de":"Fastfetch konnte nicht wiederhergestellt werden."},{"key":"Color scheme definition not included.","ru":"Определение цветовой схемы не сохранено.","de":"Farbschema-Definition fehlt."},{"key":"Terminal appearance not fully restored.","ru":"Оформление терминала восстановлено не полностью.","de":"Terminaldesign nicht vollständig wiederhergestellt."},{"key":"Custom Fastfetch configuration not restored.","ru":"Свой конфиг Fastfetch не восстановлен.","de":"Eigene Fastfetch-Konfiguration nicht wiederhergestellt."},{"key":"External Fastfetch assets/options were omitted.","ru":"Внешние ресурсы Fastfetch пропущены.","de":"Externe Fastfetch-Ressourcen ausgelassen."},{"key":"Configuration partially restored.","ru":"Настройки восстановлены частично.","de":"Konfiguration teilweise wiederhergestellt."},{"key":"Configuration restored. Reopen terminal tabs.","ru":"Настройки восстановлены. Переоткрой вкладки терминала.","de":"Konfiguration wiederhergestellt. Terminal-Tabs neu öffnen."},{"key":"S Export | R Restore | Esc Overview","ru":"S Экспорт | R Восстановить | Esc Обзор","de":"S Export | R Wiederherstellen | Esc Übersicht"},{"key":"Crimson Eclipse","ru":"Алое затмение","de":"Scharlachfinsternis"},{"key":"Blood Moon","ru":"Багровая луна","de":"Blutmond"},{"key":"Ember Forge","ru":"Огненная кузница","de":"Glutschmiede"},{"key":"Solar Flare","ru":"Солнечная вспышка","de":"Sonneneruption"},{"key":"Ivory Frost","ru":"Белый иней","de":"Elfenbeinreif"},{"key":"Obsidian","ru":"Обсидиан","de":"Obsidian"},{"key":"Glacier","ru":"Ледник","de":"Gletscher"},{"key":"Ocean Depths","ru":"Глубины океана","de":"Ozeantiefe"},{"key":"Midnight Aurora","ru":"Полночное сияние","de":"Mitternachtsaurora"},{"key":"Cyber Pulse","ru":"Киберимпульс","de":"Cyberpuls"},{"key":"Violet Nebula","ru":"Фиолетовая туманность","de":"Violetter Nebel"},{"key":"Cherry Blossom","ru":"Цветение вишни","de":"Kirschblüte"},{"key":"Rose Quartz","ru":"Розовый кварц","de":"Rosenquarz"},{"key":"Peach Sunset","ru":"Персиковый закат","de":"Pfirsichsonnenuntergang"},{"key":"Forest Spirit","ru":"Лесной дух","de":"Waldgeist"},{"key":"Emerald Circuit","ru":"Изумрудная схема","de":"Smaragdschaltkreis"},{"key":"Acid Lime","ru":"Кислотный лайм","de":"Neonlimette"},{"key":"Golden Hour","ru":"Золотой час","de":"Goldene Stunde"},{"key":"Copper Dusk","ru":"Медные сумерки","de":"Kupferdämmerung"},{"key":"Sapphire Night","ru":"Сапфировая ночь","de":"Saphirnacht"},{"key":"Storm Grey","ru":"Грозовое небо","de":"Sturmgrau"},{"key":"Arcade Neon","ru":"Аркадный неон","de":"Arcade-Neon"},{"key":"Polar Dawn","ru":"Полярный рассвет","de":"Polarmorgen"},{"key":"Lavender Haze","ru":"Лавандовая дымка","de":"Lavendeldunst"},{"key":"Raspberry Ink","ru":"Малиновый бархат","de":"Himbeersamt"},{"key":"click to edit","ru":"нажмите для изменения","de":"zum Bearbeiten klicken"},{"key":"Native color scheme","ru":"Цветовая схема терминала","de":"Terminal-Farbschema"},{"key":"Scroll for more settings","ru":"Прокрутите для других настроек","de":"Für weitere Einstellungen scrollen"},{"key":"Low","ru":"Низкая","de":"Niedrig"},{"key":"Moderate","ru":"Средняя","de":"Mittel"},{"key":"High","ru":"Высокая","de":"Hoch"},{"key":"Critical","ru":"Критическая","de":"Kritisch"},{"key":"Clear screen on return","ru":"Очищать при возврате","de":"Bei Rückkehr leeren"},{"key":"Loading on return","ru":"Загрузка при возврате","de":"Ladebild bei Rückkehr"},{"key":"Hardware Info","ru":"Комплектующие","de":"Hardware-Info"},{"key":"Gaming Mode","ru":"Игровой режим","de":"Gaming-Modus"},{"key":"App Launcher","ru":"Запуск приложений","de":"App-Starter"},{"key":"Update Center","ru":"Обновления NEX","de":"NEX-Updates"},{"key":"System Health","ru":"Состояние системы","de":"Systemzustand"},{"key":"Notification Center","ru":"Уведомления","de":"Benachrichtigungen"},{"key":"Model","ru":"Модель","de":"Modell"},{"key":"Maximum clock","ru":"Макс. частота","de":"Max. Takt"},{"key":"Socket","ru":"Сокет","de":"Sockel"},{"key":"Resolution","ru":"Разрешение","de":"Auflösung"},{"key":"Module","ru":"Модуль","de":"Modul"},{"key":"Architecture","ru":"Архитектура","de":"Architektur"},{"key":"Apply recommended plan","ru":"Применить рекомендацию","de":"Empfohlenen Plan anwenden"},{"key":"Choose power plan","ru":"Выбрать схему питания","de":"Energiesparplan wählen"},{"key":"Windows Game Mode","ru":"Игровой режим Windows","de":"Windows-Spielmodus"},{"key":"Windows power options","ru":"Электропитание Windows","de":"Windows-Energieoptionen"},{"key":"Available power plans","ru":"Доступные схемы питания","de":"Verfügbare Energiesparpläne"},{"key":"Recommended","ru":"Рекомендуется","de":"Empfohlen"},{"key":"Balanced plan not found.","ru":"Сбалансированная схема не найдена.","de":"Ausbalancierter Plan fehlt."},{"key":"X3D: Balanced supports normal chipset scheduling.","ru":"X3D: Balanced подходит для работы планировщика чипсета.","de":"X3D: Ausbalanciert unterstützt die Chipsatzplanung."},{"key":"AMD: Balanced is the preferred starting point.","ru":"AMD: лучше начать со сбалансированной схемы.","de":"AMD: Ausbalanciert als Ausgangspunkt."},{"key":"Balanced is a safe default; High performance is optional.","ru":"Balanced по умолчанию; высокая производительность необязательна.","de":"Ausbalanciert als Standard; Höchstleistung optional."},{"key":"Apply power plan","ru":"Применить схему питания","de":"Energieplan anwenden"},{"key":"No CPU or GPU overclocking.","ru":"Без разгона CPU или GPU.","de":"Keine CPU- oder GPU-Übertaktung."},{"key":"Power plan applied.","ru":"Схема питания применена.","de":"Energieplan angewendet."},{"key":"Power plan change failed.","ru":"Не удалось изменить схему питания.","de":"Energieplan konnte nicht geändert werden."},{"key":"Search applications","ru":"Поиск приложений","de":"Apps suchen"},{"key":"Choose application","ru":"Выбрать приложение","de":"App auswählen"},{"key":"Loading applications...","ru":"Загрузка приложений...","de":"Apps werden geladen..."},{"key":"Installed applications","ru":"Установленные приложения","de":"Installierte Apps"},{"key":"Application launched.","ru":"Приложение запущено.","de":"App gestartet."},{"key":"GitHub repository (owner/name)","ru":"Репозиторий GitHub (владелец/имя)","de":"GitHub-Repository (Besitzer/Name)"},{"key":"Invalid repository.","ru":"Некорректный репозиторий.","de":"Ungültiges Repository."},{"key":"Configure a release repository first.","ru":"Сначала укажите репозиторий релизов.","de":"Zuerst Release-Repository konfigurieren."},{"key":"Another query is running.","ru":"Выполняется другой запрос.","de":"Eine andere Abfrage läuft."},{"key":"Checking for releases...","ru":"Проверка релизов...","de":"Releases werden geprüft..."},{"key":"Not a valid NEX installer.","ru":"Некорректный установщик NEX.","de":"Ungültiger NEX-Installer."},{"key":"Select a newer installer.","ru":"Выберите более новый установщик.","de":"Neueren Installer auswählen."},{"key":"Install local update","ru":"Установить локальное обновление","de":"Lokales Update installieren"},{"key":"Only run installers from a source you trust.","ru":"Запускайте установщики только из доверенного источника.","de":"Nur Installer aus vertrauenswürdigen Quellen ausführen."},{"key":"Installed version","ru":"Установленная версия","de":"Installierte Version"},{"key":"Release repository","ru":"Репозиторий релизов","de":"Release-Repository"},{"key":"Configure release repository","ru":"Настроить репозиторий","de":"Release-Repository konfigurieren"},{"key":"Check for releases","ru":"Проверить обновления","de":"Nach Updates suchen"},{"key":"Open releases","ru":"Открыть релизы","de":"Releases öffnen"},{"key":"Latest release","ru":"Последний релиз","de":"Neuester Release"},{"key":"Version cannot be compared","ru":"Не удалось сравнить версии","de":"Version nicht vergleichbar"},{"key":"New version available","ru":"Доступна новая версия","de":"Neue Version verfügbar"},{"key":"No newer release found","ru":"Новая версия не найдена","de":"Keine neuere Version gefunden"},{"key":"Windows Security","ru":"Безопасность Windows","de":"Windows-Sicherheit"},{"key":"Last check","ru":"Последняя проверка","de":"Letzte Prüfung"},{"key":"Recent system errors","ru":"Недавние ошибки системы","de":"Neuere Systemfehler"},{"key":"Restart pending","ru":"Требуется перезапуск","de":"Neustart ausstehend"},{"key":"Defender real-time protection","ru":"Защита Defender в реальном времени","de":"Defender-Echtzeitschutz"},{"key":"Defender real-time protection is off","ru":"Защита Defender отключена","de":"Defender-Echtzeitschutz ist aus"},{"key":"Dismiss current alerts","ru":"Скрыть текущие уведомления","de":"Aktuelle Meldungen ausblenden"},{"key":"Current notifications","ru":"Текущие уведомления","de":"Aktuelle Meldungen"},{"key":"Waiting for health check...","ru":"Ожидание диагностики...","de":"Warte auf Systemprüfung..."},{"key":"No active notifications","ru":"Нет активных уведомлений","de":"Keine aktiven Meldungen"},{"key":"Low disk space","ru":"Мало места на диске","de":"Wenig Speicherplatz"},{"key":"Disk health warning","ru":"Предупреждение о накопителе","de":"Laufwerkswarnung"},{"key":"High memory usage","ru":"Высокая нагрузка памяти","de":"Hohe Speicherauslastung"},{"key":"High GPU temperature","ru":"Высокая температура GPU","de":"Hohe GPU-Temperatur"},{"key":"Temperature alerts use available GPU sensors only.","ru":"Температурные уведомления используют доступные датчики GPU.","de":"Temperaturmeldungen nutzen verfügbare GPU-Sensoren."},{"key":"Click a power plan to apply it.","ru":"Нажмите на схему питания для применения.","de":"Zum Anwenden auf einen Energiesparplan klicken."},{"key":"No power plans found.","ru":"Схемы питания не найдены.","de":"Keine Energiesparpläne gefunden."},{"key":"This power plan is already active.","ru":"Эта схема питания уже активна.","de":"Dieser Energiesparplan ist bereits aktiv."},{"key":"Could not verify the active power plan.","ru":"Не удалось проверить активную схему питания.","de":"Aktiver Energiesparplan konnte nicht überprüft werden."},{"key":"Windows did not activate the selected plan.","ru":"Windows не активировала выбранную схему.","de":"Windows hat den ausgewählten Plan nicht aktiviert."},{"key":"Enabled (Windows default)","ru":"Включён (по умолчанию Windows)","de":"Aktiviert (Windows-Standard)"},{"key":"Event list changed. Refresh and try again.","ru":"Список событий изменился. Обновите и повторите.","de":"Ereignisliste geändert. Aktualisieren und erneut versuchen."},{"key":"Windows did not provide an event description.","ru":"Windows не предоставила описание события.","de":"Windows hat keine Ereignisbeschreibung bereitgestellt."},{"key":"Last 24 hours - up to 30 events. Click an event for details.","ru":"За 24 часа — до 30 событий. Нажмите для подробностей.","de":"Letzte 24 Stunden – bis zu 30 Ereignisse. Für Details anklicken."},{"key":"No recent system errors","ru":"Нет недавних системных ошибок","de":"Keine aktuellen Systemfehler"},{"key":"System event details","ru":"Подробности системных событий","de":"Systemereignisdetails"},{"key":"Event ID","ru":"Код события","de":"Ereignis-ID"},{"key":"Severity","ru":"Уровень","de":"Schweregrad"},{"key":"Error","ru":"Ошибка","de":"Fehler"},{"key":"Description","ru":"Описание","de":"Beschreibung"},{"key":"Source","ru":"Источник","de":"Quelle"},{"key":"Show computer name","ru":"Показывать имя ПК","de":"Computernamen anzeigen"},{"key":"Computer alias","ru":"Псевдоним компьютера","de":"Computer-Alias"},{"key":"Enter computer alias","ru":"Введите имя после @","de":"Namen nach @ eingeben"},{"key":"Use Windows computer name","ru":"Использовать имя ПК Windows","de":"Windows-Computernamen verwenden"},{"key":"Computer alias (Enter keeps current)","ru":"Имя после @ (Enter — оставить)","de":"Computer-Alias (Enter: beibehalten)"},{"key":"Identity preview","ru":"Предпросмотр имени","de":"Namensvorschau"},{"key":"Live preview","ru":"Предпросмотр","de":"Live-Vorschau"},{"key":"Existing prompt (not managed)","ru":"Исходная строка (без изменений)","de":"Vorhandener Prompt (unverändert)"},{"key":"Aurora","ru":"Северное сияние","de":"Aurora"},{"key":"Circuit","ru":"Электроника","de":"Schaltkreis"},{"key":"Metro","ru":"Метро","de":"Metro"},{"key":"Orbit","ru":"Орбита","de":"Orbit"},{"key":"Zen","ru":"Дзен","de":"Zen"},{"key":"Terminal Pro","ru":"Терминал Pro","de":"Terminal Pro"},{"key":"Pixel","ru":"Пиксель","de":"Pixel"},{"key":"Twin Line","ru":"Двойная линия","de":"Doppellinie"},{"key":"Soft Wave","ru":"Мягкая волна","de":"Sanfte Welle"},{"key":"Clear displayed events","ru":"Очистить список событий","de":"Angezeigte Ereignisse leeren"},{"key":"Hide old events in both pages.","ru":"Скрыть старые события в обоих разделах.","de":"Alte Ereignisse in beiden Bereichen ausblenden."},{"key":"Windows event logs will be kept.","ru":"Журналы Windows сохранятся.","de":"Windows-Ereignisprotokolle bleiben erhalten."},{"key":"Wait for a successful event check.","ru":"Дождитесь успешной проверки событий.","de":"Erfolgreiche Ereignisprüfung abwarten."},{"key":"Could not save the event checkpoint.","ru":"Не удалось сохранить отметку очистки.","de":"Zeitpunkt konnte nicht gespeichert werden."},{"key":"Old events hidden. New events will appear automatically.","ru":"Старые события скрыты. Новые появятся автоматически.","de":"Alte Ereignisse ausgeblendet. Neue erscheinen automatisch."},{"key":"Events shown after last clear","ru":"События после очистки","de":"Ereignisse seit letzter Bereinigung"},{"key":"Old events are hidden in Dashboard only.","ru":"Старые события скрыты только в Dashboard.","de":"Alte Ereignisse sind nur im Dashboard ausgeblendet."},{"key":"Choose update file (.ps1)","ru":"Выбрать файл обновления (.ps1)","de":"Update-Datei auswählen (.ps1)"},{"key":"About NEX Dashboard","ru":"О NEX Dashboard","de":"Über NEX Dashboard"},{"key":"Version history","ru":"История обновлений","de":"Versionsverlauf"},{"key":"Recent release notes","ru":"Изменения последних версий","de":"Änderungen der letzten Versionen"},{"key":"Public Edition","ru":"Публичная версия","de":"Öffentliche Version"},{"key":"A customizable PowerShell dashboard for monitoring, tools and terminal appearance.","ru":"Настраиваемая панель PowerShell для мониторинга, инструментов и оформления терминала.","de":"Anpassbares PowerShell-Dashboard für Monitoring, Werkzeuge und Terminalgestaltung."},{"key":"Supports English, Russian and German.","ru":"Поддерживает английский, русский и немецкий языки.","de":"Unterstützt Englisch, Russisch und Deutsch."},{"key":"Local updates keep your personal settings.","ru":"Локальные обновления сохраняют ваши настройки.","de":"Lokale Updates behalten persönliche Einstellungen bei."},{"key":"After installation, reopen PowerShell to load the new version.","ru":"После установки откройте PowerShell заново, чтобы загрузить новую версию.","de":"Nach der Installation PowerShell neu öffnen, um die neue Version zu laden."},{"key":"Online releases are optional.","ru":"Онлайн-релизы необязательны.","de":"Online-Releases sind optional."},{"key":"Update from file","ru":"Обновить из файла","de":"Update aus Datei"},{"key":"Local update","ru":"Локальное обновление","de":"Lokales Update"},{"key":"Reordered navigation; direct local update button; About and changelog.","ru":"Упорядочено меню, добавлены кнопка установки из файла, сведения и история изменений.","de":"Navigation neu geordnet; direkte lokale Installation, Info und Versionsverlauf."},{"key":"Persistent clearing of displayed system events without deleting Windows logs.","ru":"Очистка отображаемых событий с сохранением журналов Windows.","de":"Angezeigte Ereignisse dauerhaft ausblenden, ohne Windows-Protokolle zu löschen."},{"key":"Computer-name visibility and alias; more prompt styles with previews.","ru":"Скрытие имени ПК, псевдоним и новые стили строки ввода с предпросмотром.","de":"Computername ein-/ausblenden, Alias und neue Prompt-Stile mit Vorschau."},{"key":"Detailed system events and notification descriptions.","ru":"Подробности системных событий и описания уведомлений.","de":"Details zu Systemereignissen und Benachrichtigungen."},{"key":"Improved Windows Game Mode detection.","ru":"Улучшено определение игрового режима Windows.","de":"Verbesserte Erkennung des Windows-Spielmodus."},{"key":"Clickable power plans and verified status indicators.","ru":"Кликабельные схемы питания и проверяемые индикаторы состояния.","de":"Anklickbare Energiesparpläne und geprüfte Statusanzeigen."},{"key":"Hardware, Gaming, Apps, Updates, Health and Notifications pages.","ru":"Разделы комплектующих, игр, приложений, обновлений, диагностики и уведомлений.","de":"Hardware-, Gaming-, App-, Update-, Systemzustands- und Benachrichtigungsseiten."},{"key":"Improved transition back to the startup screen.","ru":"Улучшен переход к стартовому экрану.","de":"Verbesserter Übergang zum Startbildschirm."},{"key":"Optional screen clearing and loading animation on return.","ru":"Настройки очистки и анимации при возврате.","de":"Optionale Bildschirmbereinigung und Ladeanimation bei Rückkehr."},{"key":"Expanded color themes, load gradients and settings cleanup.","ru":"Новые цветовые темы, градиенты нагрузки и упрощение настроек.","de":"Weitere Farbthemen, Lastfarbverläufe und bereinigte Einstellungen."},{"key":"Portable configuration export and restore.","ru":"Экспорт и восстановление конфигураций.","de":"Export und Wiederherstellung portabler Konfigurationen."},{"key":"Custom ASCII and Unicode startup logo editor.","ru":"Редактор собственного ASCII/Unicode-логотипа.","de":"Editor für eigene ASCII- und Unicode-Startlogos."},{"key":"Translation key compatibility fix for Windows PowerShell.","ru":"Исправлена совместимость ключей переводов с Windows PowerShell.","de":"Korrektur der Übersetzungsschlüssel für Windows PowerShell."},{"key":"Unified monitor cards and adaptive load colors.","ru":"Единые карточки монитора и цвета нагрузки.","de":"Einheitliche Monitorkarten und adaptive Lastfarben."},{"key":"More localization, DNS controls, icons and Fastfetch animation.","ru":"Расширенная локализация, DNS, иконки и анимация Fastfetch.","de":"Erweiterte Lokalisierung, DNS, Symbole und Fastfetch-Animation."},{"key":"Vendor hardware colors and Nerd Font icon recovery.","ru":"Цвета производителей комплектующих и восстановление иконок Nerd Font.","de":"Herstellerfarben und Wiederherstellung der Nerd-Font-Symbole."},{"key":"Restore Nerd Font in all terminal profiles?","ru":"Восстановить Nerd Font во всех профилях терминала?","de":"Nerd Font in allen Terminalprofilen wiederherstellen?"},{"key":"Icons restored. Reopen terminal tabs.","ru":"Иконки восстановлены. Откройте вкладки терминала заново.","de":"Symbole wiederhergestellt. Terminal-Tabs neu öffnen."},{"key":"Restore icons and font","ru":"Восстановить иконки и шрифт","de":"Symbole und Schrift wiederherstellen"},{"key":"Original monochrome Nerd Font icons restored without emoji fallback.","ru":"Возвращены оригинальные монохромные иконки Nerd Font без замены на эмодзи.","de":"Originale einfarbige Nerd-Font-Symbole ohne Emoji-Ersatz wiederhergestellt."},{"key":"Softer hardware colors, multicolor startup info and in-session updates.","ru":"Мягкие цвета комплектующих, разноцветный Fastfetch и обновление в текущей вкладке.","de":"Sanfte Hardwarefarben, mehrfarbige Startinformationen und Updates in derselben Sitzung."},{"key":"Local updates reload Dashboard in this terminal.","ru":"Локальные обновления перезагружают Dashboard в текущей вкладке.","de":"Lokale Updates laden das Dashboard in diesem Terminal neu."},{"key":"Update installed. Open Dashboard to see the new version.","ru":"Обновление установлено. Откройте Dashboard, чтобы увидеть новую версию.","de":"Update installiert. Dashboard öffnen, um die neue Version zu sehen."},{"key":"Update failed","ru":"Не удалось установить обновление","de":"Update fehlgeschlagen"},{"key":"Download and install update","ru":"Скачать и установить обновление","de":"Update herunterladen und installieren"},{"key":"Install official update","ru":"Установить официальное обновление","de":"Offizielles Update installieren"},{"key":"Download from the official GitHub repository?","ru":"Скачать из официального репозитория GitHub?","de":"Aus dem offiziellen GitHub-Repository herunterladen?"},{"key":"Downloading and verifying update...","ru":"Скачивание и проверка обновления...","de":"Update wird heruntergeladen und geprüft..."},{"key":"No published releases found.","ru":"Опубликованных релизов нет.","de":"Keine veröffentlichten Releases gefunden."},{"key":"Release installer or SHA-256 unavailable.","ru":"Установщик релиза или SHA-256 недоступен.","de":"Release-Installer oder SHA-256 nicht verfügbar."},{"key":"Update integrity check failed.","ru":"Проверка целостности обновления не пройдена.","de":"Integritätsprüfung des Updates fehlgeschlagen."},{"key":"Online update cancelled.","ru":"Онлайн-обновление отменено.","de":"Online-Update abgebrochen."},{"key":"Invalid update version.","ru":"Некорректная версия обновления.","de":"Ungültige Update-Version."},{"key":"Invalid update metadata.","ru":"Некорректные данные обновления.","de":"Ungültige Update-Metadaten."},{"key":"Manual update and information","ru":"Ручное обновление и информация","de":"Manuelles Update und Informationen"},{"key":"Official releases are checked before installation.","ru":"Официальные релизы проверяются перед установкой.","de":"Offizielle Releases werden vor der Installation geprüft."},{"key":"Official online updates with SHA-256 verification and beta release support.","ru":"Официальные онлайн-обновления с проверкой SHA-256 и поддержкой бета-релизов.","de":"Offizielle Online-Updates mit SHA-256-Prüfung und Beta-Unterstützung."},{"key":"Dashboard Designer","ru":"Дизайнер монитора","de":"Dashboard-Designer"},{"key":"Startup Manager","ru":"Автозагрузка","de":"Autostart-Manager"},{"key":"Plugin Manager","ru":"Модули","de":"Modulverwaltung"},{"key":"Animation Studio","ru":"Студия анимаций","de":"Animationsstudio"},{"key":"Search Dashboard","ru":"Поиск по Dashboard","de":"Dashboard durchsuchen"},{"key":"Type to filter; Enter opens the selected result.","ru":"Введите запрос; Enter открывает выбранный раздел.","de":"Tippen zum Filtern; Enter öffnet den gewählten Bereich."},{"key":"Setting explanations","ru":"Объяснения настроек","de":"Einstellungserklärungen"},{"key":"Ctrl+K: search | F1: help | Esc: back","ru":"Ctrl+K: поиск | F1: помощь | Esc: назад","de":"Strg+K: Suche | F1: Hilfe | Esc: zurück"},{"key":"Monitor designer, startup manager, global search, optional modules, animation studio and setting explanations.","ru":"Дизайнер монитора, автозагрузка, поиск, модули, студия анимаций и пояснения настроек.","de":"Monitor-Designer, Autostart, globale Suche, Module, Animationen und Einstellungshilfe."},{"key":"Choose monitor columns","ru":"Выбрать колонки","de":"Spalten wählen"},{"key":"Columns","ru":"Колонки","de":"Spalten"},{"key":"Auto","ru":"Автоматически","de":"Automatisch"},{"key":"Single column","ru":"Одна колонка","de":"Eine Spalte"},{"key":"Two columns","ru":"Две колонки","de":"Zwei Spalten"},{"key":"Move card up","ru":"Поднять карточку","de":"Karte nach oben"},{"key":"Move card down","ru":"Опустить карточку","de":"Karte nach unten"},{"key":"Show or hide card","ru":"Показать или скрыть карточку","de":"Karte ein-/ausblenden"},{"key":"Choose monitor card","ru":"Выбрать карточку","de":"Monitorkarte wählen"},{"key":"Preview monitor","ru":"Предпросмотр монитора","de":"Monitorvorschau"},{"key":"Reset layout","ru":"Сбросить расположение","de":"Layout zurücksetzen"},{"key":"Card order","ru":"Порядок карточек","de":"Kartenreihenfolge"},{"key":"Arrange the System Monitor cards. Click a card to show or hide it.","ru":"Настройте карточки монитора. Нажмите на карточку, чтобы скрыть или показать её.","de":"Monitorkarten anordnen. Anklicken zum Ein- oder Ausblenden."},{"key":"Keep at least one monitor card visible.","ru":"Оставьте хотя бы одну карточку.","de":"Mindestens eine Karte muss sichtbar bleiben."},{"key":"Windows Startup Apps","ru":"Автозагрузка Windows","de":"Windows-Autostart-Apps"},{"key":"Open user startup folder","ru":"Открыть папку автозагрузки пользователя","de":"Benutzer-Autostartordner öffnen"},{"key":"Open shared startup folder","ru":"Открыть общую папку автозагрузки","de":"Gemeinsamen Autostartordner öffnen"},{"key":"Use Windows Startup Apps to enable or disable entries.","ru":"Включайте и отключайте приложения в настройках автозагрузки Windows.","de":"Apps in den Windows-Autostarteinstellungen aktivieren oder deaktivieren."},{"key":"This list is read-only and may not include all disabled apps or scheduled tasks.","ru":"Список только для чтения; не все отключённые приложения и задачи отображаются.","de":"Liste nur lesbar; nicht alle deaktivierten Apps und Aufgaben sind enthalten."},{"key":"Detected startup commands","ru":"Найденные команды автозагрузки","de":"Gefundene Autostartbefehle"},{"key":"Startup command","ru":"Команда автозагрузки","de":"Autostartbefehl"},{"key":"No startup commands found.","ru":"Команды автозагрузки не найдены.","de":"Keine Autostartbefehle gefunden."},{"key":"Built-in modules add widgets to the header. No external scripts are executed.","ru":"Встроенные модули добавляют виджеты в верхнюю панель. Внешние скрипты не запускаются.","de":"Integrierte Module ergänzen die Kopfzeile. Externe Skripte werden nicht ausgeführt."},{"key":"Battery module","ru":"Модуль батареи","de":"Akkumodul"},{"key":"Session module","ru":"Модуль сеанса","de":"Sitzungsmodul"},{"key":"Shortcut module","ru":"Модуль ярлыков","de":"Verknüpfungsmodul"},{"key":"Shows battery charge and power status in the header on supported PCs.","ru":"Показывает заряд и питание в верхней панели на ПК с аккумулятором.","de":"Zeigt Akkustand und Stromversorgung in der Kopfzeile auf unterstützten PCs."},{"key":"Shows elapsed Dashboard session time in the header.","ru":"Показывает длительность сеанса Dashboard в верхней панели.","de":"Zeigt die Sitzungsdauer in der Kopfzeile."},{"key":"Adds header shortcuts to App Launcher and Dashboard Designer.","ru":"Добавляет в верхнюю панель кнопки запуска приложений и дизайнера.","de":"Ergänzt Schnellzugriffe auf App-Starter und Designer in der Kopfzeile."},{"key":"Module preview","ru":"Предпросмотр модулей","de":"Modulvorschau"},{"key":"Battery information unavailable","ru":"Данные батареи недоступны","de":"Akkuinformationen nicht verfügbar"},{"key":"No system battery","ru":"Батарея отсутствует","de":"Kein Systemakku"},{"key":"Online","ru":"От сети","de":"Netzbetrieb"},{"key":"Offline","ru":"От батареи","de":"Akkubetrieb"},{"key":"Choose loading animation","ru":"Выбрать анимацию загрузки","de":"Ladeanimation wählen"},{"key":"Choose animation speed","ru":"Выбрать скорость анимации","de":"Animationsgeschwindigkeit wählen"},{"key":"Animation","ru":"Анимация","de":"Animation"},{"key":"Speed","ru":"Скорость","de":"Geschwindigkeit"},{"key":"Progress","ru":"Полоса","de":"Fortschritt"},{"key":"Pulse","ru":"Импульс","de":"Impuls"},{"key":"Wave","ru":"Волна","de":"Welle"},{"key":"Dots","ru":"Точки","de":"Punkte"},{"key":"Fast","ru":"Быстро","de":"Schnell"},{"key":"Normal","ru":"Обычно","de":"Normal"},{"key":"Slow","ru":"Медленно","de":"Langsam"},{"key":"Preview loading animation","ru":"Предпросмотр загрузки","de":"Ladeanimation ansehen"},{"key":"Reset animations","ru":"Сбросить анимации","de":"Animationen zurücksetzen"},{"key":"Speed changes loading and Fastfetch reveal. Preview does not restart the terminal.","ru":"Скорость влияет на загрузку и появление Fastfetch. Предпросмотр не перезапускает терминал.","de":"Tempo gilt für Ladebildschirm und Fastfetch. Vorschau ohne Terminalneustart."},{"key":"Help","ru":"Помощь","de":"Hilfe"},{"key":"Search Dashboard with Ctrl+K. Tab switches between navigation and content. Esc returns to Overview or the shell.","ru":"Ctrl+K — поиск. Tab — переключение меню и содержимого. Esc — возврат в Обзор или терминал.","de":"Strg+K: Suche. Tab wechselt Navigation und Inhalt. Esc kehrt zur Übersicht oder Shell zurück."},{"key":"Changes the language of the Dashboard interface.","ru":"Меняет язык интерфейса Dashboard.","de":"Ändert die Oberflächensprache."},{"key":"Changes your displayed name, not the Windows account.","ru":"Меняет отображаемое имя, не учётную запись Windows.","de":"Ändert den Anzeigenamen, nicht das Windows-Konto."},{"key":"Shows or hides @computer in the prompt and startup info.","ru":"Показывает или скрывает @имя ПК в строке ввода и Fastfetch.","de":"Zeigt oder verbirgt @Computer in Prompt und Startinfo."},{"key":"Sets a custom computer alias without renaming Windows.","ru":"Задаёт псевдоним ПК без переименования в Windows.","de":"Legt einen Alias fest, ohne Windows umzubenennen."},{"key":"Changes the color palette of Dashboard and the terminal.","ru":"Меняет цветовую палитру Dashboard и терминала.","de":"Ändert die Farbpalette von Dashboard und Terminal."},{"key":"Sets your own accent color using a six-digit HEX code.","ru":"Задаёт свой акцентный цвет через шестизначный HEX-код.","de":"Legt eine eigene Akzentfarbe per sechsstelligem HEX-Code fest."},{"key":"Shows a loading animation when the shell starts.","ru":"Показывает анимацию загрузки при запуске оболочки.","de":"Zeigt beim Shellstart eine Ladeanimation."},{"key":"Clears visible output on return; command history is preserved.","ru":"Очищает видимый вывод при возврате; история команд сохраняется.","de":"Löscht beim Zurückkehren die sichtbare Ausgabe, nicht den Verlauf."},{"key":"Shows a loading animation when leaving Dashboard.","ru":"Показывает анимацию при выходе из Dashboard.","de":"Zeigt eine Ladeanimation beim Verlassen des Dashboards."},{"key":"Displays hardware and software information at shell startup.","ru":"Показывает информацию о ПК при запуске оболочки.","de":"Zeigt Hardware- und Softwareinfos beim Shellstart."},{"key":"Reveals startup information line by line.","ru":"Показывает стартовую информацию построчно.","de":"Blendet Startinformationen zeilenweise ein."},{"key":"Selects the layout used for startup hardware information.","ru":"Выбирает оформление стартовой информации о ПК.","de":"Wählt das Layout der Startinformationen."},{"key":"Edits the ASCII logo. Save an empty editor to restore the default.","ru":"Редактирует ASCII-логотип. Пустой редактор возвращает стандартный.","de":"Bearbeitet das ASCII-Logo. Leer speichern stellt den Standard wieder her."},{"key":"Changes the appearance of the PowerShell command prompt.","ru":"Меняет внешний вид строки ввода PowerShell.","de":"Ändert das Aussehen der PowerShell-Eingabeaufforderung."},{"key":"Enables monochrome Nerd Font icons. A compatible font is required.","ru":"Включает монохромные значки Nerd Font. Нужен совместимый шрифт.","de":"Aktiviert einfarbige Nerd-Font-Symbole; passende Schrift erforderlich."},{"key":"Enables history-based suggestions when PSReadLine supports them.","ru":"Включает подсказки из истории, если их поддерживает PSReadLine.","de":"Aktiviert Verlaufsvorschläge, sofern PSReadLine sie unterstützt."},{"key":"Labels your internet access type; it does not change networking.","ru":"Задаёт подпись типа интернета, не изменяя сеть.","de":"Beschriftet den Internetzugang, ändert keine Netzwerkeinstellungen."},{"key":"Repairs the Nerd Font installation and applies it to terminal profiles.","ru":"Восстанавливает Nerd Font и применяет его к профилям терминала.","de":"Repariert Nerd Font und wendet ihn auf Terminalprofile an."},{"key":"Applies the selected palette to Windows Terminal profiles.","ru":"Применяет выбранную палитру к профилям Windows Terminal.","de":"Wendet die Palette auf Windows-Terminal-Profile an."},{"key":"Shows a preview of the startup information.","ru":"Показывает предпросмотр стартовой информации.","de":"Zeigt eine Vorschau der Startinformationen."},{"key":"Changes individual native terminal colors.","ru":"Меняет отдельные цвета терминала.","de":"Ändert einzelne native Terminalfarben."},{"key":"Selects a Windows Terminal color scheme.","ru":"Выбирает цветовую схему Windows Terminal.","de":"Wählt ein Windows-Terminal-Farbschema."},{"key":"Exports portable personalization settings to a file.","ru":"Сохраняет переносимые настройки в файл.","de":"Exportiert portable Einstellungen in eine Datei."},{"key":"Restores personalization from a configuration file.","ru":"Восстанавливает персонализацию из файла конфигурации.","de":"Stellt Einstellungen aus einer Konfigurationsdatei wieder her."},{"key":"Shows explanations in setting selection dialogs.","ru":"Показывает пояснения в окнах выбора настроек.","de":"Zeigt Erläuterungen in den Einstellungsdialogen."},{"key":"Selects the Windows Terminal profile to inspect.","ru":"Выбирает профиль Windows Terminal для просмотра.","de":"Wählt das zu prüfende Windows-Terminal-Profil."},{"key":"Controls terminal opacity: 100 percent is fully opaque.","ru":"Настраивает прозрачность терминала: 100% — непрозрачный.","de":"Regelt die Deckkraft: 100 Prozent ist undurchsichtig."},{"key":"Toggles the acrylic blur effect where Windows supports it.","ru":"Включает размытие Acrylic, если Windows его поддерживает.","de":"Schaltet den Acrylic-Weichzeichner ein oder aus."},{"key":"Changes the shape of the text cursor.","ru":"Меняет форму текстового курсора.","de":"Ändert die Form des Textcursors."},{"key":"Opens the native Windows Terminal JSON settings file.","ru":"Открывает родной JSON-файл настроек Windows Terminal.","de":"Öffnet die native Windows-Terminal-JSON-Datei."},{"key":"Reloads terminal settings from disk.","ru":"Перечитывает настройки терминала с диска.","de":"Lädt Terminaleinstellungen erneut von der Festplatte."},{"key":"AC power","ru":"Питание от сети","de":"Netzbetrieb"},{"key":"Battery power","ru":"Питание от батареи","de":"Akkubetrieb"},{"key":"Power source unknown","ru":"Источник питания неизвестен","de":"Stromquelle unbekannt"},{"key":"No matching sections. Change the search text.","ru":"Ничего не найдено. Измените запрос.","de":"Keine Treffer. Suchtext ändern."},{"key":"No modules enabled","ru":"Модули не включены","de":"Keine Module aktiviert"},{"key":"Select a Windows power plan. Balanced is recommended for most systems.","ru":"Выберите схему питания Windows. Сбалансированная подходит большинству ПК.","de":"Energiesparplan wählen. Ausbalanciert wird für die meisten PCs empfohlen."},{"key":"Select the card to move or show and hide.","ru":"Выберите карточку для перемещения или изменения видимости.","de":"Karte zum Verschieben oder Ein-/Ausblenden wählen."},{"key":"Select the startup and return loading animation.","ru":"Выберите анимацию при запуске и возврате из Dashboard.","de":"Animation für Start und Rückkehr auswählen."},{"key":"One column is full-width; two columns adapt to the terminal size.","ru":"Одна колонка на всю ширину; две колонки подстраиваются под размер окна.","de":"Eine Spalte nutzt die Breite; zwei Spalten passen sich der Fenstergröße an."},{"key":"Continue","ru":"Продолжить","de":"Weiter"},{"key":"Apps","ru":"Приложения","de":"Apps"},{"key":"Layout","ru":"Макет","de":"Layout"},{"key":"Apply","ru":"Применить","de":"Anwenden"},{"key":"One line","ru":"Одна строка","de":"Eine Zeile"},{"key":"Two lines","ru":"Две строки","de":"Zwei Zeilen"},{"key":"Prompt styles","ru":"Стили строки ввода","de":"Prompt-Stile"},{"key":"Click to preview","ru":"Нажмите для просмотра","de":"Klicken für Vorschau"},{"key":"Current style","ru":"Текущий стиль","de":"Aktueller Stil"},{"key":"Enter: Apply | Esc: Cancel","ru":"Enter: применить | Esc: отмена","de":"Enter: Anwenden | Esc: Abbrechen"},{"key":"Install optional Ookla Speedtest CLI for personal use?","ru":"Установить необязательный Ookla Speedtest для личного использования?","de":"Optionalen Ookla Speedtest CLI für den privaten Gebrauch installieren?"},{"key":"Downloading and verifying Ookla Speedtest...","ru":"Скачивание и проверка Ookla Speedtest...","de":"Ookla Speedtest wird heruntergeladen und geprüft..."},{"key":"Ookla Speedtest installed.","ru":"Ookla Speedtest установлен.","de":"Ookla Speedtest installiert."},{"key":"Speedtest installation failed","ru":"Не удалось установить Speedtest","de":"Speedtest-Installation fehlgeschlagen"},{"key":"Install Ookla Speedtest?","ru":"Установить Ookla Speedtest?","de":"Ookla Speedtest installieren?"},{"key":"Official download for personal use.","ru":"Официальная загрузка для личного использования.","de":"Offizieller Download für den privaten Gebrauch."},{"key":"No administrator rights required.","ru":"Права администратора не нужны.","de":"Keine Administratorrechte erforderlich."},{"key":"Accept Ookla terms for personal use?","ru":"Принять условия Ookla для личного использования?","de":"Ookla-Bedingungen für den privaten Gebrauch akzeptieren?"},{"key":"Accept Ookla privacy notice?","ru":"Принять политику конфиденциальности Ookla?","de":"Ookla-Datenschutzhinweise akzeptieren?"},{"key":"A test sends connection data to Ookla.","ru":"Тест отправляет данные подключения в Ookla.","de":"Der Test sendet Verbindungsdaten an Ookla."},{"key":"Download and install Ookla Speedtest","ru":"Скачать и установить Ookla Speedtest","de":"Ookla Speedtest herunterladen und installieren"},{"key":"Speedtest failed. Try again.","ru":"Ошибка Speedtest. Повторите попытку.","de":"Speedtest fehlgeschlagen. Erneut versuchen."},{"key":"Optional Ookla Speedtest installation and first-test consent.","ru":"Необязательная установка Ookla Speedtest и согласие перед первым тестом.","de":"Optionale Ookla-Speedtest-Installation und Zustimmung vor dem ersten Test."},{"key":"Yes","ru":"Да","de":"Ja"},{"key":"No","ru":"Нет","de":"Nein"},{"key":"Windows Update restart","ru":"Перезапуск для Windows Update","de":"Neustart für Windows Update"},{"key":"Servicing restart marker","ru":"Маркер перезапуска обслуживания","de":"Neustartmarker der Wartung"},{"key":"Restart marker detected","ru":"Обнаружен маркер перезапуска","de":"Neustartmarker erkannt"},{"key":"Restart source unavailable","ru":"Источник перезапуска недоступен","de":"Neustartquelle nicht verfügbar"},{"key":"Windows Update requires restart","ru":"Windows Update требует перезапуск","de":"Windows Update erfordert Neustart"},{"key":"Local connection","ru":"Локальное подключение","de":"Lokale Verbindung"},{"key":"Ethernet","ru":"Ethernet","de":"Ethernet"},{"key":"Wi-Fi","ru":"Wi-Fi","de":"WLAN"},{"key":"Mobile network","ru":"Мобильная сеть","de":"Mobilfunk"},{"key":"Other adapter","ru":"Другой адаптер","de":"Anderer Adapter"},{"key":"Identity and language","ru":"Имя и язык","de":"Identität und Sprache"},{"key":"Colors and appearance","ru":"Цвета и оформление","de":"Farben und Darstellung"},{"key":"Startup and transitions","ru":"Запуск и переходы","de":"Start und Übergänge"},{"key":"Startup information","ru":"Информация при запуске","de":"Startinformationen"},{"key":"Prompt and input","ru":"Строка ввода и подсказки","de":"Eingabe und Vorschläge"},{"key":"Terminal appearance and backup","ru":"Оформление терминала и резервные копии","de":"Terminaldesign und Sicherung"},{"key":"I/O","ru":"Ввод/вывод","de":"E/A"},{"key":"TCP","ru":"TCP","de":"TCP"},{"key":"Process metrics","ru":"Показатели процессов","de":"Prozessmetriken"},{"key":"I/O includes file, device and network operations; TCP is connection count, not speed.","ru":"I/O включает файлы, устройства и сеть; TCP — число соединений, не скорость.","de":"E/A umfasst Dateien, Geräte und Netzwerk; TCP ist die Verbindungszahl, keine Geschwindigkeit."},{"key":"Processes sampled","ru":"Процессов измерено","de":"Erfasste Prozesse"},{"key":"GPU %","ru":"GPU %","de":"GPU %"},{"key":"I/O MiB/s","ru":"I/O МиБ/с","de":"E/A MiB/s"},{"key":"TCP count","ru":"TCP (шт.)","de":"TCP-Anzahl"},{"key":"Sidebar separators","ru":"Разделители меню","de":"Menü-Trennlinien"},{"key":"Show horizontal separators between sidebar groups.","ru":"Показывает горизонтальные линии между группами бокового меню.","de":"Zeigt horizontale Trennlinien zwischen Menügruppen."}]
'@ | ConvertFrom-Json
$global:NexPublicDictionary = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::Ordinal)
$global:NexPublicDictionaryFallback = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($nexTranslationEntry in $nexTranslationEntries) {
    $nexTranslationKey = [string]$nexTranslationEntry.key
    $global:NexPublicDictionary.Add($nexTranslationKey,$nexTranslationEntry)
    if (-not $global:NexPublicDictionaryFallback.ContainsKey($nexTranslationKey) -or $nexTranslationKey -cne $nexTranslationKey.ToUpperInvariant()) {
        $global:NexPublicDictionaryFallback[$nexTranslationKey] = $nexTranslationEntry
    }
}
$global:NexPersonalHelp=@{'L'='Changes the language of the Dashboard interface.';'N'='Changes your displayed name, not the Windows account.';'M'='Shows or hides @computer in the prompt and startup info.';'D'='Sets a custom computer alias without renaming Windows.';'H'='Changes the color palette of Dashboard and the terminal.';'X'='Sets your own accent color using a six-digit HEX code.';'B'='Shows a loading animation when the shell starts.';'C'='Clears visible output on return; command history is preserved.';'U'='Shows a loading animation when leaving Dashboard.';'F'='Displays hardware and software information at shell startup.';'J'='Reveals startup information line by line.';'V'='Selects the layout used for startup hardware information.';'K'='Edits the ASCII logo. Save an empty editor to restore the default.';'P'='Changes the appearance of the PowerShell command prompt.';'I'='Enables monochrome Nerd Font icons. A compatible font is required.';'Q'='Enables history-based suggestions when PSReadLine supports them.';'A'='Show horizontal separators between sidebar groups.';'O'='Repairs the Nerd Font installation and applies it to terminal profiles.';'Y'='Applies the selected palette to Windows Terminal profiles.';'E'='Shows a preview of the startup information.';'Z'='Changes individual native terminal colors.';'T'='Selects a Windows Terminal color scheme.';'S'='Exports portable personalization settings to a file.';'R'='Restores personalization from a configuration file.';'G'='Shows explanations in setting selection dialogs.'}
$global:NexTerminalHelp=@{'G'='Selects the Windows Terminal profile to inspect.';'O'='Controls terminal opacity: 100 percent is fully opaque.';'A'='Toggles the acrylic blur effect where Windows supports it.';'C'='Changes the shape of the text cursor.';'J'='Opens the native Windows Terminal JSON settings file.';'R'='Reloads terminal settings from disk.'}
$global:NexDialogHelp=@{'Choose language'='Changes the language of the Dashboard interface.';'Enter display name'='Changes your displayed name, not the Windows account.';'Enter computer alias'='Sets a custom computer alias without renaming Windows.';'Choose theme'='Changes the color palette of Dashboard and the terminal.';'RGB HEX (#RRGGBB)'='Sets your own accent color using a six-digit HEX code.';'Choose fetch preset'='Selects the layout used for startup hardware information.';'Choose prompt style'='Changes the appearance of the PowerShell command prompt.';'Choose access type'='Labels your internet access type; it does not change networking.';'Opacity 0-100 (%)'='Controls terminal opacity: 100 percent is fully opaque.';'Choose cursor shape'='Changes the shape of the text cursor.';'Choose an existing color scheme'='Selects a Windows Terminal color scheme.';'Choose monitor columns'='Arrange the System Monitor cards. Click a card to show or hide it.';'Choose animation speed'='Speed changes loading and Fastfetch reveal. Preview does not restart the terminal.';'Choose power plan'='Select a Windows power plan. Balanced is recommended for most systems.';'Choose monitor card'='Select the card to move or show and hide.';'Choose loading animation'='Select the startup and return loading animation.'}
function global:NexL([string]$text) {
    if ($global:NexPublicSettings.Language -eq 'en') {return $text}
    $entry=$null
    if ($global:NexPublicDictionary.ContainsKey($text)) { $entry=$global:NexPublicDictionary[$text] }
    elseif ($global:NexPublicDictionaryFallback.ContainsKey($text)) { $entry=$global:NexPublicDictionaryFallback[$text] }
    if ($entry) { $v=$entry.PSObject.Properties[$global:NexPublicSettings.Language]; if ($v) {return [string]$v.Value} }
    if ($text -match '^(\[[^\]]+\])\s+(.+)$') {return ($Matches[1]+' '+(NexL $Matches[2]))}
    if ($text -match '^\[ (.+) \]$') {return ('[ '+(NexL $Matches[1])+' ]')}
    return $text
}
function global:Normalize-NexLogo([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) {return ''}
    $text=$text.Replace("`r`n","`n").Replace("`r","`n").Replace("`t",'    ')
    if ($text -match '[\x00-\x09\x0B-\x1F\x7F-\x9F\u202A-\u202E\u2066-\u2069]') {throw (NexL 'Logo must contain printable text only.')}
    try {$null=([Text.UTF8Encoding]::new($false,$true)).GetByteCount($text)} catch {throw (NexL 'Logo must contain printable text only.')}
    $lines=@($text -split "`n")
    # Preserve indentation and internal empty lines; ignore trailing empty editor lines.
    while ($lines.Count -gt 1 -and [string]::IsNullOrWhiteSpace($lines[-1])) {$lines=@($lines | Select-Object -First ($lines.Count-1))}
    if ($lines.Count -gt 80) {throw (NexL 'Logo limit: 80 lines, 120 characters per line.')}
    foreach ($line in $lines) {if ($line.Length -gt 120) {throw (NexL 'Logo limit: 80 lines, 120 characters per line.')}}
    return ($lines -join "`n")
}
function global:Get-NexLogoWidth([string]$line) {
    $width=0
    $it=[Globalization.StringInfo]::GetTextElementEnumerator($line)
    while ($it.MoveNext()) {
        $element=$it.GetTextElement(); $cp=[char]::ConvertToUtf32($element,0)
        if (($cp -ge 0x1100 -and $cp -le 0x115F) -or ($cp -ge 0x2E80 -and $cp -le 0xA4CF) -or ($cp -ge 0xAC00 -and $cp -le 0xD7A3) -or ($cp -ge 0xF900 -and $cp -le 0xFAFF) -or ($cp -ge 0xFF00 -and $cp -le 0xFF60) -or ($cp -ge 0x1F300 -and $cp -le 0x1FAFF) -or $cp -ge 0x20000) {$width+=2}
        else {$width++}
    }
    return $width
}
function global:Get-NexThemeNames {
    @('Pink','Lavender','Blue','Mint','Amber','Mono','Crimson Eclipse','Blood Moon','Ember Forge','Solar Flare','Ivory Frost','Obsidian','Glacier','Ocean Depths','Midnight Aurora','Cyber Pulse','Violet Nebula','Cherry Blossom','Rose Quartz','Peach Sunset','Forest Spirit','Emerald Circuit','Acid Lime','Golden Hour','Copper Dusk','Sapphire Night','Storm Grey','Arcade Neon','Polar Dawn','Lavender Haze','Raspberry Ink','Custom')
}
function global:Get-NexPromptStyles {
    @('Rounded','Compact','Powerline','Minimal','Classic','Aurora','Circuit','Metro','Orbit','Zen','Terminal Pro','Pixel','Twin Line','Soft Wave','Keep existing')
}
function global:Normalize-NexIdentityPart([string]$value) {
    $value=($value -replace '[\x00-\x1F\x7F-\x9F\u202A-\u202E\u2066-\u2069]','').Trim()
    if ($value.Length -gt 32) {$value=$value.Substring(0,32)}
    if ($value.Length -and [char]::IsHighSurrogate($value[$value.Length-1])) {$value=$value.Substring(0,$value.Length-1)}
    return $value
}
function global:Get-NexIdentity {
    $c=$global:NexPublicSettings
    $name=Normalize-NexIdentityPart (Get-NexName)
    if (-not $c.ShowComputerName) {return $name}
    $computer=Normalize-NexIdentityPart $c.ComputerAlias
    if (-not $computer) {$computer=Normalize-NexIdentityPart $env:COMPUTERNAME}
    if ($computer) {return ($name+'@'+$computer)}
    return $name
}
function global:Get-NexPromptLines([string]$style,[string]$identity,[string]$path,[string]$time,[bool]$ok,[string]$duration='',[bool]$icons=$false) {
    $p=Get-NexPalette;$a=NexAnsi $p[0];$b=NexAnsi $p[1];$w=NexAnsi $p[4];$m=NexAnsi $p[5];$z="$([char]27)[0m"
    $status=if ($ok) {"$(NexAnsi 'A6E3A1')✓$z"} else {"$(NexAnsi 'F38BA8')×$z"}
    $u=if ($icons) {([string][char]0xF007)+' '} else {''};$f=if ($icons) {([string][char]0xF07B)+' '} else {''}
    switch ($style) {
        'Classic' { "PS $path> " }
        'Minimal' { "$a❯$z " }
        'Compact' { "$a$identity $b$path $status$z ❯ " }
        'Powerline' { "${a}[$u$identity]${b}[$f$path]${a}[$time]$z ❯ " }
        'Aurora' { "$a╭── $u$identity $m· $b$f$path $m· $w$time $status$a$duration$z"; "$b╰─ ✧ ❯$z " }
        'Circuit' { "$a┌─[$u$identity]$m──$b[$f$path]$m──$w[$time] $status$a$duration$z"; "$a└─›$z " }
        'Metro' { "$a▌$u$identity $m│ $b$f$path $m│ $w$time $status $a❯$z " }
        'Orbit' { "$a◉ $u$identity $m· $b$f$path $m· $w$time $status $b➜$z " }
        'Zen' { "$a$identity $m/ $b$path $status $a›$z " }
        'Terminal Pro' { "$a$u$identity $m[$w$time$m] $b$f$path $status$a$duration$z"; "$aλ$z " }
        'Pixel' { "$a■ $u$identity $m│ $b■ $f$path $m│ $w$time $status $a▸$z " }
        'Twin Line' { "$a╔═ $u$identity $b$f$path $m│ $w$time $status$a$duration$z"; "$a╚═»$z " }
        'Soft Wave' { "$a╭─ $u$identity $m~ $b$f$path $m~ $w$time $status$a$duration$z"; "$b╰─ ❀ ›$z " }
        'Keep existing' { "PS $path> " }
        default { "$a╭─ $b$u$identity $a│ $f$path │ $time │ $status$a$duration$z"; "$a╰── ❯$z " }
    }
}
function global:Normalize-NexExtras($o) {
    $cards=@('Processor','Graphics','Memory','Storage','Network','System')
    $d=@{MonitorOrder=($cards -join ',');MonitorHidden='';MonitorColumns='Auto';LoadingStyle='Progress';AnimationSpeed='Normal';SettingHelp=$true;SidebarSeparators=$true;ModuleBattery=$false;ModuleSession=$false;ModuleShortcuts=$false}
    $order=@(([string]$o.MonitorOrder -split ',') | Where-Object {$_ -cin $cards} | Select-Object -Unique)
    if ($order.Count -eq $cards.Count) {$d.MonitorOrder=$order -join ','}
    $hidden=@(([string]$o.MonitorHidden -split ',') | Where-Object {$_ -cin $cards} | Select-Object -Unique)
    if ($hidden.Count -lt $cards.Count) {$d.MonitorHidden=$hidden -join ','}
    foreach ($k in @('MonitorColumns','LoadingStyle','AnimationSpeed')) {
        $allowed=@{MonitorColumns=@('Auto','Single column','Two columns');LoadingStyle=@('Progress','Pulse','Wave','Dots','Minimal');AnimationSpeed=@('Fast','Normal','Slow')}[$k]
        if ($o.$k -is [string] -and $o.$k -cin $allowed) {$d[$k]=$o.$k}
    }
    foreach ($k in @('SettingHelp','SidebarSeparators','ModuleBattery','ModuleSession','ModuleShortcuts')) {if ($o.$k -is [bool]) {$d[$k]=$o.$k}}
    return $d
}
function global:Get-NexPreferences {
    $defaults=@{MonitorOrder='Processor,Graphics,Memory,Storage,Network,System';MonitorHidden='';MonitorColumns='Auto';LoadingStyle='Progress';AnimationSpeed='Normal';SettingHelp=$true;SidebarSeparators=$true;ModuleBattery=$false;ModuleSession=$false;ModuleShortcuts=$false;Language='en';Name='';ShowComputerName=$true;ComputerAlias='';Theme='Pink';Accent='F5C2E7';Startup=$true;ClearOnReturn=$true;LoadingOnReturn=$false;Fetch=$true;FetchAnimation=$true;FetchPreset='Cards';CustomLogo='';Prompt='Rounded';Icons=$true;Prediction='History';Access='Unknown';ReleaseRepo='owoNEXowo/NEX-Dashboard'}
    $p=Join-Path $env:LOCALAPPDATA 'NexDashboard\preferences.json'
    if (Test-Path -LiteralPath $p) {try {
        $o=[IO.File]::ReadAllText($p) | ConvertFrom-Json -ErrorAction Stop
        foreach ($k in @($defaults.Keys)) {if ($o.PSObject.Properties[$k] -and $null -ne $o.$k) {$defaults[$k]=$o.$k}}
    } catch {}}
    if ($defaults.Language -notin @('en','ru','de')) {$defaults.Language='en'}
    if ($defaults.Theme -notin @(Get-NexThemeNames)) {$defaults.Theme='Pink'}
    if ($defaults.Accent -notmatch '^[0-9A-Fa-f]{6}$') {$defaults.Accent='F5C2E7'}
    if ($defaults.Prompt -notin @(Get-NexPromptStyles)) {$defaults.Prompt='Rounded'}
    if ($defaults.FetchPreset -notin @('Cards','Compact','Minimal','Neon Frame','Color Labels','Tree Layout','Studio','Fastfetch classic','Fastfetch custom')) {$defaults.FetchPreset='Cards'}
    if ($defaults.Prediction -notin @('None','History')) {$defaults.Prediction='History'}
    foreach ($k in @('Startup','Fetch','FetchAnimation','Icons')) {if ($defaults[$k] -isnot [bool]) {$defaults[$k]=$true}}
    if ($defaults.ShowComputerName -isnot [bool]) {$defaults.ShowComputerName=$true}
    $defaults.ComputerAlias=Normalize-NexIdentityPart ([string]$defaults.ComputerAlias)
    if ($defaults.ClearOnReturn -isnot [bool]) {$defaults.ClearOnReturn=$true}
    if ($defaults.LoadingOnReturn -isnot [bool]) {$defaults.LoadingOnReturn=$false}
    $defaults.ReleaseRepo='owoNEXowo/NEX-Dashboard'
    $defaults.CustomLogo=[string]$defaults.CustomLogo
    try {$defaults.CustomLogo=Normalize-NexLogo $defaults.CustomLogo} catch {$defaults.CustomLogo=''}
    $defaults.Name=([string]$defaults.Name -replace '[\x00-\x1F\x7F-\x9F]','').Trim()
    if ($defaults.Name.Length -gt 32) {$defaults.Name=$defaults.Name.Substring(0,32)}
    $extra=Normalize-NexExtras $defaults;foreach ($k in $extra.Keys) {$defaults[$k]=$extra[$k]}
    return $defaults
}
$global:NexPublicSettings=Get-NexPreferences
function global:Save-NexPreferences {
    $p=Join-Path $env:LOCALAPPDATA 'NexDashboard\preferences.json'
    $null=New-Item -ItemType Directory -Path (Split-Path $p) -Force
    $tmp=$p+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try {
        [IO.File]::WriteAllText($tmp,($global:NexPublicSettings | ConvertTo-Json -Depth 4),(New-Object System.Text.UTF8Encoding($true)))
        if (Test-Path -LiteralPath $p) {[IO.File]::Replace($tmp,$p,[System.Management.Automation.Language.NullString]::Value)} else {[IO.File]::Move($tmp,$p)}
    } finally {if (Test-Path -LiteralPath $tmp) {Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}}
}
function global:Get-NexName {if ($global:NexPublicSettings.Name) {return $global:NexPublicSettings.Name}; return $env:USERNAME}
function global:Get-NexPalette([string]$theme=$global:NexPublicSettings.Theme) {
    $colors=@{
        'Pink'=@('F5C2E7','CBA6F7','45314F','181825','CDD6F4','A6A4BF')
        'Lavender'=@('CBA6F7','B4BEFE','3B3058','1E1E2E','E0DEF4','A6A0BF')
        'Blue'=@('89B4FA','74C7EC','273953','111827','DCE9FF','99ADC6')
        'Mint'=@('A6E3A1','94E2D5','25453D','10221E','DDF5E7','9CBBAF')
        'Amber'=@('FAB387','F9E2AF','503B2E','211810','FCE9D5','C2AE99')
        'Mono'=@('E5E7EB','9CA3AF','404040','181818','F2F2F2','B2B2B2')
        'Crimson Eclipse'=@('FF657A','FF9B92','542735','1D1018','FFE3E8','C9A0AA')
        'Blood Moon'=@('FCA5A5','F472B6','542833','1F1118','FDE6ED','C8A4AE')
        'Ember Forge'=@('FF9E45','FFD17A','593520','21160F','FFF0D9','C7AC91')
        'Solar Flare'=@('FFD166','FF9A62','524120','201B10','FFF2CD','C7B88C')
        'Ivory Frost'=@('FFFFFF','B6D3EB','38434F','141A20','F3F7FA','AABAC8')
        'Obsidian'=@('C9D1D9','7D91A8','303945','0B0F14','E5EDF6','97A6B6')
        'Glacier'=@('96E6FF','C0B9FF','2C405C','101E30','E7F4FF','9EB9D0')
        'Ocean Depths'=@('38BDF8','2DD4BF','174253','0B1B29','DDF6FF','8EACBA')
        'Midnight Aurora'=@('5EEAD4','A78BFA','304259','101526','E5F6F4','9FADCB')
        'Cyber Pulse'=@('67E8F9','F472B6','3C3158','170F28','F3E8FF','B6A3D0')
        'Violet Nebula'=@('C084FC','F0ABFC','48315D','201229','F5E6FF','C0A5CC')
        'Cherry Blossom'=@('FDA4AF','FBCFE8','58323F','22151D','FFF0F5','CAABB9')
        'Rose Quartz'=@('F9A8D4','FDE68A','553447','211720','FFEAF6','C6ADBB')
        'Peach Sunset'=@('FFB199','F7A8D8','55372E','23181A','FFF0E7','CBAA9C')
        'Forest Spirit'=@('86EFAC','D9F99D','304A30','142016','E6F6D8','A0BA9E')
        'Emerald Circuit'=@('34D399','A3E635','1C493E','0E221C','DFFFEA','9CBFB0')
        'Acid Lime'=@('BEF264','5EEAD4','3C4927','1A2011','F0F9D9','B4C393')
        'Golden Hour'=@('FACC15','FDBA74','554322','201A12','FFF1D5','C4B193')
        'Copper Dusk'=@('EBA075','A5B4FC','493A3D','21191C','F7E8E2','C3ABA9')
        'Sapphire Night'=@('60A5FA','A5B4FC','263B60','10172B','E7EEFF','9BACD1')
        'Storm Grey'=@('BAC8DA','94A3B8','394350','171D27','E9EFF7','A0ADBD')
        'Arcade Neon'=@('F0ABFC','67E8F9','49315B','1B102A','F6E8FF','B6A6CE')
        'Polar Dawn'=@('C4B5FD','BAE6FD','38405C','161C30','EDF3FF','A6B4D1')
        'Lavender Haze'=@('DDD6FE','F9A8D4','483854','231A31','F8EDFF','C4AECF')
        'Raspberry Ink'=@('FB7185','C4B5FD','532B4C','211329','FCE7F3','C2A1BA')
        'Custom'=@($global:NexPublicSettings.Accent,'CDD6F4','393945','181825','CDD6F4','A6A4BF')
    }
    if (-not $colors.ContainsKey($theme)) {$theme='Pink'}
    return ,$colors[$theme]
}
function global:NexAnsi([string]$hex,[switch]$Background) {
    $hex=$hex.TrimStart('#');$kind=if ($Background) {48} else {38}
    "$([char]27)[$kind;2;$([Convert]::ToInt32($hex.Substring(0,2),16));$([Convert]::ToInt32($hex.Substring(2,2),16));$([Convert]::ToInt32($hex.Substring(4,2),16))m"
}
function global:NexSetup {
    param([switch]$SkipTerminalSync)
    $c=$global:NexPublicSettings
    function Choose([string]$label,[string[]]$options,[string]$current) {
        Write-Host "`n$label" -ForegroundColor Magenta
        for ($i=0;$i -lt $options.Count;$i++) {Write-Host ('  {0}. {1}' -f ($i+1),(NexL $options[$i]))}
        while ($true) {$v=Read-Host "[Enter = $(NexL $current)]"; if ([string]::IsNullOrWhiteSpace($v)) {return $current};$n=0;if ([int]::TryParse($v,[ref]$n) -and $n -ge 1 -and $n -le $options.Count) {return $options[$n-1]}}
    }
    Write-Host ('{0} / DASHBOARD 2.6.2' -f (Get-NexName)) -ForegroundColor Magenta
    $choice=Choose 'Language / Язык / Sprache' @('English','Русский','Deutsch') (@{en='English';ru='Русский';de='Deutsch'}[$c.Language])
    $c.Language=@{English='en';'Русский'='ru';Deutsch='de'}[$choice]
    $v=Read-Host "$(NexL 'Display name') [$(Get-NexName)]";if ($v) {$c.Name=($v -replace '[\x00-\x1F\x7F-\x9F]','').Trim();if ($c.Name.Length -gt 32) {$c.Name=$c.Name.Substring(0,32)}}
    $c.Theme=Choose (NexL 'Theme') @(Get-NexThemeNames) $c.Theme
    if ($c.Theme -eq 'Custom') {$hex=Read-Host 'RGB HEX (e.g. F5C2E7)';if ($hex -match '^#?([0-9A-Fa-f]{6})$') {$c.Accent=$Matches[1]}}
    foreach ($pair in @(@('Startup','Startup screen'),@('ClearOnReturn','Clear screen on return'),@('LoadingOnReturn','Loading on return'),@('Fetch','Startup info'),@('FetchAnimation','Fetch animation'),@('Icons','Icons'),@('ShowComputerName','Show computer name'))) {
        $on=NexL 'Enabled';$off=NexL 'Disabled';$current=if ($c[$pair[0]]) {$on} else {$off}
        $c[$pair[0]]=(Choose (NexL $pair[1]) @($on,$off) $current) -eq $on
    }
    $c.FetchPreset=Choose (NexL 'Fetch preset') @('Cards','Compact','Minimal','Neon Frame','Color Labels','Tree Layout','Studio','Fastfetch classic','Fastfetch custom') $c.FetchPreset
    if ($c.ShowComputerName) {$v=Read-Host (NexL 'Computer alias (Enter keeps current)');if ($v) {$c.ComputerAlias=Normalize-NexIdentityPart ($v.TrimStart('@'))}}
    $c.Prompt=Choose (NexL 'Prompt style') @(Get-NexPromptStyles) $c.Prompt
    $c.Prediction=Choose (NexL 'Prediction') @('History','None') $c.Prediction
     if ($c.Icons) {Write-Host (NexL 'Nerd Font icons need a compatible font.') -ForegroundColor DarkGray}
    Save-NexPreferences
    Write-Host (NexL 'Preferences saved.') -ForegroundColor Green
    if (-not $SkipTerminalSync -and (Get-Command Apply-NexSharedTheme -ErrorAction SilentlyContinue)) {
        try {if (Get-NexTerminalHost) {$null=Apply-NexSharedTheme}} catch {Write-Warning ('Terminal appearance: '+$_.Exception.Message)}
    }
}
function global:JsonTokens([string]$text) {
    $rx='"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/|[{}\[\]:,]|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null'
    @([regex]::Matches($text,$rx) | Where-Object { -not $_.Value.StartsWith('//') -and -not $_.Value.StartsWith('/*') })
}
function global:ParseConfig([string]$text) {
    $ts=@(JsonTokens $text); $parts=New-Object 'System.Collections.Generic.List[string]'
    for ($i=0;$i -lt $ts.Count;$i++) {
        if ($ts[$i].Value -eq ',' -and $i+1 -lt $ts.Count -and $ts[$i+1].Value -in @('}',']')) { continue }
        $parts.Add($ts[$i].Value)
    }
    # Reject unrecognized non-whitespace outside valid tokens/comments.
    $rx='"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/|[{}\[\]:,]|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null'
    if (-not [string]::IsNullOrWhiteSpace([regex]::Replace($text,$rx,''))) { throw 'Unsupported settings JSON format.' }
    ($parts -join '') | ConvertFrom-Json -ErrorAction Stop
}
function global:FindDirectProperty($ts,[int]$begin,[string]$name) {
    $depth=0; $found=-1
    for ($j=$begin+1;$j -lt $ts.Count;$j++) {
        $v=$ts[$j].Value
        if ($depth -eq 0 -and $v -ceq ('"'+$name+'"') -and $j+1 -lt $ts.Count -and $ts[$j+1].Value -eq ':') {
            if ($found -ge 0) { throw "Duplicate property: $name" }
            $found=$j+2
        }
        if ($v -in @('{','[')) { $depth++ }
        elseif ($v -in @('}',']')) { if ($depth -eq 0) { break }; $depth-- }
    }
    return $found
}

# All Windows Terminal profiles share the selected appearance. No shell commands,
# key bindings, startup directories or profile identities are changed here.
function global:Set-NexObjectMember($obj,[string]$key,$value) {
    if ($obj.PSObject.Properties[$key]) { $obj.$key=$value }
    else { $obj | Add-Member -NotePropertyName $key -NotePropertyValue $value }
}
function global:Get-NexSharedPaletteChanges {
    $p=Get-NexPalette
    return @{background=('#'+$p[3]);foreground=('#'+$p[4]);cursorColor=('#'+$p[0]);selectionBackground=('#'+$p[2]);colorScheme='NEX Shared'}
}
function global:Get-NexSharedScheme {
    $p=Get-NexPalette
    return [pscustomobject]@{name='NEX Shared';background=('#'+$p[3]);foreground=('#'+$p[4]);cursorColor=('#'+$p[0]);selectionBackground=('#'+$p[2]);black='#45475A';red='#F38BA8';green='#A6E3A1';yellow='#F9E2AF';blue='#89B4FA';purple=('#'+$p[1]);cyan='#94E2D5';white='#BAC2DE';brightBlack='#585B70';brightRed='#F38BA8';brightGreen='#A6E3A1';brightYellow='#F9E2AF';brightBlue='#89B4FA';brightPurple=('#'+$p[0]);brightCyan='#94E2D5';brightWhite=('#'+$p[4])}
}
function global:Sync-NexTerminalAppearance([hashtable]$changes,$scheme=$null,[string]$extraPath='') {
    $paths=@(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    if ($extraPath) {$paths+= $extraPath}
    $paths=@($paths | Select-Object -Unique | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf})
    if (-not $paths.Count) {throw 'Windows Terminal settings not found. Run Initialize-NexAppearance first.'}
    $allowed=@('background','foreground','cursorColor','selectionBackground','colorScheme','opacity','useAcrylic','cursorShape','fontFace','fontSize')
    foreach ($k in $changes.Keys) {if ($k -notin $allowed) {throw "Unsupported appearance setting: $k"}}
    $plans=@()
    foreach ($path in $paths) {
        $old=[IO.File]::ReadAllText($path)
        $obj=ParseConfig $old
        if (-not $obj.profiles -or $obj.profiles -is [array]) {throw "Unsupported profiles format: $path"}
        if (-not $obj.profiles.defaults) {Set-NexObjectMember $obj.profiles 'defaults' ([pscustomobject]@{})}
        if ($scheme) {
            $items=@($obj.schemes | Where-Object {$_ -and $_.name -ine $scheme.name})
            $items+= $scheme
            Set-NexObjectMember $obj 'schemes' $items
        }
        $profiles=@($obj.profiles.defaults)+@($obj.profiles.list | Where-Object {$_})
        foreach ($pr in $profiles) {
            if ($pr -isnot [pscustomobject]) {throw "Invalid profile object: $path"}
            foreach ($k in $changes.Keys) {
                if ($k -in @('fontFace','fontSize')) {
                    if ($pr.PSObject.Properties[$k]) {$pr.PSObject.Properties.Remove($k)}
                    if (-not $pr.font -or $pr.font -isnot [pscustomobject]) {Set-NexObjectMember $pr 'font' ([pscustomobject]@{})}
                    $fk=if ($k -eq 'fontFace') {'face'} else {'size'}
                    Set-NexObjectMember $pr.font $fk $changes[$k]
                } else {
                    Set-NexObjectMember $pr $k $changes[$k]
                    if ($k -eq 'opacity' -and $pr.PSObject.Properties['acrylicOpacity']) {$pr.PSObject.Properties.Remove('acrylicOpacity')}
                    if ($pr.unfocusedAppearance -is [pscustomobject] -and $k -in @('background','foreground','cursorColor','selectionBackground','colorScheme','opacity','useAcrylic','cursorShape')) {
                        if ($pr.unfocusedAppearance.PSObject.Properties[$k]) {Set-NexObjectMember $pr.unfocusedAppearance $k $changes[$k]}
                        if ($k -eq 'opacity' -and $pr.unfocusedAppearance.PSObject.Properties['acrylicOpacity']) {$pr.unfocusedAppearance.PSObject.Properties.Remove('acrylicOpacity')}
                    }
                }
            }
        }
        $new=ConvertTo-Json -InputObject $obj -Depth 100
        $check=ParseConfig $new
        $checkProfiles=@($check.profiles.defaults)+@($check.profiles.list | Where-Object {$_})
        if ($checkProfiles.Count -ne $profiles.Count) {throw 'Profile count verification failed.'}
        foreach ($pr in $checkProfiles) {
            foreach ($k in $changes.Keys) {
                $v=if ($k -eq 'fontFace') {$pr.font.face} elseif ($k -eq 'fontSize') {$pr.font.size} else {$pr.$k}
                if ($v -cne $changes[$k]) {throw "Appearance verification failed: $k"}
            }
        }
        $plans+=@{Path=$path;Old=$old;New=$new;Count=$profiles.Count-1}
    }
    $written=@();$count=0
    try {
        foreach ($plan in $plans) {
            $path=$plan.Path
            if ([IO.File]::ReadAllText($path) -cne $plan.Old) {throw "Terminal settings changed elsewhere: $path"}
            $temp=$path+'.nex-'+[guid]::NewGuid().ToString('N')+'.tmp'
            $bak=$path+'.nex-shared-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.bak'
            try {
                [IO.File]::WriteAllText($temp,$plan.New,(New-Object System.Text.UTF8Encoding($false)))
                [IO.File]::Replace($temp,$path,$bak)
                $written+=@{Path=$path;Backup=$bak;New=$plan.New}
                $count+=$plan.Count
            } finally {if (Test-Path -LiteralPath $temp) {Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}}
        }
    } catch {
        $reason=$_.Exception.Message
        foreach ($entry in $written) {
            try {if ([IO.File]::ReadAllText($entry.Path) -ceq $entry.New) {Copy-Item -LiteralPath $entry.Backup -Destination $entry.Path -Force -ErrorAction Stop} else {Write-Warning ('Settings changed; restore manually from '+$entry.Backup)}} catch {Write-Warning ('Restore manually from '+$entry.Backup)}
        }
        throw $reason
    }
    return $count
}
function global:Apply-NexSharedTheme {
    $changes=Get-NexSharedPaletteChanges
    return (Sync-NexTerminalAppearance $changes (Get-NexSharedScheme))
}

# Public setup: downloads only from the official Microsoft / Nerd Fonts sources.
function global:Get-NexTerminalHost {
    foreach ($edition in @('Microsoft.WindowsTerminal','Microsoft.WindowsTerminalPreview')) {
        $pkg=Get-AppxPackage -Name $edition -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $pkg) {continue}
        $alias=Join-Path $env:LOCALAPPDATA ('Microsoft\WindowsApps\'+$pkg.PackageFamilyName+'\wt.exe')
        $local=Join-Path $pkg.InstallLocation 'wt.exe'
        $exe=if (Test-Path -LiteralPath $alias) {$alias} elseif (Test-Path -LiteralPath $local) {$local} else {$null}
        if (-not $exe -and $edition -eq 'Microsoft.WindowsTerminal') {
            $cmd=Get-Command wt.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cmd) {$exe=$cmd.Source}
        }
        if ($exe) {return @{Exe=$exe;Settings=(Join-Path $env:LOCALAPPDATA ('Packages\'+$pkg.PackageFamilyName+'\LocalState\settings.json'))}}
    }
    $portable=Join-Path $env:LOCALAPPDATA 'NexDashboard\Terminal'
    if (Test-Path -LiteralPath $portable) {
        $exe=Get-ChildItem -LiteralPath $portable -Filter WindowsTerminal.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) {return @{Exe=$exe.FullName;Settings=(Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')}}
    }
    $cmd=Get-Command wt.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source -notlike '*\WindowsApps\*') {return @{Exe=$cmd.Source;Settings=(Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')}}
    return $null
}
function global:Get-NexOfficialDownload([string]$url,[string]$path,[string]$digest='') {
    if ($url -notmatch '^https://github\.com/(microsoft/terminal|ryanoasis/nerd-fonts|fastfetch-cli/fastfetch)/releases/') {throw 'Unexpected download source.'}
    $progressPreference='SilentlyContinue'
    Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile $path -TimeoutSec 180 -ErrorAction Stop
    if ($digest -match '^sha256:([0-9a-fA-F]{64})$') {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $Matches[1]) {throw 'Download checksum mismatch.'}
    }
}
function global:Install-NexTerminal([string]$work) {
    $existing=Get-NexTerminalHost
    if ($existing) {return $existing}
    Write-Host '[1/3] Windows Terminal: installing...' -ForegroundColor Magenta
    $wg=Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wg) {
        & $wg.Source install --id Microsoft.WindowsTerminal --exact --source winget --accept-source-agreements --disable-interactivity | Out-Host
        $existing=Get-NexTerminalHost
        if ($existing) {return $existing}
    }
    $release=Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/terminal/releases/latest' -Headers @{'User-Agent'='NEX-Dashboard-Setup'} -TimeoutSec 30 -ErrorAction Stop
    if ($release.prerelease -or $release.draft) {throw 'Stable Terminal release not found.'}
    $bundle=$release.assets | Where-Object {$_.name -match '^Microsoft\.WindowsTerminal_.*\.msixbundle$' -and $_.name -notmatch 'Preview|Canary'} | Select-Object -First 1
    if (-not $bundle) {throw 'Official Terminal bundle not found.'}
    $download=Join-Path $work $bundle.name
    Get-NexOfficialDownload $bundle.browser_download_url $download $bundle.digest
    try {Add-AppxPackage -Path $download -ErrorAction Stop}
    catch {
        # Only use Microsoft's normal unpackaged distribution for a missing framework dependency.
        # Never work around an administrator's installation policy or signature failure.
        if (($_ | Out-String) -notmatch '0x80073CF3') {throw}
        $arch=$env:PROCESSOR_ARCHITEW6432; if (-not $arch) {$arch=$env:PROCESSOR_ARCHITECTURE}
        $arch=switch ($arch) {'AMD64' {'x64'} 'ARM64' {'arm64'} 'x86' {'x86'} default {throw 'Unsupported Windows architecture.'}}
        $asset=$release.assets | Where-Object {$_.name -match '^Microsoft\.WindowsTerminal_' -and $_.name -match ('(?i)[_-]'+$arch+'\.zip$') -and $_.name -notmatch 'Preview|Canary'} | Select-Object -First 1
        if (-not $asset) {throw 'Terminal framework dependency missing and no matching official ZIP is available.'}
        $zip=Join-Path $work $asset.name
        Get-NexOfficialDownload $asset.browser_download_url $zip $asset.digest
        $expanded=Join-Path $work 'terminal'
        Expand-Archive -LiteralPath $zip -DestinationPath $expanded -ErrorAction Stop
        $terminal=Get-ChildItem -LiteralPath $expanded -Recurse -Filter WindowsTerminal.exe -File | Select-Object -First 1
        if (-not $terminal) {throw 'Terminal ZIP is incomplete.'}
        $dest=Join-Path $env:LOCALAPPDATA 'NexDashboard\Terminal'
        if (Test-Path -LiteralPath $dest) {throw 'Existing unpackaged Terminal needs repair.'}
        Move-Item -LiteralPath $expanded -Destination $dest -ErrorAction Stop
    }
    $existing=Get-NexTerminalHost
    if (-not $existing) {throw 'Windows Terminal is installed but its launcher is not available yet.'}
    return $existing
}
function global:Mix-NexColor([string]$first,[string]$second,[double]$weight=0.5) {
    $weight=[Math]::Max(0,[Math]::Min(1,$weight))
    if ($first -notmatch '^[0-9A-Fa-f]{6}$') {$first='CDD6F4'}
    if ($second -notmatch '^[0-9A-Fa-f]{6}$') {$second='CDD6F4'}
    $rgb=for ($i=0;$i -lt 6;$i+=2) {
        $x=[Convert]::ToInt32($first.Substring($i,2),16)
        $y=[Convert]::ToInt32($second.Substring($i,2),16)
        [int][Math]::Round($x*(1-$weight)+$y*$weight)
    }
    return ('{0:X2}{1:X2}{2:X2}' -f $rgb[0],$rgb[1],$rgb[2])
}
function global:Get-NexVendorColor([string]$name,[string]$fallback='CDD6F4') {
    $hue=if ($name -match '(?i)\b(NVIDIA|GeForce|Quadro|TITAN)\b') {'9FC78D'}
        elseif ($name -match '(?i)\b(AMD|Radeon|Ryzen|EPYC|Athlon|Threadripper)\b') {'DFA0A9'}
        elseif ($name -match '(?i)\b(Intel|Arc|Xeon|Celeron|Pentium|Iris)\b') {'93B9E6'}
        else {return $fallback}
    return (Mix-NexColor $hue $fallback 0.25)
}
function global:Get-NexFetchHue([string]$kind,$palette) {
    $colors=@{cpu='DFA8AD';gpu='A3C99A';memory='E3B3D6';disk='94B9E8';os='B9A9E9';kernel='A0D0CA';shell='ABB9E8';terminal='9DC9D3';uptime='E2CC99';date='E4B29C'}
    if (-not $colors.ContainsKey($kind)) {return $palette[1]}
    return (Mix-NexColor $colors[$kind] $palette[0] 0.23)
}
function global:Test-NexNerdFont {
    $userFontDir=Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $systemFontDir=Join-Path $env:WINDIR 'Fonts'
    foreach ($key in @('HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts','HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')) {
        $p=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if (-not $p) {continue}
        foreach ($v in $p.PSObject.Properties) {
            if ($v.Name -notmatch '(?i)JetBrains\s*Mono.*(?:Nerd Font Mono|NFM)' -and [string]$v.Value -notmatch '(?i)JetBrainsMonoNerdFontMono.*\.(ttf|otf)$') {continue}
            $path=[Environment]::ExpandEnvironmentVariables([string]$v.Value).Trim('"')
            if (-not $path) {continue}
            $candidates=if ([IO.Path]::IsPathRooted($path)) {@($path)} else {@((Join-Path $userFontDir $path),(Join-Path $systemFontDir $path))}
            foreach ($candidate in $candidates) {if (Test-Path -LiteralPath $candidate -PathType Leaf) {return $true}}
        }
    }
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $fc=New-Object System.Drawing.Text.InstalledFontCollection
        try {if (@($fc.Families | Where-Object {$_.Name -match '(?i)JetBrains\s*Mono.*(?:Nerd Font Mono|NFM)'}).Count) {return $true}} finally {$fc.Dispose()}
    } catch {}
    return $false
}

function global:Install-NexFont([string]$work) {
    if (Test-NexNerdFont) {return $true}
    Write-Host '[2/3] Installing JetBrainsMono Nerd Font Mono...' -ForegroundColor Magenta
    $zip=Join-Path $work 'JetBrainsMono.zip'
    Get-NexOfficialDownload 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' $zip
    $extract=Join-Path $work 'fonts'
    Expand-Archive -LiteralPath $zip -DestinationPath $extract -ErrorAction Stop
    $fontDir=Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $reg='HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $null=New-Item -ItemType Directory -Path $fontDir -Force
    if (-not (Test-Path -LiteralPath $reg)) {$null=New-Item -Path $reg -ErrorAction Stop}
    if (-not ('NexDash.SetupFont221' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace NexDash { public static class SetupFont221 {
 [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceEx(string file, uint flags, IntPtr reserved);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
}}
"@ -ErrorAction Stop
    }
    foreach ($style in @('Regular','Bold','Italic','BoldItalic')) {
        $font=Get-ChildItem -LiteralPath $extract -Filter "JetBrainsMonoNerdFontMono-$style.ttf" -Recurse -File | Select-Object -First 1
        if (-not $font) {if ($style -eq 'Regular') {throw 'Regular font missing in release archive.'};continue}
        $dest=Join-Path $fontDir $font.Name
        if (-not (Test-Path -LiteralPath $dest)) {Copy-Item -LiteralPath $font.FullName -Destination $dest -ErrorAction Stop}
        $name=if ($style -eq 'Regular') {'JetBrainsMono Nerd Font Mono (TrueType)'} else {"JetBrainsMono Nerd Font Mono $style (TrueType)"}
        $null=New-ItemProperty -LiteralPath $reg -Name $name -Value $dest -PropertyType String -Force
        $null=[NexDash.SetupFont221]::AddFontResourceEx($dest,0,[IntPtr]::Zero)
    }
    $result=[IntPtr]::Zero
    $null=[NexDash.SetupFont221]::SendMessageTimeout([IntPtr]0xffff,0x001D,[IntPtr]::Zero,[IntPtr]::Zero,2,1000,[ref]$result)
    return (Test-NexNerdFont)
}
function global:Install-NexTerminalProfile($terminal,[bool]$fontReady) {
    Write-Host '[3/3] Applying your terminal profile...' -ForegroundColor Magenta
    $id='{7e499cb9-0e64-4c22-9bb5-f4e4db932221}'
    $path=$terminal.Settings
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
    $palette=Get-NexPalette
    $face=if ($fontReady) {'JetBrainsMono Nerd Font Mono'} else {'Cascadia Mono'}
    $profileData=[ordered]@{guid=$id;name='NEX Dashboard';commandline='powershell.exe -NoLogo';startingDirectory='%USERPROFILE%';hidden=$false;font=@{face=$face;size=12};opacity=85;useAcrylic=$true;background=('#'+$palette[3]);foreground=('#'+$palette[4]);cursorColor=('#'+$palette[0]);selectionBackground=('#'+$palette[2]);cursorShape='bar'}
    $utf8=New-Object System.Text.UTF8Encoding($false)
    $exists=Test-Path -LiteralPath $path -PathType Leaf
    if ($exists) {$old=[IO.File]::ReadAllText($path)} else {$old='{"profiles":{"defaults":{},"list":[]}}'}
    $obj=ParseConfig $old
    $found=@($obj.profiles.list | Where-Object {$_.guid -and ([string]$_.guid).Trim('{}') -ieq $id.Trim('{}')})
    if ($found.Count -gt 1) {throw 'Duplicate NEX profiles.'}
    if ($found.Count -eq 0) {
        $ts=@(JsonTokens $old)
        $at=FindDirectProperty $ts 0 'profiles'
        if ($at -lt 0 -or $ts[$at].Value -ne '{') {throw 'Terminal profiles object not found.'}
        $list=FindDirectProperty $ts $at 'list'
        if ($list -lt 0 -or $ts[$list].Value -ne '[') {throw 'Terminal profile list not found.'}
        $comma=if ($ts[$list+1].Value -eq ']') {''} else {','}
        $json=ConvertTo-Json -InputObject $profileData -Depth 8 -Compress
        $new=$old.Insert($ts[$list].Index+1,"`r`n        $json$comma")
    } else {
        # Preserve existing custom NEX appearance, but repair the font face if required.
        $new=$old
        if ($fontReady -and $found[0].font.face -ne $face) {
            $ts=@(JsonTokens $old)
            $start=FindDirectProperty $ts 0 'profiles';$list=FindDirectProperty $ts $start 'list'
            $depth=0;$begin=-1
            for ($i=$list+1;$i -lt $ts.Count;$i++) {
                $v=$ts[$i].Value
                if ($v -eq ']' -and $depth -eq 0) {break}
                if ($v -eq '{' -and $depth -eq 0) {
                    $g=FindDirectProperty $ts $i 'guid'
                    if ($g -ge 0 -and $ts[$g].Value.Trim('"').Trim('{}') -ieq $id.Trim('{}')) {$begin=$i;break}
                }
                if ($v -in @('{','[')) {$depth++} elseif ($v -in @('}',']')) {$depth--}
            }
            if ($begin -lt 0) {throw 'NEX profile could not be located.'}
            $f=FindDirectProperty $ts $begin 'font'
            if ($f -ge 0 -and $ts[$f].Value -eq '{') {
                $a=FindDirectProperty $ts $f 'face'
                if ($a -ge 0 -and $ts[$a].Value.StartsWith('"')) {$new=$old.Remove($ts[$a].Index,$ts[$a].Length).Insert($ts[$a].Index,('"'+$face+'"'))}
                elseif ($a -lt 0) {$comma=if ($ts[$f+1].Value -eq '}') {''} else {','};$new=$old.Insert($ts[$f].Index+1,('"face":"'+$face+'"'+$comma))}
                else {throw 'Unsupported font property.'}
            } elseif ($f -lt 0) {$comma=if ($ts[$begin+1].Value -eq '}') {''} else {','};$new=$old.Insert($ts[$begin].Index+1,('"font":{"face":"'+$face+'","size":12}'+$comma))}
            else {throw 'Unsupported existing font configuration.'}
        }
    }
    $verified=ParseConfig $new
    $matches=@($verified.profiles.list | Where-Object {$_.guid -and ([string]$_.guid).Trim('{}') -ieq $id.Trim('{}')})
    if ($matches.Count -ne 1 -or ($fontReady -and $matches[0].font.face -ne $face)) {throw 'Terminal profile verification failed.'}
    if ($new -cne $old -or -not $exists) {
        $tmp=$path+'.nex-'+[guid]::NewGuid().ToString('N')+'.tmp'
        try {
            [IO.File]::WriteAllText($tmp,$new,$utf8)
            if ($exists) {
                if ([IO.File]::ReadAllText($path) -cne $old) {throw 'Terminal settings changed during setup; run setup again.'}
                [IO.File]::Replace($tmp,$path,($path+'.nex-setup-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.bak'))
            } else {[IO.File]::Move($tmp,$path)}
        } finally {if (Test-Path -LiteralPath $tmp) {Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}}
    }
    $changes=Get-NexSharedPaletteChanges
    $changes.fontFace=$face
    $changes.fontSize=12
    $changes.opacity=85
    $changes.useAcrylic=$true
    $changes.cursorShape='bar'
    if ($matches.Count -eq 1) {
        $existingProfile=$matches[0]
        foreach ($key in @('opacity','useAcrylic','cursorShape')) {
            if ($existingProfile.PSObject.Properties[$key] -and $null -ne $existingProfile.$key) {$changes[$key]=$existingProfile.$key}
        }
        if ($existingProfile.font.size) {$changes.fontSize=$existingProfile.font.size}
    }
    $synced=Sync-NexTerminalAppearance $changes (Get-NexSharedScheme) $path
    Write-Host "[OK] Shared appearance applied to $synced saved profiles and defaults." -ForegroundColor Green
    $launchArgs='-w new new-tab -p "'+$id+'" powershell.exe -NoLogo -NoExit -Command dashboard'
    $shortcut=Join-Path ([Environment]::GetFolderPath('Programs')) 'NEX Dashboard.lnk'
    $ws=New-Object -ComObject WScript.Shell
    if (Test-Path -LiteralPath $shortcut) {
        $existingLink=$ws.CreateShortcut($shortcut)
        if ($existingLink.Arguments -notlike ('*'+$id.Trim('{}')+'*')) { $shortcut=Join-Path ([Environment]::GetFolderPath('Programs')) 'NEX Dashboard Public.lnk' }
    }
    $lnk=$ws.CreateShortcut($shortcut);$lnk.TargetPath=$terminal.Exe;$lnk.Arguments=$launchArgs;$lnk.WorkingDirectory=$HOME;$lnk.Description='Open your personalized NEX Dashboard';$lnk.Save()
    return @{Exe=$terminal.Exe;Arguments=$launchArgs;Shortcut=$shortcut}
}
function global:Initialize-NexAppearance {
    $answer=Read-Host 'Install missing Windows Terminal / Nerd Font and apply shared appearance to ALL Windows Terminal profiles? [Y/n / Д/н]'
    if ($answer -match '^(?i:n|no|н|нет)$') {Write-Host 'Appearance setup skipped.';return $false}
    if ($answer -and $answer -notmatch '^(?i:y|yes|д|да|j|ja)$') {Write-Warning 'Appearance setup cancelled.';return $false}
    $work=Join-Path $env:TEMP ('NexSetup-'+[guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory -Path $work
    $oldTls=[Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol=$oldTls -bor [Net.SecurityProtocolType]::Tls12
        $terminal=Install-NexTerminal $work
        if (-not $terminal) {throw 'No supported Windows Terminal launcher.'}
        $font=$false
        if ($global:NexPublicSettings.Icons) {
            try {$font=Install-NexFont $work} catch {Write-Warning ('Font setup failed: '+$_.Exception.Message)}
            if (-not $font) {Write-Warning 'Nerd Font unavailable. Plain symbols will be used.';$global:NexPublicSettings.Icons=$false;Save-NexPreferences}
        }
        if (-not (Get-NexFastfetch)) {
            $ffAnswer=Read-Host ((NexL 'Install official Fastfetch now?')+' [Y/n]')
            if (-not $ffAnswer -or $ffAnswer -match '^(?i:y|yes|д|да|j|ja)$') {
                try {$null=Install-NexFastfetch;Write-Host (NexL 'Fastfetch ready.') -ForegroundColor Green} catch {Write-Warning ('Fastfetch: '+$_.Exception.Message)}
            }
        }
        $launcher=Install-NexTerminalProfile $terminal $font
        Write-Host '[OK] NEX profile ready. Start menu: NEX Dashboard.' -ForegroundColor Green
        Start-Process -FilePath $launcher.Exe -ArgumentList $launcher.Arguments -ErrorAction Stop
        return $true
    } catch {Write-Warning ('Appearance setup: '+$_.Exception.Message);Write-Host 'Dashboard is installed. To retry appearance setup, run Initialize-NexAppearance.';return $false}
    finally {[Net.ServicePointManager]::SecurityProtocol=$oldTls;Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
}

function global:Get-NexSpeedtest {
    foreach ($rel in @('NexDashboard\Speedtest\speedtest.exe','Microsoft\WinGet\Links\speedtest.exe','Programs\Ookla\speedtest.exe')) {
        $p=Join-Path $env:LOCALAPPDATA $rel
        if (Test-Path -LiteralPath $p -PathType Leaf) {return $p}
    }
    $cmd=Get-Command speedtest.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and (Test-Path -LiteralPath $cmd.Source -PathType Leaf)) {return [string]$cmd.Source}
    return $null
}
function global:Install-NexSpeedtest {
    # Version and checksum pinned to the WinGet community manifest.
    # No bundled third-party executable; no elevation, PATH or policy changes.
    $ErrorActionPreference='Stop'
    $ProgressPreference='SilentlyContinue'
    $arch=$env:PROCESSOR_ARCHITEW6432
    if (-not $arch) {$arch=$env:PROCESSOR_ARCHITECTURE}
    if ($arch -ne 'AMD64') {throw 'Ookla automatic installation currently supports Windows x64 only.'}
    $dest=Join-Path $env:LOCALAPPDATA 'NexDashboard\Speedtest'
    $target=Join-Path $dest 'speedtest.exe'
    if (Test-Path -LiteralPath $target -PathType Leaf) {return $target}
    $work=Join-Path $env:TEMP ('NexSpeedtest-'+[guid]::NewGuid().ToString('N'))
    $oldTls=[Net.ServicePointManager]::SecurityProtocol
    try {
        $null=New-Item -ItemType Directory -Path $work
        [Net.ServicePointManager]::SecurityProtocol=$oldTls -bor [Net.SecurityProtocolType]::Tls12
        $zip=Join-Path $work 'ookla.zip'
        Invoke-WebRequest -Uri 'https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip' -UseBasicParsing -OutFile $zip -TimeoutSec 90 -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ine '13E3D888B845D301A556419E31F14AB9BFF57E3F06089EF2FD3BDC9BA6841EFA') {throw 'Ookla download checksum mismatch.'}
        $unpacked=Join-Path $work 'unpacked'
        Expand-Archive -LiteralPath $zip -DestinationPath $unpacked -ErrorAction Stop
        $exe=Join-Path $unpacked 'speedtest.exe'
        if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {throw 'Speedtest executable missing from verified archive.'}
        # Preserve the accompanying license and documentation from the verified ZIP.
        $null=New-Item -ItemType Directory -Path $dest -Force
        Get-ChildItem -LiteralPath $unpacked -File | Where-Object {$_.Name -ne 'speedtest.exe'} | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $dest -Force}
        Copy-Item -LiteralPath $exe -Destination $target -Force
        return $target
    } finally {
        [Net.ServicePointManager]::SecurityProtocol=$oldTls
        if (Test-Path -LiteralPath $work) {Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
    }
}
function global:Get-NexFastfetch {
    $cmd=Get-Command fastfetch.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and (Test-Path -LiteralPath $cmd.Source -PathType Leaf)) {return [string]$cmd.Source}
    $local=Join-Path $env:LOCALAPPDATA 'NexDashboard\Fastfetch\fastfetch.exe'
    if (Test-Path -LiteralPath $local -PathType Leaf) {return $local}
    return $null
}
function global:Install-NexFastfetch {
    # Call only after explicit consent. No PATH or system policy changes.
    $existing=Get-NexFastfetch
    if ($existing) {return $existing}
    $arch=$env:PROCESSOR_ARCHITEW6432
    if (-not $arch) {$arch=$env:PROCESSOR_ARCHITECTURE}
    $assetName=switch ($arch) {
        'AMD64' {'fastfetch-windows-amd64.zip'}
        'ARM64' {'fastfetch-windows-aarch64.zip'}
        default {throw 'Fastfetch: unsupported Windows architecture.'}
    }
    $work=Join-Path $env:TEMP ('NexFastfetch-'+[guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory -Path $work -ErrorAction Stop
    $tls=[Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol=$tls -bor [Net.SecurityProtocolType]::Tls12
        Write-Host (NexL 'Install Fastfetch') -ForegroundColor Magenta
        $release=Invoke-RestMethod -Uri 'https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest' -Headers @{'User-Agent'='NEX-Dashboard-Setup'} -TimeoutSec 30 -ErrorAction Stop
        if ($release.prerelease -or $release.draft) {throw 'Fastfetch stable release not found.'}
        $asset=$release.assets | Where-Object {$_.name -ceq $assetName} | Select-Object -First 1
        if (-not $asset) {throw ('Official asset missing: '+$assetName)}
        $zip=Join-Path $work $assetName
        Get-NexOfficialDownload $asset.browser_download_url $zip $asset.digest
        $expanded=Join-Path $work 'expanded'
        Expand-Archive -LiteralPath $zip -DestinationPath $expanded -ErrorAction Stop
        $exe=Get-ChildItem -LiteralPath $expanded -Recurse -File -Filter fastfetch.exe | Select-Object -First 1
        if (-not $exe) {throw 'Fastfetch archive is incomplete.'}
        $version=@(& $exe.FullName --version 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $version.Count) {throw 'Fastfetch executable check failed.'}
        $dest=Join-Path $env:LOCALAPPDATA 'NexDashboard\Fastfetch'
        if (Test-Path -LiteralPath $dest) {throw 'Existing Fastfetch installation needs repair.'}
        $null=New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force
        Move-Item -LiteralPath $exe.Directory.FullName -Destination $dest -ErrorAction Stop
        $result=Get-NexFastfetch
        if (-not $result) {throw 'Fastfetch installation could not be verified.'}
        return $result
    } finally {
        [Net.ServicePointManager]::SecurityProtocol=$tls
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
# Portable appearance backups. Only data is imported, never profiles/scripts or executables.
function global:Get-NexBackupPreferences($o) {
    if ($o -isnot [pscustomobject]) {throw (NexL 'Invalid configuration file.')}
    $out=@{}
    $sets=@{Language=@('en','ru','de');Theme=@(Get-NexThemeNames);Prompt=@(Get-NexPromptStyles);FetchPreset=@('Cards','Compact','Minimal','Neon Frame','Color Labels','Tree Layout','Studio','Fastfetch classic','Fastfetch custom');Prediction=@('None','History');Access=@('Unknown','Fiber / Glasfaser','DSL','Cable','Mobile','Other')}
    foreach ($k in $sets.Keys) {
        if ($o.$k -isnot [string] -or $o.$k -cnotin $sets[$k]) {throw "Invalid preference: $k"}
        $out[$k]=$o.$k
    }
    foreach ($k in @('Startup','Fetch','FetchAnimation','Icons')) {
        if ($o.$k -isnot [bool]) {throw "Invalid preference: $k"}; $out[$k]=$o.$k
    }
    # Schema 1 backups created before 2.3.1 have neither return option.
    $returnDefaults=@{ClearOnReturn=$true;LoadingOnReturn=$false;ShowComputerName=$true}
    foreach ($k in $returnDefaults.Keys) {
        if (-not $o.PSObject.Properties[$k]) {$out[$k]=$returnDefaults[$k]}
        elseif ($o.$k -isnot [bool]) {throw "Invalid preference: $k"}
        else {$out[$k]=$o.$k}
    }
    if ($o.Name -isnot [string] -or $o.Name.Length -gt 32 -or $o.Name -match '[\x00-\x1F\x7F-\x9F\u202A-\u202E\u2066-\u2069]') {throw 'Invalid display name.'}
    if ($o.Accent -isnot [string] -or $o.Accent -notmatch '^[0-9a-fA-F]{6}$') {throw 'Invalid accent.'}
    if ($o.CustomLogo -isnot [string]) {throw 'Invalid logo.'}
    $out.ReleaseRepo='owoNEXowo/NEX-Dashboard'
    $out.ComputerAlias=''
    if ($o.PSObject.Properties['ComputerAlias']) {
        if ($o.ComputerAlias -isnot [string] -or $o.ComputerAlias.Length -gt 32 -or $o.ComputerAlias -cne (Normalize-NexIdentityPart $o.ComputerAlias)) {throw 'Invalid computer alias.'}
        $out.ComputerAlias=$o.ComputerAlias
    }
    $out.Name=$o.Name; $out.Accent=$o.Accent; $out.CustomLogo=Normalize-NexLogo $o.CustomLogo
    $extra=Normalize-NexExtras $o;foreach ($k in $extra.Keys) {$out[$k]=$extra[$k]}
    return $out
}
function global:Get-NexBackupScheme($o) {
    if ($null -eq $o) {return $null}
    if ($o -isnot [pscustomobject] -or $o.name -isnot [string] -or $o.name.Length -gt 100 -or -not $o.name -or $o.name -match '[\x00-\x1F\x7F-\x9F]') {throw 'Invalid color scheme.'}
    $out=[ordered]@{name=$o.name}
    foreach ($k in @('background','foreground','cursorColor','selectionBackground','black','red','green','yellow','blue','purple','cyan','white','brightBlack','brightRed','brightGreen','brightYellow','brightBlue','brightPurple','brightCyan','brightWhite')) {
        if ($o.$k -isnot [string] -or $o.$k -notmatch '^#[0-9a-fA-F]{6}$') {throw "Invalid scheme color: $k"}
        $out[$k]=$o.$k
    }
    return [pscustomobject]$out
}
function global:Get-NexBackupAppearance($o) {
    if ($o -isnot [pscustomobject]) {throw (NexL 'Invalid configuration file.')}
    $out=@{}
    foreach ($k in @('background','foreground','cursorColor','selectionBackground')) {
        if ($o.$k -isnot [string] -or $o.$k -notmatch '^#[0-9a-fA-F]{6}$') {throw "Invalid appearance: $k"};$out[$k]=$o.$k
    }
    if ($o.colorScheme -isnot [string] -or $o.colorScheme.Length -gt 100 -or -not $o.colorScheme -or $o.colorScheme -match '[\x00-\x1F\x7F-\x9F]') {throw 'Invalid color scheme name.'}
    if ($o.fontFace -isnot [string] -or -not $o.fontFace -or $o.fontFace.Length -gt 100 -or $o.fontFace -match '[\x00-\x1F\x7F-\x9F]') {throw 'Invalid font name.'}
    if ($o.opacity -isnot [int] -and $o.opacity -isnot [long]) {throw 'Invalid opacity.'}
    if ($o.opacity -lt 0 -or $o.opacity -gt 100 -or $o.useAcrylic -isnot [bool]) {throw 'Invalid opacity/acrylic.'}
    if ($o.fontSize -isnot [int] -and $o.fontSize -isnot [long] -and $o.fontSize -isnot [double] -and $o.fontSize -isnot [decimal]) {throw 'Invalid font size.'}
    if ($o.fontSize -lt 1 -or $o.fontSize -gt 128 -or $o.cursorShape -cnotin @('bar','filledBox','emptyBox','underscore','vintage','doubleUnderscore')) {throw 'Invalid font size/cursor.'}
    foreach ($k in @('colorScheme','fontFace','opacity','useAcrylic','fontSize','cursorShape')) {$out[$k]=$o.$k}
    return $out
}
function global:Get-NexPortableFetch([string]$text) {
    # Conservative subset: built-in modules and logos only. No commands or external assets.
    if (-not $text -or $text.Length -gt 262144) {throw 'Unsupported Fastfetch configuration.'}
    $o=ParseConfig $text
    if ($o -isnot [pscustomobject]) {throw 'Unsupported Fastfetch configuration.'}
    foreach ($p in $o.PSObject.Properties) {if ($p.Name -cnotin @('$schema','logo','display','modules','general')) {throw 'Unsupported Fastfetch setting.'}}
    if ($o.general) {
        if ($o.general -isnot [pscustomobject]) {throw 'Unsupported Fastfetch general settings.'}
        foreach ($p in $o.general.PSObject.Properties) {if ($p.Name -notin @('thread','multithreading','processingTimeout','detectVersion','showErrors','escapeBedrock')) {throw 'Unsupported Fastfetch general option.'}}
    }
    $safeTypes=@('title','separator','os','host','kernel','uptime','packages','shell','display','de','wm','wmtheme','theme','icons','font','cursor','terminal','terminalfont','terminalsize','cpu','cpuusage','gpu','memory','swap','disk','battery','poweradapter','locale','localip','netio','diskio','physicaldisk','sound','player','media','processes','datetime','colors','break','custom','board','bios','chassis','bootmgr','monitor','version')
    foreach ($m in @($o.modules)) {
        $type=if ($m -is [string]) {$m} elseif ($m -is [pscustomobject]) {$m.type} else {''}
        if ($type -notin $safeTypes) {throw 'External or unsupported Fastfetch module.'}
    }
    if ($o.logo) {
        if ($o.logo -is [string]) {if ($o.logo -notmatch '^[\p{L}\p{N} _-]{1,80}$') {throw 'External logo not supported.'};$o.logo=[pscustomobject]@{type='builtin';source=$o.logo}}
        elseif ($o.logo -is [pscustomobject]) {
            if ($o.logo.type -and $o.logo.type -notin @('auto','builtin','small','none')) {throw 'External logo not supported.'}
            if ($o.logo.source -and ($o.logo.source -isnot [string] -or $o.logo.source -notmatch '^[\p{L}\p{N} _-]{1,80}$' -or $o.logo.type -notin @('builtin','small'))) {throw 'External logo not supported.'}
        } else {throw 'External logo not supported.'}
    }
    # Recursively reject executable or file-backed options even inside nested objects.
    $queue=New-Object 'System.Collections.Generic.Queue[object]';$queue.Enqueue($o)
    while ($queue.Count) {
        $node=$queue.Dequeue()
        if ($node -is [pscustomobject]) {
            foreach ($p in $node.PSObject.Properties) {
                if ($p.Name -match '(?i)command|exec|script|file|path|cache|url|image|prerun|postrun' -and $p.Name -ne '$schema') {throw 'External Fastfetch option not supported.'}
                if ($p.Name -ne '$schema' -and $null -ne $p.Value) {$queue.Enqueue($p.Value)}
            }
        } elseif ($node -is [array]) {foreach ($v in $node) {if ($null -ne $v) {$queue.Enqueue($v)}}}
        elseif ($node -is [string] -and $node -match '[\x00-\x08\x0B-\x1F\x7F-\x9F]') {throw 'Control characters not supported.'}
    }
    return (ConvertTo-Json -InputObject $o -Depth 50)
}
function global:Write-NexBackupData([string]$path,[string]$text) {
    $tmp=$path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try {
        [IO.File]::WriteAllText($tmp,$text,(New-Object System.Text.UTF8Encoding($false)))
        if (Test-Path -LiteralPath $path -PathType Leaf) {[IO.File]::Replace($tmp,$path,[System.Management.Automation.Language.NullString]::Value)}
        else {[IO.File]::Move($tmp,$path)}
    } finally {if (Test-Path -LiteralPath $tmp) {Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}}
}
function global:Get-NexBackupFontAvailable([string]$face) {
    if ($face -eq 'JetBrainsMono Nerd Font Mono') {return (Test-NexNerdFont)}
    try {Add-Type -AssemblyName System.Drawing -ErrorAction Stop; $fc=New-Object System.Drawing.Text.InstalledFontCollection;try {return [bool]@($fc.Families | Where-Object Name -eq $face).Count} finally {$fc.Dispose()}} catch {return $false}
}

function global:Get-NexCustomFetchConfig {
    $managed=Join-Path $env:LOCALAPPDATA 'NexDashboard\restored-fastfetch.json'
    if (Test-Path -LiteralPath $managed -PathType Leaf) {try {$null=Get-NexPortableFetch ([IO.File]::ReadAllText($managed));return $managed} catch {}}
    $paths=@((Join-Path $HOME '.config\fastfetch\config.jsonc'),(Join-Path $HOME '.config\fastfetch\config.json'))
    foreach ($base in @($env:XDG_CONFIG_HOME,$env:APPDATA,$env:LOCALAPPDATA)) {
        if ($base) {$paths+=Join-Path $base 'fastfetch\config.jsonc';$paths+=Join-Path $base 'fastfetch\config.json'}
    }
    return ($paths | Select-Object -Unique | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf} | Select-Object -First 1)
}

function global:Show-NexPublicFetch {
    param([int]$Width=0,[switch]$AsLines,[switch]$NoAnimation,[hashtable]$Snapshot,[switch]$CompactLayout)
    if ($Width -le 0) { $Width=[Console]::WindowWidth }
    $Width=[Math]::Max(1,$Width)
    $p=Get-NexPalette;$a=NexAnsi $p[0];$b=NexAnsi $p[1];$z="$([char]27)[0m";$white=NexAnsi $p[4];$muted=NexAnsi $p[5]
    $c=$global:NexPublicSettings;$mode=if ($CompactLayout) {'Compact'} else {$c.FetchPreset}
    # Reveal only after output is collected; no extra native process or fake loading.
    function FetchEmit([string]$line) {
        # Leave one cell unused so Windows Terminal never autowraps a complete frame.
        $limit=[Math]::Max(0,$Width-1)
        if ((Get-NexLogoWidth ($line -replace '\x1b\[[0-9;]*m','')) -gt $limit) {
            $result=New-Object System.Text.StringBuilder
            $used=0
            foreach ($part in [regex]::Matches($line,'\x1b\[[0-9;]*m|\P{M}\p{M}*|\p{M}+')) {
                $token=$part.Value
                if ($token -match '^\x1b\[') {$null=$result.Append($token);continue}
                $cells=Get-NexLogoWidth $token
                if ($used+$cells -gt $limit) {break}
                $null=$result.Append($token);$used+=$cells
            }
            $line=$result.ToString()+$z
        }
        if ($AsLines) {return $line}
        Write-Host $line
        if (-not $NoAnimation -and $c.FetchAnimation -and -not [Console]::IsOutputRedirected) {Start-Sleep -Milliseconds (@{Fast=7;Normal=18;Slow=40}[[string]$c.AnimationSpeed])}
    }
    if ($mode -like 'Fastfetch*') {
        $ff=Get-NexFastfetch
        if ($ff) {
            $old=[Console]::OutputEncoding
            $logoTemp=$null; $titleTemp=$null; $logoArgs=@(); $nativeCustom=$false
            $themeArgs=@('--color-keys',('#'+$p[0]),'--color-title',('#'+$p[1]),'--logo-color-1',('#'+$p[0]),'--logo-color-2',('#'+$p[1]))
            try {
                [Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
                if ($c.CustomLogo) {
                    $logoTemp=Join-Path $env:TEMP ('nex-logo-'+[guid]::NewGuid().ToString('N')+'.txt')
                    $coloredLogo=@($c.CustomLogo -split "`n" | ForEach-Object {$a+$_+$z}) -join "`n"
                    [IO.File]::WriteAllText($logoTemp,($coloredLogo+"`n"),(New-Object System.Text.UTF8Encoding($false)))
                    $logoArgs=@('--logo-type','file-raw','--logo',$logoTemp)
                }
                # Use JSON title format rather than version-dependent CLI title flags.
                $titleTemp=Join-Path $env:TEMP ('nex-title-'+[guid]::NewGuid().ToString('N')+'.json')
                $identity=Get-NexIdentity
                # Prefix with a fixed color token so user text is always literal, never a script.
                $rgb=(NexAnsi $p[0]) -replace '^\x1b\[|m$',''
                $format='{#'+$rgb+'}'+$identity.Replace('{','{{')+'{#}'
                $titleModule=@{type='title';format=$format}
                $sepModule=@{type='separator';times=[Math]::Max(1,(Get-NexLogoWidth $identity))}
                $modules=@($titleModule,$sepModule)
                foreach ($kind in @('os','kernel','uptime','cpu','gpu','memory','disk','terminal','shell')) {
                    $hue=Get-NexFetchHue $kind $p
                    $modules+=@{type=$kind;keyColor=('#'+$hue);outputColor=('#'+(Mix-NexColor $hue $p[4] 0.68))}
                }
                $modules+='colors' 
                [IO.File]::WriteAllText($titleTemp,(@{modules=$modules} | ConvertTo-Json -Depth 6),(New-Object System.Text.UTF8Encoding($false)))
                if ($mode -eq 'Fastfetch classic') {
                    $lines=@(& $ff --config $titleTemp --pipe false @themeArgs @logoArgs 2>$null)
                } else {
                    $custom=Get-NexCustomFetchConfig
                    if ($custom) {$nativeCustom=$true;$lines=@(& $ff --config $custom --pipe false @themeArgs @logoArgs 2>$null)}
                    else {
                        Write-Host "$muted$(NexL 'No custom config found; using themed Fastfetch.')$z"
                        $lines=@(& $ff --config $titleTemp --pipe false @themeArgs @logoArgs 2>$null)
                    }
                }
                if ($LASTEXITCODE -eq 0 -and $lines.Count) {
                    # A custom config may use an arbitrary title. Only substitute its standard user@host title, never edit its file.
                    $titlePattern=$null
                    if ($nativeCustom -and $env:USERNAME -and $env:COMPUTERNAME) {
                        $ansi='(?:\x1b\[[0-9;]*m)*'
                        $titlePattern='(?i)'+[regex]::Escape($env:USERNAME)+$ansi+'@'+$ansi+[regex]::Escape($env:COMPUTERNAME)+'(?![\w.-])'
                    }
                    $titleChanged=$false
                    foreach ($line in $lines) {
                        if ($titlePattern -and -not $titleChanged) {
                            $match=[regex]::Match([string]$line,$titlePattern)
                            if ($match.Success) {
                                $line=$line.Substring(0,$match.Index)+$a+$identity+$z+$line.Substring($match.Index+$match.Length)
                                $titleChanged=$true
                            }
                        }
                        FetchEmit $line
                    };return
                }
            } catch {} finally {[Console]::OutputEncoding=$old; if ($logoTemp) {Remove-Item -LiteralPath $logoTemp -Force -ErrorAction SilentlyContinue};if ($titleTemp) {Remove-Item -LiteralPath $titleTemp -Force -ErrorAction SilentlyContinue}}
            Write-Host "$muted$(NexL 'Fastfetch failed; showing built-in Cards.')$z"
        } else {
            Write-Host "$muted$(NexL 'Fastfetch missing; showing built-in Cards.')$z"
        }
        $mode='Cards'
    }
    # Built-in presets do not require Fastfetch, internet or a specific GPU.
    try {
        if ($null -ne $Snapshot -and $Snapshot.ContainsKey('OS')) {
            $os=$Snapshot.OS;$cpu=$Snapshot.CPU;$gpu=@($Snapshot.GPU);$disks=@($Snapshot.Disks);$cv=$Snapshot.CV
        } else {
            $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $cpu=Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
            $gpu=@(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object {$_.Name})
            $disks=@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | Select-Object -First 4)
            $cv=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
            if ($null -ne $Snapshot) {$Snapshot.OS=$os;$Snapshot.CPU=$cpu;$Snapshot.GPU=$gpu;$Snapshot.Disks=$disks;$Snapshot.CV=$cv}
        }
        $memTotal=[double]$os.TotalVisibleMemorySize
        $memUsed=$memTotal-[double]$os.FreePhysicalMemory
        $mem='{0:0.0} / {1:0.0} GiB' -f ($memUsed/1MB),($memTotal/1MB)
        $ramPct=if ($memTotal -gt 0) {100*$memUsed/$memTotal} else {0}
        $mem+=' ({0:0}%)' -f $ramPct
        $name=Get-NexName
        $icons=[bool]$c.Icons
        function FetchIcon([int]$id,[string]$fallback) {
            if ($icons) {return [char]::ConvertFromUtf32($id)};return $fallback
        }
        function FetchClean([string]$v) {return ($v -replace '[\x00-\x1F\x7F-\x9F]',' ')}
        function FetchFit([string]$v,[int]$width) {
            $v=FetchClean $v
            if ($width -le 0) {return ''}
            $cells=Get-NexLogoWidth $v
            if ($cells -le $width) {return ($v+(' '*($width-$cells)))}
            $result=New-Object System.Text.StringBuilder
            $used=0;$it=[Globalization.StringInfo]::GetTextElementEnumerator($v)
            while ($it.MoveNext()) {
                $part=$it.GetTextElement();$n=Get-NexLogoWidth $part
                if ($used+$n -gt $width-1) {break}
                $null=$result.Append($part);$used+=$n
            }
            return ($result.ToString()+'…'+(' '*[Math]::Max(0,$width-$used-1)))
        }
        function FetchRow([int]$icon,[string]$fallback,[string]$label,[string]$value) {
            return @{Icon=(FetchIcon $icon $fallback);Label=(NexL $label);Value=(FetchClean $value)}
        }
        function FetchHex([string]$label,[string]$value='') {
            if ($label -in @((NexL 'Processor'),(NexL 'Graphics'))) {return (Get-NexVendorColor $value $p[4])}
            if ($label -match '^[A-Z]:$') {return (Get-NexFetchHue 'disk' $p)}
            $kind=if ($label -eq (NexL 'Memory')) {'memory'}
                elseif ($label -eq (NexL 'OS')) {'os'}
                elseif ($label -eq (NexL 'Build')) {'kernel'}
                elseif ($label -eq (NexL 'Shell')) {'shell'}
                elseif ($label -eq (NexL 'Terminal')) {'terminal'}
                elseif ($label -eq (NexL 'Uptime')) {'uptime'}
                elseif ($label -eq (NexL 'Date')) {'date'}
                else {''}
            return (Get-NexFetchHue $kind $p)
        }
        function FetchTone([string]$label,[string]$value='') {return (NexAnsi (FetchHex $label $value))}
        function FetchValueTone($entry) {
            return (NexAnsi (Mix-NexColor (FetchHex $entry.Label $entry.Value) $p[4] 0.68))
        }
        $hardware=@((FetchRow 0xF2DB 'C' 'Processor' $cpu.Name))
        foreach ($gpuName in @($gpu)) {$hardware+=FetchRow 0xF108 'G' 'Graphics' $gpuName}
        if (-not $gpu.Count) {$hardware+=FetchRow 0xF108 'G' 'Graphics' (NexL 'Not detected')}
        $hardware+=FetchRow 0xEFC5 'M' 'Memory' $mem
        foreach ($disk in $disks) {
            if ($disk.Size -gt 0) {
                $pct=100*(1-$disk.FreeSpace/$disk.Size)
                $hardware+=FetchRow 0xF0A0 'D' ($disk.DeviceID) ('{0:0.0} / {1:0.0} GiB ({2:0}%)' -f (($disk.Size-$disk.FreeSpace)/1GB),($disk.Size/1GB),$pct)
            }
        }
        $build=[string]$os.BuildNumber
        if ($null -ne $cv.UBR) {$build+='.'+$cv.UBR}
        $terminalName=if ($env:WT_SESSION -or $env:WT_PROFILE_ID) {'Windows Terminal'} elseif ($env:TERM_PROGRAM) {$env:TERM_PROGRAM} else {'ConsoleHost'}
        $software=@(
            (FetchRow 0xF17A 'W' 'OS' ([string]$os.Caption+' '+$cv.DisplayVersion))
            (FetchRow 0xF013 '#' 'Build' $build)
            (FetchRow 0xF120 '>' 'Shell' ('PowerShell '+$PSVersionTable.PSVersion))
            (FetchRow 0xF108 'T' 'Terminal' $terminalName)
        )
        $system=@((FetchRow 0xF017 'U' 'Uptime' (((Get-Date)-$os.LastBootUpTime).ToString('dd\.hh\:mm\:ss'))))
        $system+=FetchRow 0xF073 'T' 'Date' (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        $title=FetchClean (Get-NexIdentity)
        FetchEmit "$a$title$z"
        $customLogoLines=@()
        if ($c.CustomLogo) {$customLogoLines=@($c.CustomLogo -split "`n")}
        if ($customLogoLines.Count -and $mode -in @('Minimal','Compact') -and -not $CompactLayout) {
            foreach ($artLine in $customLogoLines) {FetchEmit ($a+$artLine+$z)}
            FetchEmit ''
        }
        if ($mode -eq 'Minimal') {
            FetchEmit "$(NexAnsi (Get-NexFetchHue 'os' $p))$(FetchIcon 0xF17A 'W') $white$(FetchClean $os.Caption) $muted| $(NexAnsi (Get-NexFetchHue 'memory' $p))$(FetchIcon 0xEFC5 'M') $white$mem$z";return
        }
        if ($mode -eq 'Compact') {
            foreach ($row in ($hardware+$software+$system)) {
                FetchEmit "$(FetchTone $row.Label $row.Value)$( $row.Icon) $(FetchFit $row.Label 14)$z $(FetchValueTone $row)$($row.Value)$z"
            }
            return
        }
        $window=$Width
        if ($window -lt 28) {
            foreach ($row in ($hardware+$software+$system)) {FetchEmit "$a$($row.Label): $white$($row.Value)$z"}
            return
        }
        $logoPane=if ($window -ge 112) {10} else {7}
        $logoWidth=2*$logoPane+3;$withLogo=$window -ge 80
        if ($customLogoLines.Count) {
            $logoWidth=0
            foreach ($artLine in $customLogoLines) {$logoWidth=[Math]::Max($logoWidth,(Get-NexLogoWidth $artLine))}
            $withLogo=($window-$logoWidth-3 -ge 40)
            if (-not $withLogo) {
                foreach ($artLine in $customLogoLines) {FetchEmit ($a+$artLine+$z)}
                FetchEmit ''
            }
        }
        $indent=if ($withLogo) {$logoWidth+3} else {0}
        $inner=[Math]::Max(20,[Math]::Min(99,$window-$indent-3))
        $labelWidth=[Math]::Max(8,[Math]::Min(14,[int]($inner/3)))
        function FetchCard([string]$heading,$entries,[string]$color) {
            $titleText=' '+(NexL $heading)+' '
            if ($titleText.Length -gt $inner) {$titleText=$titleText.Substring(0,$inner)}
            $left=[int][Math]::Floor(($inner-$titleText.Length)/2)
            $right=$inner-$left-$titleText.Length
            "$color╭$('─'*$left)$titleText$('─'*$right)╮$z"
            foreach ($entry in $entries) {
                $key=FetchFit $entry.Label $labelWidth
                $iconWidth=Get-NexLogoWidth $entry.Icon
                $value=FetchFit $entry.Value ($inner-$labelWidth-4-$iconWidth)
                "$color│$z $(FetchTone $entry.Label $entry.Value)$($entry.Icon) $key$z $(FetchValueTone $entry)$value$z $color│$z"
            }
            "$color╰$('─'*$inner)╯$z"
        }
        # Public preset gallery. Each mode uses the same detected hardware and current theme.
        $groups=@(
            @{Title='Hardware';Items=$hardware;Color=$a},
            @{Title='Software';Items=$software;Color=$b},
            @{Title='System';Items=$system;Color=$a}
        )
        if ($mode -eq 'Studio') {
            if (-not $customLogoLines.Count) {$withLogo=$false; $indent=0}
            $inner=[Math]::Max(20,[Math]::Min(99,$window-$indent-3))
            $labelWidth=[Math]::Max(8,[Math]::Min(16,[int]($inner/3)))
        }
        function FetchStyledRow($entry,[string]$color,[string]$prefix,[int]$width) {
            $key=FetchFit $entry.Label $labelWidth
            $value=FetchFit $entry.Value ([Math]::Max(1,$width-$labelWidth-$prefix.Length-4))
            return "$color$prefix$(if ($mode -eq 'Color Labels' -and $entry.Label -notin @((NexL 'Processor'),(NexL 'Graphics'))) {$color} else {FetchTone $entry.Label $entry.Value})$($entry.Icon) $key$z $(FetchValueTone $entry)$value$z"
        }
        $rows=@()
        switch ($mode) {
            'Neon Frame' {
                foreach ($group in $groups) {
                    $color=$group.Color
                    $head=FetchFit ('◆ '+(NexL $group.Title).ToUpperInvariant()+' ') ([Math]::Min($inner-2,22))
                    $rows+= "$color╭─$head$('─'*($inner-2-$head.Length))─╮$z"
                    foreach ($entry in $group.Items) {
                        $rows+= "$color│$z$(FetchStyledRow $entry $color ' ' $inner) $color│$z"
                    }
                    $rows+= "$color╰$('─'*$inner)╯$z"
                    $rows+=''
                }
            }
            'Color Labels' {
                $labelWidth=[Math]::Max(8,[Math]::Min(12,[int]($inner/3)))
                $shades=@($a,$b,(NexAnsi 'A6E3A1'),(NexAnsi '89B4FA'),(NexAnsi 'FAB387'))
                $i=0
                foreach ($entry in ($software+$hardware+$system)) {
                    $color=$shades[$i%$shades.Count]
                    $rows+=FetchStyledRow $entry $color '' $inner
                    $i++
                }
            }
            'Tree Layout' {
                foreach ($group in $groups) {
                    $color=$group.Color
                    $head=' '+(NexL $group.Title)+' '
                    if ($head.Length -gt $inner-3) {$head=$head.Substring(0,$inner-3)}
                    $rows+="$color╭─$head$('─'*($inner-$head.Length-1))$z"
                    for ($i=0;$i -lt $group.Items.Count;$i++) {
                        $branch=if ($i -eq $group.Items.Count-1) {'╰─ '} else {'├─ '}
                        $rows+=FetchStyledRow $group.Items[$i] $color $branch $inner
                    }
                    $rows+="$muted $('─'*($inner-1))$z"
                    $rows+=''
                }
            }
            'Studio' {
                $rows+="$a$(FetchFit ((NexL 'System overview').ToUpperInvariant()) $inner)$z"
                $rows+="$b$('━'*$inner)$z"
                foreach ($group in $groups) {
                    $color=$group.Color
                    $rows+="$color$(NexL $group.Title)$z"
                    foreach ($entry in $group.Items) {
                        $rows+=FetchStyledRow $entry $color '  ' $inner
                    }
                    if ($group.Title -eq 'Hardware') {
                        $barWidth=[Math]::Min(30,[Math]::Max(5,$inner-14))
                        $fill=[int][Math]::Round($barWidth*[Math]::Max(0,[Math]::Min(100,$ramPct))/100)
                        $rows+="$muted RAM $a$('━'*$fill)$muted$('─'*($barWidth-$fill))$z $white$('{0:0}%' -f $ramPct)$z"
                    }
                    $rows+="$muted$('─'*$inner)$z"
                }
            }
            default {
                $rows=@(FetchCard 'Hardware' $hardware $a)+@('')+@(FetchCard 'Software' $software $b)+@('')+@(FetchCard 'System' $system $a)
            }
        }
        if ($rows.Count -and $rows[-1] -eq '') { $rows=@($rows | Select-Object -First ($rows.Count-1)) }
        # Windows logo made of normal text cells: no external font is needed for it.
        $logo=@()
        for ($i=0;$i -lt 5;$i++) {$logo+=($a+('╱'*$logoPane)+'   '+$b+('╱'*$logoPane)+$z)}
        $logo+=''
        for ($i=0;$i -lt 5;$i++) {$logo+=($b+('╱'*$logoPane)+'   '+$a+('╱'*$logoPane)+$z)}
        if ($customLogoLines.Count) {$logo=@($customLogoLines | ForEach-Object {$a+$_+$z})}
        $height=if ($withLogo) {[Math]::Max($rows.Count,$logo.Count)} else {$rows.Count}
        $top=[int][Math]::Max(0,[Math]::Floor(($height-$logo.Count)/2))
        $infoTop=if ($withLogo -and $customLogoLines.Count) {[int][Math]::Floor(($height-$rows.Count)/2)} else {0}
        for ($i=0;$i -lt $height;$i++) {
            $prefix=''
            if ($withLogo) {
                $li=$i-$top
                $prefix=' '*$indent
                if ($li -ge 0 -and $li -lt $logo.Count -and $logo[$li]) {
                    $plainLogo=if ($customLogoLines.Count) {$customLogoLines[$li]} else {$logo[$li] -replace '\x1B\[[0-9;]*m',''}
                    $padding=[Math]::Max(0,$indent-(Get-NexLogoWidth $plainLogo))
                    $prefix=$logo[$li]+(' '*$padding)
                }
            }
            $ri=$i-$infoTop
            $infoLine=if ($ri -ge 0 -and $ri -lt $rows.Count) {$rows[$ri]} else {''}
            FetchEmit ($prefix+$infoLine)
        }
        FetchEmit (' '*$indent+$a+'● '+$b+'● '+(NexAnsi '89B4FA')+'● '+(NexAnsi 'A6E3A1')+'● '+(NexAnsi 'FAB387')+'● '+$white+'●'+$z)
    } catch {Write-Warning (((NexL 'Startup info')+': ')+$_.Exception.Message)}
}
function global:NexFetch {
    $global:NexPublicSettings=Get-NexPreferences
    Show-NexPublicFetch
}
function global:Show-NexLoadingScreen {
    param([switch]$PreserveScreen,[switch]$InAlternateBuffer)
    $e=[char]27;$z="$e[0m";$p=Get-NexPalette;$a=NexAnsi $p[0];$b=NexAnsi $p[1]
    if ([Console]::IsOutputRedirected -or $Host.Name -ne 'ConsoleHost') {return}
    try {
        if ($InAlternateBuffer) {Write-Host "$z$e[2J$e[H" -NoNewline}
        elseif ($PreserveScreen) {Write-Host "$e[?1049h$e[2J$e[H" -NoNewline}
        else {Clear-Host}
        Write-Host "$e[?25l" -NoNewline
        $w=[Math]::Max(8,[Math]::Min(36,[Console]::WindowWidth-12));$x=[Math]::Max(1,[int][Math]::Floor(([Console]::WindowWidth-$w-6)/2));$y=[Math]::Max(1,[int]([Console]::WindowHeight/2)-2)
        $title=(NexL 'Welcome back')+' / '+(Get-NexName);if ($title.Length -gt $w+5) {$title=$title.Substring(0,$w+5)}
        $delay=@{Fast=8;Normal=22;Slow=48}[[string]$global:NexPublicSettings.AnimationSpeed]
        $style=[string]$global:NexPublicSettings.LoadingStyle
        for ($i=0;$i -le $w;$i++) {
            $pct=[int](100*$i/$w)
            $line=switch ($style) {
                'Pulse' { $n=[Math]::Min($w-1,$i);$b+('─'*$n)+$a+'◆'+$b+('─'*($w-$n-1))+$z;break }
                'Wave' { $wave='';for ($j=0;$j -lt $w;$j++) {$wave+=$(if (($j+$i)%8 -lt 3) {$a+'━'} else {$b+'─'})};$wave+$z;break }
                'Dots' { $a+('● '*[Math]::Min(4,1+[int]($i/4)%4))+$z;break }
                'Minimal' { $a+(NexL 'Loading')+$z;break }
                default {$a+('━'*$i)+$b+('─'*($w-$i))+$z}
            }
            Write-Host "$e[${y};${x}H$a$title$z$e[$($y+2);${x}H$line $pct% $z$e[K" -NoNewline
            Start-Sleep -Milliseconds $delay
        }
    } finally {
        if ($InAlternateBuffer) {Write-Host $z -NoNewline}
        elseif ($PreserveScreen) {Write-Host "$z$e[?1049l$e[?25h" -NoNewline}
        else {Write-Host "$z$e[?25h" -NoNewline;Clear-Host}
    }
}
function global:Show-NexResponsiveStartupFetch {
    # Only a fresh, interactive built-in fetch can be safely repainted.
    # An alternate buffer keeps normal console history and typed commands untouched.
    $c=$global:NexPublicSettings
    if ($c.FetchPreset -like 'Fastfetch*' -or -not ($env:WT_SESSION -or $env:WT_PROFILE_ID) -or [Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {Show-NexPublicFetch;return}
    $snapshot=@{};$e=[char]27;$z="$e[0m";$lastSize='';$entered=$false
    try {
        # Do not consume any key: PSReadLine receives the original input after the preview.
        if ([Console]::KeyAvailable) {Show-NexPublicFetch;return}
        Write-Host "$e[?1049h$e[?25l" -NoNewline;$entered=$true
        while (-not [Console]::KeyAvailable) {
            $w=[Console]::WindowWidth;$h=[Console]::WindowHeight;$size="${w}x${h}"
            if ($size -ne $lastSize) {
                $lines=@(Show-NexPublicFetch -Width $w -AsLines -NoAnimation -Snapshot $snapshot)
                $path=(Get-Location).Path
                if ($path -eq $HOME) {$path='~'} elseif ($HOME -and $path.StartsWith($HOME+'\',[StringComparison]::OrdinalIgnoreCase)) {$path='~'+$path.Substring($HOME.Length)}
                $promptLines=if ($c.Prompt -eq 'Keep existing') {@('PS '+$path+'> ')} else {@(Get-NexPromptLines $c.Prompt (Get-NexIdentity) $path (Get-Date -Format 'HH:mm:ss') $true '' ([bool]$c.Icons))}
                $room=[Math]::Max(0,$h-$promptLines.Count-2)
                if ($lines.Count -gt $room) {$lines=@(Show-NexPublicFetch -Width $w -AsLines -NoAnimation -Snapshot $snapshot -CompactLayout)}
                if ($lines.Count -gt $room) {$lines=@($lines | Select-Object -First $room)}
                if ("$([Console]::WindowWidth)x$([Console]::WindowHeight)" -ne $size) {continue}
                Write-Host "$e[2J$e[H" -NoNewline
                foreach ($line in $lines) {
                    if ([Console]::WindowWidth -ne $w) {break}
                    Write-Host $line
                }
                Write-Host ''
                foreach ($line in $promptLines) {
                    if ([Console]::WindowWidth -ne $w) {break}
                    # A very narrow prompt may be longer than the viewport; use a short preview.
                    if ((Get-NexLogoWidth ($line -replace '\x1b\[[0-9;]*m','')) -ge $w) {$line='PS > '}
                    Write-Host $line
                }
                $lastSize=$size
            }
            Start-Sleep -Milliseconds 100
        }
    } catch {} finally {if ($entered) {Write-Host "$z$e[?1049l$e[?25h" -NoNewline}}
    Show-NexPublicFetch -NoAnimation -Snapshot $snapshot
}
function global:Show-NexPublicStartup {
    $c=$global:NexPublicSettings
    if ($c.Startup) {Show-NexLoadingScreen}
    if ($c.Fetch) {Show-NexResponsiveStartupFetch}
}
function global:Initialize-NexPublic {
    $argsList=[Environment]::GetCommandLineArgs()
    if ($Host.Name -ne 'ConsoleHost' -or [Console]::IsOutputRedirected -or [Console]::IsInputRedirected -or ($argsList -match '^[-/](NonInteractive|File)$') -or (($argsList -match '^[-/]Command$') -and -not ($argsList -match '^[-/]NoExit$'))) {return}
    if (-not $global:NexPublicInitialized) {$global:NexPublicInitialized=$true;$global:NexPublicPending=$true;$global:NexPublicOldPrompt=(Get-Command prompt -ErrorAction SilentlyContinue).ScriptBlock}
    try {if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {Set-PSReadLineOption -PredictionSource $global:NexPublicSettings.Prediction -ErrorAction Stop}} catch {}
    function global:prompt {
        $ok=$?
        try {
            $prefFile=Join-Path $env:LOCALAPPDATA 'NexDashboard\preferences.json'
            $stamp=[IO.File]::GetLastWriteTimeUtc($prefFile).Ticks
            if ($global:NexPublicPrefStamp -ne $stamp) {
                $global:NexPublicSettings=Get-NexPreferences
                $global:NexPublicPrefStamp=$stamp
            }
        } catch {}
        $c=$global:NexPublicSettings
        if ($global:NexPublicPending) {$global:NexPublicPending=$false;try {Show-NexPublicStartup} catch {}}
        if ($c.Prompt -eq 'Keep existing' -and $global:NexPublicOldPrompt) {& $global:NexPublicOldPrompt;return}
        $path=(Get-Location).Path;$time=Get-Date -Format 'HH:mm:ss';$duration='';$last=Get-History -Count 1 -ErrorAction SilentlyContinue
        if ($last -and $last.CommandLine.Trim() -notmatch '^(?i:dashboard|monitor)(?:\s|$)') {$seconds=($last.EndExecutionTime-$last.StartExecutionTime).TotalSeconds;if ($seconds -ge 1) {$duration=' │ '+('{0:0.0}s' -f $seconds)}}
        if ($path -eq $HOME) {$path='~'} elseif ($path.StartsWith($HOME+'\',[StringComparison]::OrdinalIgnoreCase)) {$path='~'+$path.Substring($HOME.Length)}
        $useIcons=[bool]$c.Icons
        $lines=@(Get-NexPromptLines $c.Prompt (Get-NexIdentity) $path $time $ok $duration $useIcons)
        if ($lines.Count -gt 1) {
            Write-Host ''
            for ($i=0;$i -lt $lines.Count-1;$i++) {Write-Host $lines[$i]}
        }
        return $lines[-1]
    }
}

function global:Invoke-NexDashboard {
    param([ValidateRange(0,20)][int]$StartPage=0)
    $e = [char]27; $reset = "$e[0m"
    $pink = "$e[38;2;245;194;231m"; $purple = "$e[38;2;203;166;247m"
    $white = "$e[38;2;205;214;244m"; $gray = "$e[38;2;147;153;178m"
    $muted = "$e[38;2;88;91;112m"; $green = "$e[38;2;166;227;161m"
    $blue = "$e[38;2;137;180;250m"; $red = "$e[38;2;243;139;168m"
    $bg = "$e[48;2;69;49;79m"; $enc = New-Object System.Text.UTF8Encoding($true)
    $global:NexPublicSettings=Get-NexPreferences
    $prefs=$global:NexPublicSettings
    $fetchState=@{Available=[bool](Get-NexFastfetch)}
    $palette=Get-NexPalette
    $pink=NexAnsi $palette[0];$purple=NexAnsi $palette[1];$bg=NexAnsi $palette[2] -Background;$white=NexAnsi $palette[4];$gray=NexAnsi $palette[5]
    $names = @('Overview','System Monitor','Processes','Network','File Explorer','System Info','Windows Update','Quick Tools','System Logs','Terminal Settings','Personalization','Hardware Info','Gaming Mode','App Launcher','Update Center','System Health','Notification Center','Dashboard Designer','Startup Manager','Plugin Manager','Animation Studio') | ForEach-Object { NexL $_ }
    $codes = @(0xF015,0xF080,0xF2DB,0xF1EB,0xF07B,0xF05A,0xF021,0xF0AD,0xF15C,0xF013,0xF1DE,0xF2DB,0xF11B,0xF135,0xF021,0xF0FA,0xF0F3,0xF009,0xF135,0xF1E6,0xF0D0)
    # Sidebar order is independent from stable page IDs used by workers and shortcuts.
    $navOrder=@(0,1,2,11,3,5,4,13,12,18,7,15,8,16,10,9,17,20,19,6,14)
    # Separators are visual rows only; real page IDs and keyboard order remain separate.
    $navGroupStarts=@(4,15,10,6)
    $s = @{
        Page=$StartPage; Nav=$StartPage; NavOffset=0; Focus='nav'; Size=''; Old=@(); Hits=@(); Msg=''; Next=0L; Need=$true
        Folder=$HOME; Drives=$false; Pos=0; Filter=''; FileItems=@(); Clipboard=$null
        ProcFilter=''; ProcSort='CPU'; ProcRows=@(); PrevProc=@{}; ProcAt=0L; ProcMetrics=$null; ProcMetricsAt=0L
        NetRows=@(); NetPrev=@{}; NetAt=0L; NetHist=@(); NetUpHist=@(); NetReady=$false; Down=0.0; Up=0.0; PeakDown=0.0; PeakUp=0.0; Ping='Not sampled'; PingHost='';
        SpeedProc=$null; SpeedOut=$null; SpeedErr=$null; SpeedStart=0L; SpeedStatus='Ready'; SpeedResult=$null; SpeedPath=(Get-NexSpeedtest); SpeedInstallPending=$false; SpeedConsentPath='';
        Info=@(); Logs=@(); LogPos=0; LogName='System'; LogText=''; ToolRows=@(); ToolTitle='';
        Config=$null; ConfigChoices=@(); ConfigPick=$null; Mouse=$false; Mode=0; Theme=0; SettingsRows=@(); LastOverview=$null
    }
    $s.ExtraErrors=@{}; $s.ExtraPos=0; $s.ExtraMax=0; $s.Hardware=$null; $s.Game=$null; $s.GameChangedAt=-1L; $s.Apps=$null; $s.AppFilter=''; $s.Health=$null
    $s.Release=$null; $s.OnlineRequested=$false; $s.OnlineReady=$false; $s.OnlineTemp=$null; $s.PendingHash=$null; $s.AlertDismiss=@{}; $s.Alerts=@(); $s.HealthNext=0L; $s.PendingInstaller=$null; $s.PendingVersion=$null
    # Local event acknowledgement; intentionally not part of a portable appearance config.
    $eventCheckpoint=Join-Path $env:LOCALAPPDATA 'NexDashboard\events-cleared.utc'
    $s.EventCutoff=0L
    try {
        if (Test-Path -LiteralPath $eventCheckpoint -PathType Leaf) {
            $ticks=0L
            if ([long]::TryParse([IO.File]::ReadAllText($eventCheckpoint).Trim(),[ref]$ticks) -and $ticks -ge 0 -and $ticks -le [datetime]::MaxValue.Ticks) {$s.EventCutoff=$ticks}
        }
    } catch {}
    $s.AlertOverview=$null; $s.AlertGpu=@(); $s.AlertGpuAt=-100000L; $s.AlertSampleNext=0L
    $s.PersonalPos=0; $s.PersonalMax=0; $s.StartupRows=$null; $s.StartupAt=$null; $s.BatteryAt=-10000L; $s.BatteryState=$null
    $s.ShowHidden=$false; $s.FileSort='Name'; $s.UpdateStatus='Ready'; $s.UpdateRows=@(); $s.UpdatePos=0; $s.UpdateStart=0L
    $s.UpdateVersion='Unknown'; $s.UpdateChecked='Never'; $s.UpdateDisplayCount=0; $s.LastFileClick=''; $s.LastFileAt=-1000L
    try {
        $win=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $s.UpdateVersion="$($win.DisplayVersion) / Build $($win.CurrentBuild).$($win.UBR)"
    } catch {}
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $visual = @{}
    $s.AnimAt=0L
    $s.MonitorPos=0; $s.MonitorMax=0; $s.MonitorNetPrev=@{}; $s.MonitorHistoryCPU=@(); $s.MonitorHistoryGPU=@()
    $s.MonitorDown=$null; $s.MonitorUp=$null; $s.ProcMemoryTotal=$null
    if ($StartPage -eq 1) { $s.Focus='body' }
    $s.NetWindow=8000L
    $s.NetTime=New-Object 'System.Collections.Generic.List[long]'
    $s.NetHist=New-Object 'System.Collections.Generic.List[double]'
    $s.NetUpHist=New-Object 'System.Collections.Generic.List[double]' 
    $s.UiDown=0.0; $s.UiUp=0.0
    $s.NetFast=$false; $s.FastDisabled=$false; $s.NetAdapters=@(); $s.FastPrev=@{}; $s.FastAt=0L
    $s.ProcListKey=''; $s.ProcList=@()
    $s.NetChartKey=''; $s.NetChartDown=@(); $s.NetChartUp=@()

    # Time-based visual interpolation; sensor samples and test results stay intact.
    function SmoothNumber([string]$id,[double]$target,[double]$tau=0.55) {
        $at=$clock.ElapsedMilliseconds
        if (-not $visual.ContainsKey($id)) {
            $visual[$id]=@{Value=$target;At=$at}
            return $target
        }
        $v=$visual[$id]
        $dt=[Math]::Max(0.0,($at-$v.At)/1000.0)
        $alpha=1.0-[Math]::Exp(-$dt/$tau)
        $v.Value=[double]$v.Value+($target-[double]$v.Value)*$alpha
        if ([Math]::Abs($target-$v.Value) -lt 0.005) { $v.Value=$target }
        $v.At=$at
        return [double]$v.Value
    }
    function AnimateTraffic {
        if (-not $s.NetReady) { return }
        $s.UiDown=SmoothNumber 'net-down' $s.Down 0.18
        $s.UiUp=SmoothNumber 'net-up' $s.Up 0.18
        $at=$clock.ElapsedMilliseconds
        # Store timestamped visual samples, not a shifting fixed-size queue.
        $count=$s.NetTime.Count
        if ($count -gt 0 -and $at -le $s.NetTime[$count-1]) { return }
        $s.NetTime.Add([long]$at)
        $s.NetHist.Add([double](NetGraphY $s.UiDown))
        $s.NetUpHist.Add([double](NetGraphY $s.UiUp))
        $cutoff=$at-$s.NetWindow
        # Keep one older sample to interpolate the left edge.
        while ($s.NetTime.Count -gt 2 -and $s.NetTime[1] -le $cutoff) {
            $s.NetTime.RemoveAt(0)
            $s.NetHist.RemoveAt(0)
            $s.NetUpHist.RemoveAt(0)
        }
    }

    function SafeText($v) { ([string]$v -replace '[\x00-\x1F\x7F-\x9F]',' ') }
    function Fit($v,[int]$w) {
        $v = SafeText $v; if ($w -le 0) { return '' }
        $si = [System.Globalization.StringInfo]::new($v)
        if ($si.LengthInTextElements -gt $w) {
            if ($w -eq 1) { return '…' }
            $v = $si.SubstringByTextElements(0,$w-1)+'…'
        }
        $v + (' ' * [Math]::Max(0,$w-([System.Globalization.StringInfo]::new($v)).LengthInTextElements))
    }
    # The original monochrome Nerd Font glyphs, never emoji substitutions.
    # A compatible terminal font is required; the repair option installs it.
    function Icon([int]$n) {
        if (-not $prefs.Icons) {return ' '}
        return [char]::ConvertFromUtf32($n)
    }
    function Label($title,$value,[string]$valueColor=$white) {
        $label=SafeText (NexL $title); $val=SafeText $value
        $available=[Math]::Max(12,[int]$rightWidth)
        $reserve=[Math]::Min([Math]::Max(8,$val.Length),[Math]::Max(8,[int]($available*0.4)))
        $column=[Math]::Min([Math]::Max(24,$label.Length+2),[Math]::Max(4,$available-$reserve-1))
        "$gray$(Fit $label $column) $valueColor$(Fit $val ([Math]::Max(1,$available-$column-1)))$reset"
    }
    function SettingLine([string]$label,[string]$value,[int]$width,[string]$valueTone='',[int]$glyph=0) {
        $name=NexL $label
        if ($glyph -and $prefs.Icons) {$name=(Icon $glyph)+' '+$name}
        $col=[Math]::Min([Math]::Max(16,[int][Math]::Floor($width*0.60)),[Math]::Max(16,$width-14))
        $col=[Math]::Min($col,[Math]::Max(8,$width-11))
        $name=(Fit $name ([Math]::Max(1,$col-4))).TrimEnd()
        $dots='·'*[Math]::Max(2,$col-(Get-NexLogoWidth $name)-2)
        if (-not $valueTone) {$valueTone=$white}
        return "$purple$name $muted$dots $valueTone$(SafeText $value)$reset"
    }
    # Fixed logarithmic vertical scale, with higher resolution near idle.
    function NetGraphY([double]$value) {
        $v=[Math]::Max(0.0,[Math]::Min(1000.0,$value))
        if ($v -le 10.0) { return 7.0*[Math]::Log10(1.0+$v)/[Math]::Log10(11.0) }
        if ($v -le 100.0) { return 7.0+4.0*[Math]::Log10($v/10.0) }
        return 11.0+4.0*[Math]::Log10($v/100.0)
    }
    function NetPlotSamples($values,[int]$dots,[long]$at) {
        # Sample the same continuous time axis every frame. No rescaling or
        # periodic whole-queue jumps. The latest point is always at the right.
        $points=New-Object 'double[]' $dots
        $count=[Math]::Min($s.NetTime.Count,$values.Count)
        $lo=0
        for ($x=0;$x -lt $dots;$x++) {
            $points[$x]=-1.0
            if ($count -eq 0) { continue }
            $t=[double]$at-$s.NetWindow*(1.0-$x/[double]([Math]::Max(1,$dots-1)))
            if ($t -lt $s.NetTime[0]) { continue }
            while ($lo+1 -lt $count -and $s.NetTime[$lo+1] -le $t) { $lo++ }
            if ($lo+1 -ge $count) {
                $points[$x]=[double]$values[$lo]
            } else {
                $hi=$lo+1
                $span=[double]($s.NetTime[$hi]-$s.NetTime[$lo])
                $mix=if ($span -gt 0) { [Math]::Max(0.0,[Math]::Min(1.0,($t-$s.NetTime[$lo])/$span)) } else { 0.0 }
                $points[$x]=[double]$values[$lo]+([double]$values[$hi]-[double]$values[$lo])*$mix
            }
        }
        return ,$points
    }
    function Spark($values) {
        if (-not $s.NetTime.Count) { return (' '*32) }
        $at=$s.NetTime[$s.NetTime.Count-1]
        $points=NetPlotSamples $values 32 $at
        $chars='▁▂▃▄▅▆▇█'; $str=''
        foreach ($v in $points) {
            if ($v -lt 0) { $str+=' '; continue }
            $level=[int][Math]::Max(0,[Math]::Min(7,[Math]::Round(7.0*$v/15.0)))
            $str+=$chars[$level]
        }
        return $str
    }
    function NetCurve($values,[int]$width,[long]$at) {
        $dots=2*$width
        $cells=New-Object 'int[]' (4*$width)
        $bits=@(1,2,4,64,8,16,32,128)
        $points=NetPlotSamples $values $dots $at
        $previous=-1
        for ($x=0;$x -lt $dots;$x++) {
            if ($points[$x] -lt 0) { $previous=-1; continue }
            $y=[int][Math]::Max(0,[Math]::Min(15,[Math]::Round($points[$x])))
            $start=$y; $end=$y
            if ($previous -ge 0) {
                $start=[Math]::Min($previous,$y); $end=[Math]::Max($previous,$y)
            }
            $col=[int][Math]::Floor($x/2.0)
            for ($py=$start;$py -le $end;$py++) {
                $screenY=15-$py
                $row=[int][Math]::Floor($screenY/4.0)
                $idx=$row*$width+$col
                $bit=$bits[($x%2)*4+($screenY%4)]
                $cells[$idx]=$cells[$idx] -bor $bit
            }
            $previous=$y
        }
        for ($row=0;$row -lt 4;$row++) {
            $line=New-Object System.Text.StringBuilder
            for ($col=0;$col -lt $width;$col++) {
                $mask=$cells[$row*$width+$col]
                if ($mask -eq 0) { $null=$line.Append(' ') }
                else { $null=$line.Append([char](0x2800+$mask)) }
            }
            $line.ToString()
        }
    }
    function NetChartPair([int]$width) {
        $at=if ($s.NetTime.Count) { $s.NetTime[$s.NetTime.Count-1] } else { 0L }
        $cacheKey="$width/$at"
        if ($s.NetChartKey -ne $cacheKey) {
            $s.NetChartDown=@(NetCurve $s.NetHist $width $at)
            $s.NetChartUp=@(NetCurve $s.NetUpHist $width $at)
            $s.NetChartKey=$cacheKey
        }
        $labels=@('1000','100','10','0')
        "$pink$(Fit ('     '+(NexL 'DOWNLOAD')) ($width+5))$reset   $blue$(Fit ('     '+(NexL 'UPLOAD')) ($width+5))$reset"
        for ($i=0;$i -lt 4;$i++) {
            $axis=$labels[$i].PadLeft(4)
            "$gray$axis│$pink$($s.NetChartDown[$i])$reset   $gray$axis│$blue$($s.NetChartUp[$i])$reset"
        }
    }

    function ShortIsp([string]$value) {
        if ([string]::IsNullOrWhiteSpace($value)) { return 'Not reported' }
        if ($value -match '(?i)^\s*inexio\b') { return 'inexio' } # display alias for reported ISP, not a default
        return $value.Trim()
    }
    # Semantic, theme-independent load scale after the near-idle accent.
    function LoadHex([double]$v,[string]$base=$palette[0]) {
        $v=[Math]::Max(0.0,[Math]::Min(100.0,$v))
        $stops=@(0,12,35,55,75,90,100)
        $shades=@($base,'63E6A0','B6F45A','FFDB4D','FF943D','FF573D','FF252F')
        $j=0
        while ($j -lt $stops.Count-2 -and $v -gt $stops[$j+1]) {$j++}
        $from=$shades[$j];$to=$shades[$j+1]
        $t=($v-$stops[$j])/($stops[$j+1]-$stops[$j])
        $rgb=for ($i=0;$i -lt 6;$i+=2) {
            $a=[Convert]::ToInt32($from.Substring($i,2),16)
            $b=[Convert]::ToInt32($to.Substring($i,2),16)
            [int][Math]::Round($a+($b-$a)*$t)
        }
        return ('{0:X2}{1:X2}{2:X2}' -f $rgb[0],$rgb[1],$rgb[2])
    }
    function LoadText([double]$v,[string]$base=$palette[0]) {
        NexAnsi (LoadHex $v $base)
    }
    function Bar([double]$v,[int]$n=24,[string]$hex=$palette[0]) {
        $hex=LoadHex $v $hex
        $units=[Math]::Max(0.0,[Math]::Min(100.0,$v))*$n/100.0
        $filled=[int][Math]::Floor($units)
        $fraction=$units-$filled
        $bar="$(NexAnsi $hex)$('━'*$filled)"
        $left=$n-$filled
        if ($left -gt 0 -and $fraction -gt 0.025) {
            $rgb=@([Convert]::ToInt32($hex.Substring(0,2),16),[Convert]::ToInt32($hex.Substring(2,2),16),[Convert]::ToInt32($hex.Substring(4,2),16))
            $r=[int](88+($rgb[0]-88)*$fraction)
            $g=[int](91+($rgb[1]-91)*$fraction)
            $b=[int](112+($rgb[2]-112)*$fraction)
            $bar+="$e[38;2;$r;$g;${b}m$([char]0x2501)"
            $left--
        }
        return "$bar$muted$('─'*$left)$reset"
    }
    function Notice($m) { $s.Msg=SafeText (NexL ([string]$m)); $s.Need=$true }
    function ResetDraw { $s.Size=''; $s.Old=@(); $s.Need=$true; $s.LastFileClick='' }

    # Optional native mouse input. Keyboard works if this cannot be enabled.
    try {
        if (-not ('NexDash.NativeInput215' -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace NexDash {
 public static class NativeInput215 {
  [StructLayout(LayoutKind.Explicit, Size=20)] public struct Record {
   [FieldOffset(0)] public ushort Type;
   [FieldOffset(4)] public int KeyDown;
   [FieldOffset(10)] public ushort VirtualKey;
   [FieldOffset(14)] public ushort UnicodeChar;
   [FieldOffset(16)] public uint ControlState;
   [FieldOffset(4)] public short X;
   [FieldOffset(6)] public short Y;
   [FieldOffset(8)] public uint Buttons;
   [FieldOffset(16)] public uint Flags;
  }
  [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
  [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h,out uint mode);
  [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h,uint mode);
  [DllImport("kernel32.dll")] static extern bool GetNumberOfConsoleInputEvents(IntPtr h,out uint n);
  [DllImport("kernel32.dll",EntryPoint="ReadConsoleInputW",CharSet=CharSet.Unicode,ExactSpelling=true)] static extern bool ReadConsoleInput(IntPtr h,out Record r,uint len,out uint read);
  static IntPtr H { get { return GetStdHandle(-10); } }
  public static int Enable() { uint m; if(!GetConsoleMode(H,out m)) return -1; uint next=(m | 0x98u) & ~0x240u; return SetConsoleMode(H,next)?(int)m:-1; }
  // Raw keyboard and mouse for the full-screen editor, with mode restored on exit.
  public static int EnableEditor() { uint m; if(!GetConsoleMode(H,out m)) return -1; uint next=(m | 0x98u) & ~0x247u; return SetConsoleMode(H,next)?(int)m:-1; }
  public static void Restore(int m) { if(m>=0) SetConsoleMode(H,(uint)m); }
  public static Record Poll() { uint n,read; Record r=new Record(); if(GetNumberOfConsoleInputEvents(H,out n)&&n>0) ReadConsoleInput(H,out r,1,out read); return r; }
 }
}
"@ -ErrorAction Stop
        }
        $s.Mode=[NexDash.NativeInput215]::Enable(); $s.Mouse=($s.Mode -ge 0)
    } catch { $s.Mouse=$false }
    function PauseMouse { if ($s.Mouse) { [NexDash.NativeInput215]::Restore($s.Mode) } }
    function ResumeMouse { if ($s.Mouse) { $s.Mode=[NexDash.NativeInput215]::Enable(); if ($s.Mode -lt 0) { $s.Mouse=$false } } }
    function InputEvent {
        if ($s.Mouse) {
            for ($j=0;$j -lt 40;$j++) {
                $r=[NexDash.NativeInput215]::Poll()
                if ($r.Type -eq 0) { return $null }
                if ($r.Type -eq 1 -and $r.KeyDown -ne 0) {
                    $vk=[int]$r.VirtualKey
                    if (-not [Enum]::IsDefined([System.ConsoleKey],$vk)) {
                        if ($r.UnicodeChar -ne 0) { return @{Key='Text';KeyChar=[char]$r.UnicodeChar;Ctrl=(($r.ControlState -band 12) -ne 0)} }
                        continue
                    }
                    $k=[System.ConsoleKey]$vk
                    return @{Key=$k.ToString();KeyChar=[char]$r.UnicodeChar;Ctrl=(($r.ControlState -band 12) -ne 0)}
                }
                if ($r.Type -eq 2 -and $r.Flags -in @(0,2) -and ($r.Buttons -band 1)) { return @{Key='Click';X=([int]$r.X-[Console]::WindowLeft);Y=([int]$r.Y-[Console]::WindowTop)} }
                if ($r.Type -eq 2 -and $r.Flags -eq 4) {
                    $wheel=if ($r.Buttons -band 0x80000000L) {'DownArrow'} else {'UpArrow'}
                    return @{Key=$wheel;Wheel=$true;X=([int]$r.X-[Console]::WindowLeft);Y=([int]$r.Y-[Console]::WindowTop)}
                }
            }
        } elseif ([Console]::KeyAvailable) {
            $ki=[Console]::ReadKey($true)
            return @{Key=$ki.Key.ToString();KeyChar=$ki.KeyChar;Ctrl=(($ki.Modifiers -band [ConsoleModifiers]::Control) -ne 0)}
        }
        return $null
    }
    function WaitNexEvent {
        $before="$([Console]::WindowWidth)x$([Console]::WindowHeight)"
        while ($true) {
            $event=InputEvent
            if ($event) { return $event }
            if ("$([Console]::WindowWidth)x$([Console]::WindowHeight)" -ne $before) { return @{Key='Resize'} }
            Start-Sleep -Milliseconds 12
        }
    }
    function ChooseNexPromptStyle {
        # A preview-first selector: clicking only selects; Enter/Apply commits.
        $styles=@(Get-NexPromptStyles)
        $pick=[Array]::IndexOf([object[]]$styles,[object]$prefs.Prompt)
        if ($pick -lt 0) {$pick=0}
        $offset=0
        $savedMode=-1
        if ($s.Mouse) {try {$savedMode=[NexDash.NativeInput215]::EnableEditor()} catch {}}
        try {
            while ($true) {
                $w=[Console]::WindowWidth; $h=[Console]::WindowHeight
                if ($w -lt 42 -or $h -lt 18) {
                    Write-Host "$e[2J$e[H$pink$(NexL 'Enlarge the window or press Esc.')$reset" -NoNewline
                    $ev=WaitNexEvent; if ($ev.Key -eq 'Escape') {return $null}; continue
                }
                $inner=[Math]::Min(112,$w-4)
                $x=[Math]::Max(1,[int][Math]::Floor(($w-$inner)/2)+1)
                $selected=[string]$styles[$pick]
                $sample=@(Get-NexPromptLines $selected (Get-NexIdentity) '~' '12:34:56' $true '' ([bool]$prefs.Icons))
                $managed=($selected -ne 'Keep existing')
                if (-not $managed) {$sample=@(NexL 'Existing prompt (not managed)')}
                $previewLength=0
                foreach ($line in $sample) {$previewLength=[Math]::Max($previewLength,(Get-NexLogoWidth ([regex]::Replace($line,'\x1b\[[0-9;]*m',''))))}
                # Prefer two panes, but never squeeze a two-line prompt into a single row.
                $leftWidth=30; $rightWidth=$inner-$leftWidth-3
                $split=($inner -ge 92 -and $h -ge 22 -and $previewLength -le ($rightWidth-4))
                if (-not $split) {$leftWidth=$inner; $rightWidth=$inner}
                $previewWidth=$rightWidth-4
                $kind=if (-not $managed) {NexL 'Existing prompt (not managed)'} elseif ($sample.Count -gt 1) {NexL 'Two lines'} else {NexL 'One line'}
                $panel=@("$purple$(NexL 'Live preview')$reset", "$pink$(NexL $selected)$reset", "$gray$kind$reset", "$muted$('─'*$previewWidth)$reset", '')
                if ($managed) {
                    for ($j=0;$j -lt $sample.Count;$j++) {
                        $line=[string]$sample[$j]
                        if ($j -eq ($sample.Count-1)) {
                            $plain=[regex]::Replace($line,'\x1b\[[0-9;]*m','')
                            if ((Get-NexLogoWidth $plain)+12 -le $previewWidth) {$line+="${white}Get-Location$reset"}
                        }
                        $panel+=ClipAnsi $line $previewWidth
                    }
                }
                $panel+=@('',"$muted$('─'*$previewWidth)$reset")
                $rows=@("$pink$(Fit ((SafeText (Get-NexName))+' / '+(NexL 'Choose prompt style')) $inner)$reset", "$muted$('─'*$inner)$reset")
                if ($prefs.SettingHelp) {
                    foreach ($line in @(WrapUpdateLine (NexL 'Changes the appearance of the PowerShell command prompt.') $inner | Select-Object -First 2)) {$rows+="$gray$line$reset"}
                }
                $rows+=''
                # In a short/narrow window the preview appears above the scrollable list.
                if (-not $split) {
                    # Keep the actual prompt and its line breaks even in short windows.
                    if ($h -lt ($rows.Count+$panel.Count+7)) {
                        $panel=@($panel[0],$panel[1]) + @($panel | Select-Object -Skip 5 -First $(if ($managed) {$sample.Count} else {0}))
                        if (-not $managed) {$panel+=ClipAnsi $sample[0] $previewWidth}
                    }
                    foreach ($line in $panel) {$rows+=('  '+(ClipAnsi $line ($inner-4)))}
                }
                $rows+="$gray$(NexL 'Prompt styles')  ·  ↑↓ / $(NexL 'Click to preview')$reset"
                $choiceRow=$rows.Count
                $available=[Math]::Max(1,$h-$choiceRow-5)
                $shown=[Math]::Min($styles.Count,$available)
                $offset=[Math]::Max(0,[Math]::Min($offset,$styles.Count-$shown))
                if ($pick -lt $offset) {$offset=$pick}
                if ($pick -ge $offset+$shown) {$offset=$pick-$shown+1}
                $bodyHeight=$shown
                if ($split) {$bodyHeight=[Math]::Max($shown,$panel.Count)}
                for ($i=0;$i -lt $bodyHeight;$i++) {
                    if ($i -lt $shown) {
                        $idx=$offset+$i
                        $marker=if ($idx -eq $pick) {'❯'} else {' '}
                        $check=if ($styles[$idx] -eq $prefs.Prompt) {'✓'} else {' '}
                        $label=Fit ("$marker $check "+(NexL $styles[$idx])) $leftWidth
                        $tone=if ($idx -eq $pick) {"$bg$pink"} else {$white}
                        $left="$tone$label$reset"
                    } else {$left=' '*$leftWidth}
                    if ($split) {
                        $right=if ($i -lt $panel.Count) {ClipAnsi $panel[$i] $previewWidth} else {''}
                        $rows+="$left $muted│$reset  $right"
                    } else {$rows+=$left}
                }
                $rows+="$gray$($pick+1)/$($styles.Count)  ·  ✓ $(NexL 'Current style')$reset"
                $rows+="$muted$('─'*$inner)$reset"
                $buttonRow=$rows.Count
                $applyButton='[ '+(NexL 'Apply')+' ]';$cancelButton='[ '+(NexL 'Cancel')+' ]'
                $rows+="$pink$applyButton$reset  $purple$cancelButton$reset"
                $rows+="$gray$(NexL 'Enter: Apply | Esc: Cancel')$reset"
                $y=[Math]::Max(1,[int][Math]::Floor(($h-$rows.Count)/2)+1)
                $frame="$e[2J$e[?25l"
                for ($i=0;$i -lt $rows.Count -and ($y+$i) -le $h;$i++) {$frame+="$e[$($y+$i);${x}H$(ClipAnsi $rows[$i] $inner)"}
                Write-Host $frame -NoNewline
                $ev=WaitNexEvent
                if ($ev.Key -eq 'Escape') {return $null}
                if ($ev.Key -eq 'Enter') {return $selected}
                if ($ev.Key -eq 'Click') {
                    $ry=$ev.Y-($y-1);$rx=$ev.X-($x-1)
                    if ($ry -eq $buttonRow) {
                        if ($rx -ge 0 -and $rx -lt $applyButton.Length) {return $selected}
                        $cancelStart=$applyButton.Length+2
                        if ($rx -ge $cancelStart -and $rx -lt ($cancelStart+$cancelButton.Length)) {return $null}
                    } elseif ($ry -ge $choiceRow -and $ry -lt ($choiceRow+$shown) -and $rx -ge 0 -and $rx -lt $leftWidth) {
                        $pick=$offset+$ry-$choiceRow
                    }
                    continue
                }
                switch ($ev.Key) {
                    'UpArrow' {$pick=[Math]::Max(0,$pick-1)}
                    'DownArrow' {$pick=[Math]::Min($styles.Count-1,$pick+1)}
                    'PageUp' {$pick=[Math]::Max(0,$pick-$shown)}
                    'PageDown' {$pick=[Math]::Min($styles.Count-1,$pick+$shown)}
                    'Home' {$pick=0}
                    'End' {$pick=$styles.Count-1}
                }
            }
        } finally {
            if ($savedMode -ge 0) {[NexDash.NativeInput215]::Restore($savedMode)}
            Write-Host "$e[?25l" -NoNewline; ResetDraw
        }
    }
    function Ask($title,$choices=@(),$choiceValues=@(),$initialChoice=$null,[string]$helpKey='') {
        # Raw mode keeps mouse and Ctrl+V available in the text field.
        $savedMode=-1
        if ($s.Mouse) { try { $savedMode=[NexDash.NativeInput215]::EnableEditor() } catch {} }
        $value=''; $caret=0; $offset=0; $pick=0; $pickedWithKeys=$false
        $searchMode=($title -eq 'Search Dashboard');$allChoices=@($choices);$allValues=@($choiceValues);$previousSearch=$null
        if ($null -ne $initialChoice -and $choiceValues.Count -gt 0) {
            $idx=[Array]::IndexOf([object[]]$choiceValues,[object]$initialChoice)
            if ($idx -ge 0) {$pick=$idx;$pickedWithKeys=$true}
        }
        try {
            while ($true) {
                $w=[Console]::WindowWidth; $h=[Console]::WindowHeight
                if ($w -lt 32 -or $h -lt 10) {
                    Write-Host "$e[2J$e[H$pink $(NexL 'Enlarge the window or press Esc.')$reset" -NoNewline
                    $ev=WaitNexEvent; if ($ev.Key -eq 'Escape') { return $null }; continue
                }
                if ($searchMode -and ($null -eq $previousSearch -or $previousSearch -cne $value)) {
                    $choices=@();$choiceValues=@();$pick=0;$offset=0;$previousSearch=$value
                    for ($k=0;$k -lt $allChoices.Count;$k++) {
                        if (([string]$allChoices[$k]).IndexOf($value,[StringComparison]::OrdinalIgnoreCase) -ge 0) {$choices+=@($allChoices[$k]);$choiceValues+=@($allValues[$k])}
                    }
                }
                $inner=[Math]::Min(76,$w-4); $x=[Math]::Max(1,[int][Math]::Floor(($w-$inner)/2))
                $dialogHelp=if ($searchMode) {if ($choices.Count) {NexL 'Type to filter; Enter opens the selected result.'} else {NexL 'No matching sections. Change the search text.'}} elseif ($prefs.SettingHelp -and $helpKey) {NexL $helpKey} elseif ($prefs.SettingHelp -and $global:NexDialogHelp.ContainsKey([string]$title)) {NexL $global:NexDialogHelp[[string]$title]} else {NexL 'Type a value, or click a choice. Esc cancels.'}
                $helpLimit=[Math]::Max(1,[Math]::Min(5,$h-10))
                $helpLines=@(WrapUpdateLine $dialogHelp ($inner-2) | Select-Object -First $helpLimit)
                $reserve=9+$helpLines.Count
                $shown=[Math]::Min($choices.Count,[Math]::Max(1,$h-$reserve))
                $offset=[Math]::Max(0,[Math]::Min($offset,$choices.Count-$shown))
                if ($shown -gt 0) { if ($pick -lt $offset) { $offset=$pick }; if ($pick -ge $offset+$shown) { $offset=$pick-$shown+1 } }
                $rows=@("$pink $(Fit ((SafeText (Get-NexName))+' / '+(NexL $title)) $inner)$reset", "$muted$('─'*$inner)$reset")
                foreach ($helpLine in $helpLines) {$rows+="$gray $helpLine$reset"}
                $choiceRow=$rows.Count
                for ($i=0;$i -lt $shown;$i++) {
                    $idx=$offset+$i; $style=if ($idx -eq $pick) { "$bg$pink" } else { $white }
                    if ($title -eq 'Choose theme') {
                        $tp=Get-NexPalette ([string]$choiceValues[$idx])
                        $label=Fit ('  '+(NexL ([string]$choices[$idx]))) ([Math]::Max(1,$inner-10))
                        $swatches="$(NexAnsi $tp[0])● $(NexAnsi $tp[1])● $(NexAnsi $tp[3] -Background)$(NexAnsi $tp[4]) Aa $reset"
                        $rows+="$style$label$reset $swatches"
                    } else {$rows+= "$style$(Fit ('  '+(NexL ([string]$choices[$idx]))) $inner)$reset"}
                }
                $rows+=''
                $fieldRow=$rows.Count
                $maxChars=[Math]::Max(1,$inner-4); $left=[Math]::Max(0,$caret-$maxChars+1)
                $visible=if ($value.Length -gt $left) {$value.Substring($left)} else {''}
                $rows+="$purple > $white$(Fit $visible $maxChars)$reset"
                $rows+="$muted$('─'*$inner)$reset"
                $buttonRow=$rows.Count
                $cancelButton='[ '+(NexL 'Cancel')+' ]';$rows+="$pink[ OK ]$reset  $purple$cancelButton$reset"
                $rows+="$gray$(NexL 'Enter OK  |  Esc Cancel  |  Ctrl+V Paste')$reset"
                $y=[Math]::Max(1,[int][Math]::Floor(($h-$rows.Count)/2)+1)
                $frame="$e[2J$e[?25l"
                for ($i=0;$i -lt $rows.Count;$i++) { $frame+="$e[$($y+$i);${x}H$(ClipAnsi $rows[$i] $inner)" }
                $frame+="$e[$($y+$fieldRow);$($x+3+$caret-$left)H$e[?25h"
                Write-Host $frame -NoNewline
                $ev=WaitNexEvent; $key=$ev.Key
                if ($key -eq 'Escape') { return $null }
                if ($key -eq 'Click') {
                    $ry=$ev.Y-($y-1); $rx=$ev.X-($x-1)
                    if ($ry -eq $buttonRow) {
                        if ($rx -ge 0 -and $rx -lt 6) { $key='Enter' }
                        elseif ($rx -ge 8 -and $rx -lt (8+$cancelButton.Length)) { return $null }
                        else { continue }
                    } elseif ($ry -ge $choiceRow -and $ry -lt $choiceRow+$shown -and $rx -ge 0 -and $rx -lt $inner) {
                        $pick=$offset+$ry-$choiceRow
                        if ($choiceValues.Count -eq $choices.Count) { return [string]$choiceValues[$pick] }
                        continue
                    } elseif ($ry -eq $fieldRow -and $rx -ge 3 -and $rx -lt $inner) {
                        $caret=[Math]::Max(0,[Math]::Min($value.Length,$left+$rx-3)); continue
                    } else { continue }
                }
                if ($key -eq 'Enter') {
                    if ($searchMode) {if ($choices.Count) {return [string]$choiceValues[$pick]};continue}
                    if ([string]::IsNullOrWhiteSpace($value)) {
                        if ($pickedWithKeys -and $choices.Count -gt 0 -and $choiceValues.Count -eq $choices.Count) { return [string]$choiceValues[$pick] }
                        return $null
                    }
                    return $value.Trim()
                }
                if ($key -eq 'Resize') { continue }
                if ($ev.Ctrl -and $key -eq 'A') { $value=''; $caret=0; continue }
                if (($ev.Ctrl -and $key -eq 'V') -or ($null -ne $ev.KeyChar -and [int]$ev.KeyChar -eq 22)) {
                    try { $insert=Get-Clipboard -Raw -ErrorAction Stop; if ($insert) { $insert=SafeText $insert; $value=$value.Insert($caret,$insert); $caret+=$insert.Length } } catch {}; continue
                }
                if ($ev.Ctrl) { continue }
                switch ($key) {
                    'LeftArrow' { $caret=[Math]::Max(0,$caret-1) }
                    'RightArrow' { $caret=[Math]::Min($value.Length,$caret+1) }
                    'Home' { $caret=0 }
                    'End' { $caret=$value.Length }
                    'Backspace' { if ($caret -gt 0) { $value=$value.Remove($caret-1,1); $caret-- } }
                    'Delete' { if ($caret -lt $value.Length) { $value=$value.Remove($caret,1) } }
                    'UpArrow' { $pick=[Math]::Max(0,$pick-1); $pickedWithKeys=$true }
                    'DownArrow' { $pick=[Math]::Min([Math]::Max(0,$choices.Count-1),$pick+1); $pickedWithKeys=$true }
                    'PageUp' { $pick=[Math]::Max(0,$pick-5); $pickedWithKeys=$true }
                    'PageDown' { $pick=[Math]::Min([Math]::Max(0,$choices.Count-1),$pick+5); $pickedWithKeys=$true }
                    default { if ($null -ne $ev.KeyChar -and -not [char]::IsControl([char]$ev.KeyChar)) { $value=$value.Insert($caret,[string]$ev.KeyChar); $caret++ } }
                }
            }
        } finally {
            if ($savedMode -ge 0) { [NexDash.NativeInput215]::Restore($savedMode) }
            Write-Host "$e[?25l" -NoNewline; ResetDraw
        }
    }
    function ChooseNexToggle([string]$title,[bool]$current,[string]$helpKey) {
        $initial=if ($current) {'Enabled'} else {'Disabled'}
        $choice=Ask $title @('Enabled','Disabled') @('Enabled','Disabled') $initial $helpKey
        if ($choice -eq 'Enabled') {return $true}
        if ($choice -eq 'Disabled') {return $false}
        return $null
    }
    function NexActionHelp([string]$title,[string]$helpKey) {
        if (-not $prefs.SettingHelp) {return $true}
        return ((Ask $title @('Continue','Cancel') @('continue','cancel') 'continue' $helpKey) -eq 'continue')
    }
    function ChoosePage([int]$i) {
        if ($i -ne 14) {$s.OnlineRequested=$false;$s.OnlineReady=$false}
        if ($s.Page -eq 3 -and $i -ne 3 -and $s.SpeedProc) { StopSpeedTest }
        if ($i -eq 3 -and $s.Page -ne 3) { $s.SpeedPath=Get-NexSpeedtest; $s.NetPrev=@{}; $s.NetAt=0L; $s.NetReady=$false; $s.NetRows=@(); $s.NetTime.Clear(); $s.NetHist.Clear(); $s.NetUpHist.Clear(); $s.NetChartKey=''; $s.NetFast=$false; $s.FastDisabled=$false; $s.NetAdapters=@(); $s.FastPrev=@{}; $s.FastAt=0L; foreach ($id in @($visual.Keys)) { if ($id -like 'net-*') { $visual.Remove($id) } } }
        if ($i -eq 1 -and $s.Page -ne 1) {$s.LastOverview=$null; $s.MonitorPos=0; $s.MonitorNetPrev=@{}; $s.MonitorDown=$null; $s.MonitorUp=$null; $s.MonitorHistoryCPU=@(); $s.MonitorHistoryGPU=@()}
        if ($i -eq 10 -and $s.Page -ne 10) {$s.PersonalPos=0}
        if ($i -ge 11 -and $s.Page -ne $i) {$s.ExtraPos=0}
        $s.Page=$i; $s.Nav=$i; $s.Focus='body'; $s.Msg=''; $s.Next=0; $s.Need=$true
    }
    function StartWorker($kind,$script,$arg=$null) {
        if ($null -ne $s.Job) { return }
        $scriptText=$script.ToString()
        $w=[PowerShell]::Create(); $null=$w.AddScript($scriptText)
        if ($null -ne $arg) { $null=$w.AddArgument($arg) }
        try { $s.Job=$w.BeginInvoke(); $s.Worker=$w; $s.JobKind=$kind; $s.JobArg=$arg; $s.JobStart=$clock.ElapsedMilliseconds } catch { $w.Dispose(); Notice $_.Exception.Message }
    }
    function PollWorker {
        if ($null -eq $s.Job -or -not $s.Job.IsCompleted) { return }
        try {
            $out=@($s.Worker.EndInvoke($s.Job))
            if ($s.Worker.HadErrors -and -not $out.Count) { if ($s.JobKind -eq 'speed-install' -and $s.Worker.Streams.Error.Count) {throw $s.Worker.Streams.Error[0].Exception.Message}; throw 'Query failed or access denied.' }
            if ($s.ExtraErrors.ContainsKey($s.JobKind)) {$s.ExtraErrors.Remove($s.JobKind)}
            switch ($s.JobKind) {
                'process-metrics' {if ($out.Count) {$s.ProcMetrics=$out[-1];$s.ProcMetricsAt=$clock.ElapsedMilliseconds}}
                'hardware' {$s.Hardware=@($out)}
                'gaming' {if ($s.JobStart -le $s.GameChangedAt) {$s.Next=0L} elseif ($out.Count) {$s.Game=$out[-1]}}
                'apps' {$s.Apps=@($out)}
                'startup' {$s.StartupRows=@($out);$s.StartupAt=Get-Date}
                'health' {if ($out.Count) {$s.Health=$out[-1]; FilterNexHealthEvents; UpdateNexAlerts}}
                'release' {
                    if ($out.Count) {$s.Release=$out[-1];$s.ReleaseSource='owoNEXowo/NEX-Dashboard';$s.OnlineReady=$s.OnlineRequested}
                    $s.OnlineRequested=$false
                }
                'speed-install' {
                    $s.SpeedPath=Get-NexSpeedtest
                    if (-not $s.SpeedPath) {throw 'Speedtest installation failed'}
                    $s.SpeedStatus='Ookla Speedtest installed.';Notice 'Ookla Speedtest installed.'
                }
                'release-download' {
                    if ($out.Count -and $s.Page -eq 14) {
                        $verified=$out[-1]
                        $s.PendingInstaller=$verified.Path;$s.PendingVersion=[version]$verified.Version;$s.PendingHash=$verified.Hash
                    } else {Notice 'Online update cancelled.'}
                }
                'updates' {
                    $s.UpdateRows=@($out | ForEach-Object { [string]$_ })
                    $s.UpdateStatus='Complete'; $s.UpdateChecked=Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; $s.UpdatePos=0
                }
                'overview' {
                    if ($out.Count) {
                        $d=$out[-1]
                        $s.AlertOverview=$d
                        if ([int]$s.JobArg -eq 1) {$s.AlertGpu=@($d.Nvidia);$s.AlertGpuAt=$clock.ElapsedMilliseconds;$s.AlertSampleNext=$clock.ElapsedMilliseconds+8000}
                        UpdateNexAlerts
                        if ($d.Total -gt 0) { $s.ProcMemoryTotal=[double]$d.Total*1024.0 }
                        if ([int]$s.JobArg -eq 1 -and $s.Page -eq 1) {
                            $s.MonitorHistoryCPU=@($s.MonitorHistoryCPU+@([double]$d.CPU) | Select-Object -Last 24)
                            if ($null -ne $d.GPU) { $s.MonitorHistoryGPU=@($s.MonitorHistoryGPU+@([double]$d.GPU) | Select-Object -Last 24) }
                            $fresh=@{}; $rx=0.0; $tx=0.0; $valid=$false
                            foreach ($n in @($d.NetCounters)) {
                                if ($null -eq $n) { continue }
                                $id=[string]$n.Name; $fresh[$id]=$n
                                if ($s.MonitorNetPrev.ContainsKey($id)) {
                                    $prev=$s.MonitorNetPrev[$id]; $dt=([long]$n.At-[long]$prev.At)/[double][Diagnostics.Stopwatch]::Frequency
                                    if ($dt -gt 0 -and $n.Rx -ge $prev.Rx -and $n.Tx -ge $prev.Tx) {
                                        $rx+=([double]$n.Rx-[double]$prev.Rx)*8.0/$dt/1e6
                                        $tx+=([double]$n.Tx-[double]$prev.Tx)*8.0/$dt/1e6; $valid=$true
                                    }
                                }
                            }
                            $s.MonitorNetPrev=$fresh
                            if ($valid) {$s.MonitorDown=$rx; $s.MonitorUp=$tx} else {$s.MonitorDown=$null; $s.MonitorUp=$null}
                            $s.LastOverview=$d
                        } elseif ($s.Page -eq 0 -and [int]$s.JobArg -eq 0) { $s.LastOverview=$d }
                    }
                }
                'info' { $s.Info=@($out | ForEach-Object { [string]$_ }) }
                'logs' { if ($s.JobArg -eq $s.LogName) { $s.Logs=@($out | ForEach-Object { $_ }); $s.LogPos=[Math]::Max(0,[Math]::Min($s.LogPos,$s.Logs.Count-1)) } }
                'ping' { if ($s.JobArg -eq $s.PingHost) { $s.Ping=($out -join ' ') } }
                'tools' { $s.ToolRows=@($out) }
                'network' {
                    if ($s.Page -ne 3) { break }
                    $rows=@(); $down=0.0; $up=0.0; $fresh=@{}; $ready=$false
                    foreach ($n in $out) {
                        $id=[string]$n.Name
                        $rxBytes=[double]$n.Rx; $txBytes=[double]$n.Tx; $at=[long]$n.At
                        $fresh[$id]=@($rxBytes,$txBytes,$at)
                        $rx=0.0; $tx=0.0
                        if ($s.NetPrev.ContainsKey($id)) {
                            $prev=$s.NetPrev[$id]
                            $dt=($at-[long]$prev[2])/[double][Diagnostics.Stopwatch]::Frequency
                            if ($dt -gt 0 -and $rxBytes -ge $prev[0] -and $txBytes -ge $prev[1]) {
                                $rx=($rxBytes-$prev[0])*8.0/$dt/1e6
                                $tx=($txBytes-$prev[1])*8.0/$dt/1e6
                                $ready=$true
                            }
                        }
                        $rows+=@{Name=$id;Link=[string]$n.Link;IP=[string]$n.IP;Type=[string]$n.Type;Down=$rx;Up=$tx}
                        $down+=$rx; $up+=$tx
                    }
                    $s.NetPrev=$fresh; $s.NetAt=$clock.ElapsedMilliseconds
                    $matched=@()
                    try {
                        $names=@($rows | ForEach-Object { $_.Name })
                        $matched=@([System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object { $_.OperationalStatus -eq 'Up' -and $_.Name -in $names })
                    } catch {}
                    $fast=(-not $s.FastDisabled -and $rows.Count -gt 0 -and $matched.Count -eq $rows.Count)
                    if ($fast) {
                        # Carry recent rates across metadata refreshes.
                        foreach ($row in $rows) {
                            foreach ($old in $s.NetRows) {
                                if ($old.Name -eq $row.Name) { $row.Down=$old.Down; $row.Up=$old.Up; break }
                            }
                        }
                        if (-not $s.NetFast) { $s.FastPrev=@{}; $s.FastAt=0L }
                        $s.NetAdapters=$matched; $s.NetFast=$true; $s.NetRows=$rows
                    } else {
                        $s.NetFast=$false; $s.NetAdapters=@(); $s.FastPrev=@{}
                        $s.NetReady=$ready; $s.NetRows=$rows; $s.Down=$down; $s.Up=$up
                        if ($ready) {
                            $s.PeakDown=[Math]::Max([double]$s.PeakDown,$down)
                            $s.PeakUp=[Math]::Max([double]$s.PeakUp,$up)
                        }
                    }
                }
            }
        } catch {
            if ($s.JobKind -in @('release','release-download')) {$s.OnlineRequested=$false;$s.OnlineReady=$false;$s.ExtraErrors['release']=[string]$_.Exception.Message}
            if ($s.JobKind -in @('hardware','gaming','apps','health','release','startup')) {$s.ExtraErrors[$s.JobKind]=[string]$_.Exception.Message}
            if ($s.JobKind -eq 'speed-install') {$s.SpeedStatus='Speedtest installation failed';$s.SpeedPath=Get-NexSpeedtest}
            if ($s.JobKind -eq 'health') {$s.HealthNext=$clock.ElapsedMilliseconds+60000}
            if ($s.JobKind -eq 'updates') { $s.UpdateStatus='Failed'; $s.UpdateRows=@($_.Exception.Message) }
            Notice $_.Exception.Message
        }
        finally { $s.Worker.Dispose(); $s.Worker=$null; $s.Job=$null; $s.Need=$true }
    }
    function SampleFastNetwork {
        if (-not $s.NetFast) { return }
        $at=$clock.ElapsedMilliseconds
        if ($at -lt $s.FastAt) { return }
        $s.FastAt=$at+150
        $fresh=@{}; $rates=@{}; $down=0.0; $up=0.0; $ready=$false
        try {
            foreach ($adapter in $s.NetAdapters) {
                $stat=$adapter.GetIPStatistics()
                $stamp=[Diagnostics.Stopwatch]::GetTimestamp()
                $rx=[double]$stat.BytesReceived; $tx=[double]$stat.BytesSent
                if ($rx -lt 0 -or $tx -lt 0) { throw 'Invalid network counters.' }
                $id=[string]$adapter.Name
                $fresh[$id]=@($rx,$tx,$stamp)
                if ($s.FastPrev.ContainsKey($id)) {
                    $prev=$s.FastPrev[$id]
                    $dt=($stamp-[long]$prev[2])/[double][Diagnostics.Stopwatch]::Frequency
                    if ($dt -gt 0 -and $rx -ge $prev[0] -and $tx -ge $prev[1]) {
                        $dr=($rx-$prev[0])*8.0/$dt/1e6; $ur=($tx-$prev[1])*8.0/$dt/1e6
                        $rates[$id]=@($dr,$ur); $down+=$dr; $up+=$ur; $ready=$true
                    }
                }
            }
            $s.FastPrev=$fresh
            if ($ready -and $rates.Count -eq $s.NetAdapters.Count) {
                foreach ($row in $s.NetRows) {
                    if ($rates.ContainsKey($row.Name)) { $row.Down=$rates[$row.Name][0]; $row.Up=$rates[$row.Name][1] }
                }
                $s.NetReady=$true; $s.Down=$down; $s.Up=$up
                $s.PeakDown=[Math]::Max([double]$s.PeakDown,$down)
                $s.PeakUp=[Math]::Max([double]$s.PeakUp,$up)
            }
        } catch {
            # Return to the original worker sampler if native counters are unavailable.
            $s.NetFast=$false; $s.FastDisabled=$true; $s.NetAdapters=@(); $s.FastPrev=@{}; $s.Next=0L
        }
    }
    function StopSpeedTest([string]$reason='Cancelled') {
        if ($s.SpeedProc) {
            try { if (-not $s.SpeedProc.HasExited) { $s.SpeedProc.Kill() } } catch {}
            $s.SpeedProc.Dispose(); $s.SpeedProc=$null
        }
        $s.SpeedOut=$null; $s.SpeedErr=$null; $s.SpeedStatus=$reason; $s.Need=$true
    }
    function RequestSpeedtestInstall {
        if ($s.SpeedInstallPending -or ($s.Job -and $s.JobKind -eq 'speed-install')) {return}
        $s.SpeedPath=Get-NexSpeedtest
        if ($s.SpeedPath) { $s.SpeedStatus='Ready';$s.Need=$true;return }
        if (-not (ConfirmNex 'Install Ookla Speedtest?' (NexL 'Official download for personal use.') 'No administrator rights required.')) {return}
        $s.SpeedInstallPending=$true;$s.SpeedStatus='Downloading and verifying Ookla Speedtest...';$s.Need=$true
    }
    function StartSpeedTest {
        if ($s.SpeedProc -or $s.SpeedInstallPending -or ($s.Job -and $s.JobKind -eq 'speed-install')) {return}
        $path=Get-NexSpeedtest;$s.SpeedPath=$path
        if (-not $path) {RequestSpeedtestInstall;return}
        # Do not silently accept third-party terms. Consent is local to this session.
        if ($s.SpeedConsentPath -ne $path) {
            if (-not (ConfirmNex 'Accept Ookla terms for personal use?' 'https://www.speedtest.net/about/eula' 'https://www.speedtest.net/about/terms')) {return}
            if (-not (ConfirmNex 'Accept Ookla privacy notice?' 'https://www.speedtest.net/about/privacy' 'A test sends connection data to Ookla.')) {return}
            $s.SpeedConsentPath=$path
        }
        $proc=New-Object System.Diagnostics.Process
        try {
            $proc.StartInfo.FileName=$path
            $proc.StartInfo.Arguments='--format=json --progress=no --accept-license --accept-gdpr'
            $proc.StartInfo.UseShellExecute=$false
            $proc.StartInfo.CreateNoWindow=$true
            $proc.StartInfo.RedirectStandardOutput=$true
            $proc.StartInfo.RedirectStandardError=$true
            $proc.StartInfo.RedirectStandardInput=$true
            $null=$proc.Start()
            $proc.StandardInput.Close()
            $s.SpeedOut=$proc.StandardOutput.ReadToEndAsync()
            $s.SpeedErr=$proc.StandardError.ReadToEndAsync()
            $s.SpeedProc=$proc; $s.SpeedStart=$clock.ElapsedMilliseconds
            $s.SpeedStatus='Running...'; $s.SpeedResult=$null; $s.Need=$true
        } catch {
            try { if (-not $proc.HasExited) { $proc.Kill() } } catch {}
            $proc.Dispose(); $s.SpeedProc=$null; $s.SpeedOut=$null; $s.SpeedErr=$null
            $s.SpeedStatus='Could not start Speedtest'; Notice $_.Exception.Message
        }
    }
    function PollSpeedTest {
        if (-not $s.SpeedProc) { return }
        if (($clock.ElapsedMilliseconds-$s.SpeedStart) -gt 120000) { StopSpeedTest 'Timed out'; return }
        if (-not $s.SpeedProc.HasExited -or -not $s.SpeedOut.IsCompleted -or -not $s.SpeedErr.IsCompleted) { return }
        try {
            $out=$s.SpeedOut.GetAwaiter().GetResult()
            $stderr=$s.SpeedErr.GetAwaiter().GetResult()
            if ($s.SpeedProc.ExitCode -ne 0) {
                $s.SpeedStatus='Speedtest failed. Try again.'
                if ($stderr) { Notice ($stderr.Trim() -split '\r?\n' | Select-Object -Last 1) }
                return
            }
            $r=$out | ConvertFrom-Json -ErrorAction Stop
            if ($null -eq $r.download.bandwidth -or $null -eq $r.upload.bandwidth -or $null -eq $r.ping.latency) { throw 'Unexpected Speedtest output. Use the official Ookla CLI.' }
            $s.SpeedResult=@{Down=[double]$r.download.bandwidth*8.0/1e6;Up=[double]$r.upload.bandwidth*8.0/1e6;Ping=[double]$r.ping.latency;Jitter=$r.ping.jitter;Server=([string]$r.server.name);ISP=([string]$r.isp);Time=(Get-Date -Format 'HH:mm:ss')}
            $s.SpeedStatus='Complete'
        } catch { $s.SpeedStatus='Could not read result'; Notice $_.Exception.Message }
        finally { $s.SpeedProc.Dispose(); $s.SpeedProc=$null; $s.SpeedOut=$null; $s.SpeedErr=$null; $s.Need=$true }
    }
    $procMetricsScript={
        $gpu=@{};$io=@{};$tcp=@{};$gpuKnown=$false;$ioKnown=$false;$tcpKnown=$false
        try {
            $engines=@(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop)
            foreach ($engine in $engines) {
                if ($engine.Name -match '^pid_(\d+)_') {
                    $id=[string]$Matches[1];$load=[double]$engine.UtilizationPercentage
                    if (-not $gpu.ContainsKey($id) -or $load -gt $gpu[$id]) {$gpu[$id]=[Math]::Max(0,[Math]::Min(100,$load))}
                }
            }
            $gpuKnown=$true
        } catch {}
        try {
            foreach ($row in @(Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop)) {
                if ($row.IDProcess -gt 0) {$io[[string]$row.IDProcess]=[double]$row.IODataBytesPersec/1MB}
            }
            $ioKnown=$true
        } catch {}
        try {
            foreach ($connection in @(Get-NetTCPConnection -ErrorAction Stop)) {
                $id=[string]$connection.OwningProcess
                if ($connection.State -eq 'Established') {$tcp[$id]=1+[int]$tcp[$id]}
            }
            $tcpKnown=$true
        } catch {}
        [pscustomobject]@{GPU=$gpu;IO=$io;TCP=$tcp;GPUKnown=$gpuKnown;IOKnown=$ioKnown;TCPKnown=$tcpKnown}
    }
    function SampleProcesses {
        if (-not $s.ProcMemoryTotal) {try {$osMem=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop;$s.ProcMemoryTotal=[double]$osMem.TotalVisibleMemorySize/1024.0} catch {}}
        $now=$clock.ElapsedMilliseconds; $dt=($now-$s.ProcAt)/1000.0; $fresh=@{}; $rows=@()
        foreach ($p in (Get-Process -ErrorAction SilentlyContinue)) {
            try {
                if ($null -eq $p.CPU) { $cpu=$null } else { $cpu=[double]$p.CPU }
                $id=[string]$p.Id; $used=$null
                if ($null -ne $cpu -and $s.ProcAt -gt 0 -and $dt -gt 0 -and $s.PrevProc.ContainsKey($id) -and $null -ne $s.PrevProc[$id]) {
                    $used=[Math]::Min(100,[Math]::Max(0,($cpu-$s.PrevProc[$id])*100/$dt/[Environment]::ProcessorCount))
                }
                $fresh[$id]=$cpu
                $gpu=$null;$io=$null;$tcp=$null
                if ($s.ProcMetrics -and ($now-$s.ProcMetricsAt) -lt 10000) {
                    $m=$s.ProcMetrics
                    if ($m.GPUKnown -and $m.GPU.ContainsKey($id)) {$gpu=$m.GPU[$id]}
                    if ($m.IOKnown -and $m.IO.ContainsKey($id)) {$io=$m.IO[$id]}
                    if ($m.TCPKnown) {$tcp=[int]$m.TCP[$id]}
                }
                $rows+=@{Id=$p.Id;Name=$p.ProcessName;RAM=$p.WorkingSet64/1MB;CPU=$used;GPU=$gpu;IO=$io;TCP=$tcp}
            } catch {}
        }
        $s.PrevProc=$fresh; $s.ProcAt=$now; $s.ProcRows=$rows
        foreach ($id in @($visual.Keys)) {
            if ($id -like 'proc-*' -and ($now-$visual[$id].At) -gt 10000) { $visual.Remove($id) }
        }
    }
    function RefreshFiles {
        $selectedName=$null
        if ($s.FileItems.Count -gt $s.Pos) { $selectedName=$s.FileItems[$s.Pos].Name }
        if ($s.Drives) { $s.FileItems=@(Get-PSDrive -PSProvider FileSystem | Sort-Object Name) }
        else {
            try {
                $sortKey=$s.FileSort
                $s.FileItems=@(Get-ChildItem -LiteralPath $s.Folder -Force:$s.ShowHidden -ErrorAction Stop | Where-Object { -not $s.Filter -or $_.Name.IndexOf($s.Filter,[StringComparison]::OrdinalIgnoreCase) -ge 0 } | Sort-Object @{Expression='PSIsContainer';Descending=$true},@{Expression=$sortKey;Descending=($sortKey -ne 'Name')},Name)
            } catch { $s.FileItems=@(); Notice $_.Exception.Message }
        }
        $s.Pos=[Math]::Max(0,[Math]::Min($s.Pos,$s.FileItems.Count-1))
        if ($selectedName) { for ($i=0;$i -lt $s.FileItems.Count;$i++) { if ($s.FileItems[$i].Name -eq $selectedName) { $s.Pos=$i; break } } }
    }
    function GoFolder($path) {
        try {
            if ([string]::IsNullOrWhiteSpace($path)) { return }
            $path=$path.Trim('"')
            if (-not (Test-Path -LiteralPath $path -PathType Container -ErrorAction Stop)) { throw 'Folder not found.' }
            $dest=Get-Item -LiteralPath $path -ErrorAction Stop
            if ($dest.PSProvider.Name -ne 'FileSystem') { throw 'Only filesystem paths are supported.' }
            $s.Folder=$dest.FullName; $s.Drives=$false; $s.Pos=0; $s.Filter=''; $s.FileItems=@(); RefreshFiles
        } catch { Notice $_.Exception.Message }
    }
    function ParentFolder {
        if ($s.Drives) { $s.Drives=$false; $s.Pos=0; RefreshFiles; return }
        $p=[IO.Directory]::GetParent($s.Folder)
        if ($p) { GoFolder $p.FullName } else { $s.Drives=$true; $s.Pos=0; $s.FileItems=@(); RefreshFiles }
    }
    $textExtensions=@('.txt','.log','.json','.xml','.csv','.md','.ini','.toml','.yaml','.yml','.ps1','.py','.js','.ts','.html','.css','.bat','.cmd','.cfg','.conf','.lua','.gitignore','.sh','.sql','.c','.cpp','.h','.cs','.rs','.java')
    function FileNameValid([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name) -or $name -in @('.','..') -or $name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $name.EndsWith('.') -or $name.EndsWith(' ') -or $name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { throw 'Invalid file name.' }
    }
    function ConfirmNex([string]$title,[string]$detail,[string]$note) {
        try {
            $choice=1
            while ($true) {
                $w=[Console]::WindowWidth; $h=[Console]::WindowHeight
                if ($w -lt 32 -or $h -lt 10) {
                    Write-Host "$e[2J$e[H$pink $(NexL 'Enlarge the window or press Esc.')$reset" -NoNewline
                    $ev=WaitNexEvent; if ($ev.Key -eq 'Escape') { return $false }; continue
                }
                $inner=[Math]::Min(64,$w-4)
                $x=[Math]::Max(1,[int][Math]::Floor(($w-$inner-2)/2)+1); $y=[Math]::Max(1,[int][Math]::Floor(($h-8)/2)+1)
                $a=if ($choice -eq 0) {"$bg$red"} else {$red}; $b=if ($choice -eq 1) {"$bg$pink"} else {$gray}
                $yes='[ '+(NexL 'Confirm')+' ]'; $no='[ '+(NexL 'Cancel')+' ]'; $action='  '+$yes+'  '+$no
                $lines=@("$pink╭$('─'*$inner)╮$reset", "$pink│$reset$red$(Fit ('  '+(NexL $title)) $inner)$pink│$reset", "$pink│$reset$white$(Fit ('  '+$detail) $inner)$pink│$reset", "$pink│$reset$gray$(Fit ('  '+(NexL $note)) $inner)$pink│$reset", "$pink│$(' '*$inner)│$reset", "$pink│$reset  $a$yes$reset  $b$no$reset$(' '*[Math]::Max(0,$inner-$action.Length))$pink│$reset", "$pink╰$('─'*$inner)╯$reset", "$gray  $(NexL 'Click / Left / Right / Enter / Esc')$reset")
                $frame="$e[2J$e[?25l"
                for ($j=0;$j -lt $lines.Count -and $y+$j -le $h;$j++) { $frame+="$e[$($y+$j);${x}H$(ClipAnsi $lines[$j] ($w-$x+1))" }
                Write-Host $frame -NoNewline
                $ev=WaitNexEvent; $k=$ev.Key
                if ($k -eq 'Click' -and $ev.Y -eq $y+4) {
                    $rel=$ev.X-($x-1)-3
                    if ($rel -ge 0 -and $rel -lt $yes.Length) { return $true }
                    if ($rel -ge $yes.Length+2 -and $rel -lt $yes.Length+2+$no.Length) { return $false }
                }
                if ($k -eq 'Escape') { return $false }
                if ($k -in @('LeftArrow','RightArrow','Tab')) { $choice=1-$choice }
                if ($k -eq 'Enter') { return ($choice -eq 0) }
            }
        } finally { ResetDraw }
    }
    function EditText($item,[switch]$LogoMode) {
        if ($LogoMode) {
            $item=[pscustomobject]@{Name=(NexL 'Custom logo')}
            $text=[string]$prefs.CustomLogo
        } else {
        if ($item.PSIsContainer -or $item.Extension -notin $textExtensions) { Notice 'Select a supported text file.'; return }
        if ($item.Length -gt 262144) { Notice 'Editor limit: 256 KiB. Use external editor for large files.'; return }
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { Notice 'Editing links is not supported.'; return }
        $path=$item.FullName
        try {
            $bytes=[IO.File]::ReadAllBytes($path); $base64=[Convert]::ToBase64String($bytes)
            $encoding=[Text.UTF8Encoding]::new($false,$true); $skip=0
            if ($bytes.Length -ge 4 -and (($bytes[0] -eq 255 -and $bytes[1] -eq 254 -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) -or ($bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 254 -and $bytes[3] -eq 255))) { throw 'UTF-32 is not supported by this editor.' }
            if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { $encoding=[Text.UTF8Encoding]::new($true,$true); $skip=3 }
            elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) { $encoding=[Text.UnicodeEncoding]::new($false,$true,$true); $skip=2 }
            elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 254 -and $bytes[1] -eq 255) { $encoding=[Text.UnicodeEncoding]::new($true,$true,$true); $skip=2 }
            $text=$encoding.GetString($bytes,$skip,$bytes.Length-$skip)
            if ($text -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') { throw 'Binary/control data is not supported.' }
        } catch { Notice ('Editor: '+$_.Exception.Message); return }
        }
        $nl=if ($text.Contains("`r`n")) {"`r`n"} elseif ($text.Contains("`r")) {"`r"} elseif ($text.Contains("`n")) {"`n"} else {[Environment]::NewLine}
        $buf=New-Object 'System.Collections.Generic.List[string]'
        foreach ($line in ($text -split '\r\n|\n|\r')) { $buf.Add([string]$line) }
        if (-not $buf.Count) { $buf.Add('') }
        $r=0; $col=0; $top=0; $left=0; $dirty=$false; $msg=''; $quit=$false; $selectAll=$false
        # Use raw input in the editor as well as in its modal dialogs.
        # A native mode snapshot is separate from the dashboard's own snapshot.
        $editorMode=-1
        try { $editorMode=[NexDash.NativeInput215]::EnableEditor() } catch {}
        $editorNative=($editorMode -ge 0)
        if (-not $editorNative) { PauseMouse }

        function ReadEditorEvent {
            $sizeBefore="$([Console]::WindowWidth)x$([Console]::WindowHeight)"
            while ($true) {
                if ($editorNative) {
                    $record=[NexDash.NativeInput215]::Poll()
                    if ($record.Type -eq 1 -and $record.KeyDown -ne 0) {
                        $vk=[int]$record.VirtualKey
                        $ch=[char]$record.UnicodeChar
                        $ctrlDown=($record.ControlState -band 12) -ne 0
                        $keyName='Text'
                        if ([Enum]::IsDefined([System.ConsoleKey],$vk)) { $keyName=([System.ConsoleKey]$vk).ToString() }
                        elseif ($ch -eq [char]0) { continue }
                        return @{Key=$keyName;KeyChar=$ch;Ctrl=$ctrlDown}
                    }
                    if ($record.Type -eq 2 -and $record.Flags -in @(0,2) -and ($record.Buttons -band 1)) {
                        return @{Key='Click';X=([int]$record.X-[Console]::WindowLeft);Y=([int]$record.Y-[Console]::WindowTop);Ctrl=$false;KeyChar=[char]0}
                    }
                    if ($record.Type -eq 2 -and $record.Flags -eq 4) {
                        $wheelKey=if ($record.Buttons -band 0x80000000L) {'DownArrow'} else {'UpArrow'}
                        return @{Key=$wheelKey;Ctrl=$false;KeyChar=[char]0}
                    }
                } elseif ([Console]::KeyAvailable) {
                    $keyInfo=[Console]::ReadKey($true)
                    return @{Key=$keyInfo.Key.ToString();KeyChar=$keyInfo.KeyChar;Ctrl=(($keyInfo.Modifiers -band [ConsoleModifiers]::Control) -ne 0)}
                }
                if ("$([Console]::WindowWidth)x$([Console]::WindowHeight)" -ne $sizeBefore) { return @{Key='Resize';Ctrl=$false;KeyChar=[char]0} }
                Start-Sleep -Milliseconds 12
            }
        }
        function EditorExitChoice {
            $choice=0
            $labels=@('[ Save & exit ]','[ Discard ]','[ Cancel ]') | ForEach-Object {NexL $_}
            try {
                while ($true) {
                    $dw=[Console]::WindowWidth; $dh=[Console]::WindowHeight
                    $dx=[Math]::Max(1,[int][Math]::Floor(($dw-[Math]::Max(52,(($labels -join ' ').Length+4)))/2))
                    $dy=[Math]::Max(1,[int][Math]::Floor(($dh-8)/2))
                    $buttons=''; $ranges=@(); $buttonX=$dx-1+2
                    for ($n=0;$n -lt $labels.Count;$n++) {
                        $shade=if ($n -eq 1) {$red} else {$pink}
                        if ($n -eq $choice) { $buttons+="$bg$shade$($labels[$n])$reset " }
                        else { $buttons+="$shade$($labels[$n])$reset " }
                        $ranges+=@{Start=$buttonX;End=$buttonX+$labels[$n].Length;Choice=$n}
                        $buttonX+=$labels[$n].Length+1
                    }
                    $hint=if ($editorNative) {'  Click | Left / Right | Enter | Esc'} else {'  Left / Right | Enter | Esc'}
                    $dialog=@("$pink  $(Fit ((SafeText (Get-NexName))+' / '+(NexL 'Editor')) 44)$reset", "$muted$('─'*48)$reset", "$white  $(NexL 'Save changes before leaving?')$reset", "$gray  $(Fit (SafeText $item.Name) 44)$reset", '', "  $buttons", "$gray$hint$reset")
                    $draw="$e[?25l$e[2J"
                    for ($n=0;$n -lt $dialog.Count -and $dy+$n -le $dh;$n++) {
                        $draw+="$e[$($dy+$n);${dx}H$(ClipAnsi $dialog[$n] ([Math]::Max(1,$dw-$dx)))"
                    }
                    Write-Host $draw -NoNewline
                    $de=ReadEditorEvent; $dk=$de.Key
                    if ($dk -eq 'Click') {
                        if ($de.Y -eq ($dy+4) -and $de.Y -lt $dh) {
                            foreach ($range in $ranges) {
                                if ($de.X -ge $range.Start -and $de.X -lt $range.End -and $de.X -lt ($dw-1)) { return @('Save','Discard','Cancel')[$range.Choice] }
                            }
                        }
                        continue
                    }
                    if ($dk -eq 'Escape' -or $dk -eq 'C') { return 'Cancel' }
                    if ($dk -eq 'S' -or $dk -eq 'F2' -or [int]$de.KeyChar -eq 19) { return 'Save' }
                    if ($dk -eq 'D') { return 'Discard' }
                    if ($dk -in @('RightArrow','Tab')) { $choice=($choice+1)%3 }
                    if ($dk -eq 'LeftArrow') { $choice=($choice+2)%3 }
                    if ($dk -eq 'Enter') { return @('Save','Discard','Cancel')[$choice] }
                }
            } finally { Write-Host "$e[2J$e[H" -NoNewline }
        }
        try {
            Write-Host "$e[2J$e[H" -NoNewline
            while (-not $quit) {
                $w=[Console]::WindowWidth; $h=[Console]::WindowHeight
                if ($w -lt 30 -or $h -lt 9) { Write-Host "$e[2J$e[H${pink}Enlarge terminal, or Esc to close.$reset" -NoNewline }
                else {
                    $view=$h-4; $avail=$w-9
                    $top=[Math]::Max(0,[Math]::Min($top,$r)); if ($r -ge $top+$view) { $top=$r-$view+1 }
                    $left=[Math]::Max(0,[Math]::Min($left,$col)); if ($col -ge $left+$avail) { $left=$col-$avail+1 }
                    $status=if ($dirty) {' * '+(NexL 'Unsaved')} else {' '+(NexL 'Saved')}
                    $frame="$e[?25l$e[H$e[2K$pink$(ClipAnsi ('  '+(SafeText (Get-NexName))+' / '+(NexL 'Editor')+' / '+(SafeText $item.Name)+$status) ($w-1))`r`n$e[2K$muted$('─'*($w-1))$reset`r`n"
                    for ($j=0;$j -lt $view;$j++) {
                        $i=$top+$j; $frame+="$e[2K"
                        if ($i -lt $buf.Count) {
                            $line=$buf[$i]; $visible=if ($line.Length -gt $left) {$line.Substring($left)} else {''}
                            $visible=$visible.Replace("`t",' ')
                            $selectStyle=if ($LogoMode -and $selectAll) {$bg} else {''}
                            $frame+="$gray$('{0,5}' -f ($i+1)) │ $selectStyle$white$(ClipAnsi (SafeText $visible) $avail)$reset"
                        }
                        $frame+="`r`n"
                    }
                    $saveButton='[ '+(NexL 'Save')+' ]';$exitButton='[ '+(NexL 'Exit')+' ]'
                    $footer="$pink$saveButton$reset $purple$exitButton$reset $gray Ctrl+S / F2 | Esc | Ctrl+V$reset"
                    $statusLine=if ($msg) { $msg } elseif ($LogoMode -and $selectAll) {NexL 'All text selected'} elseif ($LogoMode) {NexL 'Paste art | Ctrl+A selects all | Empty + Save = default'} else { "Line $($r+1)/$($buf.Count)  Col $($col+1)" }
                    $statusColor=if ($msg -like 'Save failed:*') {$red} elseif ($msg -like 'Saved*' -or $msg -eq 'Already saved.' -or ($LogoMode -and $msg -in @((NexL 'Custom logo saved.'),(NexL 'Default logo restored.')))) {$green} else {$gray}
                    $frame+="$e[2K$(ClipAnsi $footer ($w-1))`r`n$e[2K$statusColor$(ClipAnsi (SafeText (NexL $statusLine)) ($w-1))$reset"
                    $frame+="$e[$($r-$top+3);$([Math]::Min($w-1,$col-$left+9))H$e[?25h"
                    Write-Host $frame -NoNewline
                }
                $k=ReadEditorEvent; $ctrl=$k.Ctrl
                if ($k.Key -eq 'Resize') { continue }
                $msg=''
                if ($LogoMode -and (($ctrl -and $k.Key -eq 'A') -or [int]$k.KeyChar -eq 1)) {$selectAll=$true;continue}
                # Mouse buttons, F2, and raw Ctrl+S all use the same save path.
                $saveRequested=($k.Key -eq 'F2' -or ($ctrl -and $k.Key -eq 'S') -or [int]$k.KeyChar -eq 19)
                $exitRequested=($k.Key -eq 'Escape')
                if ($k.Key -eq 'Click') {
                    if ($w -lt 30 -or $h -lt 9) { continue }
                    if ($k.Y -eq ($h-2)) {
                        if ($k.X -ge 0 -and $k.X -lt $saveButton.Length) { $saveRequested=$true }
                        elseif ($k.X -ge ($saveButton.Length+1) -and $k.X -lt ($saveButton.Length+1+$exitButton.Length)) { $exitRequested=$true }
                    } elseif ($k.Y -ge 2 -and $k.Y -lt ($h-2)) {
                        $selectAll=$false
                        $r=[Math]::Min($buf.Count-1,$top+$k.Y-2)
                        $col=[Math]::Max(0,[Math]::Min($buf[$r].Length,$left+$k.X-8))
                    }
                    if (-not $saveRequested -and -not $exitRequested) { continue }
                }
                $saveAndExit=$false
                if ($exitRequested) {
                    if (-not $dirty) { break }
                    $decision=EditorExitChoice
                    if ($decision -eq 'Discard') { break }
                    if ($decision -ne 'Save') { continue }
                    $saveRequested=$true; $saveAndExit=$true
                }
                if ($saveRequested) {
                    if (-not $dirty) { if ($saveAndExit) { break }; $msg='Already saved.'; continue }
                    if ($LogoMode) {
                        $previousLogo=$prefs.CustomLogo
                        try {
                            $newLogo=Normalize-NexLogo ($buf -join "`n")
                            $prefs.CustomLogo=$newLogo
                            Save-NexPreferences
                            $dirty=$false; $selectAll=$false
                            $msg=if ($newLogo) {NexL 'Custom logo saved.'} else {NexL 'Default logo restored.'}
                            Notice $msg
                            if ($saveAndExit) {break}
                        } catch {$prefs.CustomLogo=$previousLogo;$msg='Save failed: '+$_.Exception.Message}
                        continue
                    }
                    $tmp=$null
                    try {
                        if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -cne $base64) { throw 'File changed outside NEX. Save refused.' }
                        $tmp=Join-Path ([IO.Path]::GetDirectoryName($path)) ('.nex-'+[guid]::NewGuid().ToString('N')+'.tmp')
                        [IO.File]::WriteAllText($tmp,($buf -join $nl),$encoding)
                        $expected=[Convert]::ToBase64String([IO.File]::ReadAllBytes($tmp))
                        [IO.File]::Replace($tmp,$path,[System.Management.Automation.Language.NullString]::Value); $tmp=$null
                        $actual=[Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
                        if ($actual -cne $expected) { throw 'Saved content could not be verified.' }
                        $base64=$actual; $dirty=$false; $msg='Saved.'
                    } catch { $msg='Save failed: '+$_.Exception.Message }
                    finally { if ($tmp -and [IO.File]::Exists($tmp)) { try { [IO.File]::Delete($tmp) } catch {} } }
                    if ($saveAndExit -and -not $dirty) { Notice 'File saved.'; break }
                    continue
                }
                if (($ctrl -and $k.Key -eq 'V') -or [int]$k.KeyChar -eq 22) {
                    try { $insert=Get-Clipboard -Raw -ErrorAction Stop } catch { $msg='Clipboard unavailable.'; continue }
                    if ($insert -and $insert.Length -le 262144 -and $insert -notmatch '[\x00-\x08\x0B\x0C\x0E-\x1F]') {
                        if ($LogoMode -and $selectAll) {$buf.Clear();$buf.Add('');$r=0;$col=0;$top=0;$left=0;$selectAll=$false}
                        $parts=@($insert -split '\r\n|\r|\n'); $tail=$buf[$r].Substring($col); $prefix=$buf[$r].Substring(0,$col)
                        $buf[$r]=$prefix+$parts[0]; $col=$buf[$r].Length
                        for ($j=1;$j -lt $parts.Count;$j++) { $r++; $buf.Insert($r,$parts[$j]); $col=$parts[$j].Length }
                        $buf[$r]+=$tail; $dirty=$true
                    }; continue
                }
                if ($ctrl) { continue }
                if ($LogoMode -and $selectAll) {
                    if ($k.Key -in @('Backspace','Delete','Enter','Tab') -or (-not [char]::IsControl($k.KeyChar))) {
                        $buf.Clear();$buf.Add('');$r=0;$col=0;$top=0;$left=0;$dirty=$true;$selectAll=$false
                        if ($k.Key -in @('Backspace','Delete')) {continue}
                    } else {$selectAll=$false}
                }
                switch ($k.Key.ToString()) {
                    'UpArrow' { $r=[Math]::Max(0,$r-1); $col=[Math]::Min($col,$buf[$r].Length) }
                    'DownArrow' { $r=[Math]::Min($buf.Count-1,$r+1); $col=[Math]::Min($col,$buf[$r].Length) }
                    'LeftArrow' { if ($col -gt 0) {$col--} elseif ($r -gt 0) {$r--; $col=$buf[$r].Length} }
                    'RightArrow' { if ($col -lt $buf[$r].Length) {$col++} elseif ($r -lt $buf.Count-1) {$r++;$col=0} }
                    'Home' { $col=0 }
                    'End' { $col=$buf[$r].Length }
                    'PageUp' { $r=[Math]::Max(0,$r-[Math]::Max(1,$h-4)); $col=[Math]::Min($col,$buf[$r].Length) }
                    'PageDown' { $r=[Math]::Min($buf.Count-1,$r+[Math]::Max(1,$h-4)); $col=[Math]::Min($col,$buf[$r].Length) }
                    'Enter' { $tail=$buf[$r].Substring($col); $buf[$r]=$buf[$r].Substring(0,$col); $r++; $buf.Insert($r,$tail); $col=0; $dirty=$true }
                    'Backspace' { if ($col -gt 0) { $buf[$r]=$buf[$r].Remove($col-1,1);$col--;$dirty=$true } elseif ($r -gt 0) { $tail=$buf[$r];$buf.RemoveAt($r);$r--;$col=$buf[$r].Length;$buf[$r]+=$tail;$dirty=$true } }
                    'Delete' { if ($col -lt $buf[$r].Length) { $buf[$r]=$buf[$r].Remove($col,1);$dirty=$true } elseif ($r -lt $buf.Count-1) { $buf[$r]+=$buf[$r+1];$buf.RemoveAt($r+1);$dirty=$true } }
                    'Tab' { $buf[$r]=$buf[$r].Insert($col,'    ');$col+=4;$dirty=$true }
                    default { if (-not [char]::IsControl($k.KeyChar)) { $buf[$r]=$buf[$r].Insert($col,[string]$k.KeyChar);$col++;$dirty=$true } }
                }
            }
        } finally {
            Write-Host "$e[?25l" -NoNewline
            if ($editorNative) { [NexDash.NativeInput215]::Restore($editorMode) } else { ResumeMouse }
            ResetDraw; if (-not $LogoMode) {RefreshFiles}
        }
    }
    function OpenFile {
        if (-not $s.FileItems.Count) { return }
        $item=$s.FileItems[$s.Pos]
        if ($s.Drives) { GoFolder $item.Root }
        elseif ($item.PSIsContainer) { GoFolder $item.FullName }
        elseif ($item.Extension -in $textExtensions) { EditText $item }
        else { try { Invoke-Item -LiteralPath $item.FullName -ErrorAction Stop } catch { Notice $_.Exception.Message } }
    }
    function FileAction($key) {
        if ($key -eq 'D') { $s.Drives=$true; $s.Pos=0; $s.FileItems=@(); RefreshFiles; return }
        if ($key -eq 'P') { $v=Ask 'Folder path'; if ($v) { GoFolder $v }; return }
        if ($key -eq 'F') { $v=Ask 'Filter names (empty cancels)'; if ($v) { $s.Filter=$v; $s.Pos=0; RefreshFiles }; return }
        if ($key -eq 'R') { $s.Filter=''; RefreshFiles; return }
        if ($key -eq 'H') { $s.ShowHidden=-not $s.ShowHidden; RefreshFiles; return }
        if ($key -eq 'F4') { $s.FileSort=switch ($s.FileSort) { 'Name' {'Length'} 'Length' {'LastWriteTime'} default {'Name'} }; RefreshFiles; return }
        if ($key -eq 'O') { if (-not $s.Drives) { Start-Process explorer.exe -ArgumentList ('"{0}"' -f $s.Folder) }; return }
        if ($key -in @('N','M') -and -not $s.Drives) {
            $v=Ask $(if ($key -eq 'N') {'New file name (e.g. notes.txt)'} else {'New folder name'})
            if (-not $v) { return }
            try {
                FileNameValid $v; $dest=Join-Path $s.Folder $v
                if (Test-Path -LiteralPath $dest) { throw 'Name already exists.' }
                if ($key -eq 'N') { $stream=[IO.File]::Open($dest,[IO.FileMode]::CreateNew); $stream.Dispose() }
                else { $null=[IO.Directory]::CreateDirectory($dest) }
                $s.Filter=''; RefreshFiles
                for ($i=0;$i -lt $s.FileItems.Count;$i++) { if ($s.FileItems[$i].Name -eq $v) { $s.Pos=$i; break } }
                Notice 'Created.'
            } catch { Notice $_.Exception.Message }; return
        }
        if ($key -eq 'V' -and $s.Clipboard -and -not $s.Drives) {
            try {
                $src=Get-Item -LiteralPath $s.Clipboard.Path -ErrorAction Stop
                $dest=Join-Path $s.Folder $src.Name
                if (Test-Path -LiteralPath $dest) { throw 'Destination already exists; nothing overwritten.' }
                if ($src.PSIsContainer -and ($s.Folder.TrimEnd('\')+'\').StartsWith($src.FullName.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Cannot copy/move a folder into itself.' }
                if ($src.PSIsContainer -and ($src.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Directory links are not supported.' }
                if (-not (ConfirmNex ("$($s.Clipboard.Mode.ToUpperInvariant()) FILE OR FOLDER?") $src.Name ("Destination: $($s.Folder)"))) { return }
                if ($src.PSIsContainer) {
                    if ($s.Clipboard.Mode -eq 'Move' -and [IO.Path]::GetPathRoot($src.FullName) -ne [IO.Path]::GetPathRoot($dest)) { throw 'Cross-drive folder moves are not supported here. Use Explorer (O).' }
                    # Avoid recursively following junctions or other reparse points.
                    if ($s.Clipboard.Mode -eq 'Copy') {
                        $stack=New-Object 'System.Collections.Generic.Stack[string]'; $stack.Push($src.FullName)
                        while ($stack.Count) {
                            foreach ($child in (Get-ChildItem -LiteralPath ($stack.Pop()) -Force -ErrorAction Stop)) {
                                if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Folder contains links or reparse points. Use Windows Explorer.' }
                                if ($child.PSIsContainer) { $stack.Push($child.FullName) }
                            }
                        }
                    }
                }
                if (Test-Path -LiteralPath $dest) { throw 'Destination already exists; nothing overwritten.' }
                if ($s.Clipboard.Mode -eq 'Move') {
                    if ($src.PSIsContainer) { [IO.Directory]::Move($src.FullName,$dest) }
                    else { [IO.File]::Move($src.FullName,$dest) }
                    $s.Clipboard=$null
                } elseif ($src.PSIsContainer) { Copy-Item -LiteralPath $src.FullName -Destination $dest -Recurse -ErrorAction Stop }
                else { [IO.File]::Copy($src.FullName,$dest,$false) }
                RefreshFiles; Notice 'Operation completed.'
            } catch { Notice $_.Exception.Message }; return
        }
        if ($s.Drives -or -not $s.FileItems.Count) { return }
        $item=$s.FileItems[$s.Pos]
        switch ($key) {
            'Delete' {
                try {
                    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Links must be handled in Explorer.' }
                    $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($item.FullName))
                    if ($drive.DriveType -ne [IO.DriveType]::Fixed) { throw 'Recycle Bin action is restricted to local fixed drives.' }
                    if (-not (ConfirmNex 'MOVE TO RECYCLE BIN?' $item.Name 'Windows may show a further confirmation.')) { return }
                    $current=Get-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                    if ($current.PSIsContainer -ne $item.PSIsContainer -or ($current.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Item changed; refresh and try again.' }
                    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
                    if ($item.PSIsContainer) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($item.FullName,[Microsoft.VisualBasic.FileIO.UIOption]::AllDialogs,[Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,[Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException) }
                    else { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($item.FullName,[Microsoft.VisualBasic.FileIO.UIOption]::AllDialogs,[Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,[Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException) }
                    RefreshFiles; Notice 'Removed via Windows Recycle Bin.'
                } catch { Notice $_.Exception.Message }
            }
            'E' { EditText $item }
            'F3' {
                $size=if ($item.PSIsContainer) {'Folder'} else {"$($item.Length) bytes"}
                $s.Preview=@{Title=('Properties: '+$item.Name);Pos=0;Lines=@($item.FullName,'',('Size: '+$size),('Created: '+$item.CreationTime),('Modified: '+$item.LastWriteTime),('Attributes: '+$item.Attributes))}
            }
            'C'  { $s.Clipboard=@{Path=$item.FullName;Mode='Copy'}; Notice 'Copied to dashboard clipboard; navigate and press V.' }
            'X' { $s.Clipboard=@{Path=$item.FullName;Mode='Move'}; Notice 'Marked to move; navigate and press V.' }
            'F2' {
                $v=Ask ('Rename: '+$item.Name)
                if ($v) { try {
                    FileNameValid $v
                    if (Test-Path -LiteralPath (Join-Path $s.Folder $v)) { throw 'Name already exists.' }
                    Rename-Item -LiteralPath $item.FullName -NewName $v -ErrorAction Stop; RefreshFiles; Notice 'Renamed.'
                } catch { Notice $_.Exception.Message } }
            }
            'Spacebar' {
                if ($item.PSIsContainer) { Notice 'Select a text file to preview.'; return }
                if ($item.Extension -notin @('.txt','.log','.json','.xml','.csv','.md','.ini','.toml','.yaml','.yml','.ps1','.py','.js','.html','.css','.bat','.cmd','.cfg','.conf','.lua')) { Notice 'Preview supports text files only.'; return }
                try {
                    $reader=[IO.StreamReader]::new($item.FullName,$true)
                    try { $buf=[char[]]::new(12000); $n=$reader.ReadBlock($buf,0,$buf.Length); $s.Preview=@{Title=$item.Name;Lines=@((-join $buf[0..([Math]::Max(0,$n-1))]) -split '\r?\n' | ForEach-Object { SafeText $_ });Pos=0} }
                    finally { $reader.Dispose() }
                    if ($n -eq 0) { $s.Preview.Lines=@('(empty file)') }
                } catch { Notice $_.Exception.Message }
            }
        }
    }
    $updateScript = {
        $ErrorActionPreference='Stop'
        $session=New-Object -ComObject Microsoft.Update.Session
        $searcher=$session.CreateUpdateSearcher()
        $searcher.CanAutomaticallyUpgradeService=$false
        $searcher.Online=$true
        $result=$searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")
        if ([int]$result.ResultCode -ne 2) { throw "Windows Update returned result code $($result.ResultCode)." }
        $regular=@(); $optional=@(); $defender=@(); $unknown=@()
        for ($i=0;$i -lt $result.Updates.Count;$i++) {
            $u=$result.Updates.Item($i)
            $kbIds=@($u.KBArticleIDs | ForEach-Object { ([string]$_) -replace '^KB','' })
            $kb=@($kbIds | ForEach-Object { 'KB'+$_ }) -join ', '
            $size=if ($u.MaxDownloadSize -gt 0) { '{0:0.0} MiB max' -f ($u.MaxDownloadSize/1MB) } else {'Size unknown'}
            $detail=@("  $($u.Title)","  $kb | $size | Revision $($u.Identity.RevisionNumber)")
            if ($kbIds -contains '2267602' -or $kbIds -contains '4052623' -or $u.Title -match 'Microsoft Defender Antivirus|Windows Defender Antivirus') {
                $defender+=,@($detail)
            } else {
                try {
                    if ($null -eq $u.BrowseOnly) { throw 'Optional status unavailable' }
                    if ([bool]$u.BrowseOnly) { $optional+=,@($detail) }
                    else { $regular+=,@($detail) }
                } catch { $unknown+=,@($detail) }
            }
        }
        if ($regular.Count -eq 0 -and $unknown.Count -eq 0) {
            'No regular software updates found by this scan.'
        } else { "Regular software updates: $($regular.Count)" }
        "Optional software updates: $($optional.Count)"
        "Microsoft Defender updates: $($defender.Count)"
        if ($unknown.Count) { "Unclassified software updates: $($unknown.Count)" }
        foreach ($group in @(@{Title='REGULAR SOFTWARE';Items=$regular},@{Title='OPTIONAL SOFTWARE';Items=$optional},@{Title='MICROSOFT DEFENDER';Items=$defender},@{Title='UNCLASSIFIED';Items=$unknown})) {
            if ($group.Items.Count -eq 0) { continue }
            ''
            "$($group.Title) ($($group.Items.Count))"
            foreach ($entry in $group.Items) { foreach ($line in $entry) { [string]$line } }
        }
        try {
            $mp=Get-MpComputerStatus -ErrorAction Stop
            if ($mp.AntivirusSignatureVersion) {
                ''
                "Installed Defender signatures: $($mp.AntivirusSignatureVersion)"
                if ($mp.AntivirusSignatureLastUpdated) { "Defender last updated: $($mp.AntivirusSignatureLastUpdated)" }
            }
        } catch {}
    }

    function UpdateAction($key) {
        if ($key -in @('Enter','C')) {
            if ($s.Job) { Notice 'A query is running. Try again shortly.'; return }
            $s.UpdateStatus='Checking'; $s.UpdateRows=@(); $s.UpdatePos=0; $s.UpdateStart=$clock.ElapsedMilliseconds
            StartWorker 'updates' $updateScript
            if (-not $s.Job) { $s.UpdateStatus='Failed' }
        } else { $s.UpdatePos=ScrollPos $key $s.UpdatePos $s.UpdateDisplayCount }
    }
    function ChangeNexDns {
        $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {Notice 'DNS changes require administrator rights.';return}
        $adapters=@(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -eq 'Up')
        if (-not $adapters.Count) {Notice 'No active physical adapters.';return}
        $ids=@($adapters | ForEach-Object {[string]$_.ifIndex})
        $labels=@($adapters | ForEach-Object {"$($_.Name) [$($_.ifIndex)]"})
        $id=Ask 'Choose network adapter' $labels $ids
        if ($id -notin $ids) {return}
        $adapter=$adapters | Where-Object {([string]$_.ifIndex) -eq $id} | Select-Object -First 1
        $dns=Get-DnsClientServerAddress -InterfaceIndex ([uint32]$id) -AddressFamily IPv4 -ErrorAction Stop
        $old=@($dns.ServerAddresses)
        $mode=Ask 'Choose DNS mode' @('Custom DNS','Automatic DNS (DHCP)') @('custom','auto')
        if ($mode -notin @('custom','auto')) {return}
        $servers=@()
        if ($mode -eq 'custom') {
            $text=Ask 'Enter IPv4 DNS addresses separated by commas'
            if (-not $text) {return}
            $parts=@($text -split '[,;\s]+' | Where-Object {$_})
            if ($parts.Count -lt 1 -or $parts.Count -gt 4) {Notice 'Invalid IPv4 DNS address.';return}
            foreach ($part in $parts) {
                $ip=$null
                if ($part -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or -not [Net.IPAddress]::TryParse($part,[ref]$ip) -or $ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or $ip.ToString() -ne $part -or $part -eq '0.0.0.0' -or $part -eq '255.255.255.255') {Notice 'Invalid IPv4 DNS address.';return}
                $servers+=$ip.ToString()
            }
        }
        $target=if ($mode -eq 'auto') {NexL 'Automatic DNS (DHCP)'} else {$servers -join ', '}
        if (-not (ConfirmNex 'APPLY DNS SETTINGS?' "$($adapter.Name): $target" 'Only the selected adapter will be changed.')) {return}
        # User-visible previous addresses, not a silent network-wide change.
        $s.ToolTitle='DNS';$s.ToolRows=@("$(NexL 'Current DNS'): $($old -join ', ')")
        if ($mode -eq 'auto') {Set-DnsClientServerAddress -InputObject $dns -ResetServerAddresses -ErrorAction Stop}
        else {Set-DnsClientServerAddress -InputObject $dns -ServerAddresses $servers -ErrorAction Stop}
        $actual=Get-DnsClientServerAddress -InterfaceIndex ([uint32]$id) -AddressFamily IPv4 -ErrorAction Stop
        $s.ToolRows=@([pscustomobject]@{Kind='DNS';Name=$adapter.Name;Value=($actual.ServerAddresses -join ', ')})
        $s.ToolPos=0;Notice 'DNS settings updated.'
    }
    function ToolAction($key) {
        $toolMap=@{D='Disks';N='DNS';S='Services';I='IP'}
        if ($key -eq 'G') {if ($s.Job) {Notice 'A query is running. Try again shortly.'} else {ChangeNexDns}}
        elseif ($toolMap.ContainsKey($key)) {
            if ($s.Job) { Notice 'A query is running. Try again shortly.' }
            else { $s.ToolTitle=$toolMap[$key]; $s.ToolRows=@('Reading...'); $s.ToolPos=0; StartWorker 'tools' $toolsScript $s.ToolTitle }
        } elseif ($key -eq 'E') { Start-Process eventvwr.msc }
        elseif ($key -eq 'T') { Start-Process taskmgr.exe }
        else { $s.ToolPos=ScrollPos $key $s.ToolPos $s.ToolDisplayCount }
    }
    function LogAction($key) {
        if ($key -in @('A','S')) { $s.LogName=if ($key -eq 'A') {'Application'} else {'System'}; $s.Logs=@(); $s.LogPos=0; $s.Next=0 }
        elseif ($key -eq 'R') { $s.Next=0 }
        elseif ($key -eq 'B' -or $key -eq 'Delete') {
            if ($s.LogName -notin @('Application','System')) { Notice 'Unsupported log.'; return }
            if ($s.Job) { Notice 'Wait for current log query.'; return }
            $name=$s.LogName
            try {
                $dir=Join-Path $HOME 'NexLogBackups'; $null=New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
                $backup=Join-Path $dir ($name+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.evtx')
                $session=[System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession
                if ($key -eq 'Delete') {
                    $principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
                    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Notice 'Clearing requires an administrator PowerShell.'; return }
                    if (-not (ConfirmNex 'ARCHIVE AND CLEAR LOG?' $name 'All events in this log; EVTX backup first.')) { return }
                    $session.ClearLog($name,$backup); $s.Logs=@(); $s.LogPos=0; $s.Next=0
                    Notice "Log archived and cleared: $backup"
                } else { $session.ExportLog($name,[System.Diagnostics.Eventing.Reader.PathType]::LogName,'*',$backup); Notice "Exported: $backup" }
            } catch { Notice $_.Exception.Message }
        }
        elseif ($key -eq 'Enter' -and $s.Logs.Count) { $l=$s.Logs[$s.LogPos]; $s.Preview=@{Title="Event $($l.Id) | $($l.Source)";Lines=@(("$($l.Time)`n$($l.Message)") -split '\r?\n');Pos=0} }
        else { $s.LogPos=ScrollPos $key $s.LogPos $s.Logs.Count }
    }
    $netScript = {
        $ErrorActionPreference='Stop'
        $adapters=Get-NetAdapter -Physical | Where-Object Status -eq 'Up'
        foreach ($a in $adapters) {
            $stat=Get-NetAdapterStatistics -Name $a.Name -ErrorAction SilentlyContinue
            $at=[Diagnostics.Stopwatch]::GetTimestamp()
            if ($stat) {
                $ip=@(Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress) -join ', '
                $type='Other adapter'
                try {
                    $ni=[System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object Name -eq $a.Name | Select-Object -First 1
                    if ($ni) {
                        switch ([string]$ni.NetworkInterfaceType) {
                            'Wireless80211' {$type='Wi-Fi'}
                            {$_ -in @('Ethernet','Ethernet3Megabit','FastEthernetT','FastEthernetFx','GigabitEthernet')} {$type='Ethernet'}
                            {$_ -in @('Wwanpp','Wwanpp2')} {$type='Mobile network'}
                        }
                    }
                } catch {}
                [pscustomobject]@{Name=$a.Name;Link=$a.LinkSpeed;IP=$ip;Type=$type;Rx=$stat.ReceivedBytes;Tx=$stat.SentBytes;At=$at}
            }
        }
    }
    $infoScript = {
        $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1
        $mb=Get-CimInstance Win32_BaseBoard | Select-Object -First 1
        $bios=Get-CimInstance Win32_BIOS | Select-Object -First 1
        "PC                 $env:COMPUTERNAME"
        "Windows            $($os.Caption) / $($os.BuildNumber)"
        "Processor          $($cpu.Name)"
        "Cores / threads    $($cpu.NumberOfCores) / $($cpu.NumberOfLogicalProcessors)"
        "Motherboard        $($mb.Manufacturer) $($mb.Product)"
        "BIOS               $($bios.SMBIOSBIOSVersion)"
        "Usable RAM         $([Math]::Round($os.TotalVisibleMemorySize/1MB,1)) GiB"
        foreach ($g in (Get-CimInstance Win32_VideoController)) { "GPU                $($g.Name)"; "Driver             $($g.DriverVersion)" }
        foreach ($d in (Get-CimInstance Win32_DiskDrive)) { "Disk               $($d.Model) / $([Math]::Round($d.Size/1GB)) GiB" }
        "PowerShell         $($PSVersionTable.PSVersion)"
    }
    $logScript = {
        param($name)
        try {
            Get-WinEvent -FilterHashtable @{LogName=$name;Level=1,2,3;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 80 -ErrorAction Stop |
                ForEach-Object { [pscustomobject]@{Time=$_.TimeCreated;Id=$_.Id;Source=$_.ProviderName;Level=$_.Level;Message=$_.Message} }
        } catch { if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { throw } }
    }
    $pingScript = {
        param($target)
        try {
            $p=New-Object System.Net.NetworkInformation.Ping
            try { $r=$p.Send($target,1200); if ($r.Status -eq 'Success') { "$($r.RoundtripTime) ms" } else { [string]$r.Status } }
            finally { $p.Dispose() }
        } catch { 'Unreachable / DNS error' }
    }
    $toolsScript = {
        param($which)
        switch ($which) {
            'DNS' { Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object {$_.ServerAddresses.Count} | ForEach-Object { [pscustomobject]@{Kind='DNS';Name=$_.InterfaceAlias;Value=($_.ServerAddresses -join ', ')} } }
            'Disks' { Get-PhysicalDisk -ErrorAction Stop | ForEach-Object { [pscustomobject]@{Kind='Disks';Name=$_.FriendlyName;Health=[string]$_.HealthStatus;Status=(@($_.OperationalStatus) -join ', ');Media=[string]$_.MediaType} } }
            'Services' { Get-Service -Name wuauserv,BITS,Dnscache,WinDefend -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{Kind='Services';Name=$_.Name;Value=[string]$_.Status} } }
            'IP' { Get-NetIPConfiguration -ErrorAction Stop | ForEach-Object { [pscustomobject]@{Kind='IP';Name=$_.InterfaceAlias;Value=($_.IPv4Address.IPAddress -join ', ');Gateway=($_.IPv4DefaultGateway.NextHop -join ', ')} } }
        }
    }

    # JSONC-aware tokenization. Only a selected property of the active profile is edited.
    function JsonTokens([string]$text) {
        $rx='"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/|[{}\[\]:,]|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null'
        @([regex]::Matches($text,$rx) | Where-Object { -not $_.Value.StartsWith('//') -and -not $_.Value.StartsWith('/*') })
    }
    function ParseConfig([string]$text) {
        $ts=@(JsonTokens $text); $parts=New-Object 'System.Collections.Generic.List[string]'
        for ($i=0;$i -lt $ts.Count;$i++) {
            if ($ts[$i].Value -eq ',' -and $i+1 -lt $ts.Count -and $ts[$i+1].Value -in @('}',']')) { continue }
            $parts.Add($ts[$i].Value)
        }
        # Reject unrecognized non-whitespace outside valid tokens/comments.
        $rx='"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/|[{}\[\]:,]|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null'
        if (-not [string]::IsNullOrWhiteSpace([regex]::Replace($text,$rx,''))) { throw 'Unsupported settings JSON format.' }
        ($parts -join '') | ConvertFrom-Json -ErrorAction Stop
    }
    function ReadConfig {
        $s.Config=$null; $s.ConfigError=''; $s.ConfigChoices=@()
        try {
            $paths=@(
                @{Path=(Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'); Edition='Stable'},
                @{Path=(Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'); Edition='Preview'},
                @{Path=(Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'); Edition='Unpackaged'}
            )
            $all=@()
            foreach ($entry in $paths) {
                $p=$entry.Path
                if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
                try {
                    $text=[IO.File]::ReadAllText($p); $obj=ParseConfig $text
                    if ($obj.profiles -and $obj.profiles.PSObject.Properties['defaults'] -and $null -ne $obj.profiles.defaults) {
                        $all+=@{Path=$p;Obj=$obj;Profile=$obj.profiles.defaults;Text=$text;Id=[guid]::Empty;Edition=$entry.Edition;Defaults=$true}
                    }
                    foreach ($profile in @($obj.profiles.list)) {
                        if (-not $profile -or -not $profile.guid -or $profile.hidden -eq $true) { continue }
                        try { $id=[guid]$profile.guid } catch { continue }
                        $all+=@{Path=$p;Obj=$obj;Profile=$profile;Text=$text;Id=$id;Edition=$entry.Edition}
                    }
                } catch {}
            }
            $s.ConfigChoices=@($all)
            if (-not $all.Count) { throw 'No readable terminal profiles found. Use Ctrl+,.' }
            if ($s.ConfigPick) {
                $found=@($all | Where-Object { $_.Path -eq $s.ConfigPick.Path -and $_.Id -eq $s.ConfigPick.Id })
                if ($found.Count -eq 1) { $s.Config=$found[0]; return }
                $s.ConfigPick=$null
            }
            $id=[guid]::Empty
            if ($env:WT_PROFILE_ID -and [guid]::TryParse($env:WT_PROFILE_ID,[ref]$id)) {
                $found=@($all | Where-Object { -not $_.Defaults -and $_.Id -eq $id })
                if ($found.Count -eq 1) { $s.Config=$found[0]; return }
                 $fallback=@($all | Where-Object {$_.Defaults} | Select-Object -First 1)
                if ($fallback.Count) {$s.Config=$fallback[0];return}
                throw 'Profile is ambiguous or missing. Click Select profile (G).'
            }
            # Delegated Win+X launches may not provide WT_PROFILE_ID.
            $found=@($all | Where-Object {
                -not $_.Defaults -and (
                    $_.Id -eq [guid]'61c54bbd-c2c6-5271-96e7-009a87ff44bf' -or
                    [string]$_.Profile.name -match '^Windows PowerShell(?:\s|$)' -or
                    [string]$_.Profile.commandline -match '(?i)\bpowershell\.exe\b'
                )
            })
            if ($found.Count -eq 1) { $s.Config=$found[0]; return }
            $fallback=@($all | Where-Object {$_.Defaults} | Select-Object -First 1)
            if ($fallback.Count) {$s.Config=$fallback[0];return}
            throw 'Click Select profile (G) and choose Windows PowerShell 5.1.'
        } catch { $s.ConfigError=$_.Exception.Message }
    }
    function SelectTerminalProfile {
        ReadConfig
        $choices=@($s.ConfigChoices)
        if (-not $choices.Count) { Notice $s.ConfigError; return }
        $labels=@()
        for ($i=0;$i -lt $choices.Count;$i++) {
            $item=$choices[$i]
            $label=if ($item.Defaults) { 'Defaults (all inheriting profiles / Win+X fallback)' } else { $item.Profile.name }
            $labels+=('{0}. {1} [{2}]' -f ($i+1),$label,$item.Edition)
            # One visible row per profile, mapped to its original index.
        }
        $v=Ask 'Choose Windows Terminal profile' $labels @(1..$choices.Count) $null $global:NexTerminalHelp['G']
        if (-not $v) { return }
        $n=0
        if (-not [int]::TryParse($v,[ref]$n) -or $n -lt 1 -or $n -gt $choices.Count) { Notice 'Invalid profile number.'; return }
        $item=$choices[$n-1]
        $s.ConfigPick=@{Path=$item.Path;Id=$item.Id}
        ReadConfig
        if ($s.Config) {
            if ($s.Config.Defaults) { Notice 'Defaults selected for display. Changes apply to all profiles.' }
            else { Notice "Selected $($s.Config.Profile.name)." }
        } else { Notice $s.ConfigError }
    }
    function Effective($key,$default) {
        if (-not $s.Config) { return $default }
        $p=$s.Config.Profile.PSObject.Properties[$key]
        if ($p) { return $p.Value }
        $d=$s.Config.Obj.profiles.defaults
        if ($d -and $d.PSObject.Properties[$key]) { return $d.PSObject.Properties[$key].Value }
        return $default
    }
    function FindDirectProperty($ts,[int]$begin,[string]$name) {
        $depth=0; $found=-1
        for ($j=$begin+1;$j -lt $ts.Count;$j++) {
            $v=$ts[$j].Value
            if ($depth -eq 0 -and $v -ceq ('"'+$name+'"') -and $j+1 -lt $ts.Count -and $ts[$j+1].Value -eq ':') {
                if ($found -ge 0) { throw "Duplicate property: $name" }
                $found=$j+2
            }
            if ($v -in @('{','[')) { $depth++ }
            elseif ($v -in @('}',']')) { if ($depth -eq 0) { break }; $depth-- }
        }
        return $found
    }
    function SetTerminalProperty([string]$key,$value) {
        try {
            $changes=@{};$changes[$key]=$value;$scheme=$null
            if ($key -eq 'colorScheme') {
                ReadConfig
                if (-not $s.Config) {throw $s.ConfigError}
                $scheme=@($s.Config.Obj.schemes | Where-Object { $_.name -ceq $value } | Select-Object -First 1)[0]
                if (-not $scheme) {throw 'Color scheme not found.'}
                foreach ($k in @('background','foreground','cursorColor','selectionBackground')) {
                    if ($scheme.PSObject.Properties[$k] -and $scheme.$k) {$changes[$k]=$scheme.$k}
                }
            }
            $count=Sync-NexTerminalAppearance $changes $scheme
            ReadConfig;Notice "Saved for all profiles ($count). Reopen tabs if needed."
        } catch {Notice $_.Exception.Message}
    }
    function SettingsAction($key) {
        if ($key -in @('A','C','T') -and -not $s.Config) { SelectTerminalProfile; if (-not $s.Config) { return } }
        switch ($key) {
            'G' { SelectTerminalProfile }
            'O' { if (-not $s.Config) { SelectTerminalProfile; if (-not $s.Config) { return } }; $v=Ask 'Opacity 0-100 (%)'; if ($v) { $n=0; if ([int]::TryParse($v,[ref]$n) -and $n -ge 0 -and $n -le 100) { SetTerminalProperty 'opacity' $n } else { Notice 'Enter a number from 0 to 100.' } } }
            'A' { $v=ChooseNexToggle 'Acrylic' ([bool](Effective 'useAcrylic' $false)) $global:NexTerminalHelp['A'];if ($null -ne $v) {SetTerminalProperty 'useAcrylic' $v} }
            'C' { $cursorChoices=@('bar','filledBox','emptyBox','underscore','vintage','doubleUnderscore'); $v=Ask 'Choose cursor shape' $cursorChoices $cursorChoices; if ($v) { if ($v -cin @('bar','filledBox','emptyBox','underscore','vintage','doubleUnderscore')) { SetTerminalProperty 'cursorShape' $v } else { Notice 'Unsupported cursor shape.' } } }
            'T' { $choices=@($s.Config.Obj.schemes | ForEach-Object { $_.name }); $v=Ask 'Choose an existing color scheme' $choices $choices; if ($v) { if ($s.Config -and @($s.Config.Obj.schemes | ForEach-Object { $_.name }) -contains $v) { $actual=@($s.Config.Obj.schemes | Where-Object name -eq $v)[0].name; SetTerminalProperty 'colorScheme' $actual } else { Notice 'Choose a listed scheme.' } } }
            'J' { if ($s.Config) { Start-Process notepad.exe -ArgumentList ('"{0}"' -f $s.Config.Path) } else { Notice 'Settings file not identified.' } }
            'R' { ReadConfig; Notice 'Settings refreshed.' }
        }
    }
    function BackupFileDialog([bool]$save) {
        PauseMouse
        $dialog=$null
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            if ($save) {$dialog=New-Object System.Windows.Forms.SaveFileDialog;$dialog.FileName='Dashboard.nexconfig';$dialog.OverwritePrompt=$true;$dialog.AddExtension=$true;$dialog.DefaultExt='nexconfig'}
            else {$dialog=New-Object System.Windows.Forms.OpenFileDialog;$dialog.CheckFileExists=$true;$dialog.Multiselect=$false}
            $dialog.Title=if ($save) {NexL 'Export configuration'} else {NexL 'Restore configuration'}
            $dialog.Filter='NEX configuration (*.nexconfig)|*.nexconfig'
            $dialog.RestoreDirectory=$true
            $dialog.InitialDirectory=[Environment]::GetFolderPath('MyDocuments')
            if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {return $dialog.FileName}
        } finally {if ($dialog) {$dialog.Dispose()};ResumeMouse;ResetDraw}
    }
    function ExportPublicConfig {
        $path=BackupFileDialog $true
        if (-not $path) {return}
        ReadConfig
        $a=Get-NexSharedPaletteChanges
        $a.fontFace=if ($prefs.Icons) {'JetBrainsMono Nerd Font Mono'} else {'Cascadia Mono'}
        $a.fontSize=12;$a.opacity=85;$a.useAcrylic=$true;$a.cursorShape='bar'
        $scheme=Get-NexSharedScheme
        if ($s.Config) {
            $a.colorScheme=Effective 'colorScheme' $a.colorScheme
            if ($a.colorScheme -isnot [string]) {throw (NexL 'Light/dark scheme pairs are not supported by export.')}
            $scheme=$s.Config.Obj.schemes | Where-Object name -eq $a.colorScheme | Select-Object -First 1
            foreach ($k in @('background','foreground','cursorColor','selectionBackground')) {if ($scheme -and $scheme.$k) {$a[$k]=$scheme.$k}}
            foreach ($k in @('background','foreground','cursorColor','selectionBackground','opacity','useAcrylic','cursorShape')) {$a[$k]=Effective $k $a[$k]}
            $p=$s.Config.Profile;$d=$s.Config.Obj.profiles.defaults
            foreach ($pair in @(@('fontFace','face'),@('fontSize','size'))) {
                $oldKey=$pair[0];$key=$pair[1]
                if ($p.font -and $p.font.PSObject.Properties[$key]) {$a[$oldKey]=$p.font.$key}
                elseif ($p.PSObject.Properties[$oldKey]) {$a[$oldKey]=$p.$oldKey}
                elseif ($d.font -and $d.font.PSObject.Properties[$key]) {$a[$oldKey]=$d.font.$key}
                elseif ($d -and $d.PSObject.Properties[$oldKey]) {$a[$oldKey]=$d.$oldKey}
            }
            if ($a.colorScheme -isnot [string]) {throw (NexL 'Light/dark scheme pairs are not supported by export.')}
            $scheme=$s.Config.Obj.schemes | Where-Object name -eq $a.colorScheme | Select-Object -First 1
            if ($scheme) {
                # Some Terminal schemes omit cursor/selection colors: use the effective color.
                foreach ($k in @('cursorColor','selectionBackground')) {if (-not $scheme.$k) {Set-NexObjectMember $scheme $k $a[$k]}}
            }
        }
        $a=Get-NexBackupAppearance ([pscustomobject]$a)
        $scheme=Get-NexBackupScheme $scheme
        $custom=$null;$omitted=$false
        $ff=Get-NexCustomFetchConfig
        if ($ff) {try {$custom=Get-NexPortableFetch ([IO.File]::ReadAllText($ff))} catch {$omitted=$true}}
        $pack=[ordered]@{Format='NEX-Portable-Configuration';Schema=1;Version='2.6.2';Preferences=(Get-NexBackupPreferences ([pscustomobject]$prefs));Appearance=$a;Scheme=$scheme;CustomFetch=$custom;CustomFetchOmitted=$omitted;HasTerminalAppearance=[bool]$s.Config}
        Write-NexBackupData $path (ConvertTo-Json -InputObject $pack -Depth 20)
        if ($omitted) {Notice 'Configuration exported. External Fastfetch assets/options were omitted.'}
        elseif (-not $s.Config) {Notice 'Configuration exported with default terminal appearance.'}
        else {Notice 'Configuration exported.'}
    }
    function RestorePublicConfig {
        $path=BackupFileDialog $false
        if (-not $path) {return}
        if ((Get-Item -LiteralPath $path -ErrorAction Stop).Length -gt 2097152) {throw (NexL 'Invalid configuration file.')}
        $pack=[IO.File]::ReadAllText($path) | ConvertFrom-Json -ErrorAction Stop
        if ($pack.Format -cne 'NEX-Portable-Configuration' -or $pack.Schema -ne 1) {throw (NexL 'Invalid configuration file.')}
        $newPrefs=Get-NexBackupPreferences $pack.Preferences
        $a=Get-NexBackupAppearance $pack.Appearance
        $scheme=Get-NexBackupScheme $pack.Scheme
        if ($scheme -and $scheme.name -cne $a.colorScheme) {throw 'Color scheme mismatch.'}
        $custom=$null
        if ($null -ne $pack.CustomFetch) {if ($pack.CustomFetch -isnot [string]) {throw 'Invalid Fastfetch configuration.'};$custom=Get-NexPortableFetch $pack.CustomFetch}
        if (-not (ConfirmNex 'Restore configuration?' ([IO.Path]::GetFileName($path)) 'Replace appearance; allow official dependency downloads?')) {return}
        $oldTls=[Net.ServicePointManager]::SecurityProtocol
        $work=Join-Path $env:TEMP ('NexRestore-'+[guid]::NewGuid().ToString('N'))
        $null=New-Item -ItemType Directory -Path $work -ErrorAction Stop
        $warnings=New-Object 'System.Collections.Generic.List[string]'
        PauseMouse
        try {
            Write-Host "$e[?25h$e[2J$e[H$pink$(NexL 'Restoring configuration...')$reset"
            [Net.ServicePointManager]::SecurityProtocol=$oldTls -bor [Net.SecurityProtocolType]::Tls12
            $hostInfo=Get-NexTerminalHost
            if (-not $hostInfo) {try {$hostInfo=Install-NexTerminal $work} catch {$warnings.Add((NexL 'Windows Terminal setup incomplete.'))}}
            if (($newPrefs.Icons -or $a.fontFace -eq 'JetBrainsMono Nerd Font Mono') -and -not (Test-NexNerdFont)) {
                try {if (-not (Install-NexFont $work)) {throw 'Font not registered.'}} catch {$warnings.Add((NexL 'Nerd Font could not be restored.'))}
            }
            if ($a.fontFace -ne 'JetBrainsMono Nerd Font Mono' -and -not (Get-NexBackupFontAvailable $a.fontFace)) {$warnings.Add((NexL 'Selected external font must be installed separately.'))}
            if ($newPrefs.FetchPreset -like 'Fastfetch*' -and -not (Get-NexFastfetch)) {
                try {$null=Install-NexFastfetch} catch {$warnings.Add((NexL 'Fastfetch could not be restored.'))}
            }
            # If settings.json was removed, recreate the NEX profile using the existing setup routine.
            if ($hostInfo -and -not (Test-Path -LiteralPath $hostInfo.Settings -PathType Leaf)) {
                try {$null=Install-NexTerminalProfile $hostInfo ([bool](Test-NexNerdFont))} catch {$warnings.Add((NexL 'Windows Terminal setup incomplete.'))}
            }
            try {
                if (-not $scheme -and $a.colorScheme -notin @('Campbell','Campbell Powershell','Vintage','One Half Dark','One Half Light','Solarized Dark','Solarized Light','Tango Dark','Tango Light')) {
                    $warnings.Add((NexL 'Color scheme definition not included.'))
                }
                $extraPath=if ($hostInfo) {$hostInfo.Settings} else {''}
                $null=Sync-NexTerminalAppearance $a $scheme $extraPath
            } catch {$warnings.Add((NexL 'Terminal appearance not fully restored.'))}
            $oldPrefs=@{};foreach ($k in $prefs.Keys) {$oldPrefs[$k]=$prefs[$k]}
            try {
                foreach ($k in $newPrefs.Keys) {$prefs[$k]=$newPrefs[$k]}
                $global:NexPublicSettings=$prefs
                Save-NexPreferences
            } catch {foreach ($k in $oldPrefs.Keys) {$prefs[$k]=$oldPrefs[$k]};$global:NexPublicSettings=$prefs;throw}
            if ($custom) {
                try {
                    $managed=Join-Path $env:LOCALAPPDATA 'NexDashboard\restored-fastfetch.json'
                    Write-NexBackupData $managed $custom
                } catch {$warnings.Add((NexL 'Custom Fastfetch configuration not restored.'))}
            } elseif ($pack.CustomFetchOmitted) {$warnings.Add((NexL 'External Fastfetch assets/options were omitted.'))}
            else {
                $managed=Join-Path $env:LOCALAPPDATA 'NexDashboard\restored-fastfetch.json'
                if (Test-Path -LiteralPath $managed -PathType Leaf) {Remove-Item -LiteralPath $managed -Force -ErrorAction SilentlyContinue}
            }
            $fetchState.Available=[bool](Get-NexFastfetch)
            try {Set-PSReadLineOption -PredictionSource $prefs.Prediction -ErrorAction Stop} catch {}
            ReadConfig
            if ($warnings.Count) {Notice ('{0} {1}' -f (NexL 'Configuration partially restored.'),($warnings -join ' '))}
            else {Notice 'Configuration restored. Reopen terminal tabs.'}
        } finally {
            [Net.ServicePointManager]::SecurityProtocol=$oldTls
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
            ResumeMouse;Write-Host "$e[?25l" -NoNewline;ResetDraw
        }
    }

    function PublicAction($key) {
        $changed=$true
        switch ($key) {
            'G' {$v=ChooseNexToggle 'Setting explanations' ([bool]$prefs.SettingHelp) $global:NexPersonalHelp['G'];if ($null -ne $v) {$prefs.SettingHelp=$v} else {$changed=$false}}
            'A' {$v=ChooseNexToggle 'Sidebar separators' ([bool]$prefs.SidebarSeparators) $global:NexPersonalHelp['A'];if ($null -ne $v) {$prefs.SidebarSeparators=$v;$s.NavOffset=0} else {$changed=$false}}
            'L' {$v=Ask 'Choose language' @('English','Русский','Deutsch') @('en','ru','de');if ($v -in @('en','ru','de')) {$prefs.Language=$v} else {$changed=$false}}
            'N' {$v=Ask 'Enter display name' @((NexL 'Use Windows account name')) @('__default__');if ($v -eq '__default__') {$prefs.Name=''} elseif ($v) {$prefs.Name=(SafeText $v).Trim();if ($prefs.Name.Length -gt 32) {$prefs.Name=$prefs.Name.Substring(0,32)}} else {$changed=$false}}
            'H' {$choices=@(Get-NexThemeNames);$v=Ask 'Choose theme' $choices $choices $prefs.Theme;if ($v -in $choices) {$prefs.Theme=$v} else {$changed=$false}}
            'X' {$v=Ask 'RGB HEX (#RRGGBB)';if ($v -match '^#?([0-9A-Fa-f]{6})$') {$prefs.Accent=$Matches[1];$prefs.Theme='Custom'} else {$changed=$false}}
            'B' {$v=ChooseNexToggle 'Startup screen' ([bool]$prefs.Startup) $global:NexPersonalHelp['B'];if ($null -ne $v) {$prefs.Startup=$v} else {$changed=$false}}
            'C' {$v=ChooseNexToggle 'Clear screen on return' ([bool]$prefs.ClearOnReturn) $global:NexPersonalHelp['C'];if ($null -ne $v) {$prefs.ClearOnReturn=$v} else {$changed=$false}}
            'U' {$v=ChooseNexToggle 'Loading on return' ([bool]$prefs.LoadingOnReturn) $global:NexPersonalHelp['U'];if ($null -ne $v) {$prefs.LoadingOnReturn=$v} else {$changed=$false}}
            'F' {$v=ChooseNexToggle 'Startup info' ([bool]$prefs.Fetch) $global:NexPersonalHelp['F'];if ($null -ne $v) {$prefs.Fetch=$v} else {$changed=$false}}
            'J' {$v=ChooseNexToggle 'Fetch animation' ([bool]$prefs.FetchAnimation) $global:NexPersonalHelp['J'];if ($null -ne $v) {$prefs.FetchAnimation=$v} else {$changed=$false}}
            'K' {$changed=$false;if (NexActionHelp 'Custom logo' $global:NexPersonalHelp['K']) {EditText -LogoMode}}
            'S' {$changed=$false;if (NexActionHelp 'Export configuration' $global:NexPersonalHelp['S']) {ExportPublicConfig}}
            'R' {$changed=$false;if (NexActionHelp 'Restore configuration' $global:NexPersonalHelp['R']) {RestorePublicConfig}}
            'V' {
                $choices=@('Cards','Compact','Minimal','Neon Frame','Color Labels','Tree Layout','Studio','Fastfetch classic','Fastfetch custom')
                $v=Ask 'Choose fetch preset' $choices $choices $prefs.FetchPreset
                if ($v -in $choices) {
                    if ($v -like 'Fastfetch*' -and -not (Get-NexFastfetch)) {
                        $action=Ask 'Install official Fastfetch now?' @('Install Fastfetch','Use built-in fallback') @('install','fallback') 'install'
                        if (-not $action) {$changed=$false;break}
                        if ($action -eq 'install') {
                            PauseMouse
                            try {Write-Host "$e[?25h$e[2J$e[H" -NoNewline;$null=Install-NexFastfetch;$fetchState.Available=$true}
                            catch {Notice $_.Exception.Message;$changed=$false}
                            finally {ResumeMouse;Write-Host "$e[?25l" -NoNewline;ResetDraw}
                            if (-not $changed) {break}
                        }
                    }
                    $prefs.FetchPreset=$v
                } else {$changed=$false}
            }
            'P' {$choices=@(Get-NexPromptStyles);$v=ChooseNexPromptStyle;if ($v -in $choices) {$prefs.Prompt=$v} else {$changed=$false}}
            'M' {$v=ChooseNexToggle 'Show computer name' ([bool]$prefs.ShowComputerName) $global:NexPersonalHelp['M'];if ($null -ne $v) {$prefs.ShowComputerName=$v} else {$changed=$false}}
            'D' {
                $v=Ask 'Enter computer alias' @((NexL 'Use Windows computer name')) @('__default__')
                if ($v -eq '__default__') {$prefs.ComputerAlias=''}
                elseif ($v) {$alias=Normalize-NexIdentityPart ($v.TrimStart('@'));if ($alias) {$prefs.ComputerAlias=$alias} else {$changed=$false}}
                else {$changed=$false}
            }
            'I' {$v=ChooseNexToggle 'Icons' ([bool]$prefs.Icons) $global:NexPersonalHelp['I'];if ($null -ne $v) {$prefs.Icons=$v} else {$changed=$false}}
            'O' {
                $changed=$false
                if (-not (NexActionHelp 'Restore icons and font' $global:NexPersonalHelp['O'])) {break};if (-not (ConfirmNex (NexL 'Restore Nerd Font in all terminal profiles?'))) {break}
                $work=Join-Path $env:TEMP ('NexIcons-'+[guid]::NewGuid().ToString('N'))
                $oldTls=[Net.ServicePointManager]::SecurityProtocol
                PauseMouse
                try {
                    Write-Host "$e[?25h$e[2J$e[H" -NoNewline
                    $null=New-Item -ItemType Directory -Path $work -Force
                    [Net.ServicePointManager]::SecurityProtocol=$oldTls -bor [Net.SecurityProtocolType]::Tls12
                    if (-not (Install-NexFont $work)) {throw 'Nerd Font not available after setup.'}
                    $null=Sync-NexTerminalAppearance @{fontFace='JetBrainsMono Nerd Font Mono'}
                    $prefs.Icons=$true;Save-NexPreferences
                    ReadConfig;Notice 'Icons restored. Reopen terminal tabs.'
                } catch {Notice $_.Exception.Message}
                finally {
                    [Net.ServicePointManager]::SecurityProtocol=$oldTls
                    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
                    ResumeMouse;Write-Host "$e[?25l" -NoNewline;ResetDraw
                }
            }
            'Q' {$v=Ask 'Prediction' @('History','None') @('History','None') $prefs.Prediction $global:NexPersonalHelp['Q'];if ($v -in @('History','None')) {$prefs.Prediction=$v;try {Set-PSReadLineOption -PredictionSource $prefs.Prediction -ErrorAction Stop} catch {}} else {$changed=$false}}
            'T' {$changed=$false;SettingsAction 'T'}
            'Y' {
                $changed=$false;if (-not (NexActionHelp 'Apply terminal palette' $global:NexPersonalHelp['Y'])) {break}
                try {$count=Apply-NexSharedTheme;ReadConfig;Notice "Theme applied to all profiles ($count)."} catch {Notice $_.Exception.Message}
            }
            'Z' {
                $changed=$false
                if (-not $s.Config) {SelectTerminalProfile}
                if ($s.Config) {
                    $prop=Ask 'Choose terminal color' @('Background','Foreground','Cursor color','Selection color') @('background','foreground','cursorColor','selectionBackground') $null $global:NexPersonalHelp['Z']
                    if ($prop -in @('background','foreground','cursorColor','selectionBackground')) {
                        $hex=Ask 'RGB HEX (#RRGGBB)'
                        if ($hex -match '^#?([0-9A-Fa-f]{6})$') {SetTerminalProperty $prop ('#'+$Matches[1])}
                    }
                }
            }
            'E' {
                $changed=$false;if (-not (NexActionHelp 'Preview fetch' $global:NexPersonalHelp['E'])) {break};PauseMouse
                try {Write-Host "$e[?25h$e[2J$e[H" -NoNewline;Show-NexPublicFetch;Write-Host "`nEsc / Enter"; $null=[Console]::ReadKey($true)} finally {ResumeMouse;Write-Host "$e[?25l" -NoNewline;ResetDraw}
            }
            default {$changed=$false}
        }
        if ($changed) {
            Save-NexPreferences;Notice 'Preferences saved.'
            if ($key -eq 'V') {Notice 'New shells use the saved preset.'}
            if ($key -in @('H','X')) {
                try {$count=Apply-NexSharedTheme;ReadConfig;Notice "Theme applied to all profiles ($count)."} catch {Notice ('Dashboard theme saved. Terminal: '+$_.Exception.Message)}
            }
            ResetDraw
        }
    }
    $overviewScript = {
        param($full)
        $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cpu=Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'" -ErrorAction Stop
        $gpuLoad=$null; $cpuName=''; $cores=$null; $threads=$null; $cpuClock=$null
        $gpuNames=@(); $disks=@(); $nvidia=@(); $netCounters=@(); $processCount=$null
        function ReadNumber($v) {
            $n=0.0
            if ([double]::TryParse(([string]$v).Trim(),[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$n) -and -not [double]::IsNaN($n) -and -not [double]::IsInfinity($n)) {return $n}
            return $null
        }
        if ($full) {
            try {
                $engines=Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop
                $loads=@($engines | Group-Object {$_.Name -replace '^pid_\d+_',''} | ForEach-Object {($_.Group | Measure-Object UtilizationPercentage -Sum).Sum})
                if ($loads.Count) {$gpuLoad=[Math]::Max(0,[Math]::Min(100,[double](($loads | Measure-Object -Maximum).Maximum)))}
            } catch {}
            try {
                $cpus=@(Get-CimInstance Win32_Processor -ErrorAction Stop)
                $cpuName=($cpus | Select-Object -First 1).Name
                $cores=($cpus | Measure-Object NumberOfCores -Sum).Sum
                $threads=($cpus | Measure-Object NumberOfLogicalProcessors -Sum).Sum
                $cpuClock=($cpus | Measure-Object CurrentClockSpeed -Maximum).Maximum
            } catch {}
            $gpuNames=@(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object {$_.Name})
            $disks=@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | Sort-Object DeviceID)
            $processCount=@(Get-Process -ErrorAction SilentlyContinue).Count
            try {
                $exe=Get-Command nvidia-smi.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($exe) {
                    $raw=@(& $exe.Source '--query-gpu=name,temperature.gpu,power.draw,clocks.gr,fan.speed,memory.used,memory.total,utilization.gpu' '--format=csv,noheader,nounits' 2>$null)
                    foreach ($line in $raw) {
                        $f=([string]$line) -split ',\s*'
                        if ($f.Count -eq 8) {
                            $nvidia+=[pscustomobject]@{Name=$f[0].Trim();Temp=(ReadNumber $f[1]);Power=(ReadNumber $f[2]);Clock=(ReadNumber $f[3]);Fan=(ReadNumber $f[4]);Used=(ReadNumber $f[5]);Total=(ReadNumber $f[6]);Load=(ReadNumber $f[7])}
                        }
                    }
                }
            } catch {}
            try {
                foreach ($a in @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -eq 'Up')) {
                    $stat=Get-NetAdapterStatistics -Name $a.Name -ErrorAction SilentlyContinue
                    if ($stat) {$netCounters+=[pscustomobject]@{Name=$a.Name;Rx=$stat.ReceivedBytes;Tx=$stat.SentBytes;At=[Diagnostics.Stopwatch]::GetTimestamp()}}
                }
            } catch {}
        }
        [pscustomobject]@{CPU=[Math]::Max(0,[Math]::Min(100,[double]$cpu.PercentProcessorTime));Nvidia=$nvidia;GPU=$gpuLoad;CpuName=$cpuName;Cores=$cores;Threads=$threads;CpuClock=$cpuClock;GpuNames=$gpuNames;Disks=$disks;NetCounters=$netCounters;ProcessCount=$processCount;RAM=100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize);Used=($os.TotalVisibleMemorySize-$os.FreePhysicalMemory)/1MB;Total=$os.TotalVisibleMemorySize/1MB;Boot=$os.LastBootUpTime}
    }
    function MonitorValue($value,[string]$format,[string]$unit) {
        if ($null -eq $value) { return '—' }
        return (($format -f $value)+$unit)
    }
    function MonitorRow([string]$label,[double]$value,[int]$inner,[string]$base=$palette[0]) {
        $n=[Math]::Max(5,[Math]::Min(24,$inner-16))
        return "$white$(Fit $label 7)$(Bar $value $n $base) $(LoadText $value $base)$('{0,6:0.0}%' -f $value)$reset"
    }
    function MonitorField([string]$label,$value,[int]$inner) {
        $value=SafeText $value
        $l=[Math]::Min(18,[Math]::Max(8,$inner-$value.Length-1))
        return "$gray$(Fit (NexL $label) $l) $white$value$reset"
    }
    function MonitorHistory($values,[string]$base,[int]$inner) {
        $str=''; $chars='▁▂▃▄▅▆▇█';$n=[Math]::Min(24,$inner)
        foreach ($v in @($values | Select-Object -Last $n)) {
            $i=[int][Math]::Max(0,[Math]::Min(7,[Math]::Floor([double]$v*7/100.0)))
            $str+="$(LoadText $v $base)$($chars[$i])"
        }
        return "$str$reset"
    }
    function MonitorCard($title,$content,[int]$width,[int]$height,[string]$color) {
        $inner=$width-2; $t=' '+(SafeText $title)+' '
        $t=(Fit $t ([Math]::Min($inner,$t.Length))).TrimEnd()+' '
        if ($t.Length -gt $inner) {$t=Fit $t $inner}
        $l=[int][Math]::Floor(($inner-$t.Length)/2); $r=$inner-$t.Length-$l
        "$color╭$('─'*$l)$t$('─'*$r)╮$reset"
        for ($i=0;$i -lt $height;$i++) {
            $line=if ($i -lt $content.Count) {ClipAnsi ([string]$content[$i]) ($inner-2)} else {''}
            $plain=$line -replace '\x1b\[[0-9;]*m',''
            $len=([Globalization.StringInfo]::new($plain)).LengthInTextElements
            $padding=[Math]::Max(0,$inner-1-$len)
            "$color│$reset $line$(' '*$padding)$color│$reset"
        }
        "$color╰$('─'*$inner)╯$reset"
    }
    function MonitorLayout($d,[int]$width) {
        $two=($width -ge 76 -and $prefs.MonitorColumns -ne 'Single column'); $cardWidth=if ($two) {[Math]::Min(60,[int][Math]::Floor(($width-3)/2.0))} else {[Math]::Min(70,$width-1)}
        $inner=$cardWidth-4; $gap='   '
        $cpuUi=SmoothNumber 'monitor-cpu' $d.CPU 0.25
        $ramUi=SmoothNumber 'monitor-ram' $d.RAM 0.25
        $gpuUi=$null; $gpuSource='GPU load: max of all adapters'
        $nv=$null; if (@($d.Nvidia).Count) {$nv=@($d.Nvidia)[0]}
        if ($null -ne $d.GPU) {$gpuUi=SmoothNumber 'monitor-gpu' $d.GPU 0.25}
        elseif ($nv -and $null -ne $nv.Load) {$gpuUi=SmoothNumber 'monitor-gpu-nv' $nv.Load 0.25; $gpuSource='GPU load: NVIDIA sensor'}
        $cpuRows=@(
            "$(NexAnsi (Get-NexVendorColor $d.CpuName $palette[4]))$(Fit $d.CpuName $inner)$reset"
            (MonitorRow 'CPU' $cpuUi $inner $palette[0])
            (MonitorHistory $s.MonitorHistoryCPU $palette[0] $inner)
            (MonitorField 'Cores / threads' ("$($d.Cores) / $($d.Threads)") $inner)
            (MonitorField 'Reported clock' (MonitorValue $d.CpuClock '{0:0}' ' MHz') $inner)
        )
        $gpuRows=@()
        foreach ($name in @($d.GpuNames)) {$gpuRows+="$(NexAnsi (Get-NexVendorColor $name $palette[4]))$(Fit $name $inner)$reset"}
        if (-not $gpuRows.Count) {$gpuRows+= "$gray$(NexL 'Not detected')$reset"}
        if ($null -ne $gpuUi) {
            $gpuRows+=MonitorRow 'GPU' $gpuUi $inner $palette[0]
            if ($null -ne $d.GPU) {$gpuRows+=MonitorHistory $s.MonitorHistoryGPU $palette[0] $inner}
            $gpuRows+="$gray$(NexL $gpuSource)$reset"
        } else {$gpuRows+="$gray$(NexL 'No GPU counter')$reset"}
        if ($nv) {
            if (@($d.GpuNames).Count -ne 1 -or @($d.Nvidia).Count -ne 1) {$gpuRows+="$(NexAnsi (Get-NexVendorColor $nv.Name $palette[4]))$(NexL 'NVIDIA sensors'): $(SafeText $nv.Name)$reset"}
            if ($inner -ge 43) {
                $gpuRows+="$gray$(NexL 'Temp.') $white$(MonitorValue $nv.Temp '{0:0.0}' ' °C')  $gray$(NexL 'Power') $white$(MonitorValue $nv.Power '{0:0.0}' ' W')$reset"
                $gpuRows+="$gray$(NexL 'Clock') $white$(MonitorValue $nv.Clock '{0:0}' ' MHz')  $gray$(NexL 'Fans') $white$(MonitorValue $nv.Fan '{0:0}' ' %')$reset"
            } else {
                $gpuRows+=MonitorField 'Temperature' (MonitorValue $nv.Temp '{0:0.0}' ' °C') $inner
                $gpuRows+=MonitorField 'Power' (MonitorValue $nv.Power '{0:0.0}' ' W') $inner
                $gpuRows+=MonitorField 'Clock' (MonitorValue $nv.Clock '{0:0}' ' MHz') $inner
                $gpuRows+=MonitorField 'Fans' (MonitorValue $nv.Fan '{0:0}' ' %') $inner
            }
        } else {$gpuRows+="$gray$(NexL 'GPU telemetry unavailable')$reset"}
        $memRows=@(
            (MonitorRow 'RAM' $ramUi $inner $palette[0])
            (MonitorField 'Memory' ('{0:0.0} / {1:0.0} GiB' -f $d.Used,$d.Total) $inner)
        )
        if ($nv -and $null -ne $nv.Used -and $nv.Total -gt 0) {
            $vr=SmoothNumber 'monitor-vram' (100.0*$nv.Used/$nv.Total) 0.25
            $memRows+=MonitorRow 'VRAM' $vr $inner $palette[0]
            $memRows+=MonitorField 'VRAM' ('{0:0} / {1:0} MiB' -f $nv.Used,$nv.Total) $inner
        } else {$memRows+="$gray$(NexL 'No dedicated VRAM sensor')$reset"}
        $diskRows=@()
        foreach ($drive in @($d.Disks)) {
            if ($drive.Size -gt 0) {
                $v=100.0*(1.0-$drive.FreeSpace/$drive.Size)
                $diskRows+=MonitorRow ([string]$drive.DeviceID) $v $inner $palette[0]
                $diskRows+=MonitorField 'Free' ('{0:0.0} / {1:0.0} GiB' -f ($drive.FreeSpace/1GB),($drive.Size/1GB)) $inner
            }
        }
        if (-not $diskRows.Count) {$diskRows+="$gray$(NexL 'No storage data')$reset"}
        $dn=$null;$up=$null
        if ($null -ne $s.MonitorDown) {$dn=SmoothNumber 'monitor-down' $s.MonitorDown 0.25}
        if ($null -ne $s.MonitorUp) {$up=SmoothNumber 'monitor-up' $s.MonitorUp 0.25}
        $netRows=@(
            (MonitorField 'Download' (MonitorValue $dn '{0:0.00}' ' Mbps') $inner)
            (MonitorField 'Upload' (MonitorValue $up '{0:0.00}' ' Mbps') $inner)
            "$gray$(NexL 'Physical adapters')$reset"
        )
        $sysRows=@(
            (MonitorField 'Processes' (MonitorValue $d.ProcessCount '{0:0}' '') $inner)
            (MonitorField 'Uptime' (((Get-Date)-$d.Boot).ToString('dd\.hh\:mm\:ss')) $inner)
            (MonitorField 'Time' (Get-Date -Format 'HH:mm:ss') $inner)
        )
        $cards=@(
            @{Id='Processor';Title="$(Icon 0xF2DB) $(NexL 'Processor')";Rows=$cpuRows;Color=$pink},
            @{Id='Graphics';Title="$(Icon 0xF108) $(NexL 'Graphics')";Rows=$gpuRows;Color=$purple},
            @{Id='Memory';Title="$(Icon 0xEFC5) $(NexL 'Memory')";Rows=$memRows;Color=(NexAnsi $palette[1])},
            @{Id='Storage';Title="$(Icon 0xF0A0) $(NexL 'Storage')";Rows=$diskRows;Color=$pink},
            @{Id='Network';Title="$(Icon 0xF1EB) $(NexL 'Network')";Rows=$netRows;Color=$purple},
            @{Id='System';Title="$(Icon 0xF013) $(NexL 'System')";Rows=$sysRows;Color=(NexAnsi $palette[1])}
        )
        $ordered=@();foreach ($id in ($prefs.MonitorOrder -split ',')) {if ($id -notin ($prefs.MonitorHidden -split ',')) {$ordered+=@($cards | Where-Object {$_.Id -eq $id})}}
        if ($ordered.Count) {$cards=$ordered}
        $pad=' '*[Math]::Max(0,[int][Math]::Floor(($width-$(if ($two) {2*$cardWidth+3} else {$cardWidth}))/2.0))
        if ($two) {
            for ($i=0;$i -lt $cards.Count;$i+=2) {
                $a=$cards[$i]
                if ($i+1 -ge $cards.Count) {foreach ($line in @(MonitorCard $a.Title $a.Rows $cardWidth $a.Rows.Count $a.Color)) {"$pad$line"};break}
                $b=$cards[$i+1];$height=[Math]::Max($a.Rows.Count,$b.Rows.Count)
                $left=@(MonitorCard $a.Title $a.Rows $cardWidth $height $a.Color)
                $right=@(MonitorCard $b.Title $b.Rows $cardWidth $height $b.Color)
                for ($j=0;$j -lt $left.Count;$j++) {"$pad$($left[$j])$gap$($right[$j])"}
                if ($i+2 -lt $cards.Count) {''}
            }
        } else {
            foreach ($a in $cards) {
                foreach ($line in @(MonitorCard $a.Title $a.Rows $cardWidth $a.Rows.Count $a.Color)) {"$pad$line"}
                ''
            }
        }
    }
    function Buttons($buttons,[int]$width) {
        $count=$buttons.Count
        if ($count -lt 1) { return @{Text='';Kind='buttons';Targets=@()} }
        $cell=[Math]::Max(1,[int][Math]::Floor($width/$count))
        $line=''; $targets=@()
        for ($j=0;$j -lt $count;$j++) {
            $btn=$buttons[$j]
            $labelText=NexL $btn.Label
            $buttonIcons=@{tool=@{D=0xF0A0;N=0xF1EB;S=0xF013;I=0xF0AC;E=0xF15C;T=0xF080;G=0xF044};fileAction=@{N=0xF15B;M=0xF07B;E=0xF044;Delete=0xF1F8;D=0xF0A0;P=0xF07C;F=0xF002;Backspace=0xF060;C=0xF0C5;X=0xF0C4;V=0xF0EA;F2=0xF044;Spacebar=0xF06E;F3=0xF05A;F4=0xF0DC;H=0xF070}}
            if ($prefs.Icons -and $buttonIcons.ContainsKey($btn.Kind) -and $buttonIcons[$btn.Kind].ContainsKey([string]$btn.Key) -and $cell -ge 19) {
                $symbol=Icon ([int]$buttonIcons[$btn.Kind][([string]$btn.Key)])
                if ($labelText -match '^(\[[^\]]+\])\s*(.*)$') {$labelText=$Matches[1]+' '+$symbol+' '+$Matches[2]}
            }
            $label=(Fit $labelText ([Math]::Max(1,$cell-2))).TrimEnd()
            $enabled=(-not $btn.ContainsKey('Enabled') -or $btn.Enabled)
            $style=if ($enabled) { $pink } else { $muted }
            if ($enabled -and $label -match '^(\[[^\]]+\])\s*(.*)$') {
                $line+="$purple$($Matches[1])"
                if ($Matches[2].Length -gt 0) { $line+="$white $($Matches[2])" }; $line+=$reset
            } else { $line+="$style$label$reset" }
            $length=$label.Length
            $line+=(' '*[Math]::Max(0,$cell-$length))
            if ($enabled) {
                $targets+=@{Kind=$btn.Kind;Index=$btn.Key;From=$j*$cell;To=$j*$cell+$length}
            }
        }
        @{Text=$line;Kind='buttons';Targets=$targets}
    }
    function WrapUpdateLine([string]$text,[int]$width) {
        $width=[Math]::Max(12,$width)
        $text=SafeText $text
        if (-not $text.Length) { return '' }
        while ($text.Length -gt $width) {
            $cut=$text.LastIndexOf(' ',$width)
            if ($cut -lt 4) { $cut=$width }
            $text.Substring(0,$cut).TrimEnd()
            $text=$text.Substring($cut).TrimStart()
        }
        $text
    }

    # Extra pages use read-only background queries; power plan changes require consent.
    $startupScript={
        Get-CimInstance Win32_StartupCommand -ErrorAction Stop | Sort-Object Name,Location | ForEach-Object {
            [pscustomobject]@{Name=[string]$_.Name;Location=[string]$_.Location;Command=[string]$_.Command}
        }
    }
    $hardwareScript={
        function AddHardwareField($group,$label,$value) {if ($null -ne $value -and [string]$value -ne '') {[pscustomobject]@{Group=$group;Label=$label;Value=[string]$value}}}
        foreach ($c in @(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue)) {
            AddHardwareField 'Processor' 'Model' $c.Name; AddHardwareField 'Processor' 'Cores / threads' "$($c.NumberOfCores) / $($c.NumberOfLogicalProcessors)"; AddHardwareField 'Processor' 'Maximum clock' "$($c.MaxClockSpeed) MHz"; AddHardwareField 'Processor' 'Socket' $c.SocketDesignation
        }
        foreach ($g in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) { AddHardwareField 'Graphics' 'Model' $g.Name; AddHardwareField 'Graphics' 'Driver' $g.DriverVersion; if ($g.CurrentHorizontalResolution) {AddHardwareField 'Graphics' 'Resolution' "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution)"} }
        # Win32_VideoController.AdapterRAM is 32-bit and cannot reliably represent modern VRAM.
        $nv=Get-Command nvidia-smi.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($nv) {foreach ($line in @(& $nv.Source '--query-gpu=name,memory.total' '--format=csv,noheader' 2>$null)) {AddHardwareField 'Graphics' 'VRAM (NVIDIA)' $line}}
        foreach ($m in @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)) {AddHardwareField 'Memory' 'Module' (('{0} / {1:N1} GiB / {2} MT/s / {3}' -f $m.DeviceLocator,($m.Capacity/1GB),$m.ConfiguredClockSpeed,$m.PartNumber).Trim())}
        foreach ($b in @(Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue)) {AddHardwareField 'Motherboard' 'Model' "$($b.Manufacturer) $($b.Product)"}
        foreach ($b in @(Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue)) {AddHardwareField 'Motherboard' 'BIOS' $b.SMBIOSBIOSVersion}
        foreach ($d in @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)) {AddHardwareField 'Storage' 'Disk' ('{0} / {1:N1} GiB' -f $d.Model,($d.Size/1GB))}
        foreach ($n in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)) {AddHardwareField 'Network' 'Adapter' "$($n.InterfaceDescription) / $($n.LinkSpeed)"}
        foreach ($o in @(Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue)) {AddHardwareField 'System' 'Windows' "$($o.Caption) / $($o.BuildNumber)";AddHardwareField 'System' 'Architecture' $o.OSArchitecture}
    }
    $gamingScript={
        $cpu=Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        $name=[string]$cpu.Name; $vendor=[string]$cpu.Manufacturer
        $plans=@(); $active=''; $balanced='381b4222-f694-41f0-9685-ff5bb260df2e'
        foreach ($line in @(powercfg.exe /list 2>$null)) {
            if ($line -match '([0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})\s+\((.*)\)\s*(\*)?\s*$') {
                $id=$Matches[1];$pn=$Matches[2];$isActive=$Matches.ContainsKey(3) -and $Matches[3] -eq '*'
                if ($isActive) {$active=$id};$plans+= [pscustomobject]@{Id=$id;Name=$pn;Active=$isActive}
            }
        }
        # Verify the actual active scheme independently of localized list output.
        $activeOutput=@(powercfg.exe /getactivescheme 2>$null)
        if ($LASTEXITCODE -eq 0) {
            $match=[regex]::Match(($activeOutput -join ' '),'(?i)\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b')
            if ($match.Success) {$active=$match.Value}
        }
        foreach ($plan in $plans) {$plan.Active=($plan.Id -eq $active)}
        $recommend=@($plans | Where-Object Id -eq $balanced | Select-Object -First 1)
        # Older Ryzen systems can have AMD's own Balanced plan; do not prefer it on modern X3D.
        if ($vendor -match 'AMD' -and $name -match 'Ryzen.*\b[123]\d{3}[A-Z]*\b' -and $name -notmatch 'X3D') {
            $legacy=@($plans | Where-Object Name -match 'AMD.*Ryzen.*(Balanced|Сбаланс|Ausbalanc)' | Select-Object -First 1);if ($legacy.Count) {$recommend=$legacy}
        }
        $reason=if ($name -match 'X3D') {'X3D: Balanced supports normal chipset scheduling.'} elseif ($vendor -match 'AMD') {'AMD: Balanced is the preferred starting point.'} else {'Balanced is a safe default; High performance is optional.'}
        $mode=$null; $modeDefault=$false
        $gameBar=$null
        try {
            # Microsoft documents AutoGameModeEnabled as the Windows 11 setting.
            $gameBar=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\GameBar')
            $rawMode=if ($null -ne $gameBar) {$gameBar.GetValue('AutoGameModeEnabled',$null)} else {$null}
            if ($null -ne $rawMode) {
                if ($rawMode -in @(0,1)) {$mode=[int]$rawMode}
            } else {
                # With no explicit preference, Windows 11 client defaults to enabled.
                # Do not infer a default on an unknown OS or after a registry access error.
                $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
                if ($os.ProductType -eq 1 -and [int]$os.BuildNumber -ge 22000) {$mode=1;$modeDefault=$true}
            }
        } catch {} finally {if ($null -ne $gameBar) {$gameBar.Dispose()}}
        [pscustomobject]@{CPU=$name;Plans=$plans;Active=$active;Recommended=$(if ($recommend.Count) {$recommend[0]} else {$null});Reason=$reason;Mode=$mode;ModeDefault=$modeDefault}
    }
    $appsScript={Get-StartApps -ErrorAction Stop | Where-Object {$_.Name -and $_.AppID} | Sort-Object Name,AppID -Unique | ForEach-Object {[pscustomobject]@{Name=[string]$_.Name;Id=[string]$_.AppID}}}
    $healthScript={
        $disks=@();$vols=@();$events=@();$diskKnown=$false;$eventKnown=$false;$volumeKnown=$false;$defender=$null
        try {$disks=@(Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {[pscustomobject]@{Name=$_.FriendlyName;Health=[string]$_.HealthStatus;Status=(@($_.OperationalStatus) -join ', ')}});$diskKnown=$true} catch {}
        try {$vols=@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop | Where-Object {$_.Size -gt 0} | ForEach-Object {[pscustomobject]@{Name=$_.DeviceID;Free=[Math]::Round(100*[double]$_.FreeSpace/[double]$_.Size,1);GiB=[Math]::Round($_.FreeSpace/1GB,1)}});$volumeKnown=$true} catch {}
        try {$events=@(Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2;StartTime=(Get-Date).AddHours(-24)} -MaxEvents 30 -ErrorAction Stop | ForEach-Object {
            $ev=$_;$message='';try {$message=[string]$ev.Message} catch {}
            [pscustomobject]@{Id=$ev.Id;RecordId=$ev.RecordId;Source=$ev.ProviderName;Time=$ev.TimeCreated;Level=$ev.Level;Message=$message}
        });$eventKnown=$true} catch {if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {$eventKnown=$true}}
        try {$defender=Get-MpComputerStatus -ErrorAction Stop | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated} catch {}
        $reboot=$null;$servicing=$null;$updateInfo=$null
        try {
            $updateInfo=New-Object -ComObject Microsoft.Update.SystemInfo -ErrorAction Stop
            $reboot=[bool]$updateInfo.RebootRequired
        } catch {} finally {if ($null -ne $updateInfo) {try {$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($updateInfo)} catch {}}}
        try {$servicing=Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -ErrorAction Stop} catch {}
        [pscustomobject]@{Disks=$disks;Volumes=$vols;Events=$events;DiskKnown=$diskKnown;VolumeKnown=$volumeKnown;EventKnown=$eventKnown;Defender=$defender;Reboot=$reboot;Servicing=$servicing;At=Get-Date}
    }
    $releaseScript={
        $ErrorActionPreference='Stop'
        $repo='owoNEXowo/NEX-Dashboard'
        $oldTls=[Net.ServicePointManager]::SecurityProtocol
        try {
            [Net.ServicePointManager]::SecurityProtocol=$oldTls -bor [Net.SecurityProtocolType]::Tls12
            $headers=@{'User-Agent'='NEX-Dashboard';'Accept'='application/vnd.github+json';'X-GitHub-Api-Version'='2022-11-28'}
            $releases=Invoke-RestMethod -Uri ('https://api.github.com/repos/'+$repo+'/releases?per_page=100') -Headers $headers -TimeoutSec 15
            $candidates=@(foreach ($r in @($releases)) {
                if ($r.draft -or [string]$r.tag_name -notmatch '^v?(\d+\.\d+\.\d+)(?:-beta(?:[.-]\d+)?)?$') {continue}
                $v=[version]$Matches[1]
                [pscustomobject]@{Version=$v;Release=$r}
            })
            $latest=$candidates | Sort-Object -Property @{Expression='Version';Descending=$true}, @{Expression={$_.Release.prerelease};Descending=$false} | Select-Object -First 1
            if (-not $latest) {return [pscustomobject]@{Tag='';Newer=$false;Comparable=$false;Available=$false;Reason='No published releases found.';At=Get-Date}}
            $r=$latest.Release;$v=$latest.Version;$tag=[string]$r.tag_name
            $name='NexDashboard-'+$v.ToString()+'-Public.ps1'
            $asset=@($r.assets | Where-Object {$_.name -ceq $name -and $_.state -eq 'uploaded'})
            $url='https://github.com/'+$repo+'/releases/download/'+$tag+'/'+$name
            $valid=($asset.Count -eq 1 -and $asset[0].browser_download_url -ceq $url -and [long]$asset[0].size -gt 0 -and [long]$asset[0].size -le 20MB -and [string]$asset[0].digest -match '^sha256:[0-9a-fA-F]{64}$')
            $hash=if ($valid) {([string]$asset[0].digest).Substring(7)} else {''}
            [pscustomobject]@{Tag=$tag;Version=$v.ToString();Newer=($v -gt [version]'2.6.2');Comparable=$true;Available=[bool]$valid;Url=$url;Hash=$hash;Size=$(if ($valid) {[long]$asset[0].size} else {0});Beta=[bool]$r.prerelease;Reason=$(if ($valid) {''} else {'Release installer or SHA-256 unavailable.'});At=Get-Date}
        } finally {[Net.ServicePointManager]::SecurityProtocol=$oldTls}
    }
    $onlineDownloadScript={
        param($a)
        $ErrorActionPreference='Stop'
        $oldTls=[Net.ServicePointManager]::SecurityProtocol
        try {
            [Net.ServicePointManager]::SecurityProtocol=$oldTls -bor [Net.SecurityProtocolType]::Tls12
            $version=[version]$a.Version
            if ($version -le [version]'2.6.2' -or $a.Tag -notmatch '^v?(\d+\.\d+\.\d+)(?:-beta(?:[.-]\d+)?)?$' -or [version]$Matches[1] -ne $version) {throw 'Invalid update version.'}
            $expected='https://github.com/owoNEXowo/NEX-Dashboard/releases/download/'+$a.Tag+'/NexDashboard-'+$version.ToString()+'-Public.ps1'
            if ($a.Url -cne $expected -or $a.Hash -notmatch '^[0-9a-fA-F]{64}$' -or [long]$a.Size -le 0 -or [long]$a.Size -gt 20MB) {throw 'Invalid update metadata.'}
            Invoke-WebRequest -UseBasicParsing -Uri $expected -Headers @{'User-Agent'='NEX-Dashboard'} -OutFile $a.Path -TimeoutSec 60 -MaximumRedirection 5
            if ((Get-Item -LiteralPath $a.Path).Length -ne [long]$a.Size -or (Get-FileHash -LiteralPath $a.Path -Algorithm SHA256).Hash -ne $a.Hash) {throw 'Update integrity check failed.'}
            $text=[IO.File]::ReadAllText($a.Path);$tokens=$null;$errors=$null
            $null=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
            if ($errors.Count -or $text -notmatch '# BEGIN NEX PUBLIC EDITION' -or $text -notmatch '\[switch\]\$Install' -or $text -notmatch 'NEX Dashboard (\d+\.\d+\.\d+) Public Edition installed\.' -or [version]$Matches[1] -ne $version) {throw 'Not a valid NEX installer.'}
            [pscustomobject]@{Path=$a.Path;Version=$version.ToString();Hash=$a.Hash}
        } finally {[Net.ServicePointManager]::SecurityProtocol=$oldTls}
    }
    function StartNexReleaseCheck([bool]$install) {
        if ($s.Job) {Notice 'Another query is running.';return}
        $s.OnlineReady=$false;$s.OnlineRequested=$install;$s.Release=$null;$s.ExtraErrors.Remove('release')
        StartWorker 'release' $releaseScript
        Notice 'Checking for releases...'
    }
    function StartNexOnlineDownload {
        $r=$s.Release
        if (-not $r -or -not $r.Comparable) {Notice 'No published releases found.';return}
        if (-not $r.Newer) {Notice 'No newer release found';return}
        if (-not $r.Available) {Notice 'Release installer or SHA-256 unavailable.';return}
        if ($s.Job) {Notice 'Another query is running.';return}
        $channel=if ($r.Beta) {'Public Beta'} else {'Release'}
        if (-not (ConfirmNex 'Install official update' ("NEX Dashboard "+$r.Tag+" / "+$channel) (NexL 'Download from the official GitHub repository?'))) {Notice 'Online update cancelled.';return}
        if ($s.OnlineTemp -and (Test-Path -LiteralPath $s.OnlineTemp)) {Remove-Item -LiteralPath $s.OnlineTemp -Force -ErrorAction SilentlyContinue}
        $s.OnlineTemp=Join-Path ([IO.Path]::GetTempPath()) ('NexDashboard-'+[guid]::NewGuid().ToString('N')+'.ps1')
        StartWorker 'release-download' $onlineDownloadScript @{Version=$r.Version;Tag=$r.Tag;Url=$r.Url;Hash=$r.Hash;Size=$r.Size;Path=$s.OnlineTemp}
        Notice 'Downloading and verifying update...'
    }
    function FilterNexHealthEvents {
        if ($s.Health -and $s.EventCutoff -gt 0) {
            $s.Health.Events=@($s.Health.Events | Where-Object {
                # Keep records with missing timestamps rather than silently hide them.
                $null -eq $_.Time -or ([datetime]$_.Time).ToUniversalTime().Ticks -gt $s.EventCutoff
            })
        }
    }
    function ClearNexHealthEvents {
        if (-not $s.Health -or -not $s.Health.EventKnown) {Notice 'Wait for a successful event check.';return $false}
        if (-not $s.Health.Events.Count) {Notice 'No recent system errors';return $false}
        if (-not (ConfirmNex 'Clear displayed events' (NexL 'Hide old events in both pages.') (NexL 'Windows event logs will be kept.'))) {return $false}
        $cutoff=[datetime]::UtcNow.Ticks
        try {
            [IO.Directory]::CreateDirectory((Split-Path -Parent $eventCheckpoint)) | Out-Null
            [IO.File]::WriteAllText($eventCheckpoint,$cutoff.ToString([Globalization.CultureInfo]::InvariantCulture),[Text.Encoding]::ASCII)
        } catch {Notice 'Could not save the event checkpoint.';return $false}
        $s.EventCutoff=$cutoff
        FilterNexHealthEvents
        UpdateNexAlerts
        $s.ExtraPos=0; $s.HealthNext=0L
        Notice 'Old events hidden. New events will appear automatically.'
        return $true
    }
    function UpdateNexAlerts {
        $a=New-Object 'System.Collections.Generic.List[object]'
        if ($s.Health) {
            foreach ($v in @($s.Health.Volumes)) {if ($v.Free -lt 10) {$a.Add(@{Id=('diskfree'+$v.Name);Level='Warning';Title='Low disk space';Detail=('{0} / {1}% / {2} GiB' -f $v.Name,$v.Free,$v.GiB)})}}
            foreach ($d in @($s.Health.Disks)) {if ($d.Health -and $d.Health -notin @('Healthy','Unknown')) {$a.Add(@{Id=('diskhealth'+$d.Name);Level='Warning';Title='Disk health warning';Detail=($d.Name+' / '+$d.Health)})}}
            if ($s.Health.Reboot -eq $true) {$a.Add(@{Id='reboot';Level='Info';Title='Windows Update requires restart';Detail=''})}
            elseif ($s.Health.Servicing -eq $true) {$a.Add(@{Id='servicing';Level='Info';Title='Restart marker detected';Detail=(NexL 'Servicing restart marker')})}
            if ($s.Health.EventKnown -and $s.Health.Events.Count -gt 0) {$a.Add(@{Id=('events:'+ $s.Health.Events[0].RecordId);Level='Info';Title='Recent system errors';Detail=[string]$s.Health.Events.Count})}
            if ($s.Health.Defender -and $s.Health.Defender.RealTimeProtectionEnabled -eq $false) {$a.Add(@{Id='defender';Level='Info';Title='Defender real-time protection is off';Detail=''})}
        }
        if ($s.AlertOverview) {
            if ($s.AlertOverview.RAM -ge 95) {$a.Add(@{Id='ram';Level='Warning';Title='High memory usage';Detail=('{0:0.0}%' -f $s.AlertOverview.RAM)})}
            foreach ($g in @($s.AlertGpu | Where-Object {$clock.ElapsedMilliseconds-$s.AlertGpuAt -lt 30000})) {if ($null -ne $g.Temp -and $g.Temp -ge 85) {$a.Add(@{Id=('gpu'+$g.Name);Level='Warning';Title='High GPU temperature';Detail=('{0} / {1} °C' -f $g.Name,$g.Temp)})}}
        }
        $active=@($a | ForEach-Object {$_.Id});foreach ($id in @($s.AlertDismiss.Keys)) {if ($id -notin $active) {$s.AlertDismiss.Remove($id)}}
        $s.Alerts=@($a | Where-Object {-not $s.AlertDismiss.ContainsKey($_.Id)});$s.Need=$true
    }
    function ShowNexHealthEvent($recordId) {
        if (-not $s.Health) {return}
        $ev=$s.Health.Events | Where-Object {[string]$_.RecordId -eq [string]$recordId} | Select-Object -First 1
        if (-not $ev) {Notice 'Event list changed. Refresh and try again.';return}
        $width=[Console]::WindowWidth
        if ($width -ge 88) {$width-=29} else {$width-=3}
        $width=[Math]::Max(12,$width-2)
        $severity=if ($ev.Level -eq 1) {NexL 'Critical'} else {NexL 'Error'}
        $message=if ([string]::IsNullOrWhiteSpace($ev.Message)) {NexL 'Windows did not provide an event description.'} else {$ev.Message}
        $lines=New-Object 'System.Collections.Generic.List[string]'
        foreach ($line in @(("$(NexL 'Time'): $($ev.Time)"),("$(NexL 'Source'): $($ev.Source)"),("$(NexL 'Event ID'): $($ev.Id)"),("$(NexL 'Severity'): $severity"),'',(NexL 'Description'), '') + @($message -split '\r?\n')) {
            foreach ($part in @(WrapUpdateLine $line $width)) {$lines.Add([string]$part)}
        }
        $s.Preview=@{Title="$(NexL 'Event ID') $($ev.Id) | $severity";Lines=@($lines.ToArray());Pos=0};$s.Need=$true
    }
    function SelectNexInstaller {
        if ($s.Job -and $s.JobKind -in @('release','release-download')) {Notice 'Another query is running.';return}
        PauseMouse;$dialog=$null;$path=$null
        try {Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop;$dialog=New-Object System.Windows.Forms.OpenFileDialog;$dialog.Filter='NEX installer (*.ps1)|*.ps1';$dialog.CheckFileExists=$true;$dialog.RestoreDirectory=$true;if ($dialog.ShowDialog() -eq 'OK') {$path=$dialog.FileName}} finally {if ($dialog) {$dialog.Dispose()};ResumeMouse;ResetDraw}
        if (-not $path) {return}
        if ((Get-Item -LiteralPath $path -ErrorAction Stop).Length -gt 20MB) {throw (NexL 'Not a valid NEX installer.')}
        $text=[IO.File]::ReadAllText($path);$tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
        if ($errors.Count -or $text -notmatch 'NEX Dashboard (\d+\.\d+\.\d+) Public Edition installed\.' -or $text -notmatch '# BEGIN NEX PUBLIC EDITION' -or $text -notmatch '\[switch\]\$Install') {throw (NexL 'Not a valid NEX installer.')}
        $null=$text -match 'NEX Dashboard (\d+\.\d+\.\d+) Public Edition installed\.';$ver=[version]$Matches[1]
        if ($ver -lt [version]'2.6.2') {Notice 'Select a newer installer.';return}
        if (ConfirmNex 'Install local update' ("NEX Dashboard $ver") (NexL 'Only run installers from a source you trust.')) {$s.PendingInstaller=$path;$s.PendingVersion=$ver}
    }
    function ShowNexReleaseDetails([string]$kind) {
        $width=[Console]::WindowWidth
        if ($width -ge 88) {$width-=29} else {$width-=3}
        $width=[Math]::Max(12,$width-2)
        $lines=New-Object 'System.Collections.Generic.List[string]'
        if ($kind -eq 'about') {
            $title=NexL 'About NEX Dashboard'
            $raw=@('NEX Dashboard 2.6.2',(NexL 'Public Edition'),'',(NexL 'A customizable PowerShell dashboard for monitoring, tools and terminal appearance.'),'',(NexL 'Supports English, Russian and German.'),(NexL 'Local updates keep your personal settings.'),'',(NexL 'Official releases are checked before installation.'),(NexL 'Local updates reload Dashboard in this terminal.'))
        } else {
            $title=NexL 'Version history'
            $raw=@((NexL 'Recent release notes'),'')
            $raw+=@('  2.6.1',(NexL 'Optional Ookla Speedtest installation and first-test consent.'),'')
            $raw+=@('  2.6.0',(NexL 'Monitor designer, startup manager, global search, optional modules, animation studio and setting explanations.'),'')
            $raw+=@('  2.5.0',(NexL 'Official online updates with SHA-256 verification and beta release support.'),'')
            $raw+=@('  2.4.9',(NexL 'Softer hardware colors, multicolor startup info and in-session updates.'),'')
            $raw+=@('  2.4.8',(NexL 'Original monochrome Nerd Font icons restored without emoji fallback.'),'')
            $raw+=@('  2.4.7',(NexL 'Vendor hardware colors and Nerd Font icon recovery.'),'')
            $raw+=@('  2.4.6',(NexL 'Reordered navigation; direct local update button; About and changelog.'),'')
            $raw+=@('  2.4.5',(NexL 'Persistent clearing of displayed system events without deleting Windows logs.'),'')
            $raw+=@('  2.4.4',(NexL 'Computer-name visibility and alias; more prompt styles with previews.'),'')
            $raw+=@('  2.4.3',(NexL 'Detailed system events and notification descriptions.'),'')
            $raw+=@('  2.4.2',(NexL 'Improved Windows Game Mode detection.'),'')
            $raw+=@('  2.4.1',(NexL 'Clickable power plans and verified status indicators.'),'')
            $raw+=@('  2.4.0',(NexL 'Hardware, Gaming, Apps, Updates, Health and Notifications pages.'),'')
            $raw+=@('  2.3.2',(NexL 'Improved transition back to the startup screen.'),'')
            $raw+=@('  2.3.1',(NexL 'Optional screen clearing and loading animation on return.'),'')
            $raw+=@('  2.3.0',(NexL 'Expanded color themes, load gradients and settings cleanup.'),'')
            $raw+=@('  2.2.9',(NexL 'Portable configuration export and restore.'),'')
            $raw+=@('  2.2.8',(NexL 'Custom ASCII and Unicode startup logo editor.'),'')
            $raw+=@('  2.2.7',(NexL 'Translation key compatibility fix for Windows PowerShell.'),'')
            $raw+=@('  2.2.6',(NexL 'Unified monitor cards and adaptive load colors.'),'')
            $raw+=@('  2.2.5',(NexL 'More localization, DNS controls, icons and Fastfetch animation.'),'')
        }
        foreach ($line in $raw) {foreach ($part in @(WrapUpdateLine $line $width)) {$lines.Add([string]$part)}}
        $s.Preview=@{Title=$title;Lines=@($lines.ToArray());Pos=0;ReleaseDetails=$true};$s.Need=$true
    }
    function SearchNexDashboard {
        $s.Preview=$null
        $labels=@();$ids=@()
        $english=@('Overview','System Monitor','Processes','Network','File Explorer','System Info','Windows Update','Quick Tools','System Logs','Terminal Settings','Personalization','Hardware Info','Gaming Mode','App Launcher','Update Center','System Health','Notification Center','Dashboard Designer','Startup Manager','Plugin Manager','Animation Studio')
        foreach ($id in $navOrder) {$label=$names[$id];if ($label -cne $english[$id]) {$label+=' / '+$english[$id]};$labels+=@($label);$ids+=@([string]$id)}
        $shortcuts=@(
            @('Choose theme',10),@('Choose fetch preset',10),@('Choose prompt style',10),@('Custom logo',10),@('Export',10),@('Restore',10),@('Choose power plan',12),@('Download and install update',14),@('Choose loading animation',20),@('Choose monitor columns',17),@('Detected startup commands',18),@('Battery module',19),@('Speedtest',3),@('DNS',7),@('Windows Security',15)
        )
        foreach ($shortcut in $shortcuts) {
            $title=NexL $shortcut[0];$label=$title+'  →  '+$names[$shortcut[1]]
            if ($title -cne $shortcut[0]) {$label+=' / '+$shortcut[0]}
            $labels+=@($label);$ids+=@([string]$shortcut[1])
        }
        $result=Ask 'Search Dashboard' $labels $ids '0' 
        if ($null -ne $result -and $result -in $ids) {ChoosePage ([int]$result)}
    }
    function NexSaveExtras {Save-NexPreferences;Notice 'Preferences saved.';ResetDraw}
    function NewPageAction($key) {
        $cardIds=@('Processor','Graphics','Memory','Storage','Network','System')
        switch ($s.Page) {
            17 {
                if ($key -eq 'P') {ChoosePage 1;return}
                if ($key -eq 'R') {$prefs.MonitorOrder=$cardIds -join ',';$prefs.MonitorHidden='';$prefs.MonitorColumns='Auto';NexSaveExtras;return}
                if ($key -eq 'C') {$choices=@('Auto','Single column','Two columns');$v=Ask 'Choose monitor columns' $choices $choices $prefs.MonitorColumns;if ($v -in $choices) {$prefs.MonitorColumns=$v;NexSaveExtras};return}
                $order=@($prefs.MonitorOrder -split ',');$hidden=@(($prefs.MonitorHidden -split ',') | Where-Object {$_})
                if ($key -in @('T','U','D')) {
                    $v=Ask 'Choose monitor card' @($order | ForEach-Object {NexL $_}) $order $order[0]
                    if ($v -notin $order) {return}
                    if ($key -eq 'T') {$key='card:'+$v}
                    else {
                        $i=[array]::IndexOf($order,$v);$j=if ($key -eq 'U') {$i-1} else {$i+1}
                        if ($j -ge 0 -and $j -lt $order.Count) {$other=$order[$j];$order[$j]=$v;$order[$i]=$other;$prefs.MonitorOrder=$order -join ',';NexSaveExtras};return
                    }
                }
                if ([string]$key -match '^card:(.+)$' -and $Matches[1] -cin $cardIds) {
                    $v=$Matches[1];if ($v -in $hidden) {$hidden=@($hidden | Where-Object {$_ -ne $v})}
                    else {if ($hidden.Count -ge 5) {Notice 'Keep at least one monitor card visible.';return};$hidden+=@($v)}
                    $prefs.MonitorHidden=$hidden -join ',';NexSaveExtras
                }
            }
            18 {
                switch -Regex ([string]$key) {
                    '^R$' {$s.StartupRows=$null;$s.StartupAt=$null;$null=$s.ExtraErrors.Remove('startup');$s.Next=0L;break}
                    '^W$' {Start-Process 'ms-settings:startupapps';break}
                    '^T$' {Start-Process taskmgr.exe;break}
                    '^F$' {Start-Process explorer.exe -ArgumentList 'shell:startup';break}
                    '^A$' {Start-Process explorer.exe -ArgumentList '"shell:common startup"';break}
                    '^entry:(\d+)$' {$i=[int]$Matches[1];if ($i -lt $s.StartupRows.Count) {$r=$s.StartupRows[$i];$lines=@((NexL 'Location'),$r.Location,'',(NexL 'Startup command'),$r.Command,'',(NexL 'Use Windows Startup Apps to enable or disable entries.'));$wrapped=@(foreach ($line in $lines) {WrapUpdateLine $line ([Math]::Max(20,[Console]::WindowWidth-31))});$s.Preview=@{Title=$r.Name;Lines=$wrapped;Pos=0}};break}
                }
            }
            19 {
                switch ($key) {
                    'B' {$v=ChooseNexToggle 'Battery module' ([bool]$prefs.ModuleBattery) 'Shows battery charge and power status in the header on supported PCs.';if ($null -ne $v) {$prefs.ModuleBattery=$v;NexSaveExtras}}
                    'S' {$v=ChooseNexToggle 'Session module' ([bool]$prefs.ModuleSession) 'Shows elapsed Dashboard session time in the header.';if ($null -ne $v) {$prefs.ModuleSession=$v;NexSaveExtras}}
                    'Q' {$v=ChooseNexToggle 'Shortcut module' ([bool]$prefs.ModuleShortcuts) 'Adds header shortcuts to App Launcher and Dashboard Designer.';if ($null -ne $v) {$prefs.ModuleShortcuts=$v;NexSaveExtras}}
                    'P' {ChoosePage 0}
                }
            }
            20 {
                switch ($key) {
                    'S' {$choices=@('Progress','Pulse','Wave','Dots','Minimal');$v=Ask 'Choose loading animation' $choices $choices $prefs.LoadingStyle;if ($v -in $choices) {$prefs.LoadingStyle=$v;NexSaveExtras}}
                    'V' {$choices=@('Fast','Normal','Slow');$v=Ask 'Choose animation speed' $choices $choices $prefs.AnimationSpeed;if ($v -in $choices) {$prefs.AnimationSpeed=$v;NexSaveExtras}}
                    'B' {$v=ChooseNexToggle 'Startup screen' ([bool]$prefs.Startup) $global:NexPersonalHelp['B'];if ($null -ne $v) {$prefs.Startup=$v;NexSaveExtras}}
                    'U' {$v=ChooseNexToggle 'Loading on return' ([bool]$prefs.LoadingOnReturn) $global:NexPersonalHelp['U'];if ($null -ne $v) {$prefs.LoadingOnReturn=$v;NexSaveExtras}}
                    'F' {$v=ChooseNexToggle 'Fetch animation' ([bool]$prefs.FetchAnimation) $global:NexPersonalHelp['J'];if ($null -ne $v) {$prefs.FetchAnimation=$v;NexSaveExtras}}
                    'P' {try {Show-NexLoadingScreen -InAlternateBuffer} finally {ResetDraw}}
                    'R' {$prefs.LoadingStyle='Progress';$prefs.AnimationSpeed='Normal';NexSaveExtras}
                }
            }
        }
    }
    function ShowNexSettingsHelp {
        $lines=@();$title=$names[$s.Page]
        if ($s.Page -eq 10) {foreach ($k in @('L','N','M','D','H','X','B','C','U','F','J','V','K','P','I','Q','A','O','Y','E','Z','T','S','R','G')) {$lines+=@("[$k] "+(NexL $global:NexPersonalHelp[$k]))}}
        elseif ($s.Page -eq 9) {foreach ($k in @('G','O','A','C','J','R')) {$lines+=@("[$k] "+(NexL $global:NexTerminalHelp[$k]))}}
        elseif ($s.Page -eq 17) {$lines+=@(NexL 'Arrange the System Monitor cards. Click a card to show or hide it.');$lines+=@(NexL 'One column is full-width; two columns adapt to the terminal size.');$lines+=@(NexL 'Keep at least one monitor card visible.')}
        elseif ($s.Page -eq 18) {$lines+=@(NexL 'Use Windows Startup Apps to enable or disable entries.');$lines+=@(NexL 'This list is read-only and may not include all disabled apps or scheduled tasks.')}
        elseif ($s.Page -eq 19) {$lines+=@(NexL 'Built-in modules add widgets to the header. No external scripts are executed.');$lines+=@(NexL 'Shows battery charge and power status in the header on supported PCs.');$lines+=@(NexL 'Shows elapsed Dashboard session time in the header.');$lines+=@(NexL 'Adds header shortcuts to App Launcher and Dashboard Designer.')}
        elseif ($s.Page -eq 20) {$lines+=@(NexL 'Speed changes loading and Fastfetch reveal. Preview does not restart the terminal.');$lines+=@(NexL $global:NexPersonalHelp['B']);$lines+=@(NexL $global:NexPersonalHelp['U']);$lines+=@(NexL $global:NexPersonalHelp['J'])}
        $lines+=@(NexL 'Search Dashboard with Ctrl+K. Tab switches between navigation and content. Esc returns to Overview or the shell.')
        $wrapped=@(foreach ($line in $lines) {WrapUpdateLine $line ([Math]::Max(20,[Console]::WindowWidth-32));''})
        $s.Preview=@{Title=((NexL 'Setting explanations')+' / '+$title);Lines=$wrapped;Pos=0};$s.Need=$true
    }
    function RefreshNexBattery {
        if (-not $prefs.ModuleBattery) {return}
            if ($clock.ElapsedMilliseconds-$s.BatteryAt -ge 5000) {
                $s.BatteryAt=$clock.ElapsedMilliseconds;$s.BatteryState=@{Status='Battery information unavailable';Charge=$null}
                try {
                    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                    $power=[System.Windows.Forms.SystemInformation]::PowerStatus
                    if ($power.BatteryChargeStatus -eq [System.Windows.Forms.BatteryChargeStatus]::Unknown) {}
                    elseif ($power.BatteryChargeStatus -band [System.Windows.Forms.BatteryChargeStatus]::NoSystemBattery) {$s.BatteryState.Status='No system battery'}
                    elseif ($power.BatteryLifePercent -ge 0 -and $power.BatteryLifePercent -le 1) {
                        $s.BatteryState.Charge=[Math]::Round($power.BatteryLifePercent*100)
                        $s.BatteryState.Status=switch ([string]$power.PowerLineStatus) {'Online' {'AC power'} 'Offline' {'Battery power'} default {'Power source unknown'}}
                    }
                } catch {}
            }
    }
    function ShowNexModules($body,$bodyHits) {
        if ($prefs.ModuleBattery) {
            RefreshNexBattery
            $text=NexL $s.BatteryState.Status
            if ($null -ne $s.BatteryState.Charge) {$text=('{0}% / {1}' -f $s.BatteryState.Charge,$text)}
            $body.Add("$purple$(Icon 0xF240) $(NexL 'Battery module'): $white$text$reset")
        }
        if ($prefs.ModuleSession) {$body.Add("$purple$(Icon 0xF017) $(NexL 'Session module'): $white$($clock.Elapsed.ToString('hh\:mm\:ss'))$reset")}
        if ($prefs.ModuleShortcuts) {$bodyHits[$body.Count]=@{Kind='nav';Index=13};$body.Add("$green$(Icon 0xF135) $(NexL 'App Launcher')$reset");$bodyHits[$body.Count]=@{Kind='nav';Index=17};$body.Add("$pink$(Icon 0xF009) $(NexL 'Dashboard Designer')$reset")}
    }
    function NexHeaderModules {
        if ($prefs.ModuleBattery) {
            RefreshNexBattery
            if ($null -ne $s.BatteryState.Charge) {
                $charge=[int]$s.BatteryState.Charge
                $tone=if ($charge -le 15) {$red} elseif ($charge -le 35) {NexAnsi 'FAB387'} else {$green}
                $glyph=if ($charge -ge 90) {0xF240} elseif ($charge -ge 65) {0xF241} elseif ($charge -ge 40) {0xF242} elseif ($charge -ge 15) {0xF243} else {0xF244}
                $powerMark=if ($s.BatteryState.Status -eq 'AC power' -and $prefs.Icons) {" $(Icon 0xF0E7)"} else {''}
                $batteryLabel=if ($prefs.Icons) {Icon $glyph} else {NexL 'Battery module'}
                [pscustomobject]@{Text="$tone$batteryLabel $charge%$powerMark$reset";Page=19}
            } elseif ($s.BatteryState.Status -ne 'No system battery') {
                [pscustomobject]@{Text="$gray$(Icon 0xF240) —$reset";Page=19}
            }
        }
        if ($prefs.ModuleSession) {[pscustomobject]@{Text="$purple$(Icon 0xF017) $($clock.Elapsed.ToString('hh\:mm\:ss'))$reset";Page=19}}
        if ($prefs.ModuleShortcuts) {
            [pscustomobject]@{Text="$green$(Icon 0xF135) $(NexL 'Apps')$reset";Page=13}
            [pscustomobject]@{Text="$pink$(Icon 0xF009) $(NexL 'Layout')$reset";Page=17}
        }
    }
    function ExtraAction($key) {
        if ($s.Page -ge 17) {NewPageAction $key;return}
        if ($s.Page -in @(15,16) -and [string]$key -match '^event:(\d+)$') {ShowNexHealthEvent $Matches[1];return}
        if ($key -eq 'R' -and $s.Page -ne 14) {
            $s.ExtraErrors.Clear()
            switch ($s.Page) {11 {$s.Hardware=$null};12 {$s.Game=$null};13 {$s.Apps=$null};15 {$s.HealthNext=0L};16 {$s.HealthNext=0L;UpdateNexAlerts}}
            $s.Next=0;$s.ExtraPos=0;return
        }
        if ($s.Page -in @(15,16) -and $key -eq 'C') {$null=ClearNexHealthEvents;return}
        switch ($s.Page) {
            12 {
                if ($key -eq 'G') {Start-Process 'ms-settings:gaming-gamemode';$s.Next=0L;return}
                if ($key -eq 'P') {Start-Process 'control.exe' -ArgumentList '/name Microsoft.PowerOptions';$s.Next=0L;return}
                if (-not $s.Game) {Notice 'Loading Windows counters...';return}
                $id=$null
                if ($key -eq 'A') {
                    if (-not $s.Game.Recommended) {Notice 'Balanced plan not found.';return}
                    $id=$s.Game.Recommended.Id
                }
                elseif ($key -eq 'S') {
                    $available=@($s.Game.Plans | Where-Object {$_ -and $_.Id})
                    if (-not $available.Count) {Notice 'No power plans found.';return}
                    $id=Ask 'Choose power plan' @($available | ForEach-Object {$_.Name}) @($available | ForEach-Object {$_.Id}) $s.Game.Active
                }
                elseif ([string]$key -match '^plan:([0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})$') {$id=$Matches[1]}
                else {return}
                if (-not $id) {return}
                $plan=$s.Game.Plans | Where-Object Id -eq $id | Select-Object -First 1
                if (-not $plan -or $plan.Id -notmatch '^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') {return}
                if ($plan.Id -eq $s.Game.Active) {Notice 'This power plan is already active.';$s.Next=0L;return}
                if (ConfirmNex 'Apply power plan' $plan.Name (NexL 'No CPU or GPU overclocking.')) {
                    $result=@(powercfg.exe /setactive $plan.Id 2>$null)
                    if ($LASTEXITCODE -ne 0) {Notice ('{0} {1}' -f (NexL 'Power plan change failed.'),(SafeText ($result -join ' ')));$s.Next=0L;return}
                    $current=@(powercfg.exe /getactivescheme 2>$null)
                    $exitCode=$LASTEXITCODE
                    $match=[regex]::Match(($current -join ' '),'(?i)\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b')
                    $s.GameChangedAt=$clock.ElapsedMilliseconds;$s.Next=0L
                    if ($exitCode -ne 0 -or -not $match.Success) {Notice 'Could not verify the active power plan.';return}
                    $s.Game.Active=$match.Value
                    foreach ($p in $s.Game.Plans) {$p.Active=($p.Id -eq $s.Game.Active)}
                    if ($s.Game.Active -ne $plan.Id) {Notice 'Windows did not activate the selected plan.';return}
                    Notice 'Power plan applied.'
                }
            }
            13 {
                if ($key -eq 'F') {$v=Ask 'Search applications';if ($null -ne $v) {$s.AppFilter=$v;$s.ExtraPos=0};return}
                if ($key -eq 'C') {$s.AppFilter='';$s.ExtraPos=0;return}
                $app=$null
                if ($key -eq 'L') {$list=@($s.Apps | Where-Object {$_.Name.IndexOf($s.AppFilter,[StringComparison]::OrdinalIgnoreCase) -ge 0});if ($list.Count) {$id=Ask 'Choose application' @($list | ForEach-Object {$_.Name}) @($list | ForEach-Object {$_.Id});$app=$list | Where-Object Id -eq $id | Select-Object -First 1}}
                elseif ([string]$key -match '^app:(\d+)$') {$i=[int]$Matches[1];if ($i -ge 0 -and $i -lt $s.Apps.Count) {$app=$s.Apps[$i]}}
                if ($app -and $app.Id -notmatch '[\x00-\x1F"&|<>]') {Start-Process explorer.exe -ArgumentList ('"shell:AppsFolder\'+$app.Id+'"');Notice 'Application launched.'}
            }
            14 {
                if ($key -eq 'U') {StartNexReleaseCheck $true;return}
                if ($key -eq 'R') {StartNexReleaseCheck $false;return}
                if ($key -eq 'O') {Start-Process 'https://github.com/owoNEXowo/NEX-Dashboard/releases';return}
                if ($key -eq 'I') {SelectNexInstaller;return}
                if ($key -eq 'A') {ShowNexReleaseDetails 'about';return}
                if ($key -eq 'H') {ShowNexReleaseDetails 'history';return}
            }
            15 {
                if ($key -eq 'L') {ChoosePage 8};if ($key -eq 'W') {ChoosePage 6};if ($key -eq 'D') {Start-Process 'windowsdefender:'}
            }
            16 {
                if ($key -eq 'D') {
                    if ($s.Health -and $s.Health.EventKnown -and $s.Health.Events.Count) {
                        if (-not (ClearNexHealthEvents)) {return}
                    }
                    foreach ($a in $s.Alerts) {$s.AlertDismiss[$a.Id]=$true}
                    UpdateNexAlerts
                }
                if ($key -eq 'H') {ChoosePage 15};if ($key -eq 'M') {ChoosePage 1}
            }
        }
    }
    function RenderExtra($body,$bodyHits) {
        function EButton($key,$label,$icon) {$bodyHits[$body.Count]=@{Kind='extra';Index=$key};$body.Add("$purple[$key] $(Icon $icon)  $white$(NexL $label)$reset")}
        function EHead($label,$icon,$color=$pink) {$body.Add('');$body.Add("$color$(Icon $icon)  $(NexL $label)$reset");$body.Add("$muted$('─'*24)$reset")}
        function EEvents {
            if (-not $s.Health.EventKnown) {$body.Add("$gray$(NexL 'Query failed or access denied.')$reset");return}
            if ($s.EventCutoff -gt 0) {$body.Add("$gray$(NexL 'Events shown after last clear'): $(([datetime]::new($s.EventCutoff,[DateTimeKind]::Utc)).ToLocalTime().ToString('g'))$reset")}
            if (-not $s.Health.Events.Count) {$body.Add("$green$(NexL 'No recent system errors')$reset");return}
            $body.Add("$gray$(NexL 'Last 24 hours - up to 30 events. Click an event for details.')$reset")
            foreach ($ev in @($s.Health.Events)) {
                $col=if ($ev.Level -eq 1) {$red} else {NexAnsi 'FF943D'}
                $severity=if ($ev.Level -eq 1) {NexL 'Critical'} else {NexL 'Error'}
                $bodyHits[$body.Count]=@{Kind='extra';Index=('event:'+$ev.RecordId)}
                $body.Add("$col$(Icon 0xF071) $severity $($ev.Id) $gray$($ev.Time.ToString('HH:mm:ss')) $white$(SafeText $ev.Source)$reset")
                $summary=if ([string]::IsNullOrWhiteSpace($ev.Message)) {NexL 'Windows did not provide an event description.'} else {SafeText $ev.Message}
                $bodyHits[$body.Count]=@{Kind='extra';Index=('event:'+$ev.RecordId)}
                $body.Add("  $gray$summary$reset")
            }
        }
        $query=(@{11='hardware';12='gaming';13='apps';14='release';15='health';16='health'})[[int]$s.Page]
        if ($query -and $s.ExtraErrors.ContainsKey($query)) {$body.Add("$red$(NexL 'Query failed or access denied.')$reset");$body.Add("$gray$(SafeText $s.ExtraErrors[$query])$reset")}
        switch ($s.Page) {
            11 {
                EButton 'R' 'Refresh' 0xF021
                if ($null -eq $s.Hardware) {$body.Add("$gray$(NexL 'Loading Windows counters...')$reset");break}
                if (-not $s.Hardware.Count) {$body.Add("$gray$(NexL 'Not detected')$reset")}
                $group='';$colors=@{Processor='FAB387';Graphics='A6E3A1';Memory=$palette[0];Motherboard='CBA6F7';Storage='89B4FA';Network='94E2D5';System='F9E2AF'};$ico=@{Processor=0xF2DB;Graphics=0xF108;Memory=0xEFC5;Motherboard=0xF085;Storage=0xF0A0;Network=0xF1EB;System=0xF17A}
                foreach ($r in $s.Hardware) {if ($r.Group -ne $group) {$group=$r.Group;EHead $group $ico[$group] (NexAnsi $colors[$group])};$vc=$white;if ($r.Group -in @('Processor','Graphics') -and $r.Label -in @('Model','VRAM (NVIDIA)')) {$vc=NexAnsi (Get-NexVendorColor $r.Value $palette[4])};$body.Add((Label $r.Label $r.Value $vc))}
            }
            12 {
                $recState=if (-not $s.Game -or -not $s.Game.Recommended -or -not $s.Game.Active) {"$gray[?]"} elseif ($s.Game.Active -eq $s.Game.Recommended.Id) {"$green[✓]"} else {"$gray[ ]"}
                $modeState=if (-not $s.Game -or $null -eq $s.Game.Mode) {"$gray[?]"} elseif ($s.Game.Mode -eq 1) {"$green[✓]"} else {"$gray[ ]"}
                $bodyHits[$body.Count]=@{Kind='extra';Index='A'};$body.Add("$purple[A] $recState $white$(NexL 'Apply recommended plan')$reset")
                EButton 'S' 'Choose power plan' 0xF0E7
                $bodyHits[$body.Count]=@{Kind='extra';Index='G'};$body.Add("$purple[G] $modeState $white$(NexL 'Windows Game Mode')$reset")
                EButton 'P' 'Windows power options' 0xF013; EButton 'R' 'Refresh' 0xF021
                if (-not $s.Game) {$body.Add("$gray$(NexL 'Loading Windows counters...')$reset");break}
                 $vendorTone=NexAnsi (Get-NexVendorColor $s.Game.CPU $palette[4]); EHead 'Processor' 0xF2DB $vendorTone;$body.Add("$vendorTone$(SafeText $s.Game.CPU)$reset")
                $body.Add("$green$(NexL $s.Game.Reason)$reset")
                $mode=if ($null -eq $s.Game.Mode) {NexL 'Not detected'} elseif ($s.Game.ModeDefault) {NexL 'Enabled (Windows default)'} elseif ($s.Game.Mode -eq 1) {NexL 'Enabled'} else {NexL 'Disabled'}
                $bodyHits[$body.Count]=@{Kind='extra';Index='G'};$body.Add("$modeState $white$(NexL 'Windows Game Mode'): $mode$reset")
                EHead 'Available power plans' 0xF0E7 (NexAnsi 'F9E2AF')
                $body.Add("$gray$(NexL 'Click a power plan to apply it.')$reset")
                foreach ($p in $s.Game.Plans) {
                    if (-not $p -or -not $p.Id) {continue}
                    $col=if ($p.Active) {$green} else {$white}
                    $mark=if (-not $s.Game.Active) {"$gray[?]"} elseif ($p.Active) {"$green[✓]"} else {"$gray[ ]"}
                    $rec=if ($s.Game.Recommended -and $p.Id -eq $s.Game.Recommended.Id) {" $pink[$(NexL 'Recommended')]"} else {''}
                    $bodyHits[$body.Count]=@{Kind='extra';Index=('plan:'+$p.Id)}
                    $body.Add("$mark $col$(SafeText $p.Name)$rec$reset")
                }
                if (-not $s.Game.Plans.Count) {$body.Add("$gray$(NexL 'No power plans found.')$reset")}
                if (-not $s.Game.Recommended) {$body.Add("$gray$(NexL 'Balanced plan not found.')$reset")}
            }
            13 {
                EButton 'F' 'Search applications' 0xF002; EButton 'L' 'Choose application' 0xF135;EButton 'C' 'Clear filter' 0xF00D;EButton 'R' 'Refresh' 0xF021
                if ($null -eq $s.Apps) {$body.Add("$gray$(NexL 'Loading applications...')$reset");break}
                EHead 'Installed applications' 0xF135 (NexAnsi '94E2D5');$body.Add((Label 'Filter' $s.AppFilter))
                for ($i=0;$i -lt $s.Apps.Count;$i++) {$app=$s.Apps[$i];if ($app.Name.IndexOf($s.AppFilter,[StringComparison]::OrdinalIgnoreCase) -lt 0) {continue};$bodyHits[$body.Count]=@{Kind='extra';Index="app:$i"};$body.Add("$pink$(Icon 0xF135)  $white$(SafeText $app.Name)$reset")}
            }
            14 {
                EHead 'NEX Dashboard' 0xF021; $body.Add((Label 'Installed version' '2.6.2'));$body.Add((Label 'Release repository' 'owoNEXowo/NEX-Dashboard'))
                $body.Add('');$bodyHits[$body.Count]=@{Kind='extra';Index='U'}
                $body.Add("$green[U] $(Icon 0xF019)  $(NexL 'Download and install update')$reset")
                EButton 'R' 'Check for releases' 0xF021;EButton 'O' 'Open releases' 0xF0AC
                if ($s.Job -and $s.JobKind -eq 'release-download') {$body.Add("$pink$(NexL 'Downloading and verifying update...')$reset")}
                elseif ($s.Job -and $s.JobKind -eq 'release') {$body.Add("$gray$(NexL 'Checking for releases...')$reset")}
                elseif ($s.Release) {
                    EHead 'Latest release' 0xF019 (NexAnsi '89B4FA')
                    if ($s.Release.Comparable) {
                        $body.Add((Label 'Version' $s.Release.Tag))
                        $status=if ($s.Release.Newer) {NexL 'New version available'} else {NexL 'No newer release found'}
                        $releaseColor=if ($s.Release.Newer) {$green} else {$white};$body.Add("$releaseColor$status$reset")
                        if ($s.Release.Newer -and -not $s.Release.Available) {$body.Add("$red$(NexL $s.Release.Reason)$reset")}
                    } else {$body.Add("$gray$(NexL $s.Release.Reason)$reset")}
                }
                EHead 'Manual update and information' 0xF05A $gray
                EButton 'I' 'Choose update file (.ps1)' 0xF019;EButton 'A' 'About NEX Dashboard' 0xF05A;EButton 'H' 'Version history' 0xF1DA
                $body.Add('');$body.Add("$gray$(NexL 'Official releases are checked before installation.')$reset")
            }
            15 {
                EButton 'R' 'Refresh' 0xF021;EButton 'C' 'Clear displayed events' 0xF1F8;EButton 'L' 'System Logs' 0xF15C;EButton 'W' 'Windows Update' 0xF021;EButton 'D' 'Windows Security' 0xF132
                if (-not $s.Health) {$body.Add("$gray$(NexL 'Loading Windows counters...')$reset");break}
                $d=$s.Health; $body.Add((Label 'Last check' $d.At.ToString('HH:mm:ss')))
                EHead 'Storage' 0xF0A0 (NexAnsi '89B4FA');if (-not $d.DiskKnown -or -not $d.Disks.Count) {$body.Add("$gray$(NexL 'Not detected')$reset")}
                foreach ($p in $d.Disks) {$col=if ($p.Health -eq 'Healthy') {$green} elseif ($p.Health -eq 'Unknown') {$gray} else {$red};$body.Add("$white$(SafeText $p.Name) $col$(NexL $p.Health)$reset")}
                foreach ($v in $d.Volumes) {$body.Add("$white$($v.Name) $(Bar (100-$v.Free)) $(LoadText (100-$v.Free))$([Math]::Round(100-$v.Free,1))% $gray$(NexL 'Used') / $($v.Free)% $(NexL 'Free')$reset")}
                EHead 'System' 0xF17A (NexAnsi 'F9E2AF');$body.Add((Label 'Recent system errors' $(if ($d.EventKnown) {$d.Events.Count} else {NexL 'Not detected'})));$body.Add((Label 'Windows Update restart' $(if ($null -eq $d.Reboot) {NexL 'Not detected'} elseif ($d.Reboot) {NexL 'Yes'} else {NexL 'No'})));$body.Add((Label 'Servicing restart marker' $(if ($null -eq $d.Servicing) {NexL 'Not detected'} elseif ($d.Servicing) {NexL 'Yes'} else {NexL 'No'})))
                EHead 'Windows Security' 0xF132 (NexAnsi '94E2D5');$body.Add((Label 'Defender real-time protection' $(if ($null -eq $d.Defender) {NexL 'Not detected'} elseif ($d.Defender.RealTimeProtectionEnabled) {NexL 'Enabled'} else {NexL 'Disabled'})))
                EHead 'Recent system errors' 0xF071 (NexAnsi 'FF943D'); EEvents
            }
            16 {
                EButton 'R' 'Refresh' 0xF021;EButton 'C' 'Clear displayed events' 0xF1F8;EButton 'D' 'Dismiss current alerts' 0xF00C;EButton 'H' 'System Health' 0xF0FA;EButton 'M' 'System Monitor' 0xF080
                EHead 'Current notifications' 0xF0F3 (NexAnsi 'F9E2AF')
                if (-not $s.Health) {$body.Add("$gray$(NexL 'Waiting for health check...')$reset")}
                elseif (-not $s.Alerts.Count) {$body.Add("$green$(Icon 0xF00C) $(NexL 'No active notifications')$reset")}
                foreach ($a in $s.Alerts) {$col=if ($a.Level -eq 'Warning') {(NexAnsi 'FF943D')} else {$blue};$body.Add("$col$(Icon 0xF071) $(NexL $a.Title)$reset");if ($a.Detail) {$body.Add("  $gray$(SafeText $a.Detail)$reset")}}
                if (@($s.Alerts | Where-Object Title -eq 'Recent system errors').Count) {EHead 'System event details' 0xF15C (NexAnsi 'FF943D'); EEvents}
                elseif ($s.EventCutoff -gt 0) {$body.Add("$gray$(NexL 'Old events are hidden in Dashboard only.')$reset")}
                $body.Add('');$body.Add("$gray$(NexL 'Temperature alerts use available GPU sensors only.')$reset")
            }
            17 {
                EHead 'Dashboard Designer' 0xF009
                foreach ($line in @(WrapUpdateLine (NexL 'Arrange the System Monitor cards. Click a card to show or hide it.') $rightWidth)) {$body.Add("$gray$line$reset")}
                EButton 'C' 'Choose monitor columns' 0xF009
                $body.Add((Label 'Columns' (NexL $prefs.MonitorColumns)))
                EButton 'U' 'Move card up' 0xF062; EButton 'D' 'Move card down' 0xF063; EButton 'T' 'Show or hide card' 0xF06E
                EButton 'P' 'Preview monitor' 0xF080; EButton 'R' 'Reset layout' 0xF021
                EHead 'Card order' 0xF0C9 (NexAnsi '89B4FA')
                $cardIcons=@{Processor=0xF2DB;Graphics=0xF108;Memory=0xEFC5;Storage=0xF0A0;Network=0xF1EB;System=0xF013}
                $num=0;foreach ($id in ($prefs.MonitorOrder -split ',')) {$num++;$shown=$id -notin ($prefs.MonitorHidden -split ',');$mark=if ($shown) {"$green[✓]"} else {"$gray[ ]"};$bodyHits[$body.Count]=@{Kind='extra';Index=('card:'+$id)};$body.Add("$mark $purple$num. $(Icon $cardIcons[$id]) $white$(NexL $id)$reset")}
            }
            18 {
                EHead 'Startup Manager' 0xF135
                EButton 'W' 'Windows Startup Apps' 0xF013; EButton 'T' 'Task Manager' 0xF080; EButton 'F' 'Open user startup folder' 0xF07B; EButton 'A' 'Open shared startup folder' 0xF07B; EButton 'R' 'Refresh' 0xF021
                foreach ($line in @(WrapUpdateLine (NexL 'Use Windows Startup Apps to enable or disable entries.') $rightWidth)) {$body.Add("$gray$line$reset")}
                foreach ($line in @(WrapUpdateLine (NexL 'This list is read-only and may not include all disabled apps or scheduled tasks.') $rightWidth)) {$body.Add("$gray$line$reset")}
                EHead 'Detected startup commands' 0xF135 (NexAnsi '89B4FA')
                if ($s.StartupAt) {$body.Add((Label 'Last check' $s.StartupAt.ToString('HH:mm:ss')))}
                if ($s.ExtraErrors.ContainsKey('startup')) {$body.Add("$red$(NexL 'Query failed or access denied.')$reset")}
                elseif ($null -eq $s.StartupRows) {$body.Add("$gray$(NexL 'Loading Windows counters...')$reset")}
                elseif (-not $s.StartupRows.Count) {$body.Add("$gray$(NexL 'No startup commands found.')$reset")}
                else {for ($i=0;$i -lt $s.StartupRows.Count;$i++) {$r=$s.StartupRows[$i];$bodyHits[$body.Count]=@{Kind='extra';Index=('entry:'+$i)};$body.Add("$pink$(Icon 0xF15B) $white$(SafeText $r.Name)$reset");$body.Add("  $gray$(SafeText $r.Location)$reset")}}
            }
            19 {
                EHead 'Plugin Manager' 0xF1E6
                foreach ($line in @(WrapUpdateLine (NexL 'Built-in modules add widgets to the header. No external scripts are executed.') $rightWidth)) {$body.Add("$gray$line$reset")}
                foreach ($row in @(@('B','Battery module','ModuleBattery','Shows battery charge and power status in the header on supported PCs.',0xF240),@('S','Session module','ModuleSession','Shows elapsed Dashboard session time in the header.',0xF017),@('Q','Shortcut module','ModuleShortcuts','Adds header shortcuts to App Launcher and Dashboard Designer.',0xF135))) {
                    $state=if ($prefs[$row[2]]) {'Enabled'} else {'Disabled'};$bodyHits[$body.Count]=@{Kind='extra';Index=$row[0]};$body.Add((SettingLine ('['+$row[0]+'] '+$row[1]) (NexL $state) $rightWidth $(if ($prefs[$row[2]]) {$green} else {$gray}) $row[4]))
                }
                EButton 'P' 'Overview' 0xF015
                EHead 'Module preview' 0xF06E (NexAnsi '94E2D5');if (-not ($prefs.ModuleBattery -or $prefs.ModuleSession -or $prefs.ModuleShortcuts)) {$body.Add("$gray$(NexL 'No modules enabled')$reset")} else {ShowNexModules $body $bodyHits}
            }
            20 {
                EHead 'Animation Studio' 0xF0D0
                $bodyHits[$body.Count]=@{Kind='extra';Index='S'};$body.Add((SettingLine '[S] Choose loading animation' (NexL $prefs.LoadingStyle) $rightWidth))
                $bodyHits[$body.Count]=@{Kind='extra';Index='V'};$body.Add((SettingLine '[V] Choose animation speed' (NexL $prefs.AnimationSpeed) $rightWidth))
                foreach ($r in @(@('B','Startup screen','Startup'),@('U','Loading on return','LoadingOnReturn'),@('F','Fetch animation','FetchAnimation'))) {
                    $state=if ($prefs[$r[2]]) {'Enabled'} else {'Disabled'};$bodyHits[$body.Count]=@{Kind='extra';Index=$r[0]};$body.Add((SettingLine ('['+$r[0]+'] '+$r[1]) (NexL $state) $rightWidth $(if ($prefs[$r[2]]) {$green} else {$gray})))
                }
                EButton 'P' 'Preview loading animation' 0xF04B; EButton 'R' 'Reset animations' 0xF021
                $body.Add('');foreach ($line in @(WrapUpdateLine (NexL 'Speed changes loading and Fastfetch reveal. Preview does not restart the terminal.') $rightWidth)) {$body.Add("$gray$line$reset")}
            }
        }
    }

    function Render {
        $w=[Console]::WindowWidth; $h=[Console]::WindowHeight
        if ($w -lt 58 -or $h -lt 16) {
            $size="${w}x${h}"
            if ($s.Size -ne $size) { $smallMsg='Enlarge terminal (58 x 16 min).'; Write-Host "$e[2J$e[H${pink}$smallMsg$reset" -NoNewline; $s.Size=$size; $s.Old=@() }
            $s.Hits=@(); return
        }
        $wide=($w -ge 88 -and $s.Page -ne 1); $leftWidth=25; $rightWidth=if ($wide) {$w-$leftWidth-4} else {$w-3}
        $maxBody=$h-7; $body=New-Object 'System.Collections.Generic.List[string]'; $bodyHits=@{}
        $extra='Ctrl+K: search | F1: help | Esc: back'; $heading=$names[$s.Page]; $hint='Tab: sidebar  |  Esc: overview / exit'
        $navVisual=@(foreach ($pageId in $navOrder) {
            if ($prefs.SidebarSeparators -and $pageId -in $navGroupStarts) {-1}
            [int]$pageId
        })
        $navIndex=[array]::IndexOf($navVisual,[int]$s.Nav)
        if ($navIndex -lt 0) {$navIndex=0}
        $navOffset=[Math]::Max(0,[Math]::Min([int]$s.NavOffset,[Math]::Max(0,$navVisual.Count-$maxBody)))
        if ($navIndex -lt $navOffset) {$navOffset=$navIndex}
        elseif ($navIndex -ge $navOffset+$maxBody) {$navOffset=$navIndex-$maxBody+1}
        $s.NavOffset=$navOffset
        $menuOnly=(-not $wide -and $s.Focus -eq 'nav' -and -not $s.Preview)
        if ($menuOnly) {
            $heading=NexL 'Navigation'; $hint='Enter: open  |  Tab: content  |  Esc: exit'
            for ($i=$navOffset;$i -lt $navVisual.Count -and $body.Count -lt $maxBody;$i++) {
                $ni=$navVisual[$i]
                if ($ni -eq -1) {$body.Add("$muted  $('─'*[Math]::Min(21,$rightWidth-3))$reset");continue}
                $a=if ($ni -eq $s.Nav) {"$bg$pink  ❯"} else {"$gray   "}
                $bodyHits[$body.Count]=@{Kind='nav';Index=$ni}
                $body.Add("$a $(Icon $codes[$ni])  $($names[$ni])$reset")
            }
        } elseif ($s.Preview) {
            $heading=NexL 'Preview'; $hint='Up/Down: scroll  |  Esc: back'
            $body.Add("$purple$(SafeText $s.Preview.Title)$reset")
            $bodyHits[$body.Count]=@{Kind='previewBack';Index=0}; $body.Add("$pink[ Back ]$reset")
            $take=[Math]::Max(1,$maxBody-2)
            $s.Preview.Pos=[Math]::Max(0,[Math]::Min($s.Preview.Pos,[Math]::Max(0,$s.Preview.Lines.Count-$take)))
            foreach ($line in @($s.Preview.Lines | Select-Object -Skip $s.Preview.Pos -First $take)) {
                $tone=if ($s.Preview.ReleaseDetails -and $line -match '^\s*\d+\.\d+\.\d+\s*$') {$pink} else {$white}
                $body.Add("$tone$(SafeText $line)$reset")
            }
        } else {
            switch ($s.Page) {
                0 {
                    $body.Add("$pink$(Icon 0xF015)  $(NexL 'Welcome'), $(SafeText (Get-NexName))$reset"); $body.Add('')
                    $body.Add((Label 'Computer' $env:COMPUTERNAME)); $body.Add((Label 'User' (Get-NexName))); $body.Add('')
                    if ($s.LastOverview) {
                        $d=$s.LastOverview
                        $uc=SmoothNumber 'overview-cpu' $d.CPU
                        $ur=SmoothNumber 'overview-ram' $d.RAM
                        $um=SmoothNumber 'overview-used' $d.Used
                        $body.Add("$(NexAnsi 'FAB387')$(Icon 0xF2DB) CPU $(Bar $uc)  $(LoadText $uc)$('{0,5:0.0}%' -f $uc)$reset")
                        $body.Add("$pink$(Icon 0xEFC5) RAM $(Bar $ur)  $(LoadText $ur)$('{0,5:0.0}%' -f $ur)$reset")
                        $body.Add((Label 'Memory' ('{0:0.0} / {1:0.0} GiB' -f $um,$d.Total)))
                        $body.Add((Label 'Uptime' (((Get-Date)-$d.Boot).ToString('dd\.hh\:mm\:ss'))))
                    } else { $body.Add("$gray $(NexL 'Loading Windows counters...')$reset") }
                    $body.Add(''); $body.Add("$green●  $(NexL 'LIVE')  $gray | $(NexL 'Smoothed display')$reset")
                    $bodyHits[$body.Count]=@{Kind='nav';Index=16};$alertColor=if ($s.Alerts.Count) {NexAnsi 'FF943D'} else {$gray};$body.Add("$alertColor$(Icon 0xF0F3) $(NexL 'Notification Center'): $($s.Alerts.Count)$reset")
                    $bodyHits[$body.Count]=@{Kind='installer';Index='I'};$body.Add("$green[I] $(Icon 0xF019) $(NexL 'Update from file')$reset")
                    $bodyHits[$body.Count]=@{Kind='globalKey';Index='Search'};$body.Add("$pink$(Icon 0xF002) Ctrl+K  $(NexL 'Search Dashboard')$reset")
                    if ($w -lt 100 -and $body.Count -lt $maxBody) {ShowNexModules $body $bodyHits}
                }
                1 {
                    if ($s.LastOverview) {
                        $content=@(MonitorLayout $s.LastOverview $rightWidth)
                        $take=[Math]::Max(1,$maxBody-1)
                        $s.MonitorMax=[Math]::Max(0,$content.Count-$take)
                        $s.MonitorPos=[Math]::Max(0,[Math]::Min($s.MonitorMax,$s.MonitorPos))
                        foreach ($line in @($content | Select-Object -Skip $s.MonitorPos -First $take)) {$body.Add($line)}
                        $note=if ($s.MonitorMax -gt 0) {" | $(NexL 'Scroll for more') ($($s.MonitorPos+1)/$($s.MonitorMax+1))"} else {''}
                        $body.Add("$green● $(NexL 'LIVE') $gray | $(NexL 'Smoothed display')$note$reset")
                    } else {$body.Add("$gray$(NexL 'Loading Windows counters...')$reset")}
                    $hint='Up/Down scroll | Tab Menu | Esc Overview'
                }
                2 {
                    $body.Add("$green● $(NexL 'LIVE') $gray | $(NexL 'Sort'): $($s.ProcSort) | $(NexL 'Filter'): $(SafeText $s.ProcFilter)$reset")
                    $buttons=Buttons @(@{Label='[C] CPU';Kind='processAction';Key='C'},@{Label='[M] RAM';Kind='processAction';Key='M'},@{Label='[G] GPU';Kind='processAction';Key='G'},@{Label='[D] I/O';Kind='processAction';Key='D'},@{Label='[N] TCP';Kind='processAction';Key='N'}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $buttons=Buttons @(@{Label='[F] Find';Kind='processAction';Key='F'},@{Label='[R] Clear';Kind='processAction';Key='R'},@{Label='[T] Task mgr';Kind='processAction';Key='T'}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $sort=$s.ProcSort
                    $columns=if ($rightWidth -ge 92) {@('CPU','RAM','GPU','IO','TCP')} else {@('CPU','RAM',$sort) | Select-Object -Unique}
                    $columns=@($columns)
                    $titles=@{CPU='CPU %';RAM='RAM MiB';GPU='GPU %';IO='I/O MiB/s';TCP='TCP count'}
                    $nameWidth=[Math]::Max(8,$rightWidth-8-12*$columns.Count)
                    $headerLine="$gray$(Fit 'PID' 8)$(Fit (NexL 'PROCESS') $nameWidth)"
                    foreach ($metric in $columns) {$headerLine+=Fit (NexL $titles[$metric]) 12}
                    $body.Add("$headerLine$reset")
                    $listKey="$($s.ProcAt)/$sort/$($s.ProcFilter)"
                    if ($s.ProcListKey -cne $listKey) {
                        $s.ProcList=@($s.ProcRows | Where-Object { -not $s.ProcFilter -or $_.Name.IndexOf($s.ProcFilter,[StringComparison]::OrdinalIgnoreCase) -ge 0 } | Sort-Object @{Expression={$_[$sort]};Descending=$true},@{Expression={$_.Name}})
                        $s.ProcListKey=$listKey
                    }
                    $list=$s.ProcList
                    $take=[Math]::Max(1,$maxBody-6)
                    $s.ProcPos=[Math]::Max(0,[Math]::Min([int]$s.ProcPos,[Math]::Max(0,$list.Count-$take)))
                    foreach ($p in @($list | Select-Object -Skip $s.ProcPos -First $take)) {
                        $row="$blue$(Fit $p.Id 8)$white$(Fit $p.Name $nameWidth)"
                        foreach ($metric in $columns) {
                            $v=$p[$metric];$tone=$gray;$display='--'
                            if ($null -ne $v) {
                                if ($metric -in @('CPU','RAM')) {$v=SmoothNumber ('proc-'+$metric+'-'+$p.Id) $v}
                                $display=if ($metric -eq 'TCP') {'{0:0}' -f $v} else {'{0:0.0}' -f $v}
                                $tone=$white
                                if ($metric -in @('CPU','GPU')) {$tone=LoadText $v $palette[0]}
                                elseif ($metric -eq 'RAM' -and $s.ProcMemoryTotal -gt 0) {$tone=LoadText (100.0*$v/$s.ProcMemoryTotal) $palette[0]}
                            }
                            $row+="$tone$(Fit $display 12)"
                        }
                        $body.Add("$row$reset")
                    }
                    $body.Add("$gray $($list.Count) $(NexL 'Processes sampled')$reset")
                    $body.Add("$gray$(Fit (NexL 'I/O includes file, device and network operations; TCP is connection count, not speed.') $rightWidth)$reset")
                    $hint='C CPU | M RAM | G GPU | D I/O | N TCP | Up/Down'
                }
                3 {
                    $body.Add("$green● $(NexL 'LIVE')  $gray $(Icon 0xF1EB)  $(NexL 'NETWORK TRAFFIC')  /  $(NexL 'Smoothed')$reset")
                    if ($s.NetReady) {
                        $body.Add("$pink ↓  $('{0,7:0.00}' -f $s.UiDown) Mbps   $blue↑  $('{0,7:0.00}' -f $s.UiUp) Mbps$reset")
                        if ($rightWidth -ge 45 -and $maxBody -ge 22) {
                            $chartWidth=[int][Math]::Min(44,[Math]::Floor(($rightWidth-13)/2.0))
                            foreach ($line in @(NetChartPair $chartWidth)) { $body.Add($line) }
                        } else {
                            $body.Add("$pink$(Spark $s.NetHist)$reset  $gray $(NexL 'Down')$reset")
                            $body.Add("$blue$(Spark $s.NetUpHist)$reset  $gray $(NexL 'Up')$reset")
                        }
                        $rateLabel=if ($s.NetFast) {'150 ms target'} else {'standard sampling'}
                        $body.Add("$gray $(NexL '8 s history') | $(NexL 'log scale') | $(NexL $rateLabel)$reset")
                        $body.Add("$gray $(NexL 'Peak'): ↓ $('{0:0.00}' -f $s.PeakDown)  ↑ $('{0:0.00}' -f $s.PeakUp) Mbps$reset")
                    } elseif (-not $s.NetRows.Count -and $s.NetAt -gt 0) { $body.Add("$gray $(NexL 'No active physical adapters.')$reset") }
                    else { $body.Add("$gray $(NexL 'Waiting for adapter counters...')$reset") }
                    $body.Add('')
                    $body.Add("$purple$(Icon 0xF0E4)  SPEEDTEST  /  Ookla$reset")
                    if ($s.SpeedInstallPending -or ($s.Job -and $s.JobKind -eq 'speed-install')) {
                        $body.Add("$pink$(Icon 0xF019) $(NexL 'Downloading and verifying Ookla Speedtest...')$reset")
                    } elseif (-not $s.SpeedPath) {
                        $bodyHits[$body.Count]=@{Kind='speed';Index='S'}
                        $body.Add("$green [S] $(Icon 0xF019) $(NexL 'Download and install Ookla Speedtest')$reset")
                        $body.Add("$gray$(NexL 'Ookla CLI not found') · $(NexL $s.SpeedStatus)$reset")
                    } else {
                        $bodyHits[$body.Count]=@{Kind='speed';Index='S'}
                        $body.Add("$bg$pink [S] $(NexL 'Start test') $reset  $gray $(SafeText (NexL $s.SpeedStatus))$reset")
                    }
                    if ($s.SpeedProc) {
                        $elapsed=[int][Math]::Floor(($clock.ElapsedMilliseconds-$s.SpeedStart)/1000)
                        $body.Add("$green● Running ($elapsed s)  $gray Live traffic above includes the test.$reset")
                        $bodyHits[$body.Count]=@{Kind='speed';Index='K'}
                        $body.Add("$pink [K] $(NexL 'Cancel test')$reset")
                    } elseif ($s.SpeedResult) {
                        $r=$s.SpeedResult
                        $body.Add("$pink ↓ $('{0:0.00}' -f $r.Down) Mbps   $blue↑ $('{0:0.00}' -f $r.Up) Mbps$reset")
                        $body.Add("$white Ping $('{0:0.0}' -f $r.Ping) ms   $gray $($r.Time)$reset")
                        $isp=ShortIsp $r.ISP
                        $body.Add((Label 'ISP (Ookla)' (Fit $isp ([Math]::Max(1,$rightWidth-22)))))
                        $body.Add((Label 'Test server' (Fit $r.Server ([Math]::Max(1,$rightWidth-22)))))
                    } else { $body.Add("$gray $(NexL 'On demand only. Measures available internet speed.')$reset") }
                    $types=@($s.NetRows | ForEach-Object {NexL $_.Type} | Select-Object -Unique)
                    $body.Add((Label 'Local connection' $(if ($types.Count) {$types -join ', '} else {NexL 'Not detected'})))
                    foreach ($n in $s.NetRows) {
                        if ($s.NetRows.Count -eq 1) { $nd=$s.UiDown; $nu=$s.UiUp }
                        else {
                            $nd=SmoothNumber ('net-rx-'+$n.Name) $n.Down 0.18
                            $nu=SmoothNumber ('net-tx-'+$n.Name) $n.Up 0.18
                        }
                        $body.Add("$pink$(Icon 0xF1EB)  $(SafeText $n.Name)  $gray$(SafeText $n.Link)$reset")
                        $body.Add((Label 'IPv4' $n.IP)); $body.Add("$white  ↓ $('{0,7:0.00}' -f $nd)  ↑ $('{0,7:0.00}' -f $nu) Mbps$reset")
                    }
                    $bodyHits[$body.Count]=@{Kind='networkAction';Index='P'}
                    $body.Add((Label '[P] Ping target' $s.PingHost)); $body.Add((Label 'Latency' (NexL $s.Ping)))
                    $hint='S Speedtest | K Cancel | P Ping host | X Stop ping | Esc Overview'
                }
                4 {
                    $loc=if ($s.Drives) {NexL 'This PC / Drives'} else {$s.Folder}
                    $bodyHits[$body.Count]=@{Kind='fileAction';Index='P'}
                    $body.Add("$purple$(SafeText $loc)$reset")
                    $body.Add("$gray $(NexL 'Filter'): $(SafeText $s.Filter) | $($s.FileItems.Count) $(NexL 'items') | $(NexL 'Sort'): $(NexL $s.FileSort) | $(NexL 'Hidden'): $(NexL ([string]$s.ShowHidden))$reset")
                    $body.Add("$muted$('─'*($rightWidth-1))$reset")
                    $canCreate=-not $s.Drives
                    $hasFile=(-not $s.Drives -and $s.FileItems.Count -gt 0)
                    $canEdit=($hasFile -and -not $s.FileItems[$s.Pos].PSIsContainer -and $s.FileItems[$s.Pos].Extension -in $textExtensions)
                    $buttons=Buttons @(@{Label='[N] New file';Kind='fileAction';Key='N';Enabled=$canCreate},@{Label='[M] Folder';Kind='fileAction';Key='M';Enabled=$canCreate},@{Label='[E] Edit';Kind='fileAction';Key='E';Enabled=$canEdit},@{Label='[Del] Trash';Kind='fileAction';Key='Delete';Enabled=$hasFile}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $buttons=Buttons @(@{Label='[D] Drives';Kind='fileAction';Key='D'},@{Label='[P] Path';Kind='fileAction';Key='P'},@{Label='[F] Find';Kind='fileAction';Key='F'},@{Label='[←] Parent';Kind='fileAction';Key='Backspace'}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $buttons=Buttons @(@{Label='[C] Copy';Kind='fileAction';Key='C';Enabled=$hasFile},@{Label='[X] Cut';Kind='fileAction';Key='X';Enabled=$hasFile},@{Label='[V] Paste';Kind='fileAction';Key='V';Enabled=($canCreate -and $null -ne $s.Clipboard)},@{Label='[F2] Rename';Kind='fileAction';Key='F2';Enabled=$hasFile}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $buttons=Buttons @(@{Label='[Space] View';Kind='fileAction';Key='Spacebar';Enabled=$hasFile},@{Label='[F3] Details';Kind='fileAction';Key='F3';Enabled=$hasFile},@{Label='[F4] Sort';Kind='fileAction';Key='F4';Enabled=$canCreate},@{Label='[H] Hidden';Kind='fileAction';Key='H';Enabled=$canCreate}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $body.Add('')
                    $take=[Math]::Max(1,$maxBody-9); $offset=[Math]::Max(0,$s.Pos-$take+1)
                    for ($i=$offset;$i -lt [Math]::Min($s.FileItems.Count,$offset+$take);$i++) {
                        $it=$s.FileItems[$i]; $ic=0xF15B; $name=$it.Name; $detail=''; $color=$white
                        if ($s.Drives) { $ic=0xF0A0; $name=$it.Root; $color=$blue }
                        elseif ($it.PSIsContainer) { $ic=0xF07B; $color=$pink; $detail=NexL 'Folder' }
                        else { $detail='{0:0.0} KiB' -f ($it.Length/1KB) }
                        $mark=if ($i -eq $s.Pos) {"$pink❯$reset$purple"} else {"$color "}
                        $bodyHits[$body.Count]=@{Kind='file';Index=$i}
                        $body.Add("$mark $(Icon $ic) $(Fit $name ([Math]::Max(8,$rightWidth-19))) $gray$detail$reset")
                    }
                    if (-not $s.FileItems.Count) { $body.Add("$gray $(NexL 'Empty, inaccessible or no matches.')$reset") }
                    if ($s.Clipboard) { $body.Add("$green Clipboard: $($s.Clipboard.Mode) $(SafeText ([IO.Path]::GetFileName($s.Clipboard.Path)))$reset") }
                    $hint='N New file | M New folder | E Edit | Del Trash | Enter Open | D Drives | P Path'
                    $extra='F2 Rename | F3 Details | F4 Sort | H Hidden | O Explorer | R Clear | Double-click Open'
                }
                5 {
                    $body.Add("$pink$(Icon 0xF05A)  $(NexL 'HARDWARE / SOFTWARE')$reset")
                    $bodyHits[$body.Count]=@{Kind='infoAction';Index='R'}; $body.Add("$purple[R]$white $(NexL 'Refresh')$reset")
                    if (-not $s.Info.Count) { $body.Add("$gray $(NexL 'Reading system information...')$reset") }
                    foreach ($line in @($s.Info | Select-Object -Skip ([int]$s.InfoPos) -First ([Math]::Max(1,$maxBody-2)))) {
                        if ($line -match '^(.+?)\s{2,}(.+)$') {$field=$Matches[1];$val=$Matches[2];$vc=$white;if ($field.Trim() -in @('Processor','GPU')) {$vc=NexAnsi (Get-NexVendorColor $val $palette[4])};$body.Add((Label $field $val $vc))} else {$body.Add("$white$(SafeText $line)$reset")}
                    }
                    $hint='Up/Down scroll | R Refresh | Esc Overview'
                }
                6 {
                    $body.Add("$pink$(Icon 0xF021)  $(NexL 'WINDOWS UPDATE CENTER')$reset"); $body.Add('')
                    $body.Add((Label 'Windows version' $s.UpdateVersion)); $body.Add((Label 'Last checked' (NexL $s.UpdateChecked)))
                    $bodyHits[$body.Count]=@{Kind='update';Index='C'}
                    $body.Add("$purple[C]$white $(NexL 'Check for updates')  $gray$reset")
                    if ($s.UpdateStatus -eq 'Checking') {
                        $spin=@('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')[[int][Math]::Floor($clock.ElapsedMilliseconds/120)%10]
                        $body.Add("$purple$spin $(NexL 'Checking Windows Update ...') $([int][Math]::Floor(($clock.ElapsedMilliseconds-$s.UpdateStart)/1000)) s$reset")
                        $body.Add("$gray $(NexL 'Windows does not report scan percentage.')$reset")
                    } else { $body.Add((Label 'Status' (NexL $s.UpdateStatus))) }
                    $body.Add('')
                    $wrapped=@(foreach ($line in $s.UpdateRows) { WrapUpdateLine (NexL $line) ($rightWidth-1) })
                    $s.UpdateDisplayCount=$wrapped.Count
                    $s.UpdatePos=[Math]::Max(0,[Math]::Min($s.UpdatePos,$wrapped.Count-1))
                    foreach ($line in @($wrapped | Select-Object -Skip $s.UpdatePos -First ([Math]::Max(1,$maxBody-$body.Count)))) {
                        $style=if ($line -match '^No regular') { $green } elseif ($line -match '^(REGULAR SOFTWARE|OPTIONAL SOFTWARE|MICROSOFT DEFENDER|UNCLASSIFIED)') { $pink } else { $white }
                        $body.Add("$style$(SafeText $line)$reset")
                    }
                    $hint='C / Enter Check | Up/Down scroll | Esc Overview'; $extra='WUA software scan only; Defender and optional updates listed separately.'
                }
                7 {
                    $body.Add("$pink$(Icon 0xF0AD)  $(NexL 'Diagnostics & network settings')$reset"); $body.Add('')
                    $toolButtons=@(
                        @{Label='[D] Disk health';Kind='tool';Key='D'},@{Label='[N] DNS servers';Kind='tool';Key='N'},
                        @{Label='[S] Service status';Kind='tool';Key='S'},@{Label='[I] IP configuration';Kind='tool';Key='I'},
                        @{Label='[E] Event Viewer';Kind='tool';Key='E'},@{Label='[T] Task Manager';Kind='tool';Key='T'},
                        @{Label='[G] Change DNS';Kind='tool';Key='G'}
                    )
                    $cols=if ($rightWidth -ge 52 -or $maxBody -lt 13) {2} else {1}
                    for ($j=0;$j -lt $toolButtons.Count;$j+=$cols) {
                        $chunk=@($toolButtons | Select-Object -Skip $j -First $cols)
                        $buttons=Buttons $chunk $rightWidth
                        $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    }
                    $body.Add(''); $body.Add("$purple$(NexL $s.ToolTitle)$reset")
                    $detail=New-Object 'System.Collections.Generic.List[string]'
                    foreach ($line in $s.ToolRows) {
                        if ($line -is [string]) {$detail.Add("$gray$(SafeText (NexL $line))$reset");continue}
                        switch ($line.Kind) {
                            'Disks' {
                                $tone=if ($line.Health -eq 'Healthy') {$green} else {$red}
                                $detail.Add("$blue$(Icon 0xF0A0)  $(SafeText $line.Name)$reset")
                                $detail.Add("  $gray$(NexL 'Health'): $tone$(NexL $line.Health)$gray | $white$(NexL $line.Status) | $purple$(SafeText $line.Media)$reset")
                            }
                            'DNS' {$detail.Add("$blue$(Icon 0xF1EB)  $(SafeText $line.Name)$gray : $green$(SafeText $line.Value)$reset")}
                            'Services' {$tone=if ($line.Value -eq 'Running') {$green} else {$gray};$detail.Add("$purple$(Icon 0xF013)  $(Fit $line.Name 16)$tone$(NexL $line.Value)$reset")}
                            'IP' {$detail.Add("$blue$(Icon 0xF1EB)  $(SafeText $line.Name)$reset");$detail.Add("  $gray IPv4: $white$(SafeText $line.Value)$reset");$detail.Add("  $gray$(NexL 'Gateway'): $green$(SafeText $line.Gateway)$reset")}
                        }
                    }
                    $s.ToolDisplayCount=$detail.Count
                    $s.ToolPos=[Math]::Max(0,[Math]::Min([int]$s.ToolPos,[Math]::Max(0,$detail.Count-1)))
                    foreach ($line in @($detail | Select-Object -Skip ([int]$s.ToolPos) -First ([Math]::Max(1,$maxBody-$body.Count)))) {$body.Add($line)}
                    $hint='Click a tool | Up/Down scroll'
                }
                8 {
                    $body.Add("$green● $(NexL 'LIVE')  $gray $(NexL $s.LogName) | $(NexL 'Last 7 days') | $(NexL 'Error / warning')$reset")
                    $buttons=Buttons @(@{Label='[A] App';Kind='logAction';Key='A'},@{Label='[S] System';Kind='logAction';Key='S'},@{Label='[B] Export';Kind='logAction';Key='B'},@{Label='[Del] Clear';Kind='logAction';Key='Delete'}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text); $body.Add('')
                    $take=[Math]::Max(1,$maxBody-4); $offset=[Math]::Max(0,$s.LogPos-$take+1)
                    for ($i=$offset;$i -lt [Math]::Min($s.Logs.Count,$offset+$take);$i++) {
                        $l=$s.Logs[$i]; $mark=if ($i -eq $s.LogPos) {"$bg$pink❯"} else {"$white "}; $color=if ($l.Level -le 2) {$red} else {$purple}
                        $bodyHits[$body.Count]=@{Kind='log';Index=$i}
                        $body.Add("$mark $gray$($l.Time.ToString('MM-dd HH:mm')) $color$(Fit $l.Id 6)$white$(SafeText $l.Source)$reset")
                    }
                    if (-not $s.Logs.Count) { $body.Add("$gray $(NexL 'No events loaded / matching events.')$reset") }
                    $hint='Enter Details | A Application | S System | B Export | Del Archive + clear'; $extra='Clear requires admin. Backup is saved in NexLogBackups.'
                }
                9 {
                    $body.Add("$pink$(Icon 0xF013)  $(NexL 'APPEARANCE & INPUT')$reset"); $bodyHits[$body.Count]=@{Kind='globalKey';Index='F1'};$body.Add("$purple[F1] $(Icon 0xF059) $(NexL 'Setting explanations')$reset")
                    $bodyHits[$body.Count]=@{Kind='setting';Index='G'}
                    $profileLabel=if ($s.Config) { if ($s.Config.Defaults) { "Defaults [$($s.Config.Edition)]" } else { "$($s.Config.Profile.name) [$($s.Config.Edition)]" } } else { 'Select profile' }
                    $body.Add((SettingLine '[G] Profile' $profileLabel $rightWidth))
                    $body.Add('')
                    $opacityLabel=if ($s.Config) { '{0}%' -f (Effective 'opacity' 100) } else { 'Not detected' }
                    $bodyHits[$body.Count]=@{Kind='setting';Index='O'}
                    $body.Add((SettingLine '[O] Opacity' (NexL $opacityLabel) $rightWidth $pink))
                    $presetLine=''; $currentOpacity=if ($s.Config) { [int](Effective 'opacity' 100) } else { -1 }
                    foreach ($pct in @(50,60,70,80,90,100)) {
                        $style=if ($pct -eq $currentOpacity) { "$bg$pink" } else { "$purple" }
                        $presetLine+=$style+('[{0,3}%]' -f $pct)+$reset+' '
                    }
                    $bodyHits[$body.Count]=@{Kind='opacityPreset';Index=0}
                    $body.Add($presetLine)
                    $body.Add('')
                    $bodyHits[$body.Count]=@{Kind='setting';Index='A'}
                    $acrylic=Effective 'useAcrylic' 'Not detected';$acrylicText=if ($acrylic -is [bool]) {if ($acrylic) {'Enabled'} else {'Disabled'}} else {[string]$acrylic};$body.Add((SettingLine '[A] Acrylic' (NexL $acrylicText) $rightWidth))
                    $bodyHits[$body.Count]=@{Kind='setting';Index='C'}
                    $body.Add((SettingLine '[C] Cursor' (NexL (Effective 'cursorShape' 'bar')) $rightWidth))
                    $body.Add('')
                    if ($s.Config) {
                        if ($s.Config.Defaults) {
                            $body.Add("$pink $(NexL 'All profiles share appearance.')$reset")
                        } elseif (-not $env:WT_PROFILE_ID) {
                            $body.Add("$pink $(NexL 'All profiles share appearance.')$reset")
                        } else {
                            $body.Add("$green $(NexL 'Profile identified. Click a value or preset.')$reset")
                        }
                        $body.Add("$gray $(NexL 'All profiles share appearance. Reopen tabs if needed.')$reset")
                    } else { $body.Add("$red$(SafeText $s.ConfigError)$reset") }
                    $hint='Click values | G Profile | O Opacity | J JSON | Ctrl+, Native settings' 
                }
                10 {
                    $body.Add("$pink$(Icon 0xF1DE)  $(NexL 'Appearance, startup and language')$reset")
                    $body.Add('')
                    $bodyHits[$body.Count]=@{Kind='public';Index='G'};$body.Add((SettingLine '[G] Setting explanations' (NexL $(if ($prefs.SettingHelp) {'Enabled'} else {'Disabled'})) $rightWidth $(if ($prefs.SettingHelp) {$green} else {$gray})))
                    $bodyHits[$body.Count]=@{Kind='public';Index='A'};$body.Add((SettingLine '[A] Sidebar separators' (NexL $(if ($prefs.SidebarSeparators) {'Enabled'} else {'Disabled'})) $rightWidth $(if ($prefs.SidebarSeparators) {$green} else {$gray})))
                    $bodyHits[$body.Count]=@{Kind='globalKey';Index='F1'};$body.Add("$pink[F1] $(Icon 0xF05A) $(NexL 'Help')$reset")
                    $rowsPrefs=@(
                        @('L','Language',@{en='English';ru='Русский';de='Deutsch'}[$prefs.Language]),
                        @('N','Display name',(Get-NexName)),
                        @('M','Show computer name',$(if ($prefs.ShowComputerName) {'Enabled'} else {'Disabled'})),
                        @('D','Computer alias',$(if ($prefs.ComputerAlias) {$prefs.ComputerAlias} else {$env:COMPUTERNAME})),@('H','Theme',$prefs.Theme),@('X','Custom accent',('#'+$prefs.Accent)),
                        @('B','Startup screen',$(if ($prefs.Startup) {'Enabled'} else {'Disabled'})),
                        @('C','Clear screen on return',$(if ($prefs.ClearOnReturn) {'Enabled'} else {'Disabled'})),
                        @('U','Loading on return',$(if ($prefs.LoadingOnReturn) {'Enabled'} else {'Disabled'})),
                        @('F','Startup info',$(if ($prefs.Fetch) {'Enabled'} else {'Disabled'})),@('J','Fetch animation',$(if ($prefs.FetchAnimation) {'Enabled'} else {'Disabled'})),@('V','Fetch preset',$prefs.FetchPreset),
                        @('K','Custom logo',$(if ($prefs.CustomLogo) {'Enabled'} else {'Default logo'})),
                        @('P','Prompt style',$prefs.Prompt),@('I','Icons',$(if ($prefs.Icons) {'Enabled'} else {'Disabled'})),
                        @('Q','Prediction',$prefs.Prediction)
                    )
                    $glyphs=@{L=0xF0AC;N=0xF007;M=0xF108;D=0xF109;H=0xF1FC;X=0xF1FB;B=0xF0D0;C=0xF12D;U=0xF021;F=0xF05A;J=0xF04B;V=0xF009;K=0xF1FC;P=0xF120;I=0xF1C5;Q=0xF0EB;A=0xF1EB}
                    $groups=@{L='Identity and language';H='Colors and appearance';B='Startup and transitions';F='Startup information';P='Prompt and input'}
                    foreach ($entry in $rowsPrefs) {
                        if ($groups.ContainsKey($entry[0])) {
                            $body.Add('');$body.Add("$pink$(NexL $groups[$entry[0]])$reset")
                            $body.Add("$muted$('─'*[Math]::Min(44,$rightWidth))$reset")
                        }
                        $bodyHits[$body.Count]=@{Kind='public';Index=$entry[0]}
                        $value=if ($entry[0] -in @('N','D')) {$entry[2]} else {NexL ([string]$entry[2])}
                        $tone=if ($entry[2] -eq 'Enabled') {$green} elseif ($entry[2] -eq 'Disabled') {$gray} else {$white}
                        $body.Add((SettingLine ('['+$entry[0]+'] '+$entry[1]) $value $rightWidth $tone $glyphs[$entry[0]]))
                    }
                    $bodyHits[$body.Count]=@{Kind='public';Index='O'};$body.Add("$pink[O] $(Icon 0xF0AD) $(NexL 'Restore icons and font')$reset")
                    $body.Add('');$body.Add("$purple$(NexL 'Identity preview'): $pink$(SafeText (Get-NexIdentity))$reset")
                    $body.Add('');$body.Add("$pink$(NexL 'Terminal appearance and backup')$reset")
                    $body.Add("$muted$('─'*[Math]::Min(44,$rightWidth))$reset")
                    $bodyHits[$body.Count]=@{Kind='public';Index='Y'};$body.Add("$pink[Y] $(Icon 0xF1FC) $(NexL 'Apply terminal palette')$reset")
                    $bodyHits[$body.Count]=@{Kind='public';Index='E'};$body.Add("$pink[E] $(Icon 0xF06E) $(NexL 'Preview fetch')$reset")
                    $bodyHits[$body.Count]=@{Kind='public';Index='Z'};$body.Add("$pink[Z] $(Icon 0xF1FC) $(NexL 'Choose terminal color')$reset")
                    $bodyHits[$body.Count]=@{Kind='public';Index='T'};$body.Add("$pink[T] $(Icon 0xF013) $(NexL 'Native color scheme')$reset")
                    $ffReady=if ($fetchState.Available) {NexL 'Installed'} else {NexL 'Not installed'}
                    $body.Add("$gray Fastfetch: $ffReady$reset")
                    $backupButtons=Buttons @(@{Label='[S] Export';Kind='public';Key='S'},@{Label='[R] Restore';Kind='public';Key='R'}) ([Math]::Min($rightWidth,54))
                    $bodyHits[$body.Count]=$backupButtons;$body.Add($backupButtons.Text)
                    $hint='S Export | R Restore | Esc Overview'
                }
            }
        }
        if ($s.Page -ge 11 -and -not $menuOnly -and -not $s.Preview) {
            RenderExtra $body $bodyHits
            $s.ExtraMax=[Math]::Max(0,$body.Count-$maxBody)
            $s.ExtraPos=[Math]::Max(0,[Math]::Min($s.ExtraMax,$s.ExtraPos))
            if ($s.ExtraMax -gt 0) {
                $offset=$s.ExtraPos;$newHits=@{};$newBody=New-Object 'System.Collections.Generic.List[string]'
                for ($i=$offset;$i -lt [Math]::Min($body.Count,$offset+$maxBody);$i++) {
                    $newBody.Add($body[$i]);if ($bodyHits.ContainsKey($i)) {$newHits[$i-$offset]=$bodyHits[$i]}
                }
                $body=$newBody;$bodyHits=$newHits
            }
            $hint=(NexL 'Scroll for more settings')+' | '+($s.ExtraPos+1)+'/'+($s.ExtraMax+1)
        }
        if ($s.Page -eq 10 -and -not $menuOnly -and -not $s.Preview) {
            $s.PersonalMax=[Math]::Max(0,$body.Count-$maxBody)
            $s.PersonalPos=[Math]::Max(0,[Math]::Min($s.PersonalMax,$s.PersonalPos))
            if ($s.PersonalMax -gt 0) {
                $offset=$s.PersonalPos;$newHits=@{};$newBody=New-Object 'System.Collections.Generic.List[string]'
                for ($i=$offset;$i -lt [Math]::Min($body.Count,$offset+$maxBody);$i++) {
                    $newBody.Add($body[$i]);if ($bodyHits.ContainsKey($i)) {$newHits[$i-$offset]=$bodyHits[$i]}
                }
                $body=$newBody;$bodyHits=$newHits
                $hint=(NexL 'Scroll for more settings')+' | '+($offset+1)+'/'+($s.PersonalMax+1)
            }
        }
        $rows=New-Object 'System.Collections.Generic.List[string]'; $hits=New-Object 'System.Collections.Generic.List[object]'
        $accentName=(NexL $prefs.Theme).ToUpperInvariant()
        $header="$pink  $(SafeText (Get-NexName))   /   D A S H B O A R D   2.6.2   $purple / $accentName   $gray • $(Get-Date -Format 'HH:mm:ss')$reset"
        $modules=@(NexHeaderModules)
        $headLen=Get-NexLogoWidth ([regex]::Replace($header,'\x1b\[[0-9;]*m',''))
        $wantedWidth=0
        foreach ($module in $modules) {$wantedWidth+=(Get-NexLogoWidth ([regex]::Replace($module.Text,'\x1b\[[0-9;]*m','')))+3}
        if ($modules.Count -and $headLen+$wantedWidth -gt $w-1) {
            $header="$pink $(SafeText (Get-NexName)) / DASHBOARD 2.6.2 $purple / $accentName $gray • $(Get-Date -Format 'HH:mm:ss')$reset"
            $headLen=Get-NexLogoWidth ([regex]::Replace($header,'\x1b\[[0-9;]*m',''))
        }
        $kept=@();$moduleWidth=0
        foreach ($module in $modules) {
            $length=Get-NexLogoWidth ([regex]::Replace($module.Text,'\x1b\[[0-9;]*m',''))
            $gap=if ($kept.Count) {3} else {0}
            if ($headLen+2+$moduleWidth+$gap+$length -le $w-1) {$kept+=@(@{Text=$module.Text;Page=$module.Page;Length=$length});$moduleWidth+=$gap+$length}
        }
        if ($kept.Count) {
            $header+=' '*[Math]::Max(2,$w-1-$headLen-$moduleWidth)
            $pos=$w-1-$moduleWidth
            for ($mi=0;$mi -lt $kept.Count;$mi++) {
                if ($mi) {$header+="$muted │ $reset";$pos+=3}
                $part=$kept[$mi];$header+=$part.Text
                $hits.Add(@{Y=0;X1=$pos;X2=($pos+$part.Length);Kind='nav';Index=$part.Page});$pos+=$part.Length
            }
        }
        $rows.Add($header)
        $rows.Add("$muted$('─'*($w-1))$reset")
        $rows.Add("$purple  $(Icon $codes[$s.Page])  $heading$reset")
        $rows.Add('')
        for ($i=0;$i -lt $maxBody;$i++) {
            $b=if ($i -lt $body.Count) {$body[$i]} else {''}
            if ($wide) {
                if ($i+$navOffset -lt $navVisual.Count) {
                    $ni=$navVisual[$i+$navOffset]
                    if ($ni -eq -1) {
                        $navText="$muted  $('─'*($leftWidth-4))  $reset"
                    } else {
                        $active=($ni -eq $s.Page); $focus=($s.Focus -eq 'nav' -and $ni -eq $s.Nav)
                        $prefix=if ($focus) {"$bg$pink ❯"} elseif ($active) {"$purple ●"} else {"$gray  "}
                        $navText="$prefix $(Icon $codes[$ni]) $(Fit $names[$ni] ($leftWidth-5))$reset"
                        $hits.Add(@{Y=$i+4;X1=0;X2=$leftWidth;Kind='nav';Index=$ni})
                    }
                } else { $navText=' '*$leftWidth }
                $rows.Add("$navText$muted │ $reset$(ClipAnsi $b $rightWidth)")
                if ($bodyHits.ContainsKey($i)) {
                    $hit=$bodyHits[$i]
                    $bodyX=$leftWidth+3
                    if ($hit.Kind -eq 'opacityPreset') {
                        for ($pi=0;$pi -lt 6;$pi++) {
                            $px=$bodyX+7*$pi
                            $hits.Add(@{Y=$i+4;X1=$px;X2=$px+6;Kind='opacityPreset';Index=(50+10*$pi)})
                        }
                    } elseif ($hit.Kind -eq 'buttons') {
                        foreach ($bHit in $hit.Targets) { $hits.Add(@{Y=$i+4;X1=$bodyX+$bHit.From;X2=[Math]::Min($w-1,$bodyX+$bHit.To);Kind=$bHit.Kind;Index=$bHit.Index}) }
                    } else { $hits.Add(@{Y=$i+4;X1=$bodyX;X2=$w-1;Kind=$hit.Kind;Index=$hit.Index}) }
                }
            } else {
                $rows.Add("  $(ClipAnsi $b $rightWidth)")
                if ($bodyHits.ContainsKey($i)) {
                    $hit=$bodyHits[$i]
                    $bodyX=2
                    if ($hit.Kind -eq 'opacityPreset') {
                        for ($pi=0;$pi -lt 6;$pi++) {
                            $px=$bodyX+7*$pi
                            $hits.Add(@{Y=$i+4;X1=$px;X2=$px+6;Kind='opacityPreset';Index=(50+10*$pi)})
                        }
                    } elseif ($hit.Kind -eq 'buttons') {
                        foreach ($bHit in $hit.Targets) { $hits.Add(@{Y=$i+4;X1=$bodyX+$bHit.From;X2=[Math]::Min($w-1,$bodyX+$bHit.To);Kind=$bHit.Kind;Index=$bHit.Index}) }
                    } else { $hits.Add(@{Y=$i+4;X1=$bodyX;X2=$w-1;Kind=$hit.Kind;Index=$hit.Index}) }
                }
            }
        }
        # Two footer rows. Never write into the last cell of the viewport.
        $rows.Add("$muted$('─'*($w-1))$reset")
        $foot=if ($s.Msg) {"$pink $($s.Msg)$reset"} else {"$gray $(NexL $hint)$reset"}
        $rows.Add((ClipAnsi $foot ($w-1)))
        $footerButtons=if ($s.Page -eq 3 -and -not $s.Preview) {
            @(@{Label='[ Back ]';Kind='globalKey';Key='Escape'},@{Label='[ Menu ]';Kind='globalKey';Key='Menu'},@{Label='[ Stop ping ]';Kind='networkAction';Key='X'})
        } elseif ($s.Page -eq 4 -and -not $s.Preview) {
            @(@{Label='[ Back ]';Kind='globalKey';Key='Escape'},@{Label='[ Menu ]';Kind='globalKey';Key='Menu'},@{Label='[ Explorer ]';Kind='fileAction';Key='O';Enabled=(-not $s.Drives)},@{Label='[ Clear filter ]';Kind='fileAction';Key='R'})
        } elseif ($s.Page -eq 10 -and -not $s.Preview) {
            @(@{Label='[ Back ]';Kind='globalKey';Key='Escape'},@{Label='[ Menu ]';Kind='globalKey';Key='Menu'},@{Label='[ Export ]';Kind='public';Key='S'},@{Label='[ Restore ]';Kind='public';Key='R'})
        } elseif ($s.Page -eq 9) {
            @(@{Label='[ Back ]';Kind='globalKey';Key='Escape'},@{Label='[ Menu ]';Kind='globalKey';Key='Menu'},@{Label='[ JSON ]';Kind='setting';Key='J'},@{Label='[ Refresh ]';Kind='setting';Key='R'})
        } else { @(@{Label='[ Back ]';Kind='globalKey';Key='Escape'},@{Label='[ Menu ]';Kind='globalKey';Key='Menu'}) }
        $footButtons=Buttons $footerButtons ([Math]::Min($w-1,64))
        $rows.Add((ClipAnsi ("$($footButtons.Text)$gray $(NexL $extra)$reset") ($w-1)))
        foreach ($fh in $footButtons.Targets) { $hits.Add(@{Y=$rows.Count-1;X1=$fh.From;X2=$fh.To;Kind=$fh.Kind;Index=$fh.Index}) }
        $size="${w}x${h}"; $frame=''
        if ($s.Size -ne $size) { $frame+="$e[2J"; $s.Old=@(); $s.Size=$size }
        for ($i=0;$i -lt [Math]::Min($rows.Count,$h);$i++) {
            $line=ClipAnsi $rows[$i] ($w-1)
            if ($i -ge $s.Old.Count -or $s.Old[$i] -cne $line) { $row=$i+1; $frame+="$e[${row};1H$line$reset$e[K" }
            $rows[$i]=$line
        }
        if ($frame) { Write-Host $frame -NoNewline }
        $s.Old=$rows.ToArray(); $s.Hits=$hits.ToArray()
    }
    function ClipAnsi([string]$line,[int]$width) {
        if ($width -le 0) { return '' }
        $plain=[regex]::Replace($line,'\x1b\[[0-9;]*m','')
        if ($plain.Length -le $width -and $plain -notmatch '[\u1100-\u115F\u2E80-\uA4CF\uAC00-\uD7A3\uD800-\uDFFF\uF900-\uFAFF\uFE10-\uFE6F\uFF00-\uFF60]') { return ($line+$reset) }
        $sb=New-Object System.Text.StringBuilder; $n=0
        foreach ($m in [regex]::Matches($line,'\x1b\[[0-9;]*m|[^\x1b]+|.')) {
            if ($m.Value.StartsWith([string]$e)) { $null=$sb.Append($m.Value); continue }
            $en=[Globalization.StringInfo]::GetTextElementEnumerator($m.Value)
            while ($en.MoveNext()) {
                $g=$en.GetTextElement(); $cp=[char]::ConvertToUtf32($g,0)
                $cells=1
                if (($cp -ge 0x1100 -and $cp -le 0x115F) -or ($cp -ge 0x2E80 -and $cp -le 0xA4CF) -or ($cp -ge 0xAC00 -and $cp -le 0xD7A3) -or ($cp -ge 0xF900 -and $cp -le 0xFAFF) -or ($cp -ge 0xFE10 -and $cp -le 0xFE6F) -or ($cp -ge 0xFF00 -and $cp -le 0xFF60) -or ($cp -ge 0x1F300 -and $cp -le 0x1FAFF) -or ($cp -ge 0x20000 -and $cp -le 0x3FFFD)) { $cells=2 }
                if ($n+$cells -gt $width) { return ($sb.ToString()+$reset) }
                $null=$sb.Append($g); $n+=$cells
            }
        }
        return ($sb.ToString()+$reset)
    }
    function ScrollPos([string]$key,[int]$pos,[int]$count) {
        $delta=if ($key -eq 'UpArrow') {-1} elseif ($key -eq 'DownArrow') {1} elseif ($key -eq 'PageUp') {-8} elseif ($key -eq 'PageDown') {8} else {0}
        [Math]::Max(0,[Math]::Min([Math]::Max(0,$count-1),$pos+$delta))
    }
    $s.Job=$null; $s.Worker=$null; $s.Preview=$null; $s.ProcPos=0; $s.InfoPos=0; $s.ToolPos=0; $s.ToolDisplayCount=0; $s.PingNext=0L
    $s.LogLoaded=$false; $lastClock=-1; $lastTheme=-1; $running=$true
    try {
        Write-Host "$e[?1049h$e[?25l$e[2J$e[H" -NoNewline
        while ($running) {
            PollWorker
            if ($s.SpeedInstallPending -and -not $s.Job) {
                $s.SpeedInstallPending=$false
                StartWorker 'speed-install' ([scriptblock]::Create((Get-Command Install-NexSpeedtest -CommandType Function).Definition))
                if (-not $s.Job) {$s.SpeedStatus='Speedtest installation failed';$s.Need=$true}
            }
            if ($s.PendingInstaller) {$running=$false;break}
            if ($s.OnlineReady) {
                $s.OnlineReady=$false
                if ($s.Page -eq 14 -and -not $s.Preview) {try {StartNexOnlineDownload} catch {Notice $_.Exception.Message}}
            }
            PollSpeedTest
            $now=$clock.ElapsedMilliseconds
            if ($lastClock -ne [int][Math]::Floor($now/1000)) { $lastClock=[int][Math]::Floor($now/1000); $s.Need=$true }
            $themeKey="$($prefs.Theme)/$($prefs.Accent)/$($prefs.Language)/$($prefs.Icons)"
            if ($lastTheme -ne $themeKey) {
                $lastTheme=$themeKey;$palette=Get-NexPalette
                $pink=NexAnsi $palette[0];$purple=NexAnsi $palette[1];$bg=NexAnsi $palette[2] -Background;$white=NexAnsi $palette[4];$gray=NexAnsi $palette[5]
                $names=@('Overview','System Monitor','Processes','Network','File Explorer','System Info','Windows Update','Quick Tools','System Logs','Terminal Settings','Personalization','Hardware Info','Gaming Mode','App Launcher','Update Center','System Health','Notification Center','Dashboard Designer','Startup Manager','Plugin Manager','Animation Studio') | ForEach-Object {NexL $_}
                ResetDraw
            }
            if (-not $s.Job -and -not $s.Preview -and $now -ge $s.HealthNext -and $s.Page -notin @(3,6,7,14)) {
                StartWorker 'health' $healthScript; $s.HealthNext=$now+60000
            }
            if ($now -ge $s.Next -and -not $s.Preview) {
                switch ($s.Page) {
                    { $_ -in @(0,1) } { if (-not $s.Job) { StartWorker 'overview' $overviewScript ([int]($s.Page -eq 1)); $s.Next=$now+1500 } }
                    2 { SampleProcesses; if (-not $s.Job -and ($null -eq $s.ProcMetrics -or ($now-$s.ProcMetricsAt) -ge 3000)) {StartWorker 'process-metrics' $procMetricsScript}; $s.Next=$now+1000 }
                    3 {
                        if (-not $s.Job) {
                            if ($s.PingHost -and $now -ge $s.PingNext) { StartWorker 'ping' $pingScript $s.PingHost; $s.PingNext=$now+4500; $s.Next=$now+200 }
                            else { StartWorker 'network' $netScript; $s.Next=$now+$(if ($s.NetFast) {2500} else {1200}) }
                        }
                    }
                    4 { RefreshFiles; $s.Next=$now+1800 }
                    5 { if (-not $s.Job -and -not $s.Info.Count) { StartWorker 'info' $infoScript; $s.Next=$now+10000 } else { $s.Next=$now+1000 } }
                    8 { if (-not $s.Job) { StartWorker 'logs' $logScript $s.LogName; $s.Next=$now+6000 } }
                    9 { ReadConfig; $s.Next=$now+10000 }
                    11 {if (-not $s.Job -and $null -eq $s.Hardware -and -not $s.ExtraErrors.ContainsKey('hardware')) {StartWorker 'hardware' $hardwareScript};$s.Next=$now+2000}
                    12 {if (-not $s.Job) {StartWorker 'gaming' $gamingScript};$s.Next=$now+8000}
                    13 {if (-not $s.Job -and $null -eq $s.Apps -and -not $s.ExtraErrors.ContainsKey('apps')) {StartWorker 'apps' $appsScript};$s.Next=$now+2000}
                    14 {$s.Next=$now+2000}
                    15 {$s.Next=$now+2000}
                    18 {if (-not $s.Job -and $null -eq $s.StartupRows -and -not $s.ExtraErrors.ContainsKey('startup')) {StartWorker 'startup' $startupScript};$s.Next=$now+2000}
                    16 {if (-not $s.Job -and $now -ge $s.AlertSampleNext) {StartWorker 'overview' $overviewScript 1;$s.AlertSampleNext=$now+8000};$s.Next=$now+1000}
                    default { $s.Next=$now+2000 }
                }
                $s.Need=$true
            }
            $size="$([Console]::WindowWidth)x$([Console]::WindowHeight)"
            if ($s.Page -eq 3) { SampleFastNetwork }
            $now=$clock.ElapsedMilliseconds
            if ($s.Page -in @(0,1,2,3) -and -not $s.Preview -and $now -ge $s.AnimAt) {
                if ($s.Page -eq 3) { AnimateTraffic }
                $s.AnimAt=$now+33
                $s.Need=$true
            }
            if ($s.Page -eq 6 -and $s.UpdateStatus -eq 'Checking' -and $now -ge $s.AnimAt) { $s.AnimAt=$now+120; $s.Need=$true }
            if ($s.Need -or $s.Size -ne $size) { Render; $s.Need=$false }
            $event=InputEvent
            if (-not $event) { Start-Sleep -Milliseconds 12; continue }
            $key=$event.Key; $s.Msg=''; $s.Need=$true
            if ($event.Ctrl -and $key -eq 'K') {try {SearchNexDashboard} catch {Notice $_.Exception.Message};continue}
            if ($event.Wheel -and -not $s.Preview) {
                if ($s.Page -eq 1) { $s.Focus='body' } elseif ([Console]::WindowWidth -ge 88) { $s.Focus=if ($event.X -lt 25) {'nav'} else {'body'} }
            }
            if ($key -eq 'Click') {
                $routed=$false
                foreach ($hit in $s.Hits) {
                    if ($hit.Y -eq $event.Y -and $event.X -ge $hit.X1 -and $event.X -lt $hit.X2) {
                        if ($hit.Kind -eq 'globalKey') {
                            if ($hit.Index -eq 'Menu') { $s.Preview=$null; $s.Focus='nav'; $s.Nav=$s.Page }
                            else { $key=$hit.Index; $routed=$true }
                        }
                        elseif ($hit.Kind -eq 'previewBack') { $s.Preview=$null }
                        elseif ($hit.Kind -in @('processAction','networkAction','infoAction')) { $s.Focus='body'; $key=$hit.Index; $routed=$true }
                        elseif ($hit.Kind -eq 'nav') { $s.Preview=$null; ChoosePage $hit.Index }
                        elseif ($hit.Kind -eq 'file') {
                            $s.Pos=$hit.Index; $s.Focus='body'
                            if ($s.FileItems.Count -gt $s.Pos) {
                                $id="$($s.Folder)|$($s.Drives)|$($s.FileItems[$s.Pos].Name)"
                                if ($id -eq $s.LastFileClick -and $now-$s.LastFileAt -lt 450) { $s.LastFileClick=''; OpenFile }
                                else { $s.LastFileClick=$id; $s.LastFileAt=$now }
                            }
                        }
                        elseif ($hit.Kind -in @('fileAction','tool','logAction','update')) {
                            $s.Focus='body'
                            try {
                                switch ($hit.Kind) {
                                    'fileAction' { if ($hit.Index -eq 'Backspace') { ParentFolder } else { FileAction $hit.Index } }
                                    'tool' { ToolAction $hit.Index }
                                    'logAction' { LogAction $hit.Index }
                                    'update' { UpdateAction $hit.Index }
                                }
                            } catch { Notice $_.Exception.Message }
                        }
                        elseif ($hit.Kind -eq 'log') {
                            $s.LogPos=$hit.Index; $s.Focus='body'
                            $logId="log|$($s.LogName)|$($hit.Index)"
                            if ($s.LastFileClick -eq $logId -and $now-$s.LastFileAt -lt 450) { $s.LastFileClick=''; LogAction 'Enter' }
                            else { $s.LastFileClick=$logId; $s.LastFileAt=$now }
                        }
                        elseif ($hit.Kind -eq 'speed') {
                            $s.Focus='body'
                            if ($hit.Index -eq 'S') { StartSpeedTest } else { StopSpeedTest }
                        }
                        elseif ($hit.Kind -eq 'installer') { $s.Focus='body'; try { SelectNexInstaller } catch { Notice $_.Exception.Message }; if ($s.PendingInstaller) {$running=$false} }
                        elseif ($hit.Kind -eq 'extra') { $s.Focus='body'; try { ExtraAction $hit.Index } catch { Notice $_.Exception.Message }; if ($s.PendingInstaller) {$running=$false} }
                        elseif ($hit.Kind -eq 'public') { $s.Focus='body'; try { PublicAction $hit.Index } catch { Notice $_.Exception.Message } }
                        elseif ($hit.Kind -eq 'setting') {
                            $s.Focus='body'
                            try { SettingsAction $hit.Index } catch { Notice $_.Exception.Message }
                        }
                        elseif ($hit.Kind -eq 'opacityPreset') {
                            $s.Focus='body'
                            try {
                                if (-not $s.Config) { SelectTerminalProfile }
                                if ($s.Config) { SetTerminalProperty 'opacity' ([int]$hit.Index) }
                            } catch { Notice $_.Exception.Message }
                        }
                        break
                    }
                }
                if (-not $routed) { continue }
            }
            if ($key -eq 'Search') {try {SearchNexDashboard} catch {Notice $_.Exception.Message};continue}
            if ($key -eq 'F1') {ShowNexSettingsHelp;continue}
            if ($s.Preview) {
                if ($key -eq 'Escape') { $s.Preview=$null }
                else { $s.Preview.Pos=ScrollPos $key $s.Preview.Pos $s.Preview.Lines.Count }
                continue
            }
            if ($key -eq 'Tab') { if ($s.Focus -eq 'nav') {$s.Focus='body'} else {$s.Focus='nav';$s.Nav=$s.Page}; continue }
            if ($key -eq 'Escape') {
                if ($s.Page -eq 0) { $running=$false }
                else { ChoosePage 0; $s.Focus='nav' }
                continue
            }
            if ($s.Focus -eq 'nav') {
                $navIndex=[array]::IndexOf($navOrder,[int]$s.Nav)
                if ($navIndex -lt 0) {$navIndex=0}
                if ($key -eq 'UpArrow') { $s.Nav=$navOrder[($navIndex+$navOrder.Count-1)%$navOrder.Count] }
                elseif ($key -eq 'DownArrow') { $s.Nav=$navOrder[($navIndex+1)%$navOrder.Count] }
                elseif ($key -eq 'Enter') { ChoosePage $s.Nav }
                elseif ($key -eq 'RightArrow') { $s.Focus='body' }
                continue
            }
            try {
                switch ($s.Page) {
                    0 { if ($key -eq 'Enter') { $s.Focus='nav' } elseif ($key -eq 'I') {SelectNexInstaller;if ($s.PendingInstaller) {$running=$false}} }
                    1 { $s.MonitorPos=ScrollPos $key $s.MonitorPos ($s.MonitorMax+1) }
                    2 {
                        switch ($key) {
                            'C' { $s.ProcSort='CPU'; $s.ProcPos=0 }
                            'M' { $s.ProcSort='RAM'; $s.ProcPos=0 }
                            'G' { $s.ProcSort='GPU'; $s.ProcPos=0 }
                            'D' { $s.ProcSort='IO'; $s.ProcPos=0 }
                            'N' { $s.ProcSort='TCP'; $s.ProcPos=0 }
                            'F' { $v=Ask 'Process name'; if ($v) { $s.ProcFilter=$v; $s.ProcPos=0 } }
                            'R' { $s.ProcFilter=''; $s.ProcPos=0 }
                            'T' { Start-Process taskmgr.exe }
                            default { $s.ProcPos=ScrollPos $key $s.ProcPos $s.ProcRows.Count }
                        }
                    }
                    3 {
                        if ($key -eq 'S') { StartSpeedTest }
                        elseif ($key -eq 'K') { if ($s.SpeedProc) { StopSpeedTest } }
                        elseif ($key -eq 'P') {
                            $v=Ask 'Ping host or IP address (e.g. 1.1.1.1)'
                            if ($v) { if ([Uri]::CheckHostName($v) -eq [UriHostNameType]::Unknown) { Notice 'Invalid host.' } else { $s.PingHost=$v; $s.Ping='Waiting...'; $s.PingNext=0; $s.Next=0 } }
                        } elseif ($key -eq 'X') { $s.PingHost=''; $s.Ping='Stopped' }
                    }
                    4 {
                        if ($key -in @('UpArrow','DownArrow','PageUp','PageDown')) { $s.Pos=ScrollPos $key $s.Pos $s.FileItems.Count }
                        elseif ($key -in @('Backspace','LeftArrow')) { ParentFolder }
                        elseif ($key -in @('Enter','RightArrow')) { OpenFile }
                        else { FileAction $key }
                    }
                    5 {
                        if ($key -eq 'R') { $s.Info=@(); $s.InfoPos=0; $s.Next=0 }
                        else { $s.InfoPos=ScrollPos $key $s.InfoPos $s.Info.Count }
                    }
                    6 { UpdateAction $key }
                    7 { ToolAction $key }
                    8 { LogAction $key }
                    9 { SettingsAction $key }
                    10 { if ($key -in @('UpArrow','DownArrow','PageUp','PageDown')) {$s.PersonalPos=ScrollPos $key $s.PersonalPos ($s.PersonalMax+1)} else {PublicAction $key} }
                    {$_ -ge 11} {if ($key -in @('UpArrow','DownArrow','PageUp','PageDown')) {$s.ExtraPos=ScrollPos $key $s.ExtraPos ($s.ExtraMax+1)} else {ExtraAction $key};if ($s.PendingInstaller) {$running=$false}}
                }
            } catch { Notice $_.Exception.Message }
        }
    } finally {
        $returnPrefs=$null
        $clearReturn=$false
        try {
            if ($s.SpeedProc) { StopSpeedTest }
            try { if ($s.Job -and $s.Worker) { $s.Worker.Stop() } } catch {}
            if ($s.Worker) { $s.Worker.Dispose() }
            if ($s.OnlineTemp -and -not $s.PendingInstaller) {Remove-Item -LiteralPath $s.OnlineTemp -Force -ErrorAction SilentlyContinue}
            PauseMouse
            # Finish the animation in the Dashboard buffer. Do not reveal the old
            # primary screen until the transition is ready.
            if (-not $running) {
                $global:NexPublicSettings=Get-NexPreferences
                $returnPrefs=$global:NexPublicSettings
                $clearReturn=[bool]$returnPrefs.ClearOnReturn
                if ($returnPrefs.LoadingOnReturn -and -not $s.PendingInstaller) {
                    try {Show-NexLoadingScreen -InAlternateBuffer} catch {}
                }
            }
        } finally {
            if ($clearReturn) {
                # One write: switch buffers, erase the old visible screen, home
                # the cursor, then show it. Never clear PSReadLine history.
                Write-Host "$reset$e[?1049l$e[2J$e[H$e[?25h" -NoNewline
            } else {
                Write-Host "$reset$e[?1049l$e[?25h" -NoNewline
            }
        }
    }
    if ($s.PendingInstaller) {
        # Local or official online installer; both explicitly confirmed.
        try {
            if ($s.PendingHash -and (Get-FileHash -LiteralPath $s.PendingInstaller -Algorithm SHA256 -ErrorAction Stop).Hash -ne $s.PendingHash) {throw (NexL 'Update integrity check failed.')}
            Unblock-File -LiteralPath $s.PendingInstaller -ErrorAction Stop
            & $s.PendingInstaller -Install
            if ($global:NexPublicVersion -and ([version]$global:NexPublicVersion -ge $s.PendingVersion)) {
                $global:NexDashboardReloadRequested=$true
            } else {
                Write-Warning (NexL 'After installation, reopen PowerShell to load the new version.')
            }
        } catch {Write-Warning ((NexL 'Update failed')+': '+$_.Exception.Message)}
        finally {if ($s.OnlineTemp) {Remove-Item -LiteralPath $s.OnlineTemp -Force -ErrorAction SilentlyContinue}}
        return
    }
    # Normal exit only: render fresh startup information once on the main screen.
    if (-not $running -and $returnPrefs -and $clearReturn -and $returnPrefs.Fetch) {
        $oldAnimation=$returnPrefs.FetchAnimation
        try {
            if (-not $returnPrefs.LoadingOnReturn) {$returnPrefs.FetchAnimation=$false}
            Show-NexPublicFetch
        } finally {$returnPrefs.FetchAnimation=$oldAnimation}
    }
}

# Public monitor is now shared by all users; legacy NexMonitor.ps1 is left on disk.
function global:monitor {param([switch]$InDashboard) dashboard -StartPage 1}

# Stable dispatch loop. An update closes the old view and invokes the new definition
# after its worker and alternate buffer have been released. No new terminal process.
function global:dashboard {
    param([ValidateRange(0,20)][int]$StartPage=0)
    $page=$StartPage
    do {
        $global:NexDashboardReloadRequested=$false
        & (Get-Command Invoke-NexDashboard -CommandType Function -ErrorAction Stop).ScriptBlock -StartPage $page
        $page=14
    } while ($global:NexDashboardReloadRequested)
}
$global:NexPublicVersion='2.6.2'
