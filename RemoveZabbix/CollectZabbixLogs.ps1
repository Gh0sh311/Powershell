<#
.SYNOPSIS
    Collects Zabbix removal logs from all servers to a central network share.

.DESCRIPTION
    Retrieves C:\Temp\zabbixRemoval.log from each server and consolidates them
    into a single log file on a network share.

.AUTHOR
    Trond Hoiberg

.LICENSE
    This script is free to use, copy, and modify without restriction.

.PARAMETER OutputPath
    Path to the centralized log file on network share.

.PARAMETER Credential
    PSCredential object for remote authentication.

.PARAMETER SearchBase
    AD search base (OU) to limit server scope.

.EXAMPLE
    .\CollectZabbixLogs.ps1 -OutputPath "\\server\share\Logs\ConsolidatedZabbixRemoval.log" -Credential (Get-Credential)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,

    [PSCredential]$Credential,

    [string]$SearchBase,

    [string]$Filter = 'OperatingSystem -like "*Server*"'
)

#Requires -Version 5.1
#Requires -Module ActiveDirectory

# Get servers from Active Directory
try {
    $adParams = @{
        Filter = [scriptblock]::Create($Filter)
        Properties = 'OperatingSystem'
    }

    if ($SearchBase) {
        $adParams['SearchBase'] = $SearchBase
    }

    $servers = Get-ADComputer @adParams |
        Select-Object -ExpandProperty Name |
        Sort-Object

    if (-not $servers) {
        Write-Warning "No servers found matching filter: $Filter"
        exit 0
    }

    Write-Host "Found $($servers.Count) server(s) to collect logs from" -ForegroundColor Cyan
} catch {
    Write-Error "Failed to query Active Directory: $_"
    exit 1
}

# Initialize consolidated log
$header = @"
========================================
Consolidated Zabbix Removal Log
Collected: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Total Servers: $($servers.Count)
========================================

"@
Set-Content -Path $OutputPath -Value $header -Force

$collected = 0
$notFound = 0

# Collect logs from each server
foreach ($server in $servers) {
    Write-Progress -Activity "Collecting Zabbix Removal Logs" `
        -Status "Processing $server" `
        -PercentComplete (($collected + $notFound) / $servers.Count * 100)

    try {
        $remotePath = "\\$server\C$\Temp\zabbixRemoval.log"

        if (Test-Path $remotePath) {
            $logContent = Get-Content -Path $remotePath -ErrorAction Stop

            # Add server header
            Add-Content -Path $OutputPath -Value "`n========== $server =========="
            Add-Content -Path $OutputPath -Value $logContent

            $collected++
            Write-Host "[OK] $server - Log collected" -ForegroundColor Green
        } else {
            $notFound++
            Write-Host "[SKIP] $server - Log file not found" -ForegroundColor Yellow
        }
    } catch {
        $notFound++
        Write-Host "[ERROR] $server - Failed to collect: $_" -ForegroundColor Red
    }
}

Write-Progress -Activity "Collecting Zabbix Removal Logs" -Completed

# Summary
$summary = @"

========================================
COLLECTION SUMMARY
========================================
Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Total Servers: $($servers.Count)
Logs Collected: $collected
Not Found/Failed: $notFound
========================================
"@

Add-Content -Path $OutputPath -Value $summary
Write-Host $summary -ForegroundColor Cyan
Write-Host "`nConsolidated log saved to: $OutputPath" -ForegroundColor Green
