# ==========================================
# YOUTELL - SCRIPT ADMIN SCOM
# ==========================================
# Execute sur  : ZEBUREAU-ADMIN (192.168.10.16)
# Cible SCOM   : ZEBUREAU-SCOM (192.168.10.12)
# Cible FTP    : ZEBU-FTP (192.168.10.7)
# Appele par   : YOUTELL_Admin.ps1
# ==========================================

# ==========================================
# CONFIGURATION
# ==========================================

$SCOMServerIP = "192.168.10.12"
$CertWorkdir  = "C:\SCOM_AGENT\Certificate_Agent_Worksgroup"
$FTPScomShare = "\\zebu-ftp\ftp$\scom"
$InboxPath    = "C:\Users\youtell\YOUTELL RSSI\SUPERVISION - General\SCOM"
$ArchivePath  = "C:\Users\youtell\YOUTELL RSSI\SUPERVISION - General\SCOM\Traites"
$LogPath      = "C:\Windows\Tools\Automation\Logs\SCOM_Admin.log"

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
# GENERATION CERTIFICAT SUR ZEBUREAU-SCOM
# ==========================================

function Invoke-CertificateGeneration {
    param([string]$FQDN)

    Write-Log "Generation du certificat pour $FQDN sur $SCOMServerIP..."

    try {
        $result = Invoke-Command -ComputerName $SCOMServerIP -ErrorAction Stop -ScriptBlock {
            param($fqdn, $workdir)

            Set-Location $workdir

            # Hostname seul (sans domaine)
            $hostname = $fqdn.Split(".")[0]

            # Nettoyage anciens fichiers
            if (Test-Path "$workdir\$hostname.pfx")        { Remove-Item "$workdir\$hostname.pfx"        -Force }
            if (Test-Path "$workdir\${hostname}_Save.pfx") { Remove-Item "$workdir\${hostname}_Save.pfx" -Force }

            # Lancement create_cetificate.bat
            $batFile = "$workdir\create_cetificate.bat"
            if (-not (Test-Path $batFile)) {
                return @{ Success = $false; Error = "create_cetificate.bat introuvable dans $workdir" }
            }

            $proc = Start-Process -FilePath "cmd.exe" `
                -ArgumentList "/C `"$batFile`" $fqdn" `
                -WorkingDirectory $workdir `
                -PassThru -Wait -WindowStyle Hidden

            if ($proc.ExitCode -ne 0) {
                return @{ Success = $false; Error = "Echec create_cetificate.bat (code $($proc.ExitCode))" }
            }

            # Verification .pfx genere
            $pfxFile = "$workdir\$hostname.pfx"
            if (-not (Test-Path $pfxFile)) {
                return @{ Success = $false; Error = "Fichier .pfx non trouve : $pfxFile" }
            }

            return @{ Success = $true; PfxPath = $pfxFile; Hostname = $hostname }

        } -ArgumentList $FQDN, $CertWorkdir

        if (-not $result.Success) {
            Write-Log "Echec generation certificat : $($result.Error)" "ERROR"
            return $null
        }

        Write-Log "Certificat genere : $($result.PfxPath)" "OK"
        return $result

    } catch {
        Write-Log "Erreur Invoke-Command sur $SCOMServerIP : $_" "ERROR"
        return $null
    }
}

# ==========================================
# COPIE PFX VERS FTP
# ==========================================

function Copy-CertToFTP {
    param([string]$Hostname)

    Write-Log "Copie du certificat vers $FTPScomShare..."

    try {
        $sourcePfx = "\\$SCOMServerIP\C$\SCOM_AGENT\Certificate_Agent_Worksgroup\$Hostname.pfx"

        if (-not (Test-Path $sourcePfx)) {
            Write-Log "Fichier source introuvable : $sourcePfx" "ERROR"
            return $false
        }

        $destPfx = "$FTPScomShare\$Hostname.pfx"
        Copy-Item -Path $sourcePfx -Destination $destPfx -Force -ErrorAction Stop
        Write-Log "Certificat copie : $destPfx" "OK"
        return $true

    } catch {
        Write-Log "Erreur copie certificat : $_" "ERROR"
        return $false
    }
}

# ==========================================
# TRAITEMENT D'UN JSON SCOM
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

    $hostname = $data.Hostname
    $fqdn     = if ($data.FQDN) { $data.FQDN } else { $hostname }

    Write-Log "Hostname : $hostname"
    Write-Log "FQDN     : $fqdn"

    if ([string]::IsNullOrWhiteSpace($hostname)) {
        Write-Log "Hostname vide - fichier ignore." "ERROR"
        return
    }

    # Etape 1 : Generation certificat
    $certResult = Invoke-CertificateGeneration -FQDN $fqdn
    if (-not $certResult) {
        Write-Log "Abandon - echec generation certificat." "ERROR"
        return
    }

    # Etape 2 : Copie .pfx vers FTP
    $copied = Copy-CertToFTP -Hostname $certResult.Hostname
    if (-not $copied) {
        Write-Log "Abandon - echec copie FTP." "ERROR"
        return
    }

    Write-Log "Certificat disponible sur FTP - la VM peut maintenant installer SCOM." "OK"
    Write-Log "L'approbation SCOM sera effectuee automatiquement par YOUTELL_Admin.ps1." "OK"

    # Archivage
    try {
        if (-not (Test-Path $ArchivePath)) { New-Item -Path $ArchivePath -ItemType Directory -Force | Out-Null }
        $archiveName = [System.IO.Path]::GetFileNameWithoutExtension($JsonFile) + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".json"
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
Write-Log "Demarrage script Admin SCOM"
Write-Log "========================================"

$jsonFiles = Get-ChildItem -Path $InboxPath -Filter "*_SCOM.json" -File -ErrorAction SilentlyContinue |
             Where-Object { $_.DirectoryName -eq $InboxPath }

if ($jsonFiles.Count -eq 0) {
    Write-Log "Aucun fichier JSON a traiter."
    exit 0
}

Write-Log "$($jsonFiles.Count) fichier(s) a traiter."

foreach ($file in $jsonFiles) {
    Process-JSON -JsonFile $file.FullName
}

Write-Log "========================================"
Write-Log "Script Admin SCOM termine."
Write-Log "========================================"