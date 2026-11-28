param([switch]$Install,[switch]$Uninstall,[string]$OpenEditor='',[switch]$RegisterEditor)
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
        $consentFile=Join-Path $stateDir 'ookla-consent.json'
        if (Test-Path -LiteralPath $consentFile) {Remove-Item -LiteralPath $consentFile -Force}
        $editorProg='NexDashboard.TextEditor';$editorBase='HKCU:\Software\Classes'
        foreach ($ext in @('.txt','.log','.json','.xml','.csv','.md','.ini','.toml','.yaml','.yml','.ps1','.py','.js','.ts','.html','.css','.bat','.cmd','.cfg','.conf','.lua','.gitignore','.sh','.sql','.c','.cpp','.h','.cs','.rs','.java')) {Remove-ItemProperty -LiteralPath (Join-Path $editorBase ($ext+'\OpenWithProgids')) -Name $editorProg -ErrorAction SilentlyContinue}
        Remove-ItemProperty -LiteralPath 'HKCU:\Software\RegisteredApplications' -Name 'NEX Terminal Editor' -ErrorAction SilentlyContinue
        foreach ($key in @((Join-Path $editorBase $editorProg),'HKCU:\Software\NexDashboard\EditorCapabilities')) {Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue}
        foreach ($ext in @('.txt','.log','.json','.xml','.csv','.md','.ini','.toml','.yaml','.yml','.ps1','.py','.js','.ts','.html','.css','.bat','.cmd','.cfg','.conf','.lua','.gitignore','.sh','.sql','.c','.cpp','.h','.cs','.rs','.java')) {foreach ($suffix in @('\OpenWithList\NexTerminalEditor.exe','\shell\NexDashboard.Edit')) {Remove-Item -LiteralPath (Join-Path $editorBase ($ext+$suffix)) -Recurse -Force -ErrorAction SilentlyContinue};Remove-Item -LiteralPath (Join-Path $editorBase ('SystemFileAssociations\'+$ext+'\shell\NexDashboard.Edit')) -Recurse -Force -ErrorAction SilentlyContinue}
        foreach ($key in @('HKCU:\Software\Classes\Applications\NexTerminalEditor.exe','HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\NexTerminalEditor.exe')) {Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue}
        foreach ($name in @('NexTerminalEditor.exe','editor-script.txt','NexTerminalEditor.ico')) {Remove-Item -LiteralPath (Join-Path $stateDir $name) -Force -ErrorAction SilentlyContinue}
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
    $registerRequested=[bool]$RegisterEditor
    . $target
    if ($registerRequested -or (Get-ItemProperty -LiteralPath 'HKCU:\Software\RegisteredApplications' -Name 'NEX Terminal Editor' -ErrorAction SilentlyContinue)) {try {Set-NexEditorAssociation $true;Write-Host (NexL 'Editor registered.') -ForegroundColor Green} catch {Write-Warning ('Editor registration: '+$_.Exception.Message)}}
    if (-not (Test-Path -LiteralPath $state)) { NexSetup -SkipTerminalSync }
    if (-not $wasConfigured -and -not (Get-NexSpeedtest)) {
        $answer=Read-Host ((NexL 'Install optional Ookla Speedtest CLI for personal use?')+' [y/N]')
        if ($answer -match '^(?i:y|yes|д|да|j|ja)$') {
            Write-Host (NexL 'Downloading and verifying Ookla Speedtest...') -ForegroundColor Cyan
            try {$null=Install-NexSpeedtest;Write-Host (NexL 'Ookla Speedtest installed.') -ForegroundColor Green}
            catch {Write-Warning ((NexL 'Speedtest installation failed')+': '+$_.Exception.Message)}
        }
    }
    Write-Host '[OK] NEX Dashboard 2.7.0 Public Edition installed.' -ForegroundColor Green
    $hostInfo=Get-NexTerminalHost
    if (-not $wasConfigured -or -not $hostInfo -or -not (Test-Path -LiteralPath $hostInfo.Settings -PathType Leaf) -or ($global:NexPublicSettings.Icons -and -not (Test-NexNerdFont))) {
        $null=Initialize-NexAppearance
    } else {Write-Host (NexL 'Update installed. Open Dashboard to see the new version.') -ForegroundColor Green}
    Initialize-NexPublic
    return
}

$nexTranslationEntries = @'
[{"key":"Overview","ru":"Обзор","de":"Übersicht"},{"key":"System Monitor","ru":"Монитор системы","de":"Systemmonitor"},{"key":"Processes","ru":"Процессы","de":"Prozesse"},{"key":"Network","ru":"Сеть","de":"Netzwerk"},{"key":"File Explorer","ru":"Проводник","de":"Dateimanager"},{"key":"System Info","ru":"О системе","de":"Systeminfo"},{"key":"Windows Update","ru":"Обновления Windows","de":"Windows Update"},{"key":"Quick Tools","ru":"Инструменты","de":"Werkzeuge"},{"key":"System Logs","ru":"Журналы системы","de":"Systemprotokolle"},{"key":"Terminal Settings","ru":"Настройки терминала","de":"Terminal-Einstellungen"},{"key":"Personalization","ru":"Персонализация","de":"Personalisierung"},{"key":"Computer","ru":"Компьютер","de":"Computer"},{"key":"User","ru":"Пользователь","de":"Benutzer"},{"key":"Memory","ru":"Память","de":"Speicher"},{"key":"Uptime","ru":"Время работы","de":"Laufzeit"},{"key":"Language","ru":"Язык","de":"Sprache"},{"key":"Display name","ru":"Отображаемое имя","de":"Anzeigename"},{"key":"Theme","ru":"Тема","de":"Design"},{"key":"Custom accent","ru":"Свой цвет","de":"Eigene Akzentfarbe"},{"key":"Startup screen","ru":"Экран загрузки","de":"Startanimation"},{"key":"Startup info","ru":"Информация при запуске","de":"Startinformationen"},{"key":"Fetch preset","ru":"Стиль информации","de":"Info-Vorlage"},{"key":"Prompt style","ru":"Стиль строки ввода","de":"Prompt-Stil"},{"key":"Icons","ru":"Иконки","de":"Symbole"},{"key":"Prediction","ru":"Подсказки","de":"Vorschläge"},{"key":"Access type","ru":"Тип подключения","de":"Anschlussart"},{"key":"Apply terminal palette","ru":"Применить тему ко всем профилям","de":"Design auf alle Profile anwenden"},{"key":"Setup wizard","ru":"Мастер настройки","de":"Einrichtung"},{"key":"Preview fetch","ru":"Предпросмотр","de":"Info-Vorschau"},{"key":"Enabled","ru":"Включено","de":"An"},{"key":"Disabled","ru":"Выключено","de":"Aus"},{"key":"Automatic","ru":"Автоматически","de":"Automatisch"},{"key":"Unknown","ru":"Неизвестно","de":"Unbekannt"},{"key":"Ready","ru":"Готово","de":"Bereit"},{"key":"Complete","ru":"Завершено","de":"Fertig"},{"key":"Checking","ru":"Проверка","de":"Prüfung"},{"key":"Failed","ru":"Ошибка","de":"Fehlgeschlagen"},{"key":"Never","ru":"Никогда","de":"Nie"},{"key":"Not sampled","ru":"Нет измерений","de":"Nicht gemessen"},{"key":"Not detected","ru":"Не определено","de":"Nicht erkannt"},{"key":"Not reported","ru":"Нет данных","de":"Keine Angabe"},{"key":"Unavailable","ru":"Недоступно","de":"Nicht verfügbar"},{"key":"Stopped","ru":"Остановлено","de":"Angehalten"},{"key":"Folder","ru":"Папка","de":"Ordner"},{"key":"This PC / Drives","ru":"Этот компьютер / Диски","de":"Dieser PC / Laufwerke"},{"key":"Preview","ru":"Просмотр","de":"Vorschau"},{"key":"Navigation","ru":"Навигация","de":"Navigation"},{"key":"Status","ru":"Статус","de":"Status"},{"key":"Last checked","ru":"Последняя проверка","de":"Letzte Prüfung"},{"key":"Windows version","ru":"Версия Windows","de":"Windows-Version"},{"key":"Test server","ru":"Сервер теста","de":"Testserver"},{"key":"ISP (Ookla)","ru":"Провайдер (Ookla)","de":"Anbieter (Ookla)"},{"key":"Latency","ru":"Задержка","de":"Latenz"},{"key":"Ping target","ru":"Адрес пинга","de":"Ping-Ziel"},{"key":"Opacity","ru":"Прозрачность","de":"Deckkraft"},{"key":"Acrylic","ru":"Размытие","de":"Acryl"},{"key":"Cursor","ru":"Курсор","de":"Cursor"},{"key":"Color scheme","ru":"Цветовая схема","de":"Farbschema"},{"key":"Profile","ru":"Профиль","de":"Profil"},{"key":"Back","ru":"Назад","de":"Zurück"},{"key":"Menu","ru":"Меню","de":"Menü"},{"key":"Save","ru":"Сохранить","de":"Speichern"},{"key":"Exit","ru":"Выход","de":"Beenden"},{"key":"Cancel","ru":"Отмена","de":"Abbrechen"},{"key":"Confirm","ru":"Подтвердить","de":"Bestätigen"},{"key":"Discard","ru":"Не сохранять","de":"Verwerfen"},{"key":"Save & exit","ru":"Сохранить и выйти","de":"Speichern & Ende"},{"key":"New file","ru":"Новый файл","de":"Neue Datei"},{"key":"Edit","ru":"Редактировать","de":"Bearbeiten"},{"key":"Trash","ru":"В корзину","de":"Papierkorb"},{"key":"Drives","ru":"Диски","de":"Laufwerke"},{"key":"Path","ru":"Путь","de":"Pfad"},{"key":"Find","ru":"Поиск","de":"Suchen"},{"key":"Parent","ru":"Выше","de":"Übergeordnet"},{"key":"Copy","ru":"Копировать","de":"Kopieren"},{"key":"Cut","ru":"Вырезать","de":"Ausschneiden"},{"key":"Paste","ru":"Вставить","de":"Einfügen"},{"key":"Rename","ru":"Переименовать","de":"Umbenennen"},{"key":"View","ru":"Просмотр","de":"Ansehen"},{"key":"Details","ru":"Свойства","de":"Details"},{"key":"Sort","ru":"Сортировка","de":"Sortierung"},{"key":"Hidden","ru":"Скрытые","de":"Versteckte"},{"key":"Clear","ru":"Очистить","de":"Leeren"},{"key":"Refresh","ru":"Обновить","de":"Aktualisieren"},{"key":"Task mgr","ru":"Диспетчер","de":"Task-Manager"},{"key":"Task Manager","ru":"Диспетчер задач","de":"Task-Manager"},{"key":"Disk health","ru":"Состояние дисков","de":"Laufwerkszustand"},{"key":"DNS servers","ru":"DNS-серверы","de":"DNS-Server"},{"key":"Service status","ru":"Службы","de":"Dienste"},{"key":"IP configuration","ru":"Настройки IP","de":"IP-Konfiguration"},{"key":"Event Viewer","ru":"Просмотр событий","de":"Ereignisanzeige"},{"key":"App","ru":"Приложения","de":"Anwendung"},{"key":"System","ru":"Система","de":"System"},{"key":"Export","ru":"Экспорт","de":"Export"},{"key":"Explorer","ru":"Проводник","de":"Explorer"},{"key":"Clear filter","ru":"Сброс поиска","de":"Filter löschen"},{"key":"Stop ping","ru":"Стоп пинг","de":"Ping stoppen"},{"key":"PROCESS","ru":"ПРОЦЕСС","de":"PROZESS"},{"key":"DOWNLOAD","ru":"ЗАГРУЗКА","de":"DOWNLOAD"},{"key":"UPLOAD","ru":"ОТДАЧА","de":"UPLOAD"},{"key":"APPEARANCE & INPUT","ru":"ОФОРМЛЕНИЕ И ВВОД","de":"DARSTELLUNG & EINGABE"},{"key":"WINDOWS UPDATE CENTER","ru":"ЦЕНТР ОБНОВЛЕНИЯ WINDOWS","de":"WINDOWS UPDATE CENTER"},{"key":"HARDWARE / SOFTWARE","ru":"ОБОРУДОВАНИЕ / ПО","de":"HARDWARE / SOFTWARE"},{"key":"READ-ONLY DIAGNOSTICS","ru":"ДИАГНОСТИКА (ЧТЕНИЕ)","de":"DIAGNOSE (NUR LESEN)"},{"key":"NETWORK TRAFFIC","ru":"СЕТЕВОЙ ТРАФИК","de":"NETZWERKVERKEHR"},{"key":"Smoothed","ru":"Сглажено","de":"Geglättet"},{"key":"Welcome","ru":"Добро пожаловать","de":"Willkommen"},{"key":"Loading Windows counters...","ru":"Загрузка счётчиков Windows...","de":"Windows-Zähler werden geladen..."},{"key":"Reading system information...","ru":"Чтение сведений о системе...","de":"Systeminformationen werden gelesen..."},{"key":"No active physical adapters.","ru":"Нет активных физических адаптеров.","de":"Keine aktiven physischen Adapter."},{"key":"Waiting for adapter counters...","ru":"Ожидание сетевых счётчиков...","de":"Warte auf Netzwerkzähler..."},{"key":"On demand only. Measures available internet speed.","ru":"По запросу: измеряет доступную скорость.","de":"Nur auf Anfrage: misst verfügbare Geschwindigkeit."},{"key":"Empty, inaccessible or no matches.","ru":"Пусто, нет доступа или совпадений.","de":"Leer, kein Zugriff oder keine Treffer."},{"key":"No events loaded / matching events.","ru":"Нет подходящих событий.","de":"Keine passenden Ereignisse."},{"key":"Check for updates","ru":"Проверить обновления","de":"Nach Updates suchen"},{"key":"Checking Windows Update ...","ru":"Проверка обновлений Windows ...","de":"Windows-Updates werden geprüft ..."},{"key":"Start test","ru":"Начать тест","de":"Test starten"},{"key":"Cancel test","ru":"Отменить тест","de":"Test abbrechen"},{"key":"Filter","ru":"Фильтр","de":"Filter"},{"key":"Peak","ru":"Пик","de":"Spitze"},{"key":"Type a value, or click a choice. Esc cancels.","ru":"Введите значение или выберите мышью. Esc — отмена.","de":"Wert eingeben oder auswählen. Esc bricht ab."},{"key":"Save changes before leaving?","ru":"Сохранить изменения перед выходом?","de":"Änderungen vor dem Schließen speichern?"},{"key":"MOVE TO RECYCLE BIN?","ru":"ПЕРЕМЕСТИТЬ В КОРЗИНУ?","de":"IN DEN PAPIERKORB VERSCHIEBEN?"},{"key":"Windows may show a further confirmation.","ru":"Windows может запросить подтверждение.","de":"Windows kann erneut nachfragen."},{"key":"Choose language","ru":"Выберите язык","de":"Sprache wählen"},{"key":"Choose theme","ru":"Выберите тему","de":"Design wählen"},{"key":"Choose prompt style","ru":"Выберите стиль строки ввода","de":"Prompt-Stil wählen"},{"key":"Choose fetch preset","ru":"Выберите пресет информации","de":"Info-Vorlage wählen"},{"key":"Preferences saved.","ru":"Настройки сохранены.","de":"Einstellungen gespeichert."},{"key":"Apply colors to selected Windows Terminal profile?","ru":"Применить цвета к выбранному профилю?","de":"Farben auf gewähltes Profil anwenden?"},{"key":"Use Windows account name","ru":"Использовать имя Windows","de":"Windows-Benutzername verwenden"},{"key":"Enter display name","ru":"Введите отображаемое имя","de":"Anzeigename eingeben"},{"key":"Choose access type","ru":"Выберите тип подключения","de":"Anschlussart wählen"},{"key":"Appearance, startup and language","ru":"Оформление, запуск и язык","de":"Darstellung, Start und Sprache"},{"key":"Open personalization","ru":"Открыть персонализацию","de":"Personalisierung öffnen"},{"key":"CPU load","ru":"Нагрузка CPU","de":"CPU-Last"},{"key":"GPU engine load","ru":"Нагрузка движков GPU","de":"GPU-Engine-Last"},{"key":"RAM usage","ru":"Использование RAM","de":"RAM-Nutzung"},{"key":"Physical memory","ru":"Физическая память","de":"Arbeitsspeicher"},{"key":"Storage","ru":"Накопители","de":"Laufwerke"},{"key":"Graphics adapters","ru":"Видеоадаптеры","de":"Grafikadapter"},{"key":"No GPU counter","ru":"Нет счётчика GPU","de":"Kein GPU-Zähler"},{"key":"Processor","ru":"Процессор","de":"Prozessor"},{"key":"Graphics","ru":"Графика","de":"Grafik"},{"key":"Hardware","ru":"Оборудование","de":"Hardware"},{"key":"Software","ru":"Программы","de":"Software"},{"key":"Welcome back","ru":"С возвращением","de":"Willkommen zurück"},{"key":"Loading","ru":"Загрузка","de":"Laden"},{"key":"Settings saved with a backup.","ru":"Настройки сохранены с резервной копией.","de":"Einstellungen mit Sicherung gespeichert."},{"key":"No regular software updates found by this scan.","ru":"Обычные обновления не найдены.","de":"Keine regulären Updates gefunden."},{"key":"Regular software updates","ru":"Обычные обновления","de":"Reguläre Updates"},{"key":"Optional software updates","ru":"Необязательные обновления","de":"Optionale Updates"},{"key":"Microsoft Defender updates","ru":"Обновления Microsoft Defender","de":"Microsoft-Defender-Updates"},{"key":"Unclassified software updates","ru":"Другие обновления","de":"Nicht klassifizierte Updates"},{"key":"Installed Defender signatures","ru":"Установленные базы Defender","de":"Installierte Defender-Signaturen"},{"key":"Defender last updated","ru":"Обновление баз Defender","de":"Letztes Defender-Update"},{"key":"No changes made.","ru":"Без изменений.","de":"Keine Änderungen."},{"key":"Tab: sidebar/content | Esc: back or exit","ru":"Tab: меню/содержимое · Esc: назад/выход","de":"Tab: Menü/Inhalt · Esc: zurück/Ende"},{"key":"Tab: sidebar  |  Esc: overview / exit","ru":"Tab: меню · Esc: обзор/выход","de":"Tab: Menü · Esc: Übersicht/Ende"},{"key":"S Speedtest | K Cancel | P Ping host | X Stop ping | Esc Overview","ru":"S тест | K отмена | P адрес пинга | X стоп | Esc обзор","de":"S Test | K Abbruch | P Ping-Ziel | X Stopp | Esc Übersicht"},{"key":"N New file | M New folder | E Edit | Del Trash | Enter Open | D Drives | P Path","ru":"N Файл · M Папка · E Правка · Del Корзина · Enter Открыть · D Диски · P Путь","de":"N Datei · M Ordner · E Edit · Del Papierkorb · Enter Öffnen · D Laufwerke · P Pfad"},{"key":"F2 Rename | F3 Details | F4 Sort | H Hidden | O Explorer | R Clear | Double-click Open","ru":"F2 Имя · F3 Свойства · F4 Сортировка · H Скрытые · O Проводник · R Сброс","de":"F2 Name · F3 Details · F4 Sortieren · H Versteckte · O Explorer · R Reset"},{"key":"Click values | G Profile | O Opacity | J JSON | Ctrl+, Native settings","ru":"Клик по значениям · G Профиль · O Прозрачность · J JSON · Ctrl+, настройки","de":"Werte anklicken · G Profil · O Deckkraft · J JSON · Ctrl+, Einstellungen"},{"key":"Click a tool | D/N/S/I Query | E/T Native tools | Up/Down scroll","ru":"Выберите инструмент · ↑↓ прокрутка","de":"Werkzeug wählen · ↑↓ scrollen"},{"key":"C / Enter Check | Up/Down scroll | Esc Overview","ru":"C / Enter — проверка | ↑↓ прокрутка | Esc обзор","de":"C / Enter prüfen | ↑↓ scrollen | Esc Übersicht"},{"key":"WUA software scan only; Defender and optional updates listed separately.","ru":"Проверка WUA; Defender и необязательные обновления отдельно.","de":"WUA-Prüfung; Defender und optionale Updates separat."},{"key":"Enter Details | A Application | S System | B Export | Del Archive + clear","ru":"Enter Подробнее · A Приложения · S Система · B Экспорт · Del Архив и очистка","de":"Enter Details · A Anwendung · S System · B Export · Del Archiv & leeren"},{"key":"Clear requires admin. Backup is saved in NexLogBackups.","ru":"Очистка требует прав администратора; архив в NexLogBackups.","de":"Leeren benötigt Adminrechte; Archiv in NexLogBackups."},{"key":"C CPU | M RAM | F Find | R Clear | Up/Down scroll | T Task Manager","ru":"C CPU · M RAM · F Поиск · R Сброс · ↑↓ · T Диспетчер","de":"C CPU · M RAM · F Suche · R Reset · ↑↓ · T Task-Manager"},{"key":"Up/Down scroll | R Refresh | Esc Overview","ru":"↑↓ прокрутка | R обновить | Esc обзор","de":"↑↓ scrollen | R aktualisieren | Esc Übersicht"},{"key":"Enter: open  |  Tab: content  |  Esc: exit","ru":"Enter: открыть · Tab: содержимое · Esc: выход","de":"Enter: öffnen · Tab: Inhalt · Esc: Ende"},{"key":"Up/Down: scroll  |  Esc: back","ru":"↑↓ прокрутка · Esc назад","de":"↑↓ scrollen · Esc zurück"},{"key":"Choose an existing color scheme","ru":"Выберите цветовую схему","de":"Farbschema auswählen"},{"key":"Choose cursor shape","ru":"Выберите форму курсора","de":"Cursorform wählen"},{"key":"Opacity 0-100 (%)","ru":"Прозрачность 0–100 (%)","de":"Deckkraft 0–100 (%)"},{"key":"Process name","ru":"Имя процесса","de":"Prozessname"},{"key":"Enter folder path","ru":"Ввести путь вручную","de":"Ordnerpfad eingeben"},{"key":"New file name","ru":"Имя нового файла","de":"Neuer Dateiname"},{"key":"New folder name","ru":"Имя новой папки","de":"Neuer Ordnername"},{"key":"Select profile","ru":"Выберите профиль","de":"Profil wählen"},{"key":"Profile identified. Click a value or preset.","ru":"Профиль найден. Нажмите на значение.","de":"Profil erkannt. Wert anklicken."},{"key":"Values on disk. Reopen tab if appearance differs.","ru":"Значения сохранены. При необходимости откройте вкладку заново.","de":"Gespeicherte Werte. Tab ggf. neu öffnen."},{"key":"Defaults: affects profiles without overrides.","ru":"Defaults: действует на профили без переопределений.","de":"Defaults: gilt für Profile ohne eigene Werte."},{"key":"Win+X: profile is inferred. G selects Defaults.","ru":"Win+X: профиль предполагается. G — выбор Defaults.","de":"Win+X: Profil geschätzt. G wählt Defaults."},{"key":"Terminal palette","ru":"Палитра терминала","de":"Terminalpalette"},{"key":"Keep existing","ru":"Оставить текущий","de":"Beibehalten"},{"key":"No startup screen","ru":"Без экрана загрузки","de":"Ohne Startanimation"},{"key":"No startup info","ru":"Без информации","de":"Ohne Startinformationen"},{"key":"Personal settings are stored locally.","ru":"Настройки сохраняются локально.","de":"Einstellungen werden lokal gespeichert."},{"key":"Nerd Font icons need a compatible font.","ru":"Для иконок нужен совместимый шрифт Nerd Font.","de":"Symbole benötigen einen Nerd Font."},{"key":"Theme saved.","ru":"Тема сохранена.","de":"Design gespeichert."},{"key":"Classic monitor","ru":"Классический монитор","de":"Klassischer Monitor"},{"key":"Choose terminal color","ru":"Выбрать цвет терминала","de":"Terminalfarbe wählen"},{"key":"Background","ru":"Фон","de":"Hintergrund"},{"key":"Foreground","ru":"Текст","de":"Text"},{"key":"Cursor color","ru":"Цвет курсора","de":"Cursorfarbe"},{"key":"Selection color","ru":"Цвет выделения","de":"Auswahlfarbe"},{"key":"Cards","ru":"Карточки","de":"Karten"},{"key":"Compact","ru":"Компактный","de":"Kompakt"},{"key":"Minimal","ru":"Минимальный","de":"Minimal"},{"key":"Rounded","ru":"Закруглённый","de":"Abgerundet"},{"key":"Powerline","ru":"Powerline","de":"Powerline"},{"key":"Classic","ru":"Классический","de":"Klassisch"},{"key":"Fastfetch classic","ru":"Fastfetch классический","de":"Fastfetch klassisch"},{"key":"Fastfetch custom","ru":"Fastfetch свой конфиг","de":"Fastfetch eigene Konfig."},{"key":"Pink","ru":"Сакура","de":"Sakura"},{"key":"Lavender","ru":"Лавандовый сон","de":"Lavendeltraum"},{"key":"Blue","ru":"Лазурное небо","de":"Azurhimmel"},{"key":"Mint","ru":"Мятный бриз","de":"Minzbrise"},{"key":"Amber","ru":"Янтарный свет","de":"Bernsteinlicht"},{"key":"Mono","ru":"Лунный монохром","de":"Mond-Monochrom"},{"key":"Custom","ru":"Своя","de":"Benutzerdefiniert"},{"key":"None","ru":"Нет","de":"Keine"},{"key":"History","ru":"История","de":"Verlauf"},{"key":"Fiber / Glasfaser","ru":"Оптоволокно","de":"Glasfaser"},{"key":"Mobile","ru":"Мобильная сеть","de":"Mobilfunk"},{"key":"Cable","ru":"Кабель","de":"Kabel"},{"key":"Other","ru":"Другой","de":"Andere"},{"key":"Click values / keys | Esc Overview","ru":"Клик по значениям · Esc Обзор","de":"Werte anklicken · Esc Übersicht"},{"key":"Esc Overview","ru":"Esc Обзор","de":"Esc Übersicht"},{"key":"Saved","ru":"Сохранено","de":"Gespeichert"},{"key":"Already saved.","ru":"Уже сохранено.","de":"Bereits gespeichert."},{"key":"Unsaved","ru":"Не сохранено","de":"Ungespeichert"},{"key":"Created.","ru":"Создано.","de":"Erstellt."},{"key":"Renamed.","ru":"Переименовано.","de":"Umbenannt."},{"key":"Removed via Windows Recycle Bin.","ru":"Перемещено в корзину Windows.","de":"In Windows-Papierkorb verschoben."},{"key":"Operation completed.","ru":"Операция завершена.","de":"Vorgang abgeschlossen."},{"key":"Folder not found","ru":"Папка не найдена","de":"Ordner nicht gefunden"},{"key":"ARCHIVE AND CLEAR LOG?","ru":"АРХИВИРОВАТЬ И ОЧИСТИТЬ?","de":"ARCHIVIEREN UND LEEREN?"},{"key":"All events in this log; EVTX backup first.","ru":"Сначала архив EVTX, затем очистка журнала.","de":"Zuerst EVTX-Archiv, dann Protokoll leeren."},{"key":"Windows Terminal settings will be backed up.","ru":"Настройки терминала будут скопированы.","de":"Terminal-Einstellungen werden gesichert."},{"key":"Please enlarge terminal to 26 rows.","ru":"Увеличьте высоту терминала до 26 строк.","de":"Terminal auf 26 Zeilen vergrößern."},{"key":"All profiles share appearance. Reopen tabs if needed.","ru":"Общее оформление всех профилей. При необходимости откройте вкладки заново.","de":"Gemeinsames Design aller Profile. Tabs ggf. neu öffnen."},{"key":"All profiles share appearance.","ru":"Единое оформление всех профилей.","de":"Gemeinsames Design aller Profile."},{"key":"Install Fastfetch","ru":"Установить Fastfetch","de":"Fastfetch installieren"},{"key":"Fastfetch is not installed.","ru":"Fastfetch не установлен.","de":"Fastfetch ist nicht installiert."},{"key":"Fastfetch failed; showing built-in Cards.","ru":"Ошибка Fastfetch; показаны встроенные карточки.","de":"Fastfetch-Fehler; integrierte Karten werden angezeigt."},{"key":"Fastfetch ready.","ru":"Fastfetch готов.","de":"Fastfetch ist bereit."},{"key":"Fastfetch missing; showing built-in Cards.","ru":"Fastfetch не установлен; показаны встроенные карточки.","de":"Fastfetch fehlt; integrierte Karten werden angezeigt."},{"key":"Use built-in fallback","ru":"Использовать встроенный вариант","de":"Integrierte Alternative verwenden"},{"key":"Install official Fastfetch now?","ru":"Установить официальный Fastfetch сейчас?","de":"Offizielles Fastfetch jetzt installieren?"},{"key":"No custom config found; using themed Fastfetch.","ru":"Свой конфиг не найден; используется цветной пресет Fastfetch.","de":"Keine eigene Konfiguration; farbiges Fastfetch-Design."},{"key":"New shells use the saved preset.","ru":"Новые окна используют сохранённый пресет.","de":"Neue Fenster verwenden die gespeicherte Vorlage."},{"key":"Installed","ru":"Установлен","de":"Installiert"},{"key":"Not installed","ru":"Не установлен","de":"Nicht installiert"},{"key":"Build","ru":"Сборка","de":"Build"},{"key":"Terminal","ru":"Терминал","de":"Terminal"},{"key":"Shell","ru":"Оболочка","de":"Shell"},{"key":"Disk","ru":"Диск","de":"Laufwerk"},{"key":"Neon Frame","ru":"Неоновые рамки","de":"Neon-Rahmen"},{"key":"Color Labels","ru":"Цветные подписи","de":"Farbige Labels"},{"key":"Tree Layout","ru":"Дерево","de":"Baumansicht"},{"key":"Studio","ru":"Студия без логотипа","de":"Studio ohne Logo"},{"key":"Editor","ru":"Редактор","de":"Editor"},{"key":"CPU","ru":"CPU","de":"CPU"},{"key":"GPU","ru":"GPU","de":"GPU"},{"key":"RAM","ru":"RAM","de":"RAM"},{"key":"System overview","ru":"Обзор системы","de":"Systemübersicht"},{"key":"Disks","ru":"Диски","de":"Laufwerke"},{"key":"DNS","ru":"DNS-серверы","de":"DNS-Server"},{"key":"Services","ru":"Службы","de":"Dienste"},{"key":"IP","ru":"Настройки IP","de":"IP-Konfiguration"},{"key":"Health","ru":"Состояние","de":"Zustand"},{"key":"Healthy","ru":"Исправен","de":"Fehlerfrei"},{"key":"Warning","ru":"Предупреждение","de":"Warnung"},{"key":"Unhealthy","ru":"Неисправен","de":"Fehlerhaft"},{"key":"OK","ru":"Норма","de":"OK"},{"key":"Running","ru":"Работает","de":"Läuft"},{"key":"StartPending","ru":"Запускается","de":"Wird gestartet"},{"key":"StopPending","ru":"Останавливается","de":"Wird beendet"},{"key":"Paused","ru":"Приостановлено","de":"Pausiert"},{"key":"Gateway","ru":"Шлюз","de":"Gateway"},{"key":"Reading...","ru":"Чтение...","de":"Wird gelesen..."},{"key":"Change DNS","ru":"Изменить DNS","de":"DNS ändern"},{"key":"Choose network adapter","ru":"Выберите сетевой адаптер","de":"Netzwerkadapter wählen"},{"key":"Choose DNS mode","ru":"Выберите режим DNS","de":"DNS-Modus wählen"},{"key":"Custom DNS","ru":"Свои DNS-адреса","de":"Eigene DNS-Adressen"},{"key":"Automatic DNS (DHCP)","ru":"Автоматический DNS (DHCP)","de":"Automatischer DNS (DHCP)"},{"key":"Enter IPv4 DNS addresses separated by commas","ru":"Введите IPv4 DNS через запятую","de":"IPv4-DNS-Adressen mit Komma eingeben"},{"key":"Invalid IPv4 DNS address.","ru":"Некорректный IPv4 DNS-адрес.","de":"Ungültige IPv4-DNS-Adresse."},{"key":"DNS changes require administrator rights.","ru":"Для изменения DNS нужны права администратора.","de":"DNS-Änderungen erfordern Administratorrechte."},{"key":"APPLY DNS SETTINGS?","ru":"ПРИМЕНИТЬ НАСТРОЙКИ DNS?","de":"DNS-EINSTELLUNGEN ANWENDEN?"},{"key":"Only the selected adapter will be changed.","ru":"Изменится только выбранный адаптер.","de":"Nur der gewählte Adapter wird geändert."},{"key":"DNS settings updated.","ru":"Настройки DNS обновлены.","de":"DNS-Einstellungen aktualisiert."},{"key":"Diagnostics & network settings","ru":"Диагностика и настройки сети","de":"Diagnose und Netzwerkeinstellungen"},{"key":"Click a tool | Up/Down scroll","ru":"Выберите инструмент мышью · ↑↓ прокрутка","de":"Werkzeug anklicken · ↑↓ scrollen"},{"key":"Fetch animation","ru":"Анимация появления информации","de":"Info-Einblendung"},{"key":"Date","ru":"Дата","de":"Datum"},{"key":"LIVE","ru":"В РЕАЛЬНОМ ВРЕМЕНИ","de":"LIVE"},{"key":"Smoothed display","ru":"Плавные показания","de":"Geglättete Anzeige"},{"key":"8 s history","ru":"История 8 с","de":"8 s Verlauf"},{"key":"log scale","ru":"лог. шкала","de":"Log-Skala"},{"key":"150 ms target","ru":"интервал ~150 мс","de":"Zielintervall 150 ms"},{"key":"standard sampling","ru":"обычный опрос","de":"Standardabfrage"},{"key":"Down","ru":"Загрузка","de":"Download"},{"key":"Up","ru":"Отдача","de":"Upload"},{"key":"items","ru":"объектов","de":"Einträge"},{"key":"True","ru":"Да","de":"Ja"},{"key":"False","ru":"Нет","de":"Nein"},{"key":"Name","ru":"Имя","de":"Name"},{"key":"Size","ru":"Размер","de":"Größe"},{"key":"Date modified","ru":"Дата изменения","de":"Änderungsdatum"},{"key":"PC","ru":"Компьютер","de":"Computer"},{"key":"Cores / threads","ru":"Ядра / потоки","de":"Kerne / Threads"},{"key":"Motherboard","ru":"Материнская плата","de":"Mainboard"},{"key":"Usable RAM","ru":"Доступная RAM","de":"Nutzbarer RAM"},{"key":"Driver","ru":"Драйвер","de":"Treiber"},{"key":"Last 7 days","ru":"Последние 7 дней","de":"Letzte 7 Tage"},{"key":"Error / warning","ru":"Ошибки / предупреждения","de":"Fehler / Warnungen"},{"key":"Application","ru":"Приложения","de":"Anwendung"},{"key":"Windows does not report scan percentage.","ru":"Windows не сообщает процент проверки.","de":"Windows meldet keinen Prüffortschritt."},{"key":"A query is running. Try again shortly.","ru":"Выполняется запрос. Повторите чуть позже.","de":"Eine Abfrage läuft. Bitte erneut versuchen."},{"key":"Query failed or access denied.","ru":"Запрос не выполнен или нет доступа.","de":"Abfrage fehlgeschlagen oder Zugriff verweigert."},{"key":"Not configured","ru":"Не настроено","de":"Nicht eingerichtet"},{"key":"Custom IPv4 DNS","ru":"Ручной IPv4 DNS","de":"Manueller IPv4-DNS"},{"key":"Current DNS","ru":"Текущий DNS","de":"Aktueller DNS"},{"key":"Enter OK  |  Esc Cancel  |  Ctrl+V Paste","ru":"Enter — ОК | Esc — отмена | Ctrl+V — вставить","de":"Enter OK | Esc Abbrechen | Ctrl+V Einfügen"},{"key":"Click / Left / Right / Enter / Esc","ru":"Мышь / ← / → / Enter / Esc","de":"Maus / ← / → / Enter / Esc"},{"key":"Enlarge terminal (58 x 16 min).","ru":"Увеличьте терминал (мин. 58 × 16).","de":"Terminal vergrößern (mind. 58 × 16)."},{"key":"Please enlarge terminal to 27 rows.","ru":"Увеличьте высоту терминала до 27 строк.","de":"Terminal auf 27 Zeilen vergrößern."},{"key":"Enlarge the window or press Esc.","ru":"Увеличьте окно или нажмите Esc.","de":"Fenster vergrößern oder Esc drücken."},{"key":"max, all adapters","ru":"макс., все адаптеры","de":"max., alle Adapter"},{"key":"session","ru":"сеанс","de":"Sitzung"},{"key":"Theme applied to all profiles.","ru":"Тема применена ко всем профилям.","de":"Design auf alle Profile angewendet."},{"key":"Dashboard theme saved.","ru":"Тема Dashboard сохранена.","de":"Dashboard-Design gespeichert."},{"key":"Install the official Ookla CLI first.","ru":"Сначала установите официальный Ookla CLI.","de":"Zuerst die offizielle Ookla CLI installieren."},{"key":"Select a supported text file.","ru":"Выберите поддерживаемый текстовый файл.","de":"Unterstützte Textdatei auswählen."},{"key":"Editor limit: 256 KiB. Use external editor for large files.","ru":"Лимит редактора: 256 КиБ. Для больших файлов нужен внешний редактор.","de":"Editorlimit: 256 KiB. Große Dateien extern bearbeiten."},{"key":"Editing links is not supported.","ru":"Редактирование ссылок не поддерживается.","de":"Bearbeiten von Links wird nicht unterstützt."},{"key":"File saved.","ru":"Файл сохранён.","de":"Datei gespeichert."},{"key":"Folder path","ru":"Путь к папке","de":"Ordnerpfad"},{"key":"Filter names (empty cancels)","ru":"Фильтр имён (пусто — отмена)","de":"Namen filtern (leer = Abbruch)"},{"key":"Copied to dashboard clipboard; navigate and press V.","ru":"Скопировано. Перейдите в нужную папку и нажмите V.","de":"Kopiert. Zielordner wählen und V drücken."},{"key":"Marked to move; navigate and press V.","ru":"Отмечено для переноса. Выберите папку и нажмите V.","de":"Zum Verschieben markiert. Zielordner wählen und V drücken."},{"key":"Select a text file to preview.","ru":"Выберите текстовый файл для просмотра.","de":"Textdatei für Vorschau auswählen."},{"key":"Preview supports text files only.","ru":"Просмотр доступен только для текстовых файлов.","de":"Vorschau nur für Textdateien."},{"key":"Unsupported log.","ru":"Журнал не поддерживается.","de":"Protokoll wird nicht unterstützt."},{"key":"Wait for current log query.","ru":"Дождитесь завершения запроса журнала.","de":"Laufende Protokollabfrage abwarten."},{"key":"Clearing requires an administrator PowerShell.","ru":"Для очистки нужны права администратора.","de":"Leeren erfordert Administratorrechte."},{"key":"Choose Windows Terminal profile","ru":"Выберите профиль Windows Terminal","de":"Windows-Terminal-Profil auswählen"},{"key":"Invalid profile number.","ru":"Неверный номер профиля.","de":"Ungültige Profilnummer."},{"key":"Defaults selected for display. Changes apply to all profiles.","ru":"Выбраны общие настройки. Изменения для всех профилей.","de":"Allgemeine Einstellungen gewählt. Änderungen für alle Profile."},{"key":"Enter a number from 0 to 100.","ru":"Введите число от 0 до 100.","de":"Zahl von 0 bis 100 eingeben."},{"key":"Unsupported cursor shape.","ru":"Неизвестная форма курсора.","de":"Nicht unterstützte Cursorform."},{"key":"Choose a listed scheme.","ru":"Выберите схему из списка.","de":"Farbschema aus der Liste wählen."},{"key":"Settings file not identified.","ru":"Файл настроек не найден.","de":"Einstellungsdatei nicht gefunden."},{"key":"Settings refreshed.","ru":"Настройки обновлены.","de":"Einstellungen aktualisiert."},{"key":"Ping host or IP address (e.g. 1.1.1.1)","ru":"Имя узла или IP для пинга","de":"Hostname oder IP für Ping"},{"key":"Invalid host.","ru":"Неверный адрес узла.","de":"Ungültiger Host."},{"key":"Waiting...","ru":"Ожидание...","de":"Warten..."},{"key":"Unreachable / DNS error","ru":"Узел недоступен / ошибка DNS","de":"Nicht erreichbar / DNS-Fehler"},{"key":"HDD","ru":"HDD","de":"HDD"},{"key":"SSD","ru":"SSD","de":"SSD"},{"key":"Choose a file","ru":"Выберите файл","de":"Datei auswählen"},{"key":"Temperature","ru":"Температура","de":"Temperatur"},{"key":"Power","ru":"Мощность","de":"Leistung"},{"key":"Clock","ru":"Частота","de":"Takt"},{"key":"Fans","ru":"Вентиляторы","de":"Lüfter"},{"key":"Reported clock","ru":"Частота по WMI","de":"Gemeldeter Takt"},{"key":"Free","ru":"Свободно","de":"Frei"},{"key":"VRAM","ru":"Видеопамять","de":"VRAM"},{"key":"NVIDIA sensors","ru":"Датчики NVIDIA","de":"NVIDIA-Sensoren"},{"key":"GPU load: max of all adapters","ru":"GPU: максимум всех адаптеров","de":"GPU: Maximum aller Adapter"},{"key":"No dedicated VRAM sensor","ru":"Нет датчика выделенной VRAM","de":"Kein Sensor für dedizierten VRAM"},{"key":"Download","ru":"Загрузка","de":"Download"},{"key":"Upload","ru":"Отдача","de":"Upload"},{"key":"Time","ru":"Время","de":"Zeit"},{"key":"Physical adapters","ru":"Физические адаптеры","de":"Physische Adapter"},{"key":"Up/Down scroll | Tab Menu | Esc Overview","ru":"↑↓ прокрутка · Tab меню · Esc обзор","de":"↑↓ scrollen · Tab Menü · Esc Übersicht"},{"key":"Scroll for more","ru":"Прокрутите для просмотра","de":"Scrollen für mehr"},{"key":"GPU telemetry unavailable","ru":"Датчики GPU недоступны","de":"GPU-Sensoren nicht verfügbar"},{"key":"Load history","ru":"История нагрузки","de":"Lastverlauf"},{"key":"Other adapters","ru":"Другие адаптеры","de":"Weitere Adapter"},{"key":"No storage data","ru":"Нет данных о дисках","de":"Keine Laufwerksdaten"},{"key":"CPU temperature unavailable","ru":"Температура CPU недоступна","de":"CPU-Temperatur nicht verfügbar"},{"key":"Rows","ru":"Строки","de":"Zeilen"},{"key":"Temp.","ru":"Темп.","de":"Temp."},{"key":"GPU load: NVIDIA sensor","ru":"GPU: датчик NVIDIA","de":"GPU: NVIDIA-Sensor"},{"key":"Custom logo","ru":"Свой логотип","de":"Eigenes Logo"},{"key":"Default logo","ru":"Стандартный логотип","de":"Standardlogo"},{"key":"Custom logo saved.","ru":"Логотип сохранён.","de":"Eigenes Logo gespeichert."},{"key":"Default logo restored.","ru":"Стандартный логотип восстановлен.","de":"Standardlogo wiederhergestellt."},{"key":"Paste art | Ctrl+A selects all | Empty + Save = default","ru":"Вставьте рисунок | Ctrl+A — всё | Пусто + сохранить = стандартный","de":"Grafik einfügen | Ctrl+A alles | Leer + Speichern = Standard"},{"key":"All text selected","ru":"Весь текст выделен","de":"Alles ausgewählt"},{"key":"Logo limit: 80 lines, 120 characters per line.","ru":"Лимит логотипа: 80 строк, 120 символов в строке.","de":"Logo-Limit: 80 Zeilen, 120 Zeichen pro Zeile."},{"key":"Logo must contain printable text only.","ru":"Логотип должен содержать только печатные символы.","de":"Logo darf nur druckbare Zeichen enthalten."},{"key":"Restore","ru":"Восстановить","de":"Wiederherstellen"},{"key":"Export configuration","ru":"Экспорт настроек","de":"Konfiguration exportieren"},{"key":"Restore configuration","ru":"Восстановление настроек","de":"Konfiguration wiederherstellen"},{"key":"Restore configuration?","ru":"Восстановить настройки?","de":"Konfiguration wiederherstellen?"},{"key":"Replace appearance; allow official dependency downloads?","ru":"Заменить оформление? Разрешить загрузку компонентов?","de":"Design ersetzen und offizielle Downloads erlauben?"},{"key":"Restoring configuration...","ru":"Восстановление настроек...","de":"Konfiguration wird wiederhergestellt..."},{"key":"Invalid configuration file.","ru":"Некорректный файл настроек.","de":"Ungültige Konfigurationsdatei."},{"key":"Light/dark scheme pairs are not supported by export.","ru":"Парные светлые/тёмные схемы не поддерживаются.","de":"Helle/dunkle Schemapaare werden nicht unterstützt."},{"key":"Configuration exported.","ru":"Настройки экспортированы.","de":"Konfiguration exportiert."},{"key":"Configuration exported. External Fastfetch assets/options were omitted.","ru":"Настройки сохранены. Внешние ресурсы Fastfetch пропущены.","de":"Exportiert. Externe Fastfetch-Ressourcen wurden ausgelassen."},{"key":"Configuration exported with default terminal appearance.","ru":"Настройки сохранены с оформлением терминала по умолчанию.","de":"Mit Standarddesign des Terminals exportiert."},{"key":"Windows Terminal setup incomplete.","ru":"Установка Windows Terminal не завершена.","de":"Windows Terminal nicht vollständig eingerichtet."},{"key":"Nerd Font could not be restored.","ru":"Не удалось восстановить Nerd Font.","de":"Nerd Font konnte nicht wiederhergestellt werden."},{"key":"Selected external font must be installed separately.","ru":"Выбранный сторонний шрифт нужно установить отдельно.","de":"Die externe Schriftart muss separat installiert werden."},{"key":"Fastfetch could not be restored.","ru":"Не удалось восстановить Fastfetch.","de":"Fastfetch konnte nicht wiederhergestellt werden."},{"key":"Color scheme definition not included.","ru":"Определение цветовой схемы не сохранено.","de":"Farbschema-Definition fehlt."},{"key":"Terminal appearance not fully restored.","ru":"Оформление терминала восстановлено не полностью.","de":"Terminaldesign nicht vollständig wiederhergestellt."},{"key":"Custom Fastfetch configuration not restored.","ru":"Свой конфиг Fastfetch не восстановлен.","de":"Eigene Fastfetch-Konfiguration nicht wiederhergestellt."},{"key":"External Fastfetch assets/options were omitted.","ru":"Внешние ресурсы Fastfetch пропущены.","de":"Externe Fastfetch-Ressourcen ausgelassen."},{"key":"Configuration partially restored.","ru":"Настройки восстановлены частично.","de":"Konfiguration teilweise wiederhergestellt."},{"key":"Configuration restored. Reopen terminal tabs.","ru":"Настройки восстановлены. Переоткрой вкладки терминала.","de":"Konfiguration wiederhergestellt. Terminal-Tabs neu öffnen."},{"key":"S Export | R Restore | Esc Overview","ru":"S Экспорт | R Восстановить | Esc Обзор","de":"S Export | R Wiederherstellen | Esc Übersicht"},{"key":"Crimson Eclipse","ru":"Алое затмение","de":"Scharlachfinsternis"},{"key":"Blood Moon","ru":"Багровая луна","de":"Blutmond"},{"key":"Ember Forge","ru":"Огненная кузница","de":"Glutschmiede"},{"key":"Solar Flare","ru":"Солнечная вспышка","de":"Sonneneruption"},{"key":"Ivory Frost","ru":"Белый иней","de":"Elfenbeinreif"},{"key":"Obsidian","ru":"Обсидиан","de":"Obsidian"},{"key":"Glacier","ru":"Ледник","de":"Gletscher"},{"key":"Ocean Depths","ru":"Глубины океана","de":"Ozeantiefe"},{"key":"Midnight Aurora","ru":"Полночное сияние","de":"Mitternachtsaurora"},{"key":"Cyber Pulse","ru":"Киберимпульс","de":"Cyberpuls"},{"key":"Violet Nebula","ru":"Фиолетовая туманность","de":"Violetter Nebel"},{"key":"Cherry Blossom","ru":"Цветение вишни","de":"Kirschblüte"},{"key":"Rose Quartz","ru":"Розовый кварц","de":"Rosenquarz"},{"key":"Peach Sunset","ru":"Персиковый закат","de":"Pfirsichsonnenuntergang"},{"key":"Forest Spirit","ru":"Лесной дух","de":"Waldgeist"},{"key":"Emerald Circuit","ru":"Изумрудная схема","de":"Smaragdschaltkreis"},{"key":"Acid Lime","ru":"Кислотный лайм","de":"Neonlimette"},{"key":"Golden Hour","ru":"Золотой час","de":"Goldene Stunde"},{"key":"Copper Dusk","ru":"Медные сумерки","de":"Kupferdämmerung"},{"key":"Sapphire Night","ru":"Сапфировая ночь","de":"Saphirnacht"},{"key":"Storm Grey","ru":"Грозовое небо","de":"Sturmgrau"},{"key":"Arcade Neon","ru":"Аркадный неон","de":"Arcade-Neon"},{"key":"Polar Dawn","ru":"Полярный рассвет","de":"Polarmorgen"},{"key":"Lavender Haze","ru":"Лавандовая дымка","de":"Lavendeldunst"},{"key":"Raspberry Ink","ru":"Малиновый бархат","de":"Himbeersamt"},{"key":"click to edit","ru":"нажмите для изменения","de":"zum Bearbeiten klicken"},{"key":"Native color scheme","ru":"Цветовая схема терминала","de":"Terminal-Farbschema"},{"key":"Scroll for more settings","ru":"Прокрутите для других настроек","de":"Für weitere Einstellungen scrollen"},{"key":"Low","ru":"Низкая","de":"Niedrig"},{"key":"Moderate","ru":"Средняя","de":"Mittel"},{"key":"High","ru":"Высокая","de":"Hoch"},{"key":"Critical","ru":"Критическая","de":"Kritisch"},{"key":"Clear screen on return","ru":"Очищать при возврате","de":"Bei Rückkehr leeren"},{"key":"Loading on return","ru":"Загрузка при возврате","de":"Ladebild bei Rückkehr"},{"key":"Hardware Info","ru":"Комплектующие","de":"Hardware-Info"},{"key":"Gaming Mode","ru":"Игровой режим","de":"Gaming-Modus"},{"key":"App Launcher","ru":"Запуск приложений","de":"App-Starter"},{"key":"Update Center","ru":"Обновления NEX","de":"NEX-Updates"},{"key":"System Health","ru":"Состояние системы","de":"Systemzustand"},{"key":"Notification Center","ru":"Уведомления","de":"Benachrichtigungen"},{"key":"Model","ru":"Модель","de":"Modell"},{"key":"Maximum clock","ru":"Макс. частота","de":"Max. Takt"},{"key":"Socket","ru":"Сокет","de":"Sockel"},{"key":"Resolution","ru":"Разрешение","de":"Auflösung"},{"key":"Module","ru":"Модуль","de":"Modul"},{"key":"Architecture","ru":"Архитектура","de":"Architektur"},{"key":"Apply recommended plan","ru":"Применить рекомендацию","de":"Empfohlenen Plan anwenden"},{"key":"Choose power plan","ru":"Выбрать схему питания","de":"Energiesparplan wählen"},{"key":"Windows Game Mode","ru":"Игровой режим Windows","de":"Windows-Spielmodus"},{"key":"Windows power options","ru":"Электропитание Windows","de":"Windows-Energieoptionen"},{"key":"Available power plans","ru":"Доступные схемы питания","de":"Verfügbare Energiesparpläne"},{"key":"Recommended","ru":"Рекомендуется","de":"Empfohlen"},{"key":"Balanced plan not found.","ru":"Сбалансированная схема не найдена.","de":"Ausbalancierter Plan fehlt."},{"key":"X3D: Balanced supports normal chipset scheduling.","ru":"X3D: Balanced подходит для работы планировщика чипсета.","de":"X3D: Ausbalanciert unterstützt die Chipsatzplanung."},{"key":"AMD: Balanced is the preferred starting point.","ru":"AMD: лучше начать со сбалансированной схемы.","de":"AMD: Ausbalanciert als Ausgangspunkt."},{"key":"Balanced is a safe default; High performance is optional.","ru":"Balanced по умолчанию; высокая производительность необязательна.","de":"Ausbalanciert als Standard; Höchstleistung optional."},{"key":"Apply power plan","ru":"Применить схему питания","de":"Energieplan anwenden"},{"key":"No CPU or GPU overclocking.","ru":"Без разгона CPU или GPU.","de":"Keine CPU- oder GPU-Übertaktung."},{"key":"Power plan applied.","ru":"Схема питания применена.","de":"Energieplan angewendet."},{"key":"Power plan change failed.","ru":"Не удалось изменить схему питания.","de":"Energieplan konnte nicht geändert werden."},{"key":"Search applications","ru":"Поиск приложений","de":"Apps suchen"},{"key":"Choose application","ru":"Выбрать приложение","de":"App auswählen"},{"key":"Loading applications...","ru":"Загрузка приложений...","de":"Apps werden geladen..."},{"key":"Installed applications","ru":"Установленные приложения","de":"Installierte Apps"},{"key":"Application launched.","ru":"Приложение запущено.","de":"App gestartet."},{"key":"GitHub repository (owner/name)","ru":"Репозиторий GitHub (владелец/имя)","de":"GitHub-Repository (Besitzer/Name)"},{"key":"Invalid repository.","ru":"Некорректный репозиторий.","de":"Ungültiges Repository."},{"key":"Configure a release repository first.","ru":"Сначала укажите репозиторий релизов.","de":"Zuerst Release-Repository konfigurieren."},{"key":"Another query is running.","ru":"Выполняется другой запрос.","de":"Eine andere Abfrage läuft."},{"key":"Checking for releases...","ru":"Проверка релизов...","de":"Releases werden geprüft..."},{"key":"Not a valid NEX installer.","ru":"Некорректный установщик NEX.","de":"Ungültiger NEX-Installer."},{"key":"Select a newer installer.","ru":"Выберите более новый установщик.","de":"Neueren Installer auswählen."},{"key":"Install local update","ru":"Установить локальное обновление","de":"Lokales Update installieren"},{"key":"Only run installers from a source you trust.","ru":"Запускайте установщики только из доверенного источника.","de":"Nur Installer aus vertrauenswürdigen Quellen ausführen."},{"key":"Installed version","ru":"Установленная версия","de":"Installierte Version"},{"key":"Release repository","ru":"Репозиторий релизов","de":"Release-Repository"},{"key":"Configure release repository","ru":"Настроить репозиторий","de":"Release-Repository konfigurieren"},{"key":"Check for releases","ru":"Проверить обновления","de":"Nach Updates suchen"},{"key":"Open releases","ru":"Открыть релизы","de":"Releases öffnen"},{"key":"Latest release","ru":"Последний релиз","de":"Neuester Release"},{"key":"Version cannot be compared","ru":"Не удалось сравнить версии","de":"Version nicht vergleichbar"},{"key":"New version available","ru":"Доступна новая версия","de":"Neue Version verfügbar"},{"key":"No newer release found","ru":"Новая версия не найдена","de":"Keine neuere Version gefunden"},{"key":"Windows Security","ru":"Безопасность Windows","de":"Windows-Sicherheit"},{"key":"Last check","ru":"Последняя проверка","de":"Letzte Prüfung"},{"key":"Recent system errors","ru":"Недавние ошибки системы","de":"Neuere Systemfehler"},{"key":"Restart pending","ru":"Требуется перезапуск","de":"Neustart ausstehend"},{"key":"Defender real-time protection","ru":"Защита Defender в реальном времени","de":"Defender-Echtzeitschutz"},{"key":"Defender real-time protection is off","ru":"Защита Defender отключена","de":"Defender-Echtzeitschutz ist aus"},{"key":"Dismiss current alerts","ru":"Скрыть текущие уведомления","de":"Aktuelle Meldungen ausblenden"},{"key":"Current notifications","ru":"Текущие уведомления","de":"Aktuelle Meldungen"},{"key":"Waiting for health check...","ru":"Ожидание диагностики...","de":"Warte auf Systemprüfung..."},{"key":"No active notifications","ru":"Нет активных уведомлений","de":"Keine aktiven Meldungen"},{"key":"Low disk space","ru":"Мало места на диске","de":"Wenig Speicherplatz"},{"key":"Disk health warning","ru":"Предупреждение о накопителе","de":"Laufwerkswarnung"},{"key":"High memory usage","ru":"Высокая нагрузка памяти","de":"Hohe Speicherauslastung"},{"key":"High GPU temperature","ru":"Высокая температура GPU","de":"Hohe GPU-Temperatur"},{"key":"Temperature alerts use available GPU sensors only.","ru":"Температурные уведомления используют доступные датчики GPU.","de":"Temperaturmeldungen nutzen verfügbare GPU-Sensoren."},{"key":"Click a power plan to apply it.","ru":"Нажмите на схему питания для применения.","de":"Zum Anwenden auf einen Energiesparplan klicken."},{"key":"No power plans found.","ru":"Схемы питания не найдены.","de":"Keine Energiesparpläne gefunden."},{"key":"This power plan is already active.","ru":"Эта схема питания уже активна.","de":"Dieser Energiesparplan ist bereits aktiv."},{"key":"Could not verify the active power plan.","ru":"Не удалось проверить активную схему питания.","de":"Aktiver Energiesparplan konnte nicht überprüft werden."},{"key":"Windows did not activate the selected plan.","ru":"Windows не активировала выбранную схему.","de":"Windows hat den ausgewählten Plan nicht aktiviert."},{"key":"Enabled (Windows default)","ru":"Включён (по умолчанию Windows)","de":"Aktiviert (Windows-Standard)"},{"key":"Event list changed. Refresh and try again.","ru":"Список событий изменился. Обновите и повторите.","de":"Ereignisliste geändert. Aktualisieren und erneut versuchen."},{"key":"Windows did not provide an event description.","ru":"Windows не предоставила описание события.","de":"Windows hat keine Ereignisbeschreibung bereitgestellt."},{"key":"Last 24 hours - up to 30 events. Click an event for details.","ru":"За 24 часа — до 30 событий. Нажмите для подробностей.","de":"Letzte 24 Stunden – bis zu 30 Ereignisse. Für Details anklicken."},{"key":"No recent system errors","ru":"Нет недавних системных ошибок","de":"Keine aktuellen Systemfehler"},{"key":"System event details","ru":"Подробности системных событий","de":"Systemereignisdetails"},{"key":"Event ID","ru":"Код события","de":"Ereignis-ID"},{"key":"Severity","ru":"Уровень","de":"Schweregrad"},{"key":"Error","ru":"Ошибка","de":"Fehler"},{"key":"Description","ru":"Описание","de":"Beschreibung"},{"key":"Source","ru":"Источник","de":"Quelle"},{"key":"Show computer name","ru":"Показывать имя ПК","de":"Computernamen anzeigen"},{"key":"Computer alias","ru":"Псевдоним компьютера","de":"Computer-Alias"},{"key":"Enter computer alias","ru":"Введите имя после @","de":"Namen nach @ eingeben"},{"key":"Use Windows computer name","ru":"Использовать имя ПК Windows","de":"Windows-Computernamen verwenden"},{"key":"Computer alias (Enter keeps current)","ru":"Имя после @ (Enter — оставить)","de":"Computer-Alias (Enter: beibehalten)"},{"key":"Identity preview","ru":"Предпросмотр имени","de":"Namensvorschau"},{"key":"Live preview","ru":"Предпросмотр","de":"Live-Vorschau"},{"key":"Existing prompt (not managed)","ru":"Исходная строка (без изменений)","de":"Vorhandener Prompt (unverändert)"},{"key":"Aurora","ru":"Северное сияние","de":"Aurora"},{"key":"Circuit","ru":"Электроника","de":"Schaltkreis"},{"key":"Metro","ru":"Метро","de":"Metro"},{"key":"Orbit","ru":"Орбита","de":"Orbit"},{"key":"Zen","ru":"Дзен","de":"Zen"},{"key":"Terminal Pro","ru":"Терминал Pro","de":"Terminal Pro"},{"key":"Pixel","ru":"Пиксель","de":"Pixel"},{"key":"Twin Line","ru":"Двойная линия","de":"Doppellinie"},{"key":"Soft Wave","ru":"Мягкая волна","de":"Sanfte Welle"},{"key":"Clear displayed events","ru":"Очистить список событий","de":"Angezeigte Ereignisse leeren"},{"key":"Hide old events in both pages.","ru":"Скрыть старые события в обоих разделах.","de":"Alte Ereignisse in beiden Bereichen ausblenden."},{"key":"Windows event logs will be kept.","ru":"Журналы Windows сохранятся.","de":"Windows-Ereignisprotokolle bleiben erhalten."},{"key":"Wait for a successful event check.","ru":"Дождитесь успешной проверки событий.","de":"Erfolgreiche Ereignisprüfung abwarten."},{"key":"Could not save the event checkpoint.","ru":"Не удалось сохранить отметку очистки.","de":"Zeitpunkt konnte nicht gespeichert werden."},{"key":"Old events hidden. New events will appear automatically.","ru":"Старые события скрыты. Новые появятся автоматически.","de":"Alte Ereignisse ausgeblendet. Neue erscheinen automatisch."},{"key":"Events shown after last clear","ru":"События после очистки","de":"Ereignisse seit letzter Bereinigung"},{"key":"Old events are hidden in Dashboard only.","ru":"Старые события скрыты только в Dashboard.","de":"Alte Ereignisse sind nur im Dashboard ausgeblendet."},{"key":"Choose update file (.ps1)","ru":"Выбрать файл обновления (.ps1)","de":"Update-Datei auswählen (.ps1)"},{"key":"About NEX Dashboard","ru":"О NEX Dashboard","de":"Über NEX Dashboard"},{"key":"Version history","ru":"История обновлений","de":"Versionsverlauf"},{"key":"Recent release notes","ru":"Изменения последних версий","de":"Änderungen der letzten Versionen"},{"key":"Public Edition","ru":"Публичная версия","de":"Öffentliche Version"},{"key":"A customizable PowerShell dashboard for monitoring, tools and terminal appearance.","ru":"Настраиваемая панель PowerShell для мониторинга, инструментов и оформления терминала.","de":"Anpassbares PowerShell-Dashboard für Monitoring, Werkzeuge und Terminalgestaltung."},{"key":"Supports English, Russian and German.","ru":"Поддерживает английский, русский и немецкий языки.","de":"Unterstützt Englisch, Russisch und Deutsch."},{"key":"Local updates keep your personal settings.","ru":"Локальные обновления сохраняют ваши настройки.","de":"Lokale Updates behalten persönliche Einstellungen bei."},{"key":"After installation, reopen PowerShell to load the new version.","ru":"После установки откройте PowerShell заново, чтобы загрузить новую версию.","de":"Nach der Installation PowerShell neu öffnen, um die neue Version zu laden."},{"key":"Online releases are optional.","ru":"Онлайн-релизы необязательны.","de":"Online-Releases sind optional."},{"key":"Update from file","ru":"Обновить из файла","de":"Update aus Datei"},{"key":"Local update","ru":"Локальное обновление","de":"Lokales Update"},{"key":"Reordered navigation; direct local update button; About and changelog.","ru":"Упорядочено меню, добавлены кнопка установки из файла, сведения и история изменений.","de":"Navigation neu geordnet; direkte lokale Installation, Info und Versionsverlauf."},{"key":"Persistent clearing of displayed system events without deleting Windows logs.","ru":"Очистка отображаемых событий с сохранением журналов Windows.","de":"Angezeigte Ereignisse dauerhaft ausblenden, ohne Windows-Protokolle zu löschen."},{"key":"Computer-name visibility and alias; more prompt styles with previews.","ru":"Скрытие имени ПК, псевдоним и новые стили строки ввода с предпросмотром.","de":"Computername ein-/ausblenden, Alias und neue Prompt-Stile mit Vorschau."},{"key":"Detailed system events and notification descriptions.","ru":"Подробности системных событий и описания уведомлений.","de":"Details zu Systemereignissen und Benachrichtigungen."},{"key":"Improved Windows Game Mode detection.","ru":"Улучшено определение игрового режима Windows.","de":"Verbesserte Erkennung des Windows-Spielmodus."},{"key":"Clickable power plans and verified status indicators.","ru":"Кликабельные схемы питания и проверяемые индикаторы состояния.","de":"Anklickbare Energiesparpläne und geprüfte Statusanzeigen."},{"key":"Hardware, Gaming, Apps, Updates, Health and Notifications pages.","ru":"Разделы комплектующих, игр, приложений, обновлений, диагностики и уведомлений.","de":"Hardware-, Gaming-, App-, Update-, Systemzustands- und Benachrichtigungsseiten."},{"key":"Improved transition back to the startup screen.","ru":"Улучшен переход к стартовому экрану.","de":"Verbesserter Übergang zum Startbildschirm."},{"key":"Optional screen clearing and loading animation on return.","ru":"Настройки очистки и анимации при возврате.","de":"Optionale Bildschirmbereinigung und Ladeanimation bei Rückkehr."},{"key":"Expanded color themes, load gradients and settings cleanup.","ru":"Новые цветовые темы, градиенты нагрузки и упрощение настроек.","de":"Weitere Farbthemen, Lastfarbverläufe und bereinigte Einstellungen."},{"key":"Portable configuration export and restore.","ru":"Экспорт и восстановление конфигураций.","de":"Export und Wiederherstellung portabler Konfigurationen."},{"key":"Custom ASCII and Unicode startup logo editor.","ru":"Редактор собственного ASCII/Unicode-логотипа.","de":"Editor für eigene ASCII- und Unicode-Startlogos."},{"key":"Translation key compatibility fix for Windows PowerShell.","ru":"Исправлена совместимость ключей переводов с Windows PowerShell.","de":"Korrektur der Übersetzungsschlüssel für Windows PowerShell."},{"key":"Unified monitor cards and adaptive load colors.","ru":"Единые карточки монитора и цвета нагрузки.","de":"Einheitliche Monitorkarten und adaptive Lastfarben."},{"key":"More localization, DNS controls, icons and Fastfetch animation.","ru":"Расширенная локализация, DNS, иконки и анимация Fastfetch.","de":"Erweiterte Lokalisierung, DNS, Symbole und Fastfetch-Animation."},{"key":"Vendor hardware colors and Nerd Font icon recovery.","ru":"Цвета производителей комплектующих и восстановление иконок Nerd Font.","de":"Herstellerfarben und Wiederherstellung der Nerd-Font-Symbole."},{"key":"Restore Nerd Font in all terminal profiles?","ru":"Восстановить Nerd Font во всех профилях терминала?","de":"Nerd Font in allen Terminalprofilen wiederherstellen?"},{"key":"Icons restored. Reopen terminal tabs.","ru":"Иконки восстановлены. Откройте вкладки терминала заново.","de":"Symbole wiederhergestellt. Terminal-Tabs neu öffnen."},{"key":"Restore icons and font","ru":"Восстановить иконки и шрифт","de":"Symbole und Schrift wiederherstellen"},{"key":"Original monochrome Nerd Font icons restored without emoji fallback.","ru":"Возвращены оригинальные монохромные иконки Nerd Font без замены на эмодзи.","de":"Originale einfarbige Nerd-Font-Symbole ohne Emoji-Ersatz wiederhergestellt."},{"key":"Softer hardware colors, multicolor startup info and in-session updates.","ru":"Мягкие цвета комплектующих, разноцветный Fastfetch и обновление в текущей вкладке.","de":"Sanfte Hardwarefarben, mehrfarbige Startinformationen und Updates in derselben Sitzung."},{"key":"Local updates reload Dashboard in this terminal.","ru":"Локальные обновления перезагружают Dashboard в текущей вкладке.","de":"Lokale Updates laden das Dashboard in diesem Terminal neu."},{"key":"Update installed. Open Dashboard to see the new version.","ru":"Обновление установлено. Откройте Dashboard, чтобы увидеть новую версию.","de":"Update installiert. Dashboard öffnen, um die neue Version zu sehen."},{"key":"Update failed","ru":"Не удалось установить обновление","de":"Update fehlgeschlagen"},{"key":"Download and install update","ru":"Скачать и установить обновление","de":"Update herunterladen und installieren"},{"key":"Install official update","ru":"Установить официальное обновление","de":"Offizielles Update installieren"},{"key":"Download from the official GitHub repository?","ru":"Скачать из официального репозитория GitHub?","de":"Aus dem offiziellen GitHub-Repository herunterladen?"},{"key":"Downloading and verifying update...","ru":"Скачивание и проверка обновления...","de":"Update wird heruntergeladen und geprüft..."},{"key":"No published releases found.","ru":"Опубликованных релизов нет.","de":"Keine veröffentlichten Releases gefunden."},{"key":"Release installer or SHA-256 unavailable.","ru":"Установщик релиза или SHA-256 недоступен.","de":"Release-Installer oder SHA-256 nicht verfügbar."},{"key":"Update integrity check failed.","ru":"Проверка целостности обновления не пройдена.","de":"Integritätsprüfung des Updates fehlgeschlagen."},{"key":"Online update cancelled.","ru":"Онлайн-обновление отменено.","de":"Online-Update abgebrochen."},{"key":"Invalid update version.","ru":"Некорректная версия обновления.","de":"Ungültige Update-Version."},{"key":"Invalid update metadata.","ru":"Некорректные данные обновления.","de":"Ungültige Update-Metadaten."},{"key":"Manual update and information","ru":"Ручное обновление и информация","de":"Manuelles Update und Informationen"},{"key":"Official releases are checked before installation.","ru":"Официальные релизы проверяются перед установкой.","de":"Offizielle Releases werden vor der Installation geprüft."},{"key":"Official online updates with SHA-256 verification and beta release support.","ru":"Официальные онлайн-обновления с проверкой SHA-256 и поддержкой бета-релизов.","de":"Offizielle Online-Updates mit SHA-256-Prüfung und Beta-Unterstützung."},{"key":"Dashboard Designer","ru":"Дизайнер монитора","de":"Dashboard-Designer"},{"key":"Startup Manager","ru":"Автозагрузка","de":"Autostart-Manager"},{"key":"Plugin Manager","ru":"Модули","de":"Modulverwaltung"},{"key":"Animation Studio","ru":"Студия анимаций","de":"Animationsstudio"},{"key":"Search Dashboard","ru":"Поиск по Dashboard","de":"Dashboard durchsuchen"},{"key":"Type to filter; Enter opens the selected result.","ru":"Введите запрос; Enter открывает выбранный раздел.","de":"Tippen zum Filtern; Enter öffnet den gewählten Bereich."},{"key":"Setting explanations","ru":"Объяснения настроек","de":"Einstellungserklärungen"},{"key":"Ctrl+K: search | F1: help | Esc: back","ru":"Ctrl+K: поиск | F1: помощь | Esc: назад","de":"Strg+K: Suche | F1: Hilfe | Esc: zurück"},{"key":"Monitor designer, startup manager, global search, optional modules, animation studio and setting explanations.","ru":"Дизайнер монитора, автозагрузка, поиск, модули, студия анимаций и пояснения настроек.","de":"Monitor-Designer, Autostart, globale Suche, Module, Animationen und Einstellungshilfe."},{"key":"Choose monitor columns","ru":"Выбрать колонки","de":"Spalten wählen"},{"key":"Columns","ru":"Колонки","de":"Spalten"},{"key":"Auto","ru":"Автоматически","de":"Automatisch"},{"key":"Single column","ru":"Одна колонка","de":"Eine Spalte"},{"key":"Two columns","ru":"Две колонки","de":"Zwei Spalten"},{"key":"Move card up","ru":"Поднять карточку","de":"Karte nach oben"},{"key":"Move card down","ru":"Опустить карточку","de":"Karte nach unten"},{"key":"Show or hide card","ru":"Показать или скрыть карточку","de":"Karte ein-/ausblenden"},{"key":"Choose monitor card","ru":"Выбрать карточку","de":"Monitorkarte wählen"},{"key":"Preview monitor","ru":"Предпросмотр монитора","de":"Monitorvorschau"},{"key":"Reset layout","ru":"Сбросить расположение","de":"Layout zurücksetzen"},{"key":"Card order","ru":"Порядок карточек","de":"Kartenreihenfolge"},{"key":"Arrange the System Monitor cards. Click a card to show or hide it.","ru":"Настройте карточки монитора. Нажмите на карточку, чтобы скрыть или показать её.","de":"Monitorkarten anordnen. Anklicken zum Ein- oder Ausblenden."},{"key":"Keep at least one monitor card visible.","ru":"Оставьте хотя бы одну карточку.","de":"Mindestens eine Karte muss sichtbar bleiben."},{"key":"Windows Startup Apps","ru":"Автозагрузка Windows","de":"Windows-Autostart-Apps"},{"key":"Open user startup folder","ru":"Открыть папку автозагрузки пользователя","de":"Benutzer-Autostartordner öffnen"},{"key":"Open shared startup folder","ru":"Открыть общую папку автозагрузки","de":"Gemeinsamen Autostartordner öffnen"},{"key":"Use Windows Startup Apps to enable or disable entries.","ru":"Включайте и отключайте приложения в настройках автозагрузки Windows.","de":"Apps in den Windows-Autostarteinstellungen aktivieren oder deaktivieren."},{"key":"This list is read-only and may not include all disabled apps or scheduled tasks.","ru":"Список только для чтения; не все отключённые приложения и задачи отображаются.","de":"Liste nur lesbar; nicht alle deaktivierten Apps und Aufgaben sind enthalten."},{"key":"Detected startup commands","ru":"Найденные команды автозагрузки","de":"Gefundene Autostartbefehle"},{"key":"Startup command","ru":"Команда автозагрузки","de":"Autostartbefehl"},{"key":"No startup commands found.","ru":"Команды автозагрузки не найдены.","de":"Keine Autostartbefehle gefunden."},{"key":"Built-in modules add widgets to the header. No external scripts are executed.","ru":"Встроенные модули добавляют виджеты в верхнюю панель. Внешние скрипты не запускаются.","de":"Integrierte Module ergänzen die Kopfzeile. Externe Skripte werden nicht ausgeführt."},{"key":"Battery module","ru":"Модуль батареи","de":"Akkumodul"},{"key":"Session module","ru":"Модуль сеанса","de":"Sitzungsmodul"},{"key":"Shortcut module","ru":"Модуль ярлыков","de":"Verknüpfungsmodul"},{"key":"Shows battery charge and power status in the header on supported PCs.","ru":"Показывает заряд и питание в верхней панели на ПК с аккумулятором.","de":"Zeigt Akkustand und Stromversorgung in der Kopfzeile auf unterstützten PCs."},{"key":"Shows elapsed Dashboard session time in the header.","ru":"Показывает длительность сеанса Dashboard в верхней панели.","de":"Zeigt die Sitzungsdauer in der Kopfzeile."},{"key":"Adds header shortcuts to App Launcher and Dashboard Designer.","ru":"Добавляет в верхнюю панель кнопки запуска приложений и дизайнера.","de":"Ergänzt Schnellzugriffe auf App-Starter und Designer in der Kopfzeile."},{"key":"Module preview","ru":"Предпросмотр модулей","de":"Modulvorschau"},{"key":"Battery information unavailable","ru":"Данные батареи недоступны","de":"Akkuinformationen nicht verfügbar"},{"key":"No system battery","ru":"Батарея отсутствует","de":"Kein Systemakku"},{"key":"Online","ru":"От сети","de":"Netzbetrieb"},{"key":"Offline","ru":"От батареи","de":"Akkubetrieb"},{"key":"Choose loading animation","ru":"Выбрать анимацию загрузки","de":"Ladeanimation wählen"},{"key":"Choose animation speed","ru":"Выбрать скорость анимации","de":"Animationsgeschwindigkeit wählen"},{"key":"Animation","ru":"Анимация","de":"Animation"},{"key":"Speed","ru":"Скорость","de":"Geschwindigkeit"},{"key":"Progress","ru":"Полоса","de":"Fortschritt"},{"key":"Pulse","ru":"Импульс","de":"Impuls"},{"key":"Wave","ru":"Волна","de":"Welle"},{"key":"Dots","ru":"Точки","de":"Punkte"},{"key":"Fast","ru":"Быстро","de":"Schnell"},{"key":"Normal","ru":"Обычно","de":"Normal"},{"key":"Slow","ru":"Медленно","de":"Langsam"},{"key":"Preview loading animation","ru":"Предпросмотр загрузки","de":"Ladeanimation ansehen"},{"key":"Reset animations","ru":"Сбросить анимации","de":"Animationen zurücksetzen"},{"key":"Speed changes loading and Fastfetch reveal. Preview does not restart the terminal.","ru":"Скорость влияет на загрузку и появление Fastfetch. Предпросмотр не перезапускает терминал.","de":"Tempo gilt für Ladebildschirm und Fastfetch. Vorschau ohne Terminalneustart."},{"key":"Help","ru":"Помощь","de":"Hilfe"},{"key":"Search Dashboard with Ctrl+K. Tab switches between navigation and content. Esc returns to Overview or the shell.","ru":"Ctrl+K — поиск. Tab — переключение меню и содержимого. Esc — возврат в Обзор или терминал.","de":"Strg+K: Suche. Tab wechselt Navigation und Inhalt. Esc kehrt zur Übersicht oder Shell zurück."},{"key":"Changes the language of the Dashboard interface.","ru":"Меняет язык интерфейса Dashboard.","de":"Ändert die Oberflächensprache."},{"key":"Changes your displayed name, not the Windows account.","ru":"Меняет отображаемое имя, не учётную запись Windows.","de":"Ändert den Anzeigenamen, nicht das Windows-Konto."},{"key":"Shows or hides @computer in the prompt and startup info.","ru":"Показывает или скрывает @имя ПК в строке ввода и Fastfetch.","de":"Zeigt oder verbirgt @Computer in Prompt und Startinfo."},{"key":"Sets a custom computer alias without renaming Windows.","ru":"Задаёт псевдоним ПК без переименования в Windows.","de":"Legt einen Alias fest, ohne Windows umzubenennen."},{"key":"Changes the color palette of Dashboard and the terminal.","ru":"Меняет цветовую палитру Dashboard и терминала.","de":"Ändert die Farbpalette von Dashboard und Terminal."},{"key":"Sets your own accent color using a six-digit HEX code.","ru":"Задаёт свой акцентный цвет через шестизначный HEX-код.","de":"Legt eine eigene Akzentfarbe per sechsstelligem HEX-Code fest."},{"key":"Shows a loading animation when the shell starts.","ru":"Показывает анимацию загрузки при запуске оболочки.","de":"Zeigt beim Shellstart eine Ladeanimation."},{"key":"Clears visible output on return; command history is preserved.","ru":"Очищает видимый вывод при возврате; история команд сохраняется.","de":"Löscht beim Zurückkehren die sichtbare Ausgabe, nicht den Verlauf."},{"key":"Shows a loading animation when leaving Dashboard.","ru":"Показывает анимацию при выходе из Dashboard.","de":"Zeigt eine Ladeanimation beim Verlassen des Dashboards."},{"key":"Displays hardware and software information at shell startup.","ru":"Показывает информацию о ПК при запуске оболочки.","de":"Zeigt Hardware- und Softwareinfos beim Shellstart."},{"key":"Reveals startup information line by line.","ru":"Показывает стартовую информацию построчно.","de":"Blendet Startinformationen zeilenweise ein."},{"key":"Selects the layout used for startup hardware information.","ru":"Выбирает оформление стартовой информации о ПК.","de":"Wählt das Layout der Startinformationen."},{"key":"Edits the ASCII logo. Save an empty editor to restore the default.","ru":"Редактирует ASCII-логотип. Пустой редактор возвращает стандартный.","de":"Bearbeitet das ASCII-Logo. Leer speichern stellt den Standard wieder her."},{"key":"Changes the appearance of the PowerShell command prompt.","ru":"Меняет внешний вид строки ввода PowerShell.","de":"Ändert das Aussehen der PowerShell-Eingabeaufforderung."},{"key":"Enables monochrome Nerd Font icons. A compatible font is required.","ru":"Включает монохромные значки Nerd Font. Нужен совместимый шрифт.","de":"Aktiviert einfarbige Nerd-Font-Symbole; passende Schrift erforderlich."},{"key":"Enables history-based suggestions when PSReadLine supports them.","ru":"Включает подсказки из истории, если их поддерживает PSReadLine.","de":"Aktiviert Verlaufsvorschläge, sofern PSReadLine sie unterstützt."},{"key":"Labels your internet access type; it does not change networking.","ru":"Задаёт подпись типа интернета, не изменяя сеть.","de":"Beschriftet den Internetzugang, ändert keine Netzwerkeinstellungen."},{"key":"Repairs the Nerd Font installation and applies it to terminal profiles.","ru":"Восстанавливает Nerd Font и применяет его к профилям терминала.","de":"Repariert Nerd Font und wendet ihn auf Terminalprofile an."},{"key":"Applies the selected palette to Windows Terminal profiles.","ru":"Применяет выбранную палитру к профилям Windows Terminal.","de":"Wendet die Palette auf Windows-Terminal-Profile an."},{"key":"Shows a preview of the startup information.","ru":"Показывает предпросмотр стартовой информации.","de":"Zeigt eine Vorschau der Startinformationen."},{"key":"Changes individual native terminal colors.","ru":"Меняет отдельные цвета терминала.","de":"Ändert einzelne native Terminalfarben."},{"key":"Selects a Windows Terminal color scheme.","ru":"Выбирает цветовую схему Windows Terminal.","de":"Wählt ein Windows-Terminal-Farbschema."},{"key":"Exports portable personalization settings to a file.","ru":"Сохраняет переносимые настройки в файл.","de":"Exportiert portable Einstellungen in eine Datei."},{"key":"Restores personalization from a configuration file.","ru":"Восстанавливает персонализацию из файла конфигурации.","de":"Stellt Einstellungen aus einer Konfigurationsdatei wieder her."},{"key":"Shows explanations in setting selection dialogs.","ru":"Показывает пояснения в окнах выбора настроек.","de":"Zeigt Erläuterungen in den Einstellungsdialogen."},{"key":"Selects the Windows Terminal profile to inspect.","ru":"Выбирает профиль Windows Terminal для просмотра.","de":"Wählt das zu prüfende Windows-Terminal-Profil."},{"key":"Controls terminal opacity: 100 percent is fully opaque.","ru":"Настраивает прозрачность терминала: 100% — непрозрачный.","de":"Regelt die Deckkraft: 100 Prozent ist undurchsichtig."},{"key":"Toggles the acrylic blur effect where Windows supports it.","ru":"Включает размытие Acrylic, если Windows его поддерживает.","de":"Schaltet den Acrylic-Weichzeichner ein oder aus."},{"key":"Changes the shape of the text cursor.","ru":"Меняет форму текстового курсора.","de":"Ändert die Form des Textcursors."},{"key":"Opens the native Windows Terminal JSON settings file.","ru":"Открывает родной JSON-файл настроек Windows Terminal.","de":"Öffnet die native Windows-Terminal-JSON-Datei."},{"key":"Reloads terminal settings from disk.","ru":"Перечитывает настройки терминала с диска.","de":"Lädt Terminaleinstellungen erneut von der Festplatte."},{"key":"AC power","ru":"Питание от сети","de":"Netzbetrieb"},{"key":"Battery power","ru":"Питание от батареи","de":"Akkubetrieb"},{"key":"Power source unknown","ru":"Источник питания неизвестен","de":"Stromquelle unbekannt"},{"key":"No matching sections. Change the search text.","ru":"Ничего не найдено. Измените запрос.","de":"Keine Treffer. Suchtext ändern."},{"key":"No modules enabled","ru":"Модули не включены","de":"Keine Module aktiviert"},{"key":"Select a Windows power plan. Balanced is recommended for most systems.","ru":"Выберите схему питания Windows. Сбалансированная подходит большинству ПК.","de":"Energiesparplan wählen. Ausbalanciert wird für die meisten PCs empfohlen."},{"key":"Select the card to move or show and hide.","ru":"Выберите карточку для перемещения или изменения видимости.","de":"Karte zum Verschieben oder Ein-/Ausblenden wählen."},{"key":"Select the startup and return loading animation.","ru":"Выберите анимацию при запуске и возврате из Dashboard.","de":"Animation für Start und Rückkehr auswählen."},{"key":"One column is full-width; two columns adapt to the terminal size.","ru":"Одна колонка на всю ширину; две колонки подстраиваются под размер окна.","de":"Eine Spalte nutzt die Breite; zwei Spalten passen sich der Fenstergröße an."},{"key":"Continue","ru":"Продолжить","de":"Weiter"},{"key":"Apps","ru":"Приложения","de":"Apps"},{"key":"Layout","ru":"Макет","de":"Layout"},{"key":"Apply","ru":"Применить","de":"Anwenden"},{"key":"One line","ru":"Одна строка","de":"Eine Zeile"},{"key":"Two lines","ru":"Две строки","de":"Zwei Zeilen"},{"key":"Prompt styles","ru":"Стили строки ввода","de":"Prompt-Stile"},{"key":"Click to preview","ru":"Нажмите для просмотра","de":"Klicken für Vorschau"},{"key":"Current style","ru":"Текущий стиль","de":"Aktueller Stil"},{"key":"Enter: Apply | Esc: Cancel","ru":"Enter: применить | Esc: отмена","de":"Enter: Anwenden | Esc: Abbrechen"},{"key":"Install optional Ookla Speedtest CLI for personal use?","ru":"Установить необязательный Ookla Speedtest для личного использования?","de":"Optionalen Ookla Speedtest CLI für den privaten Gebrauch installieren?"},{"key":"Downloading and verifying Ookla Speedtest...","ru":"Скачивание и проверка Ookla Speedtest...","de":"Ookla Speedtest wird heruntergeladen und geprüft..."},{"key":"Ookla Speedtest installed.","ru":"Ookla Speedtest установлен.","de":"Ookla Speedtest installiert."},{"key":"Speedtest installation failed","ru":"Не удалось установить Speedtest","de":"Speedtest-Installation fehlgeschlagen"},{"key":"Install Ookla Speedtest?","ru":"Установить Ookla Speedtest?","de":"Ookla Speedtest installieren?"},{"key":"Official download for personal use.","ru":"Официальная загрузка для личного использования.","de":"Offizieller Download für den privaten Gebrauch."},{"key":"No administrator rights required.","ru":"Права администратора не нужны.","de":"Keine Administratorrechte erforderlich."},{"key":"Accept Ookla terms for personal use?","ru":"Принять условия Ookla для личного использования?","de":"Ookla-Bedingungen für den privaten Gebrauch akzeptieren?"},{"key":"Accept Ookla privacy notice?","ru":"Принять политику конфиденциальности Ookla?","de":"Ookla-Datenschutzhinweise akzeptieren?"},{"key":"A test sends connection data to Ookla.","ru":"Тест отправляет данные подключения в Ookla.","de":"Der Test sendet Verbindungsdaten an Ookla."},{"key":"Download and install Ookla Speedtest","ru":"Скачать и установить Ookla Speedtest","de":"Ookla Speedtest herunterladen und installieren"},{"key":"Speedtest failed. Try again.","ru":"Ошибка Speedtest. Повторите попытку.","de":"Speedtest fehlgeschlagen. Erneut versuchen."},{"key":"Optional Ookla Speedtest installation and first-test consent.","ru":"Необязательная установка Ookla Speedtest и согласие перед первым тестом.","de":"Optionale Ookla-Speedtest-Installation und Zustimmung vor dem ersten Test."},{"key":"Yes","ru":"Да","de":"Ja"},{"key":"No","ru":"Нет","de":"Nein"},{"key":"Windows Update restart","ru":"Перезапуск для Windows Update","de":"Neustart für Windows Update"},{"key":"Servicing restart marker","ru":"Маркер перезапуска обслуживания","de":"Neustartmarker der Wartung"},{"key":"Restart marker detected","ru":"Обнаружен маркер перезапуска","de":"Neustartmarker erkannt"},{"key":"Restart source unavailable","ru":"Источник перезапуска недоступен","de":"Neustartquelle nicht verfügbar"},{"key":"Windows Update requires restart","ru":"Windows Update требует перезапуск","de":"Windows Update erfordert Neustart"},{"key":"Local connection","ru":"Локальное подключение","de":"Lokale Verbindung"},{"key":"Ethernet","ru":"Ethernet","de":"Ethernet"},{"key":"Wi-Fi","ru":"Wi-Fi","de":"WLAN"},{"key":"Mobile network","ru":"Мобильная сеть","de":"Mobilfunk"},{"key":"Other adapter","ru":"Другой адаптер","de":"Anderer Adapter"},{"key":"Identity and language","ru":"Имя и язык","de":"Identität und Sprache"},{"key":"Colors and appearance","ru":"Цвета и оформление","de":"Farben und Darstellung"},{"key":"Startup and transitions","ru":"Запуск и переходы","de":"Start und Übergänge"},{"key":"Startup information","ru":"Информация при запуске","de":"Startinformationen"},{"key":"Prompt and input","ru":"Строка ввода и подсказки","de":"Eingabe und Vorschläge"},{"key":"Terminal appearance and backup","ru":"Оформление терминала и резервные копии","de":"Terminaldesign und Sicherung"},{"key":"I/O","ru":"Ввод/вывод","de":"E/A"},{"key":"TCP","ru":"TCP","de":"TCP"},{"key":"Process metrics","ru":"Показатели процессов","de":"Prozessmetriken"},{"key":"I/O includes file, device and network operations; TCP is connection count, not speed.","ru":"I/O включает файлы, устройства и сеть; TCP — число соединений, не скорость.","de":"E/A umfasst Dateien, Geräte und Netzwerk; TCP ist die Verbindungszahl, keine Geschwindigkeit."},{"key":"Processes sampled","ru":"Процессов измерено","de":"Erfasste Prozesse"},{"key":"GPU %","ru":"GPU %","de":"GPU %"},{"key":"I/O MiB/s","ru":"I/O МиБ/с","de":"E/A MiB/s"},{"key":"TCP count","ru":"TCP (шт.)","de":"TCP-Anzahl"},{"key":"Sidebar separators","ru":"Разделители меню","de":"Menü-Trennlinien"},{"key":"Show horizontal separators between sidebar groups.","ru":"Показывает горизонтальные линии между группами бокового меню.","de":"Zeigt horizontale Trennlinien zwischen Menügruppen."},{"key":"TCP active","ru":"TCP активн.","de":"TCP aktiv"},{"key":"Resource Monitor","ru":"Монитор ресурсов","de":"Ressourcenmonitor"},{"key":"Per-process network speed is available in Windows Resource Monitor.","ru":"Скорость сети по процессам доступна в мониторе ресурсов Windows.","de":"Netzwerkrate pro Prozess im Windows-Ressourcenmonitor."},{"key":"TCP counts established connections only, not Mbps.","ru":"TCP — число установленных соединений, не Мбит/с.","de":"TCP zählt aktive Verbindungen, keine Mbit/s."},{"key":"Reset Ookla consent","ru":"Сбросить согласие Ookla","de":"Ookla-Zustimmung zurücksetzen"},{"key":"Ookla consent reset.","ru":"Согласие Ookla сброшено.","de":"Ookla-Zustimmung zurückgesetzt."},{"key":"Light interface","ru":"Светлый интерфейс","de":"Helle Oberfläche"},{"key":"Reset Dashboard to defaults","ru":"Сброс Dashboard к заводским настройкам","de":"Dashboard zurücksetzen"},{"key":"All NEX preferences will be reset.","ru":"Все настройки NEX будут сброшены.","de":"Alle NEX-Einstellungen werden zurückgesetzt."},{"key":"Your files and installed programs are kept.","ru":"Ваши файлы и программы сохранятся.","de":"Dateien und installierte Programme bleiben erhalten."},{"key":"Dashboard reset. Backup saved. Reopen terminal tabs if needed.","ru":"Настройки сброшены. Копия сохранена. При необходимости откройте вкладки заново.","de":"Dashboard zurückgesetzt. Sicherung gespeichert. Tabs ggf. neu öffnen."},{"key":"Full PC scan","ru":"Полная проверка ПК","de":"PC-Gesamtprüfung"},{"key":"Start scan","ru":"Начать проверку","de":"Prüfung starten"},{"key":"Stop","ru":"Стоп","de":"Stopp"},{"key":"Read-only checks; no automatic repairs.","ru":"Только проверка, без автоисправлений.","de":"Nur Prüfung, keine automatische Reparatur."},{"key":"Review","ru":"Требует внимания","de":"Prüfen"},{"key":"Info","ru":"Информация","de":"Info"},{"key":"Drivers","ru":"Драйверы","de":"Treiber"},{"key":"System logs","ru":"Журналы системы","de":"Systemprotokolle"},{"key":"Windows image (DISM)","ru":"Образ Windows (DISM)","de":"Windows-Abbild (DISM)"},{"key":"Device Manager","ru":"Диспетчер устройств","de":"Geräte-Manager"},{"key":"Memory diagnostics","ru":"Диагностика памяти","de":"Speicherdiagnose"},{"key":"Network settings","ru":"Настройки сети","de":"Netzwerkeinstellungen"},{"key":"Restart","ru":"Перезагрузка","de":"Neustart"},{"key":"Restart computer?","ru":"Перезагрузить компьютер?","de":"Computer neu starten?"},{"key":"Save your work before restarting.","ru":"Сохраните работу перед перезапуском.","de":"Vor dem Neustart Arbeit speichern."},{"key":"Windows will restart after confirmation.","ru":"Windows перезапустится после подтверждения.","de":"Windows startet nach Bestätigung neu."},{"key":"Finish the scan before restarting.","ru":"Дождитесь окончания проверки.","de":"Prüfung zuerst abschließen."},{"key":"Restart is no longer required.","ru":"Перезапуск больше не требуется.","de":"Neustart nicht mehr erforderlich."},{"key":"No data returned.","ru":"Нет данных.","de":"Keine Daten."},{"key":"Some device status is unavailable.","ru":"Статус некоторых устройств недоступен.","de":"Gerätestatus teilweise unbekannt."},{"key":"Windows reports normal device status.","ru":"Windows сообщает нормальное состояние устройств.","de":"Windows meldet normalen Gerätestatus."},{"key":"Memory detected; not a physical RAM test.","ru":"Память обнаружена; не тест ячеек RAM.","de":"Speicher erkannt; kein physischer RAM-Test."},{"key":"Reported drive health is normal.","ru":"Накопители сообщают нормальное состояние.","de":"Gemeldeter Laufwerkszustand normal."},{"key":"Some drive health is unavailable.","ru":"Статус некоторых дисков недоступен.","de":"Laufwerkszustand teilweise unbekannt."},{"key":"No PnP problem codes reported.","ru":"Коды ошибок PnP не обнаружены.","de":"Keine PnP-Fehlercodes gemeldet."},{"key":"A local default gateway is configured.","ru":"Локальный шлюз настроен.","de":"Lokales Standardgateway konfiguriert."},{"key":"No default gateway detected.","ru":"Основной шлюз не обнаружен.","de":"Kein Standardgateway erkannt."},{"key":"Defender real-time protection is on.","ru":"Защита Defender в реальном времени включена.","de":"Defender-Echtzeitschutz ist aktiv."},{"key":"Defender real-time protection is off; another antivirus may be active.","ru":"Защита Defender отключена; возможно, работает другой антивирус.","de":"Defender-Echtzeitschutz aus; ggf. anderes Antivirus aktiv."},{"key":"No critical/error system events in the last 24 hours.","ru":"Критические события и ошибки за 24 часа не найдены.","de":"Keine kritischen Ereignisse/Fehler in den letzten 24 Stunden."},{"key":"Windows Update reports that a restart is required.","ru":"Windows Update сообщает о необходимости перезапуска.","de":"Windows Update erfordert einen Neustart."},{"key":"Windows Update does not require a restart.","ru":"Windows Update не требует перезапуска.","de":"Windows Update benötigt keinen Neustart."},{"key":"Administrator rights are needed for DISM ScanHealth.","ru":"Для DISM ScanHealth нужны права администратора.","de":"DISM ScanHealth benötigt Administratorrechte."},{"key":"DISM reports a healthy Windows component store.","ru":"DISM: хранилище компонентов Windows исправно.","de":"DISM: Windows-Komponentenspeicher intakt."},{"key":"DISM found repairable corruption. Review Windows repair options.","ru":"DISM обнаружил исправимые повреждения. Проверьте варианты восстановления Windows.","de":"DISM meldet reparierbare Beschädigung. Windows-Reparaturoptionen prüfen."},{"key":"DISM reports non-repairable corruption. Seek Windows support.","ru":"DISM обнаружил неисправимые повреждения. Обратитесь в поддержку Windows.","de":"DISM meldet nicht reparierbare Beschädigung. Windows-Support kontaktieren."},{"key":"System files (SFC)","ru":"Системные файлы (SFC)","de":"Systemdateien (SFC)"},{"key":"Administrator rights are needed for SFC verification.","ru":"Для проверки SFC нужны права администратора.","de":"SFC-Prüfung benötigt Administratorrechte."},{"key":"Devices and connectivity","ru":"Устройства и подключение","de":"Geräte und Verbindung"},{"key":"Windows and security","ru":"Windows и безопасность","de":"Windows und Sicherheit"},{"key":"Event history","ru":"История событий","de":"Ereignisverlauf"},{"key":"Admin required","ru":"Нужны права администратора","de":"Adminrechte nötig"},{"key":"Click a check to see details.","ru":"Нажмите на проверку для подробностей.","de":"Prüfung für Details anklicken."},{"key":"Click a check for details | Up/Down | B Back","ru":"Нажмите на проверку · ↑↓ прокрутка · B назад","de":"Prüfung anklicken · ↑↓ scrollen · B zurück"},{"key":"Past system events; not proof of an active fault. Review the event IDs and timestamps.","ru":"Прошлые события, не доказательство текущей ошибки. Проверьте коды и время.","de":"Vergangene Ereignisse, kein Nachweis eines aktiven Fehlers. IDs und Zeit prüfen."},{"key":"No completed Windows memory test found.","ru":"Нет результата завершённой проверки памяти Windows.","de":"Kein abgeschlossenes Windows-Speichertestergebnis."},{"key":"Memory test result could not be read.","ru":"Не удалось прочитать результат проверки памяти.","de":"Speichertestergebnis nicht lesbar."},{"key":"Last Windows memory test reported errors.","ru":"Последняя проверка памяти Windows выявила ошибки.","de":"Letzter Windows-Speichertest meldete Fehler."},{"key":"Last Windows memory test reported no errors.","ru":"Последняя проверка памяти Windows не выявила ошибок.","de":"Letzter Windows-Speichertest meldete keine Fehler."},{"key":"Run as administrator","ru":"Запустить от администратора","de":"Als Administrator starten"},{"key":"Open a separate elevated PowerShell window?","ru":"Открыть отдельное окно PowerShell с правами администратора?","de":"Separates PowerShell-Fenster mit Adminrechten öffnen?"},{"key":"Windows will ask for permission.","ru":"Windows запросит разрешение.","de":"Windows fragt nach Berechtigung."},{"key":"Check the service name and error in the description.","ru":"Проверьте название службы и текст ошибки в описании.","de":"Dienstname und Fehler in der Beschreibung prüfen."},{"key":"Check firewall status in Windows Security; do not disable protection.","ru":"Проверьте состояние брандмауэра в Безопасности Windows; не отключайте защиту.","de":"Firewallstatus in Windows-Sicherheit prüfen; Schutz nicht deaktivieren."},{"key":"Review the boot security policy and status in the description.","ru":"Проверьте политику безопасности загрузки и статус в описании.","de":"Startsicherheitsrichtlinie und Status in der Beschreibung prüfen."},{"key":"Acrylic blurs and blends with the desktop. Disable it for clear transparency.","ru":"Размытие смешивает фон с рабочим столом. Выключите его для чёткой прозрачности.","de":"Acryl mischt den Hintergrund mit dem Desktop. Für klare Transparenz ausschalten."},{"key":"Admin","ru":"Админ","de":"Admin"},{"key":"Open normal terminal","ru":"Открыть обычный терминал","de":"Normales Terminal öffnen"},{"key":"Open a separate non-administrator window.","ru":"Открыть отдельное окно без прав администратора.","de":"Separates Fenster ohne Administratorrechte öffnen."},{"key":"The current window stays open.","ru":"Текущее окно останется открытым.","de":"Das aktuelle Fenster bleibt geöffnet."},{"key":"New terminal requested. The current window stays open.","ru":"Запрошено новое окно. Текущее окно останется открытым.","de":"Neues Fenster angefordert. Das aktuelle bleibt geöffnet."},{"key":"Finish the active operation first.","ru":"Сначала завершите текущую операцию.","de":"Zuerst den laufenden Vorgang abschließen."},{"key":"Switch to a standard PowerShell session.","ru":"Переключиться в обычную сессию PowerShell.","de":"Zu einer normalen PowerShell-Sitzung wechseln."},{"key":"This PowerShell session closes after successful switching.","ru":"После успешного перехода текущая сессия PowerShell закроется.","de":"Nach erfolgreichem Wechsel wird diese PowerShell-Sitzung geschlossen."},{"key":"Switching terminal mode...","ru":"Переключение режима терминала...","de":"Terminalmodus wird gewechselt..."},{"key":"Switch not confirmed. Original session kept.","ru":"Переход не подтверждён. Исходная сессия сохранена.","de":"Wechsel nicht bestätigt. Ursprüngliche Sitzung bleibt offen."},{"key":"Benchmark Center","ru":"Бенчмарки","de":"Benchmarks"},{"key":"Large files and folders","ru":"Крупные файлы и папки","de":"Große Dateien und Ordner"},{"key":"Favorites","ru":"Избранное","de":"Favoriten"},{"key":"Pin / unpin current section","ru":"Добавить / убрать из избранного","de":"Bereich anheften / lösen"},{"key":"Home layout","ru":"Настройка главной","de":"Startseitenlayout"},{"key":"Identity","ru":"Компьютер и пользователь","de":"Computer und Benutzer"},{"key":"Metrics","ru":"Показатели системы","de":"Systemwerte"},{"key":"Actions","ru":"Быстрые действия","de":"Schnellaktionen"},{"key":"Compact mode","ru":"Компактный режим","de":"Kompaktmodus"},{"key":"Drag card headers to reorder","ru":"Перетащите заголовки карточек","de":"Kartentitel zum Sortieren ziehen"},{"key":"Drag rows to reorder; click to toggle","ru":"Перетащите строки; клик — скрыть/показать","de":"Zeilen ziehen; Klick blendet um"},{"key":"Search large files","ru":"Поиск крупных файлов","de":"Große Dateien suchen"},{"key":"Scan current folder","ru":"Сканировать текущую папку","de":"Aktuellen Ordner scannen"},{"key":"Choose scan folder","ru":"Выбрать папку для анализа","de":"Scanordner wählen"},{"key":"Cancel task","ru":"Отменить задачу","de":"Aufgabe abbrechen"},{"key":"Largest files","ru":"Самые крупные файлы","de":"Größte Dateien"},{"key":"Largest folders","ru":"Самые крупные папки","de":"Größte Ordner"},{"key":"Scan is read-only; links and inaccessible items are skipped.","ru":"Только чтение; ссылки и недоступные объекты пропускаются.","de":"Nur Lesen; Links und nicht zugängliche Elemente werden übersprungen."},{"key":"Scanned items","ru":"Проверено объектов","de":"Geprüfte Elemente"},{"key":"Skipped items","ru":"Пропущено объектов","de":"Übersprungene Elemente"},{"key":"Partial results","ru":"Неполные результаты","de":"Teilergebnisse"},{"key":"Open location","ru":"Открыть расположение","de":"Speicherort öffnen"},{"key":"No scan yet","ru":"Сканирование ещё не запускалось","de":"Noch kein Scan"},{"key":"A background task is busy. Try again shortly.","ru":"Фоновая задача занята. Повторите чуть позже.","de":"Hintergrundaufgabe läuft. Gleich erneut versuchen."},{"key":"CPU quick test","ru":"Быстрый тест CPU","de":"CPU-Kurztest"},{"key":"RAM quick test","ru":"Быстрый тест ОЗУ","de":"RAM-Kurztest"},{"key":"GPU telemetry test","ru":"Тест показателей GPU","de":"GPU-Telemetrietest"},{"key":"Choose duration","ru":"Выбрать длительность","de":"Dauer wählen"},{"key":"Test duration","ru":"Длительность теста","de":"Testdauer"},{"key":"Peak throughput","ru":"Пиковая пропускная способность","de":"Spitzendurchsatz"},{"key":"Average throughput","ru":"Средняя пропускная способность","de":"Mittlerer Durchsatz"},{"key":"Peak load","ru":"Пиковая нагрузка","de":"Spitzenauslastung"},{"key":"Peak temperature","ru":"Пиковая температура","de":"Spitzentemperatur"},{"key":"Errors detected","ru":"Обнаружено ошибок","de":"Erkannte Fehler"},{"key":"Hardware event count","ru":"Аппаратные события","de":"Hardwareereignisse"},{"key":"Measurement samples","ru":"Количество измерений","de":"Messwerte"},{"key":"Not a full stability test.","ru":"Не является полной проверкой стабильности.","de":"Kein vollständiger Stabilitätstest."},{"key":"GPU telemetry only: run your usual graphics application separately.","ru":"GPU: только замеры. Запустите обычное графическое приложение отдельно.","de":"Nur GPU-Telemetrie: normale Grafikanwendung separat starten."},{"key":"Test report","ru":"Отчёт тестирования","de":"Testbericht"},{"key":"Register Windows editor","ru":"Добавить NEX Terminal Editor","de":"NEX Terminal Editor hinzufügen"},{"key":"Remove Windows editor registration","ru":"Убрать NEX Terminal Editor","de":"NEX Terminal Editor entfernen"},{"key":"Does not change default file associations.","ru":"Не меняет приложения по умолчанию.","de":"Ändert keine Standardprogramme."},{"key":"Editor registered.","ru":"Редактор зарегистрирован.","de":"Editor registriert."},{"key":"Editor registration removed.","ru":"Регистрация редактора удалена.","de":"Editor abgemeldet."},{"key":"No test yet","ru":"Тест ещё не запускался","de":"Noch kein Test"},{"key":"Cancelled","ru":"Отменено","de":"Abgebrochen"},{"key":"Elapsed","ru":"Прошло","de":"Vergangen"},{"key":"Data size","ru":"Объём данных","de":"Datenmenge"},{"key":"File search limit reached","ru":"Достигнут лимит поиска","de":"Suchlimit erreicht"},{"key":"CPU usage (system)","ru":"Нагрузка CPU (система)","de":"CPU-Auslastung (System)"},{"key":"RAM usage (system)","ru":"Нагрузка ОЗУ (система)","de":"RAM-Auslastung (System)"},{"key":"GPU usage (max engine)","ru":"Нагрузка GPU (макс. движок)","de":"GPU-Auslastung (max. Engine)"},{"key":"Test type","ru":"Тип теста","de":"Testtyp"},{"key":"No GPU counter available","ru":"Счётчик GPU недоступен","de":"GPU-Zähler nicht verfügbar"},{"key":"No full-memory coverage.","ru":"Проверяется не вся память.","de":"Keine vollständige Speicherprüfung."},{"key":"Pin / unpin section","ru":"Закрепить / открепить раздел","de":"Bereich anheften / lösen"},{"key":"Reset home layout","ru":"Сбросить главную","de":"Startseite zurücksetzen"},{"key":"Show or hide home block","ru":"Показать / скрыть блок","de":"Startblock ein-/ausblenden"},{"key":"No favorites yet","ru":"Нет избранных разделов","de":"Noch keine Favoriten"},{"key":"Open in NEX Terminal Editor","ru":"Открыть в NEX Terminal Editor","de":"In NEX Terminal Editor öffnen"},{"key":"File search","ru":"Поиск файлов","de":"Dateisuche"},{"key":"Choose test","ru":"Выбрать тест","de":"Test auswählen"},{"key":"Peak memory usage","ru":"Пиковое использование ОЗУ","de":"Spitzenspeicherbelegung"},{"key":"Result","ru":"Результат","de":"Ergebnis"},{"key":"Folder sizes are logical and may count hard links twice.","ru":"Логический размер папок; жёсткие ссылки могут учитываться дважды.","de":"Logische Ordnergrößen; Hardlinks können doppelt zählen."},{"key":"Test worker stopped.","ru":"Тест остановлен.","de":"Test beendet."},{"key":"Press F6 to pin or unpin a section.","ru":"F6 — закрепить или открепить раздел.","de":"F6 heftet einen Bereich an oder löst ihn."},{"key":"Search root","ru":"Папка поиска","de":"Suchordner"},{"key":"No results","ru":"Нет результатов","de":"Keine Ergebnisse"},{"key":"Search time limit: 90 seconds; up to 100,000 items.","ru":"Лимит: 90 секунд и 100 000 объектов.","de":"Limit: 90 Sekunden und 100.000 Elemente."},{"key":"Choose section","ru":"Выбрать раздел","de":"Bereich wählen"},{"key":"Test score is not a hardware rating.","ru":"Результат не является рейтингом оборудования.","de":"Kein Hardware-Rating."},{"key":"GPU sensors unavailable","ru":"Датчики GPU недоступны","de":"GPU-Sensoren nicht verfügbar"},{"key":"CPU: single-thread SHA-256 throughput.","ru":"CPU: скорость SHA-256 в одном потоке.","de":"CPU: SHA-256-Durchsatz auf einem Thread."},{"key":"RAM: 16 MiB buffer copy and checksum, not full-memory coverage.","ru":"ОЗУ: копирование буфера 16 MiB и контрольная сумма; не вся память.","de":"RAM: 16 MiB kopieren und Prüfsumme, kein vollständiger Speichertest."},{"key":"Ctrl+K: search | F6: favorite | F1: help","ru":"Ctrl+K: поиск | F6: избранное | F1: помощь","de":"Ctrl+K: Suche | F6: Favorit | F1: Hilfe"},{"key":"Install Dashboard first.","ru":"Сначала установите Dashboard.","de":"Dashboard zuerst installieren."},{"key":"Enter to close","ru":"Enter — закрыть","de":"Enter zum Schließen"},{"key":"Folder is unavailable or is a link.","ru":"Папка недоступна или является ссылкой.","de":"Ordner nicht verfügbar oder ein Link."},{"key":"Only local fixed drives are supported.","ru":"Поддерживаются только локальные диски.","de":"Nur lokale Festlaufwerke werden unterstützt."},{"key":"Could not open registry key.","ru":"Не удалось открыть ключ реестра.","de":"Registrierungsschlüssel konnte nicht geöffnet werden."},{"key":"GPU counter unavailable","ru":"Счётчик GPU недоступен","de":"GPU-Zähler nicht verfügbar"},{"key":"CPU multi-thread test","ru":"Многопоточный тест CPU","de":"CPU-Mehrkerntest"},{"key":"RAM bandwidth test","ru":"Тест пропускной способности ОЗУ","de":"RAM-Bandbreitentest"},{"key":"GPU compute test","ru":"Вычислительный тест GPU","de":"GPU-Rechentest"},{"key":"GPU: Direct3D 11 hardware compute and sampled readback.","ru":"GPU: вычисления Direct3D 11 и выборочная проверка результата.","de":"GPU: Direct3D-11-Berechnung mit stichprobenartiger Prüfung."},{"key":"RAM: parallel copies, up to 4 GiB of available memory.","ru":"ОЗУ: параллельное копирование, до 4 ГиБ доступной памяти.","de":"RAM: parallele Kopien, bis zu 4 GiB verfügbarer Speicher."},{"key":"CPU: parallel SHA-256 workload on logical processors.","ru":"CPU: параллельные вычисления SHA-256 на логических процессорах.","de":"CPU: parallele SHA-256-Berechnung auf logischen Prozessoren."},{"key":"Preparing test","ru":"Подготовка теста","de":"Test wird vorbereitet"},{"key":"Graphics adapter","ru":"Графический адаптер","de":"Grafikadapter"},{"key":"Peak dispatch rate","ru":"Пик вычислений","de":"Spitzenrate (Dispatches)"},{"key":"Average dispatch rate","ru":"Средняя частота вычислений","de":"Mittlere Dispatch-Rate"},{"key":"Completed workloads","ru":"Выполнено вычислений","de":"Abgeschlossene Durchläufe"},{"key":"Worker threads","ru":"Рабочие потоки","de":"Arbeitsthreads"},{"key":"Test memory allocated","ru":"Память теста","de":"Belegter Testspeicher"},{"key":"GPU temperature limit reached.","ru":"Достигнут предел температуры GPU.","de":"GPU-Temperaturgrenze erreicht."},{"key":"No workload completed.","ru":"Ни один цикл не завершён.","de":"Kein Durchlauf abgeschlossen."},{"key":"Use this folder","ru":"Выбрать эту папку","de":"Diesen Ordner wählen"},{"key":"Parent folder","ru":"На уровень выше","de":"Übergeordneter Ordner"},{"key":"Choose a folder or type its full path.","ru":"Выберите папку мышью или введите полный путь.","de":"Ordner anklicken oder vollständigen Pfad eingeben."},{"key":"Type a value. Esc cancels.","ru":"Введите значение. Esc — отмена.","de":"Wert eingeben. Esc bricht ab."},{"key":"Dragging","ru":"Перетаскивание","de":"Ziehen"},{"key":"Release to move; Esc cancels.","ru":"Отпустите для обмена; Esc — отмена.","de":"Zum Tauschen loslassen; Esc bricht ab."},{"key":"Windows .NET Framework C# compiler not found.","ru":"Не найден компилятор C# из .NET Framework.","de":"C#-Compiler von .NET Framework nicht gefunden."},{"key":"Invalid folder.","ru":"Недопустимая папка.","de":"Ungültiger Ordner."},{"key":"Current name","ru":"Текущее имя","de":"Aktueller Name"},{"key":"New name preview","ru":"Новое имя","de":"Neuer Name"},{"key":"Rename help","ru":"Введите новое имя. Расширение сохраняется автоматически. Ctrl+A выделяет имя.","de":"Neuen Namen eingeben. Die Dateiendung bleibt erhalten. Strg+A markiert den Namen."},{"key":"Invalid file name.","ru":"Недопустимое имя файла.","de":"Ungültiger Dateiname."},{"key":"Name already exists.","ru":"Имя уже существует.","de":"Name bereits vorhanden."},{"key":"Windows Open with","ru":"«Открыть с помощью»","de":"„Öffnen mit“"},{"key":"Editor association help","ru":"Добавляет редактор NEX в список «Открыть с помощью» Windows. Приложения по умолчанию не меняются.","de":"Fügt den NEX-Editor zur Windows-Liste „Öffnen mit“ hinzu. Standardprogramme bleiben unverändert."},{"key":"Choose memory amount","ru":"Объём тестируемой памяти","de":"Test-Speichermenge wählen"},{"key":"Maximum safe available","ru":"Максимум свободной с резервом","de":"Sicheres verfügbares Maximum"},{"key":"Custom GiB","ru":"Свой объём (ГиБ)","de":"Eigene Menge (GiB)"},{"key":"Enter memory amount in GiB","ru":"Введите объём в ГиБ","de":"Speichermenge in GiB eingeben"},{"key":"Invalid memory amount.","ru":"Недопустимый объём памяти.","de":"Ungültige Speichermenge."},{"key":"Requested memory","ru":"Запрошенный объём","de":"Angeforderter Speicher"},{"key":"GPU: compute and sampled VRAM readback within the DXGI budget.","ru":"GPU: вычисления и выборочная проверка VRAM в пределах бюджета DXGI.","de":"GPU: Berechnung und VRAM-Stichproben innerhalb des DXGI-Budgets."},{"key":"RAM: parallel copies; Windows memory reserve is always kept.","ru":"ОЗУ: параллельное копирование; резерв для Windows сохраняется.","de":"RAM: parallele Kopien; Windows-Speicherreserve bleibt erhalten."},{"key":"Test VRAM allocated","ru":"Выделено VRAM для теста","de":"VRAM für Test belegt"},{"key":"Peak VRAM usage","ru":"Пиковое использование VRAM","de":"Maximale VRAM-Nutzung"},{"key":"Total VRAM","ru":"Всего VRAM","de":"VRAM insgesamt"},{"key":"Resource module","ru":"Модуль CPU / RAM","de":"Ressourcenmodul"},{"key":"Alerts module","ru":"Модуль уведомлений","de":"Benachrichtigungsmodul"},{"key":"Disk module","ru":"Модуль накопителя","de":"Laufwerksmodul"},{"key":"Shows cached CPU and RAM usage in the header.","ru":"Показывает последние показатели CPU и RAM в шапке.","de":"Zeigt zuletzt gemessene CPU- und RAM-Auslastung im Kopfbereich."},{"key":"Shows the number of current notifications.","ru":"Показывает число текущих уведомлений.","de":"Zeigt die Anzahl aktueller Benachrichtigungen."},{"key":"Shows free space on the Windows drive.","ru":"Показывает свободное место на диске Windows.","de":"Zeigt freien Speicher auf dem Windows-Laufwerk."},{"key":"The workload stopped before the selected duration.","ru":"Тест остановился до окончания выбранного времени.","de":"Der Test endete vor Ablauf der gewählten Dauer."},{"key":"Memory reserve reached before allocation","ru":"Достигнут резерв памяти до выделения.","de":"Speicherreserve vor Zuweisung erreicht."},{"key":"Notifications","ru":"Уведомления","de":"Benachrichtigungen"},{"key":"Find in file","ru":"Поиск в файле","de":"In Datei suchen"},{"key":"No matches","ru":"Нет совпадений","de":"Keine Treffer"},{"key":"Type to search","ru":"Введите текст","de":"Suchtext eingeben"},{"key":"Terminal zoom","ru":"Масштаб терминала","de":"Terminal-Zoom"},{"key":"Line","ru":"Строка","de":"Zeile"},{"key":"Col","ru":"Столбец","de":"Spalte"},{"key":"Search","ru":"Поиск","de":"Suchen"},{"key":"Terminal zoom: Ctrl+ +/− | Ctrl+0: reset","ru":"Масштаб терминала: Ctrl+ +/− | Ctrl+0: сброс","de":"Terminalzoom: Strg+ +/− | Strg+0: Reset"},{"key":"Up/Down or Enter/F3: matches | Esc: close search","ru":"↑/↓ или Enter/F3: совпадения | Esc: закрыть поиск","de":"↑/↓ oder Enter/F3: Treffer | Esc: Suche schließen"},{"key":"Ctrl+A: select all","ru":"Ctrl+A: выделить всё","de":"Strg+A: alles auswählen"},{"key":"Select all text","ru":"Выделить всё","de":"Alles markieren"},{"key":"Undo","ru":"Отмена действия","de":"Rückgängig"},{"key":"Delete selection","ru":"Удалить выделение","de":"Auswahl löschen"},{"key":"Click: cursor | Drag: select | Ctrl++ / Ctrl+-: zoom","ru":"Клик: курсор | Протянуть мышью: выделить | Ctrl++ / Ctrl+-: масштаб","de":"Klick: Cursor | Ziehen: markieren | Strg++ / Strg+-: Zoom"},{"key":"Click/drag: select | Ctrl++ / Ctrl+-: zoom","ru":"Мышь: выделение | Ctrl++ / Ctrl+-: масштаб","de":"Maus: Auswahl | Strg++ / Strg+-: Zoom"},{"key":"Selection","ru":"Выделение","de":"Auswahl"},{"key":"Nothing to undo.","ru":"Нет действий для отмены.","de":"Nichts rückgängig zu machen."},{"key":"Undone.","ru":"Действие отменено.","de":"Rückgängig gemacht."},{"key":"Select text first.","ru":"Сначала выделите текст.","de":"Zuerst Text markieren."},{"key":"Selection cut.","ru":"Выделенный текст вырезан.","de":"Auswahl ausgeschnitten."},{"key":"Selection copied.","ru":"Выделенный текст скопирован.","de":"Auswahl kopiert."},{"key":"Clipboard unavailable.","ru":"Буфер обмена недоступен.","de":"Zwischenablage nicht verfügbar."},{"key":"Editor zoom","ru":"Масштаб","de":"Zoom"},{"key":"Reset zoom","ru":"Сброс","de":"Reset"},{"key":"Zoom reset requested.","ru":"Запрошен сброс масштаба (Ctrl+0).","de":"Zoom-Reset angefordert (Strg+0)."},{"key":"Zoom reset unavailable.","ru":"Сброс не выполнен. Ctrl+0 — вручную.","de":"Zurücksetzen fehlgeschlagen. Manuell: Strg+0."},{"key":"Open file in tab","ru":"Открыть файл во вкладке","de":"Datei im Tab öffnen"},{"key":"Open tabs","ru":"Открытые вкладки","de":"Offene Tabs"},{"key":"Tab limit: 12 files.","ru":"Не более 12 открытых файлов.","de":"Maximal 12 offene Dateien."},{"key":"Close tab","ru":"Закрыть вкладку","de":"Tab schließen"},{"key":"Enter path","ru":"Ввести путь","de":"Pfad eingeben"},{"key":"Parent folders","ru":"Родительские папки","de":"Übergeordnete Ordner"},{"key":"Tab file path or file name","ru":"Путь или имя файла","de":"Dateipfad oder Dateiname"},{"key":"Choose a text file or enter its path.","ru":"Выберите текстовый файл или введите путь.","de":"Textdatei auswählen oder Pfad eingeben."},{"key":"Auto pairs and indent","ru":"Автоскобки и отступы","de":"Auto-Klammern und Einzug"},{"key":"Tab: complete","ru":"Tab: дополнить","de":"Tab: vervollständigen"},{"key":"Redo","ru":"Повторить действие","de":"Wiederholen"},{"key":"Nothing to redo.","ru":"Нечего повторять.","de":"Nichts zu wiederholen."},{"key":"Redone.","ru":"Действие восстановлено.","de":"Aktion wiederholt."},{"key":"Editor tabs, syntax highlighting, search, mouse selection, clipboard, undo/redo, inline completion, auto-pairs and bracket matching.","ru":"Вкладки редактора, подсветка синтаксиса, поиск, выделение мышью, буфер обмена, отмена и повтор, автодополнение и парные скобки.","de":"Editor-Tabs, Syntaxhervorhebung, Suche, Mausauswahl, Zwischenablage, Rückgängig/Wiederholen, Vervollständigung und Klammerpaare."},{"key":"Clickable path breadcrumbs, rename preview with preserved extension, optional NEX Terminal Editor registration in Windows.","ru":"Кликабельный путь, предпросмотр переименования с сохранением расширения, опциональная регистрация NEX Terminal Editor в Windows.","de":"Anklickbare Pfadnavigation, Umbenennungsvorschau mit Dateiendung und optionale Windows-Registrierung des NEX Terminal Editor."},{"key":"Large file and folder search; CPU, RAM and GPU benchmarks with memory budgets, cancellation and reports.","ru":"Поиск крупных файлов и папок; бенчмарки CPU, RAM и GPU с выбором объёма памяти, отменой и отчётами.","de":"Suche nach großen Dateien und Ordnern; CPU-, RAM- und GPU-Benchmarks mit Speicherbudget, Abbruch und Berichten."},{"key":"Theme-based light mode, favorites, adaptive sidebar, compact layout, drag-and-drop monitor cards and extra status widgets.","ru":"Светлый режим на основе темы, избранное, адаптивное меню, компактный режим, перетаскивание карточек и новые виджеты.","de":"Designbasierter Hellmodus, Favoriten, adaptive Seitenleiste, Kompaktmodus, verschiebbare Monitorkarten und weitere Status-Widgets."},{"key":"Read-only full PC scan, preference reset with backup, F8 privilege switching and animated update indicators.","ru":"Полное сканирование ПК без ремонта, сброс настроек с резервной копией, переключение прав F8 и анимация обновлений.","de":"Schreibgeschützte PC-Diagnose, Einstellungsreset mit Sicherung, F8-Berechtigungswechsel und animierte Update-Anzeigen."},{"key":"Adaptive sidebar and startup layouts, per-process CPU/RAM/GPU metrics, persistent Ookla consent and separate restart indicators.","ru":"Адаптивное меню и стартовые карточки, CPU/RAM/GPU по процессам, сохранение согласия Ookla и раздельные индикаторы перезапуска.","de":"Adaptive Seitenleiste und Startlayouts, CPU/RAM/GPU je Prozess, gespeicherte Ookla-Zustimmung und getrennte Neustartanzeigen."}]
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
    $d=@{MonitorOrder=($cards -join ',');MonitorHidden='';MonitorColumns='Auto';LoadingStyle='Progress';AnimationSpeed='Normal';SettingHelp=$true;SidebarSeparators=$true;LightMode=$false;ModuleBattery=$false;ModuleSession=$false;ModuleShortcuts=$false;ModuleResources=$false;ModuleAlerts=$false;ModuleDisk=$false;Favorites='';OverviewHidden='';CompactMode='Auto'}
    $order=@(([string]$o.MonitorOrder -split ',') | Where-Object {$_ -cin $cards} | Select-Object -Unique)
    if ($order.Count -eq $cards.Count) {$d.MonitorOrder=$order -join ','}
    $hidden=@(([string]$o.MonitorHidden -split ',') | Where-Object {$_ -cin $cards} | Select-Object -Unique)
    if ($hidden.Count -lt $cards.Count) {$d.MonitorHidden=$hidden -join ','}
    foreach ($k in @('MonitorColumns','LoadingStyle','AnimationSpeed')) {
        $allowed=@{MonitorColumns=@('Auto','Single column','Two columns');LoadingStyle=@('Progress','Pulse','Wave','Dots','Minimal');AnimationSpeed=@('Fast','Normal','Slow')}[$k]
        if ($o.$k -is [string] -and $o.$k -cin $allowed) {$d[$k]=$o.$k}
    }
    foreach ($k in @('SettingHelp','SidebarSeparators','LightMode','ModuleBattery','ModuleSession','ModuleShortcuts','ModuleResources','ModuleAlerts','ModuleDisk')) {if ($o.$k -is [bool]) {$d[$k]=$o.$k}}
    $validFavorites=@(1..22 | ForEach-Object {[string]$_})
    $d.Favorites=(@(([string]$o.Favorites -split ',') | Where-Object {$_ -cin $validFavorites} | Select-Object -Unique) -join ',')
    $d.OverviewHidden=(@(([string]$o.OverviewHidden -split ',') | Where-Object {$_ -cin @('Identity','Metrics','Actions','Favorites')} | Select-Object -Unique) -join ',')
    if ($o.CompactMode -cin @('Auto','Compact')) {$d.CompactMode=[string]$o.CompactMode}
    return $d
}
function global:Get-NexPreferences {
    param([switch]$DefaultsOnly)
    $defaults=@{MonitorOrder='Processor,Graphics,Memory,Storage,Network,System';MonitorHidden='';MonitorColumns='Auto';LoadingStyle='Progress';AnimationSpeed='Normal';SettingHelp=$true;SidebarSeparators=$true;LightMode=$false;ModuleBattery=$false;ModuleSession=$false;ModuleShortcuts=$false;ModuleResources=$false;ModuleAlerts=$false;ModuleDisk=$false;Favorites='';OverviewHidden='';CompactMode='Auto';Language='en';Name='';ShowComputerName=$true;ComputerAlias='';Theme='Pink';Accent='F5C2E7';Startup=$true;ClearOnReturn=$true;LoadingOnReturn=$false;Fetch=$true;FetchAnimation=$true;FetchPreset='Cards';CustomLogo='';Prompt='Rounded';Icons=$true;Prediction='History';Access='Unknown';ReleaseRepo='owoNEXowo/NEX-Dashboard'}
    $p=Join-Path $env:LOCALAPPDATA 'NexDashboard\preferences.json'
    if (-not $DefaultsOnly -and (Test-Path -LiteralPath $p)) {try {
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
    if ($defaults.LightMode -isnot [bool]) {$defaults.LightMode=$false}
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
    $p=$colors[$theme]
    if ($global:NexPublicSettings.LightMode) {
        $p=@((Get-NexLightInk $p[0]),(Get-NexLightInk $p[1]),(Get-NexLightCanvas $p[0] 82),(Get-NexLightCanvas $p[0] 54),(Mix-NexColor $p[0] '252332' 0.95),(Mix-NexColor $p[1] '353647' 0.94))
    }
    return ,$p
}
function global:Get-NexLightCanvas([string]$hex,[double]$spread=54.0) {
    $channels=@([Convert]::ToInt32($hex.Substring(0,2),16),[Convert]::ToInt32($hex.Substring(2,2),16),[Convert]::ToInt32($hex.Substring(4,2),16))
    $hi=[double](($channels | Measure-Object -Maximum).Maximum)
    $lo=[double](($channels | Measure-Object -Minimum).Minimum)
    $delta=$hi-$lo
    if ($delta -lt 12) {return 'F0F0F2'}
    $rgb=foreach ($channel in $channels) {[int][Math]::Round(255.0-$spread+($channel-$lo)*$spread/$delta)}
    return ('{0:X2}{1:X2}{2:X2}' -f $rgb[0],$rgb[1],$rgb[2])
}
function global:Get-NexLightInk([string]$hex) {
    # Preserve the input hue; use a deeper, more saturated ink on a light canvas.
    $channels=@([Convert]::ToInt32($hex.Substring(0,2),16),[Convert]::ToInt32($hex.Substring(2,2),16),[Convert]::ToInt32($hex.Substring(4,2),16))
    $hi=[double](($channels | Measure-Object -Maximum).Maximum)
    $lo=[double](($channels | Measure-Object -Minimum).Minimum)
    $delta=$hi-$lo
    if ($delta -lt 12) {return '53515E'}
    $spread=[Math]::Min(124.0,54.0+$delta*0.52)
    $rgb=@(foreach ($channel in $channels) {[int][Math]::Round(33.0+($channel-$lo)*$spread/$delta)})
    # Bright yellow/green/cyan need a lower luminance than magenta or blue.
    for ($i=0;$i -lt 16;$i++) {
        $linear=@(foreach ($channel in $rgb) {
            $c=$channel/255.0
            if ($c -le 0.04045) {$c/12.92} else {[Math]::Pow(($c+0.055)/1.055,2.4)}
        })
        if ((0.2126*$linear[0]+0.7152*$linear[1]+0.0722*$linear[2]) -le 0.10) {break}
        $rgb=@(foreach ($channel in $rgb) {[int][Math]::Round($channel*0.92)})
    }
    return ('{0:X2}{1:X2}{2:X2}' -f $rgb[0],$rgb[1],$rgb[2])
}
function global:NexAnsi([string]$hex,[switch]$Background) {
    $hex=$hex.TrimStart('#');$kind=if ($Background) {48} else {38}
    if (-not $Background -and $global:NexPublicSettings.LightMode) {
        $r=[Convert]::ToInt32($hex.Substring(0,2),16);$g=[Convert]::ToInt32($hex.Substring(2,2),16);$b=[Convert]::ToInt32($hex.Substring(4,2),16)
        $l=0.2126*$r+0.7152*$g+0.0722*$b
        if ($l -gt 120) {$hex=Get-NexLightInk $hex}
    }
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
    Write-Host ('{0} / DASHBOARD 2.7.0' -f (Get-NexName)) -ForegroundColor Magenta
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
    if ($global:NexPublicSettings.LightMode) {
        return [pscustomobject]@{name='NEX Shared';background=('#'+$p[3]);foreground=('#'+$p[4]);cursorColor=('#'+$p[0]);selectionBackground=('#'+$p[2]);black='#242733';red='#A12348';green='#17663B';yellow='#835400';blue='#225AA0';purple=('#'+$p[1]);cyan='#08676A';white='#434957';brightBlack='#626779';brightRed='#AF2649';brightGreen='#14733E';brightYellow='#825100';brightBlue='#245DA5';brightPurple=('#'+$p[0]);brightCyan='#08747B';brightWhite=('#'+$p[4])}
    }
    return [pscustomobject]@{name='NEX Shared';background=('#'+$p[3]);foreground=('#'+$p[4]);cursorColor=('#'+$p[0]);selectionBackground=('#'+$p[2]);black='#45475A';red='#F38BA8';green='#A6E3A1';yellow='#F9E2AF';blue='#89B4FA';purple=('#'+$p[1]);cyan='#94E2D5';white='#BAC2DE';brightBlack='#585B70';brightRed='#F38BA8';brightGreen='#A6E3A1';brightYellow='#F9E2AF';brightBlue='#89B4FA';brightPurple=('#'+$p[0]);brightCyan='#94E2D5';brightWhite=('#'+$p[4])}
}
function global:Get-NexWindowTheme($scheme) {
    $canvas=([string]$scheme.background).TrimStart('#')
    $ink=([string]$scheme.foreground).TrimStart('#')
    if ($canvas -notmatch '^[0-9A-Fa-f]{6}$' -or $ink -notmatch '^[0-9A-Fa-f]{6}$') {throw 'Invalid NEX window palette.'}
    $r=[Convert]::ToInt32($canvas.Substring(0,2),16);$g=[Convert]::ToInt32($canvas.Substring(2,2),16);$b=[Convert]::ToInt32($canvas.Substring(4,2),16)
    $light=(0.2126*$r+0.7152*$g+0.0722*$b) -gt 150
    $row='#'+(Mix-NexColor $canvas $ink 0.10)
    $inactive='#'+(Mix-NexColor $canvas $ink 0.15)
    $tab='#'+(Mix-NexColor $canvas $ink 0.025)
    return [pscustomobject]@{
        name='NEX Window'
        window=[pscustomobject]@{applicationTheme=$(if ($light) {'light'} else {'dark'});useMica=$false}
        tabRow=[pscustomobject]@{background=$row;unfocusedBackground=$inactive}
        tab=[pscustomobject]@{background=$tab;unfocusedBackground=$row}
    }
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
    $windowTheme=$null
    if ($scheme -and $scheme.name -eq 'NEX Shared' -and $changes.colorScheme -eq 'NEX Shared') {$windowTheme=Get-NexWindowTheme $scheme}
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
        if ($windowTheme) {
            $themes=@($obj.themes | Where-Object {$_ -and $_.name -ine $windowTheme.name})
            $themes+= $windowTheme
            Set-NexObjectMember $obj 'themes' $themes
            Set-NexObjectMember $obj 'theme' $windowTheme.name
        }
        $profiles=@($obj.profiles.defaults)+@($obj.profiles.list | Where-Object {$_})
        foreach ($pr in $profiles) {
            if ($pr -isnot [pscustomobject]) {throw "Invalid profile object: $path"}
            # Per-profile tabColor overrides the managed native window theme.
            if ($windowTheme -and $pr.PSObject.Properties['tabColor']) {$pr.PSObject.Properties.Remove('tabColor')}
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
        if ($windowTheme -and ($check.theme -ne $windowTheme.name -or @($check.themes | Where-Object name -eq $windowTheme.name).Count -ne 1)) {throw 'Window theme verification failed.'}
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
    $count=Sync-NexTerminalAppearance $changes (Get-NexSharedScheme)
    if ($env:WT_SESSION -and $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected) {
        # Release runtime color overrides so the native profile owns the background and opacity.
        $e=[char]27;$bell=[char]7
        Write-Host "$e]110$bell$e]111$bell$e[0m" -NoNewline
    }
    return $count
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
    $weight=[Math]::Max(0.0,[Math]::Min(1.0,$weight))
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
# Explicit acceptance is user-local, separate from portable appearance backups.
function global:Get-NexOoklaConsentPath {
    Join-Path $env:LOCALAPPDATA 'NexDashboard\ookla-consent.json'
}
function global:Test-NexOoklaConsent([string]$Hash) {
    if ($Hash -notmatch '^[0-9A-Fa-f]{64}$') {return $false}
    try {
        $file=Get-NexOoklaConsentPath
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {return $false}
        if ((Get-Item -LiteralPath $file -ErrorAction Stop).Length -gt 16384) {return $false}
        $data=[IO.File]::ReadAllText($file) | ConvertFrom-Json -ErrorAction Stop
        return ($data.Schema -eq 1 -and $data.TermsRevision -ceq 'ookla-personal-use-v1' -and $data.ExecutableSHA256 -ieq $Hash -and $data.TermsAccepted -is [bool] -and $data.TermsAccepted -and $data.PrivacyAccepted -is [bool] -and $data.PrivacyAccepted)
    } catch {return $false}
}
function global:Save-NexOoklaConsent([string]$Hash) {
    if ($Hash -notmatch '^[0-9A-Fa-f]{64}$') {throw 'Invalid Ookla executable hash.'}
    $file=Get-NexOoklaConsentPath
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force -ErrorAction Stop
    $tmp=$file+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try {
        $data=@{Schema=1;TermsRevision='ookla-personal-use-v1';ExecutableSHA256=$Hash;TermsAccepted=$true;PrivacyAccepted=$true;AcceptedAtUtc=[datetime]::UtcNow.ToString('o')}
        [IO.File]::WriteAllText($tmp,($data | ConvertTo-Json -Compress),(New-Object System.Text.UTF8Encoding($true)))
        if (Test-Path -LiteralPath $file) {[IO.File]::Replace($tmp,$file,[System.Management.Automation.Language.NullString]::Value)} else {[IO.File]::Move($tmp,$file)}
    } finally {if (Test-Path -LiteralPath $tmp) {Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}}
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
    $returnDefaults=@{ClearOnReturn=$true;LoadingOnReturn=$false;ShowComputerName=$true;LightMode=$false}
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
            :clip foreach ($token in [regex]::Split($line,'(\x1b\[[0-9;]*m)')) {
                if ($token -match '^\x1b\[') {$null=$result.Append($token);continue}
                $it=[Globalization.StringInfo]::GetTextElementEnumerator($token)
                while ($it.MoveNext()) {
                    $part=$it.GetTextElement();$cells=Get-NexLogoWidth $part
                    if ($used+$cells -gt $limit) {break clip}
                    $null=$result.Append($part);$used+=$cells
                }
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
    param([string[]]$PromptLines,[switch]$Refresh)
    $c=$global:NexPublicSettings
    if ($c.FetchPreset -like 'Fastfetch*' -or $c.Prompt -eq 'Keep existing' -or $Host.Name -ne 'ConsoleHost' -or [Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        if (-not $Refresh) {Show-NexPublicFetch}
        return
    }
    try {
        $w=[Console]::WindowWidth;$h=[Console]::WindowHeight
        if (-not $Refresh -and ([Console]::CursorLeft -ne 0 -or [Console]::CursorTop -ne [Console]::WindowTop)) {Show-NexPublicFetch;return}
        if ($w -lt 12 -or $h -lt 5) {if (-not $Refresh) {Show-NexPublicFetch};return}
        if (-not $global:NexRefreshSnapshot) {$global:NexRefreshSnapshot=@{}}
        $preview=@(for ($j=0;$j -lt $PromptLines.Count;$j++) {
            $line=$PromptLines[$j]
            if ((Get-NexLogoWidth ($line -replace '\x1b\[[0-9;]*m','')) -ge $w) {
                if ($j -eq $PromptLines.Count-1) {'PS > '}
            } else {$line}
        })
        if (-not $preview.Count) {$preview=@('PS > ')}
        $gap=if ($preview.Count -gt 1) {1} else {0}
        $room=[Math]::Max(0,$h-$preview.Count-$gap-2)
        $fetch=@(Show-NexPublicFetch -Width $w -AsLines -NoAnimation -Snapshot $global:NexRefreshSnapshot)
        if ($fetch.Count -gt $room) {$fetch=@(Show-NexPublicFetch -Width $w -AsLines -NoAnimation -Snapshot $global:NexRefreshSnapshot -CompactLayout)}
        if ($fetch.Count -gt $room) {$fetch=@($fetch | Select-Object -First $room)}
        $frame=@($fetch)
        if ($gap) {$frame+=@('')}
        if ($preview.Count -gt 1) {$frame+=@($preview | Select-Object -First ($preview.Count-1))}
        $e=[char]27;$z="$e[0m";$size="$($w)x$($h)"
        if (-not $Refresh -and $c.FetchAnimation) {
            $delay=@{Fast=7;Normal=18;Slow=40}[[string]$c.AnimationSpeed]
            try {
                Write-Host "$e[?25l" -NoNewline
                for ($i=0;$i -lt $frame.Count;$i++) {
                    if ("$([Console]::WindowWidth)x$([Console]::WindowHeight)" -ne $size) {break}
                    Write-Host "$e[$($i+1);1H$($frame[$i])$z$e[K" -NoNewline
                    if ($delay) {Start-Sleep -Milliseconds $delay}
                }
            } finally {Write-Host "$e[?25h" -NoNewline}
        }
        # Paint positioned rows, then leave the cursor where the real editor expects its prompt.
        # Do not switch screen buffers or clear the scrollback.
        $paint=New-Object System.Text.StringBuilder
        for ($i=0;$i -lt $frame.Count;$i++) {
            $null=$paint.Append("$e[$($i+1);1H$($frame[$i])$z$e[K")
        }
        $null=$paint.Append("$e[$($frame.Count+1);1H$e[J")
        Write-Host $paint.ToString() -NoNewline
        $global:NexRefreshSize=$size
        return @{Prompt=$preview[-1]}
    } catch {
        if (-not $Refresh) {Show-NexPublicFetch -NoAnimation}
    }
}
function global:Update-NexFetchWhileEditing {
    if (-not $global:NexStartupRefresh -or -not $global:NexFetchEditorActive -or $global:NexRefreshBusy) {return}
    if ($global:NexPublicSettings.FetchPreset -like 'Fastfetch*') {return}
    $e=[char]27
    try {
        $global:NexRefreshBusy=$true
        $inputText='';$cursor=0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$inputText,[ref]$cursor)
        # Keep multiline and wrapped edits untouched. Only the original startup view is eligible.
        if ($inputText -match '[\r\n]') {return}
        $w=[Console]::WindowWidth;$h=[Console]::WindowHeight
        if ($w -lt 28 -or $h -lt 8) {return}
        if ((Get-NexLogoWidth $inputText) -gt [Math]::Max(1,$w-16)) {return}
        $top=[int][Console]::WindowTop
        $cy=[Console]::CursorTop
        if ($cy -lt $top -or $cy -ge $top+$h) {return}
        $global:NexRefreshRequested=$true
        # The editor performs its own redraw and keeps its command buffer and cursor.
        # Synchronized output (where supported) hides intermediate frames.
        Write-Host "$e[?2026h" -NoNewline
        try {[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt($null,$top)}
        finally {Write-Host "$e[?2026l$e[?25h" -NoNewline}
    } catch {} finally {$global:NexRefreshRequested=$false;$global:NexRefreshBusy=$false}
}
function global:Start-NexFirstPromptEditor {
    # Install only around the first real PSReadLine read. Do not replace custom editors.
    $reader=Get-Command PSConsoleHostReadLine -CommandType Function -ErrorAction SilentlyContinue
    if (-not $reader -or $reader.ModuleName -ne 'PSReadLine' -or -not $reader.ScriptBlock) {return}
    if ($global:NexFetchReaderOriginal) {return}
    $global:NexFetchReaderOriginal=$reader.ScriptBlock
    function global:PSConsoleHostReadLine {
        [System.Diagnostics.DebuggerHidden()]
        param()
        $original=$global:NexFetchReaderOriginal
        $timer=$null;$eventJob=$null;$source='NEX.Fetch.Resize.'+[guid]::NewGuid().ToString('N')
        try {
            if ($global:NexStartupRefresh) {
                try {
                    $timer=New-Object System.Timers.Timer 150
                    $timer.AutoReset=$false
                    $global:NexFetchEditorActive=$true
                    $global:NexFetchTimer=$timer
                    $eventJob=Register-ObjectEvent -InputObject $timer -EventName Elapsed -SourceIdentifier $source -ErrorAction Stop -Action {
                        try {
                            if ($global:NexFetchEditorActive -and $global:NexStartupRefresh) {
                                $size="$([Console]::WindowWidth)x$([Console]::WindowHeight)"
                                if ($size -ne $global:NexRefreshSize) {Update-NexFetchWhileEditing}
                            }
                        } catch {} finally {
                            if ($global:NexFetchEditorActive -and $global:NexFetchTimer) {
                                try {$global:NexFetchTimer.Start()} catch {}
                            }
                        }
                    }
                    $timer.Start()
                } catch {$global:NexFetchEditorActive=$false}
            }
            & $original
        } finally {
            # Stop event processing before any accepted command begins execution.
            $global:NexFetchEditorActive=$false;$global:NexStartupRefresh=$false
            $global:NexFetchTimer=$null
            if ($timer) {try {$timer.Stop();$timer.Dispose()} catch {}}
            Unregister-Event -SourceIdentifier $source -ErrorAction SilentlyContinue
            if ($eventJob) {Remove-Job -Job $eventJob -Force -ErrorAction SilentlyContinue}
            Remove-Event -SourceIdentifier $source -ErrorAction SilentlyContinue
            Set-Item -Path 'Function:\global:PSConsoleHostReadLine' -Value $original -Force
            $global:NexFetchReaderOriginal=$null
        }
    }
}
function global:Initialize-NexPublic {
    $argsList=[Environment]::GetCommandLineArgs()
    if ($Host.Name -ne 'ConsoleHost' -or [Console]::IsOutputRedirected -or [Console]::IsInputRedirected -or ($argsList -match '^[-/](NonInteractive|File)$') -or (($argsList -match '^[-/]Command$') -and -not ($argsList -match '^[-/]NoExit$'))) {return}
    if (-not $global:NexPublicInitialized) {$global:NexPublicInitialized=$true;$global:NexPublicPending=$true;$global:NexPublicOldPrompt=(Get-Command prompt -ErrorAction SilentlyContinue).ScriptBlock}
    try {if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {Set-PSReadLineOption -PredictionSource $global:NexPublicSettings.Prediction -ErrorAction Stop}} catch {}
    try {
        if (-not $global:NexFetchRefreshBound -and (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue)) {
            $existing=@(Get-PSReadLineKeyHandler -Bound | Where-Object Key -eq 'Ctrl+Alt+r')
            if (-not $existing.Count) {
                Set-PSReadLineKeyHandler -Chord 'Ctrl+Alt+r' -BriefDescription 'NexRefreshFetch' -LongDescription 'Refresh startup cards without changing the current command' -ScriptBlock {Update-NexFetchWhileEditing}
                $global:NexFetchRefreshBound=$true
            }
        }
    } catch {}
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
        $first=[bool]$global:NexPublicPending
        $refresh=[bool]$global:NexRefreshRequested
        if (-not $first -and -not $refresh) {$global:NexStartupRefresh=$false}
        if ($first) {
            $global:NexPublicPending=$false
            if ($c.Startup) {try {Show-NexLoadingScreen} catch {}}
        }
        if ($c.Prompt -eq 'Keep existing' -and $global:NexPublicOldPrompt) {
            if ($first -and $c.Fetch) {Show-NexPublicFetch}
            & $global:NexPublicOldPrompt;return
        }
        $path=(Get-Location).Path;$time=Get-Date -Format 'HH:mm:ss';$duration='';$last=Get-History -Count 1 -ErrorAction SilentlyContinue
        if ($last -and $last.CommandLine.Trim() -notmatch '^(?i:dashboard|monitor)(?:\s|$)') {$seconds=($last.EndExecutionTime-$last.StartExecutionTime).TotalSeconds;if ($seconds -ge 1) {$duration=' │ '+('{0:0.0}s' -f $seconds)}}
        if ($path -eq $HOME) {$path='~'} elseif ($path.StartsWith($HOME+'\',[StringComparison]::OrdinalIgnoreCase)) {$path='~'+$path.Substring($HOME.Length)}
        $useIcons=[bool]$c.Icons
        $lines=@(Get-NexPromptLines $c.Prompt (Get-NexIdentity) $path $time $ok $duration $useIcons)
        if ($refresh -and $c.Fetch) {
            $prepared=Show-NexResponsiveStartupFetch -PromptLines $lines -Refresh
            if ($null -ne $prepared) {return $prepared.Prompt}
        }
        if ($first -and $c.Fetch) {
            $global:NexRefreshSnapshot=@{}
            $prepared=Show-NexResponsiveStartupFetch -PromptLines $lines
            if ($null -ne $prepared) {
                $global:NexStartupRefresh=$true
                try {Start-NexFirstPromptEditor} catch {}
                return $prepared.Prompt
            }
        }
        if ($lines.Count -gt 1) {
            Write-Host ''
            for ($i=0;$i -lt $lines.Count-1;$i++) {Write-Host $lines[$i]}
        }
        return $lines[-1]
    }
}

function global:Test-NexAdministrator {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try {return ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
    finally {$identity.Dispose()}
}
function global:Get-NexPrivilegeGeometry {
    $options=''
    if (-not $env:WT_SESSION) {return $options}
    try {
        if (-not ('NexDash.WindowGeometry270' -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace NexDash {
    public static class WindowGeometry270 {
        [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, StringBuilder name, int max);
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
        [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr hwnd);
    }
}
"@ -ErrorAction Stop
        }
        $hwnd=[NexDash.WindowGeometry270]::GetForegroundWindow()
        $name=New-Object Text.StringBuilder 256
        $null=[NexDash.WindowGeometry270]::GetClassName($hwnd,$name,$name.Capacity)
        if ($name.ToString() -ne 'CASCADIA_HOSTING_WINDOW_CLASS') {return $options}
        if ([NexDash.WindowGeometry270]::IsZoomed($hwnd)) {return '--maximized '}
        $rect=New-Object NexDash.WindowGeometry270+RECT
        if ([NexDash.WindowGeometry270]::GetWindowRect($hwnd,[ref]$rect)) {
            $cols=[Math]::Max(20,[Math]::Min(999,[Console]::WindowWidth))
            $rows=[Math]::Max(10,[Math]::Min(999,[Console]::WindowHeight))
            $options="--pos $($rect.Left),$($rect.Top) --size $cols,$rows "
        }
    } catch {}
    return $options
}
function global:Get-NexHandoffPath([string]$Token,[ValidateSet('pending','ready')][string]$Kind) {
    if ($Token -cnotmatch '^[0-9a-f]{32}$') {throw 'Invalid handoff token.'}
    Join-Path (Join-Path $env:LOCALAPPDATA 'NexDashboard') ('handoff-'+$Token+'.'+$Kind)
}
function global:Complete-NexHandoff([string]$Token) {
    if (-not $Token) {return}
    try {
        $pending=Get-NexHandoffPath $Token pending
        $ready=Get-NexHandoffPath $Token ready
        if (-not (Test-Path -LiteralPath $pending -PathType Leaf)) {return}
        if (((Get-Date).ToUniversalTime()-(Get-Item -LiteralPath $pending).LastWriteTimeUtc).TotalSeconds -gt 120) {return}
        if ([IO.File]::ReadAllText($pending) -cne $Token) {return}
        $stream=[IO.File]::Open($ready,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
        try {
            $bytes=[Text.Encoding]::ASCII.GetBytes($Token)
            $stream.Write($bytes,0,$bytes.Length)
        } finally {$stream.Dispose()}
    } catch {}
}
function global:Open-NexPrivilegeWindow([bool]$Elevated,[ValidateRange(0,22)][int]$Page=0,[switch]$StartScan,[string]$HandoffToken='',[string]$Geometry='') {
    $terminal=Get-NexTerminalHost
    if (-not $terminal) {throw 'Windows Terminal settings not found. Run Initialize-NexAppearance first.'}
    $obj=ParseConfig ([IO.File]::ReadAllText($terminal.Settings))
    $id='{7e499cb9-0e64-4c22-9bb5-f4e4db932221}'
    $profiles=@($obj.profiles.list | Where-Object {$_})
    if (-not @($profiles | Where-Object guid -eq $id).Count) {
        $id='{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'
        if (-not @($profiles | Where-Object guid -eq $id).Count) {throw 'The NEX or Windows PowerShell Terminal profile was not found.'}
    }
    # Fixed command only; no command history, user input, or executable arguments are transferred.
    $expected=if ($Elevated) {'$true'} else {'$false'}
    $cmd='if ((Test-NexAdministrator) -eq '+$expected+') { dashboard -StartPage '+$Page
    if ($StartScan) {$cmd+=' -StartScan'}
    if ($HandoffToken -cnotmatch '^[0-9a-f]{32}$') {throw 'Invalid handoff token.'}
    $cmd+=' -HandoffToken '+$HandoffToken
    $cmd+=' } else { Write-Warning "Requested privilege level was not obtained. Close this window and launch the intended Terminal mode." }'
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    if ($Geometry -notmatch '^(|--maximized |--pos -?\d+,-?\d+ --size \d+,\d+ )$') {throw 'Invalid window geometry.'}
    $args=$Geometry+'-w new new-tab -p "'+$id+'" powershell.exe -NoLogo -NoExit -EncodedCommand '+$encoded
    if ($Elevated) {Start-Process -FilePath $terminal.Exe -ArgumentList $args -Verb RunAs -ErrorAction Stop}
    else {
        # Ask the existing interactive Explorer shell to launch a normal window.
        # Do not change UAC, duplicate tokens or store credentials.
        $shell=New-Object -ComObject Shell.Application
        try {
            $hwnd=0
            $desktop=$shell.Windows().FindWindowSW(0,0,8,[ref]$hwnd,1)
            if (-not $desktop -or -not $desktop.Document) {throw 'Normal desktop shell unavailable. Open Windows Terminal from Start.'}
            $desktop.Document.Application.ShellExecute($terminal.Exe,$args,'','open',1)
        } finally {if ($shell) {$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($shell)}}
    }
}
function global:Invoke-NexDiagnosticStep {
    param([string]$Step)
    $ErrorActionPreference='Stop'
    function Result([string]$state,[string]$detail,[string]$action='',[string[]]$data=@()) {
        [pscustomobject]@{State=$state;Detail=$detail;Action=$action;Data=$data}
    }
    function DecodeSfcOutput([byte[]]$bytes) {
        if (-not $bytes.Length) {return ''}
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) {return [Text.Encoding]::Unicode.GetString($bytes,2,$bytes.Length-2)}
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 254 -and $bytes[1] -eq 255) {return [Text.Encoding]::BigEndianUnicode.GetString($bytes,2,$bytes.Length-2)}
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {return [Text.Encoding]::UTF8.GetString($bytes,3,$bytes.Length-3)}
        # SFC commonly writes UTF-16LE even without a BOM. English progress lines and
        # Cyrillic high bytes (0x04) both provide evidence of wide-character output.
        $pairs=[Math]::Min(2048,[int][Math]::Floor($bytes.Length/2.0));$wide=0
        for ($i=0;$i -lt $pairs;$i++) {if ($bytes[2*$i+1] -in @(0,4)) {$wide++}}
        if ($pairs -gt 3 -and ($wide/[double]$pairs) -gt 0.65) {return [Text.Encoding]::Unicode.GetString($bytes)}
        try {return ([Text.UTF8Encoding]::new($false,$true)).GetString($bytes)} catch {}
        return [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage).GetString($bytes)
    }
    function DeviceCheck([string]$class) {
        $devices=@(Get-CimInstance -ClassName $class -OperationTimeoutSec 15)
        if (-not $devices.Count) {return (Result 'Unknown' 'No data returned.')}
        $bad=@($devices | Where-Object {($null -ne $_.ConfigManagerErrorCode -and $_.ConfigManagerErrorCode -ne 0) -or ($_.Status -and $_.Status -notin @('OK','Unknown'))})
        if ($bad.Count) {return (Result 'Warning' (($bad | ForEach-Object {"$($_.Name): $($_.Status) / $($_.ConfigManagerErrorCode)"}) -join '; ') 'Device Manager')}
        $known=@($devices | Where-Object {$_.Status -eq 'OK' -or ($null -ne $_.ConfigManagerErrorCode -and $_.ConfigManagerErrorCode -eq 0)})
        if ($known.Count -ne $devices.Count) {return (Result 'Unknown' 'Some device status is unavailable.' 'Device Manager')}
        return (Result 'OK' 'Windows reports normal device status.')
    }
    try {
        switch ($Step) {
            'GPU' {DeviceCheck 'Win32_VideoController'}
            'CPU' {DeviceCheck 'Win32_Processor'}
            'RAM' {
                $modules=@(Get-CimInstance Win32_PhysicalMemory -OperationTimeoutSec 15)
                if (-not $modules.Count) {Result 'Unknown' 'No data returned.';break}
                $bad=@($modules | Where-Object {$_.Status -and $_.Status -notin @('OK','Unknown')})
                if ($bad.Count) {Result 'Warning' 'Memory module status requires review.' 'Memory diagnostics';break}
                $event=$null
                try {$event=Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-MemoryDiagnostics-Results';Id=1201,1202,1101,1102} -MaxEvents 1 -ErrorAction Stop}
                catch {if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {Result 'Info' 'Memory test result could not be read.' 'Memory diagnostics';break}}
                if (-not $event) {Result 'Info' 'No completed Windows memory test found.' 'Memory diagnostics';break}
                $data=@($event.TimeCreated.ToString('yyyy-MM-dd HH:mm'),"Event ID: $($event.Id)")
                if ($event.Id -in @(1202,1102)) {Result 'Warning' 'Last Windows memory test reported errors.' 'Memory diagnostics' $data}
                else {Result 'OK' 'Last Windows memory test reported no errors.' 'Memory diagnostics' $data}
            }
            'Storage' {
                $disks=@(Get-PhysicalDisk -ErrorAction Stop)
                if (-not $disks.Count) {Result 'Unknown' 'No data returned.';break}
                $bad=@($disks | Where-Object {$_.HealthStatus -notin @('Healthy','Unknown') -or ($_.OperationalStatus -and $_.OperationalStatus -notcontains 'OK')})
                if ($bad.Count) {Result 'Warning' (($bad | ForEach-Object {"$($_.FriendlyName): $($_.HealthStatus) / $($_.OperationalStatus -join ', ')"}) -join '; ') 'Disk health';break}
                if (@($disks | Where-Object HealthStatus -ne 'Healthy').Count) {Result 'Unknown' 'Some drive health is unavailable.' 'Disk health';break}
                Result 'OK' 'Reported drive health is normal.'
            }
            'Drivers' {
                $devices=@(Get-CimInstance Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0' -OperationTimeoutSec 20)
                if ($devices.Count) {Result 'Warning' (($devices | Select-Object -First 4 | ForEach-Object {"$($_.Name): code $($_.ConfigManagerErrorCode)"}) -join '; ') 'Device Manager'}
                else {Result 'OK' 'No PnP problem codes reported.'}
            }
            'Network' {
                $up=@(Get-NetIPConfiguration -ErrorAction Stop | Where-Object {$_.IPv4DefaultGateway -or $_.IPv6DefaultGateway})
                if ($up.Count) {Result 'OK' 'A local default gateway is configured.'}
                else {Result 'Info' 'No default gateway detected.' 'Network settings'}
            }
            'Windows Security' {
                $d=Get-MpComputerStatus -ErrorAction Stop
                if ($null -eq $d.RealTimeProtectionEnabled) {Result 'Unknown' 'Defender status unavailable.' 'Windows Security'}
                elseif (-not $d.RealTimeProtectionEnabled) {Result 'Warning' 'Defender real-time protection is off; another antivirus may be active.' 'Windows Security'}
                else {Result 'OK' 'Defender real-time protection is on.'}
            }
            'System logs' {
                $events=@()
                try {$events=@(Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2;StartTime=(Get-Date).AddDays(-1)} -MaxEvents 20 -ErrorAction Stop)}
                catch {if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {throw}}
                if ($events.Count) {
                    $data=@("24 h: $($events.Count)"+$(if ($events.Count -ge 20) {'+'} else {''}))
                    $data+=@(foreach ($ev in ($events | Select-Object -First 8)) {
                        ''
                        "$($ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) | $($ev.ProviderName) | ID $($ev.Id)"
                        $message=''
                        try {$message=[string]$ev.Message} catch {}
                        if ([string]::IsNullOrWhiteSpace($message)) {try {$message=[string]$ev.FormatDescription()} catch {}}
                        if ($message) {
                            if ($message.Length -gt 3000) {$message=$message.Substring(0,3000)+'…'}
                            foreach ($line in ($message -split '[\r\n]+')) {if ($line.Trim()) {$line.Trim()}}
                        } else {'Windows did not provide an event description.'}
                        if ($ev.ProviderName -eq 'Service Control Manager' -and $ev.Id -eq 7023) {'Check the service name and error in the description.'}
                        elseif ($ev.ProviderName -eq 'Microsoft-Windows-Windows Firewall With Advanced Security' -and $ev.Id -eq 2042) {'Check firewall status in Windows Security; do not disable protection.'}
                        elseif ($ev.ProviderName -eq 'Microsoft-Windows-Kernel-Boot' -and $ev.Id -eq 124) {'Review the boot security policy and status in the description.'}
                    })
                    Result 'History' 'Past system events; not proof of an active fault. Review the event IDs and timestamps.' 'Event Viewer' $data
                }
                else {Result 'OK' 'No critical/error system events in the last 24 hours.'}
            }
            'Windows Update' {
                $info=New-Object -ComObject Microsoft.Update.SystemInfo
                try {if ($info.RebootRequired) {Result 'Warning' 'Windows Update reports that a restart is required.' 'Restart'} else {Result 'OK' 'Windows Update does not require a restart.'}}
                finally {if ($info) {$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($info)}}
            }
            'System files (SFC)' {
                $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {Result 'Skipped' 'Administrator rights are needed for SFC verification.' 'Run as administrator';break}
                # Verify only; never repair or reboot automatically. Preserve native output for localized systems.
                $process=New-Object Diagnostics.Process
                $process.StartInfo.FileName=Join-Path $env:SystemRoot 'System32\sfc.exe'
                $process.StartInfo.Arguments='/verifyonly'
                $process.StartInfo.UseShellExecute=$false;$process.StartInfo.CreateNoWindow=$true
                $process.StartInfo.RedirectStandardOutput=$true;$process.StartInfo.RedirectStandardError=$true
                $output=New-Object IO.MemoryStream;$errorOutput=New-Object IO.MemoryStream
                try {
                    $null=$process.Start()
                    $a=$process.StandardOutput.BaseStream.CopyToAsync($output)
                    $b=$process.StandardError.BaseStream.CopyToAsync($errorOutput)
                    $process.WaitForExit();$a.GetAwaiter().GetResult();$b.GetAwaiter().GetResult()
                    $code=$process.ExitCode
                    $raw=(DecodeSfcOutput $output.ToArray())+[Environment]::NewLine+(DecodeSfcOutput $errorOutput.ToArray())
                } finally {$process.Dispose();$output.Dispose();$errorOutput.Dispose()}
                $lines=@($raw -split '[\r\n]+' | ForEach-Object {$_.Trim()} | Where-Object {$_ -and $_ -notmatch '\d{1,3}\s*%'})
                $summary=($lines | Select-Object -Last 3) -join ' '
                if ($summary -match '(?i)did not find any integrity violations|не обнаружила нарушений целостности|keine Integritätsverletzungen gefunden') {Result 'OK' $summary}
                elseif ($summary -match '(?i)found integrity violations|обнаружила нарушения целостности|Integritätsverletzungen festgestellt') {Result 'Warning' ($summary+' — '+ 'Review Windows repair options.')}
                elseif ($code -ne 0) {Result 'Unknown' ("SFC exit code: $code. $summary")}
                else {Result 'Info' ("SFC verification output: $summary")}
            }
            'Windows image (DISM)' {
                $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {Result 'Skipped' 'Administrator rights are needed for DISM ScanHealth.' 'Run as administrator';break}
                $d=Repair-WindowsImage -Online -ScanHealth -NoRestart -ErrorAction Stop
                switch ([string]$d.ImageHealthState) {
                    'Healthy' {Result 'OK' 'DISM reports a healthy Windows component store.'}
                    'Repairable' {Result 'Warning' 'DISM found repairable corruption. Review Windows repair options.'}
                    'NonRepairable' {Result 'Warning' 'DISM reports non-repairable corruption. Seek Windows support.'}
                    default {Result 'Unknown' 'DISM did not return a known health state.'}
                }
            }
            default {Result 'Unknown' 'Unknown check.'}
        }
    } catch {Result 'Unknown' $_.Exception.Message}
}
# Optional per-user Explorer association. Never changes the default application.
function global:Get-NexEditorExtensions { return @('.txt','.log','.json','.xml','.csv','.md','.ini','.toml','.yaml','.yml','.ps1','.py','.js','.ts','.html','.css','.bat','.cmd','.cfg','.conf','.lua','.gitignore','.sh','.sql','.c','.cpp','.h','.cs','.rs','.java') }
function global:Set-NexEditorAssociation([bool]$Enable) {
    $base='HKCU:\Software\Classes';$id='NexDashboard.TextEditor';$prog=Join-Path $base $id
    $cap='HKCU:\Software\NexDashboard\EditorCapabilities';$apps='HKCU:\Software\RegisteredApplications';$app='NexTerminalEditor.exe';$appKey=Join-Path $base ('Applications\'+$app)
    $stateDir=Join-Path $env:LOCALAPPDATA 'NexDashboard';$launcher=Join-Path $stateDir $app;$config=Join-Path $stateDir 'editor-script.txt';$iconPath=Join-Path $stateDir 'NexTerminalEditor.ico'
    function WriteEditorReg([string]$sub,[string]$name,$value,[Microsoft.Win32.RegistryValueKind]$kind=[Microsoft.Win32.RegistryValueKind]::String) {
        $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($sub)
        if (-not $key) {throw 'Could not open registry key.'}
        try {$key.SetValue($name,$value,$kind)} finally {$key.Dispose()}
    }
    if ($Enable) {
        $installed=Join-Path (Split-Path -Parent $PROFILE) 'NexDashboard.ps1'
        if (-not (Test-Path -LiteralPath $installed -PathType Leaf)) {throw 'Install Dashboard first.'}
        $null=New-Item -ItemType Directory -Path $stateDir -Force
        # A distinct executable is required for Explorer's Applications/OpenWithList registration.
        # Compile locally; the launcher never executes the selected document.
        $source=@'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;
using System.Reflection;
[assembly: AssemblyTitle("NEX Terminal Editor")]
[assembly: AssemblyDescription("NEX Dashboard text editor")]
[assembly: AssemblyProduct("NEX Dashboard")]
namespace NexDash {
 public static class EditorLauncher270 {
  static string Enc(string s) {return Convert.ToBase64String(Encoding.Unicode.GetBytes(s));}
  [STAThread] public static void Main(string[] args) {
   try {
    if(args.Length!=1 || !File.Exists(args[0])) throw new Exception("Select an existing text file.");
    string script=File.ReadAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"editor-script.txt")).Trim();
    if(!File.Exists(script)) throw new Exception("NEX Dashboard is not installed. Register the editor again.");
    string ps=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32\\WindowsPowerShell\\v1.0\\powershell.exe");
    // Encode the two paths separately so neither quotes nor Terminal's semicolon parser can interpret them as commands.
    string cmd="& ([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('"+Enc(script)+"'))) -OpenEditor ([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('"+Enc(Path.GetFullPath(args[0]))+"')))";
    string arguments="-NoLogo -NoProfile -EncodedCommand "+Enc(cmd);
    string wt=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Microsoft\\WindowsApps\\wt.exe");
    if(File.Exists(wt)) {try {Process.Start(new ProcessStartInfo(wt,"-w new new-tab \""+ps+"\" "+arguments){UseShellExecute=true});return;}catch{}}
    Process.Start(new ProcessStartInfo(ps,arguments){UseShellExecute=true});
   } catch(Exception ex) {MessageBox.Show(ex.Message,"NEX Terminal Editor",MessageBoxButtons.OK,MessageBoxIcon.Error);}
  }
 }
}
'@
        $temp=Join-Path $stateDir ('editor-'+[guid]::NewGuid().ToString('N')+'.exe');$sourceFile=[IO.Path]::ChangeExtension($temp,'.cs')
        try {
            $compiler=Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
            if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {$compiler=Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe'}
            if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {throw 'Windows .NET Framework C# compiler not found.'}
            # Original NEX logo supplied by the maintainer; embedded so this test stays a single PS1.
            [IO.File]::WriteAllBytes($iconPath,[Convert]::FromBase64String('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'))
            [IO.File]::WriteAllText($sourceFile,$source,[Text.UTF8Encoding]::new($true))
            $compilerLog=@(& $compiler '/nologo' '/target:winexe' '/optimize+' ('/out:'+$temp) ('/win32icon:'+$iconPath) '/reference:System.Windows.Forms.dll' $sourceFile 2>&1)
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temp -PathType Leaf)) {throw (($compilerLog | Out-String).Trim())}
            Move-Item -LiteralPath $temp -Destination $launcher -Force -ErrorAction Stop
            [IO.File]::WriteAllText($config,$installed,[Text.UTF8Encoding]::new($false))
        } finally {foreach ($file in @($temp,$sourceFile)) {if (Test-Path -LiteralPath $file) {Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue}}}
        $command='"'+$launcher+'" "%1"';$icon='"'+$iconPath+'",0'
        $class='Software\Classes\'+$id;$capPath='Software\NexDashboard\EditorCapabilities';$application='Software\Classes\Applications\'+$app
        WriteEditorReg $class '' 'NEX Terminal Editor';WriteEditorReg $class 'FriendlyTypeName' 'NEX Terminal Editor'
        WriteEditorReg ($class+'\Application') 'ApplicationName' 'NEX Terminal Editor';WriteEditorReg ($class+'\DefaultIcon') '' $icon;WriteEditorReg ($class+'\shell\open\command') '' $command
        WriteEditorReg $application 'FriendlyAppName' 'NEX Terminal Editor';WriteEditorReg ($application+'\DefaultIcon') '' $icon;WriteEditorReg ($application+'\shell\open\command') '' $command
        WriteEditorReg ('Software\Microsoft\Windows\CurrentVersion\App Paths\'+$app) '' $launcher
        WriteEditorReg $capPath 'ApplicationName' 'NEX Terminal Editor';WriteEditorReg $capPath 'ApplicationDescription' 'Text and source code editor inside NEX Dashboard'
        foreach ($ext in @(Get-NexEditorExtensions)) {
            WriteEditorReg ('Software\Classes\'+$ext+'\OpenWithProgids') $id ([byte[]]@()) ([Microsoft.Win32.RegistryValueKind]::None)
            WriteEditorReg ($application+'\SupportedTypes') $ext ''
            WriteEditorReg ('Software\Classes\'+$ext+'\OpenWithList\'+$app) '' ''
            WriteEditorReg ($capPath+'\FileAssociations') $ext $id
            $verb='Software\Classes\SystemFileAssociations\'+$ext+'\shell\NexDashboard.Edit';WriteEditorReg $verb '' 'Open in NEX Terminal Editor';WriteEditorReg $verb 'Icon' $icon;WriteEditorReg ($verb+'\command') '' $command
        }
        WriteEditorReg 'Software\RegisteredApplications' 'NEX Terminal Editor' $capPath
    } else {
        foreach ($ext in @(Get-NexEditorExtensions)) {
            Remove-ItemProperty -LiteralPath (Join-Path $base ($ext+'\OpenWithProgids')) -Name $id -ErrorAction SilentlyContinue
            foreach ($key in @((Join-Path $base ($ext+'\OpenWithList\'+$app)),(Join-Path $base ($ext+'\shell\NexDashboard.Edit')),(Join-Path $base ('SystemFileAssociations\'+$ext+'\shell\NexDashboard.Edit')))) {Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue}
        }
        Remove-ItemProperty -LiteralPath $apps -Name 'NEX Terminal Editor' -ErrorAction SilentlyContinue
        foreach ($key in @($prog,$cap,$appKey,('HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\'+$app))) {if (Test-Path -LiteralPath $key) {Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop}}
        foreach ($file in @($launcher,$config,$iconPath)) {Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue}
    }
    try {
        if (-not ('NexDash.ShellAssociation270' -as [type])) {Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; namespace NexDash { public static class ShellAssociation270 { [DllImport("shell32.dll")] public static extern void SHChangeNotify(uint e,uint f,IntPtr a,IntPtr b); }}' -ErrorAction Stop}
        [NexDash.ShellAssociation270]::SHChangeNotify(0x08000000,0,[IntPtr]::Zero,[IntPtr]::Zero)
    } catch {}
}
# Lightweight, non-executing single-line lexer for the existing editor.
# Offsets remain those of the original text; no ANSI is inserted into the buffer.
function global:Get-NexSyntaxSpans([string]$Line,[string]$Extension) {
    $ext=$Extension.ToLowerInvariant()
    if ($ext -in @('.txt','.log','.csv','.gitignore')) {return}
    $comment=if ($ext -in @('.py','.ps1','.sh','.yaml','.yml','.toml','.ini','.cfg','.conf')) {'\#.*$'} elseif ($ext -in @('.sql','.lua')) {'--.*$'} elseif ($ext -in @('.bat','.cmd')) {'(?i:\bREM\s+.*$|^\s*::.*$)'} elseif ($ext -in @('.html','.xml','.md')) {'<!--.*?(?:-->|$)'} elseif ($ext -eq '.json') {'(?!)'} else {'//.*$|/\*.*?(?:\*/|$)'}
    $keywords='if|else|elif|elseif|for|foreach|while|do|return|yield|break|continue|class|def|function|import|from|as|try|except|catch|finally|throw|raise|new|const|let|var|public|private|protected|static|void|async|await|switch|case|default|in|is|not|and|or|true|false|null|none|nil|using|namespace|struct|enum|match|fn|use|mod|select|where|join|insert|update|delete|begin|end|param|filter|process|function|pass|with|lambda|global|nonlocal|export|interface|extends|implements|package|int|string|bool|float|double|long|char|unsigned|include|print|echo'
    $pattern='(?<comment>'+$comment+')|(?<string>"(?:\\.|`.|[^"\\`])*"?|''(?:\\.|[^''\\])*''?|`(?:\\.|[^`\\])*`?)|(?<number>\b(?:0x[\da-fA-F]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\b)|(?<variable>\$[\w:]+)|(?<keyword>\b(?:'+$keywords+')\b)|(?<call>\b[A-Za-z_][\w-]*(?=\s*\())|(?<operator>[{}\[\]();,:=+*/%<>!&|~-])'
    if ($ext -in @('.html','.xml')) {$pattern='(?<tag></?[\w:.-]+|/?>)|'+$pattern}
    if ($ext -eq '.md') {$pattern='(?<keyword>^\s*#{1,6}\s+.*$|\*\*[^*]+\*\*)|'+$pattern}
    foreach ($m in [regex]::Matches($Line,$pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase,[TimeSpan]::FromMilliseconds(100))) {
        foreach ($kind in @('comment','string','number','variable','keyword','call','operator','tag')) {if ($m.Groups[$kind].Success) {[pscustomobject]@{Start=$m.Index;Length=$m.Length;Kind=$kind};break}}
    }
}

function global:Invoke-NexDashboard {
    param([ValidateRange(0,22)][int]$StartPage=0,[switch]$StartScan,[string]$HandoffToken='',[string]$EditorPath='')
    $isAdmin=Test-NexAdministrator
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
    $pink=NexAnsi $palette[0];$purple=NexAnsi $palette[1];$bg=NexAnsi $palette[2] -Background;$white=NexAnsi $palette[4];$gray=NexAnsi $palette[5];$green=if ($prefs.LightMode) {NexAnsi '21683E'} else {NexAnsi 'A6E3A1'};$red=if ($prefs.LightMode) {NexAnsi 'A12848'} else {NexAnsi 'F38BA8'};$blue=if ($prefs.LightMode) {NexAnsi '275DAB'} else {NexAnsi '89B4FA'};$muted=if ($prefs.LightMode) {NexAnsi (Mix-NexColor $palette[5] $palette[3] 0.18)} else {NexAnsi '585B70'};$reset="$e[0m";if ($prefs.LightMode) {$reset+=$white}
    $names = @('Overview','System Monitor','Processes','Network','File Explorer','System Info','Windows Update','Quick Tools','System Logs','Terminal Settings','Personalization','Hardware Info','Gaming Mode','App Launcher','Update Center','System Health','Notification Center','Dashboard Designer','Startup Manager','Plugin Manager','Animation Studio','Benchmark Center','Large files and folders') | ForEach-Object { NexL $_ }
    $codes = @(0xF015,0xF080,0xF2DB,0xF1EB,0xF07B,0xF05A,0xF021,0xF0AD,0xF15C,0xF013,0xF1DE,0xF2DB,0xF11B,0xF135,0xF021,0xF0FA,0xF0F3,0xF009,0xF135,0xF1E6,0xF0D0,0xF080,0xF002)
    # Sidebar order is independent from stable page IDs used by workers and shortcuts.
    $baseNavOrder=@(0,1,2,11,3,5,4,22,13,12,21,18,7,15,8,16,10,9,17,20,19,6,14)
    function FavoriteIds {foreach ($v in ($prefs.Favorites -split ',')) {if ($v -match '^\d+$' -and [int]$v -in $baseNavOrder -and [int]$v -ne 0) {[int]$v}}}
    function NavOrder { $fav=@(FavoriteIds);0;foreach ($id in $fav) {$id};foreach ($id in $baseNavOrder) {if ($id -ne 0 -and $id -notin $fav) {$id}} }
    function ToggleFavorite([int]$id) {
        if ($id -eq 0 -or $id -notin $baseNavOrder) {return}
        $fav=@(FavoriteIds);if ($id -in $fav) {$fav=@($fav | Where-Object {$_ -ne $id})} else {$fav+=@($id)}
        $prefs.Favorites=$fav -join ',';NexSaveExtras
    }
    function HomeBlock([string]$name) {return ($name -notin ($prefs.OverviewHidden -split ','))}
    # Separators are visual rows only; real page IDs and keyboard order remain separate.
    $navGroupStarts=@(4,15,10,6)
    $s = @{
        Page=$StartPage; Nav=$StartPage; NavOffset=0; Focus='nav'; Size=''; Old=@(); Hits=@(); Msg=''; Next=0L; Need=$true
        Folder=$HOME; Drives=$false; Pos=0; Filter=''; FileItems=@(); Clipboard=$null
        ProcFilter=''; ProcSort='CPU'; ProcRows=@(); PrevProc=@{}; ProcAt=0L; ProcMetrics=$null; ProcMetricsAt=0L
        NetRows=@(); NetPrev=@{}; NetAt=0L; NetHist=@(); NetUpHist=@(); NetReady=$false; Down=0.0; Up=0.0; PeakDown=0.0; PeakUp=0.0; Ping='Not sampled'; PingHost='';
        SpeedProc=$null; SpeedOut=$null; SpeedErr=$null; SpeedStart=0L; SpeedStatus='Ready'; SpeedResult=$null; SpeedPath=(Get-NexSpeedtest); SpeedInstallPending=$false; SpeedConsentHash='';
        Info=@(); Logs=@(); LogPos=0; LogName='System'; LogText=''; ToolRows=@(); ToolTitle='';
        Config=$null; ConfigChoices=@(); ConfigPick=$null; Mouse=$false; Mode=0; Theme=0; SettingsRows=@(); LastOverview=$null
    }
    $s.ScanGroups=@(@{Title='Hardware';Steps=@('GPU','CPU','RAM','Storage')},@{Title='Devices and connectivity';Steps=@('Drivers','Network')},@{Title='Windows and security';Steps=@('Windows Security','System logs','Windows Update','Windows image (DISM)','System files (SFC)')});$s.ScanSteps=@($s.ScanGroups | ForEach-Object {$_.Steps});$s.ScanResults=@{};$s.ScanIndex=0;$s.ScanActive=$false;$s.ScanView=$false;$s.ScanStop=$false;$s.ScanPos=0;$s.ScanSelected='';$s.ScanDisplayCount=0
    if ($StartScan -and $StartPage -eq 7) {$s.ScanView=$true;$s.ScanActive=$true;$s.Focus='body'}
    $s.HomePos=0;$s.HomeMax=0;$s.NavWidth=0;$s.Task=$null;$s.TaskReport=$null;$s.DiskReport=$null;$s.DiskRoot=$HOME;$s.BenchKind='CPU';$s.BenchSeconds=10;$s.BenchRam='4';$s.BenchVram='2';$s.DragCard='';$s.DragOrder='';$s.DragMoved=$false;$s.DragPulse='';$s.DragOther='';$s.DragPulseUntil=0L;$s.DragPulseAt=0L;$s.DragOverlayRow=-1;$s.DragHover='';$s.DragHoverAt=0L;$s.DragRenderAt=0L;$s.DragSwapAt=0L;$s.DragSwapOrder='';$s.DragViewX=-1.0;$s.DragViewY=-1.0;$s.DragX=-1;$s.DragY=-1;$s.AllowDrag=$false;$s.CardTargets=@();$s.DragTargets=@()
    $s.HandoffToken='';$s.HandoffDeadline=0L;$s.HandoffExit=$false
    $s.ExtraErrors=@{}; $s.ExtraPos=0; $s.ExtraMax=0; $s.Hardware=$null; $s.Game=$null; $s.GameChangedAt=-1L; $s.Apps=$null; $s.AppFilter=''; $s.Health=$null
    $s.Release=$null; $s.ReleaseBadge=$false;$s.ReleaseBadgeAt=-10000L;$s.ReleaseCheckAt=-10000L;$s.ReleaseFinishAt=-10000L;$s.ReleaseAnimAt=0L;$s.ReleaseProbeStarted=$false;$s.ReleaseProbeManual=$false;$s.ReleaseProbeWorker=$null;$s.ReleaseProbeJob=$null; $s.OnlineRequested=$false; $s.OnlineReady=$false; $s.OnlineTemp=$null; $s.PendingHash=$null; $s.AlertDismiss=@{}; $s.Alerts=@(); $s.HealthNext=0L; $s.PendingInstaller=$null; $s.PendingVersion=$null
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
    function SmoothNumber([string]$id,[double]$target,[double]$tau=0.20) {
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
        if (-not ('NexDash.NativeInput216' -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace NexDash {
 public static class NativeInput216 {
  [StructLayout(LayoutKind.Explicit, Size=20)] public struct Record {
   [FieldOffset(0)] public ushort Type;
   [FieldOffset(4)] public int KeyDown;
   [FieldOffset(10)] public ushort VirtualKey;
   [FieldOffset(14)] public ushort UnicodeChar;
   [FieldOffset(16)] public uint ControlState;
   [FieldOffset(4)] public short X;
   [FieldOffset(6)] public short Y;
   [FieldOffset(8)] public uint Buttons;
   [FieldOffset(12)] public uint MouseControlState;
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
        $s.Mode=[NexDash.NativeInput216]::Enable(); $s.Mouse=($s.Mode -ge 0)
    } catch { $s.Mouse=$false }
    # Fast lightweight resource sampling; full overview worker still supplies hardware metadata.
    try {
        if (-not ('NexDash.LiveResources274' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace NexDash {
 public sealed class LiveResources274 {
  [StructLayout(LayoutKind.Sequential)] struct FT {public uint Low,High;public ulong Value {get {return ((ulong)High<<32)|Low;}}}
  [StructLayout(LayoutKind.Sequential)] struct Mem {public uint Length,Load;public ulong Total,Available,PageTotal,PageAvailable,VirtualTotal,VirtualAvailable,Extended;}
  [DllImport("kernel32.dll")] [return:MarshalAs(UnmanagedType.Bool)] static extern bool GetSystemTimes(out FT idle,out FT kernel,out FT user);
  [DllImport("kernel32.dll")] [return:MarshalAs(UnmanagedType.Bool)] static extern bool GlobalMemoryStatusEx(ref Mem m);
  ulong oldIdle,oldTotal; bool initialized;
  public double[] Read() {FT i,k,u;double cpu=Double.NaN; if(GetSystemTimes(out i,out k,out u)) {ulong total=k.Value+u.Value; if(initialized && total>oldTotal && i.Value>=oldIdle) cpu=Math.Max(0,Math.Min(100,100.0*(1.0-(double)(i.Value-oldIdle)/(total-oldTotal))));oldIdle=i.Value;oldTotal=total;initialized=true;}
   Mem m=new Mem();m.Length=(uint)Marshal.SizeOf(typeof(Mem));if(!GlobalMemoryStatusEx(ref m) || m.Total==0)return new double[]{cpu,Double.NaN,Double.NaN,Double.NaN};return new double[]{cpu,100.0*(1.0-(double)m.Available/m.Total),(m.Total-m.Available)/1073741824.0,m.Total/1073741824.0};}
 }
}
'@ -ErrorAction Stop
        }
        $s.LiveReader=[NexDash.LiveResources274]::new()
    } catch {$s.LiveReader=$null}
    $s.LiveAt=0L;$s.LiveCpu=$null;$s.LiveRam=$null;$s.LiveUsed=$null;$s.LiveTotal=$null
    function SampleNexResources {
        if (-not $s.LiveReader -or $clock.ElapsedMilliseconds -lt $s.LiveAt) {return}
        $s.LiveAt=$clock.ElapsedMilliseconds+350
        try {
            $v=$s.LiveReader.Read()
            if (-not [double]::IsNaN($v[0])) {$s.LiveCpu=$v[0]}
            if (-not [double]::IsNaN($v[1])) {$s.LiveRam=$v[1];$s.LiveUsed=$v[2];$s.LiveTotal=$v[3]}
        } catch {$s.LiveReader=$null}
    }
    function PauseMouse { if ($s.Mouse) { [NexDash.NativeInput216]::Restore($s.Mode) } }
    function ResumeMouse { if ($s.Mouse) { $s.Mode=[NexDash.NativeInput216]::Enable(); if ($s.Mode -lt 0) { $s.Mouse=$false } } }
    function DragCardAt([int]$x,[int]$y,[switch]$Drop) {
        if ($s.Preview -or -not $s.AllowDrag -or $s.DragSwapOrder) {return ''}
        if ($s.Page -eq 17) {foreach ($hit in $s.Hits) {if ($hit.Y -eq $y -and $x -ge $hit.X1 -and $x -lt $hit.X2 -and $hit.Kind -eq 'extra' -and [string]$hit.Index -match '^card:(.+)$') {return $Matches[1]}}}
        if ($s.Page -eq 1) {foreach ($hit in $s.DragTargets) {if (($hit.Y -eq $y -or ($Drop -and $y -ge $hit.Y -and $y -le $hit.EndY)) -and $x -ge $hit.X1 -and $x -lt $hit.X2) {return $hit.Id}}}
        return ''
    }
    function MoveNexCard([string]$from,[string]$to) {
        $order=@($s.DragOrder -split ',');if ($from -eq $to -or $from -notin $order -or $to -notin $order) {return}
        $fromIndex=[array]::IndexOf($order,$from);$toIndex=[array]::IndexOf($order,$to)
        $order[$fromIndex]=$to;$order[$toIndex]=$from
        $s.DragOrder=$order -join ',';$s.DragMoved=$true;$s.DragOther=$to
    }
    function DragFill([string]$id) {
        $now=$clock.ElapsedMilliseconds;$amount=0.0
        if ($s.DragCard -eq $id) {$amount=0.34}
        elseif ($s.DragCard -and $s.DragHover -eq $id) {
            $t=[Math]::Min(1.0,[Math]::Max(0.0,($now-$s.DragHoverAt)/150.0));$amount=0.46+0.08*(1-[Math]::Pow(1-$t,3))
        } elseif ($s.DragPulse -and $id -in @($s.DragPulse,$s.DragOther) -and $now -lt $s.DragPulseUntil) {
            if ($s.DragSwapOrder) {
                $t=[Math]::Min(1.0,[Math]::Max(0.0,1.0-($s.DragSwapAt-$now)/160.0));$amount=0.34+0.22*$t
            } else {
                $t=[Math]::Min(1.0,[Math]::Max(0.0,($s.DragPulseUntil-$now)/420.0));$amount=0.56*$t*$t
            }
        }
        if ($amount -gt 0) {return (NexAnsi (Mix-NexColor $palette[3] $palette[0] $amount) -Background)}
        return ''
    }
    function DrawNexDragBadge {
        $w=[Console]::WindowWidth;$h=[Console]::WindowHeight
        $frame='';$previous=$s.DragOverlayRow
        if ($previous -ge 0 -and $previous -lt $s.Old.Count -and $previous -lt $h) {$frame+="$e[$($previous+1);1H$reset$($s.Old[$previous])$reset$e[K"}
        $s.DragOverlayRow=-1
        if ($s.DragCard -and $s.DragY -ge 4 -and $s.DragY -lt $h-3 -and $s.DragX -ge 0 -and $s.DragX -lt $w) {
            $badge=' ◆ '+(NexL $s.DragCard)+' ';$bw=[Math]::Min($w-1,(Get-NexLogoWidth $badge));$bx=[Math]::Max(0,[Math]::Min($w-1-$bw,$s.DragX+2));$by=[Math]::Max(4,[Math]::Min($h-4,$s.DragY+1))
            $frame+="$e[$($by+1);$($bx+1)H$bg$pink$(ClipAnsi $badge $bw)$reset";$s.DragOverlayRow=$by
        }
        if ($frame) {Write-Host $frame -NoNewline}
    }
    function InputEvent {
        if ($s.Mouse) {
            $pendingMove=$null
            for ($j=0;$j -lt $(if ($s.DragCard) {256} else {40});$j++) {
                $r=[NexDash.NativeInput216]::Poll()
                if ($r.Type -eq 0) { return $pendingMove }
                if ($r.Type -eq 1 -and $r.KeyDown -ne 0) {
                    $vk=[int]$r.VirtualKey
                    if (-not [Enum]::IsDefined([System.ConsoleKey],$vk)) {
                        if ($r.UnicodeChar -ne 0) { return @{Key='Text';KeyChar=[char]$r.UnicodeChar;Ctrl=(($r.ControlState -band 12) -ne 0)} }
                        continue
                    }
                    $k=[System.ConsoleKey]$vk
                    return @{Key=$k.ToString();KeyChar=[char]$r.UnicodeChar;Ctrl=(($r.ControlState -band 12) -ne 0)}
                }
                if ($r.Type -eq 2 -and $r.Flags -in @(0,1,2)) {
                    $mx=[int]$r.X-[Console]::WindowLeft;$my=[int]$r.Y-[Console]::WindowTop
                    if ($s.DragCard) {
                        if (-not ($r.Buttons -band 1)) {return @{Key='CardDrop';X=$mx;Y=$my}}
                        if ($mx -ne $s.DragX -or $my -ne $s.DragY -or $pendingMove) {$pendingMove=@{Key='CardMove';X=$mx;Y=$my}}
                        continue
                    }
                    if ($r.Flags -in @(0,2) -and ($r.Buttons -band 1)) {
                        $card=DragCardAt $mx $my
                        if ($card) {return @{Key='CardGrab';Card=$card;X=$mx;Y=$my}}
                        return @{Key='Click';X=$mx;Y=$my}
                    }
                }
                if ($r.Type -eq 2 -and $r.Flags -eq 4) {
                    $wheel=if ($r.Buttons -band 0x80000000L) {'DownArrow'} else {'UpArrow'}
                    return @{Key=$wheel;Wheel=$true;X=([int]$r.X-[Console]::WindowLeft);Y=([int]$r.Y-[Console]::WindowTop)}
                }
            }
            if ($pendingMove) {return $pendingMove}
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
        if ($s.Mouse) {try {$savedMode=[NexDash.NativeInput216]::EnableEditor()} catch {}}
        try {
            while ($true) {
                $w=[Console]::WindowWidth; $h=[Console]::WindowHeight
                if ($w -lt 42 -or $h -lt 18) {
                    Write-Host "$reset$e[2J$e[H$pink$(NexL 'Enlarge the window or press Esc.')$reset" -NoNewline
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
                $frame="$reset$e[2J$e[?25l"
                for ($i=0;$i -lt $rows.Count -and ($y+$i) -le $h;$i++) {$frame+="$e[$($y+$i);${x}H$reset$(ClipAnsi $rows[$i] $inner)"}
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
            if ($savedMode -ge 0) {[NexDash.NativeInput216]::Restore($savedMode)}
            Write-Host "$e[?25l" -NoNewline; ResetDraw
        }
    }
    function Ask($title,$choices=@(),$choiceValues=@(),$initialChoice=$null,[string]$helpKey='',[string]$initialText='',[string]$renameSuffix='',[string]$renameOriginal='') {
        # Raw mode keeps mouse and Ctrl+V available in the text field.
        $savedMode=-1
        if ($s.Mouse) { try { $savedMode=[NexDash.NativeInput216]::EnableEditor() } catch {} }
        $value=$initialText; $caret=$value.Length; $renameSelected=[bool]$renameOriginal; $offset=0; $pick=0; $pickedWithKeys=$false
        $searchMode=($title -eq 'Search Dashboard');$allChoices=@($choices);$allValues=@($choiceValues);$previousSearch=$null
        if ($null -ne $initialChoice -and $choiceValues.Count -gt 0) {
            $idx=[Array]::IndexOf([object[]]$choiceValues,[object]$initialChoice)
            if ($idx -ge 0) {$pick=$idx;$pickedWithKeys=$true}
        }
        try {
            while ($true) {
                $w=[Console]::WindowWidth; $h=[Console]::WindowHeight
                if ($w -lt 32 -or $h -lt 10) {
                    Write-Host "$reset$e[2J$e[H$pink $(NexL 'Enlarge the window or press Esc.')$reset" -NoNewline
                    $ev=WaitNexEvent; if ($ev.Key -eq 'Escape') { return $null }; continue
                }
                if ($searchMode -and ($null -eq $previousSearch -or $previousSearch -cne $value)) {
                    $choices=@();$choiceValues=@();$pick=0;$offset=0;$previousSearch=$value
                    for ($k=0;$k -lt $allChoices.Count;$k++) {
                        if (([string]$allChoices[$k]).IndexOf($value,[StringComparison]::OrdinalIgnoreCase) -ge 0) {$choices+=@($allChoices[$k]);$choiceValues+=@($allValues[$k])}
                    }
                }
                $inner=[Math]::Min(76,$w-4); $x=[Math]::Max(1,[int][Math]::Floor(($w-$inner)/2))
                $dialogHelp=if ($searchMode) {if ($choices.Count) {NexL 'Type to filter; Enter opens the selected result.'} else {NexL 'No matching sections. Change the search text.'}} elseif ($renameOriginal) {NexL 'Rename help'} elseif ($helpKey -eq 'Editor association help') {NexL $helpKey} elseif ($prefs.SettingHelp -and $helpKey) {NexL $helpKey} elseif ($prefs.SettingHelp -and $global:NexDialogHelp.ContainsKey([string]$title)) {NexL $global:NexDialogHelp[[string]$title]} elseif (-not $choices.Count) {NexL 'Type a value. Esc cancels.'} else {NexL 'Type a value, or click a choice. Esc cancels.'}
                $helpLimit=[Math]::Max(1,[Math]::Min(5,$h-10))
                $helpLines=@(WrapUpdateLine $dialogHelp ($inner-2) | Select-Object -First $helpLimit)
                $reserve=9+$helpLines.Count+$(if ($renameOriginal) {2} else {0})
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
                        $marker=if ($idx -eq $pick) {'❯ '} else {'  '}
                        $label=Fit ($marker+(NexL ([string]$choices[$idx]))) ([Math]::Max(1,$inner-10))
                        $swatches="$(NexAnsi $tp[0])● $(NexAnsi $tp[1])● $(NexAnsi $tp[3] -Background)$(NexAnsi $tp[4]) Aa $reset"
                        $rows+="$style$label$reset $swatches"
                    } else {$rows+= "$style$(Fit ('  '+(NexL ([string]$choices[$idx]))) $inner)$reset"}
                }
                $rows+=''
                $fieldRow=$rows.Count
                $maxChars=[Math]::Max(1,$inner-4); $left=[Math]::Max(0,$caret-$maxChars+1)
                $visible=if ($value.Length -gt $left) {$value.Substring($left)} else {''}
                if ($renameSelected) {$rows+="$purple > $bg$white$(ClipAnsi (SafeText $visible) $maxChars)$reset"}
                else {$rows+="$purple > $white$(Fit $visible $maxChars)$reset"}
                if ($renameOriginal) {
                    $newName=RenameFullName $value $renameSuffix;$validName=$true
                    try {FileNameValid $newName} catch {$validName=$false}
                    $rows+="$gray $(NexL 'Current name'): $white$(SafeText $renameOriginal)$reset"
                    $previewText=if ($validName) {"$green$(SafeText $newName)"} else {"$red$(NexL 'Invalid file name.')"}
                    $rows+="$purple $(NexL 'New name preview'): $previewText$reset"
                }
                $rows+="$muted$('─'*$inner)$reset"
                $buttonRow=$rows.Count
                $cancelButton='[ '+(NexL 'Cancel')+' ]';$rows+="$pink[ OK ]$reset  $purple$cancelButton$reset"
                $rows+="$gray$(NexL 'Enter OK  |  Esc Cancel  |  Ctrl+V Paste')$reset"
                $y=[Math]::Max(1,[int][Math]::Floor(($h-$rows.Count)/2)+1)
                $frame="$reset$e[2J$e[?25l"
                for ($i=0;$i -lt $rows.Count;$i++) { $frame+="$e[$($y+$i);${x}H$reset$(ClipAnsi $rows[$i] $inner)" }
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
                        $renameSelected=$false;$caret=[Math]::Max(0,[Math]::Min($value.Length,$left+$rx-3)); continue
                    } else { continue }
                }
                if ($key -eq 'Enter') {
                    if ($renameOriginal -and -not $validName) {continue}
                    if ($searchMode) {if ($choices.Count) {return [string]$choiceValues[$pick]};continue}
                    if ([string]::IsNullOrWhiteSpace($value)) {
                        if ($pickedWithKeys -and $choices.Count -gt 0 -and $choiceValues.Count -eq $choices.Count) { return [string]$choiceValues[$pick] }
                        return $null
                    }
                    return $value.Trim()
                }
                if ($key -eq 'Resize') { continue }
                if ($ev.Ctrl -and $key -eq 'A') {if ($renameOriginal) {$renameSelected=$true;$caret=$value.Length} else {$value='';$caret=0};continue}
                if (($ev.Ctrl -and $key -eq 'V') -or ($null -ne $ev.KeyChar -and [int]$ev.KeyChar -eq 22)) {
                    try { $insert=Get-Clipboard -Raw -ErrorAction Stop; if ($insert) { if ($renameSelected) {$value='';$caret=0;$renameSelected=$false};$insert=SafeText $insert; $value=$value.Insert($caret,$insert); $caret+=$insert.Length } } catch {}; continue
                }
                if ($ev.Ctrl) { continue }
                if ($renameSelected) {
                    if ($key -in @('LeftArrow','Home')) {$caret=0;$renameSelected=$false;continue}
                    if ($key -in @('RightArrow','End')) {$caret=$value.Length;$renameSelected=$false;continue}
                    if ($key -in @('Backspace','Delete')) {$value='';$caret=0;$renameSelected=$false;continue}
                    if ($null -ne $ev.KeyChar -and -not [char]::IsControl([char]$ev.KeyChar)) {$value='';$caret=0;$renameSelected=$false}
                }
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
            if ($savedMode -ge 0) { [NexDash.NativeInput216]::Restore($savedMode) }
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
        if ($i -eq 0 -and $s.Page -ne 0) {$s.HomePos=0}
        if ($i -eq 10 -and $s.Page -ne 10) {$s.PersonalPos=0}
        if ($i -ge 11 -and $s.Page -ne $i) {$s.ExtraPos=0}
        $s.Page=$i; $s.Nav=$i; $s.Focus='body'; $s.Msg=''; $s.Next=0; $s.Need=$true
    }
    # Bounded, read-only filesystem walk. Do not follow junctions, symlinks or cloud reparse points.
    $largeScanScript={param($task)
        $ErrorActionPreference='Stop';$watch=[Diagnostics.Stopwatch]::StartNew()
        $files=New-Object 'System.Collections.Generic.List[object]';$folders=New-Object 'System.Collections.Generic.List[object]'
        $state=@{Count=0;Skipped=0;Partial=$false};$root=[IO.DirectoryInfo]::new([string]$task.Root)
        function AddTop($list,$path,[long]$size) {
            if ($size -le 0) {return}
            if ($list.Count -ge 30 -and $size -le $list[$list.Count-1].Bytes) {return}
            $i=0;while ($i -lt $list.Count -and $list[$i].Bytes -ge $size) {$i++}
            $list.Insert($i,[pscustomobject]@{Path=$path;Bytes=$size})
            if ($list.Count -gt 30) {$list.RemoveAt($list.Count-1)}
        }
        function Walk($dir,[int]$depth) {
            $sum=0L
            if ($depth -gt 64) {$state.Skipped++;$state.Partial=$true;return $sum}
            try {
                foreach ($entry in $dir.EnumerateFileSystemInfos()) {
                    if ($task.Cancel -or $state.Count -ge 100000 -or $watch.Elapsed.TotalSeconds -ge 90) {$state.Partial=$true;break}
                    $state.Count++
                    if ($state.Count % 128 -eq 0) {$task.Count=$state.Count;$task.Skipped=$state.Skipped}
                    try {
                        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {$state.Skipped++;continue}
                        if ($entry -is [IO.DirectoryInfo]) {
                            $size=Walk $entry ($depth+1);$sum+=$size
                            AddTop $folders $entry.FullName $size
                        } elseif ($entry -is [IO.FileInfo]) {$size=[long]$entry.Length;$sum+=$size;AddTop $files $entry.FullName $size}
                    } catch {$state.Skipped++}
                    if ($state.Partial -and ($task.Cancel -or $state.Count -ge 100000 -or $watch.Elapsed.TotalSeconds -ge 90)) {break}
                }
            } catch {$state.Skipped++;$state.Partial=$true}
            return $sum
        }
        if (-not $root.Exists -or ($root.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Folder is unavailable or is a link.'}
        $total=Walk $root 0
        $task.Count=$state.Count;$task.Skipped=$state.Skipped
        [pscustomobject]@{Root=$root.FullName;Files=$files.ToArray();Folders=$folders.ToArray();Count=$state.Count;Skipped=$state.Skipped;Partial=($state.Partial -or $state.Skipped -gt 0);Cancelled=[bool]$task.Cancel;Bytes=$total;Seconds=$watch.Elapsed.TotalSeconds}
    }
    # Native, time-limited synthetic workloads. No external executables are downloaded.
    $benchScript={param($task)
        $ErrorActionPreference='Stop';$watch=[Diagnostics.Stopwatch]::new();$started=Get-Date
        $seconds=[int]$task.Seconds;$kind=[string]$task.TestKind;$bench=$null;$process=$null
        $errors=0;$samples=0;$peakLoad=$null;$peakTemp=$null;$peakRate=0.0;$peakMemory=$null;$peakVram=$null;$vramTotal=$null;$peakAlloc=0L;$bytes=0L;$units=0L;$status='Complete';$detail='';$adapter='';$lastSample=0.0;$lastBytes=0L;$lastUnits=0L;$lastCpu=0.0
        try {
            if (-not ('NexDash.Bench274' -as [type])) {
                Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Collections;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
namespace NexDash {
 public sealed class Bench274 : IDisposable {
  volatile bool stop; readonly List<Thread> threads=new List<Thread>();
  readonly Stopwatch timer=new Stopwatch(); int duration; IDictionary control; bool waitForRam;
  bool ShouldStop {get {return stop || timer.Elapsed.TotalSeconds>=duration || (control!=null && object.Equals(control["Cancel"],true));}}
  long bytes, units, errors, allocated, peakAllocated; string failure=""; readonly object gate=new object();
  public long Bytes { get { return Interlocked.Read(ref bytes); } }
  public long Units { get { return Interlocked.Read(ref units); } }
  public long Errors { get { return Interlocked.Read(ref errors); } }
  public long Allocated { get { return Interlocked.Read(ref allocated); } }
  public long PeakAllocated {get{return Interlocked.Read(ref peakAllocated);}}
  void TrackPeak(long value) {long prior;do {prior=Interlocked.Read(ref peakAllocated);if(value<=prior)return;}while(Interlocked.CompareExchange(ref peakAllocated,value,prior)!=prior);}
  public string Failure { get { lock(gate) return failure; } }
  public bool Running { get { foreach(Thread t in threads) if(t.IsAlive) return true; return false; } }
  public int Workers { get { return threads.Count; } }
  [StructLayout(LayoutKind.Sequential)] struct Mem {public uint Length,Load;public ulong Total,Available,PageTotal,PageAvailable,VirtualTotal,VirtualAvailable,Extended;}
  [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool GlobalMemoryStatusEx(ref Mem m);
  public static long[] Memory() { Mem m=new Mem();m.Length=(uint)Marshal.SizeOf(typeof(Mem));if(!GlobalMemoryStatusEx(ref m)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());return new long[]{(long)m.Total,(long)m.Available}; }
  string adapter=""; public string Adapter {get {lock(gate) return adapter;}}
  void Fail(Exception ex) { lock(gate) { if(failure.Length==0) failure=ex.Message; } Interlocked.Increment(ref errors); stop=true; }
  void Spawn(ThreadStart work) { Thread t=new Thread(delegate() { try { work(); } catch(Exception ex) { Fail(ex); } }); t.IsBackground=true; t.Priority=ThreadPriority.BelowNormal; threads.Add(t); t.Start(); }
  public void Start(string kind,long ramBudget,int seconds,IDictionary task) {
   duration=Math.Max(1,Math.Min(30,seconds));control=task;waitForRam=kind=="RAM";timer.Start();
   int n=Math.Max(1,Math.Min(64,Environment.ProcessorCount-1));
   if(kind=="CPU") {
    for(int i=0;i<n;i++) Spawn(delegate() {
     byte[] data=new byte[1024*1024];
     using(SHA256 sha=SHA256.Create()) {
      byte[] expected=sha.ComputeHash(data);
      while(!ShouldStop) { byte[] actual=sha.ComputeHash(data); bool equal=true; for(int j=0;j<expected.Length;j++) if(actual[j]!=expected[j]) {equal=false;break;}
       if(!equal) throw new InvalidOperationException("CPU checksum mismatch"); Interlocked.Add(ref bytes,data.Length); Interlocked.Increment(ref units);
      }
     }
    });
   } else if(kind=="RAM") {
    // Allocate separate 32 MiB pairs progressively, then verify every copied byte.
    const int chunk=32*1024*1024; n=(int)Math.Max(1L,Math.Min(Math.Min(n,8),ramBudget/(2L*chunk)));long perWorker=ramBudget/n;
    if(perWorker<2L*chunk) throw new InvalidOperationException("Not enough available RAM for a safe test");
    for(int i=0;i<n;i++) Spawn(delegate() { RamWorker(perWorker,chunk); });
   } else if(kind=="GPU") Spawn(delegate() { using(Gpu274 gpu=new Gpu274(ramBudget)) { lock(gate) adapter=gpu.AdapterName; while(!ShouldStop) { gpu.Run(); Interlocked.Exchange(ref allocated,gpu.Allocated);TrackPeak(gpu.Allocated); Interlocked.Increment(ref units); } } });
   else throw new ArgumentException("Unknown benchmark");
  }
  [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr VirtualAlloc(IntPtr address,UIntPtr size,uint allocation,uint protect);
  [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool VirtualFree(IntPtr address,UIntPtr size,uint freeType);
  [DllImport("msvcrt.dll", CallingConvention=CallingConvention.Cdecl)] static extern IntPtr memset(IntPtr dest,int value,UIntPtr size);
  [DllImport("msvcrt.dll", CallingConvention=CallingConvention.Cdecl)] static extern IntPtr memcpy(IntPtr dest,IntPtr src,UIntPtr size);
  [DllImport("msvcrt.dll", CallingConvention=CallingConvention.Cdecl)] static extern int memcmp(IntPtr a,IntPtr b,UIntPtr size);
  static IntPtr Allocate(int size) {IntPtr p=VirtualAlloc(IntPtr.Zero,new UIntPtr((uint)size),0x3000,0x04);if(p==IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());return p;}
  static void ReleaseRam(IntPtr p) {if(p!=IntPtr.Zero && !VirtualFree(p,UIntPtr.Zero,0x8000)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());}
  void RamWorker(long budget,int chunk) {
   List<IntPtr> src=new List<IntPtr>(),dst=new List<IntPtr>();long own=0;
   try {
    while(!ShouldStop && own+2L*chunk<=budget) {
     long[] m=Memory(); long reserve=Math.Max(3L*1024*1024*1024,(long)(m[0]*0.15));
     if(m[1]<reserve+2L*chunk*8) break;
     IntPtr a=IntPtr.Zero,b=IntPtr.Zero;
     try {
      a=Allocate(chunk);b=Allocate(chunk);
      memset(a,0xA5,new UIntPtr((uint)chunk));memset(b,0x5A,new UIntPtr((uint)chunk));
      src.Add(a);dst.Add(b);a=IntPtr.Zero;b=IntPtr.Zero;
      own+=2L*chunk;TrackPeak(Interlocked.Add(ref allocated,2L*chunk));
     } finally {try {ReleaseRam(a);} finally {ReleaseRam(b);}}
    }
    if(src.Count==0 && !ShouldStop) throw new InvalidOperationException("Memory reserve reached before allocation");
    int round=0;
    while(!ShouldStop) {for(int k=0;k<src.Count && !ShouldStop;k++) {
     long[] available=Memory();if(available[1]<Math.Max(2L*1024*1024*1024,(long)(available[0]*0.10))) {stop=true;break;}
     for(int off=0;off<chunk && !ShouldStop;off+=1024*1024) {
      int count=Math.Min(1024*1024,chunk-off);UIntPtr size=new UIntPtr((uint)count);
      IntPtr a=IntPtr.Add(src[k],off),b=IntPtr.Add(dst[k],off);
      memset(a,(round+k+(off/1048576))&255,size);memcpy(b,a,size);
      if(memcmp(a,b,size)!=0) throw new InvalidOperationException("RAM copy mismatch");
      Interlocked.Add(ref bytes,count);Interlocked.Increment(ref units);
     }
    } round++;}
   } finally {
    foreach(IntPtr a in src) {try {ReleaseRam(a);} catch(Exception ex) {Fail(ex);}}
    foreach(IntPtr b in dst) {try {ReleaseRam(b);} catch(Exception ex) {Fail(ex);}}
    src.Clear();dst.Clear();Interlocked.Add(ref allocated,-own);
   }
  }
  public void Dispose() { stop=true; foreach(Thread t in threads) if(t.IsAlive) {if(waitForRam)t.Join();else t.Join(1500);} }

 }
 // Direct3D 11 hardware compute only. Bounded dispatches and a readback check; no software fallback.
 internal sealed class Gpu274 : IDisposable {
  const int Count=262144;
  IntPtr dev,ctx,buf,uav,read,shader,code,err,adapter3,memShader,memRead;
  const int MemCount=4*1024*1024; const long BlockBytes=MemCount*4L;
  readonly List<IntPtr> memBuffers=new List<IntPtr>(), memViews=new List<IntPtr>();
  long requested; int cursor; public long Allocated {get{return memBuffers.Count*BlockBytes;}}
  [StructLayout(LayoutKind.Sequential)] struct VideoInfo {public ulong Budget,CurrentUsage,AvailableForReservation,CurrentReservation;}
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int QueryVideo(IntPtr self,uint node,uint segment,out VideoInfo info);
  long Headroom() {if(adapter3==IntPtr.Zero)return 0; VideoInfo v;if(Method<QueryVideo>(adapter3,14)(adapter3,0,0,out v)<0)return 0;return (long)Math.Min(v.Budget,(ulong)long.MaxValue)-(long)Math.Min(v.CurrentUsage,(ulong)long.MaxValue);}
  void GetBudgetAdapter(IntPtr a) {Guid iid=new Guid("645967a4-1392-4310-a798-8053ce3e93fd");if(Marshal.QueryInterface(a,ref iid,out adapter3)<0)adapter3=IntPtr.Zero;}
  [StructLayout(LayoutKind.Sequential)] struct BufferDesc {public uint ByteWidth,Usage,BindFlags,CPUAccessFlags,MiscFlags,StructureByteStride;}
  [StructLayout(LayoutKind.Sequential)] struct UavDesc {public uint Format,Dimension,FirstElement,NumElements,Flags;}
  [StructLayout(LayoutKind.Sequential)] struct Mapped {public IntPtr Data;public uint RowPitch,DepthPitch;}
  [DllImport("d3d11.dll",CallingConvention=CallingConvention.StdCall)] static extern int D3D11CreateDevice(IntPtr adapter,uint driver,IntPtr software,uint flags,IntPtr levels,uint n,uint sdk,out IntPtr device,out uint level,out IntPtr context);
  [DllImport("d3dcompiler_47.dll",CallingConvention=CallingConvention.StdCall)] static extern int D3DCompile(byte[] src,UIntPtr size,IntPtr name,IntPtr defines,IntPtr include,[MarshalAs(UnmanagedType.LPStr)] string entry,[MarshalAs(UnmanagedType.LPStr)] string target,uint f1,uint f2,out IntPtr blob,out IntPtr errors);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate IntPtr BlobPtr(IntPtr self);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate UIntPtr BlobSize(IntPtr self);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateBuffer(IntPtr self,ref BufferDesc desc,IntPtr init,out IntPtr buffer);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateUav(IntPtr self,IntPtr resource,ref UavDesc desc,out IntPtr view);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateShader(IntPtr self,IntPtr bytes,UIntPtr size,IntPtr linkage,out IntPtr shader);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void SetUav(IntPtr self,uint start,uint count,ref IntPtr views,IntPtr counts);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void SetShader(IntPtr self,IntPtr shader,IntPtr instances,uint count);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void Dispatch(IntPtr self,uint x,uint y,uint z);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void Copy(IntPtr self,IntPtr dest,IntPtr source);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int Map(IntPtr self,IntPtr resource,uint sub,uint type,uint flags,out Mapped map);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void Unmap(IntPtr self,IntPtr resource,uint sub);
  static T Method<T>(IntPtr obj,int slot) where T:class { return Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(Marshal.ReadIntPtr(obj),slot*IntPtr.Size),typeof(T)) as T; }
  static void Check(int hr) { if(hr<0) Marshal.ThrowExceptionForHR(hr); }
  static void Release(ref IntPtr p) { if(p!=IntPtr.Zero) { Marshal.Release(p); p=IntPtr.Zero; } }
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct AdapterDesc { [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)] public string Name; public uint Vendor,Device,SubSys,Revision;public UIntPtr Video,System,Shared;public long Luid; }
  [DllImport("dxgi.dll",CallingConvention=CallingConvention.StdCall)] static extern int CreateDXGIFactory1(ref Guid iid,out IntPtr factory);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int EnumAdapter(IntPtr self,uint index,out IntPtr adapter);
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct AdapterDesc1 { [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)] public string Name; public uint Vendor,Device,SubSys,Revision;public UIntPtr Video,System,Shared;public long Luid;public uint Flags; }
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetDesc1(IntPtr self,out AdapterDesc1 desc);
  static IntPtr PreferredAdapter() {IntPtr factory=IntPtr.Zero,best=IntPtr.Zero;ulong largest=0;
   try {Guid iid=new Guid("770aae78-f26f-4dba-a829-253c83d1b387");if(CreateDXGIFactory1(ref iid,out factory)<0)return IntPtr.Zero;
    for(uint i=0;i<32;i++) {IntPtr a=IntPtr.Zero;try {if(Method<EnumAdapter>(factory,12)(factory,i,out a)<0)break;AdapterDesc1 d;
      if(Method<GetDesc1>(a,10)(a,out d)>=0 && (d.Flags&2)==0 && d.Video.ToUInt64()>largest) {largest=d.Video.ToUInt64();Release(ref best);best=a;a=IntPtr.Zero;}
     } finally {Release(ref a);}}
   }catch{Release(ref best);}finally{Release(ref factory);}return best;
  }
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetAdapter(IntPtr self,out IntPtr adapter);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetDesc(IntPtr self,out AdapterDesc desc);
  public string AdapterName {get;private set;}
  string GetName() {IntPtr dx=IntPtr.Zero,a=IntPtr.Zero;try {Guid iid=new Guid("54ec77fa-1377-44e6-8c32-88fd5f44c84c");Check(Marshal.QueryInterface(dev,ref iid,out dx));Check(Method<GetAdapter>(dx,7)(dx,out a));AdapterDesc d;Check(Method<GetDesc>(a,8)(a,out d));if(d.Video.ToUInt64()>0)GetBudgetAdapter(a);return d.Name;}catch{return "";}finally{Release(ref a);Release(ref dx);}}
  readonly SetUav setUav; readonly SetShader setShader; readonly Dispatch dispatch; readonly Copy copy; readonly Map map; readonly Unmap unmap;
  public Gpu274(long budget) { requested=budget; try {
   uint level=0;IntPtr preferred=PreferredAdapter();int hr=-1;
   try {if(preferred!=IntPtr.Zero)hr=D3D11CreateDevice(preferred,0,IntPtr.Zero,0,IntPtr.Zero,0,7,out dev,out level,out ctx);} finally {Release(ref preferred);}
   if(hr<0) {Release(ref ctx);Release(ref dev);Check(D3D11CreateDevice(IntPtr.Zero,1,IntPtr.Zero,0,IntPtr.Zero,0,7,out dev,out level,out ctx));}
   if(level<0xb000) throw new NotSupportedException("Direct3D 11 feature level required"); AdapterName=GetName();
   const string hlsl="RWStructuredBuffer<uint> result : register(u0); [numthreads(256,1,1)] void main(uint3 id : SV_DispatchThreadID) { uint v=id.x+1; [loop] for(uint j=0;j<512;j++){v=v*1664525u+1013904223u; v^=v>>13;} result[id.x]=v; }";
   byte[] src=Encoding.ASCII.GetBytes(hlsl); Check(D3DCompile(src,new UIntPtr((uint)src.Length),IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,"main","cs_5_0",0,0,out code,out err));
   Check(Method<CreateShader>(dev,18)(dev,Method<BlobPtr>(code,3)(code),Method<BlobSize>(code,4)(code),IntPtr.Zero,out shader));
   BufferDesc d=new BufferDesc {ByteWidth=Count*4,Usage=0,BindFlags=0x80,MiscFlags=0x40,StructureByteStride=4};
   Check(Method<CreateBuffer>(dev,3)(dev,ref d,IntPtr.Zero,out buf));
   UavDesc u=new UavDesc {Format=0,Dimension=1,NumElements=Count}; Check(Method<CreateUav>(dev,8)(dev,buf,ref u,out uav));
   d=new BufferDesc {ByteWidth=Count*4,Usage=3,CPUAccessFlags=0x20000}; Check(Method<CreateBuffer>(dev,3)(dev,ref d,IntPtr.Zero,out read));
   setUav=Method<SetUav>(ctx,68);setShader=Method<SetShader>(ctx,69);dispatch=Method<Dispatch>(ctx,41);copy=Method<Copy>(ctx,47);map=Method<Map>(ctx,14);unmap=Method<Unmap>(ctx,15);
   if(adapter3!=IntPtr.Zero && requested!=0) {
    IntPtr blob=IntPtr.Zero,errors=IntPtr.Zero;
    try {byte[] memSrc=Encoding.ASCII.GetBytes("RWStructuredBuffer<uint> result : register(u0); [numthreads(256,1,1)] void main(uint3 id : SV_DispatchThreadID){result[id.x]=id.x ^ 0xA5A55A5Au;}");
     Check(D3DCompile(memSrc,new UIntPtr((uint)memSrc.Length),IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,"main","cs_5_0",0,0,out blob,out errors));
     Check(Method<CreateShader>(dev,18)(dev,Method<BlobPtr>(blob,3)(blob),Method<BlobSize>(blob,4)(blob),IntPtr.Zero,out memShader));
     BufferDesc staging=new BufferDesc {ByteWidth=(uint)BlockBytes,Usage=3,CPUAccessFlags=0x20000};Check(Method<CreateBuffer>(dev,3)(dev,ref staging,IntPtr.Zero,out memRead));
    } finally {Release(ref blob);Release(ref errors);}
   }
  } catch { Dispose(); throw; } }
  static uint Expected(uint i) { unchecked {uint v=i+1;for(int j=0;j<512;j++){v=v*1664525u+1013904223u;v^=v>>13;}return v;} }
  void MemoryPass() {
   if(memShader==IntPtr.Zero)return;
   long room=Headroom();
   // Stay within the OS-reported local video-memory budget, with 1 GiB headroom.
   if(room<512L*1024*1024 && memBuffers.Count>0) {int k=memBuffers.Count-1;IntPtr a=memViews[k],b=memBuffers[k];memViews.RemoveAt(k);memBuffers.RemoveAt(k);Release(ref a);Release(ref b);}
   if(room>1024L*1024*1024+BlockBytes && (requested<0 || Allocated+BlockBytes<=requested) && memBuffers.Count<2048) {
    IntPtr b=IntPtr.Zero,v=IntPtr.Zero;
    try {BufferDesc d=new BufferDesc {ByteWidth=(uint)BlockBytes,Usage=0,BindFlags=0x80,MiscFlags=0x40,StructureByteStride=4};Check(Method<CreateBuffer>(dev,3)(dev,ref d,IntPtr.Zero,out b));
     UavDesc u=new UavDesc {Dimension=1,NumElements=MemCount};Check(Method<CreateUav>(dev,8)(dev,b,ref u,out v));memBuffers.Add(b);memViews.Add(v);b=IntPtr.Zero;v=IntPtr.Zero;cursor=memBuffers.Count-1;
    } finally {Release(ref b);Release(ref v);}
   }
   if(memBuffers.Count==0)return; int index=cursor%memBuffers.Count;cursor=(index+1)%memBuffers.Count;
   IntPtr view=memViews[index];setShader(ctx,memShader,IntPtr.Zero,0);setUav(ctx,0,1,ref view,IntPtr.Zero);dispatch(ctx,MemCount/256,1,1);
   IntPtr none=IntPtr.Zero;setUav(ctx,0,1,ref none,IntPtr.Zero);copy(ctx,memRead,memBuffers[index]);Mapped m;Check(map(ctx,memRead,0,1,0,out m));
   try {for(int i=0;i<MemCount;i+=1021)if(unchecked((uint)Marshal.ReadInt32(m.Data,i*4))!=((uint)i^0xA5A55A5Au))throw new InvalidOperationException("VRAM sample mismatch");}finally{unmap(ctx,memRead,0);}
  }
  public void Run() {
   MemoryPass();setShader(ctx,shader,IntPtr.Zero,0);setUav(ctx,0,1,ref uav,IntPtr.Zero);dispatch(ctx,Count/256,1,1);
   IntPtr none=IntPtr.Zero;setUav(ctx,0,1,ref none,IntPtr.Zero);copy(ctx,read,buf);
   Mapped m;Check(map(ctx,read,0,1,0,out m));try { for(int i=0;i<Count;i+=65535) if(unchecked((uint)Marshal.ReadInt32(m.Data,i*4))!=Expected((uint)i)) throw new InvalidOperationException("GPU readback mismatch"); } finally {unmap(ctx,read,0);}
  }
  public void Dispose() {Release(ref ctx);foreach(IntPtr item in memViews){IntPtr p=item;Release(ref p);}foreach(IntPtr item in memBuffers){IntPtr p=item;Release(ref p);}memViews.Clear();memBuffers.Clear();Release(ref memShader);Release(ref memRead);Release(ref adapter3);Release(ref shader);Release(ref read);Release(ref uav);Release(ref buf);Release(ref code);Release(ref err);Release(ref dev);}
 }
}
'@ -ErrorAction Stop
            }
            $budget=0L
            if ($kind -eq 'RAM') {
                $memory=[NexDash.Bench274]::Memory();$reserve=[Math]::Max([double](3GB),[double]$memory[0]*0.15)
                $safe=[Math]::Max(0.0,([double]$memory[1]-$reserve));$requested=if ($task.RamChoice -eq 'Max') {$safe} else {[double]::Parse([string]$task.RamChoice,[Globalization.CultureInfo]::InvariantCulture)*1GB}
                $budget=[long][Math]::Min($safe,$requested);$task.Budget=$budget
            } elseif ($kind -eq 'GPU') {$budget=if ($task.VramChoice -eq 'Max') {-1L} else {[long]([double]::Parse([string]$task.VramChoice,[Globalization.CultureInfo]::InvariantCulture)*1GB)}}
            $bench=[NexDash.Bench274]::new();$process=[Diagnostics.Process]::GetCurrentProcess()
            $lastCpu=$process.TotalProcessorTime.TotalSeconds
            if ($task.Cancel) {throw [OperationCanceledException]::new()}
            $started=Get-Date;$watch.Start();$bench.Start($kind,$budget,$seconds,$task);$task.Workers=$bench.Workers;$task.Ready=$true
            $nv=$null;if ($kind -eq 'GPU') {
                $nv=Get-Command nvidia-smi.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $nv) {foreach ($candidate in @("$env:SystemRoot\System32\nvidia-smi.exe","$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe")) {if (Test-Path -LiteralPath $candidate -PathType Leaf) {$nv=[pscustomobject]@{Source=$candidate};break}}}
            }
            while (-not $task.Cancel -and $watch.Elapsed.TotalSeconds -lt $seconds -and $bench.Running) {
                Start-Sleep -Milliseconds 100
                $elapsed=$watch.Elapsed.TotalSeconds;$task.Elapsed=[Math]::Min([double]$seconds,[double]$elapsed);$task.Errors=$bench.Errors;$task.Allocated=$bench.Allocated;$peakAlloc=[Math]::Max([long]$peakAlloc,[long]$bench.PeakAllocated)
                $task.Adapter=$bench.Adapter;$task.Units=$bench.Units;if ($kind -eq 'GPU') {$task.VramAllocated=$bench.Allocated}
                if ($elapsed-$lastSample -lt 0.75) {continue}
                $dt=$elapsed-$lastSample;$load=$null;$bytes=$bench.Bytes;$units=$bench.Units;$rate=if ($kind -eq 'GPU') {($units-$lastUnits)/$dt} else {($bytes-$lastBytes)/1MB/$dt}
                $peakRate=[Math]::Max($peakRate,$rate);$task.Rate=$rate;$task.PeakRate=$peakRate
                if ($kind -eq 'CPU') {$process.Refresh();$cpu=$process.TotalProcessorTime.TotalSeconds;$load=100.0*($cpu-$lastCpu)/($dt*[Environment]::ProcessorCount);$lastCpu=$cpu}
                elseif ($kind -eq 'RAM') {$mem=[NexDash.Bench274]::Memory();if ($mem[0] -gt 0) {$load=100.0*(1-$mem[1]/[double]$mem[0]);$used=($mem[0]-$mem[1])/1GB;if ($null -eq $peakMemory -or $used -gt $peakMemory) {$peakMemory=$used}}}
                else {
                    # These system counters are supplemental; the shader itself runs on the named hardware adapter.
                    if ($nv -and $bench.Adapter -match 'NVIDIA') {
                        $p=$null;try {
                            $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName=$nv.Source;$psi.Arguments='--query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits';$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
                            $p=[Diagnostics.Process]::Start($psi);$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
                            if ($p.WaitForExit(900) -and $p.ExitCode -eq 0 -and $stdout.Wait(100)) {
                                foreach ($line in ($stdout.Result -split '\r?\n')) {
                                    $f=$line -split ',\s*';if ($f.Count -ne 5) {continue}
                                    $normalize={param($name) ([string]$name -replace '[^a-zA-Z0-9]','').ToLowerInvariant() -replace 'nvidia|geforce',''}
                                    $actual=& $normalize $bench.Adapter;$sensor=& $normalize $f[0]
                                    if (-not $actual -or $actual -ne $sensor) {continue}
                                    if ($f[1].Trim() -match '^\d+$') {$temp=[double]$f[1];if ($temp -le 150 -and ($null -eq $peakTemp -or $temp -gt $peakTemp)) {$peakTemp=$temp;$task.PeakTemp=$temp}}
                                    if ($f[2].Trim() -match '^\d+$') {$load=[double]$f[2]}
                                    if ($f[3].Trim() -match '^\d+$') {$used=[double]$f[3];if ($null -eq $peakVram -or $used -gt $peakVram) {$peakVram=$used;$task.PeakVram=$used}}
                                    if ($f[4].Trim() -match '^\d+$') {$vramTotal=[double]$f[4];$task.VramTotal=$vramTotal};break
                                }
                            }
                        } catch {} finally {if ($p) {try {if (-not $p.HasExited) {$p.Kill()}} catch {};$p.Dispose()}}
                    }
                    if ($null -eq $load -and -not $task.Cancel) {try {$engines=@(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -Filter "Name LIKE 'pid_$($process.Id)_%'" -OperationTimeoutSec 2 -ErrorAction Stop);if ($engines.Count) {$load=($engines | Measure-Object UtilizationPercentage -Maximum).Maximum}} catch {}}
                    if ($null -ne $peakTemp -and $peakTemp -ge 85) {$status='Stopped';$detail='GPU temperature limit reached.';break}
                }
                if ($null -ne $load) {$samples++;$load=[Math]::Min(100.0,[Math]::Max(0.0,[double]$load));$task.Load=$load;if ($null -eq $peakLoad -or $load -gt $peakLoad) {$peakLoad=$load};$task.PeakLoad=$peakLoad}
                $lastSample=$elapsed;$lastBytes=$bytes;$lastUnits=$units;$task.Samples=$samples
            }
        } catch {if (-not $task.Cancel) {$errors++;$status='Failed';$detail=$_.Exception.Message}}
        finally {if ($bench) {$peakAlloc=[Math]::Max([long]$peakAlloc,[long]$bench.PeakAllocated);$bench.Dispose();$bytes=$bench.Bytes;$units=$bench.Units;$errors+=$bench.Errors;$adapter=$bench.Adapter;if ($bench.Failure) {$detail=$bench.Failure}};if ($process) {$process.Dispose()};$watch.Stop()}
        if ($task.Cancel) {$status='Cancelled'} elseif ($errors) {$status='Failed'} elseif ($units -eq 0 -and $status -eq 'Complete') {$status='Unavailable';$detail='No workload completed.'} elseif ($status -eq 'Complete' -and $watch.Elapsed.TotalSeconds -lt ($seconds-0.7)) {$status='Stopped';$detail='The workload stopped before the selected duration.'}
        $elapsed=[Math]::Min([double]$seconds,$watch.Elapsed.TotalSeconds);$events=$null
        if ($task.Ready) {try {$events=@(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WHEA-Logger';StartTime=$started} -ErrorAction Stop).Count} catch {if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {$events=0}}}
        [pscustomobject]@{Kind=$kind;Status=$status;Detail=$detail;Elapsed=$elapsed;Samples=$samples;Errors=$errors;PeakLoad=$peakLoad;PeakTemperature=$peakTemp;PeakMemory=$peakMemory;PeakVram=$peakVram;VramTotal=$vramTotal;Budget=$task.Budget;PeakRate=$peakRate;AverageRate=$(if ($elapsed -gt 0) {if ($kind -eq 'GPU') {$units/$elapsed} else {$bytes/1MB/$elapsed}} else {$null});Bytes=$bytes;Events=$events;Units=$units;Workers=$task.Workers;Allocated=$peakAlloc;Adapter=$adapter}
    }
    function StartNexLargeScan {
        if ($s.Job -or $s.ScanActive) {Notice 'A background task is busy. Try again shortly.';return}
        $root=Get-Item -LiteralPath $s.DiskRoot -ErrorAction Stop
        if (-not $root.PSIsContainer -or $root.PSProvider.Name -ne 'FileSystem' -or ($root.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Folder is unavailable or is a link.'}
        $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($root.FullName))
        if ($drive.DriveType -ne [IO.DriveType]::Fixed) {throw 'Only local fixed drives are supported.'}
        $s.DiskReport=$null;$s.ExtraPos=0
        $s.Task=[hashtable]::Synchronized(@{Type='large-scan';Root=$root.FullName;Cancel=$false;Count=0;Skipped=0;Start=$clock.ElapsedMilliseconds})
        StartWorker 'large-scan' $largeScanScript $s.Task
        if (-not $s.Job) {$s.Task=$null}
    }
    function StartNexBench {
        if ($s.Job -or $s.ScanActive) {Notice 'A background task is busy. Try again shortly.';return}
        $s.TaskReport=$null;$s.ExtraPos=0
        $s.Task=[hashtable]::Synchronized(@{Type='benchmark';TestKind=$s.BenchKind;Seconds=$s.BenchSeconds;RamChoice=$s.BenchRam;VramChoice=$s.BenchVram;Budget=0L;VramAllocated=0L;PeakVram=$null;VramTotal=$null;Cancel=$false;Elapsed=0.0;Rate=0.0;PeakRate=0.0;Load=$null;PeakLoad=$null;Samples=0;Errors=0;PeakTemp=$null;Ready=$false;Workers=0;Allocated=0L;Units=0L;Adapter='';Start=$clock.ElapsedMilliseconds})
        StartWorker 'benchmark' $benchScript $s.Task
        if (-not $s.Job) {$s.Task=$null}
    }
    function ChooseNexScanFolder {
        $current=$s.DiskRoot
        if (-not (Test-Path -LiteralPath $current -PathType Container)) {$current=$HOME}
        $drives=$false;$problem=''
        :folderPicker while ($true) {
            $labels=New-Object 'System.Collections.Generic.List[string]';$values=New-Object 'System.Collections.Generic.List[string]'
            if ($drives) {
                foreach ($drive in [IO.DriveInfo]::GetDrives()) {try {if ($drive.DriveType -eq [IO.DriveType]::Fixed -and $drive.IsReady) {$labels.Add("$(Icon 0xF0A0) $($drive.Name) $($drive.VolumeLabel)");$values.Add($drive.Name)}} catch {}}
                $labels.Add((NexL 'Back'));$values.Add('@back')
            } else {
                $labels.Add("$(Icon 0xF00C) $(NexL 'Use this folder')");$values.Add('@use')
                $labels.Add("$(Icon 0xF062) $(NexL 'Parent folder')");$values.Add('@parent')
                $labels.Add("$(Icon 0xF0A0) $(NexL 'Drives')");$values.Add('@drives')
                $labels.Add("$(Icon 0xF040) $(NexL 'Enter folder path')");$values.Add('@path')
                try {foreach ($dir in @(Get-ChildItem -LiteralPath $current -Directory -ErrorAction Stop | Where-Object {-not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)} | Select-Object -First 250 | Sort-Object Name)) {$labels.Add("$(Icon 0xF07B) $(SafeText $dir.Name)");$values.Add($dir.FullName)}} catch {}
            }
            $title=if ($drives) {'Drives'} else {"$(NexL 'Choose scan folder'): $(SafeText $current)"}
            $help=if ($problem) {$problem} else {'Choose a folder or type its full path.'};$problem=''
            $v=Ask $title ($labels.ToArray()) ($values.ToArray()) $values[0] $help
            if (-not $v) {return $null}
            switch ($v) {
                '@use' {return $current}
                '@back' {$drives=$false;continue folderPicker}
                '@drives' {$drives=$true;continue folderPicker}
                '@parent' {$parent=[IO.Directory]::GetParent($current);if ($parent) {$current=$parent.FullName} else {$drives=$true};continue folderPicker}
                '@path' {$v=Ask 'Folder path';if (-not $v) {continue folderPicker}}
            }
            try {
                $item=Get-Item -LiteralPath $v.Trim('"') -ErrorAction Stop
                if (-not $item.PSIsContainer -or $item.PSProvider.Name -ne 'FileSystem' -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Invalid folder.'}
                $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($item.FullName));if ($drive.DriveType -ne [IO.DriveType]::Fixed) {throw 'Only local fixed drives are supported.'}
                $current=$item.FullName;$drives=$false
            } catch {$problem=$_.Exception.Message}
        }
    }
    function NewTaskAction($key) {
        if ($key -eq 'K' -and $s.Task) {if (($s.Page -eq 21 -and $s.Task.Type -eq 'benchmark') -or ($s.Page -eq 22 -and $s.Task.Type -eq 'large-scan')) {$s.Task.Cancel=$true};return}
        if ($s.Page -eq 21) {
            if ($s.Task) {return}
            switch ($key) {
                'C' {$kinds=@('CPU','RAM','GPU');$v=Ask 'Choose test' @((NexL 'CPU multi-thread test'),(NexL 'RAM bandwidth test'),(NexL 'GPU compute test')) $kinds $s.BenchKind;if ($v -in $kinds) {$s.BenchKind=$v}}
                'D' {$dur=@('5','10','20','30');$v=Ask 'Choose duration' @($dur | ForEach-Object {$_+' s'}) $dur ([string]$s.BenchSeconds);if ($v -in $dur) {$s.BenchSeconds=[int]$v}}
                'M' {
                    if ($s.BenchKind -notin @('RAM','GPU')) {return}
                    $isRam=$s.BenchKind -eq 'RAM';$current=if ($isRam) {$s.BenchRam} else {$s.BenchVram}
                    $choices=if ($isRam) {@('4','Max','Custom')} else {@('1','2','4','Max','Custom')}
                    $labels=@(foreach ($choice in $choices) {if ($choice -eq 'Max') {NexL 'Maximum safe available'} elseif ($choice -eq 'Custom') {NexL 'Custom GiB'} else {$choice+' GiB'}})
                    $v=Ask 'Choose memory amount' $labels $choices $current
                    if ($v -eq 'Custom') {
                        $raw=Ask 'Enter memory amount in GiB';$g=0.0
                        if (-not [double]::TryParse(([string]$raw).Replace(',','.'),[Globalization.NumberStyles]::AllowDecimalPoint,[Globalization.CultureInfo]::InvariantCulture,[ref]$g) -or $g -lt 0.25 -or $g -gt 1024) {if ($raw) {Notice 'Invalid memory amount.'};return}
                        $v=$g.ToString([Globalization.CultureInfo]::InvariantCulture)
                    }
                    if ($v) {if ($isRam) {$s.BenchRam=$v} else {$s.BenchVram=$v}}
                }
                'S' {StartNexBench}
            }
        } elseif ($s.Page -eq 22) {
            if ($s.Task) {return}
            if ($key -eq 'P') {$p=ChooseNexScanFolder;if ($p) {$s.DiskRoot=$p;$s.DiskReport=$null;$s.ExtraPos=0};return}
            if ($key -eq 'S') {StartNexLargeScan;return}
            if ([string]$key -match '^result:(file|folder):(\d+)$' -and $s.DiskReport) {
                $kind=$Matches[1];$idx=[int]$Matches[2];$list=if ($kind -eq 'file') {@($s.DiskReport.Files)} else {@($s.DiskReport.Folders)}
                $list=@($list);if ($idx -lt 0 -or $idx -ge $list.Count) {return}
                $path=$list[$idx].Path;$folder=if ($kind -eq 'file') {[IO.Path]::GetDirectoryName($path)} else {$path}
                if (Test-Path -LiteralPath $folder -PathType Container) {ChoosePage 4;GoFolder $folder;if ($kind -eq 'file') {for ($i=0;$i -lt $s.FileItems.Count;$i++) {if ($s.FileItems[$i].FullName -eq $path) {$s.Pos=$i;break}}}}
            }
        }
    }
    function RenderNexTaskPage($body,$bodyHits) {
        function TaskButton($key,$label,$icon,[bool]$enabled=$true) {
            if ($enabled) {$bodyHits[$body.Count]=@{Kind='extra';Index=$key}}
            $tone=if ($enabled) {$purple} else {$muted};$body.Add("$tone[$key] $(Icon $icon) $(NexL $label)$reset")
        }
        function TaskLine($name,$value) {$body.Add((Label $name $(if ($null -eq $value) {NexL 'Unavailable'} else {$value})))}
        function TaskNote($key) {foreach ($line in @(WrapUpdateLine (NexL $key) $rightWidth)) {$body.Add("$gray$line$reset")}}
        if ($s.Page -eq 21) {
            $body.Add("$pink$(Icon 0xF080)  $(NexL 'Benchmark Center')$reset");$body.Add('')
            TaskButton 'C' 'Choose test' 0xF2DB (-not $s.Task);$kindLabel=@{CPU='CPU multi-thread test';RAM='RAM bandwidth test';GPU='GPU compute test'}[$s.BenchKind];TaskLine 'Test type' (NexL $kindLabel)
            TaskButton 'D' 'Choose duration' 0xF017 (-not $s.Task);TaskLine 'Test duration' ($s.BenchSeconds.ToString()+' s')
            if ($s.BenchKind -in @('RAM','GPU')) {
                TaskButton 'M' 'Choose memory amount' 0xEFC5 (-not $s.Task)
                $amount=if ($s.BenchKind -eq 'RAM') {$s.BenchRam} else {$s.BenchVram};TaskLine 'Requested memory' $(if ($amount -eq 'Max') {NexL 'Maximum safe available'} else {$amount+' GiB'})
            }
            if ($s.BenchKind -eq 'GPU') {TaskNote 'GPU: compute and sampled VRAM readback within the DXGI budget.'} elseif ($s.BenchKind -eq 'RAM') {TaskNote 'RAM: parallel copies; Windows memory reserve is always kept.'} else {TaskNote 'CPU: parallel SHA-256 workload on logical processors.'}
            TaskNote 'Not a full stability test.';$body.Add('')
            TaskButton 'S' 'Start test' 0xF04B (-not $s.Task);TaskButton 'K' 'Cancel task' 0xF04D ([bool]$s.Task -and $s.Task.Type -eq 'benchmark')
            $body.Add("$muted$('─'*[Math]::Min(60,$rightWidth-1))$reset")
            if ($s.Task -and $s.Task.Type -eq 'benchmark') {
                $t=$s.Task;$left=[Math]::Max(0,$t.Seconds-[Math]::Floor($t.Elapsed));$pct=100*$t.Elapsed/$t.Seconds
                $body.Add("$green$(Bar $pct ([Math]::Min(25,[Math]::Max(8,$rightWidth-20)))) $white$left s$reset")
                TaskLine 'Status' $(if ($t.Cancel) {NexL 'Cancelled'} elseif (-not $t.Ready) {NexL 'Preparing test'} else {NexL 'Checking'})
                if ($t.TestKind -eq 'GPU') {TaskLine 'Graphics adapter' $(if ($t.Adapter) {$t.Adapter});TaskLine 'Peak dispatch rate' ('{0:0.0} /s' -f $t.PeakRate);TaskLine 'Completed workloads' $t.Units} else {TaskLine 'Worker threads' $t.Workers}
                if ($t.TestKind -eq 'RAM') {TaskLine 'Test memory allocated' ('{0:0.00} / {1:0.00} GiB' -f ($t.Allocated/1GB),($t.Budget/1GB))}
                if ($t.TestKind -eq 'GPU') {TaskLine 'Test VRAM allocated' ('{0:0.00} GiB' -f ($t.VramAllocated/1GB));TaskLine 'Peak VRAM usage' $(if ($null -ne $t.PeakVram) {'{0:0.00} GiB' -f ($t.PeakVram/1024)})}
                if ($t.TestKind -ne 'GPU') {TaskLine 'Peak throughput' ('{0:0.0} MiB/s' -f $t.PeakRate)}
                TaskLine 'Peak load' $(if ($null -ne $t.PeakLoad) {'{0:0.0} %' -f $t.PeakLoad});if ($t.TestKind -eq 'GPU') {TaskLine 'Peak temperature' $(if ($null -ne $t.PeakTemp) {'{0:0} °C' -f $t.PeakTemp})}
                TaskLine 'Errors detected' $t.Errors;TaskLine 'Measurement samples' $t.Samples
            } elseif ($s.TaskReport) {
                $r=$s.TaskReport;$body.Add("$pink$(Icon 0xF15C) $(NexL 'Test report')$reset")
                TaskLine 'Test type' $r.Kind;TaskLine 'Status' (NexL $r.Status);TaskLine 'Elapsed' ('{0:0.0} s' -f $r.Elapsed)
                if ($r.Kind -eq 'GPU') {TaskLine 'Graphics adapter' $(if ($r.Adapter) {$r.Adapter});TaskLine 'Peak dispatch rate' ('{0:0.0} /s' -f $r.PeakRate);TaskLine 'Average dispatch rate' $(if ($null -ne $r.AverageRate) {'{0:0.0} /s' -f $r.AverageRate});TaskLine 'Completed workloads' $r.Units} else {TaskLine 'Worker threads' $r.Workers}
                if ($r.Kind -eq 'RAM') {TaskLine 'Test memory allocated' ('{0:0.00} / {1:0.00} GiB' -f ($r.Allocated/1GB),($r.Budget/1GB))}
                if ($r.Kind -eq 'GPU') {TaskLine 'Test VRAM allocated' ('{0:0.00} GiB' -f ($r.Allocated/1GB));TaskLine 'Peak VRAM usage' $(if ($null -ne $r.PeakVram) {'{0:0.00} GiB' -f ($r.PeakVram/1024)});TaskLine 'Total VRAM' $(if ($null -ne $r.VramTotal) {'{0:0.00} GiB' -f ($r.VramTotal/1024)})}
                if ($r.Kind -ne 'GPU') {TaskLine 'Average throughput' $(if ($null -ne $r.AverageRate) {'{0:0.0} MiB/s' -f $r.AverageRate});TaskLine 'Peak throughput' ('{0:0.0} MiB/s' -f $r.PeakRate);TaskLine 'Data size' ('{0:0.0} MiB' -f ($r.Bytes/1MB))}
                TaskLine 'Peak load' $(if ($null -ne $r.PeakLoad) {'{0:0.0} %' -f $r.PeakLoad});if ($r.Kind -eq 'GPU') {TaskLine 'Peak temperature' $(if ($null -ne $r.PeakTemperature) {'{0:0} °C' -f $r.PeakTemperature})};if ($r.Kind -eq 'RAM') {TaskLine 'Peak memory usage' $(if ($null -ne $r.PeakMemory) {'{0:0.0} GiB' -f $r.PeakMemory})}
                TaskLine 'Measurement samples' $r.Samples;TaskLine 'Errors detected' $r.Errors;TaskLine 'Hardware event count' $r.Events
                if ($r.Detail) {TaskNote $r.Detail};TaskNote 'Test score is not a hardware rating.'
            } else {TaskNote 'No test yet'}
        } else {
            $body.Add("$pink$(Icon 0xF002)  $(NexL 'Large files and folders')$reset");$body.Add('')
            $body.Add("$gray$(NexL 'Search root')$reset  $white$(SafeText $s.DiskRoot)$reset")
            TaskButton 'P' 'Choose scan folder' 0xF07B (-not $s.Task);TaskButton 'S' 'Scan current folder' 0xF002 (-not $s.Task);TaskButton 'K' 'Cancel task' 0xF04D ([bool]$s.Task -and $s.Task.Type -eq 'large-scan')
            TaskNote 'Scan is read-only; links and inaccessible items are skipped.';TaskNote 'Search time limit: 90 seconds; up to 100,000 items.';$body.Add('')
            if ($s.Task -and $s.Task.Type -eq 'large-scan') {TaskLine 'Elapsed' ('{0:0} s' -f (($clock.ElapsedMilliseconds-$s.Task.Start)/1000));TaskLine 'Scanned items' $s.Task.Count;TaskLine 'Skipped items' $s.Task.Skipped}
            elseif ($s.DiskReport) {
                $r=$s.DiskReport;TaskLine 'Status' (NexL $(if ($r.Cancelled) {'Cancelled'} elseif ($r.Partial) {'Partial results'} else {'Complete'}));TaskLine 'Scanned items' $r.Count;TaskLine 'Skipped items' $r.Skipped;TaskLine 'Data size' ('{0:0.00} GiB' -f ($r.Bytes/1GB));TaskNote 'Folder sizes are logical and may count hard links twice.'
                foreach ($kind in @('file','folder')) {
                    $body.Add('');$title=if ($kind -eq 'file') {'Largest files'} else {'Largest folders'};$body.Add("$pink$(Icon $(if ($kind -eq 'file') {0xF15B} else {0xF07B})) $(NexL $title)$reset")
                    $list=if ($kind -eq 'file') {@($r.Files)} else {@($r.Folders)};$list=@($list)
                    if (-not $list.Count) {TaskNote 'No results'}
                    for ($i=0;$i -lt $list.Count;$i++) {$item=$list[$i];$bodyHits[$body.Count]=@{Kind='extra';Index="result:${kind}:$i"};$size=if ($item.Bytes -ge 1GB) {'{0:0.00} GiB' -f ($item.Bytes/1GB)} else {'{0:0.0} MiB' -f ($item.Bytes/1MB)};$body.Add("$purple$(Fit $size 13)$white$(SafeText $item.Path)$reset")}
                }
            } else {TaskNote 'No scan yet'}
        }
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
                'large-scan' {if ($out.Count) {$s.DiskReport=$out[-1]};$s.Task=$null}
                'benchmark' {if ($out.Count) {$s.TaskReport=$out[-1]};$s.Task=$null}
                'diagnostic' {if ($out.Count) {$s.ScanResults[[string]$s.JobArg]=$out[-1]} else {$s.ScanResults[[string]$s.JobArg]=[pscustomobject]@{State='Unknown';Detail='No data returned.';Action=''}};$s.ScanIndex++}
                'process-metrics' {if ($out.Count) {$s.ProcMetrics=$out[-1];$s.ProcMetricsAt=$clock.ElapsedMilliseconds}}
                'hardware' {$s.Hardware=@($out)}
                'gaming' {if ($s.JobStart -le $s.GameChangedAt) {$s.Next=0L} elseif ($out.Count) {$s.Game=$out[-1]}}
                'apps' {$s.Apps=@($out)}
                'startup' {$s.StartupRows=@($out);$s.StartupAt=Get-Date}
                'health' {if ($out.Count) {$s.Health=$out[-1]; FilterNexHealthEvents; UpdateNexAlerts}}
                'release' {
                    if ($out.Count) {SetNexReleaseResult $out[-1];$s.OnlineReady=$s.OnlineRequested}
                    $s.ReleaseFinishAt=$clock.ElapsedMilliseconds;$s.OnlineRequested=$false
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
            if ($s.JobKind -in @('benchmark','large-scan')) {$s.Task=$null}
            if ($s.JobKind -eq 'diagnostic') {$s.ScanResults[[string]$s.JobArg]=[pscustomobject]@{State='Unknown';Detail=$_.Exception.Message;Action=''};$s.ScanIndex++}
            if ($s.JobKind -eq 'release') {$s.ReleaseFinishAt=$clock.ElapsedMilliseconds}
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
    function ResetSpeedtestConsent {
        if ($s.SpeedProc) {StopSpeedTest}
        try {
            $file=Get-NexOoklaConsentPath
            if (Test-Path -LiteralPath $file) {Remove-Item -LiteralPath $file -Force -ErrorAction Stop}
            $s.SpeedConsentHash='';$s.SpeedStatus='Ready';$s.Need=$true
            Notice 'Ookla consent reset.'
        } catch {Notice $_.Exception.Message}
    }
    function StartSpeedTest {
        if ($s.SpeedProc -or $s.SpeedInstallPending -or ($s.Job -and $s.JobKind -eq 'speed-install')) {return}
        $path=Get-NexSpeedtest;$s.SpeedPath=$path
        if (-not $path) {RequestSpeedtestInstall;return}
        # Remember only explicit acceptance, tied to the exact CLI binary and terms revision.
        try {$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash}
        catch {Notice $_.Exception.Message;return}
        if ($s.SpeedConsentHash -ne $hash -and -not (Test-NexOoklaConsent $hash)) {
            if (-not (ConfirmNex 'Accept Ookla terms for personal use?' 'https://www.speedtest.net/about/eula' 'https://www.speedtest.net/about/terms')) {return}
            if (-not (ConfirmNex 'Accept Ookla privacy notice?' 'https://www.speedtest.net/about/privacy' 'A test sends connection data to Ookla.')) {return}
            try {Save-NexOoklaConsent $hash} catch {Notice $_.Exception.Message}
        }
        $s.SpeedConsentHash=$hash
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
        $gpu=@{};$gpuKnown=$false
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
        [pscustomobject]@{GPU=$gpu;GPUKnown=$gpuKnown}
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
                $gpu=$null
                if ($s.ProcMetrics -and ($now-$s.ProcMetricsAt) -lt 10000) {
                    $m=$s.ProcMetrics
                    if ($m.GPUKnown -and $m.GPU.ContainsKey($id)) {$gpu=$m.GPU[$id]}
                }
                $rows+=@{Id=$p.Id;Name=$p.ProcessName;RAM=$p.WorkingSet64/1MB;CPU=$used;GPU=$gpu}
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
    function ExplorerBreadcrumb([int]$width) {
        $targets=@();$text='';$x=0
        $inputLabel='[P] '+(NexL 'Enter path')
        if ((Get-NexLogoWidth $inputLabel) -gt [Math]::Max(3,[int]($width/3))) {$inputLabel='[P]'}
        $inputWidth=Get-NexLogoWidth $inputLabel
        $text=$purple+$inputLabel+$reset;$targets+=@{Kind='fileAction';Index='P';From=0;To=$inputWidth};$x=$inputWidth+3;$text+="$muted │ $reset"
        if ($s.Drives) {return @{Text=($text+$purple+(NexL 'This PC / Drives')+$reset);Kind='buttons';Targets=$targets}}
        $parts=[Collections.Generic.List[object]]::new();$dir=[IO.DirectoryInfo]::new($s.Folder)
        while ($dir) {
            $name=if ($dir.Parent) {$dir.Name} else {$dir.FullName}
            $parts.Insert(0,@{Name=(SafeText $name);Path=$dir.FullName});$dir=$dir.Parent
        }
        $available=[Math]::Max(0,$width-1-$x)
        $total=0;foreach ($part in $parts) {$total+=(Get-NexLogoWidth $part.Name)+3};$total-=3
        $show=@($parts.ToArray());$collapsed=$false
        if ($total -gt $available -and $parts.Count -gt 1) {
            $show=@();$remaining=$available-4
            for ($pi=$parts.Count-1;$pi -ge 0;$pi--) {
                $partWidth=(Get-NexLogoWidth $parts[$pi].Name)+$(if ($show.Count) {3} else {0})
                if ($partWidth -gt $remaining -and $show.Count) {break}
                if ($partWidth -gt $remaining) {$show=@($parts[$pi]);break}
                $show=@($parts[$pi])+@($show);$remaining-=$partWidth
            }
            $collapsed=$true
        }
        if ($collapsed -and $available -ge 4) {
            $text+="$purple…$reset$muted › $reset";$targets+=@{Kind='fileParents';Index=0;From=$x;To=$x+1};$x+=4
        }
        for ($pi=0;$pi -lt $show.Count;$pi++) {
            if ($pi) {$text+="$muted › $reset";$x+=3}
            $remaining=[Math]::Max(0,$width-1-$x);if (-not $remaining) {break}
            $part=$show[$pi];$label=$part.Name
            if ((Get-NexLogoWidth $label) -gt $remaining) {
                while ($label.Length -and (Get-NexLogoWidth $label) -gt [Math]::Max(0,$remaining-1)) {
                    $label=$label.Substring(0,$label.Length-1);if ($label.Length -and [char]::IsHighSurrogate($label[$label.Length-1])) {$label=$label.Substring(0,$label.Length-1)}
                };$label+='…'
            }
            $partStyle=if ($part.Path -ieq $s.Folder) {$pink} else {$purple}
            $partWidth=Get-NexLogoWidth $label;$text+=$partStyle+$label+$reset
            $targets+=@{Kind='fileCrumb';Index=$part.Path;From=$x;To=$x+$partWidth};$x+=$partWidth
        }
        return @{Text=$text;Kind='buttons';Targets=$targets}
    }
    function ParentFolder {
        if ($s.Drives) { $s.Drives=$false; $s.Pos=0; RefreshFiles; return }
        $p=[IO.Directory]::GetParent($s.Folder)
        if ($p) { GoFolder $p.FullName } else { $s.Drives=$true; $s.Pos=0; $s.FileItems=@(); RefreshFiles }
    }
    $textExtensions=@(Get-NexEditorExtensions)
    function RenameFullName([string]$stem,[string]$suffix) {
        $stem=$stem.Trim()
        if (-not $stem) {return ''}
        if ($suffix -and $stem.EndsWith($suffix,[StringComparison]::OrdinalIgnoreCase)) {$stem=$stem.Substring(0,$stem.Length-$suffix.Length)}
        if (-not $stem -or $stem -in @('.','..') -or $stem.EndsWith('.') -or $stem.EndsWith(' ')) {return ''}
        return ($stem+$suffix)
    }
    function FileNameValid([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name) -or $name -in @('.','..') -or $name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $name.EndsWith('.') -or $name.EndsWith(' ') -or $name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { throw 'Invalid file name.' }
    }
    function ConfirmNex([string]$title,[string]$detail,[string]$note) {
        try {
            $choice=1
            while ($true) {
                $w=[Console]::WindowWidth; $h=[Console]::WindowHeight
                if ($w -lt 32 -or $h -lt 10) {
                    Write-Host "$reset$e[2J$e[H$pink $(NexL 'Enlarge the window or press Esc.')$reset" -NoNewline
                    $ev=WaitNexEvent; if ($ev.Key -eq 'Escape') { return $false }; continue
                }
                $inner=[Math]::Min(64,$w-4)
                $x=[Math]::Max(1,[int][Math]::Floor(($w-$inner-2)/2)+1); $y=[Math]::Max(1,[int][Math]::Floor(($h-8)/2)+1)
                $a=if ($choice -eq 0) {"$bg$red"} else {$red}; $b=if ($choice -eq 1) {"$bg$pink"} else {$gray}
                $yes='[ '+(NexL 'Confirm')+' ]'; $no='[ '+(NexL 'Cancel')+' ]'; $action='  '+$yes+'  '+$no
                $lines=@("$pink╭$('─'*$inner)╮$reset", "$pink│$reset$red$(Fit ('  '+(NexL $title)) $inner)$pink│$reset", "$pink│$reset$white$(Fit ('  '+$detail) $inner)$pink│$reset", "$pink│$reset$gray$(Fit ('  '+(NexL $note)) $inner)$pink│$reset", "$pink│$(' '*$inner)│$reset", "$pink│$reset  $a$yes$reset  $b$no$reset$(' '*[Math]::Max(0,$inner-$action.Length))$pink│$reset", "$pink╰$('─'*$inner)╯$reset", "$gray  $(NexL 'Click / Left / Right / Enter / Esc')$reset")
                $frame="$reset$e[2J$e[?25l"
                for ($j=0;$j -lt $lines.Count -and $y+$j -le $h;$j++) { $frame+="$e[$($y+$j);${x}H$reset$(ClipAnsi $lines[$j] ($w-$x+1))" }
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
        function NewEditorDocument($file,[bool]$logo=$false) {
            $path=$null;$base64=$null;$encoding=$null
            if ($logo) {
                $item=[pscustomobject]@{Name=(NexL 'Custom logo')};$text=[string]$prefs.CustomLogo
            } else {
                $item=Get-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                if ($item.PSProvider.Name -ne 'FileSystem' -or $item.PSIsContainer -or $item.Extension -notin $textExtensions) {throw (NexL 'Select a supported text file.')}
                if ($item.Length -gt 262144) {throw (NexL 'Editor limit: 256 KiB. Use external editor for large files.')}
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw (NexL 'Editing links is not supported.')}
        $path=$item.FullName
            $bytes=[IO.File]::ReadAllBytes($path);if ($bytes.Length -gt 262144) {throw (NexL 'Editor limit: 256 KiB. Use external editor for large files.')};$base64=[Convert]::ToBase64String($bytes)
            $encoding=[Text.UTF8Encoding]::new($false,$true); $skip=0
            if ($bytes.Length -ge 4 -and (($bytes[0] -eq 255 -and $bytes[1] -eq 254 -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) -or ($bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 254 -and $bytes[3] -eq 255))) { throw 'UTF-32 is not supported by this editor.' }
            if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { $encoding=[Text.UTF8Encoding]::new($true,$true); $skip=3 }
            elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) { $encoding=[Text.UnicodeEncoding]::new($false,$true,$true); $skip=2 }
            elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 254 -and $bytes[1] -eq 255) { $encoding=[Text.UnicodeEncoding]::new($true,$true,$true); $skip=2 }
            $text=$encoding.GetString($bytes,$skip,$bytes.Length-$skip)
            if ($text -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') { throw 'Binary/control data is not supported.' }
            }
            $nl=if ($text.Contains("`r`n")) {"`r`n"} elseif ($text.Contains("`r")) {"`r"} elseif ($text.Contains("`n")) {"`n"} else {[Environment]::NewLine}
            $buf=[Collections.Generic.List[string]]::new()
            foreach ($line in ($text -split '\r\n|\n|\r')) {$buf.Add([string]$line)}
            if (-not $buf.Count) {$buf.Add('')}
            return @{item=$item;path=$path;base64=$base64;encoding=$encoding;nl=$nl;buf=$buf;r=0;col=0;top=0;left=0;dirty=$false;detachedScroll=$false;selection=@{Row=-1;Col=0;Dragging=$false};history=[Collections.Generic.List[object]]::new();historyState=@{Chars=0L;RedoChars=0L;Redo=[Collections.Generic.List[object]]::new();Saved=($buf -join "`n")};find=@{Active=$false;Query='';Rows=@{};Ordered=@();Total=0;Index=-1;Row=-1;Col=-1}}
        }
        try {$initialDoc=NewEditorDocument $item ([bool]$LogoMode)} catch {Notice ('Editor: '+$_.Exception.Message);return}
        $editorTabs=[Collections.Generic.List[object]]::new();$editorTabs.Add($initialDoc);$activeTab=0
        $docKeys=@('item','path','base64','encoding','nl','buf','r','col','top','left','dirty','detachedScroll','selection','history','historyState','find')
        foreach ($docKey in $docKeys) {Set-Variable -Name $docKey -Value $initialDoc[$docKey] -Scope Local}
        function SaveEditorTabState {
            $doc=$editorTabs[$activeTab]
            foreach ($docKey in $docKeys) {$doc[$docKey]=Get-Variable -Name $docKey -ValueOnly -Scope 1}
            $doc.selection.Dragging=$false
        }
        function EditorFilePicker {
            $folder=$item.DirectoryName
            $choices=@(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue | Where-Object {$_.Extension -in $textExtensions -and $_.Length -le 262144 -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)} | Select-Object -First 200)
            $v=Ask 'Open file in tab' @($choices | ForEach-Object {$_.Name}) @($choices | ForEach-Object {$_.FullName}) -helpKey 'Choose a text file or enter its path.'
            if (-not $v) {return $null}
            $v=$v.Trim('"')
            if (-not [IO.Path]::IsPathRooted($v)) {$v=Join-Path $folder $v}
            return (Get-Item -LiteralPath $v -Force -ErrorAction Stop)
        }
        # Local, language-specific completions; no code execution or network requests.
        $editorCompletionWords=@{
            '.py'='print property range enumerate len list dict set tuple str int float bool bytes bytearray type isinstance issubclass super object input open abs all any bin chr ord divmod filter format getattr hasattr setattr delattr globals locals hex iter map max min next oct pow repr reversed round sorted sum vars zip callable compile staticmethod classmethod Exception ValueError TypeError RuntimeError ImportError FileNotFoundError True False None import from as def class return yield if elif else for while in is not and or break continue pass try except finally raise with lambda async await assert del global nonlocal'
            '.ps1'='Write-Host Write-Output Write-Error Write-Warning Write-Verbose Get-Item Get-ChildItem Get-Content Set-Content Add-Content Get-Process Get-Service Get-Command Get-Variable Get-Date Get-Location Set-Location Test-Path Join-Path Split-Path Resolve-Path New-Item Remove-Item Copy-Item Move-Item Rename-Item Select-Object Where-Object ForEach-Object Sort-Object Measure-Object Out-File ConvertTo-Json ConvertFrom-Json Import-Csv Export-Csv Start-Process Stop-Process Start-Sleep Invoke-RestMethod Invoke-WebRequest Read-Host Set-Variable Clear-Host function param return foreach if elseif else switch while for do try catch finally throw break continue begin process end'
            '.js'='console document window globalThis undefined null true false function return const let var async await import export default class constructor extends super new this if else for while switch case break continue try catch finally throw typeof instanceof delete void fetch Promise Array Object String Number Boolean Math JSON Date Map Set RegExp Error parseInt parseFloat setTimeout setInterval clearTimeout clearInterval addEventListener querySelector querySelectorAll getElementById createElement appendChild textContent innerHTML length push pop map filter reduce forEach find includes stringify parse log warn error'
            '.ts'='interface type implements public private protected readonly abstract declare namespace keyof infer never unknown any string number boolean void enum satisfies'
            '.html'='html head body title meta link script style div span section article header footer main nav button input label form textarea select option table tr td th ul ol li img a href class id src alt type name value placeholder'
            '.xml'='xml version encoding xmlns'
            '.css'='display position relative absolute fixed sticky flex grid block inline none color background background-color border border-radius margin padding width height min-width max-width font-size font-family font-weight line-height text-align align-items justify-content gap overflow opacity transform transition animation box-shadow z-index'
            '.json'='true false null'
            '.yaml'='true false null'
            '.lua'='print pairs ipairs next type tostring tonumber require assert error pcall xpcall select unpack setmetatable getmetatable string table math coroutine local function return end if then else elseif for while repeat until do break nil true false'
            '.sh'='echo printf read export source alias unset local return exit function if then elif else fi for while until do done case esac break continue true false test'
            '.sql'='SELECT FROM WHERE JOIN INNER LEFT RIGHT FULL OUTER ON GROUP BY ORDER HAVING LIMIT OFFSET INSERT INTO VALUES UPDATE SET DELETE CREATE TABLE ALTER DROP INDEX DISTINCT AS AND OR NOT NULL IS EXISTS COUNT SUM AVG MIN MAX UNION CASE WHEN THEN ELSE END'
            '.c'='printf scanf fprintf snprintf puts fgets malloc calloc realloc free sizeof memcpy memset strlen strcmp strcpy fopen fclose fread fwrite int char float double long short unsigned signed void const static extern typedef struct union enum return if else for while do switch case break continue goto include define NULL'
            '.cpp'='std string vector cout cin endl namespace using class public private protected template typename constexpr auto nullptr bool true false new delete virtual override friend explicit noexcept try catch throw include'
            '.cs'='Console WriteLine ReadLine string int bool double float decimal long var object dynamic public private protected internal static readonly const class interface struct enum namespace using new this base async await Task List Dictionary IEnumerable void return if else for foreach while switch case break continue try catch finally throw null true false'
            '.rs'='println print format fn let mut pub struct enum impl trait use mod crate self Self super match if else for while loop break continue return async await move unsafe const static type where dyn ref true false String Vec Option Result Some None Ok Err'
            '.java'='System println print String Integer Boolean Object List ArrayList Map HashMap Set HashSet public private protected static final abstract class interface extends implements package import new this super void int long boolean double float char return if else for while switch case break continue try catch finally throw throws null true false'
            '.bat'='echo set setlocal endlocal call goto exit if else for in do rem pause shift title cls start'
        }
        $editorCompletionWords['.ts']+=' '+$editorCompletionWords['.js']
        $editorCompletionWords['.cpp']+=' '+$editorCompletionWords['.c']
        $editorCompletionWords['.h']=$editorCompletionWords['.cpp'];$editorCompletionWords['.yml']=$editorCompletionWords['.yaml'];$editorCompletionWords['.cmd']=$editorCompletionWords['.bat']
        foreach ($completionExtension in @($editorCompletionWords.Keys)) {$editorCompletionWords[$completionExtension]=@($editorCompletionWords[$completionExtension] -split ' ' | Select-Object -Unique)}
        $editorCompletion=$null
        function GetEditorCompletion {
            if ($LogoMode -or $find.Active -or $selection.Dragging -or $detachedScroll -or (GetEditorSelection) -or $col -lt 2) {return}
            $ext=([string]$item.Extension).ToLowerInvariant()
            if (-not $editorCompletionWords.ContainsKey($ext)) {return}
            $line=$buf[$r];if ($line.Length -gt 16384 -or $col -gt $line.Length) {return}
            $wordPattern=if ($ext -in @('.ps1','.css')) {'(?<![\w$-])[A-Za-z_][A-Za-z0-9_-]*$'} else {'(?<![\w$])[A-Za-z_][A-Za-z0-9_]*$'}
            $word=[regex]::Match($line.Substring(0,$col),$wordPattern)
            if (-not $word.Success -or $word.Length -lt 2) {return}
            $tail=$line.Substring($col)
            if ($tail -match '^[\w]' -or ($ext -in @('.ps1','.css') -and $tail.StartsWith('-'))) {return}
            # Keep completion out of comments and strings (line-local lexer).
            try {$completionSpans=@(Get-NexSyntaxSpans $line $ext)} catch {return}
            foreach ($span in $completionSpans) {
                if ($span.Kind -in @('comment','string') -and $span.Start -lt $col -and $span.Start+$span.Length -ge $col) {return}
            }
            $comparison=if ($ext -in @('.ps1','.sql','.bat','.cmd','.html','.css')) {[StringComparison]::OrdinalIgnoreCase} else {[StringComparison]::Ordinal}
            $candidate=$null
            foreach ($name in $editorCompletionWords[$ext]) {
                if ($name.Equals($word.Value,$comparison)) {return}
                if (-not $candidate -and $name.StartsWith($word.Value,$comparison)) {$candidate=$name}
            }
            if ($candidate) {return @{Suffix=$candidate.Substring($word.Length);Word=($word.Value+$candidate.Substring($word.Length));Inline=($tail.Length -eq 0);Row=$r;Col=$col}}
        }
        $syntaxCache=@{}
        $syntaxColors=if ($prefs.LightMode) {@{comment='547454';string='9B3D12';number='176B5C';variable='145DA0';keyword='702E91';call='785D00';operator='555B70';tag='145DA0'}} else {@{comment='829080';string='A6E3A1';number='FAB387';variable='89DCEB';keyword='CBA6F7';call='F9E2AF';operator='BAC2DE';tag='89B4FA'}}
        function SyntaxColorLine([string]$raw,[int]$start,[int]$width,[int]$row) {
            if ($start -ge $raw.Length) {return ''}
            $end=[Math]::Min($raw.Length,$start+$width)
            if ($start -gt 0 -and [char]::IsLowSurrogate($raw[$start])) {$start++}
            if ($end -gt 0 -and $end -lt $raw.Length -and [char]::IsLowSurrogate($raw[$end])) {$end--}
            if ($end -le $start) {return ''}
            if ($LogoMode) {return (SafeText ($raw.Substring($start,$end-$start).Replace("`t",' ')))}
            if (-not $syntaxCache.ContainsKey($row) -or $syntaxCache[$row].Text -cne $raw) {
                if ($syntaxCache.Count -ge 256) {$syntaxCache.Clear()}
                $spans=@();if ($raw.Length -le 16384) {try {$spans=@(Get-NexSyntaxSpans $raw ([string]$item.Extension))} catch {}}
                $syntaxCache[$row]=@{Text=$raw;Spans=$spans}
            }
            $out='';$at=$start
            foreach ($span in $syntaxCache[$row].Spans) {
                $a=[Math]::Max($start,$span.Start);$b=[Math]::Min($end,$span.Start+$span.Length)
                if ($b -le $a) {continue}
                if ($a -gt $at) {$out+=$white+(SafeText ($raw.Substring($at,$a-$at).Replace("`t",' ')))}
                $out+=(NexAnsi $syntaxColors[$span.Kind])+(SafeText ($raw.Substring($a,$b-$a).Replace("`t",' ')))
                $at=$b
            }
            if ($at -lt $end) {$out+=$white+(SafeText ($raw.Substring($at,$end-$at).Replace("`t",' ')))}
            return $out
        }
        function UpdateEditorFind {
            $find.Rows=@{};$find.Ordered=@();$find.Total=0;$find.Index=-1;$find.Row=-1;$find.Col=-1
            if ([string]::IsNullOrEmpty($find.Query)) {return}
            $rx=[regex]::new([regex]::Escape($find.Query),[Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant)
            $ordered=[Collections.Generic.List[object]]::new()
            for ($lineNo=0;$lineNo -lt $buf.Count;$lineNo++) {
                $hits=$rx.Matches($buf[$lineNo]);if (-not $hits.Count) {continue}
                $find.Rows[$lineNo]=$hits;$ordered.Add(@{Row=$lineNo;First=$find.Total;Matches=$hits});$find.Total+=$hits.Count
            }
            $find.Ordered=$ordered.ToArray()
        }
        function MoveEditorFind([int]$direction,[switch]$Initial) {
            if (-not $find.Total) {return}
            if ($Initial) {
                $find.Index=0
                foreach ($entry in $find.Ordered) {
                    if ($entry.Row -lt $r) {continue}
                    if ($entry.Row -gt $r) {$find.Index=$entry.First;break}
                    for ($j=0;$j -lt $entry.Matches.Count;$j++) {if ($entry.Matches[$j].Index -ge $col) {$find.Index=$entry.First+$j;break}}
                    if ($entry.Matches[$entry.Matches.Count-1].Index -ge $col) {break}
                }
            } else {$find.Index=($find.Index+$direction+$find.Total)%$find.Total}
            foreach ($entry in $find.Ordered) {
                if ($find.Index -ge $entry.First -and $find.Index -lt ($entry.First+$entry.Matches.Count)) {
                    $find.Row=$entry.Row;$find.Col=$entry.Matches[($find.Index-$entry.First)].Index;break
                }
            }
        }
        function SearchSyntaxLine([string]$raw,[int]$start,[int]$width,[int]$row) {
            if (-not $find.Active -or -not $find.Rows.ContainsKey($row)) {return (SyntaxColorLine $raw $start $width $row)}
            $end=[Math]::Min($raw.Length,$start+$width);$at=$start;$result=''
            foreach ($hit in $find.Rows[$row]) {
                if ($hit.Index -ge $end) {break}
                $a=[Math]::Max($start,$hit.Index);$b=[Math]::Min($end,$hit.Index+$hit.Length)
                if ($b -le $a) {continue}
                if ($a -gt $at) {$result+=SyntaxColorLine $raw $at ($a-$at) $row}
                $active=($row -eq $find.Row -and $hit.Index -eq $find.Col)
                $tone=if ($active) {NexAnsi $palette[0] -Background} else {NexAnsi (Mix-NexColor $palette[3] $palette[0] 0.60) -Background}
                $ink=if ($active) {NexAnsi '24202B'} elseif ($prefs.LightMode) {NexAnsi '24202B'} else {$white}
                $result+=$tone+$ink+(SafeText ($raw.Substring($a,$b-$a).Replace("`t",' ')))+$reset;$at=$b
            }
            if ($at -lt $end) {$result+=SyntaxColorLine $raw $at ($end-$at) $row}
            return $result
        }
        $msg=''; $quit=$false; $closeNow=$false
        function ClearEditorSelection { $selection.Row=-1;$selection.Col=0;$selection.Dragging=$false }
        function GetEditorSelection {
            if ($selection.Row -lt 0 -or ($selection.Row -eq $r -and $selection.Col -eq $col)) {return $null}
            if ($selection.Row -lt $r -or ($selection.Row -eq $r -and $selection.Col -lt $col)) {
                return @{A=$selection.Row;AC=$selection.Col;B=$r;BC=$col}
            }
            return @{A=$r;AC=$col;B=$selection.Row;BC=$selection.Col}
        }
        function GetEditorSelectedText($range) {
            if ($range.A -eq $range.B) {return $buf[$range.A].Substring($range.AC,$range.BC-$range.AC)}
            $lines=[Collections.Generic.List[string]]::new()
            $lines.Add($buf[$range.A].Substring($range.AC))
            for ($i=$range.A+1;$i -lt $range.B;$i++) {$lines.Add($buf[$i])}
            $lines.Add($buf[$range.B].Substring(0,$range.BC))
            return ($lines -join $nl)
        }
        function PushEditorSnapshot($stack,[string]$countKey) {
            $snapshot=$buf -join "`n"
            $stack.Add(@{Text=$snapshot;Row=$r;Col=$col;Top=$top;Left=$left;AnchorRow=$selection.Row;AnchorCol=$selection.Col})
            $historyState[$countKey]+=$snapshot.Length
            while ($stack.Count -gt 1 -and ($stack.Count -gt 48 -or $historyState[$countKey] -gt 4194304)) {
                $historyState[$countKey]-=$stack[0].Text.Length;$stack.RemoveAt(0)
            }
        }
        function PushEditorUndo {
            PushEditorSnapshot $history 'Chars'
            $historyState.Redo.Clear();$historyState.RedoChars=0L
        }
        function RemoveEditorSelection($range) {
            $prefix=$buf[$range.A].Substring(0,$range.AC);$suffix=$buf[$range.B].Substring($range.BC)
            $buf[$range.A]=$prefix+$suffix
            if ($range.B -gt $range.A) {$buf.RemoveRange($range.A+1,$range.B-$range.A)}
            ClearEditorSelection
            return @{Row=$range.A;Col=$range.AC}
        }
        function GetEditorRowSelection([int]$row,[int]$length,$range) {
            if (-not $range -or $row -lt $range.A -or $row -gt $range.B) {return $null}
            $from=if ($row -eq $range.A) {$range.AC} else {0}
            $to=if ($row -eq $range.B) {$range.BC} else {$length}
            return @{From=$from;To=$to;Newline=($row -lt $range.B)}
        }
        function GetEditorBracketTokens([int]$row) {
            $raw=$buf[$row]
            if ($raw.Length -gt 16384) {return}
            if (-not $syntaxCache.ContainsKey($row) -or $syntaxCache[$row].Text -cne $raw) {
                if ($syntaxCache.Count -ge 256) {$syntaxCache.Clear()}
                try {$spans=@(Get-NexSyntaxSpans $raw ([string]$item.Extension))} catch {return}
                $syntaxCache[$row]=@{Text=$raw;Spans=$spans}
            }
            foreach ($span in $syntaxCache[$row].Spans) {
                if ($span.Kind -eq 'operator' -and $span.Length -eq 1 -and [string]$raw[$span.Start] -in @('(',')','[',']','{','}')) {
                    @{Col=[int]$span.Start;Char=[string]$raw[$span.Start]}
                }
            }
        }
        function GetEditorBracketPair {
            if ($LogoMode -or $find.Active -or $range -or $detachedScroll -or $item.Extension -notin @('.py','.ps1','.psm1','.psd1','.js','.jsx','.ts','.tsx','.json','.css','.scss','.html','.htm','.xml','.yaml','.yml','.toml','.ini','.lua','.c','.h','.cpp','.hpp','.cs','.java','.go','.rs','.php','.sh','.sql','.rb')) {return}
            $raw=$buf[$r];$chars=@('(',')','[',']','{','}')
            if (-not (($col -lt $raw.Length -and [string]$raw[$col] -in $chars) -or ($col -gt 0 -and [string]$raw[$col-1] -in $chars))) {return}
            $tokens=@(GetEditorBracketTokens $r);$anchor=$null
            foreach ($t in $tokens) {if ($t.Col -eq $col) {$anchor=$t;break};if ($t.Col -eq $col-1) {$anchor=$t}}
            if (-not $anchor) {return}
            $pairs=@{'('=')';'['=']';'{'='}';')'='(';']'='[';'}'='{'}
            $opening=@('(','[','{');$direction=if ($anchor.Char -in $opening) {1} else {-1}
            $stack=[Collections.Generic.Stack[string]]::new();$stack.Push($pairs[$anchor.Char])
            $budget=[Diagnostics.Stopwatch]::StartNew();$scanned=0
            for ($lineNo=$r;$lineNo -ge 0 -and $lineNo -lt $buf.Count -and [Math]::Abs($lineNo-$r) -le 160;$lineNo+=$direction) {
                $scanned+=$buf[$lineNo].Length
                if ($scanned -gt 32768 -or $buf[$lineNo].Length -gt 16384 -or $budget.ElapsedMilliseconds -gt 120) {return}
                $rowTokens=if ($lineNo -eq $r) {$tokens} else {@(GetEditorBracketTokens $lineNo)}
                $rowTokens=@($rowTokens | Where-Object {$_})
                if ($direction -lt 0) {[array]::Reverse($rowTokens)}
                foreach ($token in $rowTokens) {
                    if ($lineNo -eq $r -and (($direction -gt 0 -and $token.Col -le $anchor.Col) -or ($direction -lt 0 -and $token.Col -ge $anchor.Col))) {continue}
                    if (($direction -gt 0 -and $token.Char -in $opening) -or ($direction -lt 0 -and $token.Char -notin $opening)) {$stack.Push($pairs[$token.Char]);continue}
                    if ($stack.Peek() -cne $token.Char) {return}
                    $null=$stack.Pop()
                    if (-not $stack.Count) {return @{A=$r;AC=$anchor.Col;B=$lineNo;BC=$token.Col}}
                }
            }
        }
        function BracketSyntaxLine([string]$raw,[int]$start,[int]$width,[int]$row) {
            $end=[Math]::Min($raw.Length,$start+$width);$positions=@()
            if ($editorPair) {
                if ($editorPair.A -eq $row) {$positions+=$editorPair.AC}
                if ($editorPair.B -eq $row) {$positions+=$editorPair.BC}
            }
            $positions=@($positions | Where-Object {$_ -ge $start -and $_ -lt $end} | Sort-Object -Unique)
            if (-not $positions.Count) {return (SearchSyntaxLine $raw $start $width $row)}
            $at=$start;$result='';$pairBg=NexAnsi $palette[1] -Background;$pairInk=NexAnsi '24202B'
            if ($prefs.LightMode) {$pairBg=NexAnsi (Mix-NexColor $palette[3] '21683E' 0.26) -Background}
            foreach ($pos in $positions) {
                if ($pos -gt $at) {$result+=SearchSyntaxLine $raw $at ($pos-$at) $row}
                $result+=$pairBg+$pairInk+$raw.Substring($pos,1)+$reset;$at=$pos+1
            }
            if ($at -lt $end) {$result+=SearchSyntaxLine $raw $at ($end-$at) $row}
            return $result
        }
        function SyntaxLine([string]$raw,[int]$start,[int]$width,[int]$row,$mark) {
            if (-not $mark) {return (BracketSyntaxLine $raw $start $width $row)}
            $end=[Math]::Min($raw.Length,$start+$width)
            $a=[Math]::Max($start,$mark.From);$b=[Math]::Min($end,$mark.To)
            $selectedBg=NexAnsi $palette[0] -Background
            $selectedInk=NexAnsi '24202B'
            if ($b -gt $a) {
                $result=''
                if ($a -gt $start) {$result+=SearchSyntaxLine $raw $start ($a-$start) $row}
                $result+=$selectedBg+$selectedInk+(SafeText ($raw.Substring($a,$b-$a).Replace("`t",' ')))+$reset
                if ($b -lt $end) {$result+=SearchSyntaxLine $raw $b ($end-$b) $row}
            } else {$result=SearchSyntaxLine $raw $start $width $row}
            if ($mark.Newline -and $raw.Length -ge $start -and $raw.Length -lt $start+$width) {$result+=$selectedBg+' '+$reset}
            return $result
        }
        # Same cell widths as ClipAnsi for normal text, including full-width characters.
        function EditorGlyphWidth([string]$glyph) {
            $cp=if ($glyph.Length -ge 2 -and [char]::IsSurrogatePair($glyph,0)) {[char]::ConvertToUtf32($glyph,0)} else {[int][char]$glyph[0]}
            if (($cp -ge 0x1100 -and $cp -le 0x115F) -or ($cp -ge 0x2E80 -and $cp -le 0xA4CF) -or ($cp -ge 0xAC00 -and $cp -le 0xD7A3) -or ($cp -ge 0xF900 -and $cp -le 0xFAFF) -or ($cp -ge 0xFE10 -and $cp -le 0xFE6F) -or ($cp -ge 0xFF00 -and $cp -le 0xFF60) -or $cp -ge 0x1F000) {return 2}
            return 1
        }
        function EditorCells([string]$line,[int]$start,[int]$end) {
            if ($end -le $start) {return 0}
            $part=$line.Substring($start,$end-$start)
            if ($part -notmatch '[\u0300-\u036F\u1100-\u115F\u2E80-\uA4CF\uAC00-\uD7A3\uD800-\uDFFF\uF900-\uFAFF\uFE10-\uFE6F\uFF00-\uFF60]') {return $part.Length}
            $cells=0;$it=[Globalization.StringInfo]::GetTextElementEnumerator($part)
            while ($it.MoveNext()) {$cells+=EditorGlyphWidth ($it.GetTextElement())}
            return $cells
        }
        function EditorColumnAtCell([string]$line,[int]$start,[int]$cell) {
            $start=[Math]::Max(0,[Math]::Min($start,$line.Length))
            if ($start -gt 0 -and $start -lt $line.Length -and [char]::IsLowSurrogate($line[$start])) {$start--}
            if ($cell -le 0) {return $start}
            $part=$line.Substring($start)
            if ($part -notmatch '[\u0300-\u036F\u1100-\u115F\u2E80-\uA4CF\uAC00-\uD7A3\uD800-\uDFFF\uF900-\uFAFF\uFE10-\uFE6F\uFF00-\uFF60]') {return [Math]::Min($line.Length,$start+$cell)}
            $used=0;$it=[Globalization.StringInfo]::GetTextElementEnumerator($part)
            while ($it.MoveNext()) {
                $glyph=$it.GetTextElement();$size=EditorGlyphWidth $glyph
                if ($cell -lt $used+$size) {return ($start+$it.ElementIndex)}
                $used+=$size
            }
            return $line.Length
        }
        function EditorPreviousColumn([string]$line,[int]$position) {
            if ($position -le 0) {return 0}
            if ($position -ge 2 -and [char]::IsLowSurrogate($line[$position-1]) -and [char]::IsHighSurrogate($line[$position-2])) {return ($position-2)}
            return ($position-1)
        }
        function EditorNextColumn([string]$line,[int]$position) {
            if ($position -ge $line.Length) {return $line.Length}
            if ($position+1 -lt $line.Length -and [char]::IsHighSurrogate($line[$position]) -and [char]::IsLowSurrogate($line[$position+1])) {return ($position+2)}
            return ($position+1)
        }
        # Use raw input in the editor as well as in its modal dialogs.
        # A native mode snapshot is separate from the dashboard's own snapshot.
        $editorMode=-1
        try { $editorMode=[NexDash.NativeInput216]::EnableEditor() } catch {}
        $editorNative=($editorMode -ge 0)
        if (-not $editorNative) { PauseMouse }

        # Native Terminal owns the actual font size. Measure its focused text
        # provider, with a client-width estimate as a fallback for older UIA
        # providers. The reset shortcut is injected only after an explicit click
        # release in the foreground Terminal; no persistent settings are edited.
        $zoomState=@{Size='';Label='—%';Baseline=0.0;Ready=$false;Tried=$false;Uia=$false;ResetArmed=$false;RetryAt=0L;Error='';LastDiagnostic='';Clock=[Diagnostics.Stopwatch]::StartNew()}
        function InitEditorZoom {
            if ($zoomState.Tried) {return}
            $zoomState.Tried=$true
            # Default-terminal delegation can omit WT_SESSION even for Windows Terminal.
            # Identify the real foreground window using its native class/process.
            try {
                if (-not ('NexDash.EditorZoom2711' -as [type])) {
                    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Diagnostics;
using System.Runtime.InteropServices;
namespace NexDash {
 public static class EditorZoom2711 {
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr hwnd,uint flags);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd,out Rect r);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd,StringBuilder name,int max);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
  [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr hwnd);
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd,out Rect r);
  [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
  [DllImport("user32.dll",SetLastError=true)] static extern uint SendInput(uint count,Input[] inputs,int size);
  [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left,Top,Right,Bottom; }
  [StructLayout(LayoutKind.Sequential)] struct Keyboard { public ushort Vk,Scan; public uint Flags,Time; public UIntPtr Extra; }
  [StructLayout(LayoutKind.Sequential)] struct Mouse { public int X,Y; public uint Data,Flags,Time; public UIntPtr Extra; }
  [StructLayout(LayoutKind.Explicit)] struct Payload { [FieldOffset(0)] public Keyboard Key; [FieldOffset(0)] public Mouse MouseData; }
  [StructLayout(LayoutKind.Sequential)] struct Input { public uint Type; public Payload Data; }
  public static uint ProcessId(IntPtr hwnd) { uint id; GetWindowThreadProcessId(hwnd,out id); return id; }
  public static IntPtr ForegroundRoot() {
   IntPtr h=GetForegroundWindow(); if(h==IntPtr.Zero) return h;
   IntPtr root=GetAncestor(h,2); return root==IntPtr.Zero?h:root;
  }
  public static string Describe(IntPtr hwnd) {
   if(hwnd==IntPtr.Zero) return "no foreground window";
   var name=new StringBuilder(256); GetClassName(hwnd,name,name.Capacity);
   string process="?"; try {using(var p=Process.GetProcessById((int)ProcessId(hwnd))) process=p.ProcessName;} catch {}
   return process+" / "+name.ToString();
  }
  public static bool IsTerminal(IntPtr hwnd) {
   if(hwnd==IntPtr.Zero || hwnd!=ForegroundRoot()) return false;
   var name=new StringBuilder(256);
   GetClassName(hwnd,name,name.Capacity);
   if(name.ToString().StartsWith("CASCADIA_HOSTING_WINDOW_CLASS",StringComparison.OrdinalIgnoreCase)) return true;
   try {
    using(var p=Process.GetProcessById((int)ProcessId(hwnd))) {
     return p.ProcessName.StartsWith("WindowsTerminal",StringComparison.OrdinalIgnoreCase);
    }
   } catch {return false;}
  }
  public static double Dpi(IntPtr hwnd) { try { uint d=GetDpiForWindow(hwnd);return d>0?d:96.0; } catch {return 96.0;} }
  public static int ClientWidth(IntPtr hwnd) {Rect r; if(GetClientRect(hwnd,out r) && r.Right>r.Left) return r.Right-r.Left; return GetWindowRect(hwnd,out r)?r.Right-r.Left:0;}
  static Input Key(ushort vk,bool up) { Input i=new Input();i.Type=1;i.Data.Key.Vk=vk;i.Data.Key.Flags=up?2u:0u;return i; }
  public static string Reset(IntPtr hwnd) {
   if(!IsTerminal(hwnd)) return "Foreground is not Windows Terminal: "+Describe(hwnd);
   int size=Marshal.SizeOf(typeof(Input)); if(size!=(IntPtr.Size==8?40:28)) return "Invalid INPUT size: "+size;
   // A console mouse-up event can arrive before the physical button is released.
   for(int attempt=0;attempt<8;attempt++) {
    bool held=false;
    foreach(int k in new int[]{0x10,0x11,0x12,0x5B,0x5C,0x01}) if((GetAsyncKeyState(k)&0x8000)!=0) held=true;
    if(!held) {
     if(!IsTerminal(hwnd)) return "Foreground changed";
     Input[] keys={Key(0x11,false),Key(0x30,false),Key(0x30,true),Key(0x11,true)};
     uint sent=SendInput((uint)keys.Length,keys,size); int err=Marshal.GetLastWin32Error();
     if(sent==keys.Length) return "OK";
     if(sent>0 && sent<keys.Length) {Input[] release={Key(0x30,true),Key(0x11,true)};SendInput(2,release,size);}
     return "SendInput: "+sent+"/4; Win32="+err;
    }
    System.Threading.Thread.Sleep(35);
   }
   return "A physical modifier or mouse button is still held";
  }
 }
}
'@ -ErrorAction Stop
                }
                $zoomState.Ready=$true
            } catch {$zoomState.Error='Native init: '+$_.Exception.Message;return}
            try {
                Add-Type -AssemblyName WindowsBase -ErrorAction Stop
                Add-Type -AssemblyName UIAutomationClient -ErrorAction Stop
                Add-Type -AssemblyName UIAutomationTypes -ErrorAction Stop
                $zoomState.Uia=$true
            } catch {}
        }
        function SaveEditorZoomDiagnostic([string]$reason) {
            # No document text, names, window titles, or clipboard contents are recorded.
            if ($zoomState.LastDiagnostic -eq $reason) {return}
            $zoomState.LastDiagnostic=$reason
            try {
                $path=Join-Path $env:LOCALAPPDATA 'NexDashboard\editor-zoom-diagnostic.txt'
                $line="$(Get-Date -Format o) | $reason | WT_SESSION present: $([bool]$env:WT_SESSION) | grid: $([Console]::WindowWidth)x$([Console]::WindowHeight)"
                $encoding=New-Object System.Text.UTF8Encoding($true)
                if ((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -lt 16384) {
                    [IO.File]::AppendAllText($path,([Environment]::NewLine+$line),$encoding)
                } else {[IO.File]::WriteAllText($path,$line,$encoding)}
            } catch {}
        }
        function GetEditorZoomCell {
            InitEditorZoom
            if (-not $zoomState.Ready) {SaveEditorZoomDiagnostic $zoomState.Error;return $null}
            try {
                $hwnd=[NexDash.EditorZoom2711]::ForegroundRoot()
                if (-not [NexDash.EditorZoom2711]::IsTerminal($hwnd)) {$zoomState.Error='Foreground: '+[NexDash.EditorZoom2711]::Describe($hwnd);SaveEditorZoomDiagnostic $zoomState.Error;return $null}
                $dpi=[NexDash.EditorZoom2711]::Dpi($hwnd)
                $terminalPid=[NexDash.EditorZoom2711]::ProcessId($hwnd)
                $columns=[Console]::WindowWidth
                if ($zoomState.Uia) {
                    try {
                        $element=[System.Windows.Automation.AutomationElement]::FocusedElement
                        $walker=[System.Windows.Automation.TreeWalker]::RawViewWalker
                        $provider=$null;$pattern=$null
                        for ($depth=0;$depth -lt 12 -and $element;$depth++) {
                            if ($element.Current.ProcessId -ne $terminalPid) {break}
                            $candidate=$null
                            if ($element.TryGetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern,[ref]$candidate)) {$provider=$element;$pattern=$candidate;break}
                            $element=$walker.GetParent($element)
                        }
                        if (-not $provider) {
                            $root=[System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
                            $condition=New-Object System.Windows.Automation.PropertyCondition -ArgumentList ([System.Windows.Automation.AutomationElement]::IsTextPatternAvailableProperty),$true
                            $matches=$root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition)
                            if ($matches.Count -eq 1) {$provider=$matches.Item(0);$pattern=$provider.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)}
                            else {for ($i=0;$i -lt [Math]::Min(32,$matches.Count);$i++) {if ($matches.Item($i).Current.HasKeyboardFocus) {$provider=$matches.Item($i);$pattern=$provider.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern);break}}}
                        }
                        if ($provider -and $pattern) {
                            foreach ($visible in $pattern.GetVisibleRanges()) {
                                $cell=$visible.Clone();$cell.ExpandToEnclosingUnit([System.Windows.Automation.Text.TextUnit]::Character)
                                foreach ($rect in $cell.GetBoundingRectangles()) {
                                    if ($rect.Width -ge 2 -and $rect.Width -le 96 -and $rect.Height -gt 0) {return @{Width=([double]$rect.Width*96.0/$dpi);Source='Cell'}}
                                }
                            }
                            $rect=$provider.Current.BoundingRectangle
                            if ($columns -gt 0 -and $rect.Width -gt 0) {
                                $width=[Math]::Round($rect.Width/$columns)
                                if ($width -ge 2 -and $width -le 96) {return @{Width=($width*96.0/$dpi);Source='Pane'}}
                            }
                        }
                    } catch {}
                }
                # Approximate single-pane cell width. Round to physical pixels so
                # small window resizes generally do not change the estimate.
                $client=[NexDash.EditorZoom2711]::ClientWidth($hwnd)
                if ($columns -gt 0 -and $client -gt 0) {
                    $width=[Math]::Round(($client-24.0*$dpi/96.0)/$columns)
                    if ($width -ge 2 -and $width -le 96) {return @{Width=($width*96.0/$dpi);Source='Window'}}
                }
                $zoomState.Error="Invalid cell estimate: client=$client, columns=$columns, dpi=$dpi"
            } catch {$zoomState.Error='Measure: '+$_.Exception.Message}
            SaveEditorZoomDiagnostic $zoomState.Error
            return $null
        }
        function UpdateEditorZoom {
            $measurement=GetEditorZoomCell
            if (-not $measurement) {return}
            $zoomState.Error=''
            $height=[double]$measurement.Width
            if (-not $script:NexEditorZoomReference -or $script:NexEditorZoomReference.Session -ne $env:WT_SESSION -or $script:NexEditorZoomReference.Source -ne $measurement.Source) {
                $script:NexEditorZoomReference=@{Session=$env:WT_SESSION;Height=$height;Source=$measurement.Source}
            }
            $zoomState.Baseline=[double]$script:NexEditorZoomReference.Height
            if ($zoomState.Baseline -gt 0) {
                $percent=[int][Math]::Round(100.0*$height/$zoomState.Baseline)
                $zoomState.Label="~$percent%"
            }
        }
        function ResetEditorZoom {
            InitEditorZoom
            if (-not $zoomState.Ready) {SaveEditorZoomDiagnostic $zoomState.Error;return $false}
            try {
                $hwnd=[NexDash.EditorZoom2711]::ForegroundRoot()
                $result=[NexDash.EditorZoom2711]::Reset($hwnd)
                if ($result -ne 'OK') {$zoomState.Error=$result;SaveEditorZoomDiagnostic $result;return $false}
                Start-Sleep -Milliseconds 280
                $script:NexEditorZoomReference=$null
                $zoomState.Baseline=0.0;$zoomState.Size='';$zoomState.Label='—%'
                UpdateEditorZoom
                return $true
            } catch {$zoomState.Error='Reset: '+$_.Exception.Message;SaveEditorZoomDiagnostic $zoomState.Error;return $false}
        }
        $editorQueue=@{Pending=$null;LeftDown=$false;WheelRemainder=0;ObservedSize="$([Console]::WindowWidth)x$([Console]::WindowHeight)"}
        function ReadEditorRaw([switch]$Immediate) {
            while ($true) {
                $nowSize="$([Console]::WindowWidth)x$([Console]::WindowHeight)"
                if ($nowSize -ne $editorQueue.ObservedSize) {$editorQueue.ObservedSize=$nowSize;return @{Key='Resize';Ctrl=$false;KeyChar=[char]0}}
                if ($editorNative) {
                    $record=[NexDash.NativeInput216]::Poll()
                    if ($record.Type -eq 1 -and $record.KeyDown -ne 0) {
                        $vk=[int]$record.VirtualKey
                        $ch=[char]$record.UnicodeChar
                        $ctrlDown=($record.ControlState -band 12) -ne 0
                        $keyName='Text'
                        if ([Enum]::IsDefined([System.ConsoleKey],$vk)) { $keyName=([System.ConsoleKey]$vk).ToString() }
                        elseif ($ch -eq [char]0) { continue }
                        return @{Key=$keyName;KeyChar=$ch;Ctrl=$ctrlDown;Shift=(($record.ControlState -band 16) -ne 0)}
                    }
                    if ($record.Type -eq 2 -and $record.Flags -in @(0,1,2)) {
                        $down=($record.Buttons -band 1) -ne 0;$wasDown=$editorQueue.LeftDown;$editorQueue.LeftDown=$down
                        $mouseKey=if ($down -and -not $wasDown) {'Click'} elseif ($down -and $wasDown -and $record.Flags -eq 1) {'MouseDrag'} elseif (-not $down -and $wasDown) {'MouseRelease'} else {''}
                        if ($mouseKey) {return @{Key=$mouseKey;X=([int]$record.X-[Console]::WindowLeft);Y=([int]$record.Y-[Console]::WindowTop);Ctrl=$false;Shift=(($record.MouseControlState -band 16) -ne 0);KeyChar=[char]0}}
                    }
                    if ($record.Type -eq 2 -and $record.Flags -eq 4 -and -not ($record.MouseControlState -band 12)) {
                        # MOUSE_EVENT_RECORD has its own modifier field at offset 12.
                        # Signed wheel delta is the high word of dwButtonState.
                        $delta=[int]($record.Buttons -shr 16)
                        if ($delta -ge 32768) {$delta-=65536}
                        $editorQueue.WheelRemainder+=$delta
                        $steps=[int][Math]::Truncate($editorQueue.WheelRemainder/120.0)
                        if ($steps) {
                            $editorQueue.WheelRemainder-=$steps*120
                            return @{Key='EditorScroll';Lines=(-3*$steps);Ctrl=$false;KeyChar=[char]0}
                        }
                    }
                } elseif ([Console]::KeyAvailable) {
                    $keyInfo=[Console]::ReadKey($true)
                    return @{Key=$keyInfo.Key.ToString();KeyChar=$keyInfo.KeyChar;Ctrl=(($keyInfo.Modifiers -band [ConsoleModifiers]::Control) -ne 0);Shift=(($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) -ne 0)}
                }
                # Ignore key-up and irrelevant mouse records without delaying queued input.
                if ($editorNative -and $record.Type -ne 0) {continue}
                if ($Immediate) {return $null}
                if ($zoomState.Label -eq '—%' -and $zoomState.Clock.ElapsedMilliseconds -ge $zoomState.RetryAt) {
                    $zoomState.RetryAt=$zoomState.Clock.ElapsedMilliseconds+1200
                    return @{Key='ZoomRefresh';Ctrl=$false;KeyChar=[char]0}
                }
                Start-Sleep -Milliseconds 8
            }
        }
        function ReadEditorEvent {
            $first=if ($editorQueue.Pending) {$v=$editorQueue.Pending;$editorQueue.Pending=$null;$v} else {ReadEditorRaw}
            if ($first.Key -eq 'MouseDrag') {
                # Coalesce motion, but never drop a release, key press or resize.
                for ($i=0;$i -lt 64;$i++) {
                    $next=ReadEditorRaw -Immediate;if (-not $next) {break}
                    if ($next.Key -ne 'MouseDrag') {$editorQueue.Pending=$next;break}
                    $first=$next
                }
                return $first
            }
            if ($first.Key -eq 'Tab' -and $editorCompletion) {return $first}
            if ($first.Ctrl -or ($first.Key -notin @('Enter','Tab') -and [char]::IsControl([char]$first.KeyChar))) {return $first}
            $sb=[Text.StringBuilder]::new();[void]$sb.Append($(if ($first.Key -eq 'Enter') {"`n"} elseif ($first.Key -eq 'Tab') {'    '} else {[string]$first.KeyChar}))
            $batchClock=[Diagnostics.Stopwatch]::StartNew();$count=1
            while ($count -lt 4096 -and $batchClock.ElapsedMilliseconds -lt 15) {
                $next=ReadEditorRaw -Immediate;if (-not $next) {break}
                if ($next.Ctrl -or ($next.Key -notin @('Enter','Tab') -and [char]::IsControl([char]$next.KeyChar))) {$editorQueue.Pending=$next;break}
                [void]$sb.Append($(if ($next.Key -eq 'Enter') {"`n"} elseif ($next.Key -eq 'Tab') {'    '} else {[string]$next.KeyChar}));$count++
            }
            if ($count -eq 1) {return $first};return @{Key='TextBatch';Text=$sb.ToString();Ctrl=$false;KeyChar=[char]0}
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
            } finally { Write-Host "$reset$e[2J$e[H" -NoNewline }
        }
        $editorOld=@();$editorSize='';$editorPaint=@{Invalid=$false};$editorRowCache=@{}; $view=1; $bodyStart=2; $bodyEnd=2; $toolbarHits=@(); $detachedScroll=$false
        try {
            Write-Host "$reset$e[2J$e[H" -NoNewline
            while (-not $quit) {
                if ($closeNow) {
                    $closeNow=$false;$editorTabs.RemoveAt($activeTab)
                    if (-not $editorTabs.Count) {break}
                    $activeTab=[Math]::Min($activeTab,$editorTabs.Count-1);$tabDoc=$editorTabs[$activeTab]
                    foreach ($docKey in $docKeys) {Set-Variable -Name $docKey -Value $tabDoc[$docKey] -Scope Local}
                    $syntaxCache.Clear();$editorRowCache.Clear();$editorPaint.Invalid=$true;$msg='';$zoomState.ResetArmed=$false
                }
                $editorCompletion=$null
                $w=[Console]::WindowWidth; $h=[Console]::WindowHeight
                if ($w -lt 30 -or $h -lt 12) {$editorSize='';$editorOld=@(); Write-Host "$reset$e[2J$e[H${pink}Enlarge terminal, or Esc to close.$reset" -NoNewline }
                else {
                    # Build a compact, localized toolbar above the editor. Mouse hit boxes
                    # and the text viewport use the same zero-based row coordinates.
                    $avail=$w-9; $range=GetEditorSelection
                    $tabRow='';$tabHits=@();$tabOffset=0
                    if (-not $LogoMode) {
                        $tabOffset=1;$tabRow="$purple[ + ]$reset $purple[ ≡ ]$reset "
                        $tabHits=@(@{Y=1;Start=0;End=5;Action='TabOpen'},@{Y=1;Start=6;End=11;Action='TabList'})
                        $tabX=12;$tabRoom=$w-1-$tabX
                        $tabSlots=[Math]::Max(1,[int][Math]::Floor($tabRoom/20.0))
                        $tabCell=[Math]::Min(26,[int][Math]::Floor($tabRoom/[Math]::Min($tabSlots,$editorTabs.Count)))
                        $tabFirst=[Math]::Max(0,[Math]::Min($activeTab,$editorTabs.Count-$tabSlots))
                        for ($ti=$tabFirst;$ti -lt [Math]::Min($editorTabs.Count,$tabFirst+$tabSlots);$ti++) {
                            $td=$editorTabs[$ti];$tabDirty=if ($ti -eq $activeTab) {$dirty} else {$td.dirty}
                            $tabMark=if ($tabDirty) {'*'} elseif ($ti -eq $activeTab) {'◆'} else {' '}
                            $tabName=SafeText $td.item.Name
                            $nameLimit=[Math]::Max(1,$tabCell-7)
                            if ((Get-NexLogoWidth $tabName) -gt $nameLimit) {
                                while ($tabName.Length -and (Get-NexLogoWidth $tabName) -gt ($nameLimit-1)) {
                                    $tabName=$tabName.Substring(0,$tabName.Length-1)
                                    if ($tabName.Length -and [char]::IsHighSurrogate($tabName[$tabName.Length-1])) {$tabName=$tabName.Substring(0,$tabName.Length-1)}
                                }
                                $tabName+='…'
                            }
                            $tabLabel=' '+$tabMark+' '+$tabName+' '
                            $tabLabel+=(' '*[Math]::Max(0,$tabCell-3-(Get-NexLogoWidth $tabLabel)))
                            $tabLabelWidth=Get-NexLogoWidth $tabLabel
                            $tabStyle=if ($ti -eq $activeTab) {"$bg$pink"} else {$gray}
                            $tabRow+=$tabStyle+$tabLabel+$reset+$tabStyle+'× '+$reset+$muted+'│'+$reset
                            $tabHits+=@{Y=1;Start=$tabX;End=$tabX+$tabLabelWidth;Action=('TabSelect:'+ $ti)}
                            $tabHits+=@{Y=1;Start=$tabX+$tabLabelWidth;End=$tabX+$tabLabelWidth+2;Action=('TabClose:'+ $ti)}
                            $tabX+=$tabLabelWidth+3
                        }
                    }
                    $toolbarEntries=@()
                    if ($find.Active) {
                        $toolbarEntries=@(
                            @{Text='[ ↑ ]';Short='[ ↑ ]';Color=$pink;Action='FindPrev'},
                            @{Text='[ ↓ ]';Short='[ ↓ ]';Color=$pink;Action='FindNext'},
                            @{Text=(NexL 'Up/Down or Enter/F3: matches | Esc: close search');Short='Enter/F3 | Esc';Color=$gray;Action=''}
                        )
                    } else {
                        $toolbarEntries=@(
                            @{Text=('[ '+(NexL 'Save')+' ] Ctrl+S/F2');Short='[ Ctrl+S/F2 ]';Color=$pink;Action='Save'},
                            @{Text=('[ '+(NexL $(if (-not $LogoMode -and $editorTabs.Count -gt 1) {'Close tab'} else {'Exit'}))+' ] Esc');Short='[ Esc ]';Color=$purple;Action='Exit'}
                        )
                        if (-not $LogoMode) {$toolbarEntries+=@{Text=('Ctrl+F '+(NexL 'Search'));Short='Ctrl+F';Color=$purple;Action='Find'}}
                        $toolbarEntries+=@(
                            @{Text=('Ctrl+C '+(NexL 'Copy'));Short='Ctrl+C';Color=$gray;Action=''},
                            @{Text=('Ctrl+X '+(NexL 'Cut'));Short='Ctrl+X';Color=$gray;Action=''},
                            @{Text=('Ctrl+V '+(NexL 'Paste'));Short='Ctrl+V';Color=$gray;Action=''},
                            @{Text=('Ctrl+A '+(NexL 'Select all text'));Short='Ctrl+A';Color=$gray;Action=''},
                            @{Text=('Ctrl+Z '+(NexL 'Undo'));Short='Ctrl+Z';Color=$gray;Action=''},
                            @{Text=('Ctrl+Y '+(NexL 'Redo'));Short='Ctrl+Y';Color=$gray;Action=''},
                            @{Text=('Ctrl++ / Ctrl+- '+(NexL 'Editor zoom'));Short='Ctrl++ / Ctrl+-';Color=$gray;Action=''}
                        )
                    }
                    $toolbarEntries+=@{Text=((NexL 'Editor zoom')+' '+$zoomState.Label+' [ ↺ '+(NexL 'Reset zoom')+' ]');Short=('[ ↺ '+$zoomState.Label+' ]');Color=$purple;Action='ResetZoom'}
                    # At narrow sizes retain all shortcuts and reserve at least three text rows.
                    for ($compactToolbar=0;$compactToolbar -le 1;$compactToolbar++) {
                        $toolbarRows=New-Object 'System.Collections.Generic.List[string]';$toolbarHits=@($tabHits);$toolbarLine='';$toolbarWidth=0
                        foreach ($entry in $toolbarEntries) {
                            $label=if ($compactToolbar -or $entry.Text.Length -gt ($w-1)) {$entry.Short} else {$entry.Text}
                            $gap=if ($toolbarWidth) {3} else {0}
                            if ($toolbarWidth -and $toolbarWidth+$gap+$label.Length -gt ($w-1)) {
                                $toolbarRows.Add($toolbarLine);$toolbarLine='';$toolbarWidth=0;$gap=0
                            }
                            if ($gap) {$toolbarLine+="$muted │ $reset";$toolbarWidth+=$gap}
                            if ($entry.Action) {$toolbarHits+=@{Y=1+$tabOffset+$toolbarRows.Count;Start=$toolbarWidth;End=$toolbarWidth+$label.Length;Action=$entry.Action}}
                            $toolbarLine+=$entry.Color+$label+$reset;$toolbarWidth+=$label.Length
                        }
                        if ($toolbarWidth) {$toolbarRows.Add($toolbarLine)}
                        if ($toolbarRows.Count+$tabOffset -le $h-6) {break}
                    }
                    $bodyStart=2+$tabOffset+$toolbarRows.Count; $bodyEnd=$h-1; $view=$bodyEnd-$bodyStart
                    $top=[Math]::Max(0,[Math]::Min($top,[Math]::Max(0,$buf.Count-$view)))
                    if (-not $detachedScroll) {
                        $top=[Math]::Min($top,$r); if ($r -ge $top+$view) {$top=$r-$view+1}
                    }
                    $left=[Math]::Max(0,[Math]::Min($left,$col)); if ($col -ge $left+$avail) { $left=$col-$avail+1 }
                    if ($left -gt 0 -and $left -lt $buf[$r].Length -and [char]::IsLowSurrogate($buf[$r][$left])) {$left--}
                    while ((EditorCells $buf[$r] $left $col) -ge $avail -and $left -lt $col) {$left=EditorNextColumn $buf[$r] $left}
                    $editorCompletion=GetEditorCompletion
                    $editorPair=GetEditorBracketPair
                    $status=if ($dirty) {' * '+(NexL 'Unsaved')} else {' '+(NexL 'Saved')}
                    $editorRows=New-Object 'System.Collections.Generic.List[string]';$editorRows.Add("$pink$(ClipAnsi ('  '+(SafeText (Get-NexName))+' / '+(NexL 'Editor')+' / '+(SafeText $item.Name)+$status) ($w-1))$reset");if ($tabOffset) {$editorRows.Add($tabRow)};foreach ($toolbarRow in $toolbarRows) {$editorRows.Add($toolbarRow)};$editorRows.Add("$muted$('─'*($w-1))$reset")
                    for ($j=0;$j -lt $view;$j++) {
                        $i=$top+$j;$rowText=''
                        if ($i -lt $buf.Count) {
                            $line=$buf[$i];$mark=GetEditorRowSelection $i $line.Length $range
                            $selectStyle=if ($mark) {"$($mark.From):$($mark.To):$($mark.Newline)"} else {''}
                            $pairStyle='';if ($editorPair) {if ($editorPair.A -eq $i) {$pairStyle+='A'+$editorPair.AC};if ($editorPair.B -eq $i) {$pairStyle+='B'+$editorPair.BC}}
                            $cached=$editorRowCache[$j]
                            if ($cached -and $cached.Row -eq $i -and $cached.Left -eq $left -and $cached.Width -eq $avail -and $cached.Select -ceq $selectStyle -and $cached.Pair -ceq $pairStyle -and $cached.Raw -ceq $line) {$rowText=$cached.Rendered}
                            else {$rowText="$gray$('{0,5}' -f ($i+1)) │ $white$(ClipAnsi (SyntaxLine $line $left $avail $i $mark) $avail)$reset";$editorRowCache[$j]=@{Row=$i;Left=$left;Width=$avail;Select=$selectStyle;Pair=$pairStyle;Raw=$line;Rendered=$rowText}}
                        }
                        # The cached row contains real text only. Ghost text never enters the buffer.
                        if ($editorCompletion -and $editorCompletion.Inline -and $i -eq $r) {
                            $remaining=[Math]::Max(0,$avail-(EditorCells $buf[$r] $left $col))
                            if ($remaining -gt 0) {$rowText+=$muted+(ClipAnsi $editorCompletion.Suffix $remaining)+$reset}
                        }
                        $editorRows.Add($rowText)
                    }
                    $statusLine=if ($msg) { $msg } elseif ($range) {"$(NexL 'Selection'): $(NexL 'Line') $($range.A+1):$($range.AC+1) – $($range.B+1):$($range.BC+1)"} elseif ($LogoMode) {NexL 'Paste art | Ctrl+A selects all | Empty + Save = default'} else { "$(NexL 'Line') $($r+1)/$($buf.Count)  $(NexL 'Col') $($col+1)" }
                    if ($find.Active) {$countLabel=if ($find.Total) {"$($find.Index+1)/$($find.Total)"} elseif ($find.Query) {NexL 'No matches'} else {NexL 'Type to search'};$statusLine="[$countLabel] > $($find.Query)"}
                    if ($editorCompletion -and -not $msg) {$statusLine+='  │  '+(NexL 'Tab: complete')+' → '+$editorCompletion.Word}
                    $statusColor=if ($msg -like 'Save failed:*') {$red} elseif ($msg -like 'Saved*' -or $msg -eq 'Already saved.' -or ($LogoMode -and $msg -in @((NexL 'Custom logo saved.'),(NexL 'Default logo restored.')))) {$green} else {$gray}
                    $editorRows.Add("$statusColor$(ClipAnsi (SafeText (NexL $statusLine)) ($w-1))$reset")
                    $frame='';$sizeKey="${w}x${h}";if ($editorSize -ne $sizeKey -or $editorPaint.Invalid) {$editorOld=@();$editorSize=$sizeKey;$editorPaint.Invalid=$false;$frame="$reset$e[2J"}
                    for ($j=0;$j -lt $editorRows.Count;$j++) {if ($j -ge $editorOld.Count -or $editorOld[$j] -cne $editorRows[$j]) {$frame+="$e[$($j+1);1H$reset$($editorRows[$j])$reset$e[K"}}
                    $editorOld=$editorRows.ToArray()
                    if ($frame) {$frame="$e[?25l$frame"}
                    if ($find.Active) {$frame+="$e[${h};$([Math]::Min($w-1,$statusLine.Length+1))H$e[?25h"}
                    elseif ($r -ge $top -and $r -lt $top+$view) {$frame+="$e[$($r-$top+$bodyStart+1);$([Math]::Min($w-1,(EditorCells $buf[$r] $left $col)+9))H$e[?25h"}
                    else {$frame+="$e[?25l"}
                    Write-Host $frame -NoNewline
                    # Sample only after the actual frame is visible, and only on
                    # first draw / resize / reset; normal typing stays fast.
                    if ($zoomState.Size -ne $sizeKey) {
                        $zoomState.Size=$sizeKey;$oldZoomLabel=$zoomState.Label
                        UpdateEditorZoom
                        if ($oldZoomLabel -ne $zoomState.Label) {continue}
                    }
                }
                $k=ReadEditorEvent; $ctrl=$k.Ctrl
                if ($k.Key -eq 'Resize') { continue }
                if ($k.Key -eq 'ZoomRefresh') {$zoomState.Size='';continue}
                if ($k.Key -eq 'EditorScroll') {
                    if ($w -ge 30 -and $h -ge 12) {
                        $top=[Math]::Max(0,[Math]::Min($top+$k.Lines,[Math]::Max(0,$buf.Count-$view)))
                        $detachedScroll=$true
                    }
                    continue
                }
                # Keyboard navigation/editing resumes following the caret. A mouse
                # click uses the displayed viewport before changing that caret.
                if ($k.Key -notin @('Click','MouseDrag','MouseRelease') -and -not ($ctrl -and $k.Key -eq 'O') -and [int]$k.KeyChar -ne 15) {$detachedScroll=$false}
                $msg='';$toolbarAction=''
                if ($k.Key -eq 'Click' -and $w -ge 30 -and $h -ge 12) {
                    foreach ($hit in $toolbarHits) {if ($k.Y -eq $hit.Y -and $k.X -ge $hit.Start -and $k.X -lt $hit.End) {$toolbarAction=$hit.Action;break}}
                }
                if (-not $LogoMode -and ($toolbarAction -like 'Tab*' -or ($ctrl -and $k.Key -eq 'O') -or [int]$k.KeyChar -eq 15)) {
                    $targetTab=-1;$closingTab=$false;$selection.Dragging=$false;$zoomState.ResetArmed=$false
                    if ($toolbarAction -match '^Tab(Select|Close):(\d+)$') {
                        $closingTab=$Matches[1] -eq 'Close';$targetTab=[int]$Matches[2]
                    } elseif ($toolbarAction -eq 'TabList') {
                        SaveEditorTabState
                        $tabChoices=@($editorTabs | ForEach-Object {$(if ($_.dirty) {'* '} else {'  '})+$_.path})
                        try {$picked=Ask 'Open tabs' $tabChoices @($editorTabs | ForEach-Object {$_.path});if ($picked) {for ($ti=0;$ti -lt $editorTabs.Count;$ti++) {if ($editorTabs[$ti].path -ieq $picked) {$targetTab=$ti;break}}}} catch {$msg=$_.Exception.Message}
                        $editorPaint.Invalid=$true;$editorQueue.LeftDown=$false
                    } else {
                        try {
                            $pickedFile=EditorFilePicker
                            if ($pickedFile) {
                                for ($ti=0;$ti -lt $editorTabs.Count;$ti++) {if ($editorTabs[$ti].path -ieq $pickedFile.FullName) {$targetTab=$ti;break}}
                                if ($targetTab -lt 0) {
                                    if ($editorTabs.Count -ge 12) {$msg=NexL 'Tab limit: 12 files.'}
                                    else {$newDoc=NewEditorDocument $pickedFile;$editorTabs.Add($newDoc);$targetTab=$editorTabs.Count-1}
                                }
                            }
                        } catch {$msg='Editor: '+$_.Exception.Message}
                        $editorPaint.Invalid=$true;$editorQueue.LeftDown=$false
                    }
                    if ($targetTab -ge 0 -and $targetTab -lt $editorTabs.Count -and $targetTab -ne $activeTab) {
                        SaveEditorTabState;$activeTab=$targetTab;$tabDoc=$editorTabs[$activeTab]
                        foreach ($docKey in $docKeys) {Set-Variable -Name $docKey -Value $tabDoc[$docKey] -Scope Local}
                        $syntaxCache.Clear();$editorRowCache.Clear();$editorPaint.Invalid=$true;$zoomState.ResetArmed=$false
                    }
                    if ($closingTab -and $targetTab -eq $activeTab) {
                        $find.Active=$false;$k=@{Key='Escape';Ctrl=$false;KeyChar=[char]0};$ctrl=$false;$toolbarAction=''
                    } else {continue}
                }
                if ($toolbarAction -eq 'ResetZoom') {
                    $selection.Dragging=$false;$zoomState.ResetArmed=$true
                    continue
                }
                if ($zoomState.ResetArmed) {
                    if ($k.Key -eq 'MouseRelease') {
                        $zoomState.ResetArmed=$false
                        $inside=$false
                        foreach ($hit in $toolbarHits) {if ($hit.Action -eq 'ResetZoom' -and $k.Y -eq $hit.Y -and $k.X -ge $hit.Start -and $k.X -lt $hit.End) {$inside=$true;break}}
                        if ($inside) {
                            if (ResetEditorZoom) {$msg=NexL 'Zoom reset requested.';$editorPaint.Invalid=$true}
                            else {$msg=(NexL 'Zoom reset unavailable.')+' ['+$zoomState.Error+']'}
                        }
                        continue
                    }
                    if ($k.Key -eq 'MouseDrag') {continue}
                    $zoomState.ResetArmed=$false
                }
                if (-not $LogoMode -and (($ctrl -and $k.Key -eq 'F') -or [int]$k.KeyChar -eq 6 -or $toolbarAction -eq 'Find')) {
                    ClearEditorSelection;$find.Active=$true;$find.Query='';UpdateEditorFind;$editorRowCache.Clear();continue
                }
                if ($find.Active -and $k.Key -eq 'Click' -and $w -ge 30 -and $h -ge 12 -and $k.Y -ge $bodyStart -and $k.Y -lt $bodyEnd) {$find.Active=$false;$editorRowCache.Clear()}
                if ($find.Active) {
                    $changed=$false;$navigate=0
                    if ($k.Key -eq 'Escape') {$find.Active=$false;$editorRowCache.Clear();continue}
                    elseif ($k.Key -in @('Enter','DownArrow','RightArrow','F3')) {$navigate=1}
                    elseif ($k.Key -in @('UpArrow','LeftArrow')) {$navigate=-1}
                    elseif ($k.Key -eq 'Click') {
                        if ($toolbarAction -eq 'FindPrev') {$navigate=-1} elseif ($toolbarAction -eq 'FindNext') {$navigate=1}
                    } elseif ($k.Key -eq 'Backspace') {if ($find.Query.Length) {$find.Query=$find.Query.Substring(0,$find.Query.Length-1);$changed=$true}}
                    elseif ($k.Key -eq 'Delete') {$find.Query='';$changed=$true}
                    elseif ($k.Key -eq 'TextBatch' -or ($ctrl -and $k.Key -eq 'V') -or [int]$k.KeyChar -eq 22) {
                        try {$inputText=if ($k.Key -eq 'TextBatch') {$k.Text} else {Get-Clipboard -Raw -ErrorAction Stop};$find.Query+=([string]$inputText -replace '[\x00-\x1F]',' ');$changed=$true} catch {}
                    } elseif (-not $ctrl -and -not [char]::IsControl($k.KeyChar)) {$find.Query+=[string]$k.KeyChar;$changed=$true}
                    if ($changed) {if ($find.Query.Length -gt 256) {$find.Query=$find.Query.Substring(0,256)};UpdateEditorFind;MoveEditorFind 1 -Initial}
                    elseif ($navigate) {MoveEditorFind $navigate}
                    if ($changed -or $navigate) {$detachedScroll=$false;if ($find.Row -ge 0) {$r=$find.Row;$col=$find.Col};$editorRowCache.Clear()}
                    continue
                }
                if (($ctrl -and $k.Key -eq 'A') -or [int]$k.KeyChar -eq 1) {
                    $selection.Row=0;$selection.Col=0;$selection.Dragging=$false;$r=$buf.Count-1;$col=$buf[$r].Length;continue
                }
                $undoRequested=(($ctrl -and $k.Key -eq 'Z') -or [int]$k.KeyChar -eq 26)
                $redoRequested=(($ctrl -and $k.Key -eq 'Y') -or [int]$k.KeyChar -eq 25)
                if ($undoRequested -or $redoRequested) {
                    if ($redoRequested) {
                        if (-not $historyState.Redo.Count) {$msg=NexL 'Nothing to redo.';continue}
                        PushEditorSnapshot $history 'Chars'
                        $snapshot=$historyState.Redo[$historyState.Redo.Count-1];$historyState.Redo.RemoveAt($historyState.Redo.Count-1);$historyState.RedoChars-=$snapshot.Text.Length
                    } else {
                        if (-not $history.Count) {$msg=NexL 'Nothing to undo.';continue}
                        PushEditorSnapshot $historyState.Redo 'RedoChars'
                        $snapshot=$history[$history.Count-1];$history.RemoveAt($history.Count-1);$historyState.Chars-=$snapshot.Text.Length
                    }
                    $buf.Clear();$buf.AddRange([string[]]($snapshot.Text -split "`n"))
                    $r=$snapshot.Row;$col=$snapshot.Col;$top=$snapshot.Top;$left=$snapshot.Left
                    $selection.Row=$snapshot.AnchorRow;$selection.Col=$snapshot.AnchorCol;$selection.Dragging=$false
                    $dirty=($snapshot.Text -cne $historyState.Saved);$editorRowCache.Clear();$msg=if ($redoRequested) {NexL 'Redone.'} else {NexL 'Undone.'};continue
                }
                $copyRequested=(($ctrl -and $k.Key -eq 'C') -or [int]$k.KeyChar -eq 3)
                $cutRequested=(($ctrl -and $k.Key -eq 'X') -or [int]$k.KeyChar -eq 24)
                if ($copyRequested -or $cutRequested) {
                    $range=GetEditorSelection
                    if (-not $range) {$msg=NexL 'Select text first.';continue}
                    try {Set-Clipboard -Value (GetEditorSelectedText $range) -ErrorAction Stop}
                    catch {$msg=NexL 'Clipboard unavailable.';continue}
                    if ($cutRequested) {PushEditorUndo;$pos=RemoveEditorSelection $range;$r=$pos.Row;$col=$pos.Col;$dirty=$true;$msg=NexL 'Selection cut.'}
                    else {$msg=NexL 'Selection copied.'}
                    continue
                }
                # Mouse buttons, F2, and raw Ctrl+S all use the same save path.
                $saveRequested=($k.Key -eq 'F2' -or ($ctrl -and $k.Key -eq 'S') -or [int]$k.KeyChar -eq 19)
                $exitRequested=($k.Key -eq 'Escape')
                if ($k.Key -in @('Click','MouseDrag','MouseRelease')) {
                    if ($w -lt 30 -or $h -lt 12) {ClearEditorSelection;continue}
                    if ($k.Key -eq 'Click' -and $toolbarAction -eq 'Save') { $saveRequested=$true }
                    elseif ($k.Key -eq 'Click' -and $toolbarAction -eq 'Exit') { $exitRequested=$true }
                    elseif ($k.Key -eq 'Click' -and $k.Y -ge $bodyStart -and $k.Y -lt $bodyEnd) {
                        $detachedScroll=$false;$oldRow=$r;$oldCol=$col
                        $r=[Math]::Min($buf.Count-1,$top+$k.Y-$bodyStart)
                        $col=EditorColumnAtCell $buf[$r] $left ([Math]::Max(0,$k.X-8))
                        if ($k.Shift) {if ($selection.Row -lt 0) {$selection.Row=$oldRow;$selection.Col=$oldCol}}
                        else {$selection.Row=$r;$selection.Col=$col}
                        $selection.Dragging=$true
                    } elseif ($k.Key -in @('MouseDrag','MouseRelease') -and $selection.Dragging) {
                        $detachedScroll=$false;$mouseRow=[Math]::Max(0,[Math]::Min($view-1,$k.Y-$bodyStart))
                        if ($k.Y -lt $bodyStart -and $top -gt 0) {$top--}
                        elseif ($k.Y -ge $bodyEnd -and $top+$view -lt $buf.Count) {$top++}
                        $r=[Math]::Min($buf.Count-1,$top+$mouseRow)
                        if ($k.X -lt 8 -and $left -gt 0) {$left--}
                        elseif ($k.X -ge $w-1 -and $left+$avail -lt $buf[$r].Length) {$left++}
                        $col=EditorColumnAtCell $buf[$r] $left ([Math]::Max(0,$k.X-8))
                        if ($k.Key -eq 'MouseRelease') {$selection.Dragging=$false;if (-not (GetEditorSelection)) {ClearEditorSelection}}
                    }
                    if (-not $saveRequested -and -not $exitRequested) { continue }
                }
                $saveAndExit=$false
                if ($exitRequested) {
                    if (-not $dirty) { if ($LogoMode) {break};$closeNow=$true;continue }
                    $selection.Dragging=$false;$decision=EditorExitChoice;$editorPaint.Invalid=$true
                    if ($decision -eq 'Discard') { if ($LogoMode) {break};$closeNow=$true;continue }
                    if ($decision -ne 'Save') { continue }
                    $saveRequested=$true; $saveAndExit=$true
                }
                if ($saveRequested) {
                    if (-not $dirty) { if ($saveAndExit) {if ($LogoMode) {break};$closeNow=$true;continue}; $msg='Already saved.'; continue }
                    if ($LogoMode) {
                        $previousLogo=$prefs.CustomLogo
                        try {
                            $newLogo=Normalize-NexLogo ($buf -join "`n")
                            $prefs.CustomLogo=$newLogo
                            Save-NexPreferences
                            $dirty=$false; $historyState.Saved=$buf -join "`n"; ClearEditorSelection
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
                        $base64=$actual; $dirty=$false; $historyState.Saved=$buf -join "`n"; $msg='Saved.'
                    } catch { $msg='Save failed: '+$_.Exception.Message }
                    finally { if ($tmp -and [IO.File]::Exists($tmp)) { try { [IO.File]::Delete($tmp) } catch {} } }
                    if ($saveAndExit -and -not $dirty) { Notice 'File saved.'; $closeNow=$true;continue }
                    continue
                }
                if ($k.Key -eq 'TextBatch' -or ($ctrl -and $k.Key -eq 'V') -or [int]$k.KeyChar -eq 22) {
                    if ($k.Key -eq 'TextBatch') {$insert=$k.Text} else {try { $insert=Get-Clipboard -Raw -ErrorAction Stop } catch { $msg='Clipboard unavailable.'; continue }}
                    if ($insert -and $insert.Length -le 262144 -and $insert -notmatch '[\x00-\x08\x0B\x0C\x0E-\x1F]') {
                        PushEditorUndo;$range=GetEditorSelection;if ($range) {$pos=RemoveEditorSelection $range;$r=$pos.Row;$col=$pos.Col} else {ClearEditorSelection}
                        $parts=@($insert -split '\r\n|\r|\n'); $tail=$buf[$r].Substring($col); $prefix=$buf[$r].Substring(0,$col)
                        $buf[$r]=$prefix+$parts[0]; $col=$buf[$r].Length
                        if ($parts.Count -gt 1) {$buf.InsertRange($r+1,[string[]]$parts[1..($parts.Count-1)]);$r+=$parts.Count-1;$col=$parts[-1].Length}
                        $buf[$r]+=$tail; $dirty=$true
                    }; continue
                }
                if ($ctrl) { continue }
                $autoCode=(-not $LogoMode -and $item.Extension -in @('.py','.ps1','.psm1','.psd1','.js','.jsx','.ts','.tsx','.json','.css','.scss','.html','.htm','.xml','.yaml','.yml','.toml','.ini','.lua','.c','.h','.cpp','.hpp','.cs','.java','.go','.rs','.php','.sh','.sql','.rb'))
                $navigation=($k.Key -in @('UpArrow','DownArrow','LeftArrow','RightArrow','Home','End','PageUp','PageDown'))
                $editing=($k.Key -in @('Backspace','Delete','Enter','Tab') -or -not [char]::IsControl($k.KeyChar))
                $range=GetEditorSelection
                if ($autoCode -and -not $range -and -not $navigation -and -not [char]::IsControl($k.KeyChar) -and [string]$k.KeyChar -in @(')',']','}','"',"'") -and $col -lt $buf[$r].Length -and $buf[$r][$col] -ceq $k.KeyChar) {
                    $col++;ClearEditorSelection;continue
                }
                if ($navigation) {
                    if ($k.Shift) {if ($selection.Row -lt 0) {$selection.Row=$r;$selection.Col=$col};$selection.Dragging=$false}
                    else {
                        if ($range -and $k.Key -in @('LeftArrow','RightArrow')) {
                            if ($k.Key -eq 'LeftArrow') {$r=$range.A;$col=$range.AC} else {$r=$range.B;$col=$range.BC}
                            ClearEditorSelection;continue
                        }
                        ClearEditorSelection
                    }
                } elseif ($editing) {
                    $changes=$range -or ($k.Key -notin @('Backspace','Delete')) -or ($k.Key -eq 'Backspace' -and ($r -gt 0 -or $col -gt 0)) -or ($k.Key -eq 'Delete' -and ($r -lt $buf.Count-1 -or $col -lt $buf[$r].Length))
                    if ($changes) {PushEditorUndo}
                    if ($range) {
                        $pos=RemoveEditorSelection $range;$r=$pos.Row;$col=$pos.Col;$dirty=$true
                        if ($k.Key -in @('Backspace','Delete')) {continue}
                    } else {ClearEditorSelection}
                }
                switch ($k.Key.ToString()) {
                    'UpArrow' { $r=[Math]::Max(0,$r-1); $col=[Math]::Min($col,$buf[$r].Length) }
                    'DownArrow' { $r=[Math]::Min($buf.Count-1,$r+1); $col=[Math]::Min($col,$buf[$r].Length) }
                    'LeftArrow' { if ($col -gt 0) {$col=EditorPreviousColumn $buf[$r] $col} elseif ($r -gt 0) {$r--; $col=$buf[$r].Length} }
                    'RightArrow' { if ($col -lt $buf[$r].Length) {$col=EditorNextColumn $buf[$r] $col} elseif ($r -lt $buf.Count-1) {$r++;$col=0} }
                    'Home' { $col=0 }
                    'End' { $col=$buf[$r].Length }
                    'PageUp' { $r=[Math]::Max(0,$r-[Math]::Max(1,$view)); $col=[Math]::Min($col,$buf[$r].Length) }
                    'PageDown' { $r=[Math]::Min($buf.Count-1,$r+[Math]::Max(1,$view)); $col=[Math]::Min($col,$buf[$r].Length) }
                    'Enter' {
                        $tail=$buf[$r].Substring($col);$prefix=$buf[$r].Substring(0,$col);$buf[$r]=$prefix
                        $indent='';$extra=''
                        if ($autoCode) {
                            $indent=[regex]::Match($prefix,'^\s*').Value
                            if ($prefix.TrimEnd() -match '[{\[(]$' -or ($item.Extension -ieq '.py' -and $prefix.TrimEnd().EndsWith(':'))) {$extra='    '}
                        }
                        $r++;$buf.Insert($r,$indent+$extra+$tail);$col=($indent+$extra).Length
                        if ($autoCode -and $extra) {
                            $endOfPrefix=$prefix.TrimEnd();$startOfTail=$tail.TrimStart()
                            if (($endOfPrefix.EndsWith('{') -and $startOfTail.StartsWith('}')) -or ($endOfPrefix.EndsWith('[') -and $startOfTail.StartsWith(']')) -or ($endOfPrefix.EndsWith('(') -and $startOfTail.StartsWith(')'))) {
                                $buf[$r]=$indent+$extra;$buf.Insert($r+1,$indent+$startOfTail)
                            }
                        }
                        $dirty=$true
                    }
                    'Backspace' { if ($col -gt 0) { $previous=EditorPreviousColumn $buf[$r] $col;$buf[$r]=$buf[$r].Remove($previous,$col-$previous);$col=$previous;$dirty=$true } elseif ($r -gt 0) { $tail=$buf[$r];$buf.RemoveAt($r);$r--;$col=$buf[$r].Length;$buf[$r]+=$tail;$dirty=$true } }
                    'Delete' { if ($col -lt $buf[$r].Length) { $next=EditorNextColumn $buf[$r] $col;$buf[$r]=$buf[$r].Remove($col,$next-$col);$dirty=$true } elseif ($r -lt $buf.Count-1) { $buf[$r]+=$buf[$r+1];$buf.RemoveAt($r+1);$dirty=$true } }
                    'Tab' {
                        if ($editorCompletion -and -not $range -and -not $k.Shift -and $editorCompletion.Row -eq $r -and $editorCompletion.Col -eq $col) {
                            $insertCompletion=$editorCompletion.Suffix
                            $buf[$r]=$buf[$r].Insert($col,$insertCompletion);$col+=$insertCompletion.Length
                        } else {$buf[$r]=$buf[$r].Insert($col,'    ');$col+=4}
                        $dirty=$true
                    }
                    default {
                        if (-not [char]::IsControl($k.KeyChar)) {
                            $typed=[string]$k.KeyChar;$line=$buf[$r]
                            $pairs=@{'('=')';'['=']';'{'='}';'"'='"';"'"="'"}
                            $next=if ($col -lt $line.Length) {[string]$line[$col]} else {''}
                            $prev=if ($col -gt 0) {[string]$line[$col-1]} else {''}
                            # Pasted text is handled above, without any auto-pair transformations.
                            $canPair=$autoCode -and $pairs.ContainsKey($typed) -and (-not $next -or $next -match '[\s,;:)}\]]')
                            if ($typed -in @('"',"'") -and ($prev -match '[\w\\]' -or $next -match '\w')) {$canPair=$false}
                            if ($canPair) {$buf[$r]=$line.Insert($col,$typed+$pairs[$typed]);$col++}
                            else {$buf[$r]=$line.Insert($col,$typed);$col++}
                            $dirty=$true
                        }
                    }
                }
                if ($col -gt 0 -and $col -lt $buf[$r].Length -and [char]::IsLowSurrogate($buf[$r][$col])) {$col--}
            }
        } finally {
            Write-Host "$e[?25l" -NoNewline
            if ($editorNative) { [NexDash.NativeInput216]::Restore($editorMode) } else { ResumeMouse }
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
        if ($key -eq 'L') {if (-not $s.Task) {$root=if ($s.Drives -and $s.FileItems.Count) {$s.FileItems[$s.Pos].Root} else {$s.Folder};if ($root -ne $s.DiskRoot) {$s.DiskReport=$null};$s.DiskRoot=$root};ChoosePage 22;return}
        if ($key -eq 'F7') {
            $options=@('Register Windows editor','Remove Windows editor registration');$v=Ask 'Windows Open with' @($options | ForEach-Object {NexL $_}) $options -helpKey 'Editor association help'
            if ($v -in $options -and (ConfirmNex $v 'NEX Terminal Editor' 'Does not change default file associations.')) {
                Set-NexEditorAssociation ($v -eq $options[0]);Notice $(if ($v -eq $options[0]) {'Editor registered.'} else {'Editor registration removed.'})
            };return
        }
        if ($key -eq 'D') { $s.Drives=$true; $s.Pos=0; $s.FileItems=@(); RefreshFiles; return }
        if ($key -eq 'P') { $v=Ask 'Folder path' -initialText $(if (-not $s.Drives) {$s.Folder} else {''}); if ($v) { GoFolder $v }; return }
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
                $suffix='';$stem=$item.Name
                if (-not $item.PSIsContainer) {
                    $candidate=[IO.Path]::GetExtension($item.Name)
                    if ($candidate -and $candidate.Length -lt $item.Name.Length) {$suffix=$candidate;$stem=$item.Name.Substring(0,$item.Name.Length-$suffix.Length)}
                }
                $v=Ask 'Rename' -initialText $stem -renameSuffix $suffix -renameOriginal $item.Name -helpKey 'Rename help'
                if ($v) { try {
                    $v=RenameFullName $v $suffix
                    FileNameValid $v
                    if ($v -ceq $item.Name) {return}
                    if ($v -ine $item.Name -and (Test-Path -LiteralPath (Join-Path $s.Folder $v))) { throw 'Name already exists.' }
                    Rename-Item -LiteralPath $item.FullName -NewName $v -ErrorAction Stop; RefreshFiles; Notice 'Renamed.'
                } catch { Notice (NexL $_.Exception.Message) } }
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
    function ClearNexHandoff {
        if ($s.HandoffToken) {
            foreach ($kind in @('pending','ready')) {
                try {Remove-Item -LiteralPath (Get-NexHandoffPath $s.HandoffToken $kind) -Force -ErrorAction SilentlyContinue} catch {}
            }
            $s.HandoffToken=''
        }
    }
    function SwitchNexPrivilege([switch]$ForScan) {
        if ($s.HandoffToken -or $s.ScanActive -or $s.SpeedProc -or $s.PendingInstaller) {Notice 'Finish the active operation first.';return}
        $target=-not $isAdmin
        $title=if ($target) {'Run as administrator'} else {'Open normal terminal'}
        $detail=if ($target) {'Windows will ask for permission.'} else {'Switch to a standard PowerShell session.'}
        if (-not (ConfirmNex $title (NexL $detail) (NexL 'This PowerShell session closes after successful switching.'))) {return}
        $geometry=Get-NexPrivilegeGeometry
        $token=[guid]::NewGuid().ToString('N')
        $pending=Get-NexHandoffPath $token pending
        $null=New-Item -ItemType Directory -Path (Split-Path -Parent $pending) -Force -ErrorAction Stop
        $s.HandoffToken=$token
        try {
            [IO.File]::WriteAllText($pending,$token,[Text.Encoding]::ASCII)
            $scan=($ForScan -or ($s.Page -eq 7 -and $s.ScanView))
            Open-NexPrivilegeWindow -Elevated $target -Page $s.Page -StartScan:$scan -HandoffToken $token -Geometry $geometry
            # Renew the marker after UAC; the child may already have acknowledged it.
            if (Test-Path -LiteralPath $pending) {[IO.File]::SetLastWriteTimeUtc($pending,[datetime]::UtcNow)}
            $s.HandoffDeadline=$clock.ElapsedMilliseconds+45000
            Notice 'Switching terminal mode...'
        } catch {ClearNexHandoff;throw}
    }
    function ToolAction($key) {
        if ($key -eq 'V') {
            $wasOpen=$s.ScanView;$s.ScanView=$true
            if (-not $s.ScanActive -and ($wasOpen -or -not $s.ScanResults.Count)) {$s.ScanResults=@{};$s.ScanIndex=0;$s.ScanStop=$false;$s.ScanActive=$true;$s.ScanPos=0;$s.ScanSelected=''}
            return
        }
        if ($s.ScanView) {
            if ($key -eq 'B') {$s.ScanView=$false;return}
            if ($key -eq 'K') {$s.ScanStop=$true;return}
            if ([string]$key -like 'scanselect:*') {$s.ScanSelected=([string]$key).Substring(11);$s.ScanPos=-1;return}
            if ($key -eq 'Enter' -and $s.ScanSelected) {$key='diag:'+$s.ScanSelected}
            if ([string]$key -like 'diag:*') {
                $step=([string]$key).Substring(5);$result=$s.ScanResults[$step]
                if (-not $result) {return}
                switch ($result.Action) {
                    'Restart' {
                        if ($s.ScanActive) {Notice 'Finish the scan before restarting.';return}
                        $info=New-Object -ComObject Microsoft.Update.SystemInfo
                        try {
                            if (-not $info.RebootRequired) {Notice 'Restart is no longer required.';return}
                            if (ConfirmNex 'Restart computer?' (NexL 'Save your work before restarting.') 'Windows will restart after confirmation.') {Restart-Computer -ErrorAction Stop}
                        } finally {if ($info) {$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($info)}}
                    }
                    'Device Manager' {Start-Process devmgmt.msc}
                    'Memory diagnostics' {Start-Process mdsched.exe}
                    'Run as administrator' {
                        if (-not $isAdmin) {SwitchNexPrivilege -ForScan}
                    }
                    'Disk health' {$s.ScanView=$false;ToolAction 'D'}
                    'Network settings' {Start-Process 'ms-settings:network-status'}
                    'Windows Security' {Start-Process 'windowsdefender:'}
                    'Event Viewer' {Start-Process eventvwr.msc}
                }
                return
            }
            $s.ScanPos=ScrollPos $key $s.ScanPos ([Math]::Max(1,$s.ScanDisplayCount));return
        }
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
        $pack=[ordered]@{Format='NEX-Portable-Configuration';Schema=1;Version='2.7.0';Preferences=(Get-NexBackupPreferences ([pscustomobject]$prefs));Appearance=$a;Scheme=$scheme;CustomFetch=$custom;CustomFetchOmitted=$omitted;HasTerminalAppearance=[bool]$s.Config}
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
            Write-Host "$reset$e[?25h$e[2J$e[H$pink$(NexL 'Restoring configuration...')$reset"
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

    function ResetNexDashboard {
        if (-not (ConfirmNex 'Reset Dashboard to defaults' (NexL 'All NEX preferences will be reset.') 'Your files and installed programs are kept.')) {return}
        $dir=Join-Path $env:LOCALAPPDATA 'NexDashboard'
        $backup=Join-Path $dir ('reset-backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        $null=New-Item -ItemType Directory -Path $backup -Force -ErrorAction Stop
        $files=@('preferences.json','restored-fastfetch.json','ookla-consent.json','events-cleared.utc')
        foreach ($name in $files) {
            $p=Join-Path $dir $name
            if (Test-Path -LiteralPath $p -PathType Leaf) {Copy-Item -LiteralPath $p -Destination (Join-Path $backup $name) -ErrorAction Stop}
        }
        $old=$prefs.Clone()
        try {
            $defaults=Get-NexPreferences -DefaultsOnly
            $prefs.Clear();foreach ($k in $defaults.Keys) {$prefs[$k]=$defaults[$k]}
            $global:NexPublicSettings=$prefs
            Save-NexPreferences
            foreach ($name in @('restored-fastfetch.json','ookla-consent.json','events-cleared.utc')) {
                $p=Join-Path $dir $name
                if (Test-Path -LiteralPath $p -PathType Leaf) {Remove-Item -LiteralPath $p -Force -ErrorAction Stop}
            }
        } catch {
            $prefs.Clear();foreach ($k in $old.Keys) {$prefs[$k]=$old[$k]}
            $global:NexPublicSettings=$prefs
            foreach ($name in $files) {
                $p=Join-Path $backup $name
                if (Test-Path -LiteralPath $p -PathType Leaf) {Copy-Item -LiteralPath $p -Destination (Join-Path $dir $name) -Force -ErrorAction SilentlyContinue}
            }
            throw
        }
        $s.EventCutoff=0L;$s.AlertDismiss=@{};$s.Alerts=@();$s.SpeedConsentHash='';$s.NavOffset=0;$s.PersonalPos=0;$s.HealthNext=0L
        try {Set-PSReadLineOption -PredictionSource $prefs.Prediction -ErrorAction Stop} catch {}
        try {
            $changes=Get-NexSharedPaletteChanges
            $changes.opacity=85;$changes.useAcrylic=$true;$changes.cursorShape='bar'
            $null=Sync-NexTerminalAppearance $changes (Get-NexSharedScheme)
            ReadConfig;Notice 'Dashboard reset. Backup saved. Reopen terminal tabs if needed.'
        } catch {Notice ('Dashboard reset. Terminal: '+$_.Exception.Message)}
        ResetDraw
    }
    function PublicAction($key) {
        $changed=$true
        switch ($key) {
            'G' {$v=ChooseNexToggle 'Setting explanations' ([bool]$prefs.SettingHelp) $global:NexPersonalHelp['G'];if ($null -ne $v) {$prefs.SettingHelp=$v} else {$changed=$false}}
            'A' {$v=ChooseNexToggle 'Sidebar separators' ([bool]$prefs.SidebarSeparators) $global:NexPersonalHelp['A'];if ($null -ne $v) {$prefs.SidebarSeparators=$v;$s.NavOffset=0} else {$changed=$false}}
            'L' {$v=Ask 'Choose language' @('English','Русский','Deutsch') @('en','ru','de');if ($v -in @('en','ru','de')) {$prefs.Language=$v} else {$changed=$false}}
            'N' {$v=Ask 'Enter display name' @((NexL 'Use Windows account name')) @('__default__');if ($v -eq '__default__') {$prefs.Name=''} elseif ($v) {$prefs.Name=(SafeText $v).Trim();if ($prefs.Name.Length -gt 32) {$prefs.Name=$prefs.Name.Substring(0,32)}} else {$changed=$false}}
            'W' {$prefs.LightMode=-not [bool]$prefs.LightMode}
            'Delete' {$changed=$false;ResetNexDashboard}
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
                            try {Write-Host "$reset$e[?25h$e[2J$e[H" -NoNewline;$null=Install-NexFastfetch;$fetchState.Available=$true}
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
                    Write-Host "$reset$e[?25h$e[2J$e[H" -NoNewline
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
                try {Write-Host "$reset$e[?25h$e[2J$e[H" -NoNewline;Show-NexPublicFetch;Write-Host "`nEsc / Enter"; $null=[Console]::ReadKey($true)} finally {ResumeMouse;Write-Host "$e[?25l" -NoNewline;ResetDraw}
            }
            default {$changed=$false}
        }
        if ($changed) {
            Save-NexPreferences;Notice 'Preferences saved.'
            if ($key -eq 'V') {Notice 'New shells use the saved preset.'}
            if ($key -in @('H','X','W')) {
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
    function MonitorCard($title,$content,[int]$width,[int]$height,[string]$color,[string]$fill='',[string]$id='') {
        $pulseWave=$s.DragPulse -and -not $s.DragSwapOrder -and $id -in @($s.DragPulse,$s.DragOther)
        $rowFill=$fill
        $inner=$width-2; $t=' '+(SafeText $title)+' '
        $t=(Fit $t ([Math]::Min($inner,$t.Length))).TrimEnd()+' '
        if ($t.Length -gt $inner) {$t=Fit $t $inner}
        $l=[int][Math]::Floor(($inner-$t.Length)/2); $r=$inner-$t.Length-$l
        "$fill$color╭$('─'*$l)$t$('─'*$r)╮$reset"
        for ($i=0;$i -lt $height;$i++) {
            $line=if ($i -lt $content.Count) {ClipAnsi ([string]$content[$i]) ($inner-2)} else {''}
            $plain=$line -replace '\x1b\[[0-9;]*m',''
            $len=([Globalization.StringInfo]::new($plain)).LengthInTextElements
            $padding=[Math]::Max(0,$inner-1-$len)
            $rowFill=$fill
            if ($pulseWave) {
                $progress=1.0-($s.DragPulseUntil-$clock.ElapsedMilliseconds)/420.0
                $local=[Math]::Max(0.0,[Math]::Min(1.0,($progress-0.36*($i/[double][Math]::Max(1,$height-1)))/0.64))
                $strength=0.56*[Math]::Pow(1.0-$local,2)
                $rowFill=if ($strength -gt 0.01) {NexAnsi (Mix-NexColor $palette[3] $palette[0] $strength) -Background} else {''}
            }
            if ($rowFill) {$line=$line.Replace("$e[0m","$e[0m$rowFill")}
            "$rowFill$color│$reset$rowFill $line$(' '*$padding)$color│$reset"
        }
        "$fill$color╰$('─'*$inner)╯$reset"
    }
    function MonitorLayout($d,[int]$width) {
        $two=($width -ge 76 -and $prefs.MonitorColumns -ne 'Single column'); $cardWidth=if ($two) {[Math]::Min(60,[int][Math]::Floor(($width-3)/2.0))} else {[Math]::Min(70,$width-1)}
        $inner=$cardWidth-4; $gap='   '
        $cpuUi=SmoothNumber 'monitor-cpu' $(if ($null -ne $s.LiveCpu) {$s.LiveCpu} else {$d.CPU}) 0.18
        $ramUi=SmoothNumber 'monitor-ram' $(if ($null -ne $s.LiveRam) {$s.LiveRam} else {$d.RAM}) 0.18
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
            (MonitorField 'Memory' ('{0:0.0} / {1:0.0} GiB' -f (SmoothNumber 'monitor-used' $(if ($null -ne $s.LiveUsed) {$s.LiveUsed} else {$d.Used}) 0.18),$d.Total) $inner)
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
        $ordered=@();$displayOrder=if ($s.DragCard -and $s.DragOrder) {$s.DragOrder} else {$prefs.MonitorOrder};foreach ($id in ($displayOrder -split ',')) {if ($id -notin ($prefs.MonitorHidden -split ',')) {$ordered+=@($cards | Where-Object {$_.Id -eq $id})}}
        if ($ordered.Count) {$cards=$ordered}
        $pad=' '*[Math]::Max(0,[int][Math]::Floor(($width-$(if ($two) {2*$cardWidth+3} else {$cardWidth}))/2.0))
        foreach ($card in $cards) {
            $card.Fill=DragFill $card.Id
            if ($s.DragCard -eq $card.Id) {$card.Color=$pink;$card.Title='◆ '+$card.Title}
            elseif ($s.DragCard -and $s.DragHover -eq $card.Id) {$card.Color=$pink;$card.Title='↔ '+$card.Title}
        }
        $s.CardTargets=@();$row=0
        if ($two) {
            for ($i=0;$i -lt $cards.Count;$i+=2) {
                $a=$cards[$i];$s.CardTargets+=@(@{Row=$row;X=$pad.Length;Width=$cardWidth;Id=$a.Id;Height=($a.Rows.Count+2)})
                if ($i+1 -ge $cards.Count) {foreach ($line in @(MonitorCard $a.Title $a.Rows $cardWidth $a.Rows.Count $a.Color $a.Fill $a.Id)) {"$pad$line"};break}
                $b=$cards[$i+1];$s.CardTargets+=@(@{Row=$row;X=($pad.Length+$cardWidth+3);Width=$cardWidth;Id=$b.Id;Height=([Math]::Max($a.Rows.Count,$b.Rows.Count)+2)});$height=[Math]::Max($a.Rows.Count,$b.Rows.Count);$s.CardTargets[$s.CardTargets.Count-2].Height=$height+2
                $left=@(MonitorCard $a.Title $a.Rows $cardWidth $height $a.Color $a.Fill $a.Id)
                $right=@(MonitorCard $b.Title $b.Rows $cardWidth $height $b.Color $b.Fill $b.Id)
                for ($j=0;$j -lt $left.Count;$j++) {"$pad$($left[$j])$gap$($right[$j])"}
                $row+=$left.Count;if ($i+2 -lt $cards.Count) {'';$row++}
            }
        } else {
            foreach ($a in $cards) {
                $s.CardTargets+=@(@{Row=$row;X=$pad.Length;Width=$cardWidth;Id=$a.Id;Height=($a.Rows.Count+2)})
                foreach ($line in @(MonitorCard $a.Title $a.Rows $cardWidth $a.Rows.Count $a.Color $a.Fill $a.Id)) {"$pad$line";$row++}
                '';$row++
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
            [pscustomobject]@{Tag=$tag;Version=$v.ToString();Newer=($v -gt [version]'2.7.0');Comparable=$true;Available=[bool]$valid;Url=$url;Hash=$hash;Size=$(if ($valid) {[long]$asset[0].size} else {0});Beta=[bool]$r.prerelease;Reason=$(if ($valid) {''} else {'Release installer or SHA-256 unavailable.'});At=Get-Date}
        } finally {[Net.ServicePointManager]::SecurityProtocol=$oldTls}
    }
    $onlineDownloadScript={
        param($a)
        $ErrorActionPreference='Stop'
        $oldTls=[Net.ServicePointManager]::SecurityProtocol
        try {
            [Net.ServicePointManager]::SecurityProtocol=$oldTls -bor [Net.SecurityProtocolType]::Tls12
            $version=[version]$a.Version
            if ($version -le [version]'2.7.0' -or $a.Tag -notmatch '^v?(\d+\.\d+\.\d+)(?:-beta(?:[.-]\d+)?)?$' -or [version]$Matches[1] -ne $version) {throw 'Invalid update version.'}
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
    function SetNexReleaseResult($result) {
        $s.Release=$result;$s.ReleaseSource='owoNEXowo/NEX-Dashboard'
        $s.ReleaseBadge=[bool]($result.Comparable -and $result.Newer)
        $s.ReleaseBadgeAt=$clock.ElapsedMilliseconds;$s.Need=$true
    }
    function PollNexReleaseProbe {
        if ($s.ReleaseProbeJob -and $s.ReleaseProbeJob.IsCompleted) {
            try {
                $result=@($s.ReleaseProbeWorker.EndInvoke($s.ReleaseProbeJob))
                if ($result.Count) {SetNexReleaseResult $result[-1];if ($s.ReleaseProbeManual) {$s.OnlineReady=$s.OnlineRequested}}
                elseif ($s.ReleaseProbeManual) {throw 'Query failed or access denied.'}
            } catch {if ($s.ReleaseProbeManual) {$s.ExtraErrors['release']=[string]$_.Exception.Message;$s.OnlineReady=$false;Notice $_.Exception.Message}} finally {
                if ($s.ReleaseProbeManual) {$s.ReleaseFinishAt=$clock.ElapsedMilliseconds;$s.OnlineRequested=$false;$s.ReleaseProbeManual=$false}
                $s.ReleaseProbeWorker.Dispose();$s.ReleaseProbeWorker=$null;$s.ReleaseProbeJob=$null;$s.Need=$true
            }
        }
        if (-not $s.ReleaseProbeStarted -and $clock.ElapsedMilliseconds -ge 3500 -and -not $s.Preview -and -not $s.ScanActive -and -not $s.Task -and $s.Page -notin @(7,21,22)) {
            $s.ReleaseProbeStarted=$true
            try {
                $s.ReleaseProbeWorker=[PowerShell]::Create();$null=$s.ReleaseProbeWorker.AddScript($releaseScript.ToString());$s.ReleaseProbeJob=$s.ReleaseProbeWorker.BeginInvoke()
            } catch {if ($s.ReleaseProbeWorker) {$s.ReleaseProbeWorker.Dispose()};$s.ReleaseProbeWorker=$null;$s.ReleaseProbeJob=$null}
        }
    }
    function StartNexReleaseCheck([bool]$install) {
        if ($s.Job) {Notice 'Another query is running.';return}
        $s.ReleaseProbeStarted=$true
        $s.OnlineReady=$false;$s.OnlineRequested=$install;$s.Release=$null;$s.ExtraErrors.Remove('release')
        $s.ReleaseCheckAt=$clock.ElapsedMilliseconds;$s.ReleaseFinishAt=-10000L
        # Adopt an in-flight passive query rather than start another TLS request.
        if ($s.ReleaseProbeJob) {$s.ReleaseProbeManual=$true;Notice 'Checking for releases...';return}
        StartWorker 'release' $releaseScript
        if (-not $s.Job) {$s.ReleaseFinishAt=$clock.ElapsedMilliseconds}
        Notice 'Checking for releases...'
    }
    function NexReleaseGlow([string]$kind) {
        $now=$clock.ElapsedMilliseconds;$strength=0.0
        if ($kind -eq 'badge' -and $s.ReleaseBadge) {
            $t=[Math]::Max(0.0,[Math]::Min(1.0,($now-$s.ReleaseBadgeAt)/1400.0))
            $strength=0.28+0.38*[Math]::Pow(1.0-$t,2)
        } elseif ($kind -eq 'check') {
            if ((($s.Job -and $s.JobKind -eq 'release') -or $s.ReleaseProbeManual) -and $s.ReleaseCheckAt -ge 0) {$strength=0.22+0.38*(0.5+0.5*[Math]::Cos(($now-$s.ReleaseCheckAt)/240.0))}
            elseif ($s.ReleaseFinishAt -ge 0 -and ($now-$s.ReleaseFinishAt) -lt 1400) {$strength=0.60*[Math]::Pow(1.0-[Math]::Max(0.0,($now-$s.ReleaseFinishAt)/1400.0),2)}
        }
        if ($strength -le 0.015) {return ''}
        $hue=if ($prefs.LightMode) {'21683E'} else {'63D88B'}
        return (NexAnsi (Mix-NexColor $palette[3] $hue $strength) -Background)
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
        if ($ver -lt [version]'2.7.0') {Notice 'Select a newer installer.';return}
        if (ConfirmNex 'Install local update' ("NEX Dashboard $ver") (NexL 'Only run installers from a source you trust.')) {$s.PendingInstaller=$path;$s.PendingVersion=$ver}
    }
    function ShowNexReleaseDetails([string]$kind) {
        $width=[Console]::WindowWidth
        if ($width -ge 88) {$width-=29} else {$width-=3}
        $width=[Math]::Max(12,$width-2)
        $lines=New-Object 'System.Collections.Generic.List[string]'
        if ($kind -eq 'about') {
            $title=NexL 'About NEX Dashboard'
            $raw=@('NEX Dashboard 2.7.0',(NexL 'Public Edition'),'',(NexL 'A customizable PowerShell dashboard for monitoring, tools and terminal appearance.'),'',(NexL 'Supports English, Russian and German.'),(NexL 'Local updates keep your personal settings.'),'',(NexL 'Official releases are checked before installation.'),(NexL 'Local updates reload Dashboard in this terminal.'))
        } else {
            $title=NexL 'Version history'
            $raw=@((NexL 'Recent release notes'),'')
            $raw+=@('  2.7.0',(NexL 'Editor tabs, syntax highlighting, search, mouse selection, clipboard, undo/redo, inline completion, auto-pairs and bracket matching.'),(NexL 'Clickable path breadcrumbs, rename preview with preserved extension, optional NEX Terminal Editor registration in Windows.'),(NexL 'Large file and folder search; CPU, RAM and GPU benchmarks with memory budgets, cancellation and reports.'),(NexL 'Theme-based light mode, favorites, adaptive sidebar, compact layout, drag-and-drop monitor cards and extra status widgets.'),(NexL 'Read-only full PC scan, preference reset with backup, F8 privilege switching and animated update indicators.'),'')
            $raw+=@('  2.6.2',(NexL 'Adaptive sidebar and startup layouts, per-process CPU/RAM/GPU metrics, persistent Ookla consent and separate restart indicators.'),'')
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
        $english=@('Overview','System Monitor','Processes','Network','File Explorer','System Info','Windows Update','Quick Tools','System Logs','Terminal Settings','Personalization','Hardware Info','Gaming Mode','App Launcher','Update Center','System Health','Notification Center','Dashboard Designer','Startup Manager','Plugin Manager','Animation Studio','Benchmark Center','Large files and folders')
        foreach ($id in @(NavOrder)) {$label=$names[$id];if ($label -cne $english[$id]) {$label+=' / '+$english[$id]};$labels+=@($label);$ids+=@([string]$id)}
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
                if ($key -eq 'H') {
                    $blocks=@('Identity','Metrics','Actions','Favorites');$hidden=@(($prefs.OverviewHidden -split ',') | Where-Object {$_})
                    $labels=@(foreach ($block in $blocks) {$(if ($block -in $hidden) {'[ ] '} else {'[✓] '})+(NexL $block)})
                    $v=Ask 'Show or hide home block' $labels $blocks
                    if ($v -in $blocks) {if ($v -in $hidden) {$hidden=@($hidden | Where-Object {$_ -ne $v})} else {$hidden+=@($v)};$prefs.OverviewHidden=$hidden -join ',';NexSaveExtras};return
                }
                if ($key -eq 'J') {$prefs.OverviewHidden='';NexSaveExtras;return}
                if ($key -eq 'F') {
                    $ids=@($baseNavOrder | Where-Object {$_ -ne 0});$fav=@(FavoriteIds);$labels=@(foreach ($id in $ids) {$(if ($id -in $fav) {'[★] '} else {'[ ] '})+$names[$id]})
                    $v=Ask 'Choose section' $labels @($ids | ForEach-Object {[string]$_});if ($v -match '^\d+$') {ToggleFavorite ([int]$v)};return
                }
                if ($key -eq 'K') {$prefs.CompactMode=if ($prefs.CompactMode -eq 'Compact') {'Auto'} else {'Compact'};NexSaveExtras;return}
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
                    'R' {$v=ChooseNexToggle 'Resource module' ([bool]$prefs.ModuleResources) 'Shows cached CPU and RAM usage in the header.';if ($null -ne $v) {$prefs.ModuleResources=$v;NexSaveExtras}}
                    'A' {$v=ChooseNexToggle 'Alerts module' ([bool]$prefs.ModuleAlerts) 'Shows the number of current notifications.';if ($null -ne $v) {$prefs.ModuleAlerts=$v;NexSaveExtras}}
                    'D' {$v=ChooseNexToggle 'Disk module' ([bool]$prefs.ModuleDisk) 'Shows free space on the Windows drive.';if ($null -ne $v) {$prefs.ModuleDisk=$v;NexSaveExtras}}
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
        foreach ($module in @(NexExtraModules)) {$bodyHits[$body.Count]=@{Kind='nav';Index=$module.Page};$body.Add($module.Text)}
        if ($prefs.ModuleShortcuts) {$bodyHits[$body.Count]=@{Kind='nav';Index=13};$body.Add("$green$(Icon 0xF135) $(NexL 'App Launcher')$reset");$bodyHits[$body.Count]=@{Kind='nav';Index=17};$body.Add("$pink$(Icon 0xF009) $(NexL 'Dashboard Designer')$reset")}
    }
    function NexExtraModules {
        if ($prefs.ModuleResources) {
            $d=$s.AlertOverview
            $c=if ($null -ne $s.LiveCpu) {$s.LiveCpu} elseif ($d) {$d.CPU} else {$null}
            $m=if ($null -ne $s.LiveRam) {$s.LiveRam} elseif ($d) {$d.RAM} else {$null}
            $value=if ($null -ne $c -and $null -ne $m) {'CPU {0:0}% / RAM {1:0}%' -f (SmoothNumber 'header-cpu' $c 0.18),(SmoothNumber 'header-ram' $m 0.18)} else {'CPU — / RAM —'}
            [pscustomobject]@{Text="$purple$(Icon 0xF2DB) $value$reset";Page=1}
        }
        if ($prefs.ModuleAlerts) {[pscustomobject]@{Text="$pink$(Icon 0xF0F3) $(NexL 'Notifications'): $(@($s.Alerts).Count)$reset";Page=16}}
        if ($prefs.ModuleDisk) {
            if ($null -eq $s.ModuleDiskAt -or $clock.ElapsedMilliseconds -ge $s.ModuleDiskAt) {
                $s.ModuleDiskAt=$clock.ElapsedMilliseconds+10000;$s.ModuleDiskValue='—';try {$drive=[IO.DriveInfo]::new($env:SystemDrive+'\');$s.ModuleDiskValue=('{0:0} GiB' -f ($drive.AvailableFreeSpace/1GB))} catch {}
            }
            [pscustomobject]@{Text="$green$(Icon 0xF0A0) $env:SystemDrive $($s.ModuleDiskValue)$reset";Page=4}
        }
    }
    function NexHeaderModules {
        NexExtraModules
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
        if ($s.Page -in @(21,22)) {NewTaskAction $key;return}
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
        if ($s.Page -in @(21,22)) {RenderNexTaskPage $body $bodyHits;return}
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
                EHead 'NEX Dashboard' 0xF021; $body.Add((Label 'Installed version' '2.7.0'));$body.Add((Label 'Release repository' 'owoNEXowo/NEX-Dashboard'))
                $body.Add('');$bodyHits[$body.Count]=@{Kind='extra';Index='U'}
                $installGlow=if ($s.Release -and $s.Release.Newer -and $s.Release.Available) {NexReleaseGlow 'badge'} else {''}
                $body.Add("$installGlow$green[U] $(Icon 0xF019)  $(NexL 'Download and install update')$reset")
                $bodyHits[$body.Count]=@{Kind='extra';Index='R'};$checkGlow=NexReleaseGlow 'check'
                if ($checkGlow) {$body.Add("$checkGlow$green[R] $(Icon 0xF021)  $(NexL 'Check for releases')$reset")}
                else {$body.Add("$purple[R] $(Icon 0xF021)  $white$(NexL 'Check for releases')$reset")}
                EButton 'O' 'Open releases' 0xF0AC
                if ($s.Job -and $s.JobKind -eq 'release-download') {$body.Add("$pink$(NexL 'Downloading and verifying update...')$reset")}
                elseif (($s.Job -and $s.JobKind -eq 'release') -or $s.ReleaseProbeJob) {$body.Add("$gray$(NexL 'Checking for releases...')$reset")}
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
                EHead 'Home layout' 0xF015
                EButton 'H' 'Show or hide home block' 0xF06E; EButton 'J' 'Reset home layout' 0xF021
                EButton 'F' 'Pin / unpin section' 0xF005
                $bodyHits[$body.Count]=@{Kind='extra';Index='K'};$body.Add((SettingLine '[K] Compact mode' (NexL $prefs.CompactMode) $rightWidth))
                EHead 'Card order' 0xF0C9 (NexAnsi '89B4FA')
                $body.Add("$gray$(NexL 'Drag rows to reorder; click to toggle')$reset")
                $cardIcons=@{Processor=0xF2DB;Graphics=0xF108;Memory=0xEFC5;Storage=0xF0A0;Network=0xF1EB;System=0xF013}
                $num=0;$displayOrder=if ($s.DragCard -and $s.DragOrder) {$s.DragOrder} else {$prefs.MonitorOrder};foreach ($id in ($displayOrder -split ',')) {$num++;$shown=$id -notin ($prefs.MonitorHidden -split ',');$mark=if ($shown) {"$green[✓]"} else {"$gray[ ]"};$bodyHits[$body.Count]=@{Kind='extra';Index=('card:'+$id)};$style=if ($id -eq $s.DragCard) {"$bg$pink"} elseif (($s.DragCard -and $s.DragHover -eq $id) -or ($s.DragPulse -and $id -in @($s.DragPulse,$s.DragOther))) {"$(DragFill $id)$white"} else {$white};$body.Add("$mark $purple$num. $(Icon $cardIcons[$id]) $style$(NexL $id)$(if ($id -eq $s.DragCard) {'  ◆'})$reset")}
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
                foreach ($row in @(@('B','Battery module','ModuleBattery','Shows battery charge and power status in the header on supported PCs.',0xF240),@('S','Session module','ModuleSession','Shows elapsed Dashboard session time in the header.',0xF017),@('Q','Shortcut module','ModuleShortcuts','Adds header shortcuts to App Launcher and Dashboard Designer.',0xF135),@('R','Resource module','ModuleResources','Shows cached CPU and RAM usage in the header.',0xF2DB),@('A','Alerts module','ModuleAlerts','Shows the number of current notifications.',0xF0F3),@('D','Disk module','ModuleDisk','Shows free space on the Windows drive.',0xF0A0))) {
                    $state=if ($prefs[$row[2]]) {'Enabled'} else {'Disabled'};$bodyHits[$body.Count]=@{Kind='extra';Index=$row[0]};$body.Add((SettingLine ('['+$row[0]+'] '+$row[1]) (NexL $state) $rightWidth $(if ($prefs[$row[2]]) {$green} else {$gray}) $row[4]))
                }
                EButton 'P' 'Overview' 0xF015
                EHead 'Module preview' 0xF06E (NexAnsi '94E2D5');if (-not ($prefs.ModuleBattery -or $prefs.ModuleSession -or $prefs.ModuleShortcuts -or $prefs.ModuleResources -or $prefs.ModuleAlerts -or $prefs.ModuleDisk)) {$body.Add("$gray$(NexL 'No modules enabled')$reset")} else {ShowNexModules $body $bodyHits}
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
            if ($s.Size -ne $size) { $smallMsg='Enlarge terminal (58 x 16 min).'; Write-Host "$reset$e[2J$e[H${pink}$smallMsg$reset" -NoNewline; $s.Size=$size; $s.Old=@() }
            $s.Hits=@(); return
        }
        $wide=($w -ge 88 -and $s.Page -ne 1 -and $prefs.CompactMode -ne 'Compact'); $longest=0;foreach ($name in $names) {$longest=[Math]::Max($longest,([Globalization.StringInfo]::new([string]$name)).LengthInTextElements)};$leftWidth=[Math]::Min([Math]::Max(21,$longest+5),[Math]::Max(21,$w-55));$s.NavWidth=if ($wide) {$leftWidth+3} else {0}; $rightWidth=if ($wide) {$w-$leftWidth-4} else {$w-3}
        $s.DragTargets=@();$maxBody=$h-7; $body=New-Object 'System.Collections.Generic.List[string]'; $bodyHits=@{}
        $extra='Ctrl+K: search | F6: favorite | F1: help'; $heading=$names[$s.Page]; $hint='Tab: sidebar  |  Esc: overview / exit'
        $fav=@(FavoriteIds);$navOrder=@(NavOrder)
        $navVisual=@(0; if ($fav.Count) {-2;foreach ($id in $fav) {$id};-1}
            foreach ($pageId in $navOrder) {if ($pageId -eq 0 -or $pageId -in $fav) {continue};if ($prefs.SidebarSeparators -and $pageId -in $navGroupStarts) {-1};[int]$pageId})
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
                if ($ni -eq -2) {$body.Add("$purple $(Icon 0xF005) $(NexL 'Favorites')$reset");continue}
                if ($ni -eq -1) {$body.Add("$muted  $('─'*[Math]::Min(21,$rightWidth-3))$reset");continue}
                $a=if ($ni -eq $s.Nav) {"$bg$pink  ❯"} else {"$gray   "}
                $bodyHits[$body.Count]=@{Kind='nav';Index=$ni}
                if ($ni -eq 14 -and $s.ReleaseBadge) {$mark=if ($ni -eq $s.Nav) {'❯'} else {'●'};$a="$(NexReleaseGlow 'badge')$green  $mark"}
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
                    if (HomeBlock 'Identity') {$body.Add((Label 'Computer' $env:COMPUTERNAME)); $body.Add((Label 'User' (Get-NexName))); $body.Add('')}
                    if (HomeBlock 'Metrics') {if ($s.LastOverview) {
                        $d=$s.LastOverview
                        $uc=SmoothNumber 'overview-cpu' $(if ($null -ne $s.LiveCpu) {$s.LiveCpu} else {$d.CPU})
                        $ur=SmoothNumber 'overview-ram' $(if ($null -ne $s.LiveRam) {$s.LiveRam} else {$d.RAM})
                        $um=SmoothNumber 'overview-used' $(if ($null -ne $s.LiveUsed) {$s.LiveUsed} else {$d.Used})
                        $body.Add("$(NexAnsi 'FAB387')$(Icon 0xF2DB) CPU $(Bar $uc)  $(LoadText $uc)$('{0,5:0.0}%' -f $uc)$reset")
                        $body.Add("$pink$(Icon 0xEFC5) RAM $(Bar $ur)  $(LoadText $ur)$('{0,5:0.0}%' -f $ur)$reset")
                        $body.Add((Label 'Memory' ('{0:0.0} / {1:0.0} GiB' -f $um,$d.Total)))
                        $body.Add((Label 'Uptime' (((Get-Date)-$d.Boot).ToString('dd\.hh\:mm\:ss'))))
                    } else { $body.Add("$gray $(NexL 'Loading Windows counters...')$reset") }
                    $body.Add(''); $body.Add("$green●  $(NexL 'LIVE')  $gray | $(NexL 'Smoothed display')$reset")}
                    if (HomeBlock 'Actions') {
                    $bodyHits[$body.Count]=@{Kind='nav';Index=16};$alertColor=if ($s.Alerts.Count) {NexAnsi 'FF943D'} else {$gray};$body.Add("$alertColor$(Icon 0xF0F3) $(NexL 'Notification Center'): $($s.Alerts.Count)$reset")
                    $bodyHits[$body.Count]=@{Kind='installer';Index='I'};$body.Add("$green[I] $(Icon 0xF019) $(NexL 'Update from file')$reset")
                    $bodyHits[$body.Count]=@{Kind='globalKey';Index='Search'};$body.Add("$pink$(Icon 0xF002) Ctrl+K  $(NexL 'Search Dashboard')$reset")
                    if ($w -lt 100 -and $body.Count -lt $maxBody) {ShowNexModules $body $bodyHits}}
                    if ((HomeBlock 'Favorites') -and $fav.Count) {
                        $body.Add('');$body.Add("$purple$(Icon 0xF005) $(NexL 'Favorites')$reset")
                        foreach ($id in $fav) {$bodyHits[$body.Count]=@{Kind='nav';Index=$id};$body.Add("$pink$(Icon $codes[$id]) $white$($names[$id])$reset")}
                    }
                    if ($true) {$bodyHits[$body.Count]=@{Kind='nav';Index=17};$body.Add("$gray$(Icon 0xF009) $(NexL 'Home layout')$reset")}
                }
                1 {
                    if ($s.LastOverview) {
                        $content=@(MonitorLayout $s.LastOverview $rightWidth)
                        $take=[Math]::Max(1,$maxBody-1)
                        $s.MonitorMax=[Math]::Max(0,$content.Count-$take)
                        $s.MonitorPos=[Math]::Max(0,[Math]::Min($s.MonitorMax,$s.MonitorPos))
                        foreach ($target in $s.CardTargets) {if ($target.Row+$target.Height -gt $s.MonitorPos -and $target.Row -lt $s.MonitorPos+$take) {$s.DragTargets+=@(@{Y=($target.Row-$s.MonitorPos+4);EndY=[Math]::Min($take+3,$target.Row-$s.MonitorPos+3+$target.Height);X1=($target.X+2);X2=($target.X+2+$target.Width);Id=$target.Id})}}
                        foreach ($line in @($content | Select-Object -Skip $s.MonitorPos -First $take)) {$body.Add($line)}
                        $note=if ($s.MonitorMax -gt 0) {" | $(NexL 'Scroll for more') ($($s.MonitorPos+1)/$($s.MonitorMax+1))"} else {''}
                        $body.Add("$green● $(NexL 'LIVE') $gray | $(NexL 'Smoothed display')$note$reset")
                    } else {$body.Add("$gray$(NexL 'Loading Windows counters...')$reset")}
                    $hint=(NexL 'Drag card headers to reorder')+' | Up/Down | Tab | Esc'
                }
                2 {
                    $body.Add("$green● $(NexL 'LIVE') $gray | $(NexL 'Sort'): $($s.ProcSort) | $(NexL 'Filter'): $(SafeText $s.ProcFilter)$reset")
                    $buttons=Buttons @(@{Label='[C] CPU';Kind='processAction';Key='C'},@{Label='[M] RAM';Kind='processAction';Key='M'},@{Label='[G] GPU';Kind='processAction';Key='G'}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $buttons=Buttons @(@{Label='[F] Find';Kind='processAction';Key='F'},@{Label='[R] Clear';Kind='processAction';Key='R'},@{Label='[T] Task mgr';Kind='processAction';Key='T'},@{Label='[W] Resource Monitor';Kind='processAction';Key='W'}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $sort=$s.ProcSort
                    $columns=if ($rightWidth -ge 56) {@('CPU','RAM','GPU')} else {@('CPU','RAM',$sort) | Select-Object -Unique}
                    $columns=@($columns)
                    $titles=@{CPU='CPU %';RAM='RAM MiB';GPU='GPU %'}
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
                    $take=[Math]::Max(1,$maxBody-5)
                    $s.ProcPos=[Math]::Max(0,[Math]::Min([int]$s.ProcPos,[Math]::Max(0,$list.Count-$take)))
                    foreach ($p in @($list | Select-Object -Skip $s.ProcPos -First $take)) {
                        $row="$blue$(Fit $p.Id 8)$white$(Fit $p.Name $nameWidth)"
                        foreach ($metric in $columns) {
                            $v=$p[$metric];$tone=$gray;$display='--'
                            if ($null -ne $v) {
                                if ($metric -in @('CPU','RAM')) {$v=SmoothNumber ('proc-'+$metric+'-'+$p.Id) $v}
                                $display='{0:0.0}' -f $v
                                $tone=$white
                                if ($metric -in @('CPU','GPU')) {$tone=LoadText $v $palette[0]}
                                elseif ($metric -eq 'RAM' -and $s.ProcMemoryTotal -gt 0) {$tone=LoadText (100.0*$v/$s.ProcMemoryTotal) $palette[0]}
                            }
                            $row+="$tone$(Fit $display 12)"
                        }
                        $body.Add("$row$reset")
                    }
                    $body.Add("$gray $($list.Count) $(NexL 'Processes sampled')$reset")
                    $hint='C CPU | M RAM | G GPU | W Resource Monitor | Up/Down'
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
                    if ($s.SpeedPath -and -not $s.SpeedProc) {
                        $bodyHits[$body.Count]=@{Kind='networkAction';Index='O'}
                        $body.Add("$gray [O] $(NexL 'Reset Ookla consent')$reset")
                    }
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
                    $crumb=ExplorerBreadcrumb $rightWidth
                    $bodyHits[$body.Count]=$crumb;$body.Add($crumb.Text)
                    $body.Add("$gray $(NexL 'Filter'): $(SafeText $s.Filter) | $($s.FileItems.Count) $(NexL 'items') | $(NexL 'Sort'): $(NexL $s.FileSort) | $(NexL 'Hidden'): $(NexL ([string]$s.ShowHidden))$reset")
                    $body.Add("$muted$('─'*($rightWidth-1))$reset")
                    $canCreate=-not $s.Drives
                    $hasFile=(-not $s.Drives -and $s.FileItems.Count -gt 0)
                    $canEdit=($hasFile -and -not $s.FileItems[$s.Pos].PSIsContainer -and $s.FileItems[$s.Pos].Extension -in $textExtensions)
                    $buttons=Buttons @(@{Label='[N] New file';Kind='fileAction';Key='N';Enabled=$canCreate},@{Label='[M] Folder';Kind='fileAction';Key='M';Enabled=$canCreate},@{Label='[E] Edit';Kind='fileAction';Key='E';Enabled=$canEdit},@{Label='[Del] Trash';Kind='fileAction';Key='Delete';Enabled=$hasFile}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $buttons=Buttons @(@{Label='[D] Drives';Kind='fileAction';Key='D'},@{Label='[F] Find';Kind='fileAction';Key='F'},@{Label='[←] Parent';Kind='fileAction';Key='Backspace'}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $buttons=Buttons @(@{Label='[C] Copy';Kind='fileAction';Key='C';Enabled=$hasFile},@{Label='[X] Cut';Kind='fileAction';Key='X';Enabled=$hasFile},@{Label='[V] Paste';Kind='fileAction';Key='V';Enabled=($canCreate -and $null -ne $s.Clipboard)},@{Label='[F2] Rename';Kind='fileAction';Key='F2';Enabled=$hasFile}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $buttons=Buttons @(@{Label='[Space] View';Kind='fileAction';Key='Spacebar';Enabled=$hasFile},@{Label='[F3] Details';Kind='fileAction';Key='F3';Enabled=$hasFile},@{Label='[F4] Sort';Kind='fileAction';Key='F4';Enabled=$canCreate},@{Label='[H] Hidden';Kind='fileAction';Key='H';Enabled=$canCreate}) $rightWidth
                    $bodyHits[$body.Count]=$buttons; $body.Add($buttons.Text)
                    $buttons=Buttons @(@{Label='[L] Search large files';Kind='fileAction';Key='L'},@{Label='[F7] Windows Open with';Kind='fileAction';Key='F7'}) $rightWidth
                    $bodyHits[$body.Count]=$buttons;$body.Add($buttons.Text)
                    $body.Add('')
                    $take=[Math]::Max(1,$maxBody-10); $offset=[Math]::Max(0,$s.Pos-$take+1)
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
                    if ($s.ScanView) {
                        $body.Add("$pink$(Icon 0xF0AD)  $(NexL 'Full PC scan')$reset")
                        $done=$s.ScanResults.Count;$total=$s.ScanSteps.Count
                        $filled=[int][Math]::Floor(18.0*$done/$total)
                        $body.Add("$pink$('━'*$filled)$muted$('─'*(18-$filled))$reset  $white$done/$total$reset  $gray$(NexL $(if ($s.ScanActive) {'Checking'} elseif ($s.ScanStop -and $done -lt $total) {'Stopped'} else {'Complete'}))$reset")
                        $btn=Buttons @(@{Label='[V] Start scan';Kind='tool';Key='V';Enabled=(-not $s.ScanActive)},@{Label='[K] Stop';Kind='tool';Key='K';Enabled=$s.ScanActive},@{Label='[B] Back';Kind='tool';Key='B'}) $rightWidth
                        $bodyHits[$body.Count]=$btn;$body.Add($btn.Text)
                        $ok=@($s.ScanResults.Values | Where-Object State -eq 'OK').Count
                        $warn=@($s.ScanResults.Values | Where-Object State -eq 'Warning').Count
                        $skip=@($s.ScanResults.Values | Where-Object {$_.State -in @('Unknown','Skipped')}).Count
                        $info=$done-$ok-$warn-$skip
                        $body.Add("$green✓ $ok$reset  $red! $warn$reset  $blue i $info$reset  $gray? $skip$reset")
                        $scanLines=New-Object 'System.Collections.Generic.List[string]';$scanHits=@{}
                        foreach ($group in $s.ScanGroups) {
                            $scanLines.Add("$pink$(NexL $group.Title)$reset $muted$('─'*[Math]::Max(2,[Math]::Min(20,$rightWidth-(Get-NexLogoWidth (NexL $group.Title))-2)))$reset")
                            foreach ($step in $group.Steps) {
                                $result=$s.ScanResults[$step];$mark=' ';$tone=$gray;$status=''
                                if ($result) {
                                    switch ($result.State) {
                                        'OK' {$mark='✓';$tone=$green;$status=NexL 'OK'}
                                        'Warning' {$mark='!';$tone=$red;$status=NexL 'Review'}
                                        'Info' {$mark='i';$tone=$blue;$status=NexL 'Info'}
                                        'History' {$mark='i';$tone=$blue;$status=NexL 'Event history'}
                                        'Skipped' {$mark='?';$tone=$gray;$status=NexL 'Admin required'}
                                        default {$mark='?';$tone=$gray;$status=NexL 'Unavailable'}
                                    }
                                } elseif ($s.ScanActive -and $s.ScanIndex -lt $total -and $step -eq $s.ScanSteps[$s.ScanIndex]) {
                                    $mark=@('◐','◓','◑','◒')[[int]([Math]::Floor($clock.ElapsedMilliseconds/120)%4)];$tone=$purple;$status=NexL 'Checking'
                                }
                                $labelWidth=[Math]::Min(28,[Math]::Max(10,$rightWidth-22))
                                $selectTone=if ($s.ScanSelected -eq $step) {$pink} else {$white}
                                $prefix=if ($s.ScanSelected -eq $step) {'›'} else {' '}
                                $scanHits[$scanLines.Count]=@{Kind='tool';Index=('scanselect:'+$step)}
                                $scanLines.Add("$selectTone$prefix $tone[$mark] $selectTone$(Fit (NexL $step) $labelWidth)$tone$status$reset")
                            }
                        }
                        $selected=$s.ScanResults[$s.ScanSelected]
                        $detail=New-Object 'System.Collections.Generic.List[string]';$detailAction=-1
                        if ($s.ScanSelected) {
                            $detail.Add("$purple$(NexL 'Details'): $(NexL $s.ScanSelected)$reset")
                            if ($selected) {
                                if ($selected.Action) {$detailAction=$detail.Count;$detail.Add("$pink› $(NexL $selected.Action)$reset")}
                                foreach ($line in @(WrapUpdateLine (NexL ([string]$selected.Detail)) ([Math]::Max(12,$rightWidth-2)))) {$detail.Add("$gray$line$reset")}
                                foreach ($item in @($selected.Data)) {
                                    if ([string]::IsNullOrWhiteSpace([string]$item)) {$detail.Add('');continue}
                                    $itemTone=if ($item -match '^\d{4}-\d{2}-\d{2} .+ \| ID \d+$') {$purple} else {$gray}
                                    foreach ($part in @(WrapUpdateLine (NexL ([string]$item)) ([Math]::Max(12,$rightWidth-2)))) {$detail.Add("$itemTone$part$reset")}
                                }
                            } else {$detail.Add("$gray$(NexL 'Not sampled')$reset")}
                        } else {$detail.Add("$gray$(NexL 'Click a check to see details.')$reset")}
                        # Details follow the compact list and can be scrolled, keeping whole result rows together.
                        $detailStart=$scanLines.Count
                        $scanLines.Add("$muted$('─'*[Math]::Min(44,$rightWidth))$reset")
                        for ($k=0;$k -lt $detail.Count;$k++) {
                            if ($k -eq $detailAction) {$scanHits[$scanLines.Count]=@{Kind='tool';Index=('diag:'+$s.ScanSelected)}}
                            $scanLines.Add($detail[$k])
                        }
                        $space=[Math]::Max(1,$maxBody-$body.Count);$s.ScanDisplayCount=$scanLines.Count
                        if ($s.ScanPos -eq -1) {$s.ScanPos=[Math]::Max(0,$detailStart-1)}
                        $s.ScanPos=[Math]::Max(0,[Math]::Min([int]$s.ScanPos,[Math]::Max(0,$scanLines.Count-$space)))
                        for ($j=$s.ScanPos;$j -lt [Math]::Min($scanLines.Count,$s.ScanPos+$space);$j++) {
                            if ($scanHits.ContainsKey($j)) {$bodyHits[$body.Count]=$scanHits[$j]}
                            $body.Add($scanLines[$j])
                        }
                        $hint='Click a check for details | Up/Down | B Back'
                        break
                    }
                    $body.Add("$pink$(Icon 0xF0AD)  $(NexL 'Diagnostics & network settings')$reset"); $body.Add('')
                    $toolButtons=@(
                        @{Label='[D] Disk health';Kind='tool';Key='D'},@{Label='[N] DNS servers';Kind='tool';Key='N'},
                        @{Label='[S] Service status';Kind='tool';Key='S'},@{Label='[I] IP configuration';Kind='tool';Key='I'},
                        @{Label='[E] Event Viewer';Kind='tool';Key='E'},@{Label='[T] Task Manager';Kind='tool';Key='T'},
                        @{Label='[G] Change DNS';Kind='tool';Key='G'},@{Label='[V] Full PC scan';Kind='tool';Key='V'}
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
                    if ($prefs.LightMode) {foreach ($part in @(WrapUpdateLine (NexL 'Acrylic blurs and blends with the desktop. Disable it for clear transparency.') $rightWidth)) {$body.Add("$gray$part$reset")}}
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
                        @('W','Light interface',$(if ($prefs.LightMode) {'Enabled'} else {'Disabled'})),
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
                    $body.Add('');$bodyHits[$body.Count]=@{Kind='public';Index='Delete'};$body.Add("$red[Del] $(NexL 'Reset Dashboard to defaults')$reset")
                    $hint='S Export | R Restore | Del Reset | Esc Overview'
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
        if ($s.Page -eq 0 -and -not $menuOnly -and -not $s.Preview) {
            $s.HomeMax=[Math]::Max(0,$body.Count-$maxBody);$s.HomePos=[Math]::Min($s.HomeMax,[Math]::Max(0,$s.HomePos))
            if ($s.HomeMax -gt 0) {
                $offset=$s.HomePos;$newHits=@{};$newBody=New-Object 'System.Collections.Generic.List[string]'
                for ($i=$offset;$i -lt [Math]::Min($body.Count,$offset+$maxBody);$i++) {$newBody.Add($body[$i]);if ($bodyHits.ContainsKey($i)) {$newHits[$i-$offset]=$bodyHits[$i]}}
                $body=$newBody;$bodyHits=$newHits;$hint=(NexL 'Scroll for more')+' | '+($s.HomePos+1)+'/'+($s.HomeMax+1)
            }
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
        $header="$pink  $(SafeText (Get-NexName))   /   D A S H B O A R D   2.7.0   $purple / $accentName   $gray • $(Get-Date -Format 'HH:mm:ss')$reset"
        $modules=@(NexHeaderModules)
        $headLen=Get-NexLogoWidth ([regex]::Replace($header,'\x1b\[[0-9;]*m',''))
        $privLabel=if ($isAdmin) {'[F8] '+$(if ($prefs.Icons) {Icon 0xF132} else {'+'})+' ADMIN'} else {'[F8] '+$(if ($prefs.Icons) {Icon 0xF132} else {'+'})+' '+(NexL 'Admin')}
        $privWidth=Get-NexLogoWidth $privLabel
        $headerLimit=$w-1-$privWidth-2
        $wantedWidth=0
        foreach ($module in $modules) {$wantedWidth+=(Get-NexLogoWidth ([regex]::Replace($module.Text,'\x1b\[[0-9;]*m','')))+3}
        if ($headLen+$wantedWidth -gt $headerLimit) {
            $header="$pink $(SafeText (Get-NexName)) / DASHBOARD 2.7.0 $purple / $accentName $gray • $(Get-Date -Format 'HH:mm:ss')$reset"
            $headLen=Get-NexLogoWidth ([regex]::Replace($header,'\x1b\[[0-9;]*m',''))
        }
        if ($headLen -gt $headerLimit) {$header=ClipAnsi $header $headerLimit;$headLen=Get-NexLogoWidth ([regex]::Replace($header,'\x1b\[[0-9;]*m',''))}
        $kept=@();$moduleWidth=0
        foreach ($module in $modules) {
            $length=Get-NexLogoWidth ([regex]::Replace($module.Text,'\x1b\[[0-9;]*m',''))
            $gap=if ($kept.Count) {3} else {0}
            if ($headLen+2+$moduleWidth+$gap+$length -le $headerLimit) {$kept+=@(@{Text=$module.Text;Page=$module.Page;Length=$length});$moduleWidth+=$gap+$length}
        }
        if ($kept.Count) {
            $header+=' '*[Math]::Max(2,$headerLimit-$headLen-$moduleWidth)
            $pos=$headerLimit-$moduleWidth
            for ($mi=0;$mi -lt $kept.Count;$mi++) {
                if ($mi) {$header+="$muted │ $reset";$pos+=3}
                $part=$kept[$mi];$header+=$part.Text
                $hits.Add(@{Y=0;X1=$pos;X2=($pos+$part.Length);Kind='nav';Index=$part.Page});$pos+=$part.Length
            }
        }
        $used=Get-NexLogoWidth ([regex]::Replace($header,'\x1b\[[0-9;]*m',''))
        $privTone=if ($isAdmin) {$green} else {$purple}
        $header+=(' '*[Math]::Max(1,$w-1-$privWidth-$used))+"$privTone$privLabel$reset"
        $hits.Add(@{Y=0;X1=($w-1-$privWidth);X2=($w-1);Kind='globalKey';Index='F8'})
        $rows.Add($header)
        $rows.Add("$muted$('─'*($w-1))$reset")
        $rows.Add("$purple  $(Icon $codes[$s.Page])  $heading$reset")
        $rows.Add('')
        for ($i=0;$i -lt $maxBody;$i++) {
            $b=if ($i -lt $body.Count) {$body[$i]} else {''}
            if ($wide) {
                if ($i+$navOffset -lt $navVisual.Count) {
                    $ni=$navVisual[$i+$navOffset]
                    if ($ni -eq -2) {$navText="$purple  $(Fit ((Icon 0xF005)+' '+(NexL 'Favorites')) ($leftWidth-2))$reset"}
                    elseif ($ni -eq -1) {
                        $navText="$muted  $('─'*($leftWidth-4))  $reset"
                    } else {
                        $active=($ni -eq $s.Page); $focus=($s.Focus -eq 'nav' -and $ni -eq $s.Nav)
                        $prefix=if ($focus) {"$bg$pink ❯"} elseif ($active) {"$purple ●"} else {"$gray  "}
                        if ($ni -eq 14 -and $s.ReleaseBadge) {$mark=if ($focus) {'❯'} else {'●'};$prefix="$(NexReleaseGlow 'badge')$green $mark"}
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
        $foot=if ($s.DragCard) {"$pink ◆ $(NexL 'Dragging'): $(NexL $s.DragCard)  |  $(NexL 'Release to move; Esc cancels.')$reset"} elseif ($s.Msg) {"$pink $($s.Msg)$reset"} else {"$gray $(NexL $hint)$reset"}
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
        if ($s.Size -ne $size) { $frame+="$reset$e[2J"; $s.Old=@(); $s.Size=$size }
        for ($i=0;$i -lt [Math]::Min($rows.Count,$h);$i++) {
            $line=ClipAnsi $rows[$i] ($w-1)
            if ($i -ge $s.Old.Count -or $s.Old[$i] -cne $line -or $i -eq $s.DragOverlayRow) { $row=$i+1; $frame+="$e[${row};1H$reset$line$reset$e[K" }
            $rows[$i]=$line
        }
        $s.DragOverlayRow=-1
        if ($s.DragCard -and $s.DragY -ge 4 -and $s.DragY -lt $h-3 -and $s.DragX -ge 0 -and $s.DragX -lt $w) {
            $badge=' ◆ '+(NexL $s.DragCard)+' ';$bw=[Math]::Min($w-1,(Get-NexLogoWidth $badge));$bx=[Math]::Max(0,[Math]::Min($w-1-$bw,$s.DragX+2));$by=[Math]::Max(4,[Math]::Min($h-4,$s.DragY+1))
            $frame+="$e[$($by+1);$($bx+1)H$bg$pink$(ClipAnsi $badge $bw)$reset";$s.DragOverlayRow=$by
        }
        if ($frame) { Write-Host $frame -NoNewline }
        $s.Old=$rows.ToArray(); $s.Hits=$hits.ToArray()
    }
    function ClipAnsi([string]$line,[int]$width) {
        if ($width -le 0) { return '' }
        if ($prefs.LightMode) {$line=[regex]::Replace($line,'\x1b\[0m(?!\x1b\[38;2;)',$reset)}
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
    if ($EditorPath) {
        try {
            $item=Get-Item -LiteralPath $EditorPath -ErrorAction Stop
            if ($item.PSProvider.Name -ne 'FileSystem' -or $item.PSIsContainer -or $item.Extension -notin $textExtensions) {throw (NexL 'Select a supported text file.')}
            $s.Folder=$item.DirectoryName
            Write-Host "$e[?1049h$reset$e[?25l$e[2J$e[H" -NoNewline
            EditText $item
        } finally {PauseMouse;Write-Host "$e[0m$e[?1049l$e[?25h" -NoNewline}
        if ($s.Msg -and $s.Msg -ne (NexL 'File saved.')) {Write-Host $s.Msg;[void](Read-Host (NexL 'Enter to close'))};return
    }
    $s.Job=$null; $s.Worker=$null; $s.Preview=$null; $s.ProcPos=0; $s.InfoPos=0; $s.ToolPos=0; $s.ToolDisplayCount=0; $s.PingNext=0L
    $s.LogLoaded=$false; $lastClock=-1; $lastTheme=-1; $running=$true
    try {
        Write-Host "$e[?1049h$reset$e[?25l$e[2J$e[H" -NoNewline
        while ($running) {
            if ($s.DragCard) {
                $dragSize="$([Console]::WindowWidth)x$([Console]::WindowHeight)"
                if ($s.Size -ne $dragSize) {$s.DragCard='';$s.DragOrder='';$s.DragHover='';$s.Need=$true;continue}
                $s.AllowDrag=$true;try {$dragEvent=InputEvent} finally {$s.AllowDrag=$false}
                if ($dragEvent -and $dragEvent.Key -eq 'CardMove') {
                    $s.DragX=$dragEvent.X;$s.DragY=$dragEvent.Y
                    DrawNexDragBadge
                    $s.AllowDrag=$true;try {$target=DragCardAt $dragEvent.X $dragEvent.Y -Drop} finally {$s.AllowDrag=$false}
                    if ($target -eq $s.DragCard) {$target=''}
                    if ($target -ne $s.DragHover) {$s.DragHover=$target;$s.DragHoverAt=$clock.ElapsedMilliseconds;$s.Need=$true}
                }
                if ($dragEvent -and $dragEvent.Key -eq 'CardDrop') {
                $from=$s.DragCard;$s.AllowDrag=$true;try {$to=DragCardAt $dragEvent.X $dragEvent.Y -Drop} finally {$s.AllowDrag=$false}
                if ($to -and $from) {if ($to -ne $from) {MoveNexCard $from $to};if ($s.DragMoved) {$s.DragSwapOrder=$s.DragOrder;$s.DragSwapAt=$clock.ElapsedMilliseconds+160;$s.DragPulse=$from;$s.DragPulseUntil=$s.DragSwapAt+420;$s.DragPulseAt=0L} elseif ($s.Page -eq 17) {NewPageAction ('card:'+$from)}}
                $s.DragCard='';$s.DragOrder='';$s.DragMoved=$false;$s.DragHover='';$s.Need=$true;continue
            }
                if ($dragEvent -and $dragEvent.Key -notin @('CardMove','CardGrab')) {$s.DragCard='';$s.DragOrder='';$s.DragHover='';$s.Need=$true;continue}
                if ($s.Need -and $clock.ElapsedMilliseconds -ge $s.DragRenderAt) {Render;$s.Need=$false;$s.DragRenderAt=$clock.ElapsedMilliseconds+120}
                if (-not $dragEvent) {Start-Sleep -Milliseconds 5};continue
            }
            PollWorker
            PollNexReleaseProbe
            if ($s.Page -in @(0,1) -or $prefs.ModuleResources) {SampleNexResources}
            if ($s.HandoffToken) {
                $ready=Get-NexHandoffPath $s.HandoffToken ready
                $ack=$false
                try {if (Test-Path -LiteralPath $ready -PathType Leaf) {$ack=([IO.File]::ReadAllText($ready) -ceq $s.HandoffToken)}} catch {}
                if ($ack) {$s.HandoffExit=$true;ClearNexHandoff;$running=$false;break}
                if ($clock.ElapsedMilliseconds -ge $s.HandoffDeadline) {ClearNexHandoff;Notice 'Switch not confirmed. Original session kept.'}
            }
            if ($s.ScanActive -and -not $s.Job) {
                if ($s.ScanStop -or $s.ScanIndex -ge $s.ScanSteps.Count) {$s.ScanActive=$false;$s.Need=$true}
                else {$step=$s.ScanSteps[$s.ScanIndex];StartWorker 'diagnostic' ([scriptblock]::Create((Get-Command Invoke-NexDiagnosticStep -CommandType Function).Definition)) $step;if (-not $s.Job) {$s.ScanResults[$step]=[pscustomobject]@{State='Unknown';Detail='Query failed or access denied.';Action=''};$s.ScanIndex++};$s.Need=$true}
            }
            if ($s.SpeedInstallPending -and -not $s.Job) {
                $s.SpeedInstallPending=$false
                StartWorker 'speed-install' ([scriptblock]::Create((Get-Command Install-NexSpeedtest -CommandType Function).Definition))
                if (-not $s.Job) {$s.SpeedStatus='Speedtest installation failed';$s.Need=$true}
            }
            if ($s.PendingInstaller) {$running=$false;break}
            if ($s.OnlineReady -and -not $s.Job) {
                $s.OnlineReady=$false
                if ($s.Page -eq 14 -and -not $s.Preview) {try {StartNexOnlineDownload} catch {Notice $_.Exception.Message}}
            }
            PollSpeedTest
            $now=$clock.ElapsedMilliseconds
            if ($lastClock -ne [int][Math]::Floor($now/1000)) { $lastClock=[int][Math]::Floor($now/1000); $s.Need=$true }
            $themeKey="$($prefs.Theme)/$($prefs.Accent)/$($prefs.Language)/$($prefs.Icons)/$($prefs.LightMode)"
            if ($lastTheme -ne $themeKey) {
                $lastTheme=$themeKey;$palette=Get-NexPalette
                $pink=NexAnsi $palette[0];$purple=NexAnsi $palette[1];$bg=NexAnsi $palette[2] -Background;$white=NexAnsi $palette[4];$gray=NexAnsi $palette[5];$green=if ($prefs.LightMode) {NexAnsi '21683E'} else {NexAnsi 'A6E3A1'};$red=if ($prefs.LightMode) {NexAnsi 'A12848'} else {NexAnsi 'F38BA8'};$blue=if ($prefs.LightMode) {NexAnsi '275DAB'} else {NexAnsi '89B4FA'};$muted=if ($prefs.LightMode) {NexAnsi (Mix-NexColor $palette[5] $palette[3] 0.18)} else {NexAnsi '585B70'};$reset="$e[0m";if ($prefs.LightMode) {$reset+=$white}
                $names=@('Overview','System Monitor','Processes','Network','File Explorer','System Info','Windows Update','Quick Tools','System Logs','Terminal Settings','Personalization','Hardware Info','Gaming Mode','App Launcher','Update Center','System Health','Notification Center','Dashboard Designer','Startup Manager','Plugin Manager','Animation Studio','Benchmark Center','Large files and folders') | ForEach-Object {NexL $_}
                ResetDraw
            }
            if (-not $s.Job -and -not $s.Preview -and $now -ge $s.HealthNext -and $s.Page -notin @(3,6,7,14,21,22)) {
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
            if ($prefs.ModuleResources -and -not $s.LiveReader -and -not $s.Job -and -not $s.ScanActive -and -not $s.Task -and $s.Page -notin @(0,1,21,22) -and ($null -eq $s.ResourceNext -or $now -ge $s.ResourceNext)) {
                $s.ResourceNext=$now+1000;StartWorker 'overview' $overviewScript 0
            }
            $size="$([Console]::WindowWidth)x$([Console]::WindowHeight)"
            if ($s.Page -eq 3) { SampleFastNetwork }
            $now=$clock.ElapsedMilliseconds
            if (($s.Page -in @(0,1,2,3) -or $prefs.ModuleResources) -and -not $s.Preview -and -not $s.DragCard -and $now -ge $s.AnimAt) {
                if ($s.Page -eq 3) { AnimateTraffic }
                $s.AnimAt=$now+$(if ($s.Page -in @(0,1,2,3)) {50} else {100})
                $s.Need=$true
            }
            if ($s.Page -eq 7 -and $s.ScanView -and $s.ScanActive -and $now -ge $s.AnimAt) {$s.AnimAt=$now+120;$s.Need=$true}
            if ($now -ge $s.ReleaseAnimAt -and (($s.ReleaseBadge -and ($now-$s.ReleaseBadgeAt) -lt 1500) -or ($s.Page -eq 14 -and (($s.Job -and $s.JobKind -eq 'release') -or $s.ReleaseProbeManual -or ($s.ReleaseFinishAt -ge 0 -and ($now-$s.ReleaseFinishAt) -lt 1500))))) {$s.ReleaseAnimAt=$now+65;$s.Need=$true}
            if ($s.Page -eq 6 -and $s.UpdateStatus -eq 'Checking' -and $now -ge $s.AnimAt) { $s.AnimAt=$now+120; $s.Need=$true }
            if ($s.Task -and $s.Page -eq 21 -and $now -ge $s.AnimAt) {$s.AnimAt=$now+200;$s.Need=$true}
            if ($s.DragSwapOrder -and $now -ge $s.DragSwapAt) {
                $prefs.MonitorOrder=$s.DragSwapOrder;$s.DragSwapOrder='';$s.DragPulseUntil=$now+420
                Save-NexPreferences;Notice 'Preferences saved.';$s.Need=$true
            }
            if ($s.DragPulse) {if ($now -ge $s.DragPulseUntil) {$s.DragPulse='';$s.DragOther='';$s.Need=$true} elseif ($now -ge $s.DragPulseAt) {$s.DragPulseAt=$now+33;$s.Need=$true}}
            if ($s.Need -or $s.Size -ne $size) { Render; $s.Need=$false; if ($HandoffToken) {Complete-NexHandoff $HandoffToken;$HandoffToken=''} }
            $s.AllowDrag=$true;try {$event=InputEvent} finally {$s.AllowDrag=$false}
            if (-not $event) { Start-Sleep -Milliseconds 12; continue }
            $key=$event.Key; $s.Msg=''; $s.Need=$true
            if ($key -eq 'CardGrab') {$s.DragCard=$event.Card;$s.DragOrder=$prefs.MonitorOrder;$s.DragMoved=$false;$s.DragOther='';$s.DragPulse='';$s.DragX=$event.X;$s.DragY=$event.Y;$s.DragViewX=[double]$event.X;$s.DragViewY=[double]$event.Y;$s.DragHover='';$s.DragRenderAt=0L;continue}
            if ($event.Ctrl -and $key -eq 'K') {try {SearchNexDashboard} catch {Notice $_.Exception.Message};continue}
            if ($event.Wheel -and -not $s.Preview) {
                if ($s.Page -eq 1) { $s.Focus='body' } elseif ($s.NavWidth -gt 0) { $s.Focus=if ($event.X -lt $s.NavWidth) {'nav'} else {'body'} }
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
                        elseif ($hit.Kind -eq 'fileCrumb') {$s.Focus='body';GoFolder $hit.Index}
                        elseif ($hit.Kind -eq 'fileParents') {
                            $s.Focus='body';$paths=[Collections.Generic.List[string]]::new();$dir=[IO.DirectoryInfo]::new($s.Folder)
                            while ($dir) {$paths.Insert(0,$dir.FullName);$dir=$dir.Parent}
                            $v=Ask 'Parent folders' $paths.ToArray() $paths.ToArray();if ($v) {GoFolder $v}
                        }
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
            if ($key -eq 'F6') {try {ToggleFavorite $(if ($s.Focus -eq 'nav') {$s.Nav} else {$s.Page})} catch {Notice $_.Exception.Message};continue}
            if ($key -eq 'F8') {try {SwitchNexPrivilege} catch {Notice $_.Exception.Message};continue}
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
                $navOrder=@(NavOrder);$navIndex=[array]::IndexOf($navOrder,[int]$s.Nav)
                if ($navIndex -lt 0) {$navIndex=0}
                if ($key -eq 'UpArrow') { $s.Nav=$navOrder[($navIndex+$navOrder.Count-1)%$navOrder.Count] }
                elseif ($key -eq 'DownArrow') { $s.Nav=$navOrder[($navIndex+1)%$navOrder.Count] }
                elseif ($key -eq 'Enter') { ChoosePage $s.Nav }
                elseif ($key -eq 'RightArrow') { $s.Focus='body' }
                continue
            }
            try {
                switch ($s.Page) {
                    0 { if ($key -in @('UpArrow','DownArrow','PageUp','PageDown')) {$s.HomePos=ScrollPos $key $s.HomePos ($s.HomeMax+1)} elseif ($key -eq 'Enter') { $s.Focus='nav' } elseif ($key -eq 'I') {SelectNexInstaller;if ($s.PendingInstaller) {$running=$false}} }
                    1 { $s.MonitorPos=ScrollPos $key $s.MonitorPos ($s.MonitorMax+1) }
                    2 {
                        switch ($key) {
                            'C' { $s.ProcSort='CPU'; $s.ProcPos=0 }
                            'M' { $s.ProcSort='RAM'; $s.ProcPos=0 }
                            'G' { $s.ProcSort='GPU'; $s.ProcPos=0 }
                            'F' { $v=Ask 'Process name'; if ($v) { $s.ProcFilter=$v; $s.ProcPos=0 } }
                            'R' { $s.ProcFilter=''; $s.ProcPos=0 }
                            'T' { Start-Process taskmgr.exe }
                            'W' { Start-Process resmon.exe }
                            default { $s.ProcPos=ScrollPos $key $s.ProcPos $s.ProcRows.Count }
                        }
                    }
                    3 {
                        if ($key -eq 'S') { StartSpeedTest }
                        elseif ($key -eq 'O') { ResetSpeedtestConsent }
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
            if ($s.DragSwapOrder) {try {$prefs.MonitorOrder=$s.DragSwapOrder;Save-NexPreferences} catch {}; $s.DragSwapOrder=''}
            ClearNexHandoff
            if ($s.SpeedProc) { StopSpeedTest }
            if ($s.Task) {$s.Task.Cancel=$true}
            if ($s.Job -and $s.JobKind -eq 'benchmark' -and $s.Task -and $s.Task.TestKind -eq 'RAM') {
                try {$null=$s.Job.AsyncWaitHandle.WaitOne(8000)} catch {}
            }
            try { if ($s.Job -and $s.Worker -and -not $s.Job.IsCompleted) { $s.Worker.Stop() } } catch {}
            if ($s.Worker) { $s.Worker.Dispose() }
            if ($s.ReleaseProbeWorker) {try {if ($s.ReleaseProbeJob -and -not $s.ReleaseProbeJob.IsCompleted) {$s.ReleaseProbeWorker.Stop()}} catch {};try {$s.ReleaseProbeWorker.Dispose()} catch {}}
            if ($s.OnlineTemp -and -not $s.PendingInstaller) {Remove-Item -LiteralPath $s.OnlineTemp -Force -ErrorAction SilentlyContinue}
            PauseMouse
            # Finish the animation in the Dashboard buffer. Do not reveal the old
            # primary screen until the transition is ready.
            if (-not $running -and -not $s.HandoffExit) {
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
                Write-Host "$e[0m$e[?1049l$e[2J$e[H$e[?25h" -NoNewline
            } else {
                Write-Host "$e[0m$e[?1049l$e[?25h" -NoNewline
            }
        }
    }
    if ($s.HandoffExit) {exit}
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
    param([ValidateRange(0,22)][int]$StartPage=0,[switch]$StartScan,[string]$HandoffToken='')
    $page=$StartPage
    do {
        $global:NexDashboardReloadRequested=$false
        & (Get-Command Invoke-NexDashboard -CommandType Function -ErrorAction Stop).ScriptBlock -StartPage $page -StartScan:$StartScan -HandoffToken $HandoffToken
        $HandoffToken='';$StartScan=$false;$page=14
    } while ($global:NexDashboardReloadRequested)
}
$global:NexPublicVersion='2.7.0'
if ($RegisterEditor -and -not $Install) {Set-NexEditorAssociation $true;Write-Host (NexL 'Editor registered.');return}
if ($OpenEditor) {
    try {Invoke-NexDashboard -StartPage 4 -EditorPath $OpenEditor} catch {Write-Warning $_.Exception.Message;[void](Read-Host 'Enter to close')}
    return
}
