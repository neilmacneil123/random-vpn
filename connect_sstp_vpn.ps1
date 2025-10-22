# PowerShell script to connect to MS-SSTP VPN servers from VPNGate
# Usage: .\connect_sstp_vpn.ps1
# Requires: Administrator privileges

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges to create VPN connections." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== VPN Gate MS-SSTP Connection Manager ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Fetching fresh list of MS-SSTP servers..." -ForegroundColor Yellow

try {
    # Download the HTML page
    $response = Invoke-WebRequest -Uri "https://www.vpngate.net/en/" -UseBasicParsing
    $html = $response.Content
    Write-Host "Server list fetched successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "Error fetching server list: $_" -ForegroundColor Red
    exit 1
}

# Parse the HTML to find MS-SSTP servers
$sstpServers = @()
$rowPattern = "(?s)<tr[^>]*>.*?</tr>"
$rows = [regex]::Matches($html, $rowPattern)

foreach ($row in $rows) {
    $rowHtml = $row.Value
    
    if ($rowHtml -match "MS-SSTP" -or ($rowHtml -match "SSTP Hostname" -and $rowHtml -match "public-vpn")) {
        $cellPattern = "(?s)<td[^>]*>(.*?)</td>"
        $cells = [regex]::Matches($rowHtml, $cellPattern)
        
        if ($cells.Count -ge 8) {
            # Extract country
            $countryCell = $cells[0].Groups[1].Value
            $country = ""
            if ($countryCell -match "<br>\s*([^<]+?)\s*<") {
                $country = $matches[1].Trim()
            } elseif ($countryCell -match "flags/(\w+)\.png") {
                $country = $matches[1].ToUpper()
            }
            
            # Extract hostname and IP
            $hostCell = $cells[1].Groups[1].Value
            $hostname = ""
            $ip = ""
            if ($hostCell -match "<b[^>]*>.*?<span[^>]*>([^<]+)</span>.*?</b>") {
                $hostname = $matches[1].Trim()
            }
            if ($hostCell -match "(\d+\.\d+\.\d+\.\d+)") {
                $ip = $matches[1].Trim()
            }
            
            # Extract speed and ping
            $qualityCell = $cells[3].Groups[1].Value
            $speed = ""
            $ping = ""
            $pingNum = 9999  # Default high value for servers with no ping
            if ($qualityCell -match "([0-9.]+)\s+Mbps") {
                $speed = $matches[1].Trim()
            }
            if ($qualityCell -match "Ping:\s*<b>([^<]+)</b>") {
                $ping = $matches[1].Trim()
                # Try to extract numeric ping value
                if ($ping -match "(\d+)") {
                    $pingNum = [int]$matches[1]
                }
            }
            
            # Extract SSTP hostname
            if ($cells.Count -gt 7) {
                $sstpCell = $cells[7].Groups[1].Value
                $sstpHostname = ""
                if ($sstpCell -match "SSTP\s+Hostname\s*:.*?<span[^>]*>([^<]+)</span>") {
                    $sstpHostname = $matches[1].Trim()
                }
                
                if ($sstpHostname -ne "" -and $hostname -ne "") {
                    $server = [PSCustomObject]@{
                        Country = $country
                        Hostname = $hostname
                        IP = $ip
                        SSTP_Hostname = $sstpHostname
                        Speed = [double]$speed
                        Ping = $ping
                        PingNum = $pingNum
                    }
                    $sstpServers += $server
                }
            }
        }
    }
}

if ($sstpServers.Count -eq 0) {
    Write-Host "No MS-SSTP servers found. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Found $($sstpServers.Count) MS-SSTP servers!" -ForegroundColor Green
Write-Host ""

# Check for existing active VPN connections (just to inform user)
$activeVpns = Get-VpnConnection | Where-Object { $_.ConnectionStatus -eq 'Connected' }
if ($activeVpns) {
    Write-Host "Active VPN connection(s) detected:" -ForegroundColor Yellow
    foreach ($vpn in $activeVpns) {
        Write-Host "  - $($vpn.Name) [$($vpn.ServerAddress)]" -ForegroundColor Cyan
    }
    Write-Host "  (Will disconnect automatically when you select a new server)" -ForegroundColor Gray
    Write-Host ""
}

# Sort by ping (ascending - lower is better) and take top 20 for display
$topServers = $sstpServers | Sort-Object -Property PingNum | Select-Object -First 20

# Display menu
Write-Host "=== Top 20 Lowest Ping Servers ===" -ForegroundColor Cyan
Write-Host ""
for ($i = 0; $i -lt $topServers.Count; $i++) {
    $server = $topServers[$i]
    $displayNum = $i + 1
    Write-Host ("{0,2}. " -f $displayNum) -NoNewline -ForegroundColor Yellow
    Write-Host ("{0,-3} " -f $server.Country) -NoNewline -ForegroundColor Cyan
    Write-Host ("{0,-35} " -f $server.Hostname) -NoNewline
    Write-Host ("{0,8} Mbps " -f $server.Speed) -NoNewline -ForegroundColor Green
    Write-Host ("Ping: {0}" -f $server.Ping) -ForegroundColor Gray
}

Write-Host ""
Write-Host "0.  Exit" -ForegroundColor Red
Write-Host ""

# Get user selection
do {
    $selection = Read-Host "Select a server (1-$($topServers.Count)) or 0 to exit"
    $selectionNum = 0
    $validInput = [int]::TryParse($selection, [ref]$selectionNum)
} while (-not $validInput -or $selectionNum -lt 0 -or $selectionNum -gt $topServers.Count)

if ($selectionNum -eq 0) {
    Write-Host "Exiting..." -ForegroundColor Yellow
    exit 0
}

$selectedServer = $topServers[$selectionNum - 1]

Write-Host ""

# Now disconnect from any active VPNs before connecting to new one
$activeVpns = Get-VpnConnection | Where-Object { $_.ConnectionStatus -eq 'Connected' }
if ($activeVpns) {
    Write-Host "Disconnecting from active VPN(s)..." -ForegroundColor Yellow
    foreach ($vpn in $activeVpns) {
        try {
            rasdial $vpn.Name /disconnect | Out-Null
            Write-Host "  Disconnected from: $($vpn.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  Warning: Could not disconnect from $($vpn.Name): $_" -ForegroundColor Yellow
        }
    }
    Start-Sleep -Seconds 2
    Write-Host ""
}

Write-Host "Selected Server:" -ForegroundColor Cyan
Write-Host "  Country:        $($selectedServer.Country)"
Write-Host "  Hostname:       $($selectedServer.Hostname)"
Write-Host "  SSTP Hostname:  $($selectedServer.SSTP_Hostname)"
Write-Host "  Speed:          $($selectedServer.Speed) Mbps"
Write-Host "  Ping:           $($selectedServer.Ping)"
Write-Host ""

# VPN connection name
$vpnName = "VPNGate-SSTP"

# Remove existing VPN connection if it exists
try {
    $existingVpn = Get-VpnConnection -Name $vpnName -ErrorAction SilentlyContinue
    if ($existingVpn) {
        Write-Host "Removing existing VPN connection..." -ForegroundColor Yellow
        Remove-VpnConnection -Name $vpnName -Force -ErrorAction SilentlyContinue
    }
} catch {
    # Connection doesn't exist, that's fine
}

# Create new VPN connection
Write-Host "Creating VPN connection..." -ForegroundColor Yellow
try {
    Add-VpnConnection -Name $vpnName `
        -ServerAddress $selectedServer.SSTP_Hostname `
        -TunnelType Sstp `
        -EncryptionLevel Required `
        -AuthenticationMethod MSChapv2 `
        -RememberCredential `
        -Force
    
    Write-Host "VPN connection created successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error creating VPN connection: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Connecting to VPN..." -ForegroundColor Yellow
Write-Host "Username: vpn" -ForegroundColor Cyan
Write-Host "Password: vpn" -ForegroundColor Cyan
Write-Host ""

# Connect to VPN using rasdial
try {
    # Use rasdial for connection (more reliable than cmdlet for SSTP)
    $result = rasdial $vpnName "vpn" "vpn"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Successfully connected to VPN!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Connection Details:" -ForegroundColor Cyan
        Write-Host "  VPN Name: $vpnName"
        Write-Host "  Server:   $($selectedServer.SSTP_Hostname)"
        Write-Host "  Country:  $($selectedServer.Country)"
        Write-Host ""
        Write-Host "To disconnect, run: " -NoNewline
        Write-Host "rasdial $vpnName /disconnect" -ForegroundColor Yellow
        Write-Host ""
        # Show connection status
        Start-Sleep -Seconds 2
        Get-VpnConnection -Name $vpnName | Format-List Name, ServerAddress, ConnectionStatus
        
        # Verify VPN connection by testing connectivity and routing
        Write-Host ""
        Write-Host "=== Verifying VPN Connection ===" -ForegroundColor Cyan
        Write-Host ""
        
        # Wait a moment for routing table to update
        Start-Sleep -Seconds 3
        
        # Test 1: Ping Google
        Write-Host "Testing connectivity to Google..." -ForegroundColor Yellow
        try {
            $pingResult = Test-Connection -ComputerName "8.8.8.8" -Count 4 -ErrorAction Stop
            $avgPing = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
            Write-Host "  Success! Average ping to Google: $([math]::Round($avgPing, 2)) ms" -ForegroundColor Green
        } catch {
            Write-Host "  Warning: Could not ping Google (8.8.8.8)" -ForegroundColor Yellow
            Write-Host "  This might indicate connectivity issues" -ForegroundColor Yellow
        }
        
        Write-Host ""
        
        # Test 2: Check public IP
        Write-Host "Checking your public IP address..." -ForegroundColor Yellow
        try {
            $publicIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 10).Content
            Write-Host "  Your current public IP: $publicIP" -ForegroundColor Cyan
            
            # Check if it matches the VPN server IP or is in same country
            if ($publicIP -eq $selectedServer.IP) {
                Write-Host "  IP matches VPN server!" -ForegroundColor Green
            } else {
                Write-Host "  VPN Server IP: $($selectedServer.IP)" -ForegroundColor Gray
                Write-Host "  (Your IP may differ from server IP due to NAT)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  Could not retrieve public IP" -ForegroundColor Yellow
        }
        
        Write-Host ""
        
    } else {
        Write-Host "Failed to connect to VPN. Error code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host ""
        Write-Host "Possible issues:" -ForegroundColor Yellow
        Write-Host "  - Server might be overloaded or offline"
        Write-Host "  - Try another server from the list"
        Write-Host "  - Check your internet connection"
        Write-Host ""
        Write-Host "You can try connecting manually with:" -ForegroundColor Cyan
        Write-Host "  rasdial $vpnName vpn vpn"
    }
} catch {
    Write-Host "Error connecting to VPN: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "You can try connecting manually with:" -ForegroundColor Cyan
    Write-Host "  rasdial $vpnName vpn vpn"
}

Write-Host ""