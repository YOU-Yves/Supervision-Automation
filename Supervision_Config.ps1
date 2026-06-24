# ==========================================
# YOUTELL - SUPERVISION CONFIG TOOL
# ==========================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "YOUTELL - Supervision Config Tool"

# Taille minimale de la console
try {
    $b = $Host.UI.RawUI.BufferSize
    if ($b.Width -lt 90) { $b.Width = 90 }
    $Host.UI.RawUI.BufferSize = $b
    $w = $Host.UI.RawUI.WindowSize
    if ($w.Width  -lt 90) { $w.Width  = 90 }
    if ($w.Height -lt 42) { $w.Height = 42 }
    $Host.UI.RawUI.WindowSize = $w
} catch { }

# ==========================================
# ADMIN CHECK
# ==========================================

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host ""
    Write-Host "  [!] Ce script doit etre lance en tant qu'Administrateur." -ForegroundColor Red
    Write-Host ""
    Pause
    exit
}

# ==========================================
# PATHS & GLOBALS
# ==========================================

$toolsPath  = "C:\Windows\Tools"
$basePath   = "C:\Windows\Tools\Automation"
$configPath = "$basePath\Config"
$outputPath = "$basePath\Output"
$curl       = "C:\Windows\curl\curl.exe"

$FTP_BASE   = "sftp://supervision.youtell.cloud:8072"
$FTP_USER   = "sftpyoutell"
$FTP_PASS   = "Youtell974"
$FTP_CREDS  = "${FTP_USER}:${FTP_PASS}"

New-Item -Path $toolsPath  -ItemType Directory -Force | Out-Null
New-Item -Path $basePath   -ItemType Directory -Force | Out-Null
New-Item -Path $configPath -ItemType Directory -Force | Out-Null
New-Item -Path $outputPath -ItemType Directory -Force | Out-Null

# ==========================================
# UI HELPERS
# ==========================================

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ██╗   ██╗ ██████╗ ██╗   ██╗████████╗███████╗██╗     ██╗" -ForegroundColor Cyan
    Write-Host "  ╚██╗ ██╔╝██╔═══██╗██║   ██║╚══██╔══╝██╔════╝██║     ██║" -ForegroundColor Cyan
    Write-Host "   ╚████╔╝ ██║   ██║██║   ██║   ██║   █████╗  ██║     ██║" -ForegroundColor Cyan
    Write-Host "    ╚██╔╝  ██║   ██║██║   ██║   ██║   ██╔══╝  ██║     ██║" -ForegroundColor Cyan
    Write-Host "     ██║   ╚██████╔╝╚██████╔╝   ██║   ███████╗███████╗███████╗" -ForegroundColor Cyan
    Write-Host "     ╚═╝    ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝╚══════╝╚══════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "                  Supervision Config Tool" -ForegroundColor DarkCyan
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "  ── $Title " -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Status {
    param([string]$Label, [string]$Value, [string]$Color)
    $pad = $Label.PadRight(16)
    Write-Host "  $pad" -NoNewline
    Write-Host $Value -ForegroundColor $Color
}

function Write-MenuItem {
    param([string]$Key, [string]$Label, [string]$Color = "White")
    Write-Host "  " -NoNewline
    Write-Host "[$Key]" -ForegroundColor DarkCyan -NoNewline
    Write-Host "  $Label" -ForegroundColor $Color
}

function Write-Success { param([string]$Msg); Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg); Write-Host "  [!]  $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg); Write-Host "  [X]  $Msg" -ForegroundColor Red }
function Write-Info    { param([string]$Msg); Write-Host "  [-]  $Msg" -ForegroundColor DarkGray }

function Write-Separator {
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
}

function Pause-Return {
    Write-Host ""
    Write-Host "  Appuyez sur Entree pour revenir au menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ==========================================
# GET MACHINE INFO
# ==========================================

function Get-MachineInfo {
    $script:Hostname = $env:COMPUTERNAME

    # IP principale (exclut loopback)
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
           Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } |
           Select-Object -First 1).IPAddress

    $script:MachineIP = if ($ip) { $ip } else { "N/A" }

    # Domaine ou Workgroup
    $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs.PartOfDomain) {
        $script:MachineNetwork = $cs.Domain
        $script:MachineFQDN    = "$($env:COMPUTERNAME).$($cs.Domain)"
    } else {
        $script:MachineNetwork = "WORKGROUP: $($cs.Workgroup)"
        $script:MachineFQDN    = $env:COMPUTERNAME
    }
}

# ==========================================
# CHECK STATUS
# ==========================================

function Test-SCCM {
    return [bool](Get-Process -Name "CcmExec" -ErrorAction SilentlyContinue)
}

function Test-SCCM-Installing {
    return [bool](Get-Process -Name "CcmSetup" -ErrorAction SilentlyContinue)
}

function Test-SCOM {
    return [bool](Get-Process -Name "HealthService" -ErrorAction SilentlyContinue)
}

function Test-ScreenConnect {
    return [bool](Get-Service -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like "*ScreenConnect*" -or $_.DisplayName -like "*ScreenConnect*"
    })
}

# ==========================================
# DOWNLOAD IN SEPARATE WINDOW
# ==========================================

function Invoke-Download {
    param(
        [string]$RemotePath,
        [string]$LocalPath,
        [string]$Label = "Téléchargement en cours"
    )

    Write-Info "$Label..."

    $args = @(
        "-k",
        "$FTP_BASE/$RemotePath",
        "-u", $FTP_CREDS,
        "-o", $LocalPath,
        "--ftp-create-dirs",
        "--silent",
        "--show-error"
    )

    $proc = Start-Process -FilePath $curl `
        -ArgumentList $args `
        -PassThru `
        -WindowStyle Hidden `
        -Wait

    return ($proc.ExitCode -eq 0)
}

function Invoke-Upload {
    param(
        [string]$LocalPath,
        [string]$RemotePath,
        [string]$Label = "Envoi en cours"
    )

    Write-Info "$Label..."

    $args = @(
        "-k",
        "$FTP_BASE/$RemotePath",
        "-u", $FTP_CREDS,
        "-T", $LocalPath,
        "--ftp-create-dirs",
        "--silent",
        "--show-error"
    )

    $proc = Start-Process -FilePath $curl `
        -ArgumentList $args `
        -PassThru `
        -WindowStyle Hidden `
        -Wait

    return ($proc.ExitCode -eq 0)
}

# ==========================================
# LOAD CONFIG FROM FTP
# ==========================================

function Initialize-AutomationConfig {

    Write-Section "Chargement de la configuration"

    $files = @(
        "SCCM_Defender.json",
        "SCCM_Production.json",
        "SCCM_Reboot_ByFolder.json"
    )

    $ok = $true
    foreach ($file in $files) {
        $success = Invoke-Download `
            -RemotePath "automation/Config/$file" `
            -LocalPath "$configPath\$file" `
            -Label $file

        if ($success) { Write-Success $file }
        else           { Write-Err "Echec : $file"; $ok = $false }
    }

    return $ok
}

function Load-Config {
    $script:Defender   = Get-Content "$configPath\SCCM_Defender.json"   | ConvertFrom-Json
    $script:Production = Get-Content "$configPath\SCCM_Production.json" | ConvertFrom-Json
    $script:Reboot     = Get-Content "$configPath\SCCM_Reboot_ByFolder.json" | ConvertFrom-Json
}

# ==========================================
# INSTALL SCREENCONNECT
# ==========================================

function Install-ScreenConnect {

    Write-Header
    Write-Section "Installation ScreenConnect"

    $ok = Invoke-Download `
        -RemotePath "screenconnect/_Copy_install_ScreenConnect.bat" `
        -LocalPath  "C:\Windows\Tools\_Copy_install_ScreenConnect.bat" `
        -Label      "_Copy_install_ScreenConnect.bat"

    if (-not $ok) {
        Write-Err "Echec du telechargement. Verifier la connexion FTP."
        Pause-Return; return
    }

    Write-Success "Fichier telecharge."
    Write-Info "Lancement de l'installation dans une nouvelle fenetre..."
    Start-Process "C:\Windows\Tools\_Copy_install_ScreenConnect.bat" -Verb RunAs
    Pause-Return
}

# ==========================================
# INSTALL SCCM
# ==========================================

function Install-SCCM {

    Write-Header
    Write-Section "Installation SCCM"

    $ok = Invoke-Download `
        -RemotePath "sccm/_Copy_install.bat" `
        -LocalPath  "C:\Windows\Tools\_Copy_install_SCCM.bat" `
        -Label      "_Copy_install.bat"

    if (-not $ok) {
        Write-Err "Echec du telechargement. Verifier la connexion FTP."
        Pause-Return; return
    }

    Write-Success "Fichier telecharge."
    Write-Info "Lancement de l'installation dans une nouvelle fenetre..."
    Start-Process "cmd.exe" `
        -Verb RunAs `
        -ArgumentList "/K `"C:\Windows\Tools\_Copy_install_SCCM.bat`""

    Pause-Return
}

# ==========================================
# INSTALL SCOM
# ==========================================

function Install-SCOM {

    Write-Header
    Write-Section "Installation SCOM"

    $ok = Invoke-Download `
        -RemotePath "scom/_Copy_install_scom.bat" `
        -LocalPath  "C:\Windows\Tools\_Copy_install_scom.bat" `
        -Label      "_Copy_install_scom.bat"

    if (-not $ok) {
        Write-Err "Echec du telechargement. Verifier la connexion FTP."
        Pause-Return; return
    }

    Write-Success "Fichier telecharge."
    Write-Info "Lancement de l'installation dans une nouvelle fenetre..."
    Start-Process "C:\Windows\Tools\_Copy_install_scom.bat" -Verb RunAs
    Pause-Return
}

# ==========================================
# UNINSTALL SCCM
# ==========================================

function Uninstall-SCCM {

    Write-Header
    Write-Section "Desinstallation SCCM"

    $setup = "C:\Windows\ccmsetup\ccmsetup.exe"

    if (-not (Test-Path $setup)) {
        Write-Err "ccmsetup.exe introuvable — SCCM n'est peut-etre pas installe."
        Pause-Return; return
    }

    Write-Info "Lancement de la desinstallation dans une nouvelle fenetre..."
    Start-Process $setup -ArgumentList "/uninstall" -Verb RunAs
    Pause-Return
}

# ==========================================
# SCCM CONFIG MENUS
# ==========================================

function Select-Defender {

    Write-Section "Configuration Defender"
    Write-MenuItem "0" "Aucun" "DarkGray"
    Write-MenuItem "1" "Active"
    Write-MenuItem "2" "Active Cloud"
    Write-Host ""

    $choice = Read-Host "  Votre choix"

    switch ($choice) {
        "1" { return "Active" }
        "2" { return "Active_Cloud" }
        default { return "NONE" }
    }
}

function Select-Production {

    Write-Section "Type de serveur (Production)"

    $keys = $Production.PSObject.Properties.Name

    Write-MenuItem "0" "Aucun" "DarkGray"
    for ($i = 0; $i -lt $keys.Count; $i++) {
        Write-MenuItem "$($i+1)" $keys[$i]
    }
    Write-Host ""

    $choice = Read-Host "  Votre choix"

    if ($choice -eq "0" -or [string]::IsNullOrWhiteSpace($choice)) { return "NONE" }

    $idx = [int]$choice - 1
    if ($idx -ge 0 -and $idx -lt $keys.Count) { return $keys[$idx] }
    return "NONE"
}

function Select-Reboot {

    Write-Section "Planification des redemarrages"
    Write-MenuItem "0" "Aucun" "DarkGray"
    Write-MenuItem "1" "Quotidien (Daily)"
    Write-MenuItem "2" "Hebdomadaire (Weekly)"
    Write-MenuItem "3" "Periodique (Periodic)"
    Write-Host ""

    $choice = Read-Host "  Votre choix"

    switch ($choice) {
        "1" { $group = "Redemarrage_Datacenter_DAILY" }
        "2" { $group = "Redemarrage_Datacenter_WEEKLY" }
        "3" { $group = "Redemarrage_Datacenter_PERIODICALLY" }
        default { return "NONE" }
    }

    $list = $Reboot.$group

    Write-Host ""
    Write-MenuItem "0" "Aucun" "DarkGray"
    for ($i = 0; $i -lt $list.Count; $i++) {
        Write-MenuItem "$($i+1)" $list[$i]
    }
    Write-Host ""

    $choice2 = Read-Host "  Votre choix"

    if ($choice2 -eq "0" -or [string]::IsNullOrWhiteSpace($choice2)) { return "NONE" }

    $idx = [int]$choice2 - 1
    if ($idx -ge 0 -and $idx -lt $list.Count) { return $list[$idx] }
    return "NONE"
}

# ==========================================
# BUILD JSON
# ==========================================

function Build-JSON {
    param($Def, $Prod, $Reb)

    $data = [ordered]@{
        Type       = "SCCM"
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
# SEND JSON TO FTP
# ==========================================

function Send-Data {
    param([string]$file)

    $remotePath = "automation/inbox/$($env:COMPUTERNAME)_SCCM.json"
    $ok = Invoke-Upload `
        -LocalPath  $file `
        -RemotePath $remotePath `
        -Label      "Envoi vers $remotePath"

    return $ok
}

# ==========================================
# MAIN SCCM CONFIG
# ==========================================

function Start-SCCM-Config {

    Write-Header
    Write-Section "Configuration SCCM"

    # Charger la config depuis FTP
    $loaded = Initialize-AutomationConfig
    if (-not $loaded) {
        Write-Err "Impossible de charger la configuration. Abandon."
        Pause-Return; return
    }

    Load-Config

    # Sélections
    $def  = Select-Defender
    $prod = Select-Production
    $reb  = Select-Reboot

    # Récap
    Write-Header
    Write-Section "Recapitulatif"
    Write-Status "Hostname"   $env:COMPUTERNAME  "White"
    Write-Status "Defender"   $def               $(if ($def  -eq "NONE") { "DarkGray" } else { "Cyan" })
    Write-Status "Production" $prod              $(if ($prod -eq "NONE") { "DarkGray" } else { "Cyan" })
    Write-Status "Reboot"     $reb               $(if ($reb  -eq "NONE") { "DarkGray" } else { "Cyan" })
    Write-Host ""
    Write-Separator

    $confirm = Read-Host "  Confirmer l'envoi ? [O/n]"
    if ($confirm -eq "n" -or $confirm -eq "N") {
        Write-Warn "Annule."
        Pause-Return; return
    }

    # Build + Send
    Write-Host ""
    $jsonFile = Build-JSON $def $prod $reb
    Write-Success "JSON genere : $jsonFile"

    $sent = Send-Data $jsonFile
    if ($sent) {
        Write-Success "Configuration envoyee avec succes vers le serveur."
    } else {
        Write-Err "Echec de l'envoi FTP. Verifier la connexion et reessayer."
    }

    Pause-Return
}

# ==========================================
# MAIN MENU
# ==========================================

function Show-Menu {

    Get-MachineInfo
    Write-Header

    # Statuts
    Write-Section "Statut de la machine"
    Write-Status "Hostname"     $script:Hostname       "White"
    Write-Status "IP"           $script:MachineIP      "White"
    Write-Status "Reseau"       $script:MachineNetwork "White"
    Write-Host ""

    $scStatus = if (Test-ScreenConnect) { @("Installe", "Green") } else { @("Non installe", "Red") }
    $scLabel  = $scStatus[0]; $scColor = $scStatus[1]

    if (Test-SCCM) {
        $sccmLabel = "Installe"; $sccmColor = "Green"
    } elseif (Test-SCCM-Installing) {
        $sccmLabel = "Installation en cours..."; $sccmColor = "Yellow"
    } else {
        $sccmLabel = "Non installe"; $sccmColor = "Red"
    }

    $scomStatus = if (Test-SCOM) { @("Installe", "Green") } else { @("Non installe", "Red") }
    $scomLabel  = $scomStatus[0]; $scomColor = $scomStatus[1]

    Write-Status "ScreenConnect" $scLabel   $scColor
    Write-Status "SCCM"          $sccmLabel $sccmColor
    Write-Status "SCOM"          $scomLabel $scomColor

    Write-Separator

    # Menu
    Write-Section "Actions disponibles"
    Write-MenuItem "1" "Installer ScreenConnect"
    Write-MenuItem "2" "Installer SCCM"
    Write-MenuItem "3" "Installer SCOM"
    Write-MenuItem "4" "Configurer SCCM  (Defender / Production / Reboot)"  "Cyan"
    Write-MenuItem "5" "Desinstaller SCCM" "DarkGray"
    Write-MenuItem "0" "Quitter" "DarkGray"
    Write-Host ""
    Write-Separator
    Write-Host ""
}

# ==========================================
# LOOP — rafraîchissement automatique
# ==========================================

# Intervalle de rafraichissement du menu (secondes)
$refreshInterval = 3

while ($true) {

    Show-Menu
    Write-Host "  Votre choix : " -NoNewline -ForegroundColor White

    # Attente input avec rafraichissement automatique
    $input    = ""
    $deadline = (Get-Date).AddSeconds($refreshInterval)

    while ($true) {

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)

            # Entree = valider
            if ($key.Key -eq "Enter") {
                Write-Host ""
                break
            }

            # Backspace
            if ($key.Key -eq "Backspace") {
                if ($input.Length -gt 0) {
                    $input = $input.Substring(0, $input.Length - 1)
                    Write-Host "`b `b" -NoNewline
                }
                continue
            }

            # Caractere normal
            $input += $key.KeyChar
            Write-Host $key.KeyChar -NoNewline
            continue
        }

        # Timeout = on rafraichit le menu
        if ((Get-Date) -ge $deadline) {
            $input = ""
            break
        }

        Start-Sleep -Milliseconds 100
    }

    if ([string]::IsNullOrWhiteSpace($input)) { continue }

    switch ($input.Trim()) {
        "1" { Install-ScreenConnect }
        "2" { Install-SCCM }
        "3" { Install-SCOM }
        "4" { Start-SCCM-Config }
        "5" { Uninstall-SCCM }
        "0" { Clear-Host; exit }
        default {
            Write-Warn "Choix invalide."
            Start-Sleep -Seconds 1
        }
    }
}