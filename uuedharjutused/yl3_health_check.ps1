<#
.SYNOPSIS
  Korjab kokku CPU, mälu ja ketaste kasutusandmed ning salvestab need CSV-faili.

.DESCRIPTION
  Skript kogub:
    - Protsessori koormuse %
    - Kogu ja vaba mälu (GB)
    - Iga fikseeritud (C:, D: jne) draivi vaba ja kogu ruum (GB)
  Seejärel lisab iga mõõtmise eraldi rea CSV-faili.
  Kui CSV-faili pole olemas, luuakse selle päis.

.PARAMEETRID
  Skriptis ei kasuta parameetreid; kõvakodeeritud on teekonnad ja failinimed.

.KASUTUS
  Käivita administraatoriõigustes:
    powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\health_check.ps1"
#>

# === 1. Konfiguratsioon ===
# CSV-faili tee. Kui seda fail ei eksisteeri, skript lisab päise.
$CsvPath = "C:\Logs\health_check.csv"

# === 2. Funktsioon: Algpäise kirjutamine, kui faili pole ===
function Initialize-LogFile {
    param (
        [string]$Path
    )
    if (-not (Test-Path $Path)) {
        # Loome kataloogi, kui puudub
        $folder = Split-Path -Parent $Path
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
        # Kirjutame CSV päise
        $header = "Timestamp,CPU_Percent,TotalMemory_GB,FreeMemory_GB,Drive,Free_GB,Total_GB"
        $header | Out-File -FilePath $Path -Encoding UTF8
    }
}

# === 3. Funktsioon: CPU ja mälu andmete kogumine ===
function Get-CpuMemoryMetrics {
    # 3.1. CPU kasutus (%)
    # Kasutame Win32_Processor klassi LoadPercentage atribuuti
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty LoadPercentage

    # 3.2. Mälu kasutus (GB)
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    # TotalVisibleMemorySize ja FreePhysicalMemory tagastavad kilobaidid
    $totalMemGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)

    return [pscustomobject]@{
        CPU_Percent     = $cpu
        TotalMemory_GB  = $totalMemGB
        FreeMemory_GB   = $freeMemGB
    }
}

# === 4. Funktsioon: Ketaste kasutusandmete kogumine ===
function Get-DiskMetrics {
    # Filtreerime ainult PSDrive tüüpi "FileSystem" (fikseeritud kettad)
    $drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3"
    $diskList = @()

    foreach ($d in $drives) {
        $freeGB  = [math]::Round($d.FreeSpace / 1GB, 2)
        $totalGB = [math]::Round($d.Size / 1GB, 2)
        # Kasutame sama võrrandit, kuid salvestame juhuks hiljem eraldi
        $diskList += [pscustomobject]@{
            Drive   = $d.DeviceID
            Free_GB = $freeGB
            Total_GB = $totalGB
        }
    }
    return $diskList
}

# === 5. Peamine töövoog ===

# 5.1. Initsialiseerime logifaili (lisame päise, kui puudub)
Initialize-LogFile -Path $CsvPath

# 5.2. Kogume CPU ja mälu andmed
$metrics = Get-CpuMemoryMetrics

# 5.3. Kogume kettaandmed (võib olla mitu rida)
$diskMetrics = Get-DiskMetrics

# 5.4. Koostame timestamp’i
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# 5.5. Logime iga ketta kohta eraldi rea CSV-faili
foreach ($disk in $diskMetrics) {
    $line = "{0},{1},{2},{3},{4},{5},{6}" -f `
        $timestamp, `
        $metrics.CPU_Percent, `
        $metrics.TotalMemory_GB, `
        $metrics.FreeMemory_GB, `
        $disk.Drive, `
        $disk.Free_GB, `
        $disk.Total_GB

    # Lisame faili lõppu (Append)
    $line | Out-File -FilePath $CsvPath -Append -Encoding UTF8
}

# 5.6. Kuva skripti lõpus lühike teavitus
Write-Output "[${timestamp}] INFO: Terviseandmed logitud aadressile $CsvPath"
