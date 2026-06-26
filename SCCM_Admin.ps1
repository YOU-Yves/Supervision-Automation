# ==========================================
# YOUTELL - SCRIPT ADMIN SCCM
# ==========================================
# Exécuté sur : ZEBUREAU-ADMIN (192.168.10.16)
# Cible       : ZEBUREAU-SCCM01 (192.168.10.15)
# Déclenché par : Power Automate Desktop
# ==========================================

# ==========================================
# CONFIGURATION
# ==========================================

$SiteCode      = "CCM"
$SiteServer    = "ZEBUREAU-SCCM01"
$InboxPath     = "C:\Users\youtell\YOUTELL RSSI\SUPERVISION - Général\SCCM\ToDo"
$ArchivePath   = "C:\Users\youtell\YOUTELL RSSI\SUPERVISION - Général\SCCM\Traites"
$LogPath       = "C:\Users\youtell\YOUTELL RSSI\SUPERVISION - Général\SCCM\Logs\SCCM_Admin.log"
$TempPath      = "C:\Users\youtell\YOUTELL RSSI\SUPERVISION - Général\SCCM\Logs"
$RemovalDelayH = 48

$DefenderMap = @{
    "Active"       = "PRD_Windows-Defender_Active"
    "Active_Cloud" = "PRD_Windows-Defender_Active_Cloud"
}

$ProductionMap = @{
    "SERVER"             = "PRD_APPS_SERVER"
    "RDS_ALL"            = "PRD_APPS_RDS_FULL_INSTALL_ALL"
    "RDS_JHP"            = "PRD_APPS_RDS_FULL_INSTALL_JHP"
    "RDS_STARCO"         = "PRD_APPS_RDS_FULL_INSTALL_STARCO"
    "RDS_NOAPPS"         = "PRD_APPS_RDS_FULL_INSTALL_NOAPPS"
    "RDS_WITHOUT_OFFICE" = "PRD_APPS_RDS_FULL_INSTALL_WITHOUT_OFFICE"
}

# ==========================================
# LOGGING
# ==========================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    switch ($Level) {
        "OK"    { Write-Host $line -ForegroundColor Green }
        "WARN"  { Write-Host $line -ForegroundColor Yellow }
        "ERROR" { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Gray }
    }
    if (-not (Test-Path (Split-Path $LogPath))) {
        New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

# ==========================================
# CONNEXION SCCM
# ==========================================

function Connect-SCCM {
    Write-Log "Connexion au site SCCM $SiteCode sur $SiteServer..."
    try {
        $modulePath = "$env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"
        Import-Module $modulePath -ErrorAction Stop
        if (-not (Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer -ErrorAction Stop | Out-Null
        }
        Set-Location "$SiteCode`:\"
        Write-Log "Connexion SCCM etablie." "OK"
        return $true
    } catch {
        Write-Log "Echec connexion SCCM : $_" "ERROR"
        return $false
    }
}

# ==========================================
# AJOUTER MACHINE DANS UNE COLLECTION
# ==========================================

function Add-MachineToCollection {
    param([string]$Hostname, [string]$CollectionName)
    try {
        $device = Get-CMDevice -Name $Hostname -ErrorAction Stop
        if (-not $device) {
            Write-Log "Machine '$Hostname' introuvable dans SCCM." "WARN"
            return $false
        }
        $collection = Get-CMDeviceCollection -Name $CollectionName -ErrorAction Stop
        if (-not $collection) {
            Write-Log "Collection '$CollectionName' introuvable." "WARN"
            return $false
        }
        $existing = Get-CMDeviceCollectionDirectMembershipRule `
            -CollectionName $CollectionName `
            -ResourceId $device.ResourceID `
            -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Log "Machine '$Hostname' deja dans '$CollectionName'." "WARN"
            return $true
        }
        Add-CMDeviceCollectionDirectMembershipRule `
            -CollectionName $CollectionName `
            -ResourceId $device.ResourceID `
            -ErrorAction Stop
        Write-Log "Machine '$Hostname' ajoutee dans '$CollectionName'." "OK"
        return $true
    } catch {
        Write-Log "Erreur ajout '$Hostname' dans '$CollectionName' : $_" "ERROR"
        return $false
    }
}

# ==========================================
# RETRAIT ONE SHOT (planifié)
# ==========================================

function Schedule-CollectionRemoval {
    param([string]$Hostname, [string]$CollectionName, [int]$DelayHours)

    $taskName      = "SCCM_Remove_" + $Hostname + "_" + ($CollectionName -replace '[^a-zA-Z0-9]', '_')
    $removeDate    = (Get-Date).AddHours($DelayHours)
    $scriptPath    = $TempPath + "\Remove_" + $Hostname + ".ps1"
    $modulePath    = $env:SMS_ADMIN_UI_PATH + "\..\ConfigurationManager.psd1"

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Import-Module '" + $modulePath + "' -ErrorAction Stop")
    $lines.Add("if (-not (Get-PSDrive -Name '" + $SiteCode + "' -ErrorAction SilentlyContinue)) {")
    $lines.Add("    New-PSDrive -Name '" + $SiteCode + "' -PSProvider CMSite -Root '" + $SiteServer + "' | Out-Null")
    $lines.Add("}")
    $lines.Add("Set-Location '" + $SiteCode + ":\\'")
    $lines.Add("`$device = Get-CMDevice -Name '" + $Hostname + "' -ErrorAction SilentlyContinue")
    $lines.Add("if (`$device) {")
    $lines.Add("    Remove-CMDeviceCollectionDirectMembershipRule -CollectionName '" + $CollectionName + "' -ResourceId `$device.ResourceID -Force -ErrorAction SilentlyContinue")
    $lines.Add("}")
    $lines.Add("Unregister-ScheduledTask -TaskName '" + $taskName + "' -Confirm:`$false -ErrorAction SilentlyContinue")
    $lines.Add("Remove-Item -Path '" + $scriptPath + "' -Force -ErrorAction SilentlyContinue")

    if (-not (Test-Path $TempPath)) { New-Item -Path $TempPath -ItemType Directory -Force | Out-Null }
    $lines | Out-File -FilePath $scriptPath -Encoding UTF8 -Force

    $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ("-NoProfile -ExecutionPolicy Bypass -File `"" + $scriptPath + "`"")
    $trigger   = New-ScheduledTaskTrigger -Once -At $removeDate
    $settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1) -DeleteExpiredTaskAfter (New-TimeSpan -Minutes 5)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Write-Log "Retrait planifie de '$Hostname' depuis '$CollectionName' dans $DelayHours h (a $($removeDate.ToString('yyyy-MM-dd HH:mm')))." "OK"
}

# ==========================================
# TRAITEMENT D'UN JSON
# ==========================================

function Process-JSON {
    param([string]$JsonFile)

    Write-Log "---- Traitement : $JsonFile ----"

    try {
        $data = Get-Content $JsonFile -Encoding UTF8 -Raw | ConvertFrom-Json
    } catch {
        Write-Log "Impossible de lire le JSON : $_" "ERROR"
        return
    }

    $hostname   = $data.Hostname
    $defender   = $data.Defender
    $production = $data.Production
    $reboot     = $data.Reboot

    Write-Log "Hostname   : $hostname"
    Write-Log "Defender   : $defender"
    Write-Log "Production : $production"
    Write-Log "Reboot     : $reboot"

    if ([string]::IsNullOrWhiteSpace($hostname)) {
        Write-Log "Hostname vide — fichier ignore." "ERROR"
        return
    }

    # --- DEFENDER ---
    if ($defender -ne "NONE" -and -not [string]::IsNullOrWhiteSpace($defender)) {
        if ($DefenderMap.ContainsKey($defender)) {
            Add-MachineToCollection -Hostname $hostname -CollectionName $DefenderMap[$defender]
        } else {
            Write-Log "Valeur Defender inconnue : '$defender'" "WARN"
        }
    } else {
        Write-Log "Defender : NONE — aucune action." "INFO"
    }

    # --- PRODUCTION (One Shot) ---
    if ($production -ne "NONE" -and -not [string]::IsNullOrWhiteSpace($production)) {
        if ($ProductionMap.ContainsKey($production)) {
            $collName = $ProductionMap[$production]
            $added = Add-MachineToCollection -Hostname $hostname -CollectionName $collName
            if ($added) {
                Schedule-CollectionRemoval -Hostname $hostname -CollectionName $collName -DelayHours $RemovalDelayH
            }
        } else {
            Write-Log "Valeur Production inconnue : '$production'" "WARN"
        }
    } else {
        Write-Log "Production : NONE — aucune action." "INFO"
    }

    # --- REBOOT ---
    if ($reboot -ne "NONE" -and -not [string]::IsNullOrWhiteSpace($reboot)) {
        $rebootConfigPath = "C:\Windows\Tools\Automation\Config\SCCM_Reboot_ByFolder.json"
        if (Test-Path $rebootConfigPath) {
            $rebootConfig = Get-Content $rebootConfigPath -Encoding UTF8 -Raw | ConvertFrom-Json
            $found = $false
            foreach ($group in $rebootConfig.PSObject.Properties) {
                if ($group.Name -like "*MONTH*") { continue }
                if ($group.Value -contains $reboot) {
                    Add-MachineToCollection -Hostname $hostname -CollectionName $reboot
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                Write-Log "Valeur Reboot '$reboot' non trouvee dans la config." "WARN"
            }
        } else {
            Write-Log "Config Reboot introuvable, tentative directe..." "WARN"
            Add-MachineToCollection -Hostname $hostname -CollectionName $reboot
        }
    } else {
        Write-Log "Reboot : NONE — aucune action." "INFO"
    }

    # --- ARCHIVAGE ---
    try {
        if (-not (Test-Path $ArchivePath)) { New-Item -Path $ArchivePath -ItemType Directory -Force | Out-Null }
        $archiveName = [System.IO.Path]::GetFileNameWithoutExtension($JsonFile) + "_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".json"
        Move-Item -Path $JsonFile -Destination "$ArchivePath\$archiveName" -Force
        Write-Log "JSON archive : $archiveName" "OK"
    } catch {
        Write-Log "Erreur archivage : $_" "ERROR"
    }

    Write-Log "---- Fin traitement : $hostname ----"
}

# ==========================================
# MAIN
# ==========================================

Write-Log "========================================"
Write-Log "Demarrage script Admin SCCM"
Write-Log "========================================"

$jsonFiles = Get-ChildItem -Path $InboxPath -Filter "*_SCCM.json" -File -ErrorAction SilentlyContinue |
             Where-Object { $_.DirectoryName -eq $InboxPath }

if ($jsonFiles.Count -eq 0) {
    Write-Log "Aucun fichier JSON a traiter." "INFO"
    exit 0
}

Write-Log "$($jsonFiles.Count) fichier(s) a traiter."

$connected = Connect-SCCM
if (-not $connected) {
    Write-Log "Abandon — connexion SCCM impossible." "ERROR"
    exit 1
}

foreach ($file in $jsonFiles) {
    Process-JSON -JsonFile $file.FullName
}

Set-Location $env:SystemRoot

Write-Log "========================================"
Write-Log "Script Admin SCCM termine."
Write-Log "========================================"