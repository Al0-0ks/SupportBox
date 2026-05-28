# ==============================================================================
# SCRIPT NAME : MenuInteractif.ps1
# DESCRIPTION : System, network, and storage diagnostic tool for technicians.
# ==============================================================================

# Force the console to display accented characters properly if needed
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ------------------------------------------------------------------------------
# UTILITY FUNCTIONS
# ------------------------------------------------------------------------------

function Get-FirstIPv4 {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$AddressList
    )

    @($AddressList | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' } | Select-Object -First 1)[0]
}

function Get-ActiveNetworkConfig {
    $Configs = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }

    $ConfigWithGateway = $Configs | Where-Object {
        $_.DefaultIPGateway -and (Get-FirstIPv4 $_.IPAddress)
    } | Select-Object -First 1

    if ($ConfigWithGateway) {
        return $ConfigWithGateway
    }

    $Configs | Where-Object {
        Get-FirstIPv4 $_.IPAddress
    } | Select-Object -First 1
}


# ------------------------------------------------------------------------------
# 1. FUNCTION DEFINITIONS (Script Toolbox)
# ------------------------------------------------------------------------------

function Get-InfoSystem {
    <#
    .SYNOPSIS
        Displays basic machine information.
    #>

    Clear-Host
    Write-Host "=== SUPPORTBOX CMIL ===" -ForegroundColor Cyan
    # Session and identification information
    Write-Host "Computer Name         : $env:COMPUTERNAME"
    Write-Host "Username              : $env:USERNAME"
    Write-Host "Domain                : $((Get-CimInstance Win32_ComputerSystem).Domain)"
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray

    # System & Hardware Information (Manufacturer)
    $OS = Get-CimInstance Win32_OperatingSystem
    $PreciseVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
        
    Write-Host "OS Version            : $($OS.Caption) (Version $PreciseVersion)"
    Write-Host "Manufacturer          : $((Get-CimInstance Win32_ComputerSystem).Manufacturer)"
    Write-Host "Model                 : $((Get-CimInstance Win32_ComputerSystem).Model)"
    # Retrieves BIOS version and serial number (Service Tag / Asset Tag)
    Write-Host "BIOS Version          : $((Get-CimInstance Win32_Bios).SMBIOSBIOSVersion) (S/N: $((Get-CimInstance Win32_Bios).SerialNumber))"
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray

    # Component Information (CPU, RAM, Architecture)
    Write-Host "Processor             : $((Get-CimInstance Win32_Processor).Name)"
    Write-Host "Architecture          : $env:PROCESSOR_ARCHITECTURE"
    
    # Retrieves the capacity of each RAM stick, sums them up, and converts raw bytes to GB
    $TotalRAM = [Math]::Round(((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB), 0)
    Write-Host "Total RAM Memory      : $TotalRAM GB"
    Write-Host "----------------------------"
}

function Get-InfoReseau {
    <#
    .SYNOPSIS
        Displays configuration and connection status of physical adapters.
        Filters intelligently to target the main active connection.
    #>
    Clear-Host
    Write-Host "=== NETWORK CONFIGURATION & STATUS ===" -ForegroundColor Cyan

    # Identifies the currently connected card (Active IP protocol + existing gateway)
    $ActiveCard = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true -and $_.DefaultIPGateway -ne $null }
    
    $AnIpWasFound = $false

    # Filters to list only real physical adapters (excludes virtual cards and disconnected Bluetooth)
    Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true } | ForEach-Object {
        
        # Associates the IP configuration (address, mask) with the physical card using its unique Index
        $ConfigIP = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "Index=$($_.Index)"

        # Status '2' = Card plugged in / connected. Prevents displaying inactive cards.
        if ($_.NetConnectionStatus -eq 2 -or ($ActiveCard -and $ActiveCard.Index -eq $_.Index)) {
            
            Write-Host "  | Adapter                : $($_.Name)" -ForegroundColor White
            # Joins multiple addresses (e.g. IPv4 and IPv6) cleanly on the same line
            Write-Host "  | IP Address(es)         : $(if($ConfigIP.IPAddress){$ConfigIP.IPAddress -join ' / '}else{'No IP'})"
            Write-Host "  | Subnet Mask            : $(if($ConfigIP.IPSubnet){$ConfigIP.IPSubnet -join ' / '}else{'No Mask'})"
            Write-Host "  | Default Gateway (GW)   : $(if($ConfigIP.DefaultIPGateway){$ConfigIP.DefaultIPGateway -join ' / '}else{'None'})"
            Write-Host "  | DNS Server(s)          : $(if($ConfigIP.DNSServerSearchOrder){$ConfigIP.DNSServerSearchOrder -join ' / '}else{'None'})"
            
            if ($ConfigIP.IPAddress) {
                $AnIpWasFound = $true
            }

            Write-Host "  | Connection Status      : CONNECTED" -ForegroundColor Green
            Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
        }
    }

    # Decision Logic: checks if the PC is cut off from the local network
    Write-Host "SCREEN CONCLUSION:" -ForegroundColor Cyan
    if ($AnIpWasFound) {
        Write-Host "  Valid and active IP configuration detected." -ForegroundColor Green
    } else {
        Write-Host "  No IP Address" -ForegroundColor Red -BackgroundColor Black
        Write-Host "  No valid IP address or missing gateway." -ForegroundColor Red
        Write-Host "  Conclusion : DHCP, cable, Wi-Fi or network card issue." -ForegroundColor Yellow
        Write-Host "  Action     : Compare configuration with a working workstation." -ForegroundColor Yellow
    }
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
}


function Get-InfoInternet {
    <#
    .SYNOPSIS
        Accurate diagnostics compatible with School Proxies / Mobile Hotspots.
    #>
    Clear-Host
    Write-Host "=== INTERNET CONNECTIVITY TESTS ===" -ForegroundColor Cyan

    $ActiveNetworkConfig = Get-ActiveNetworkConfig
    # Safety: retrieves the first IPv4 gateway if it exists, otherwise returns $null
    $GW = if ($ActiveNetworkConfig) { Get-FirstIPv4 $ActiveNetworkConfig.DefaultIPGateway } else { $null }
    $GatewayOK = $false

    if ($GW) {
        # Pings the local gateway (router) once (-Count 1) silently (-Quiet)
        if (Test-Connection -ComputerName $GW -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            Write-Host "| Local Gateway ($GW) : OK" -ForegroundColor Green
            $GatewayOK = $true
        } else {
            Write-Host "| Local Gateway ($GW) : FAILED (Local Cut-off)" -ForegroundColor Red
        }
    } else {
        Write-Host "| Local Gateway          : NOT FOUND" -ForegroundColor Red
    }

    # Anti-crash safety: If the gateway does not respond, exit the function immediately
    if (-not $GatewayOK) {
        Write-Host "--> Diagnosis: Physical cut-off or Wi-Fi disconnected." -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
        return
    }

    # Resolve-DnsName tests if DNS servers can translate a domain name to an IP address
    $TestDNS = Resolve-DnsName -Name "www.google.com" -ErrorAction SilentlyContinue
    $DnsOK = if ($TestDNS) { $true } else { $false }

    # Invoke-WebRequest simulates a browser request to pass through potential proxy servers
    $TestWeb = Invoke-WebRequest -Uri "https://www.google.com" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
    # HTTP Status 200 = Web page loaded successfully
    $InternetOK = if ($TestWeb.StatusCode -eq 200) { $true } else { $false }

    Write-Host "| DNS Resolution (google.com) : $(if ($DnsOK) {'OK'} else {'FAILED'})"
    Write-Host "| Internet Access (Web Flux)  : $(if ($InternetOK) {'OK'} else {'FAILED'})"
    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray

    # Cascading analysis of the internet outage type
    if ($InternetOK) {
        Write-Host "CONCLUSION: Everything is functional. Internet and DNS OK." -ForegroundColor Green
    }
    else {
        if (-not $DnsOK) {
            Write-Host "CONCLUSION: PROBABLE DNS ISSUE!" -ForegroundColor Red
            Write-Host "ACTION     : Unable to resolve 'google.com'. Check network adapter DNS servers." -ForegroundColor Yellow
        } 
        else {
            # Typical case: DNS resolves the IP but HTTP traffic is blocked (Unauthenticated proxy or firewall)
            Write-Host "CONCLUSION: Network block or misconfigured Proxy." -ForegroundColor Yellow
            Write-Host "ACTION     : DNS is working, but HTTP/HTTPS traffic is blocked (check proxy credentials)." -ForegroundColor Yellow
        }
    }

    Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
}


function Get-EspaceDisque {
    <#
    .SYNOPSIS
        Displays free space on the C: drive.
    #>
    Clear-Host
    Write-Host "=== DISK SPACE (C:) ===" -ForegroundColor Cyan
    $DriveC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    
    # Converts raw bytes into Gigabytes (GB) rounded to 2 decimals
    $TotalSize = [Math]::Round($DriveC.Size / 1GB, 2)
    $FreeSpace  = [Math]::Round($DriveC.FreeSpace / 1GB, 2)
    
    # Mathematical calculation of used and remaining space percentages
    $PercentFree   = [Math]::Round(($DriveC.FreeSpace / $DriveC.Size) * 100, 1)
    $PercentUsed   = [Math]::Round(100 - $PercentFree, 1)

    Write-Host "Total Size : $TotalSize GB"
    Write-Host "Free Space : $FreeSpace GB ($PercentFree % free)"
    Write-Host "Used Space : $([Math]::Round($TotalSize - $FreeSpace, 2)) GB ($PercentUsed % used)" -ForegroundColor Gray
    
    # Critical alert thresholds (5% and 15%) for storage maintenance
    if (($FreeSpace / $TotalSize) -lt 0.05) {
        Write-Host "Less than 5% free space, disk cleanup or space analysis required!" -ForegroundColor Red
    } elseif (($FreeSpace / $TotalSize) -lt 0.15) {
        Write-Host "Warning: Less than 15% free space!" -ForegroundColor Yellow
    } else {
        Write-Host "Sufficient disk space." -ForegroundColor Green
    }
    Write-Host "--------------------------"
}

function Get-InfoImprimantes {
    <#
    .SYNOPSIS
        Displays printers in read-only mode directly without extra variables.
    #>
    Clear-Host
    Write-Host "=== PRINTER COLLECTION ===" -ForegroundColor Cyan

    Get-CimInstance Win32_Printer | ForEach-Object {
        Write-Host "  | Name                   : $($_.Name)" -ForegroundColor White
        # Uses the .Default boolean property to instantly identify the default printer
        Write-Host "  | Default Printer        : $(if($_.Default){'YES'}else{'No'})"
        Write-Host "  | Driver Used            : $($_.DriverName)"
        Write-Host "  | Connection Port        : $($_.PortName)"
        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
    }
}

function Get-InfoLecteursReseau {
    <#
    .SYNOPSIS
        Displays the list of mapped network drives, their path, and actual status.
    #>
    Clear-Host 
    Write-Host "=== MAPPED NETWORK DRIVES ===" -ForegroundColor Cyan

    # DriveType -eq 4 specifically targets mapped network shares (e.g. Z:, X: drives, etc.)
    $DriveList = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 4 }

    if ($null -eq $DriveList) {
        Write-Host "No network drives mapped on this workstation." -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
        return
    }

    $DriveList | ForEach-Object {
        Write-Host "  | Letter            : $($_.DeviceID)" -ForegroundColor White
        Write-Host "  | Network Path      : $($_.ProviderName)"

        # Isolates the remote server name or IP by splitting backslashes
        $Server = if ($_.ProviderName) { $_.ProviderName.Split('\')[2] } else { $null }

        if ($Server -and (Test-Connection -ComputerName $Server -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
            Write-Host "  | Drive Status      : ACCESSIBLE (Server Online)" -ForegroundColor Green
        } else {
            Write-Host "  | Drive Status      : OFFLINE or INACCESSIBLE" -ForegroundColor Red
        }

        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
    }
}



function Install-FichierConfig {
    # Generates a unique filename based on machine name and current time (Format: YYYYMMDD-HHMM)
    $PCName        = $env:COMPUTERNAME
    $FileDate      = Get-Date -Format "yyyyMMdd-HHmm"
    # Builds the absolute path to the current user's Desktop
    $FilePath      = "$env:USERPROFILE\Desktop\SupportBox-Report-$PCName-$FileDate.txt"

    # --- SILENT BACKGROUND DATA COLLECTION ---
    $ActiveNetworkConfig = Get-ActiveNetworkConfig
    $IP = if ($ActiveNetworkConfig) { Get-FirstIPv4 $ActiveNetworkConfig.IPAddress } else { $null }
    $GW = if ($ActiveNetworkConfig) { Get-FirstIPv4 $ActiveNetworkConfig.DefaultIPGateway } else { $null }
    
    $GWStatus = "FAILED"
    if ($GW -and (Test-Connection -ComputerName $GW -Count 1 -Quiet -ErrorAction SilentlyContinue)) { $GWStatus = "OK" }

    $DNSStatus = "FAILED"
    $WebStatus = "FAILED"
    $ConclusionTxt = ""

    $DriveC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $FreeSpaceGB = [Math]::Round(($DriveC.FreeSpace / 1GB), 2)
    $TotalSpaceGB = [Math]::Round(($DriveC.Size / 1GB), 2)
    $PercentFree = ($DriveC.FreeSpace / $DriveC.Size) * 100

    # --- DECISION TREE FOR THE REPORT ---
    if (-not $IP -or -not $GW) {
        $ConclusionTxt = "DHCP, CABLE, WI-FI OR NETWORK CARD ISSUE! No valid IP address or missing gateway. Action: Compare with a working workstation."
    }
    elseif ($PercentFree -lt 5) {
        $ConclusionTxt = "CRITICAL - INSUFFICIENT DISK SPACE! Drive C: has less than 5% free space ($FreeSpaceGB GB remaining). Action: Clean up disk or analyze space usage urgently."
    }
    elseif ($PercentFree -lt 15) {
        $ConclusionTxt = "WARNING - LOW DISK SPACE! Drive C: has less than 15% free space ($FreeSpaceGB GB remaining). Conclusion: Possible insufficient space. Action: Clean up or analyze usage."
    }
    elseif ($GWStatus -eq "OK") {
        if (Resolve-DnsName -Name "www.google.com" -ErrorAction SilentlyContinue) { $DNSStatus = "OK" }
        $TestWeb = Invoke-WebRequest -Uri "https://www.google.com" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($TestWeb.StatusCode -eq 200) { $WebStatus = "OK" }

        if ($WebStatus -eq "OK") {
            $ConclusionTxt = "Everything is functional. Internet and DNS OK."
        } elseif ($DNSStatus -eq "FAILED") {
            $ConclusionTxt = "PROBABLE DNS ISSUE! Unable to resolve domain names."
        } else {
            $ConclusionTxt = "Network block or misconfigured Proxy (HTTP/HTTPS traffic blocked)."
        }
    } else {
        $ConclusionTxt = "Local physical cut-off (No access to local gateway, cable unplugged or Wi-Fi turned off)."
    }

    # --- PRINTER LISTING & FORMATTING ---
    $PrinterListTxt = ""
    $Printers = Get-CimInstance Win32_Printer
    if ($Printers) {
        foreach ($Printer in $Printers) {
            $Default = if ($Printer.Default) { "YES" } else { "NO" }
            $PrinterListTxt += "`r`n   [ Default: $Default ] Name: $($Printer.Name) | Driver: $($Printer.DriverName)"
        }
    } else {
        $PrinterListTxt = " No devices detected."
    }

    # --- NETWORK SHARES LISTING & VERIFICATION ---
    $DriveListTxt = ""
    $Drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 4 }
    if ($Drives) {
        foreach ($Drive in $Drives) {
            $Server = if ($Drive.ProviderName) { $Drive.ProviderName.Split('\')[2] } else { $null }
            $DriveState = "INACCESSIBLE"
            if ($Server) {
                if (Test-Connection -ComputerName $Server -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                    $DriveState = "ACCESSIBLE"
                } else {
                    # Safety double-check on standard SMB port (445) if ICMP ping is blocked
                    $TestSMB = Test-NetConnection -ComputerName $Server -Port 445 -WarningAction SilentlyContinue
                    if ($TestSMB.TcpTestSucceeded) { $DriveState = "ACCESSIBLE" }
                }
            }
            $DriveListTxt += "`r`n   | $($Drive.DeviceID) -> $($Drive.ProviderName) [$DriveState]"
        }
    } else {
        $DriveListTxt = " No mapped network drives."
    }

    # Report layout construction (Here-String)
    $ReportContent = @"
======================================================================
                     PC DIAGNOSTIC REPORT
======================================================================
> Diagnostic Date      : $(Get-Date -Format "dd/MM/yyyy HH:mm")
> Computer Name        : $env:COMPUTERNAME
> Username              : $env:USERNAME

----------------------------------------------------------------------
SYSTEM INFORMATION
----------------------------------------------------------------------
> Windows Info         : $((Get-CimInstance Win32_OperatingSystem).Caption) ($env:PROCESSOR_ARCHITECTURE)
> Disk Space C:        : $FreeSpaceGB GB free out of $TotalSpaceGB GB ($([Math]::Round($PercentFree, 1))% free)

----------------------------------------------------------------------
CONNECTIVITY & NETWORK
----------------------------------------------------------------------
> Current IP Address   : $(if($IP){$IP}else{"No IP"})
> Local Gateway        : $(if($GW){$GW}else{"None"}) ($GWStatus)
> DNS Resolution       : google.com ($DNSStatus)
> Web Flux (Internet)  : $WebStatus
----------------------------------------------------------------------
PERIPHERALS & SHARES
----------------------------------------------------------------------
> Printers             : $PrinterListTxt
> Network Drives       : $DriveListTxt

----------------------------------------------------------------------
DIAGNOSTIC CONCLUSION
----------------------------------------------------------------------
> Automated Conclusion : $ConclusionTxt
======================================================================
"@

    # Physically writes the text file onto the Desktop
    try {
        $ReportContent | Out-File -FilePath $FilePath -Force -Encoding utf8 -ErrorAction Stop
        Clear-Host
        Write-Host "[OK] Report generated on Desktop : SupportBox-Report-$PCName-$FileDate.txt" -ForegroundColor Green
    }
    catch {
        Clear-Host
        Write-Host "[ERROR] Unable to write the file onto the Desktop." -ForegroundColor Red
    }
}


function Get-TicketSupport {
    <#
    .SYNOPSIS
        Generates a compact diagnostic summary and copies it directly
        to the clipboard, ensuring correct character encoding.
    #>
    Clear-Host
    Write-Host "=== SUPPORT TICKET GENERATION ===" -ForegroundColor Cyan

    # Loads the .NET graphical library required to interact with the Windows clipboard
    Add-Type -AssemblyName System.Windows.Forms

    $ActiveNetworkConfig = Get-ActiveNetworkConfig
    $IP = if ($ActiveNetworkConfig) { Get-FirstIPv4 $ActiveNetworkConfig.IPAddress } else { $null }
    $GW = if ($ActiveNetworkConfig) { Get-FirstIPv4 $ActiveNetworkConfig.DefaultIPGateway } else { $null }
    
    $GWStatus = "FAILED"
    if ($GW -and (Test-Connection -ComputerName $GW -Count 1 -Quiet -ErrorAction SilentlyContinue)) { $GWStatus = "OK" }

    $DNSStatus = "FAILED"
    $WebStatus = "FAILED"
    $TicketConclusion = ""

    $IPFinding = if ($IP) { "The workstation has a valid IP address." } else { "The workstation does not have a valid IP address." }
    $GWFinding = if ($GWStatus -eq "OK") { "The gateway responds." } else { "The gateway is not responding or is missing." }
    $WebFinding = "Internet access via IP / Web Flux is untested."
    $DNSFinding = "DNS resolution is untested."

    $DriveC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $PercentFree = ($DriveC.FreeSpace / $DriveC.Size) * 100

    if (-not $IP -or -not $GW) {
        $TicketConclusion = "DHCP, cable, Wi-Fi, or network card issue."
    }
    elseif ($PercentFree -lt 5) {
        $TicketConclusion = "Critical disk space (Less than 5% free)."
    }
    elseif ($PercentFree -lt 15) {
        $TicketConclusion = "Possible low disk space (Less than 15% free)."
    }
    else {
        if ($GWStatus -eq "OK") {
            if (Resolve-DnsName -Name "www.google.com" -ErrorAction SilentlyContinue) { $DNSStatus = "OK" }
            $TestWeb = Invoke-WebRequest -Uri "https://www.google.com" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($TestWeb.StatusCode -eq 200) { $WebStatus = "OK" }

            $DNSFinding = if ($DNSStatus -eq "OK") { "DNS resolution works." } else { "DNS resolution fails." }
            $WebFinding = if ($WebStatus -eq "OK") { "Internet access via IP works." } else { "Internet access via IP / Web Flux fails." }

            if ($WebStatus -eq "OK") {
                $TicketConclusion = "No issues detected. Everything is functional."
            } elseif ($DNSStatus -eq "FAILED") {
                $TicketConclusion = "DNS issue or partial network configuration."
            } else {
                $TicketConclusion = "Network block or misconfigured Proxy."
            }
        } else {
            $TicketConclusion = "No access to the local network gateway."
        }
    }

    $TicketText = @"
Diagnostic summary:

Workstation: $env:COMPUTERNAME
User: $env:USERNAME
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm")

Findings:
$IPFinding
$GWFinding
$WebFinding
$DNSFinding

Probable conclusion:
$TicketConclusion
"@

    try {
        # Calls the .NET Windows Forms API command to paste the string into the clipboard
        [Windows.Forms.Clipboard]::SetText($TicketText)
        
        Write-Host "[OK] The ticket summary has been copied to your clipboard!" -ForegroundColor Green
        Write-Host "     Open your ticketing tool and simply press CTRL+V." -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "[ERROR] Unable to access the Windows clipboard." -ForegroundColor Red
    }
}


# ------------------------------------------------------------------------------
# 2. MAIN LOOP AND MENU
# ------------------------------------------------------------------------------

# Control variable serving as an ON/OFF switch to keep the menu active
$Continue = $true

while ($Continue) {
    
    Clear-Host
    Write-Host "`n=== MAINTENANCE MENU ===" -ForegroundColor Magenta
    Write-Host "1. Display system info"
    Write-Host "2. Network diagnostics"
    Write-Host "3. Test Internet / DNS"
    Write-Host "4. Check disk space (C:)"
    Write-Host "5. Printers"
    Write-Host "6. Network drives"
    Write-Host "7. Generate full report"
    Write-Host "8. Generate summary for support ticket"
    Write-Host "9. Exit script"
    Write-Host "========================="
    
    # Pauses the script and waits for user input
    $Choice = Read-Host "Enter your choice (1-9)"
    
    # Switch routing structure based on user choice
    switch ($Choice) {
        "1" { Get-InfoSystem }
        "2" { Get-InfoReseau }
        "3" { Get-InfoInternet }
        "4" { Get-EspaceDisque }
        "5" { Get-InfoImprimantes }
        "6" { Get-InfoLecteursReseau }
        "7" { Install-FichierConfig }
        "8" { Get-TicketSupport }
        "9" { 
            Write-Host "`nThank you for using the script. Goodbye!" -ForegroundColor Magenta
            # Sets the variable to False to break the While loop and close the program
            $Continue = $false 
        }
        Default { 
            # Triggered only if the input does not match any digit from 1 to 9
            Write-Host "Invalid choice, please try again." -ForegroundColor Red 
        }
    }
    
    # Freezes the output result on the screen before reloading the main menu
    if ($Continue) {
        Read-Host "`nPress Enter to return to the menu..."
        Clear-Host
    }
}