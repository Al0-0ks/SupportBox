
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
=== MAINTENANCE MENU ===
1. Display system info
2. Network diagnostics
3. Test Internet / DNS
4. Check disk space (C:)
5. Printers
6. Network drives
7. Generate full report
8. Generate summary for support ticket
9. Exit script
=========================
Enter your choice (1-9):
