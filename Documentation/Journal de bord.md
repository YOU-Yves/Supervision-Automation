# JOURNAL DE BORD - Plateforme Automation YOUTELL

> Une entree par session de travail. Toujours ajouter en haut (ordre antechronologique).

---

## Session 2 - Juin 2025

### Realise
- Refonte complete de Supervision_Config.ps1 :
  - UI : header YOUTELL, couleurs par statut, rafraichissement auto toutes les 3s
  - Correction bug statut SCCM non rafraichi apres install/desinstall
  - Telechargements curl isoles dans fenetre separee (plus de flood console)
  - Remplacement envoi FTP par envoi mail SMTP2Go (OneDrive sync trop instable)
  - Envoi JSON en piece jointe avec sujet [SCCM] <HOSTNAME>
- Creation SCCM_Admin.ps1 sur ZEBUREAU-ADMIN :
  - Mapping JSON -> collections SCCM (Defender, Production, Reboot)
  - Retrait automatique _Mise_en_Production apres 48h via tache planifiee
  - Archivage JSON traite avec horodatage
  - Log complet dans Logs/SCCM_Admin.log
- Flow Power Automate SCCM operationnel :
  - Declencheur : nouveau mail sur supervision@youtest.re
  - Parse JSON piece jointe
  - Notification Teams canal General
  - Copie JSON vers dossier SCCM SharePoint
  - Declenchement SCCM_Admin.ps1 via tache planifiee Windows toutes les 5 minutes (Power Automate Desktop abandonne - necessite licence Premium)

### Etat du projet
- 14/28 taches terminees (50%)
- Module VM et SCCM fonctionnels et valides en prod
- Module SCOM entierement a faire

### Prevu pour la prochaine session
- Module SCOM : automatisation generation certificat + script Admin + flow Power Automate

---

## Session 1 - Juin 2025

### Realise
- Analyse complete du projet et de l'existant
- Collecte de tous les scripts existants
- Creation du Cahier des Charges complet
- Creation de la TODO List
- Creation du Journal de bord

### Etat du projet
- 25 taches identifiees, 0 terminees, 2 en cours
- Aucun script Admin existant
- Aucun flow Power Automate existant

---

## Prompt de demarrage (a copier-coller en debut de session)

> Voici le contexte du projet YOUTELL Automation. Lis le cahier des charges, la todo list et le journal de bord disponibles dans les fichiers du projet, puis dis-moi ou on en est et ce qu'on peut attaquer. Je vais t'indiquer ce qui a avance depuis la derniere session.