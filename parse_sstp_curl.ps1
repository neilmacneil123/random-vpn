# PowerShell script to fetch and parse MS-SSTP servers from VPNGate using curl
# Usage: .\parse_sstp_curl.ps1

Write-Host "Fetching VPN Gate server list..." -ForegroundColor Cyan

try {
    # Download the HTML page using Invoke-WebRequest (PowerShell's curl)
    $response = Invoke-WebRequest -Uri "https://www.vpngate.net/en/" -UseBasicParsing
    $html = $response.Content
    
    Write-Host "Page fetched successfully. Parsing MS-SSTP servers..." -ForegroundColor Green
    
    # Save a copy of the HTML for debugging
    $html | Out-File "vpngate_downloaded.html" -Encoding UTF8
    
} catch {
    Write-Host "Error fetching page: $_" -ForegroundColor Red
    Write-Host "Trying to use cached vpngate.html if available..." -ForegroundColor Yellow
    
    if (Test-Path "vpngate.html") {
        $html = Get-Content "vpngate.html" -Raw
    } else {
        Write-Host "No cached HTML file found. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Parse the HTML to find MS-SSTP servers
$sstpServers = @()

# Find all table rows
$rowPattern = "(?s)<tr[^>]*>.*?</tr>"
$rows = [regex]::Matches($html, $rowPattern)

Write-Host "Found $($rows.Count) table rows. Analyzing..." -ForegroundColor Yellow

foreach ($row in $rows) {
    $rowHtml = $row.Value
    
    # Check if this row contains MS-SSTP checkmark/link
    # The MS-SSTP column contains either a checkmark image or "Connect guide" link
    if ($rowHtml -match "MS-SSTP" -or ($rowHtml -match "SSTP Hostname" -and $rowHtml -match "public-vpn")) {
        
        # Extract all table cells
        $cellPattern = "(?s)<td[^>]*>(.*?)</td>"
        $cells = [regex]::Matches($rowHtml, $cellPattern)
        
        if ($cells.Count -ge 8) {
            # Cell 0: Country with flag
            $countryCell = $cells[0].Groups[1].Value
            $country = ""
            if ($countryCell -match "<br>\s*([^<]+?)\s*<") {
                $country = $matches[1].Trim()
            } elseif ($countryCell -match "flags/(\w+)\.png") {
                $country = $matches[1].ToUpper()
            }
            
            # Cell 1: Hostname and IP
            $hostCell = $cells[1].Groups[1].Value
            $hostname = ""
            $ip = ""
            
            # Extract hostname (in bold)
            if ($hostCell -match "<b[^>]*>.*?<span[^>]*>([^<]+)</span>.*?</b>") {
                $hostname = $matches[1].Trim()
            }
            
            # Extract IP address
            if ($hostCell -match "(\d+\.\d+\.\d+\.\d+)") {
                $ip = $matches[1].Trim()
            }
            
            # Cell 2: VPN Sessions (uptime, users)
            $sessionCell = $cells[2].Groups[1].Value
            $sessions = ""
            $uptime = ""
            if ($sessionCell -match "<b[^>]*>(\d+)\s+sessions") {
                $sessions = $matches[1].Trim()
            }
            if ($sessionCell -match "(\d+)\s+days") {
                $uptime = $matches[1] + " days"
            }
            
            # Cell 3: Line quality (Speed and Ping)
            $qualityCell = $cells[3].Groups[1].Value
            $speed = ""
            $ping = ""
            
            if ($qualityCell -match "([0-9.]+)\s+Mbps") {
                $speed = $matches[1].Trim() + " Mbps"
            }
            if ($qualityCell -match "Ping:\s*<b>([^<]+)</b>") {
                $ping = $matches[1].Trim()
            }
            
            # Cell 7: MS-SSTP column (8th column, index 7)
            if ($cells.Count -gt 7) {
                $sstpCell = $cells[7].Groups[1].Value
                $sstpHostname = ""
                
                # Extract SSTP hostname - pattern: SSTP Hostname :<br /><b><span style='color: #006600;' >hostname</span></b>
                if ($sstpCell -match "SSTP\s+Hostname\s*:.*?<span[^>]*>([^<]+)</span>") {
                    $sstpHostname = $matches[1].Trim()
                }
            } else {
                $sstpHostname = ""
            }
            
            # Only add if we have valid SSTP hostname
            if ($sstpHostname -ne "" -and $hostname -ne "") {
                $server = [PSCustomObject]@{
                    Country = $country
                    Hostname = $hostname
                    IP = $ip
                    SSTP_Hostname = $sstpHostname
                    Speed = $speed
                    Ping = $ping
                    Sessions = $sessions
                    Uptime = $uptime
                }
                $sstpServers += $server
            }
        }
    }
}

# Display results
Write-Host ""
Write-Host "=== MS-SSTP Servers Found: $($sstpServers.Count) ===" -ForegroundColor Green
Write-Host ""

if ($sstpServers.Count -eq 0) {
    Write-Host "No MS-SSTP servers found. The page structure may have changed." -ForegroundColor Yellow
    exit 1
}

foreach ($server in $sstpServers) {
    Write-Host "Country:        $($server.Country)" -ForegroundColor Cyan
    Write-Host "Hostname:       $($server.Hostname)" -ForegroundColor Yellow
    Write-Host "IP Address:     $($server.IP)" -ForegroundColor Yellow
    Write-Host "SSTP Hostname:  $($server.SSTP_Hostname)" -ForegroundColor Green
    Write-Host "Speed:          $($server.Speed)"
    Write-Host "Ping:           $($server.Ping)"
    Write-Host "Sessions:       $($server.Sessions)"
    Write-Host "Uptime:         $($server.Uptime)"
    Write-Host "----------------------------------------"
}

# Export to CSV
$csvPath = "sstp_servers_curl.csv"
$sstpServers | Export-Csv $csvPath -NoTypeInformation
Write-Host ""
Write-Host "Data exported to $csvPath" -ForegroundColor Green

# Also create a simple text file with just the SSTP hostnames
$txtPath = "sstp_hostnames.txt"
$sstpServers | ForEach-Object { $_.SSTP_Hostname } | Out-File $txtPath -Encoding UTF8
Write-Host "SSTP hostnames exported to $txtPath" -ForegroundColor Green
Write-Host ""