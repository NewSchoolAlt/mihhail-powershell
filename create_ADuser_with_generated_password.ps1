<#
.SYNOPSIS
    Creates a new Active Directory user account.
.DESCRIPTION
    This script creates a new Active Directory user account based on first name and last name input.
    It generates a username, creates a secure random password, and logs user information to a CSV file.
.NOTES
    Requires Active Directory module
#>

# Import required module
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
if (-not (Get-Module -Name ActiveDirectory)) {
    Write-Host "ERROR: Active Directory module could not be loaded. Please ensure it is installed." -ForegroundColor Red
    exit 1
}

# Check domain connectivity
try {
    $domain = Get-ADDomain
    Write-Host "Successfully connected to domain: $($domain.DNSRoot)" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Could not connect to Active Directory domain. Please check your network connection and permissions." -ForegroundColor Red
    Write-Host "Error details: $_" -ForegroundColor Red
    exit 1
}

# Function to generate a secure random password
function New-RandomPassword {
    $length = 12
    $uppercase = "ABCDEFGHKLMNOPRSTUVWXYZ".ToCharArray()
    $lowercase = "abcdefghiklmnoprstuvwxyz".ToCharArray()
    $numbers = "0123456789".ToCharArray()
    $special = "!@#$%^&*()_-+={}[]|\:;<>,.?/~".ToCharArray()
    
    # Ensure at least one of each type
    $password = @(
        $uppercase | Get-Random
        $lowercase | Get-Random
        $numbers | Get-Random
        $special | Get-Random
    )
    
    # Fill the rest randomly
    $remainingLength = $length - $password.Count
    $allChars = $uppercase + $lowercase + $numbers + $special
    
    for ($i = 0; $i -lt $remainingLength; $i++) {
        $password += $allChars | Get-Random
    }
    
    # Shuffle the password array
    $password = $password | Sort-Object { Get-Random }
    
    return -join $password
}

# Function to check if CSV file exists and create if it doesn't
function Initialize-CsvFile {
    param (
        [string]$filePath
    )
    
    if (-not (Test-Path $filePath)) {
        $headers = "FirstName,LastName,Username,Password,Email,CreationTime"
        $headers | Out-File -FilePath $filePath -Encoding utf8
        Write-Host "Created new CSV file for user records: $filePath" -ForegroundColor Green
    }
}

# Prompt for user information
Write-Host "`n=== Active Directory User Creation Tool ===" -ForegroundColor Cyan
$firstName = Read-Host -Prompt "Enter first name"
$lastName = Read-Host -Prompt "Enter last name"

# Check if inputs are not empty
if ([string]::IsNullOrWhiteSpace($firstName) -or [string]::IsNullOrWhiteSpace($lastName)) {
    Write-Host "ERROR: First name and last name cannot be empty." -ForegroundColor Red
    exit 1
}

# Generate username (first letter of first name + last name, all lowercase)
$username = ($firstName.Substring(0, 1) + $lastName).ToLower()
$username = $username -replace '[^a-z0-9]', '' # Remove any special characters

Write-Host "Generated username: $username" -ForegroundColor Cyan

# Check if the username already exists
try {
    $userExists = Get-ADUser -Filter {SamAccountName -eq $username} -ErrorAction Stop
    if ($userExists) {
        Write-Host "ERROR: User with username '$username' already exists in Active Directory." -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "Username is available." -ForegroundColor Green
    }
}
catch {
    Write-Host "Error checking if username exists: $_" -ForegroundColor Red
    exit 1
}

# Generate a random password
$password = New-RandomPassword
$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force

Write-Host "Generated secure password." -ForegroundColor Green

# Construct email address using the domain from AD
$email = "$username@$($domain.DNSRoot)"

# Set UPN suffix
$upnSuffix = $domain.DNSRoot

# Create the new AD user
try {
    New-ADUser -Name "$firstName $lastName" `
               -GivenName $firstName `
               -Surname $lastName `
               -SamAccountName $username `
               -UserPrincipalName "$username@$upnSuffix" `
               -EmailAddress $email `
               -AccountPassword $securePassword `
               -Enabled $true `
               -ChangePasswordAtLogon $true `
               -PassThru | Out-Null
    
    Write-Host "Successfully created user '$firstName $lastName' in Active Directory." -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to create user in Active Directory." -ForegroundColor Red
    Write-Host "Error details: $_" -ForegroundColor Red
    exit 1
}

# Save user info to CSV
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "kasutanimi.csv"
Initialize-CsvFile -filePath $csvPath

$creationTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$userRecord = "$firstName,$lastName,$username,$password,$email,$creationTime"

try {
    $userRecord | Out-File -FilePath $csvPath -Encoding utf8 -Append
    Write-Host "User information saved to CSV file: $csvPath" -ForegroundColor Green
}
catch {
    Write-Host "WARNING: Failed to write user information to CSV file." -ForegroundColor Yellow
    Write-Host "Error details: $_" -ForegroundColor Yellow
}

# Display summary
Write-Host "`n=== User Creation Summary ===" -ForegroundColor Cyan
Write-Host "Name: $firstName $lastName" -ForegroundColor White
Write-Host "Username: $username" -ForegroundColor White
Write-Host "Email: $email" -ForegroundColor White
Write-Host "Password: $password" -ForegroundColor White
Write-Host "Created: $creationTime" -ForegroundColor White
Write-Host "`nUser must change password at next logon." -ForegroundColor Yellow
Write-Host "`nUser creation completed successfully!" -ForegroundColor Green

