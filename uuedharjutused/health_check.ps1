<#
.SYNOPSIS
  Kontrollib, kas teenus 'W3SVC' (IIS) on paigaldatud ja käivitunud.

.Kasutus
  Lae skript alla: C:\Scripts\IIS_Check.ps1
  Käivita PowerShell-is (jookse administraatori õigustes):
    powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\IIS_Check.ps1"
#>

param (
  # Võimalus määrata teenuse nimi käsurealt
  [string]$ServiceName = "W3SVC"
)

# Logi asukoht; vajadusel loo kataloog C:\Logs
$LogPath = "C:\Logs\IIS_Check.log"
if (-not (Test-Path $LogPath)) {
  # Kui logifail puudub, loo kaust ja päis
  $logDir = Split-Path $LogPath
  if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
  }
  "Timestamp,Level,Message" | Out-File -FilePath $LogPath -Encoding UTF8
}

# Funktsioon: logisõnumite salvestus
function Log-Message {
  param (
    [string]$Level,
    [string]$Message
  )
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $entry = "$timestamp,$Level,$Message"
  Add-Content -Path $LogPath -Value $entry
  Write-Output "[$timestamp] [$Level] $Message"
}

# 1) Kontrolli, kas teenus on paigaldatud
try {
  $svc = Get-Service -Name $ServiceName -ErrorAction Stop
} catch {
  Log-Message -Level "ERROR" -Message "Teenust '$ServiceName' ei leitud (mitte paigaldatud)."
  exit 1
}

Log-Message -Level "OK" -Message "Teenus '$ServiceName' on paigaldatud."

# 2) Kontrolli, kas teenus töötab
if ($svc.Status -eq "Running") {
  Log-Message -Level "OK" -Message "Teenus '$ServiceName' töötab: állikas."
  exit 0
} else {
  Log-Message -Level "WARN" -Message "Teenus '$ServiceName' on paigaldatud, kuid ei tööta (Status: $($svc.Status))."
  exit 2
}
