<#
.SYNOPSIS
    Kontrollib, kas Apache2 (httpd) on installitud ja töökorras Windows Serveri PowerShelli keskkonnas (nt WSL-is või Linuxi PowerShellis).

.NOTES
    Käivitamiseks: Powershellis “./Check-Apache.ps1” (WC: Powershell Core Linuxi peal või Windowsi puhtal keskkonnal, aga siis Apache asemel nt IIS-i kontroll).
#>

param (
    [string]$ServiceName = "apache2",   # Linuxi Apache teenus. Kui Windows: "W3SVC" (IIS).
    [string]$LogPath = "/var/log/Check-Apache.log"
)

# Funktsioon logimiseks
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    # Kirjuta ka konsooli ja logifaili
    Write-Output $entry
    try {
        Add-Content -Path $LogPath -Value $entry
    } catch {
        Write-Output "Ei saanud kirjutada logifaili ${LogFile}: $_"
    }
}

# Alustame logimist
Write-Log "Starting Apache check (PowerShell)..."

# Kontrollime, kas systemd teenus eksisteerib
try {
    $unitFile = powershell -c "systemctl list-unit-files | Select-String '^$ServiceName.service'" 2>$null
} catch {
    Write-Log "systemctl ei ole saadaval või viga: $_"
    exit 1
}

if (-not $unitFile) {
    Write-Log "Teenust '$ServiceName' ei leitud. Ei ole installitud."
    exit 1
}

# Kontrollime teenuse staatust
$status = (powershell -c "systemctl is-active $ServiceName").Trim()
if ($status -eq "active") {
    Write-Log "$ServiceName on töökorras (active)."
} else {
    Write-Log "$ServiceName EI ole töökorras (status: $status)."
    # Võime lisada teenuse käivitamise loogi:
    # powershell -c "systemctl start $ServiceName"
}

exit 0
