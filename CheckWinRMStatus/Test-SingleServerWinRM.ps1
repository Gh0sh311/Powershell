<#
.SYNOPSIS
    Test WinRM connectivity on a single server with detailed diagnostics.

.DESCRIPTION
    This script performs comprehensive WinRM testing on a single server, showing detailed information
    about each test attempt and why it failed or succeeded.

.PARAMETER ComputerName
    The name or IP address of the server to test.

.PARAMETER SkipCertificateCheck
    Skip SSL certificate validation when testing WinRM connections.

.EXAMPLE
    .\Test-SingleServerWinRM.ps1 -ComputerName "SERVER01"

.EXAMPLE
    .\Test-SingleServerWinRM.ps1 -ComputerName "SERVER01.domain.com" -SkipCertificateCheck

.NOTES
    Made by Trond Hoiberg
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,

    [Parameter(Mandatory=$false)]
    [switch]$SkipCertificateCheck
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WinRM Connectivity Test - Detailed Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target Server: $ComputerName" -ForegroundColor White
Write-Host "Test Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "Skip Certificate Check: $SkipCertificateCheck" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: DNS Resolution Test
Write-Host "[TEST 1] DNS Resolution" -ForegroundColor Yellow
Write-Host "  Testing DNS resolution for: $ComputerName" -NoNewline
try {
    $dnsResult = [System.Net.Dns]::GetHostEntry($ComputerName)
    Write-Host " [SUCCESS]" -ForegroundColor Green
    Write-Host "  Resolved to IP: $($dnsResult.AddressList[0].IPAddressToString)" -ForegroundColor Green
    Write-Host "  FQDN: $($dnsResult.HostName)" -ForegroundColor Green
    $resolvedIP = $dnsResult.AddressList[0].IPAddressToString
}
catch {
    Write-Host " [FAILED]" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  This could mean the server name is incorrect or DNS is not configured properly." -ForegroundColor Red
    $resolvedIP = $null
}

# Step 2: Network Connectivity Test
Write-Host "`n[TEST 2] Network Connectivity (ICMP Ping)" -ForegroundColor Yellow
Write-Host "  Pinging $ComputerName..." -NoNewline
try {
    $pingResult = Test-Connection -ComputerName $ComputerName -Count 2 -Quiet -ErrorAction Stop
    if ($pingResult) {
        Write-Host " [SUCCESS]" -ForegroundColor Green
        Write-Host "  Server is reachable on the network." -ForegroundColor Green
    }
    else {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "  Server did not respond to ping." -ForegroundColor Red
        Write-Host "  Note: Some servers may have ICMP disabled by firewall." -ForegroundColor Yellow
    }
}
catch {
    Write-Host " [FAILED]" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 3: WinRM HTTP Port Test (5985)
Write-Host "`n[TEST 3] WinRM HTTP Port (5985) Connectivity" -ForegroundColor Yellow
Write-Host "  Testing TCP port 5985..." -NoNewline
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect($ComputerName, 5985)
    Write-Host " [OPEN]" -ForegroundColor Green
    Write-Host "  Port 5985 is accessible." -ForegroundColor Green
    $tcpClient.Close()
    $port5985Open = $true
}
catch {
    Write-Host " [CLOSED/BLOCKED]" -ForegroundColor Red
    Write-Host "  Port 5985 is not accessible." -ForegroundColor Red
    Write-Host "  This could mean WinRM is not running or firewall is blocking the port." -ForegroundColor Red
    $port5985Open = $false
}

# Step 4: WinRM HTTPS Port Test (5986)
Write-Host "`n[TEST 4] WinRM HTTPS Port (5986) Connectivity" -ForegroundColor Yellow
Write-Host "  Testing TCP port 5986..." -NoNewline
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect($ComputerName, 5986)
    Write-Host " [OPEN]" -ForegroundColor Green
    Write-Host "  Port 5986 is accessible." -ForegroundColor Green
    $tcpClient.Close()
    $port5986Open = $true
}
catch {
    Write-Host " [CLOSED/BLOCKED]" -ForegroundColor Red
    Write-Host "  Port 5986 is not accessible." -ForegroundColor Red
    Write-Host "  HTTPS WinRM may not be configured on this server." -ForegroundColor Yellow
    $port5986Open = $false
}

# Configure certificate validation if needed
if ($SkipCertificateCheck) {
    Write-Host "`n[INFO] Certificate validation is disabled for this test." -ForegroundColor Yellow
    $originalCertValidation = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
}

# Step 5: WinRM Service Test via Test-WSMan (HTTP)
Write-Host "`n[TEST 5] WinRM Service Test - HTTP (Port 5985)" -ForegroundColor Yellow
if ($port5985Open) {
    Write-Host "  Attempting Test-WSMan on HTTP..." -NoNewline
    try {
        $wsmanResult = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
        Write-Host " [SUCCESS]" -ForegroundColor Green
        Write-Host "  WinRM is accessible via HTTP." -ForegroundColor Green
        Write-Host "  Protocol Version: $($wsmanResult.ProductVersion)" -ForegroundColor Green
        Write-Host "  Product Vendor: $($wsmanResult.ProductVendor)" -ForegroundColor Green
        $httpSuccess = $true
    }
    catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red

        # Analyze the error
        if ($_.Exception.Message -like "*access is denied*") {
            Write-Host "  Reason: Authentication failed or insufficient permissions." -ForegroundColor Red
        }
        elseif ($_.Exception.Message -like "*2150859046*") {
            Write-Host "  Reason: Authentication method mismatch or configuration issue." -ForegroundColor Red
            Write-Host "  The server may require Kerberos authentication or specific auth settings." -ForegroundColor Yellow
        }
        elseif ($_.Exception.Message -like "*timeout*") {
            Write-Host "  Reason: Connection timeout - server may be slow or overloaded." -ForegroundColor Red
        }
        else {
            Write-Host "  Reason: Unknown error - see error message above." -ForegroundColor Red
        }
        $httpSuccess = $false
    }
}
else {
    Write-Host "  Skipped - Port 5985 is not accessible." -ForegroundColor Yellow
    $httpSuccess = $false
}

# Step 6: WinRM Service Test via Test-WSMan (HTTPS)
Write-Host "`n[TEST 6] WinRM Service Test - HTTPS (Port 5986)" -ForegroundColor Yellow
if ($port5986Open) {
    Write-Host "  Attempting Test-WSMan on HTTPS..." -NoNewline
    try {
        $wsmanResult = Test-WSMan -ComputerName $ComputerName -UseSSL -ErrorAction Stop
        Write-Host " [SUCCESS]" -ForegroundColor Green
        Write-Host "  WinRM is accessible via HTTPS." -ForegroundColor Green
        Write-Host "  Protocol Version: $($wsmanResult.ProductVersion)" -ForegroundColor Green
        Write-Host "  Product Vendor: $($wsmanResult.ProductVendor)" -ForegroundColor Green
        $httpsSuccess = $true
    }
    catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red

        # Analyze the error
        if ($_.Exception.Message -like "*certificate*") {
            Write-Host "  Reason: SSL certificate validation failed." -ForegroundColor Red
            Write-Host "  Try running with -SkipCertificateCheck parameter." -ForegroundColor Yellow
        }
        elseif ($_.Exception.Message -like "*access is denied*") {
            Write-Host "  Reason: Authentication failed or insufficient permissions." -ForegroundColor Red
        }
        else {
            Write-Host "  Reason: Unknown error - see error message above." -ForegroundColor Red
        }
        $httpsSuccess = $false
    }
}
else {
    Write-Host "  Skipped - Port 5986 is not accessible." -ForegroundColor Yellow
    $httpsSuccess = $false
}

# Step 7: Authentication Methods Test
Write-Host "`n[TEST 7] Available Authentication Methods" -ForegroundColor Yellow
if ($httpSuccess -or $httpsSuccess) {
    Write-Host "  Checking server authentication configuration..." -ForegroundColor White
    try {
        $session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop
        $authMethods = Invoke-Command -Session $session -ScriptBlock {
            Get-Item WSMan:\localhost\Service\Auth\* | Select-Object Name, Value
        } -ErrorAction Stop

        Write-Host "  Available authentication methods on ${ComputerName}:" -ForegroundColor Green
        foreach ($method in $authMethods) {
            $status = if ($method.Value -eq "true") { "[ENABLED]" } else { "[DISABLED]" }
            $color = if ($method.Value -eq "true") { "Green" } else { "Red" }
            Write-Host "    $($method.Name): $status" -ForegroundColor $color
        }
        Remove-PSSession -Session $session
    }
    catch {
        Write-Host "  Could not retrieve authentication methods." -ForegroundColor Yellow
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "  Skipped - WinRM is not accessible." -ForegroundColor Yellow
}

# Restore certificate validation
if ($SkipCertificateCheck) {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCertValidation
}

# Final Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($httpSuccess -or $httpsSuccess) {
    Write-Host "Result: WinRM is ENABLED and ACCESSIBLE" -ForegroundColor Green
    if ($httpSuccess) {
        Write-Host "  - HTTP (5985): Working" -ForegroundColor Green
    }
    if ($httpsSuccess) {
        Write-Host "  - HTTPS (5986): Working" -ForegroundColor Green
    }
}
else {
    Write-Host "Result: WinRM is NOT ACCESSIBLE" -ForegroundColor Red
    Write-Host "`nPossible reasons:" -ForegroundColor Yellow
    Write-Host "  1. Windows Firewall is blocking WinRM ports on the server" -ForegroundColor Yellow
    Write-Host "  2. Network firewall between client and server is blocking ports" -ForegroundColor Yellow
    Write-Host "  3. WinRM service is not running on the server" -ForegroundColor Yellow
    Write-Host "  4. WinRM listener is not configured" -ForegroundColor Yellow
    Write-Host "  5. Server is in a different network segment with restricted access" -ForegroundColor Yellow

    Write-Host "`nRecommended actions ON THE SERVER:" -ForegroundColor Yellow
    Write-Host "  1. Check if WinRM is running: Get-Service WinRM" -ForegroundColor White
    Write-Host "  2. Check WinRM listeners: winrm enumerate winrm/config/listener" -ForegroundColor White
    Write-Host "  3. Check firewall rule status: Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' | Select-Object Name,Enabled,Profile" -ForegroundColor White
    Write-Host "  4. Enable firewall rule if disabled: Enable-NetFirewallRule -Name 'WINRM-HTTP-In-TCP'" -ForegroundColor White
    Write-Host "  5. If listener is missing, run: winrm quickconfig" -ForegroundColor White
    Write-Host "  6. Test locally on server: Test-WSMan -ComputerName localhost" -ForegroundColor White
    Write-Host "`n  Note: If all above checks pass on the server, check network firewall rules." -ForegroundColor Cyan
}

Write-Host "========================================`n" -ForegroundColor Cyan
