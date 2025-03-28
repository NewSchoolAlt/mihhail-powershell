# PowerShell skript AD kasutaja eemaldamiseks
# Skript küsib eesnime ja perekonnanime, genereerib kasutajanime
# ja eemaldab vastava kasutaja aktiivkirjest

# Kasutaja sisendi küsimine
function Küsi-Kasutaja {
    $eesnimi = Read-Host -Prompt "Sisesta eesnimi"
    $perekonnanimi = Read-Host -Prompt "Sisesta perekonnanimi"
    
    # Valideeri, et sisendid ei ole tühjad
    if ([string]::IsNullOrWhiteSpace($eesnimi)) {
        Write-Host "Viga: Eesnimi ei saa olla tühi!" -ForegroundColor Red
        return $null, $null
    }
    
    if ([string]::IsNullOrWhiteSpace($perekonnanimi)) {
        Write-Host "Viga: Perekonnanimi ei saa olla tühi!" -ForegroundColor Red
        return $null, $null
    }
    
    return $eesnimi, $perekonnanimi
}

# Kasutajanime genereerimine
function Genereeri-Kasutajanimi {
    param (
        [string]$eesnimi,
        [string]$perekonnanimi
    )
    
    # Võta eesnime esimene täht ja lisa kogu perekonnanimi
    $kasutajanimi = ($eesnimi.Substring(0, 1) + $perekonnanimi).ToLower()
    
    return $kasutajanimi
}

# Domeeni ühenduse kontrollimine
function Kontrolli-Domeeniühendus {
    try {
        # Kontrolli ühendust domeeni kontrolleriga
        $domainController = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers[0].Name
        $ping = Test-Connection -ComputerName $domainController -Count 1 -Quiet
        
        if (-not $ping) {
            Write-Host "Viga: Domeeniga ei ole võimalik ühendust luua." -ForegroundColor Red
            return $false
        }
        
        return $true
    }
    catch {
        Write-Host "Viga: Domeeniga ei ole võimalik ühendust luua. Veateade: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Kasutaja eemaldamine
function Eemalda-Kasutaja {
    param (
        [string]$kasutajanimi
    )
    
    try {
        # Kontrolli, kas kasutaja eksisteerib
        $kasutajaOlemas = Get-ADUser -Identity $kasutajanimi -ErrorAction SilentlyContinue
        
        if ($null -eq $kasutajaOlemas) {
            Write-Host "Viga: Kasutajat '$kasutajanimi' ei eksisteeri." -ForegroundColor Yellow
            return
        }
        
        # Proovi kasutajat eemaldada
        Remove-ADUser -Identity $kasutajanimi -Confirm:$false
        Write-Host "Kasutaja '$kasutajanimi' on edukalt kustutatud." -ForegroundColor Green
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Host "Viga: Kasutajat '$kasutajanimi' ei eksisteeri." -ForegroundColor Yellow
    }
    catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Host "Viga: Kasutaja kustutamisel tekkis probleem õigustega. Veateade: $($_.Exception.Message)" -ForegroundColor Red
    }
    catch {
        Write-Host "Viga: Kasutaja kustutamisel tekkis ootamatu viga. Veateade: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Põhiprogramm
try {
    # Lae Active Directory moodul
    Import-Module ActiveDirectory -ErrorAction Stop
    
    # Küsi kasutaja andmed
    $eesnimi, $perekonnanimi = Küsi-Kasutaja
    
    # Kontrolli, kas andmed on olemas
    if ($null -eq $eesnimi -or $null -eq $perekonnanimi) {
        exit
    }
    
    # Genereeri kasutajanimi
    $kasutajanimi = Genereeri-Kasutajanimi -eesnimi $eesnimi -perekonnanimi $perekonnanimi
    Write-Host "Genereeritud kasutajanimi: $kasutajanimi" -ForegroundColor Cyan
    
    # Kontrolli domeeni ühendust
    if (-not (Kontrolli-Domeeniühendus)) {
        exit
    }
    
    # Kasutaja eemaldamine
    Eemalda-Kasutaja -kasutajanimi $kasutajanimi
}
catch {
    Write-Host "Kriitiline viga: $($_.Exception.Message)" -ForegroundColor Red
}

