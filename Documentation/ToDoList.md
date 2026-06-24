# ✅ TODO LIST — Plateforme Automation YOUTELL
**Dernière mise à jour : Juin 2025**

> Légende statuts : `⬜ À FAIRE` | `🔄 EN COURS` | `🔴 BLOQUÉ` | `✅ FAIT`
> Légende priorités : `🔴 HAUTE` | `🟠 MOYENNE` | `🟡 BASSE`

---

## 🖥️ Module VM — `Supervision_Config.ps1`

| ID | Priorité | Statut | Tâche | Notes |
|---|---|---|---|---|
| VM-01 | 🔴 HAUTE | ⬜ À FAIRE | Refonte UI : couleurs par statut, ASCII art header YOUTELL, rafraîchissement auto du menu | |
| VM-02 | 🔴 HAUTE | ⬜ À FAIRE | Isoler les téléchargements curl dans une fenêtre séparée pour ne pas flooder la console | |
| VM-03 | 🔴 HAUTE | ⬜ À FAIRE | Corriger le bug : statut SCCM ne se rafraîchit pas après install/désinstall | Reste en "Installé" ou "En cours" sans mise à jour |
| VM-04 | 🔴 HAUTE | 🔄 EN COURS | Finaliser et tester `Send-Data` — upload JSON vers `/inbox/` FTP | Génération JSON locale OK, envoi FTP à valider |
| VM-05 | 🟠 MOYENNE | ⬜ À FAIRE | Détection automatique du FQDN complet de la machine (pour SCOM) | Actuellement saisi manuellement dans `_Install_Complet.bat` |
| VM-06 | 🟠 MOYENNE | ⬜ À FAIRE | Ajouter option : reconfigurer SCCM sans réinstaller (relancer `Start-SCCM-Config`) | |
| VM-07 | 🟡 BASSE | ⬜ À FAIRE | Afficher IP et domaine/workgroup dans le header du menu | |

---

## 🔵 Module SCCM — Script Admin

| ID | Priorité | Statut | Tâche | Notes |
|---|---|---|---|---|
| SCCM-01 | 🔴 HAUTE | ⬜ À FAIRE | Créer script PowerShell Admin : lecture JSON inbox + ajout machine dans collections SCCM | Module ConfigurationManager OK sur ZEBUREAU-ADMIN |
| SCCM-02 | 🔴 HAUTE | ⬜ À FAIRE | Implémenter mapping JSON → collections : Defender, Production, Reboot | Basé sur les 3 fichiers JSON de config FTP |
| SCCM-03 | 🔴 HAUTE | ⬜ À FAIRE | Retrait automatique de `_Mise_en_Production` après ~48h (One Shot) | Délai à confirmer : 24h ou 48h ? |
| SCCM-04 | 🟠 MOYENNE | ⬜ À FAIRE | Export/rapport des machines par collection pour cartographier la répartition actuelle | Via `Get-CMDeviceCollectionDirectMember` ou rapport SCCM |
| SCCM-05 | 🟡 BASSE | ⬜ À FAIRE | Archiver le JSON après traitement (déplacer vers sous-dossier `/inbox/processed/`) | |

---

## 🟣 Module SCOM — Certificats & Agent

| ID | Priorité | Statut | Tâche | Notes |
|---|---|---|---|---|
| SCOM-01 | 🔴 HAUTE | ⬜ À FAIRE | Automatiser la génération de certificat sur ZEBUREAU-SCOM (remplace `_Install_Complet.bat` manuel) | OpenSSL uniquement sur ZEBUREAU-SCOM (192.168.10.12) |
| SCOM-02 | 🔴 HAUTE | ⬜ À FAIRE | Automatiser la copie du `.pfx` vers `\\zebu-ftp\ftp$\scom` avec renommage si la VM est dans un domaine | Actuellement copie manuelle |
| SCOM-03 | 🔴 HAUTE | ⬜ À FAIRE | Automatiser ou guider l'approbation SCOM (Administration > En attente > Approuver) | Notification Teams ou approbation script |
| SCOM-04 | 🟠 MOYENNE | ⬜ À FAIRE | Tester la chaîne complète : génération cert → FTP → VM install → approbation SCOM | |

---

## ⚙️ Module Power Automate

| ID | Priorité | Statut | Tâche | Notes |
|---|---|---|---|---|
| PA-01 | 🔴 HAUTE | ⬜ À FAIRE | Créer le flow SCCM : déclencheur nouveau fichier dans dossier SCCM OneDrive | Chemin : `SUPERVISION - Général\SCCM` |
| PA-02 | 🔴 HAUTE | ⬜ À FAIRE | Action : lecture et parsing du JSON reçu | |
| PA-03 | 🔴 HAUTE | ⬜ À FAIRE | Action : notification Teams canal Général (Hostname, Defender, Production, Reboot) | |
| PA-04 | 🔴 HAUTE | ⬜ À FAIRE | Action : déclencher le script PowerShell Admin sur ZEBUREAU-ADMIN | Mécanisme à définir : tâche planifiée, WinRM, autre |
| PA-05 | 🟠 MOYENNE | ⬜ À FAIRE | Créer flow similaire pour SCOM (dossier SCOM OneDrive) | |
| PA-06 | 🟡 BASSE | ⬜ À FAIRE | Archiver le JSON après traitement dans un sous-dossier "Traités" | |

---

## 🏗️ Infrastructure / FTP

| ID | Priorité | Statut | Tâche | Notes |
|---|---|---|---|---|
| FTP-01 | 🔴 HAUTE | 🔄 EN COURS | Valider l'upload JSON vers `/inbox/` depuis la VM en conditions réelles | `Build-JSON` OK, `Send-Data` à tester |
| FTP-02 | 🟠 MOYENNE | ⬜ À FAIRE | Clarifier et documenter la mécanique de sync FTP → OneDrive sur ZEBUREAU-ADMIN | ZEBU-FTP (192.168.10.7) → OneDrive → Power Automate |
| FTP-03 | 🟡 BASSE | ⬜ À FAIRE | Sécuriser les credentials FTP (sortir du clair — SecureString ou vault) | Hors priorité immédiate |

---

## 📊 Résumé

| Module | Total | ✅ Fait | 🔄 En cours | ⬜ À faire |
|---|---|---|---|---|
| VM Script | 7 | 0 | 1 | 6 |
| SCCM Admin | 5 | 0 | 0 | 5 |
| SCOM | 4 | 0 | 0 | 4 |
| Power Automate | 6 | 0 | 0 | 6 |
| Infrastructure | 3 | 0 | 1 | 2 |
| **TOTAL** | **25** | **0** | **2** | **23** |