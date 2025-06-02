<#
.SYNOPSIS
  Kontrollib, kas teenus 'W3SVC' (IIS) on paigaldatud ja käivitunud.

.KASUTUS
  Salvesta skript kausta, nt C:\Scripts\IIS_Check.ps1
  Liigu PowerShell’is samasse kausta (cd C:\Scripts)
  Käivita administraatoriõigustes:
    powershell.exe -ExecutionPolicy Bypass -File ".\IIS_Check.ps1"
#>

param (
  # Võimalus määrata teenuse nimi käsurealt
  [string]$ServiceName = "W3SVC"
)

# Skripti käivituskaust (selle kausta sees luuakse log)
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

# Logi asukoht skripti kaustas
$LogPath = Join-Path -Path $ScriptDir -ChildPath "IIS_Check.log"

# Kui logifaili kataloogi pole (teoreetiliselt peaks $ScriptDir olemas olema), siis loo see
$logDir = Split-Path $LogPath
if (-not (Test-Path $logDir)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Kui logifail puudub, lisa päis
if (-not (Test-Path $LogPath)) {
  "Timestamp,Level,Message" | Out-File -FilePath $LogPath -Encoding UTF8
}

# Funktsioon: logisõnumite salvestus ja ekraanile väljatrükk
function Write-Message {
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
  Write-Message -Level "ERROR" -Message "Teenust '$ServiceName' ei leitud (mitte paigaldatud)."
  exit 1
}

Write-Message -Level "OK" -Message "Teenus '$ServiceName' on paigaldatud."

# 2) Kontrolli, kas teenus töötab
if ($svc.Status -eq "Running") {
  Write-Message -Level "OK" -Message "Teenus '$ServiceName' töötab."
  exit 0
} else {
  Write-Message -Level "WARN" -Message "Teenus '$ServiceName' on paigaldatud, kuid ei tööta (Status: $($svc.Status))."
  exit 2
}
