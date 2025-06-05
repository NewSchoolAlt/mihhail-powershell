Import-Module Selenium



# see on natuke rohkem advanced ja optimised kui see mis mihhailiga koostasime, mi
# Määrake ChromeDriveri asukoht (eeldusel, et chromedriver.exe asub samas kaustas, kust skript käivitatakse)
$chromeDriverPath = (Get-Location).Path

try {
    # —————————————
    #  CHROMEDRIVERSERVICE’I KONFIGUREERIMINE
    # —————————————
    $service = [OpenQA.Selenium.Chrome.ChromeDriverService]::CreateDefaultService($chromeDriverPath)
    $service.HideCommandPromptWindow = $true
    $service.SuppressInitialDiagnosticInformation = $true

    # (Valikuline) Määrake Chrome’i logitasemeks ainult veateated
    $options = New-Object OpenQA.Selenium.Chrome.ChromeOptions
    $options.AddArgument("--log-level=3")

    # Käivitage ChromeDriver kasutades eelnevalt seadistatud service ja options
    $driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($service, $options)

    # —————————————
    #  NAVIGEERIMINE JA TEHTAVAD TOIMINGUD
    # —————————————

    # Avage W3Schools HTML-vormide lehekülg
    $driver.Navigate().GoToUrl("https://www.w3schools.com/html/html_forms.asp")
    Start-Sleep -Seconds 1

    # Proovige automaatselt klõpsata "Accept Cookies" nupul (kui see ilmub)
    try {
        $cookieButton = $driver.FindElementById("accept-choices")
        if ($cookieButton.Displayed -and $cookieButton.Enabled) {
            $cookieButton.Click()
            Start-Sleep -Seconds 1
        }
    }
    catch {
        # Kui küpsisenupu bännerit ei leita, jätkatakse vigadeta
    }

    Start-Sleep -Seconds 1

    # —————————————
    #  FIRST NAME JA LAST NAME VÄLJADE OOTAMINE
    # —————————————

    $timeout      = 15
    $elapsed      = 0
    $firstNameField = $null
    $lastNameField  = $null

    while ((-not $firstNameField -or -not $lastNameField) -and ($elapsed -lt $timeout)) {
        try {
            if (-not $firstNameField) {
                $candidate = $driver.FindElementById("fname") # parem kui XPath, mis võib lehe struktuuri muutumisel puruneda ja kui on pikk on aeglane
                if ($candidate.Displayed -and $candidate.Enabled) {
                    $firstNameField = $candidate
                }
            }
            if (-not $lastNameField) {
                $candidate = $driver.FindElementById("lname") # parem kui XPath, mis võib lehe struktuuri muutumisel puruneda ja kui on pikk on aeglane
                if ($candidate.Displayed -and $candidate.Enabled) {
                    $lastNameField = $candidate
                }
            }
        }
        catch {
            # Elementi veel ei leitud või ei ole nähtav/aktiivne
        }
        if (-not $firstNameField -or -not $lastNameField) {
            Start-Sleep -Seconds .5
            $elapsed++
        }
    }

    if (-not $firstNameField -or -not $lastNameField) {
        throw "Tekstivälju 'First name' või 'Last name' ei õnnestunud $timeout sekundi jooksul leida."
    }

    # —————————————
    #  TEKSTIVÄLJADELE NIMETE SISSEKIRJUTAMINE
    # —————————————

    $firstNameField.Clear()
    Start-Sleep -Milliseconds 200
    $firstNameField.SendKeys("Test")
    Start-Sleep -Milliseconds 200

    $lastNameField.Clear()
    Start-Sleep -Milliseconds 200
    $lastNameField.SendKeys("User")
    Start-Sleep -Milliseconds 200

    # —————————————
    #  SUBMIT-NUPU KLÕPSAMINE JA TULEMUSE KUVAMINE
    # —————————————

    $timeout = 10
    $elapsed = 0
    $submitButton = $null

    while (-not $submitButton -and ($elapsed -lt $timeout)) {
        try {
            $candidate = $driver.FindElementByXPath("//input[@type='submit' and @value='Submit']")
            if ($candidate.Displayed -and $candidate.Enabled) {
                $submitButton = $candidate
            }
        }
        catch {
            # Nuppu ei ole veel leitav
        }
        if (-not $submitButton) {
            Start-Sleep -Seconds 1
            $elapsed++
        }
    }

    if (-not $submitButton) {
        throw "'Submit' nuppu ei õnnestunud $timeout sekundi jooksul leida."
    }

    $submitButton.Click()
    Start-Sleep -Seconds 2

    $bodyText = $driver.FindElementByTagName("body").Text
    Write-Host "Tulemuse tekst:"
    Write-Host $bodyText
}
catch {
    Write-Host "Viga: $($_.Exception.Message)"
}
finally {
    Start-Sleep -Seconds 3
    if ($driver) {
        $driver.Quit()
    }
}
