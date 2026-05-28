# ==============================================================================
# NOM DU SCRIPT : MenuInteractif.ps1
# DESCRIPTION   : Outil de diagnostic système, réseau et stockage pour techniciens.
# ==============================================================================

# Force l'affichage correct des caractères accentués (é, à, è) dans la console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ------------------------------------------------------------------------------
# 1. DÉFINITION DES FONCTIONS (Boîte à outils du script)
# ------------------------------------------------------------------------------

function Get-InfoSystem {
    <#
    .SYNOPSIS
        Affiche les informations de base de la machine.
    #>

    Clear-Host
    Write-Host "=== SUPPORTBOX CMIL ===" -ForegroundColor Cyan
    # Informations de session et d'identification
    Write-Host "Nom de l'ordinateur   : $env:COMPUTERNAME"
    Write-Host "Nom de l'utilisateur  : $env:USERNAME"
    Write-Host "Domaine               : $((Get-CimInstance Win32_ComputerSystem).Domain)"
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray

    # Informations Système & Matériel (Constructeur)
    $OS = Get-CimInstance Win32_OperatingSystem
    $VersionPrecise = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
        
    Write-Host "Version de l'OS       : $($OS.Caption) (Version $VersionPrecise)"
    Write-Host "Fabricant             : $((Get-CimInstance Win32_ComputerSystem).Manufacturer)"
    Write-Host "Modèle                : $((Get-CimInstance Win32_ComputerSystem).Model)"
    # Récupère la version et le numéro de série (souvent le Tag Service/Asset du constructeur)
    Write-Host "Version du BIOS       : $((Get-CimInstance Win32_Bios).SMBIOSBIOSVersion) (S/N: $((Get-CimInstance Win32_Bios).SerialNumber))"
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray

    # Informations Composants (CPU, RAM, Architecture)
    Write-Host "Processeur            : $((Get-CimInstance Win32_Processor).Name)"
    Write-Host "Architecture          : $env:PROCESSOR_ARCHITECTURE"
    
    # Récupère la capacité de chaque barrette de RAM, les additionne (Measure-Object) et convertit les octets en Go
    $TotalRAM = [Math]::Round(((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB), 0)
    Write-Host "Mémoire RAM Totale    : $TotalRAM Go"
    Write-Host "----------------------------"
}

function Get-InfoReseau {
    <#
    .SYNOPSIS
        Affiche la configuration et l'état de connexion réel des cartes physiques.
        Filtre intelligemment pour cibler la connexion principale active.
    #>
    Clear-Host
    Write-Host "=== CONFIGURATION ET ÉTAT RÉSEAU ===" -ForegroundColor Cyan

    # Identifie la carte actuellement connectée (Protocole IP actif + Passerelle existante)
    $CarteActive = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true -and $_.DefaultIPGateway -ne $null }
    
    $UneIpAeteTrouvee = $false

    # Filtre pour lister uniquement les vraies cartes physiques (exclut le virtuel et le Bluetooth débranché)
    Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true } | ForEach-Object {
        
        # Associe la configuration IP (adresse, masque) à la carte physique via son numéro d'Index unique
        $ConfigIP = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "Index=$($_.Index)"

        # Statut '2' = Carte branchée/connectée. Évite d'afficher les cartes inactives à l'écran.
        if ($_.NetConnectionStatus -eq 2 -or ($CarteActive -and $CarteActive.Index -eq $_.Index)) {
            
            Write-Host "  | Carte                  : $($_.Name)" -ForegroundColor White
            # Le paramètre -join ' / ' rassemble proprement les adresses (ex: IPv4 et IPv6) sur la même ligne
            Write-Host "  | Adresse(s) IP          : $(if($ConfigIP.IPAddress){$ConfigIP.IPAddress -join ' / '}else{'Pas d''IP'})"
            Write-Host "  | Masque de sous-réseau : $(if($ConfigIP.IPSubnet){$ConfigIP.IPSubnet -join ' / '}else{'Pas de masque'})"
            Write-Host "  | Passerelle (GW)       : $(if($ConfigIP.DefaultIPGateway){$ConfigIP.DefaultIPGateway -join ' / '}else{'Aucune'})"
            Write-Host "  | Serveur(s) DNS        : $(if($ConfigIP.DNSServerSearchOrder){$ConfigIP.DNSServerSearchOrder -join ' / '}else{'Aucun'})"
            
            if ($ConfigIP.IPAddress) {
                $UneIpAeteTrouvee = $true
            }

            Write-Host "  | État de connexion     : CONNECTÉ" -ForegroundColor Green
            Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
        }
    }

    # Logique décisionnelle : analyse si le PC est coupé du réseau local
    Write-Host "CONCLUSION ÉCRAN :" -ForegroundColor Cyan
    if ($UneIpAeteTrouvee) {
        Write-Host "  Configuration IP valide et active détectée." -ForegroundColor Green
    } else {
        Write-Host "  Pas d'adresse IP" -ForegroundColor Red -BackgroundColor Black
        Write-Host "  Aucune adresse IP valide ou passerelle absente." -ForegroundColor Red
        Write-Host "  Conclusion : Problème DHCP, câble, Wi-Fi ou carte réseau." -ForegroundColor Yellow
        Write-Host "  Action     : Comparer la configuration avec un poste fonctionnel." -ForegroundColor Yellow
    }
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
}


function Get-InfoInternet {
    <#
    .SYNOPSIS
        Diagnostic précis compatible Proxy Lycée / Partage de connexion.
    #>
    Clear-Host
    Write-Host "=== TESTS CONNECTIVITÉ INTERNET ===" -ForegroundColor Cyan

    $ConfigReseauActive = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    # Sécurité : Récupère la première passerelle [0] si elle existe, sinon attribue une valeur nulle ($null)
    $GW = if ($ConfigReseauActive.DefaultIPGateway) { $ConfigReseauActive.DefaultIPGateway[0] } else { $null }
    $PasserelleOK = $false

    if ($GW) {
        # Ping la passerelle locale (box/routeur) une seule fois (-Count 1) de manière invisible (-Quiet)
        if (Test-Connection $GW -Count 1 -Quiet) {
            Write-Host "| Passerelle locale ($GW) : OK" -ForegroundColor Green
            $PasserelleOK = $true
        } else {
            Write-Host "| Passerelle locale ($GW) : ÉCHEC (Coupure locale)" -ForegroundColor Red
        }
    } else {
        Write-Host "| Passerelle locale          : INTROUVABLE" -ForegroundColor Red
    }

    # Sécurité anti-crash : Si la passerelle ne répond pas, on stoppe la fonction immédiatement (return)
    if (-not $PasserelleOK) {
        Write-Host "--> Diagnostic : Coupure physique ou Wi-Fi débranché." -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
        return
    }

    # Resolve-DnsName teste si les serveurs DNS arrivent à traduire un nom de domaine en adresse IP
    $TestDNS = Resolve-DnsName -Name "www.google.fr" -ErrorAction SilentlyContinue
    $DnsOK = if ($TestDNS) { $true } else { $false }

    # Invoke-WebRequest simule une requête de navigateur (HTTP/HTTPS) pour traverser d'éventuels serveurs proxy
    $TestWeb = Invoke-WebRequest -Uri "https://www.google.fr" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
    # Statut HTTP 200 = Page Web chargée avec succès
    $InternetOK = if ($TestWeb.StatusCode -eq 200) { $true } else { $false }

    Write-Host "| Résolution DNS (google.fr) : $(if ($DnsOK) {'OK'} else {'ÉCHEC'})"
    Write-Host "| Accès Internet (Flux Web)  : $(if ($InternetOK) {'OK'} else {'ÉCHEC'})"
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray

    # Analyse en cascade du type de panne internet
    if ($InternetOK) {
        Write-Host "CONCLUSION : Tout est fonctionnel. Internet et DNS OK." -ForegroundColor Green
    }
    else {
        if (-not $DnsOK) {
            Write-Host "CONCLUSION : PROBLÈME DNS PROBABLE !" -ForegroundColor Red
            Write-Host "ACTION     : Impossible de traduire 'google.fr'. Vérifiez les serveurs DNS de la carte réseau." -ForegroundColor Yellow
        } 
        else {
            # Cas typique : Le DNS résout l'IP mais le flux HTTP est bloqué (Proxy non authentifié ou pare-feu)
            Write-Host "CONCLUSION : Blocage réseau ou Proxy mal configuré." -ForegroundColor Yellow
            Write-Host "ACTION     : Le DNS fonctionne, mais le flux HTTP/HTTPS est bloqué (vérifiez les identifiants proxy)." -ForegroundColor Orange
        }
    }

    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
}


function Get-EspaceDisque {
    <#
    .SYNOPSIS
        Affiche l'espace libre sur le disque C:
    #>
    Clear-Host
    Write-Host "=== ESPACE DISQUE (C:) ===" -ForegroundColor Cyan
    $DisqueC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    
    # Division par 1GB et l'arrondi pour convertir les octets bruts en Giga-octets (Go)
    $TailleTotale = [Math]::Round($DisqueC.Size / 1GB, 2)
    $EspaceLibre  = [Math]::Round($DisqueC.FreeSpace / 1GB, 2)
    
    # Calcul mathématique des pourcentages d'occupation et d'espace restant
    $PourcentLibre   = [Math]::Round(($DisqueC.FreeSpace / $DisqueC.Size) * 100, 1)
    $PourcentOccupe  = [Math]::Round(100 - $PourcentLibre, 1)

    Write-Host "Taille totale : $TailleTotale Go"
    Write-Host "Espace libre  : $EspaceLibre Go ($PourcentLibre % libre)"
    Write-Host "Espace occupé : $([Math]::Round($TailleTotale - $EspaceLibre, 2)) Go ($PourcentOccupe % utilisé)" -ForegroundColor Gray
    
    # Calcul des seuils d'alerte critique (5% et 15%) pour l'entretien du stockage
    if (($EspaceLibre / $TailleTotale) -lt 0.05) {
        Write-Host "Moins de 5% d'espace libre, il faut nettoyer ou analyser l'occupation !" -ForegroundColor Red
    } elseif (($EspaceLibre / $TailleTotale) -lt 0.15) {
        Write-Host "Attention : Moins de 15% d'espace libre !" -ForegroundColor Yellow
    } else {
        Write-Host "Espace disque suffisant." -ForegroundColor Green
    }
    Write-Host "--------------------------"
}

function Get-InfoImprimantes {
    <#
    .SYNOPSIS
        Affiche les imprimantes en lecture seule directement sans variables.
    #>
    Clear-Host
    Write-Host "=== COLLECTE DES IMPRIMANTES ===" -ForegroundColor Cyan

    Get-CimInstance Win32_Printer | ForEach-Object {
        Write-Host "  | Nom                    : $($_.Name)" -ForegroundColor White
        # Utilise la propriété booléenne .Default pour repérer immédiatement l'imprimante active par défaut
        Write-Host "  | Imprimante par défaut : $(if($_.Default){'OUI'}else{'Non'})"
        Write-Host "  | Pilote utilisé        : $($_.DriverName)"
        Write-Host "  | Port de connexion     : $($_.PortName)"
        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
    }
}

function Get-InfoLecteursReseau {
    <#
    .SYNOPSIS
        Affiche la liste des lecteurs réseau mappés, leur chemin et leur état réel.
    #>
    Clear-Host 
    Write-Host "=== LECTEURS RÉSEAU MAPPÉS ===" -ForegroundColor Cyan

    # DriveType -eq 4 cible spécifiquement les partages réseau mappés (ex: disques Z:, X:, etc.)
    $ListeLecteurs = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 4 }

    if ($null -eq $ListeLecteurs) {
        Write-Host "Aucun lecteur réseau mappé sur ce poste." -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
        return
    }
    $ListeLecteurs | ForEach-Object {
        
        Write-Host "  | Lettre            : $($_.DeviceID)" -ForegroundColor White
        Write-Host "  | Chemin réseau     : $($_.ProviderName)"
        
        # Isole le nom ou l'IP du serveur distant en découpant les antislashs (ex: \\Serveur\Partage devient 'Serveur')
        $Serveur = if ($_.ProviderName) { $_.ProviderName.Split('\')[2] } else { $null }

        Write-Host "  | État du lecteur   : $(
            if ($Serveur -and (Test-Connection -ComputerName $Serveur -Count 1 -Quiet)) {
                Write-Output "ACCESSIBLE (Serveur en ligne)" -ForegroundColor Green
            } else {
                Write-Output "HORS LIGNE ou INACCESSIBLE" -ForegroundColor Red
            }
        )"
        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
    }
}


function Install-FichierConfig {
    # Génère un nom de fichier unique basé sur le nom de la machine et l'heure courante (Format: AAAAMMJJ-HHMM)
    $NomPC         = $env:COMPUTERNAME
    $DateFichier   = Get-Date -Format "yyyyMMdd-HHmm"
    # Construit le chemin d'accès absolu vers le Bureau de la session utilisateur actuelle
    $CheminFichier = "$env:USERPROFILE\Desktop\SupportBox-Rapport-$NomPC-$DateFichier.txt"

    # --- COLLECTE SILENCIEUSE DES DONNÉES EN ARRIÈRE-PLAN ---
    $ConfigReseauActive = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    $IP = if ($ConfigReseauActive.IPAddress) { $ConfigReseauActive.IPAddress[0] } else { $null }
    $GW = if ($ConfigReseauActive.DefaultIPGateway) { $ConfigReseauActive.DefaultIPGateway[0] } else { $null }
    
    $StatutGW = "ÉCHEC"
    if ($GW -and (Test-Connection $GW -Count 1 -Quiet)) { $StatutGW = "OK" }

    $StatutDNS = "ÉCHEC"
    $StatutWeb = "ÉCHEC"
    $ConclusionTxt = ""

    $DisqueC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $EspaceLibreGo = [Math]::Round(($DisqueC.FreeSpace / 1GB), 2)
    $EspaceTotalGo = [Math]::Round(($DisqueC.Size / 1GB, 2))
    $PourcentLibre = ($DisqueC.FreeSpace / $DisqueC.Size) * 100

    # --- ARBRE DÉCISIONNEL PRIORITAIRE POUR LE RAPPORT ---
    if (-not $IP -or -not $GW) {
        $ConclusionTxt = "PROBLÈME DHCP, CÂBLE, WI-FI OU CARTE RÉSEAU ! Aucune adresse IP valide ou passerelle absente. Action : comparer avec un poste fonctionnel."
    }
    elseif ($PourcentLibre -lt 5) {
        $ConclusionTxt = "CRITIQUE - ESPACE DISQUE INSUFFISANT ! Le lecteur C: a moins de 5% d'espace libre ($EspaceLibreGo Go restants). Action : Nettoyer le disque ou analyser l'occupation en urgence."
    }
    elseif ($PourcentLibre -lt 15) {
        $ConclusionTxt = "ATTENTION - ESPACE DISQUE FAIBLE ! Le lecteur C: a moins de 15% d'espace libre ($EspaceLibreGo Go restants). Conclusion : Espace insuffisant possible. Action : Nettoyer ou analyser l'occupation."
    }
    elseif ($StatutGW -eq "OK") {
        if (Resolve-DnsName -Name "www.google.fr" -ErrorAction SilentlyContinue) { $StatutDNS = "OK" }
        $TestWeb = Invoke-WebRequest -Uri "https://www.google.fr" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($TestWeb.StatusCode -eq 200) { $StatutWeb = "OK" }

        if ($StatutWeb -eq "OK") {
            $ConclusionTxt = "Tout est fonctionnel. Internet et DNS OK."
        } elseif ($StatutDNS -eq "ÉCHEC") {
            $ConclusionTxt = "PROBLÈME DNS PROBABLE ! Impossible de traduire les noms de domaine."
        } else {
            $ConclusionTxt = "Blocage réseau ou Proxy mal configuré (HTTP/HTTPS bloqué)."
        }
    } else {
        $ConclusionTxt = "Coupure physique locale (Pas d'accès à la passerelle, câble débranché ou Wi-Fi coupé)."
    }

    # --- LISTAGE ET MISE EN FORME DES IMPRIMANTES ---
    $ListeImprimantesTxt = ""
    $Printers = Get-CimInstance Win32_Printer
    if ($Printers) {
        foreach ($Printer in $Printers) {
            $Defaut = if ($Printer.Default) { "OUI" } else { "NON" }
            $ListeImprimantesTxt += "`r`n   [ Par Défaut: $Defaut ] Name: $($Printer.Name) | Driver: $($Printer.DriverName)"
        }
    } else {
        $ListeImprimantesTxt = " Aucun périphérique détecté."
    }

    # --- LISTAGE ET SÉCURISATION DES PARTAGES RÉSEAU ---
    $ListeLecteursTxt = ""
    $Lecteurs = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 4 }
    if ($Lecteurs) {
        foreach ($Lecteur in $Lecteurs) {
            $Serveur = if ($Lecteur.ProviderName) { $Lecteur.ProviderName.Split('\')[2] } else { $null }
            $EtatLecteur = "INACCESSIBLE"
            if ($Serveur) {
                if (Test-Connection -ComputerName $Serveur -Count 1 -Quiet) {
                    $EtatLecteur = "ACCESSIBLE"
                } else {
                    # Double test de sécurité sur le port SMB standard (445) si le ping ICMP de base est bloqué
                    $TestSMB = Test-NetConnection -ComputerName $Serveur -Port 445 -WarningAction SilentlyContinue
                    if ($TestSMB.TcpTestSucceeded) { $EtatLecteur = "ACCESSIBLE" }
                }
            }
            $ListeLecteursTxt += "`r`n   | $($Lecteur.DeviceID) -> $($Lecteur.ProviderName) [$EtatLecteur]"
        }
    } else {
        $ListeLecteursTxt = " Aucun lecteur réseau mappé."
    }

    # Construction du gabarit texte du rapport final (Here-String @" ... "@)
    $ContenuRapport = @"
======================================================================
                     RAPPORT DE DIAGNOSTIC PC
======================================================================
> date du diagnostic   : $(Get-Date -Format "dd/MM/yyyy HH:mm")
> nom du poste         : $env:COMPUTERNAME
> utilisateur          : $env:USERNAME

----------------------------------------------------------------------
INFORMATIONS SYSTEME
----------------------------------------------------------------------
> infos Windows        : $((Get-CimInstance Win32_OperatingSystem).Caption) ($env:PROCESSOR_ARCHITECTURE)
> espace disque C:     : $EspaceLibreGo Go libres sur $EspaceTotalGo Go ($([Math]::Round($PourcentLibre, 1))% libre)

----------------------------------------------------------------------
CONNECTIVITÉ & RESEAU
----------------------------------------------------------------------
> Adresse IP actuelle  : $(if($IP){$IP}else{"Pas d'IP"})
> Passerelle locale    : $(if($GW){$GW}else{"Aucune"}) ($StatutGW)
> Resolution DNS       : google.fr ($StatutDNS)
> Flux Web (Internet)  : $StatutWeb
----------------------------------------------------------------------
PERIPHERIQUES & PARTAGES
----------------------------------------------------------------------
> imprimantes          : $ListeImprimantesTxt
> lecteurs reseau      : $ListeLecteursTxt

----------------------------------------------------------------------
CONCLUSION DIAGNOSTIC
----------------------------------------------------------------------
> conclusion automatique : $ConclusionTxt
======================================================================
"@

    # Écriture physique du fichier texte sur le support de stockage (Bureau)
    try {
        $ContenuRapport | Out-File -FilePath $CheminFichier -Force -Encoding utf8 -ErrorAction Stop
        Clear-Host
        Write-Host "[OK] Rapport généré sur le Bureau : SupportBox-Rapport-$NomPC-$DateFichier.txt" -ForegroundColor Green
    }
    catch {
        Clear-Host
        Write-Host "[ERREUR] Impossible d'écrire le fichier sur le Bureau." -ForegroundColor Red
    }
}


function Get-TicketSupport {
    <#
    .SYNOPSIS
        Génère un résumé de diagnostic compact et le copie directement 
        dans le presse-papiers en forçant l'encodage correct des accents.
    #>
    Clear-Host
    Write-Host "=== GÉNÉRATION DU TICKET SUPPORT ===" -ForegroundColor Cyan

    # Charge la bibliothèque graphique .NET indispensable pour interagir avec le presse-papiers Windows
    Add-Type -AssemblyName System.Windows.Forms

    $ConfigReseauActive = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    $IP = if ($ConfigReseauActive.IPAddress) { $ConfigReseauActive.IPAddress[0] } else { $null }
    $GW = if ($ConfigReseauActive.DefaultIPGateway) { $ConfigReseauActive.DefaultIPGateway[0] } else { $null }
    
    $StatutGW = "ÉCHEC"
    if ($GW -and (Test-Connection $GW -Count 1 -Quiet)) { $StatutGW = "OK" }

    $StatutDNS = "ÉCHEC"
    $StatutWeb = "ÉCHEC"
    $ConclusionTicket = ""

    $ConstatIP = if ($IP) { "Le poste dispose d'une adresse IP valide." } else { "Le poste ne dispose d'aucune adresse IP valide." }
    $ConstatGW = if ($StatutGW -eq "OK") { "La passerelle répond." } else { "La passerelle ne répond pas ou est absente." }
    $ConstatWeb = "L'accès Internet par IP / Flux Web est non testé."
    $ConstatDNS = "La résolution DNS is non testée."

    $DisqueC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $PourcentLibre = ($DisqueC.FreeSpace / $DisqueC.Size) * 100

    if (-not $IP -or -not $GW) {
        $ConclusionTicket = "Problème DHCP, câble, Wi-Fi ou carte réseau."
    }
    elseif ($PourcentLibre -lt 5) {
        $ConclusionTicket = "Espace disque critique (Moins de 5% libre)."
    }
    elseif ($PourcentLibre -lt 15) {
        $ConclusionTicket = "Espace insuffisant possible (Moins de 15% libre)."
    }
    else {
        if ($StatutGW -eq "OK") {
            if (Resolve-DnsName -Name "www.google.fr" -ErrorAction SilentlyContinue) { $StatutDNS = "OK" }
            $TestWeb = Invoke-WebRequest -Uri "https://www.google.fr" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($TestWeb.StatusCode -eq 200) { $StatutWeb = "OK" }

            $ConstatDNS = if ($StatutDNS -eq "OK") { "La résolution DNS fonctionne." } else { "La résolution DNS échoue." }
            $ConstatWeb = if ($StatutWeb -eq "OK") { "L'accès Internet par IP fonctionne." } else { "L'accès Internet par IP / Flux Web échoue." }

            if ($StatutWeb -eq "OK") {
                $ConclusionTicket = "Aucun problème détecté. Tout est fonctionnel."
            } elseif ($StatutDNS -eq "ÉCHEC") {
                $ConclusionTicket = "Problème DNS ou configuration réseau partielle."
            } else {
                $ConclusionTicket = "Blocage réseau ou Proxy mal configuré."
            }
        } else {
            $ConclusionTicket = "Pas d'accès à la passerelle réseau locale."
        }
    }

    $TexteTicket = @"
Résumé diagnostic :

Poste : $env:COMPUTERNAME
Utilisateur : $env:USERNAME
Date : $(Get-Date -Format "yyyy-MM-dd HH:mm")

Constat :
$ConstatIP
$ConstatGW
$ConstatWeb
$ConstatDNS

Conclusion probable :
$ConclusionTicket
"@

    try {
        # Appelle la commande de l'API .NET Windows Forms pour coller la chaîne de caractères dans la mémoire vive
        [Windows.Forms.Clipboard]::SetText($TexteTicket)
        
        Write-Host "[OK] Le résumé du ticket a été copié dans votre presse-papiers !" -ForegroundColor Green
        Write-Host "     Ouvrez votre outil de support et faites simplement CTRL+V." -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "[ERREUR] Impossible d'accéder au presse-papiers de Windows." -ForegroundColor Red
    }
}


# ------------------------------------------------------------------------------
# 2. BOUCLE PRINCIPALE ET MENU
# ------------------------------------------------------------------------------

# Variable de contrôle servant de commutateur marche/arrêt pour maintenir le menu actif
$Continuer = $true

while ($Continuer) {
    
    Clear-Host
    Write-Host "`n=== MENU DE MAINTENANCE ===" -ForegroundColor Magenta
    Write-Host "1. Afficher les infos système"
    Write-Host "2. Diagnostic réseau "
    Write-Host "3. Tester internet / DNS"
    Write-Host "4. Vérifier l'espace disque (C:)"
    Write-Host "5. Imprimantes"
    Write-Host "6. Lecteurs réseau"
    Write-Host "7. Générer un rapport complet"
    Write-Host "8. Générer un résumé pour ticket support"
    Write-Host "9. Quitter le script"
    Write-Host "==========================="
    
    # Interrompt le script et attend que l'opérateur saisisse une valeur au clavier
    $Choix = Read-Host "Entrez votre choix (1-9)"
    
    # Structure d'aiguillage optimisée : route le choix utilisateur vers la bonne fonction
    switch ($Choix) {
        "1" { Get-InfoSystem }
        "2" { Get-InfoReseau }
        "3" { Get-InfoInternet }
        "4" { Get-EspaceDisque }
        "5" { Get-InfoImprimantes }
        "6" { Get-InfoLecteursReseau }
        "7" { Install-FichierConfig }
        "8" { Get-TicketSupport }
        "9" { 
            Write-Host "`nMerci d'avoir utilisé le script. Au revoir !" -ForegroundColor Magenta
            # Passe la variable à Faux pour casser la condition de la boucle While et clore le programme
            $Continuer = $false 
        }
        Default { 
            # Déclenché uniquement si la saisie ne correspond à aucun chiffre de 1 à 9
            Write-Host "Choix invalide, veuillez recommencer." -ForegroundColor Red 
        }
    }
    
    # Crée un temps d'arrêt pour figer le résultat à l'écran avant de recharger le menu principal
    if ($Continuer) {
        Read-Host "`nAppuyez sur Entrée pour revenir au menu..."
        Clear-Host
    }
}