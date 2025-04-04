$dateString = Get-Date -Format "yyyyMMdd"

$backupRoot = "C:\Backups"
if (-not (Test-Path -Path $backupRoot)) {
    New-Item -Path $backupRoot -ItemType Directory -Force | Out-Null
}

$users = Get-LocalUser | Select-Object Name, FullName

foreach ($user in $users) {
    $homePath = "C:\Users\$($user.Name)"
    
    if (Test-Path -Path $homePath) {
        try {
            $backupFileName = "$($user.Name)_backup_$dateString.zip"
            $backupPath = Join-Path -Path $backupRoot -ChildPath $backupFileName
            
            Compress-Archive -Path $homePath -DestinationPath $backupPath -Force
            Write-Output "Created backup for user $($user.Name): $backupPath"
        }
        catch {
            Write-Error "Error creating backup for user $($user.Name): $_"
        }
    }
    else {
        Write-Warning "No home folder found for user: $($user.Name) ($($user.FullName))"
    }
}

