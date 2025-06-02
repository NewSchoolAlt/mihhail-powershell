<#
.SYNOPSIS
    Kogub süsteemi terviseandmed (CPU, DS, RAM) ja salvestab logifaili.

.NOTES
    Käivitamiseks Linuxi PowerShell Core või Windows PowerShell (mõningad käsklused võivad erineda).
    Logifail: /var/log/health_check.log
#>

param (
    [string]$LogFile = "/var/log/health_check.log"
)

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Write-Output $entry
    try {
        Add-Content -Path $LogFile -Value $entry
    } catch {
        Write-Output "Ei saanud kirjutada logifaili $LogFile: $_"
    }
}

Write-Log "Alustasin süsteemi tervisekontrolli..."

# 1) CPU koormus (Linuxis: top või /proc/loadavg)
try {
    $cpuLoad = (Get-Content "/proc/loadavg").Split()[0]
    Write-Log "CPU keskmine koormus (1-min): $cpuLoad"
} catch {
    Write-Log "Ei saanud lugeda /proc/loadavg: $_"
}

# 2) Mälu kasutus (Linux: free -m)
try {
    $mem = bash -c "free -m | awk 'NR==2 {printf(\"%s/%s MB (%.2f%%)\", \$3,\$2, \$3/\$2*100)}'" 2>&1
    Write-Log "Mälu kasutus: $mem"
} catch {
    Write-Log "Probleem mälu info kogumisel: $_"
}

# 3) Ketaste kasutus (Linux: df -h /)
try {
    $disk = bash -c "df -h / | awk 'NR==2 {printf(\"%s/%s (%s)\", \$3,\$2,\$5)}'" 2>&1
    Write-Log "Root-ketta kasutus: $disk"
} catch {
    Write-Log "Probleem kettakasutuse kogumisel: $_"
}

Write-Log "Süsteemi tervisekontroll lõppes."
exit 0
