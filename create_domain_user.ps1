# Test domain connectivity and membership
try {
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
    Write-Host "Connected to domain: $($domain.Name)"
} catch {
    Write-Host "Error: Could not connect to domain. Please ensure you are connected to the domain 'sitajunn.uss'"
    exit 1
}

# Function to validate password complexity
function Test-PasswordComplexity {
    param([string]$Password)
    if ($Password.Length -lt 8) { return $false }
    if ($Password -notmatch '[A-Z]') { return $false }
    if ($Password -notmatch '[a-z]') { return $false }
    if ($Password -notmatch '[0-9]') { return $false }
    if ($Password -notmatch '[^A-Za-z0-9]') { return $false }
    return $true
}

# Küsib kasutaja eesnime
$firstName = Read-Host "Enter the user's esi nimi"
# Küsib kasutaja perekonnanime
$lastName = Read-Host "Enter the user's perekonna nimi"

# Koostab kasutajanime (eesnime esimene täht + perekonnanimi)
$username = ($firstName.Substring(0,1) + $lastName).ToLower()

# Kontrollib, kas kasutaja juba eksisteerib domeenis
try {
    $existingUser = Get-ADUser -Filter {SamAccountName -eq $username} -ErrorAction Stop
    if ($existingUser) {
        Write-Host "Error: Kasutaja '$username' on juba olemas domeenis sitajunn.uss"
        exit 1
    }
} catch {
    Write-Host "Error kontrollides kasutajat domeenis: $_"
    exit 1
}

Write-Host "`nParooli nõuded:"
Write-Host "- Vähemalt 8 tähemärki"
Write-Host "- Vähemalt üks suurtäht"
Write-Host "- Vähemalt üks väiketäht"
Write-Host "- Vähemalt üks number"
Write-Host "- Vähemalt üks erimärk"

do {
    $plainPassword = Read-Host "Sisesta parool uuele kasutajale"
    if (-not (Test-PasswordComplexity -Password $plainPassword)) {
        Write-Host "Parool ei vasta nõuetele. Palun proovi uuesti."
        continue
    }
    $password = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force
    break
} while ($true)

# Loob uue domeeni kasutaja
try {
    $userParams = @{
        Name = "$firstName $lastName"
        GivenName = $firstName
        Surname = $lastName
        SamAccountName = $username
        UserPrincipalName = "$username@sitajunn.uss"
        AccountPassword = $password
        Enabled = $true
        PasswordNeverExpires = $true
        Path = "DC=sitajunn,DC=uss"
        DisplayName = "$firstName $lastName"
    }

    New-ADUser @userParams
    Write-Host "Kasutaja '$username' on edukalt loodud domeenis sitajunn.uss"
} catch {
    Write-Host "Error: Kasutaja loomine ebaõnnestus: $_"
    exit 1
}
