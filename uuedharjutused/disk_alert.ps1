<#
.SYNOPSIS
    Kontrollib, kas root-ketas on üle 70% täis. Kui jah, saadab e-kirja.

.NOTES
    Ettetäidetud SMTP seaded – kohanda enda juures kehtivatega:
        - $SmtpServer, $SmtpPort, $SmtpUser, $SmtpPass
        - $MailFrom ja $MailTo kohanda enda e-posti aadressidega
#>

param (
    [int]$ThresholdPercent = 70,
    [string]$LogFile = "/var/log/disk_alert.log"
)

# SMTP seaded (näidis)
$SmtpServer = "smtp.example.com"
$SmtpPort   = 587
$SmtpUser   = "alert@example.com"
$SmtpPass   = "SinuSalajaneParool"
$MailFrom   = "alert@example.com"
$MailTo     = "sinuaadress@too.ee"
$Subject    = "ALERT: Kettakasutus üle $ThresholdPercent%"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Write-Output $entry
    try {
        Add-Content -Path $LogFile -Value $entry
    } catch {
        Write-Output "Ei saanud kirjutada logifaili ${LogFile}: $_"
    }
}

Write-Log "Alustan ketta kasutuse kontrolli..."

# Saame kettakasutuse (root) Linuxis: df -h /
try {
    $usageLine = bash -c "df -h / | awk 'NR==2 {print \$5}'" 2>&1
    # Tulemuseks nt "65%"
    $percentString = $usageLine.Trim()
    if ($percentString -match "(\d+)%") {
        $percentValue = [int]$matches[1]
    } else {
        throw "Ei saanud protsenti parsida: $percentString"
    }

    Write-Log "Root-ketta kasutus: $percentString"

    if ($percentValue -gt $ThresholdPercent) {

        $body = @"
Kettakasutus on jõudnud $percentString (üle seatud läve $ThresholdPercent%).
Palun kontrolli VM-i kettaruumi.
"@

        Write-Log "ALARM: Ketakasutus ületas $ThresholdPercent%. Saadan e-kirja..."

        Send-MailMessage `
            -SmtpServer $SmtpServer `
            -Port $SmtpPort `
            -UseSsl `
            -Credential (New-Object System.Management.Automation.PSCredential($SmtpUser, (ConvertTo-SecureString $SmtpPass -AsPlainText -Force))) `
            -From $MailFrom `
            -To $MailTo `
            -Subject $Subject `
            -Body $body

        Write-Log "E-kiri saadetud aadressile $MailTo."
    } else {
        Write-Log "Ketakasutus ($percentString) on alla $ThresholdPercent%, ei saada e-kirja."
    }
} catch {
    Write-Log "Viga ketakasutuse kontrollimisel: $_"
}

Write-Log "Ketta kontrolli lõpp."
exit 0
