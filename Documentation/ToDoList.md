# ✅ TODO LIST — Plateforme Automation YOUTELL
**Dernière mise à jour : Juin 2025**

> Légende statuts : `⬜ À FAIRE` | `🔄 EN COURS` | `🔴 BLOQUÉ` | `✅ FAIT`
> Légende priorités : `🔴 HAUTE` | `🟠 MOYENNE` | `🟡 BASSE`

---

## 🖥️ Module VM — `Supervision_Config.ps1`

| ID | Priorité | Statut | Tâche | Notes |
|---|---|---|---|---|
| VM-01 | 🔴 HAUTE | ✅ FAIT | Refonte UI : couleurs par statut, ASCII art header YOUTELL, rafraîchissement auto du menu | |
| VM-02 | 🔴 HAUTE | ✅ FAIT | Isoler les téléchargements curl dans une fenêtre séparée pour ne pas flooder la console | |
| VM-03 | 🔴 HAUTE | ✅ FAIT | Corriger le bug : statut SCCM ne se rafraîchit pas après install/désinstall | Rafraichissement toutes les 3s |
| VM-04 | 🔴 HAUTE | ✅ FAIT | Envoi configuration par mail SMTP2Go vers supervision@youtest.re | FTP abandonne au profit du mail |
| VM-05 | 🟠 MOYENNE | ⬜ À FAIRE | Détection automatique du FQDN complet de la machine (pour SCOM) | Actuellement saisi manuellement dans `_Install_Complet.bat` |
| VM-06 | 🟠 MOYENNE | ⬜ À FAIRE | Ajouter option : reconfigurer SCCM sans réinstaller (relancer `Start-SCCM-Config`) | |
| VM-07 | 🟡 BASSE | ✅ FAIT | Afficher IP et domaine/workgroup dans le header du menu | |


---

## 🔵 Module SCCM — Script Admin

| ID | Priorité | Statut | Tâche | Notes |
|---|---|---|---|---|
| SCCM-01 | 🔴 HAUTE | ✅ FAIT | Créer script PowerShell Admin : lecture JSON inbox + ajout machine dans collections SCCM |  SCCM_Admin.ps1 sur ZEBUREAU-ADMIN |
| SCCM-02 | 🔴 HAUTE | ✅ FAIT | Implémenter mapping JSON → collections : Defender, Production, Reboot | Basé sur les 3 fichiers JSON de config FTP |
| SCCM-03 | 🔴 HAUTE | ✅ FAIT | Retrait automatique de `_Mise_en_Production` après ~48h (One Shot) | (tache planifiee) |
| SCCM-04 | 🟠 MOYENNE | ⬜ À FAIRE | Export/rapport des machines par collection pour cartographier la répartition actuelle | Via `Get-CMDeviceCollectionDirectMember` ou rapport SCCM |
| SCCM-05 | 🟡 BASSE | ✅ FAIT | Archiver le JSON après traitement (déplacer vers sous-dossier `/inbox/processed/`) | Deja prevu dans SCCM_Admin.ps1 |


---

## 🟣 Module SCOM — Certificats & Agent

| ID | Priorité | Statut | Tâche | Notes |
|---|---|---|---|---|
| SCOM-01 | 🔴 HAUTE | ⬜ À FAIRE | Automatiser la génération de certificat sur ZEBUREAU-SCOM (remplace `_Install_Complet.bat` manuel) | OpenSSL uniquement sur ZEBUREAU-SCOM (192.168.10.12) |
| SCOM-02 | 🔴 HAUTE | ⬜ À FAIRE | Automatiser la copie du `.pfx` vers `\\zebu-ftp\ftp$\scom` avec renommage si la VM est dans un domaine | Actuellement copie manuelle |
| SCOM-03 | 🔴 HAUTE | ⬜ A FAIRE | Creer script Admin SCOM sur ZEBUREAU-ADMIN | |
| SCOM-04 | 🔴 HAUTE | ⬜ À FAIRE | Automatiser ou guider l'approbation SCOM (Administration > En attente > Approuver) | Notification Teams ou approbation script |
| SCOM-05 | 🔴 HAUTE | ⬜ A FAIRE | Ajouter envoi mail SCOM depuis Supervision_Config.ps1 | Meme mecanisme que SCCM |
| SCOM-06 | 🟠 MOYENNE | ⬜ À FAIRE | Tester la chaîne complète : génération cert → FTP → VM install → approbation SCOM | |

---

## ⚙️ Module Power Automate

| ID | Priorité | Statut | Tâche | Notes |
|---|---|---|---|---|
| PA-01 | 🔴 HAUTE | ✅ FAIT | Flow SCCM : declencheur nouveau mail sur supervision@youtest.re | Remplace le declencheur OneDrive |
| PA-02 | 🔴 HAUTE | ✅ FAIT | Action : lecture et parsing du JSON reçu | |
| PA-03 | 🔴 HAUTE | ✅ FAIT | Action : notification Teams canal Général (Hostname, Defender, Production, Reboot) | |
| PA-04 | 🔴 HAUTE | ✅ FAIT | Action : copie JSON vers dossier SCCM SharePoint | |
| PA-05 | 🔴 HAUTE | ✅ FAIT | Action : declenchement script Admin via tache planifiee Windows (toutes les 5 min) | Power Automate Desktop abandonne - licence Premium requise |
| PA-06 | 🟠 MOYENNE | ⬜ À FAIRE | Créer flow similaire pour SCOM (dossier SCOM OneDrive) | |
| PA-07 | 🟡 BASSE | ⬜ À FAIRE | Archiver le JSON après traitement dans un sous-dossier "Traités" | |

---

## 🏗️ Infrastructure / FTP

| ID | Priorité | Statut | Tâche | Notes |
|---|---|---|---|---|
| FTP-01 | 🔴 HAUTE | ✅ FAIT | Validation envoi JSON par mail SMTP2Go | Fonctionne |
| FTP-02 | 🔴 HAUTE | ✅ FAIT | Flow Power Automate operationnel bout en bout (SCCM) | |
| FTP-03 | 🟡 BASSE | ⬜ À FAIRE | Sécuriser les credentials FTP (sortir du clair — SecureString ou vault) | Hors priorité immédiate |

---

## 📊 Résumé

| Module | Total | ✅ Fait | 🔄 En cours | ⬜ À faire |
|---|---|---|---|---|
| VM Script | 7 | 4 | 0 | 3 |
| SCCM Admin | 5 | 3 | 0 | 2 |
| SCOM | 6 | 0 | 0 | 6 |
| Power Automate | 7 | 5 | 0 | 2 |
| Infrastructure | 3 | 2 | 0 | 1 |
| **TOTAL** | **28** | **14** | **0** | **14** |


