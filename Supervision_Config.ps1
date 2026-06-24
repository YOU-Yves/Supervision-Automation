# ==========================================
# YOUTELL - SUPERVISION CONFIG TOOL
# ==========================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ==========================================
# ADMIN CHECK
# ==========================================

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Merci de lancer en admin !" -ForegroundColor Red
    Pause
    exit
}

# ==========================================
# PATHS
# ==========================================

$toolsPath  = "C:\Windows\Tools"
$basePath   = "C:\Windows\Tools\Automation"
$configPath = "$basePath\Config"
$outputPath = "$basePath\Output"

$curl = "C:\windows\curl\curl.exe"

New-Item -Path $toolsPath  -ItemType Directory -Force | Out-Null
New-Item -Path $basePath   -ItemType Directory -Force | Out-Null
New-Item -Path $configPath -ItemType Directory -Force | Out-Null
New-Item -Path $outputPath -ItemType Directory -Force | Out-Null

# ==========================================
# AUTOMATION CONFIG (FTP)
# ==========================================

function Initialize-AutomationConfig {

    $files = @(
        "SCCM_Defender.json",
        "SCCM_Production.json",
        "SCCM_Reboot_ByFolder.json"
    )

    foreach ($file in $files) {

        $localFile = "$configPath\$file"

        & $curl -k `
        "sftp://supervision.youtell.cloud:8072/automation/Config/$file" `
        -u "sftpyoutell:Youtell974" `
        -o $localFile `
        --ftp-create-dirs
    }
}

# ==========================================
# LOAD CONFIG
# ==========================================

function Load-Config {

    $script:Defender   = Get-Content "$configPath\SCCM_Defender.json" | ConvertFrom-Json
    $script:Production = Get-Content "$configPath\SCCM_Production.json" | ConvertFrom-Json
    $script:Reboot     = Get-Content "$configPath\SCCM_Reboot_ByFolder.json" | ConvertFrom-Json
}

# ==========================================
# CHECK STATUS
# ==========================================

function Test-SCCM {
    return Get-Process -Name "CcmExec" -ErrorAction SilentlyContinue
}

function Test-SCCM-Install {
    return Get-Process -Name "CcmSetup" -ErrorAction SilentlyContinue
}

function Test-SCOM {
    return Get-Process -Name "HealthService" -ErrorAction SilentlyContinue
}

function Test-ScreenConnect {
    return Get-Service | Where-Object {
        $_.Name -like "*ScreenConnect*" -or
        $_.DisplayName -like "*ScreenConnect*"
    }
}

# ==========================================
# INSTALL SCREENCONNECT
# ==========================================

function Install-ScreenConnect {

    Write-Host "Installation ScreenConnect..." -ForegroundColor Yellow

    & $curl -k `
    "sftp://supervision.youtell.cloud:8072/screenconnect/_Copy_install_ScreenConnect.bat" `
    -u "sftpyoutell:Youtell974" `
    -o "C:\windows\tools\_Copy_install_ScreenConnect.bat" `
    --ftp-create-dirs

    Start-Sleep 2

    & "C:\windows\tools\_Copy_install_ScreenConnect.bat"
}

# ==========================================
# INSTALL SCCM
# ==========================================

function Install-SCCM {

    Write-Host "Installation SCCM..." -ForegroundColor Yellow

    & $curl -k `
    "sftp://supervision.youtell.cloud:8072/sccm/_Copy_install.bat" `
    -u "sftpyoutell:Youtell974" `
    -o "C:\windows\tools\_Copy_install_SCCM.bat" `
    --ftp-create-dirs

    Start-Sleep 2

    Start-Process powershell -Verb runAs -ArgumentList "-NoExit -File C:\windows\tools\_Copy_install_SCCM.bat"
}

# ==========================================
# INSTALL SCOM
# ==========================================

function Install-SCOM {

    Write-Host "Installation SCOM..." -ForegroundColor Yellow

    & $curl -k `
    "sftp://supervision.youtell.cloud:8072/scom/_Copy_install_scom.bat" `
    -u "sftpyoutell:Youtell974" `
    -o "C:\windows\tools\_Copy_install_scom.bat" `
    --ftp-create-dirs

    Start-Sleep 2

    & "C:\windows\tools\_Copy_install_scom.bat"
}

# ==========================================
# UNINSTALL
# ==========================================

function Uninstall-SCCM {

    Write-Host "Désinstallation SCCM..." -ForegroundColor Red

    if (Test-Path "C:\Windows\ccmsetup\ccmsetup.exe") {

        Start-Process "C:\Windows\ccmsetup\ccmsetup.exe" `
            -ArgumentList "/uninstall" `
            -Verb RunAs

    } else {
        Write-Host "ccmsetup introuvable !" -ForegroundColor Red
    }
}


# ==========================================
# SCCM MENUS
# ==========================================

function Select-Defender {

    Write-Host "`nDEFENDER"
    Write-Host "0 - Aucun"
    Write-Host "1 - Active"
    Write-Host "2 - Active Cloud"

    $choice = Read-Host "Choix"

    switch ($choice) {
        "1" { return "Active" }
        "2" { return "Active_Cloud" }
        default { return "NONE" }
    }
}

function Select-Production {

    Write-Host "`nTYPE SERVEUR"

    $keys = $Production.PSObject.Properties.Name

    for ($i=0; $i -lt $keys.Count; $i++) {
        Write-Host "$($i+1) - $($keys[$i])"
    }

    Write-Host "0 - Aucun"

    $choice = Read-Host "Choix"

    if ($choice -eq "0") { return "NONE" }

    return $keys[[int]$choice - 1]
}

function Select-Reboot {

    Write-Host "`nREBOOT"
    Write-Host "0 - Aucun"
    Write-Host "1 - Daily"
    Write-Host "2 - Weekly"
    Write-Host "3 - Periodic"

    $choice = Read-Host "Choix"

    switch ($choice) {
        "1" { $group = "Redemarrage_Datacenter_DAILY" }
        "2" { $group = "Redemarrage_Datacenter_WEEKLY" }
        "3" { $group = "Redemarrage_Datacenter_PERIODICALLY" }
        default { return "NONE" }
    }

    $list = $Reboot.$group

    for ($i=0; $i -lt $list.Count; $i++) {
        Write-Host "$($i+1) - $($list[$i])"
    }

    $choice2 = Read-Host "Choix"
    return $list[[int]$choice2 - 1]
}

# ==========================================
# BUILD JSON
# ==========================================

function Build-JSON {

    param($Def,$Prod,$Reb)

    $data = @{
        Hostname   = $env:COMPUTERNAME
        Defender   = $Def
        Production = $Prod
        Reboot     = $Reb
    }

    $file = "$outputPath\$($env:COMPUTERNAME)_SCCM.json"

    $data | ConvertTo-Json -Depth 3 | Out-File $file -Encoding UTF8

    return $file
}

# ==========================================
# SEND JSON
# ==========================================

function Send-Data {

    param($file)

    & $curl -k `
    "sftp://supervision.youtell.cloud:8072/inbox/$($env:COMPUTERNAME).json" `
    -u "sftpyoutell:Youtell974" `
    -T $file
}

# ==========================================
# MAIN SCCM CONFIG
# ==========================================

function Start-SCCM-Config {

    Initialize-AutomationConfig
    Load-Config

    $def  = Select-Defender
    $prod = Select-Production
    $reb  = Select-Reboot

    $json = Build-JSON $def $prod $reb
    Send-Data $json
}

# ==========================================
# MENU
# ==========================================

function Show-Menu {

    Clear-Host

    Write-Host "=============================="
    Write-Host "YOUTELL SUPERVISION TOOL"
    Write-Host "=============================="
    Write-Host ""
    Write-Host ""

    if (Test-ScreenConnect) { Write-Host "ScreenConnect : Installé" -ForegroundColor Green }
    else { Write-Host "ScreenConnect : Non installé" -ForegroundColor Red }



    if (Test-SCCM) {
        Write-Host "SCCM : Installé" -ForegroundColor Green
    }
    elseif (Test-SCCM-Install) {
        Write-Host "SCCM : En cours..." -ForegroundColor Yellow
    }
    else {
        Write-Host "SCCM : Non installé" -ForegroundColor Red
    }


    if (Test-SCOM) { Write-Host "SCOM : Installé" -ForegroundColor Green }
    else { Write-Host "SCOM : Non installé" -ForegroundColor Red }

    Write-Host ""
    Write-Host "------------------------------" -ForegroundColor Green
    Write-Host ""
    Write-Host "1 - Installer ScreenConnect"
    Write-Host "2 - Installer SCCM"
    Write-Host "3 - Installer SCOM"
    Write-Host "4 - Configurer SCCM"
    Write-Host "5 - Désinstaller SCCM"
    Write-Host "0 - Quitter"
    Write-Host ""
    Write-Host "------------------------------" -ForegroundColor Green
    Write-Host ""
}

# ==========================================
# LOOP
# ==========================================

do {

    Show-Menu
    $choice = Read-Host "Choix"

    switch ($choice) {

        "1" { Install-ScreenConnect }
        "2" { Install-SCCM }
        "3" { Install-SCOM }
        "4" { Start-SCCM-Config }
        "5" { Uninstall-SCCM }
        "0" { break }
    }

    Start-Sleep 3

} while ($true)