# ==========================================
# YOUTELL - ORCHESTRATEUR ADMIN
# ==========================================
# Execute sur  : ZEBUREAU-ADMIN (192.168.10.16)
# Declenche par: Tache planifiee (toutes les 5 min)
# ==========================================

# ==========================================
# CONFIGURATION
# ==========================================

$ScriptsPath  = "C:\Windows\Tools\Automation"
$SCCMInbox    = "C:\Users\youtell\YOUTELL RSSI\SUPERVISION - General\SCCM"
$SCOMInbox    = "C:\Users\youtell\YOUTELL RSSI\SUPERVISION - General\SCOM"
$LogPath      = "C:\Windows\Tools\Automation\Logs\YOUTELL_Admin.log"
$SCOMServer   = "ZEBUREAU-SCOM.zeburo-youtell.local"

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
    $logDir = Split-Path $LogPath
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

# ==========================================
# APPROBATION AUTOMATIQUE SCOM
# ==========================================

function Invoke-SCOMApproval {

    Write-Log "Verification agents SCOM en attente d'approbation..."

    try {
        Import-Module OperationsManager -ErrorAction Stop
        New-SCOMManagementGroupConnection -ComputerName $SCOMServer -ErrorAction Stop

        $pending = Get-SCOMPendingManagement | Where-Object {
            $_.AgentPendingActionType -eq "ManualApproval"
        }

        if (-not $pending) {
            Write-Log "Aucun agent en attente d'approbation."
            return
        }

        Write-Log "$($pending.Count) agent(s) en attente d'approbation."

        foreach ($agent in $pending) {
            try {
                $agent | Approve-SCOMPendingManagement -ErrorAction Stop
                Write-Log "Agent approuve : $($agent.AgentName)" "OK"
            } catch {
                Write-Log "Echec approbation $($agent.AgentName) : $_" "ERROR"
            }
        }

    } catch {
        Write-Log "Erreur connexion SCOM : $_" "ERROR"
    }
}

# ==========================================
# MAIN
# ==========================================

Write-Log "========================================"
Write-Log "Demarrage YOUTELL_Admin.ps1"
Write-Log "========================================"

# --- SCAN SCCM ---
Write-Log "--- Scan dossier SCCM ---"
$sccmFiles = Get-ChildItem -Path $SCCMInbox -Filter "*_SCCM.json" -File -ErrorAction SilentlyContinue |
             Where-Object { $_.DirectoryName -eq $SCCMInbox }

if ($sccmFiles.Count -gt 0) {
    Write-Log "$($sccmFiles.Count) fichier(s) SCCM a traiter."
    $sccmScript = "$ScriptsPath\SCCM_Admin.ps1"
    if (Test-Path $sccmScript) {
        & $sccmScript
    } else {
        Write-Log "SCCM_Admin.ps1 introuvable : $sccmScript" "ERROR"
    }
} else {
    Write-Log "Aucun fichier SCCM a traiter."
}

# --- SCAN SCOM ---
Write-Log "--- Scan dossier SCOM ---"
$scomFiles = Get-ChildItem -Path $SCOMInbox -Filter "*_SCOM.json" -File -ErrorAction SilentlyContinue |
             Where-Object { $_.DirectoryName -eq $SCOMInbox }

if ($scomFiles.Count -gt 0) {
    Write-Log "$($scomFiles.Count) fichier(s) SCOM a traiter."
    $scomScript = "$ScriptsPath\SCOM_Admin.ps1"
    if (Test-Path $scomScript) {
        & $scomScript
    } else {
        Write-Log "SCOM_Admin.ps1 introuvable : $scomScript" "ERROR"
    }
} else {
    Write-Log "Aucun fichier SCOM a traiter."
}

# --- APPROBATION SCOM (toujours) ---
Write-Log "--- Approbation SCOM ---"
Invoke-SCOMApproval

Write-Log "========================================"
Write-Log "YOUTELL_Admin.ps1 termine."
Write-Log "========================================"