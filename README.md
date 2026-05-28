#  SupportBox CMIL - Menu Interactif de Pré-Diagnostic

`SupportBox-CMIL` est un script PowerShell léger et interactif conçu pour les techniciens de support et les administrateurs système. Il permet de réaliser un **pré-diagnostic complet et instantané** d'un poste de travail Windows en cas de dysfonctionnement général (panne réseau, lenteurs, stockage saturé, etc.).

L'outil offre une interface console intuitive et génère des livrables exploitables pour accélérer la résolution des incidents (Rapports Bureau, Tickets de support pré-rédigés).

---

##  Fonctionnalités Clés

Le script est découpé en modules de tests automatisés et sécurisés contre les plantages :

* ** Infos Système Avancées :** Remonte instantanément l'identité du poste, la version précise de l'OS (ex: *Windows 11 Pro 23H2*), le modèle, le processeur, la quantité totale de RAM cumulée et la version/S-N du BIOS.
* ** Diagnostic Réseau Intelligent :** Filtre les cartes virtuelles pour cibler la carte physique active, affiche les configurations IP, et isole graphiquement les déconnexions de câbles ou de Wi-Fi.
* ** Test Connectivité & Proxy :** Analyse la communication avec la passerelle locale, teste la résolution DNS et simule un flux Web (HTTP/HTTPS) compatible avec les environnements restrictifs (Proxy Lycée/Entreprise).
* ** Contrôle de l'Espace Disque :** Calcule les pourcentages d'espace libre/occupé sur le lecteur `C:` et déclenche des alertes visuelles de couleur selon la criticité (seuils d'alerte à 15% et 5%).
* ** Périphériques & Partages :** Liste les imprimantes (en repérant celle par défaut) ainsi que les lecteurs réseau mappés, tout en vérifiant en arrière-plan si le serveur de fichiers distant répond.
* ** Génération de Rapports Automatisation :** * **Option 7 :** Crée un rapport de diagnostic complet au format `.txt` directement sur le Bureau de l'utilisateur avec un nom de fichier horodaté dynamique.
* **Option 8 :** Génère un résumé compact "Prêt à l'envoi" et l'injecte proprement dans le presse-papiers Windows (sans bug d'accents) pour un copier-coller (`CTRL+V`) direct dans ton outil de ticketing (GLPI, Jira, etc.).

---

##  Aperçu du Menu

```text
=== MENU DE MAINTENANCE ===
1. Afficher les infos système
2. Diagnostic réseau 
3. Tester internet / DNS
4. Vérifier l'espace disque (C:)
5. Imprimantes
6. Lecteurs réseau
7. Générer un rapport complet
8. Générer un résumé pour ticket support
9. Quitter le script
===========================
Entrez votre choix (1-9):
````

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#  SupportBox CMIL - Interactive Pre-Diagnostic Menu

`SupportBox-CMIL` is a lightweight, interactive PowerShell script designed for helpdesk technicians and system administrators. It delivers an **instant, comprehensive pre-diagnostic report** for Windows workstations experiencing general troubleshooting issues (network outages, sluggish performance, low storage, etc.).

Featuring an intuitive console interface, the tool generates actionable deliverables to speed up incident resolution (Desktop reports, pre-formatted support tickets).

---

##  Key Features

The script is divided into automated testing modules, built to be stable and crash-resistant:

* ** Advanced System Information:** Instantly retrieves the machine's identity, precise OS version (e.g., *Windows 11 Pro 23H2*), model, processor name, total cumulative RAM, and BIOS version/Serial Number.
* ** Smart Network Diagnostics:** Filters out virtual adapters to isolate the active physical network card, displays IP configurations, and visually flags disconnected Ethernet cables or Wi-Fi drops.
* ** Connectivity & Proxy Testing:** Pings the local gateway, tests DNS resolution, and simulates a Web (HTTP/HTTPS) request compatible with restrictive environments (School/Corporate Proxies).
* ** Storage Capacity Monitoring:** Calculates the exact free and used space percentages on the `C:` drive, triggering color-coded visual alerts based on remaining capacity (warning thresholds at 15% and 5%).
* ** Peripherals & Network Shares:** Lists local and network printers (highlighting the default printer) as well as mapped network drives, while verifying in the background if the remote file server is reachable.
* ** Automated Reporting:**
* **Option 7:** Generates a full diagnostic report as a `.txt` file dropped straight onto the user's Desktop with a dynamic, timestamped filename.
* **Option 8:** Generates a compact, "ready-to-send" summary and copies it directly into the Windows clipboard (handling encoding smoothly) for an instant paste (`CTRL+V`) into your ticketing system (GLPI, Jira, ServiceNow, etc.).

---

##  Menu Preview

```text
=== MENU DE MAINTENANCE ===
1. Afficher les infos système
2. Diagnostic réseau 
3. Tester internet / DNS
4. Vérifier l'espace disque (C:)
5. Imprimantes
6. Lecteurs réseau
7. Générer un rapport complet
8. Générer un résumé pour ticket support
9. Quitter le script
===========================
Entrez votre choix (1-9):
```
