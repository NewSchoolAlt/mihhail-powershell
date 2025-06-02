<#
.SYNOPSIS
  Ühendab kõiki tervisekontrolli, logimise ja häire-saatmise komponendid.

.DESCRIPTION
  1) Kogub CPU ja mälu näitajad.  
  2) Kogub iga fikseeritud ketta vaba ja kogu ruumi (GB).  
  3) Logib iga jooksu rea CSV-faili.  
  4) Kontrollib, kas CPU, mälu või ketta kasutus ületab künniseid (näiteks 70 %).  
  5) Kui künnis ületatud, saadab Gmaili kaudu hoiatuse ja logib selle eraldi faili.  
  6) Iga skripti käivituse edu või vea kohta prindib teate ka ekraanile (või Task Scheduler’i logisse).

.PARAMETER N/A
  - Kõik konfiguratsioonimäärangud on skripti ülemises “Config” sektsioonis.

.NOTES
  - Kasuta “Set-ExecutionPolicy RemoteSigned” või “Bypass” režiimis, nt:
      powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\Main-HealthFramework.ps1"
  - Jooksmiseks on vaja administraatoriõigusi (et lugeda kõiki süsteemi-näitajaid).
#>

# ============================
# === 1. KONFIGURATSIOON ===
# ============================

# 1.1. Failirada, kuhu tulemused salvestada (CSV-fail). Kui ei eksisteeri, skript loob selle päisega.
$CsvPath = "C:\Logs\health_check.csv"

# 1.2. Hoiatus-/veateadete logifail
$AlertLogPath = "C:\Logs\health_alerts.log"

# 1.3. Threshold’d protsentides
$Thresholds = @{
    CPU    = 85    # Kui protsessori koormus ≥ 85%, saadame hoiatuse
    Memory = 90    # Kui kasutatud mälu protsendina ≥ 90%, alarm
    Disk   = 70    # Kui ketta kasutus protsentides ≥ 70%, alarm
}

# 1.4. Gmail SMTP seaded (kirjuta enda andmed siia)
$SmtpSettings = @{
    SmtpServer = "smtp.gmail.com"
    SmtpPort   = 587
    From       = "mina.kasutaja@gmail.com"       # sinu Gmaili aadress
    To         = "admin@domain.com"               # sihtadress (võid eraldada mitme “;”-ga)
    Credential = New-Object System.Management.Automation.PSCredential(
                     "mina.kasutaja@gmail.com",
                     (ConvertTo-SecureString "Sinu_App_Password_Generated_16char" -AsPlainText -Force)
                 )
    UseSsl     = $true
}

# =============================
# === 2. LOGIFAILI INITSIALISEERIMINE ===
# =============================

function Initialize-Files {
    # 2.1. CSV-faili päis
    if (-not (Test-Path $CsvPath)) {
        $folder = Split-Path -Parent $CsvPath
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
        # Kirjutame CSV päise
        "Timestamp,CPU_Percent,Memory_TotalGB,Memory_FreeGB,Drive,Free_GB,Total_GB,UsedPercent" |
            Out-File -FilePath $CsvPath -Encoding UTF8
    }

    # 2.2. Alert-logi päis, kui ei eksisteeri
    if (-not (Test-Path $AlertLogPath)) {
        $folderA = Split-Path -Parent $AlertLogPath
        if (-not (Test-Path $folderA)) {
            New-Item -Path $folderA -ItemType Directory -Force | Out-Null
        }
        "===== Alert/Error Log =====" | Out-File -FilePath $AlertLogPath -Encoding UTF8
        "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $AlertLogPath -Append -Encoding UTF8
        "===========================" | Out-File -FilePath $AlertLogPath -Append -Encoding UTF8
    }
}

# ========================
# === 3. METRIKATE KOGUMINE ===
# ========================

function Get-CpuMemoryMetrics {
    # CPU kasutus protsendina (LoadPercentage)
    $cpuLoad = (Get-CimInstance -ClassName Win32_Processor).LoadPercentage

    # Mälu (kilobaitides → GB)
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)

    return [pscustomobject]@{
        CPU_Percent   = $cpuLoad
        Memory_TotalGB = $totalMemGB
        Memory_FreeGB  = $freeMemGB
    }
}

function Get-DiskMetrics {
    # Vaatame ainult fikseeritud kettad (DriveType=3)
    $drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3"
    $list = @()
    foreach ($d in $drives) {
        $freeGB  = [math]::Round($d.FreeSpace / 1GB, 2)
        $totalGB = [math]::Round($d.Size / 1GB, 2)
        $usedPercent = [math]::Round(((($d.Size - $d.FreeSpace) / $d.Size) * 100), 2)
        $list += [pscustomobject]@{
            Drive       = $d.DeviceID
            Free_GB     = $freeGB
            Total_GB    = $totalGB
            UsedPercent = $usedPercent
        }
    }
    return $list
}

# ================================
# === 4. ALARMIDE KONTROLL & SAATMINE ===
# ================================

function Send-Alert {
    param(
        [string]$Subject,
        [string]$Body
    )
    try {
        Send-MailMessage `
            -From $SmtpSettings.From `
            -To $SmtpSettings.To `
            -Subject $Subject `
            -Body $Body `
            -SmtpServer $SmtpSettings.SmtpServer `
            -Port $SmtpSettings.SmtpPort `
            -Credential $SmtpSettings.Credential `
            -UseSsl:$($SmtpSettings.UseSsl) `
            -BodyAsHtml:$false

        # Kui saatis edukalt, logime OK kirje
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$ts [ALERT] E-post saadetud (Subject: $Subject)" | Out-File -FilePath $AlertLogPath -Append -Encoding UTF8
    }
    catch {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$ts [ERROR] E-posti saatmine ebaõnnestus: $($_.Exception.Message)" |
            Out-File -FilePath $AlertLogPath -Append -Encoding UTF8
    }
}

function Check-Thresholds {
    param(
        [psobject]$metrics,       # objektil: CPU_Percent, Memory_TotalGB, Memory_FreeGB
        [array]$diskMetrics,      # iga elem. sisaldab: Drive, Free_GB, Total_GB, UsedPercent
        [hashtable]$thresholds
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # 4.1. CPU
    if ($metrics.CPU_Percent -ge $thresholds.CPU) {
        $subj = "[ALERT] CPU ≥ $($thresholds.CPU)% on $env:COMPUTERNAME"
        $body = "Host: $env:COMPUTERNAME`n" +
                "Aeg: $timestamp`n" +
                "Mõõdetud CPU kasutus: $($metrics.CPU_Percent)% (küünis: $($thresholds.CPU)%)`n"
        Send-Alert -Subject $subj -Body $body
    }

    # 4.2. Memory (kasutusprotsent = ((Total-Free)/Total)*100)
    $usedMemPercent = [math]::Round(((($metrics.Memory_TotalGB - $metrics.Memory_FreeGB) / $metrics.Memory_TotalGB) * 100), 2)
    if ($usedMemPercent -ge $thresholds.Memory) {
        $subj = "[ALERT] Mälu kasutus ≥ $($thresholds.Memory)% on $env:COMPUTERNAME"
        $body = "Host: $env:COMPUTERNAME`n" +
                "Aeg: $timestamp`n" +
                "Mõõdetud mälu kasutus: $usedMemPercent% (küünis: $($thresholds.Memory)%)`n" +
                "Total: $($metrics.Memory_TotalGB)GB, Free: $($metrics.Memory_FreeGB)GB`n"
        Send-Alert -Subject $subj -Body $body
    }

    # 4.3. Disk (iga ketta kohta eraldi)
    foreach ($d in $diskMetrics) {
        if ($d.UsedPercent -ge $thresholds.Disk) {
            $subj = "[ALERT] Ketta $($d.Drive) kasutus ≥ $($thresholds.Disk)% on $env:COMPUTERNAME"
            $body = "Host: $env:COMPUTERNAME`n" +
                    "Aeg: $timestamp`n" +
                    "Ketastähis: $($d.Drive)`n" +
                    "Kasutus: $($d.UsedPercent)% (küünis: $($thresholds.Disk)%)`n" +
                    "Total: $($d.Total_GB)GB, Free: $($d.Free_GB)GB`n"
            Send-Alert -Subject $subj -Body $body
        }
    }
}

# ============================
# === 5. LOOGIMINE JA LOGIMINE ===
# ============================

function Write-LogEntry {
    param(
        [string]$timestamp,
        [psobject]$metrics,
        [array]$diskMetrics
    )

    foreach ($d in $diskMetrics) {
        $line = "{0},{1},{2},{3},{4},{5},{6},{7}" -f `
            $timestamp, `
            $metrics.CPU_Percent, `
            $metrics.Memory_TotalGB, `
            $metrics.Memory_FreeGB, `
            $d.Drive, `
            $d.Free_GB, `
            $d.Total_GB, `
            $d.UsedPercent

        # Kirjuta CSV-faili uus rida
        $line | Out-File -FilePath $CsvPath -Append -Encoding UTF8
    }
}

# ============================
# === 6. PEAMINE TÖÖVOOG ===
# ============================

try {
    # 6.1. Loo (vajadusel) CSV ja alert-failid
    Initialize-Files

    # 6.2. Kogume CPU ja mälu näitajad
    $cmMetrics = Get-CpuMemoryMetrics

    # 6.3. Kogume kettaandmed
    $dkMetrics = Get-DiskMetrics

    # 6.4. Aja märge
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # 6.5. Logime andmed CSV-faili
    Write-LogEntry -timestamp $ts -metrics $cmMetrics -diskMetrics $dkMetrics

    # 6.6. Kontrollime künniseid ja vajadusel saadame e-kirja
    Check-Thresholds -metrics $cmMetrics -diskMetrics $dkMetrics -thresholds $Thresholds

    # 6.7. Teade edukast lõpetamisest
    Write-Output "[$ts] INFO: Skript edukalt lõpetatud. Log @ $CsvPath"
}
catch {
    # Kui midagi tõsiselt läheb viltu, viskame vea alert-logi ja saame süsteemiadministraatorile e-posti
    $errMsg = $_.Exception.Message
    $timeErr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Logime vea alert-faili
    "$timeErr [CRITICAL ERROR] Skripti viga: $errMsg" |
        Out-File -FilePath $AlertLogPath -Append -Encoding UTF8

    # Koostame kiire e-kirja skriptirikkest
    $subj = "[CRITICAL] Skripti viga $env:COMPUTERNAME"
    $body = "Host: $env:COMPUTERNAME`nAeg: $timeErr`nSkripti viga: $errMsg`n"
    Send-Alert -Subject $subj -Body $body

    throw  # viska viga uuesti üles, et Task Scheduler saaks võtta teadmiseks väljumiskoodi
}
