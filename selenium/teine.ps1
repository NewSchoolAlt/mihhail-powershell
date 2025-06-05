Import-Module Selenium

# Määra ChromeDriver'i asukoht (eelduseks on, et chromedriver.exe on sama kaustas, kust skripti käivitad)
$chromeDriverPath = (Get-Location).Path

try {
    # Käivita Chrome Selenium abil
    $driver = Start-SeChrome -WebDriverDirectory $chromeDriverPath

    # Ava W3Schools HTML-vormide leht
    $driver.Navigate().GoToUrl("https://www.w3schools.com/html/html_forms.asp")

    # Vähene paus, et leht saaks alustada laadimist
    Start-Sleep -Seconds 1

    # Proovi automaatselt klikata "Accept Cookies" nupul (id="accept-choices") :contentReference[oaicite:0]{index=0}
    try {
        $cookieButton = $driver.FindElementById("accept-choices")
        if ($cookieButton) {
            $cookieButton.Click()
            # Kui vajalik, oota veel natuke, et banner kaoks
            Start-Sleep -Seconds 1
        }
    }
    catch {
        # Kui bannerit ei leitud, jätka ilma veateateta
    }

    # Lisa lühike paus, et lehe ülejäänud elemendid jõuaksid laadida
    Start-Sleep -Seconds 1

    # Leia tekstiväljad "First name" ja "Last name" ning oota, kuni need on saadaval
    $firstNameField = $null
    $lastNameField  = $null

    $timeout = 10
    $elapsed = 0
    while ((-not $firstNameField -or -not $lastNameField) -and ($elapsed -lt $timeout)) {
        try {
            if (-not $firstNameField) { $firstNameField = $driver.FindElementById("fname") }
            if (-not $lastNameField)  { $lastNameField  = $driver.FindElementById("lname") }
        }
        catch {
            Start-Sleep -Seconds 1
            $elapsed++
        }
    }

    if (-not $firstNameField -or -not $lastNameField) {
        throw "Tekstivälju ei õnnestunud 10 sekundi jooksul laadida."
    }

    # Sisesta nimed
    $firstNameField.Clear()
    $lastNameField.Clear()
    $firstNameField.SendKeys("Test")
    $lastNameField.SendKeys("User")

    # Leia ja vajuta "Submit" nuppu
    $submitButton = $driver.FindElementByXPath("//input[@type='submit' and @value='Submit']")
    $submitButton.Click()

    # Oota, kuni leht uuesti laeb ja tulemuse tekst ilmub
    Start-Sleep -Seconds 2

    # Loe tulemuse kogu tekst (<body> sisu) ja väljasta see konsooli
    $bodyText = $driver.FindElementByTagName("body").Text
    Write-Host "Tulemuse tekst:"
    Write-Host $bodyText
}
catch {
    Write-Host "Viga: $($_.Exception.Message)"
}
finally {
    Start-Sleep -Seconds 3
    # Sulge brauser
    if ($driver) {
        $driver.Quit()
    }
}
