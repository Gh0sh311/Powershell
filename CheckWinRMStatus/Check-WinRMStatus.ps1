<#
.SYNOPSIS
    Check WinRM status on all servers in a domain.

.DESCRIPTION
    This script queries Active Directory for all server computers and tests if WinRM is enabled and accessible on each server.

.EXAMPLE
    .\Check-WinRMStatus.ps1

.NOTES
    Requires Active Directory module and appropriate permissions.
    Made by Trond Hoiberg
#>

# Import Active Directory module
Import-Module ActiveDirectory -ErrorAction Stop

# Get all server computers from Active Directory
Write-Host "Retrieving all servers from Active Directory..." -ForegroundColor Cyan
try {
    $servers = Get-ADComputer -Filter {OperatingSystem -like "*Server*"} -Properties Name, OperatingSystem, DNSHostName |
               Select-Object Name, OperatingSystem, DNSHostName

    Write-Host "Found $($servers.Count) servers in the domain.`n" -ForegroundColor Green
}
catch {
    Write-Host "Error retrieving servers from Active Directory: $_" -ForegroundColor Red
    exit 1
}

# Initialize results array
$results = @()

# Test WinRM on each server
Write-Host "Testing WinRM connectivity on each server...`n" -ForegroundColor Cyan

foreach ($server in $servers) {
    Write-Host "Testing $($server.Name)..." -NoNewline

    $result = [PSCustomObject]@{
        ServerName      = $server.Name
        DNSHostName     = $server.DNSHostName
        OperatingSystem = $server.OperatingSystem
        WinRMEnabled    = $false
        WinRMPort       = "N/A"
        Status          = "Unknown"
        ErrorMessage    = ""
    }

    # Test WinRM using Test-WSMan
    try {
        $wsmanTest = Test-WSMan -ComputerName $server.DNSHostName -ErrorAction Stop

        if ($wsmanTest) {
            $result.WinRMEnabled = $true
            $result.Status = "Online"
            $result.WinRMPort = "5985 (HTTP)"
            Write-Host " [SUCCESS]" -ForegroundColor Green
        }
    }
    catch {
        # Try HTTPS port if HTTP fails
        try {
            $wsmanTest = Test-WSMan -ComputerName $server.DNSHostName -UseSSL -ErrorAction Stop
            $result.WinRMEnabled = $true
            $result.Status = "Online"
            $result.WinRMPort = "5986 (HTTPS)"
            Write-Host " [SUCCESS - HTTPS]" -ForegroundColor Green
        }
        catch {
            $result.WinRMEnabled = $false
            $result.Status = "Failed"
            $result.ErrorMessage = $_.Exception.Message
            Write-Host " [FAILED]" -ForegroundColor Red
        }
    }

    $results += $result
}

# Display summary
Write-Host "`n========== SUMMARY ==========" -ForegroundColor Cyan
$enabledCount = ($results | Where-Object { $_.WinRMEnabled -eq $true }).Count
$disabledCount = ($results | Where-Object { $_.WinRMEnabled -eq $false }).Count

Write-Host "Total Servers: $($results.Count)" -ForegroundColor White
Write-Host "WinRM Enabled: $enabledCount" -ForegroundColor Green
Write-Host "WinRM Disabled/Unreachable: $disabledCount" -ForegroundColor Red

# Display detailed results
Write-Host "`n========== DETAILED RESULTS ==========" -ForegroundColor Cyan
$results | Format-Table ServerName, WinRMEnabled, WinRMPort, Status, OperatingSystem -AutoSize

# Export results to CSV
$csvPath = ".\WinRM-Status-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "`nResults exported to: $csvPath" -ForegroundColor Yellow

# Create Results.txt file
$txtPath = ".\Results.txt"
$enabledServers = $results | Where-Object { $_.WinRMEnabled -eq $true }
$disabledServers = $results | Where-Object { $_.WinRMEnabled -eq $false }

# Build text file content
$txtContent = @()
$txtContent += "=========================================="
$txtContent += "WinRM Status Report"
$txtContent += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$txtContent += "=========================================="
$txtContent += ""
$txtContent += "SERVERS WITH WINRM ENABLED:"
$txtContent += "=========================================="
if ($enabledServers.Count -gt 0) {
    foreach ($server in $enabledServers) {
        $txtContent += "$($server.ServerName) - $($server.DNSHostName) - Port: $($server.WinRMPort)"
    }
} else {
    $txtContent += "None"
}
$txtContent += ""
$txtContent += "SERVERS WITH WINRM DISABLED/UNREACHABLE:"
$txtContent += "=========================================="
if ($disabledServers.Count -gt 0) {
    foreach ($server in $disabledServers) {
        $txtContent += "$($server.ServerName) - $($server.DNSHostName) - Error: $($server.ErrorMessage)"
    }
} else {
    $txtContent += "None"
}
$txtContent += ""
$txtContent += "=========================================="
$txtContent += "SUMMARY:"
$txtContent += "=========================================="
$txtContent += "Total servers with WinRM enabled: $enabledCount"
$txtContent += "Total servers with WinRM disabled/unreachable: $disabledCount"
$txtContent += "=========================================="

# Write to file
$txtContent | Out-File -FilePath $txtPath -Encoding UTF8
Write-Host "Text report exported to: $txtPath" -ForegroundColor Yellow

# Display results in GridView
Write-Host "`nDisplaying results in GridView..." -ForegroundColor Cyan
$results | Out-GridView -Title "WinRM Status Report - Total: $($results.Count) | Enabled: $enabledCount | Disabled: $disabledCount"

# Show servers where WinRM is disabled
if ($disabledServers.Count -gt 0) {
    Write-Host "`n========== SERVERS WITH WINRM DISABLED ==========" -ForegroundColor Yellow
    $disabledServers | Format-Table ServerName, DNSHostName, ErrorMessage -AutoSize
}
