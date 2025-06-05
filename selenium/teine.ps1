Import-Module Selenium

# Määrake ChromeDriveri asukoht (eeldusel, et chromedriver.exe asub samas kaustas, kust skript käivitatakse)
$chromeDriverPath = (Get-Location).Path

try {
    # —————————————
    #  CHROMEDRIVERSERVICE’I KONFIGUREERIMINE
    # —————————————
    # Looge ChromeDriverService, et varjata käsuviiba akent ja vaikida algdiagnostika teated
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

    # Proovige automaatselt klõpsata "Accept Cookies" nupul (id="accept-choices")
    try {
        $cookieButton = $driver.FindElementById("accept-choices")
        if ($cookieButton) {
            $cookieButton.Click()
            # Oodake veidi, kuni bänner kaob
            Start-Sleep -Seconds 1
        }
    }
    catch {
        # Kui küpsise nõusoleku bännerit ei leita, jätkatakse vigadeta
    }

    # Lühike paus, et lehe ülejäänud elemendid jõuaksid laadida
    Start-Sleep -Seconds 1

    # Oodake tekstiväljade "First name" ja "Last name" ilmumist, kuni maksimaalselt 10 sekundit
    $firstNameField = $null
    $lastNameField  = $null
    $timeout = 10
    $elapsed = 0

    while ((-not $firstNameField -or -not $lastNameField) -and ($elapsed -lt $timeout)) {
        try {
            if (-not $firstNameField) {
                $firstNameField = $driver.FindElementByXPath("/html/body/div[5]/div/div[2]/div[1]/div[1]/div[3]/div/form/input[1]")
            }
            if (-not $lastNameField) {
                $lastNameField = $driver.FindElementByXPath("/html/body/div[5]/div/div[2]/div[1]/div[1]/div[3]/div/form/input[2]")
            }
        }
        catch {
            Start-Sleep -Seconds 1
            $elapsed++
        }
    }

    if (-not $firstNameField -or -not $lastNameField) {
        throw "Tekstivälju ei õnnestunud 10 sekundi jooksul laadida."
    }

    # Sisestage tekstiväljadele nimed "Test" ja "User"
    $firstNameField.Clear()
    $lastNameField.Clear()
    $firstNameField.SendKeys("Test")
    $lastNameField.SendKeys("User")

    # Leidke ja klõpsake "Submit" nuppu
    $submitButton = $driver.FindElementByXPath("//input[@type='submit' and @value='Submit']")
    $submitButton.Click()

    # Oodake, kuni leht uuesti laeb ja tulemus ilmub
    Start-Sleep -Seconds 2

    # Looge lehe kogu tekst (<body> sisu) ja väljasta see konsooli
    $bodyText = $driver.FindElementByTagName("body").Text
    Write-Host "Tulemuse tekst:"
    Write-Host $bodyText
}
catch {
    Write-Host "Viga: $($_.Exception.Message)"
}
finally {
    # Lühike paus enne brauseri sulgemist
    Start-Sleep -Seconds 3

    # Sulgege brauser, kui draiver on olemas
    if ($driver) {
        $driver.Quit()
    }
}
