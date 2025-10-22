# VPN Gate MS-SSTP Connection Tools

PowerShell scripts to fetch, parse, and connect to MS-SSTP VPN servers from [VPN Gate](https://www.vpngate.net/en/) using Windows' built-in VPN functionality.

## Overview

This project provides two scripts:
1. **Server Parser** - Fetches and exports MS-SSTP server list
2. **VPN Connection Manager** - Interactive tool to connect to VPN servers

## Requirements

- Windows Vista/7/8/10/11 with built-in SSTP VPN support
- PowerShell (built into Windows)
- Administrator privileges (for VPN connection manager)
- Internet connection

## Scripts

### 1. Parse SSTP Servers (`parse_sstp_curl.ps1`)

Fetches and parses MS-SSTP servers from VPN Gate, exporting data to CSV and text files.

**Usage:**
```powershell
powershell -ExecutionPolicy Bypass -File .\parse_sstp_curl.ps1
```

**Output Files:**
- `sstp_servers_curl.csv` - Complete server data (Country, Hostname, IP, SSTP Hostname, Speed, Ping, etc.)
- `sstp_hostnames.txt` - Just the SSTP hostnames for quick reference
- `vpngate_downloaded.html` - Cached HTML page for debugging

**Features:**
- Fetches live server data using `Invoke-WebRequest`
- Falls back to cached HTML if network fails
- Extracts comprehensive server information
- Handles both standard hostnames and hostnames with custom ports
- Color-coded console output

---

### 2. VPN Connection Manager (`connect_sstp_vpn.ps1`)

Interactive script to connect to VPN Gate servers using Windows built-in VPN.

**Usage:**
```powershell
# Must run as Administrator
powershell -ExecutionPolicy Bypass -File .\connect_sstp_vpn.ps1
```

**Features:**
- Fetches fresh MS-SSTP server list
- Detects active VPN connections
- Displays top 20 servers sorted by **lowest ping** (best latency)
- Interactive numbered menu for server selection
- Auto-disconnects from old VPN when new server is chosen
- Creates Windows VPN connection automatically
- Connects using standard VPN Gate credentials (vpn/vpn)
- Verifies connection with:
  - Ping test to Google (8.8.8.8)
  - Public IP address check

**Workflow:**
```
1. Fetch server list from VPN Gate
2. Show active VPN connections (if any)
3. Display top 20 lowest-ping servers
4. User selects server number
5. Disconnect from any active VPNs
6. Create and connect to new VPN
7. Verify connectivity and show public IP
```

**Example Output:**
```
=== Top 20 Lowest Ping Servers ===

 1. JP  aura143.opengw.net                    99.75 Mbps  Ping: 1 ms
 2. JP  vpn791857798.opengw.net              1023.83 Mbps  Ping: 3 ms
 3. JP  vpn104717671.opengw.net                84.66 Mbps  Ping: 3 ms
...

Select a server (1-20) or 0 to exit: 1

Selected Server:
  Country:        JP
  Hostname:       aura143.opengw.net
  SSTP Hostname:  aura143.opengw.net
  Speed:          99.75 Mbps
  Ping:           1 ms

Creating VPN connection...
Successfully connected to VPN!

=== Verifying VPN Connection ===

Testing connectivity to Google...
  Success! Average ping to Google: 45.25 ms

Checking your public IP address...
  Your current public IP: 164.70.84.149
  VPN Server IP: 164.70.84.149
  IP matches VPN server!
```

## VPN Connection Details

**Connection Name:** `VPNGate-SSTP`  
**Credentials:**
- Username: `vpn`
- Password: `vpn`

**To Disconnect:**
```powershell
rasdial VPNGate-SSTP /disconnect
```

## Troubleshooting

### Execution Policy Error
If you get "running scripts is disabled" error:

```powershell
# Option 1: Use bypass flag (recommended)
powershell -ExecutionPolicy Bypass -File .\connect_sstp_vpn.ps1

# Option 2: Change policy temporarily
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\connect_sstp_vpn.ps1
```

### Administrator Privileges Required
The VPN connection manager requires administrator privileges to:
- Create VPN connections
- Disconnect existing VPNs
- Modify network settings

Right-click PowerShell → "Run as Administrator"

### Connection Fails
If connection fails:
- Try another server from the list
- Some servers may be overloaded or offline
- Check your internet connection
- Verify Windows Firewall isn't blocking SSTP (port 443)

## About VPN Gate

VPN Gate is an academic research project run by the University of Tsukuba, Japan. It provides free public VPN relay servers operated by volunteers worldwide.

**Official Website:** https://www.vpngate.net/en/

**Supported VPN Protocols:**
- MS-SSTP (Windows built-in)
- L2TP/IPsec
- OpenVPN
- SoftEther VPN

## Security Notes

- VPN Gate servers are operated by volunteers
- Logging policies vary (typically 2 weeks)
- Suitable for bypassing geographic restrictions, but use discretion for sensitive data
- This is a public VPN service - encrypt sensitive traffic additionally if needed

## License

These scripts are provided as-is for educational and research purposes.

## Credits

- VPN Gate Academic Experiment Project
- University of Tsukuba, Japan