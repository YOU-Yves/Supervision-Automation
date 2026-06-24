# 📄 CAHIER DES CHARGES — Plateforme d'Automatisation SCCM / SCOM / Supervision
**YOUTELL — Document de référence projet | Juin 2025**

---

## 1. Contexte

Ce projet vise à remplacer l'ensemble des opérations manuelles liées à l'intégration de nouvelles VMs dans l'infrastructure YOUTELL par une plateforme d'automatisation complète.

Actuellement, chaque mise en production implique une série d'actions manuelles sur plusieurs serveurs (SCCM, SCOM, FTP, console ScreenConnect), sources d'erreurs et consommatrices de temps.

La plateforme cible orchestre automatiquement :
- L'installation et la configuration des agents (SCCM, SCOM, ScreenConnect)
- L'ajout de la VM dans les bonnes collections SCCM
- La génération et le déploiement du certificat SCOM
- Les notifications Teams à l'équipe
- L'ensemble des workflows via Power Automate

---

## 2. Infrastructure existante

### 2.1 Serveurs

| Hostname | IP | Rôle |
|---|---|---|
| ZEBU-FTP | 192.168.10.7 | Serveur FTP SFTP — dépôt configs, certificats, agents |
| ZEBUREAU-SCOM | 192.168.10.12 | Serveur SCOM — génération certificats, supervision |
| ZEBUREAU-SCCM01 | 192.168.10.15 | Serveur SCCM — gestion collections machines |
| ZEBUREAU-ADMIN | 192.168.10.16 | Serveur Admin — orchestration, scripts, OneDrive sync |

### 2.2 Serveur FTP

```
sftp://supervision.youtell.cloud:8072/
```

Structure des dossiers :
```
automation/
 └── Config/
     ├── SCCM_Defender.json
     ├── SCCM_Production.json
     └── SCCM_Reboot_ByFolder.json
sccm/
 ├── _Copy_install.bat
 └── _Copy_uninstall_SCCM.bat
scom/
 ├── MOMAgent.msi
 ├── MOMCertImport.exe
 ├── Agent_SCOM.bat
 ├── _Install.bat
 ├── ZEBUREAU-SCOM.zeburo-youtell.local.pfx
 ├── <HOSTNAME>.pfx         ← généré par machine
 └── (fichiers .mst multilingues)
screenconnect/
 └── _Copy_install_ScreenConnect.bat
inbox/
 └── <HOSTNAME>.json        ← JSON envoyés par les VMs
```

### 2.3 Stockage partagé (OneDrive / SharePoint)

Chemin local sur ZEBUREAU-ADMIN :
```
C:\Users\youtell\YOUTELL RSSI\SUPERVISION - Général\SCCM
C:\Users\youtell\YOUTELL RSSI\SUPERVISION - Général\SCOM
```

Ces dossiers sont synchronisés via OneDrive et servent de déclencheurs pour Power Automate.

---

## 3. Workflow global

### 3.1 Processus actuel (manuel)

| Étape | Action | Où |
|---|---|---|
| 1 | Créer la VM, la renommer, lui attribuer une IP | Hyperviseur |
| 2 | Installer ScreenConnect via curl + .bat | VM |
| 3 | Installer agent SCCM via curl + .bat | VM |
| 4 | Obtenir le FQDN exact de la machine (ping via ScreenConnect) | ZEBUREAU-SCOM |
| 5 | Éditer `_Install_Complet.bat` avec le FQDN, l'exécuter en admin | ZEBUREAU-SCOM |
| 6 | Récupérer le .pfx généré, le copier dans `\\zebu-ftp\ftp$\scom` (renommer sans domaine si nécessaire) | ZEBUREAU-SCOM → FTP |
| 7 | Lancer `_Copy_install_scom.bat` sur la VM | VM |
| 8 | Ajouter la VM dans les collections SCCM (Defender, Production, Reboot) | Console SCCM |
| 9 | Lancer "Récupération de stratégie ordinateur" sur la VM | VM |
| 10 | Approuver l'agent SCOM dans la console (Administration > En attente) | Console SCOM |

### 3.2 Processus cible (automatisé)

```
VM
 └── Utilisateur lance Supervision_Config.ps1
      └── Menu : choix Defender / Production / Reboot
           └── Génération JSON + upload FTP → /inbox/
                └── Power Automate détecte le fichier (OneDrive sync)
                     ├── Notification Teams (canal Général)
                     └── Script Admin déclenché sur ZEBUREAU-ADMIN
                          ├── Ajout VM dans collections SCCM
                          ├── Génération certificat SCOM (appel sur ZEBUREAU-SCOM)
                          ├── Copie .pfx vers FTP
                          └── Approbation SCOM (auto ou guidée)
```

---

## 4. Modules détaillés

### 4.1 Module VM — `Supervision_Config.ps1`

**Fichier unique sur la VM :** `C:\Windows\Tools\Supervision_Config.ps1`

**Raccourci de lancement :**
```
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -ExecutionPolicy Bypass -File "C:\Windows\Tools\Supervision_Config.ps1"
```

#### Fonctions existantes
- Menu principal avec statut ScreenConnect / SCCM / SCOM
- Installation SCCM, SCOM, ScreenConnect via curl + .bat
- Sélection Defender / Production / Reboot via sous-menus
- Génération JSON local + upload FTP vers `/inbox/`

#### Améliorations à apporter
- Refonte UI : couleurs, ASCII art header YOUTELL, rafraîchissement automatique du menu
- Téléchargements curl isolés dans une fenêtre séparée (ne pas flooder la console principale)
- Correction bug : statut ne se rafraîchit pas après install/désinstall SCCM
- Détection automatique du FQDN complet de la machine (pour SCOM)

#### Contraintes
- 1 seul script PowerShell sur la VM
- Utilisation exclusive de `curl` pour les transferts réseau
- Aucun fichier de config embarqué — tout téléchargé dynamiquement depuis FTP
- Les VMs sont dans des VLANs isolés — elles ne peuvent pas atteindre SCCM/SCOM directement

---

### 4.2 Module SCCM — Script Admin

**Exécuté sur :** ZEBUREAU-ADMIN (192.168.10.16)
**Cible :** ZEBUREAU-SCCM01 (192.168.10.15) via module PowerShell ConfigurationManager

#### Mapping JSON → Collections

| Clé JSON | Collection SCCM | Comportement |
|---|---|---|
| `Defender = Active` | `PRD_Windows-Defender_Active` | Ajout permanent |
| `Defender = Active_Cloud` | `PRD_Windows-Defender_Active_Cloud` | Ajout permanent |
| `Production = SERVER` | `PRD_APPS_SERVER` | **One Shot** — retrait auto après ~48h |
| `Production = RDS_ALL` | `PRD_APPS_RDS_FULL_INSTALL_ALL` | **One Shot** — retrait auto après ~48h |
| `Production = RDS_JHP` | `PRD_APPS_RDS_FULL_INSTALL_JHP` | **One Shot** — retrait auto après ~48h |
| `Production = RDS_STARCO` | `PRD_APPS_RDS_FULL_INSTALL_STARCO` | **One Shot** — retrait auto après ~48h |
| `Production = RDS_NOAPPS` | `PRD_APPS_RDS_FULL_INSTALL_NOAPPS` | **One Shot** — retrait auto après ~48h |
| `Production = RDS_WITHOUT_OFFICE` | `PRD_APPS_RDS_FULL_INSTALL_WITHOUT_OFFICE` | **One Shot** — retrait auto après ~48h |
| `Reboot = (valeur)` | Collection Reboot correspondante | Ajout permanent |
| `NONE` | — | Aucun ajout |

#### Collections SCCM existantes (non gérées par ce projet)
- `Production_Windows_Update`
- `Production_Windows_Defender`
- `Production_Apps`
- `Clean`
- `Production_Logoff_Users`
- `En test` : Production_Office_xxx, Production_Nakivo, Production_Microsoft_Edge, Production_Metering

#### Règle Reboot
- `MONTH` : réservé aux AD (redémarrage mensuel des contrôleurs de domaine) — **non géré ici**
- `ONCE` : ignoré
- `DAILY` / `WEEKLY` / `PERIODICALLY` : gérés via les JSON

---

### 4.3 Module SCOM — Certificats & Agent

**Génération certificat sur :** ZEBUREAU-SCOM (192.168.10.12)
**OpenSSL installé uniquement sur ZEBUREAU-SCOM**
**Dossier de travail :** `C:\SCOM_AGENT\Certificate_Agent_Worksgroup`

#### Processus de génération (actuel)

```bat
# _Install_Complet.bat — édité manuellement avec le FQDN
create_certificate.bat DIAMLOISIR-RD01.DIAMLOISIR.LOCAL

# create_certificate.bat :
# 1. Génération cert auto-signé via OpenSSL (CN = FQDN, RSA 2048, 5825 jours)
# 2. Export .pfx (password : Password01.)
# 3. Import dans store Windows (CERTUTIL)
# 4. Re-export sans chaîne → <HOSTNAME>.pfx final
# 5. Suppression fichiers intermédiaires (.crt, .key)
```

Fichiers produits :
- `<HOSTNAME>_Save.pfx` — sauvegarde complète
- `<HOSTNAME>.pfx` — certificat final sans chaîne (celui déployé sur la VM)

#### Copie vers FTP (actuelle — manuelle)
```
\\zebu-ftp\ftp$\scom\<HOSTNAME>.pfx
```
⚠️ Si la VM est dans un domaine, renommer le fichier avec uniquement le `%COMPUTERNAME%` (sans le suffixe domaine).

#### Processus d'installation agent (VM)

`_Copy_install_scom.bat` télécharge depuis FTP :
- `MOMAgent.msi` + fichiers .mst multilingues
- `MOMCertImport.exe`
- `ZEBUREAU-SCOM.zeburo-youtell.local.pfx` (cert du serveur SCOM)
- `%COMPUTERNAME%.pfx` (cert de la VM)
- `Agent_SCOM.bat` + `_Install.bat`

`Agent_SCOM.bat` :
1. Import des deux certificats (VM + SCOM) dans le store Windows
2. Installation silencieuse `MOMAgent.msi` (groupe `SCOMZebureau`, serveur `ZEBUREAU-SCOM.zeburo-youtell.local`, port 5723)
3. `MOMCertImport.exe` enregistre le certificat auprès de l'agent
4. Ajout entrée hosts : `165.169.246.58 ZEBUREAU-SCOM.zeburo-youtell.local`
5. Redémarrage `HealthService`

#### Approbation SCOM (actuelle — manuelle)
Console SCOM → Administration → Administration en attente → F5 → Clic droit → Approuver

#### Automatisation cible
- Script Admin appelle ZEBUREAU-SCOM à distance pour générer le certificat
- Copie automatique du .pfx vers FTP avec renommage si nécessaire
- Approbation automatique ou notification guidée dans Teams

---

### 4.4 Module Power Automate

#### Flow SCCM
- **Déclencheur :** nouveau fichier dans le dossier SCCM OneDrive (`SUPERVISION - Général\SCCM`)
- **Action 1 :** lecture et parsing du JSON
- **Action 2 :** notification Teams canal Général
- **Action 3 :** déclenchement script PowerShell Admin sur ZEBUREAU-ADMIN
- **Action 4 :** archivage du JSON traité

#### Flow SCOM
- **Déclencheur :** nouveau fichier dans le dossier SCOM OneDrive (`SUPERVISION - Général\SCOM`)
- Actions similaires orientées SCOM

#### Format notification Teams
```
🖥️ Nouvelle VM à configurer :
   Hostname   : VM-01
   Defender   : Active
   Production : RDS_ALL
   Reboot     : REBOOT_HEBDO_FRIDAY_18h00
```

---

## 5. Format JSON

### JSON émis par la VM
```json
{
  "Hostname": "VM-01",
  "Defender": "Active",
  "Production": "RDS_ALL",
  "Reboot": "REBOOT_HEBDO_FRIDAY_18h00"
}
```

### Valeurs possibles

| Champ | Valeurs | NONE |
|---|---|---|
| `Defender` | `Active` \| `Active_Cloud` | Pas d'ajout collection Defender |
| `Production` | `SERVER` \| `RDS_ALL` \| `RDS_JHP` \| `RDS_STARCO` \| `RDS_NOAPPS` \| `RDS_WITHOUT_OFFICE` | Pas d'ajout collection Production |
| `Reboot` | Toute valeur des groupes DAILY / WEEKLY / PERIODICALLY | Pas d'ajout collection Reboot |

---

## 6. Contraintes & règles

- 1 seul script PowerShell côté VM
- `curl` exclusif pour tous les transferts réseau depuis les VMs
- OpenSSL disponible uniquement sur ZEBUREAU-SCOM
- Les VMs sont dans des VLANs isolés — elles ne peuvent pas atteindre SCCM/SCOM directement
- ZEBUREAU-ADMIN orchestre tout : même réseau que SCCM/SCOM (192.168.10.x)
- Credentials FTP maintenus en clair pour l'instant
- Collection `_Mise_en_Production` : One Shot — retrait auto après ~48h
- Collections `MONTH` : réservées à l'AD, non gérées par ce projet

---

## 7. Problèmes identifiés & solutions

| Problème | Solution retenue |
|---|---|
| Installation SCCM floode la console | Lancement dans nouvelle fenêtre PowerShell (`Start-Process`) |
| Statut SCCM ne se rafraîchit pas après install | Rafraîchissement dynamique du menu sans fermer la console |
| Génération certificat SCOM entièrement manuelle | Automatiser via script appelé à distance sur ZEBUREAU-SCOM |
| Copie .pfx vers FTP manuelle avec renommage | Automatiser dans le script Admin post-génération |
| Aucun workflow Power Automate n'existe | Créer les flows depuis zéro (SCCM + SCOM) |
| Approbation SCOM agent manuelle | Automatiser ou créer notification guidée dans Teams |
| `_Install_Complet.bat` édité manuellement à chaque VM | Passer le FQDN en paramètre dynamique depuis le script Admin |

---

## 8. Vision finale

Une plateforme d'orchestration complète permettant de déployer, configurer, superviser et maintenir les machines automatiquement, sans action manuelle répétitive.

- **Côté VM :** outil simple, menu clair, zéro erreur utilisateur
- **Côté Admin :** traitement automatique à réception du JSON, aucune intervention manuelle
- **Côté entreprise :** plateforme scalable, maintenable, modifiable uniquement via les fichiers JSON centralisés sur le FTP