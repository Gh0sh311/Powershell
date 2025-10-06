<#
.SYNOPSIS
    Remotely executes the Zabbix removal script on Active Directory servers.

.DESCRIPTION
    This script connects to Windows servers in Active Directory and executes a Zabbix removal script.
    Includes robust error handling, credential support, WinRM validation, and progress tracking.

.AUTHOR
    Trond Hoiberg

.LICENSE
    This script is free to use, copy, and modify without restriction.

.PARAMETER ScriptPath
    Path to the RemoveZabbix.ps1 script. Defaults to the DFS share location.

.PARAMETER LogFile
    Path to the log file. Defaults to C:\Temp\ScriptExecutionLog.txt

.PARAMETER Credential
    PSCredential object for remote authentication. If not provided, uses current user context.

.PARAMETER SearchBase
    AD search base (OU) to limit server scope. If not provided, searches entire domain.

.PARAMETER Filter
    Custom AD filter. Defaults to servers with "Server" in OperatingSystem.

.PARAMETER MaxThreads
    Maximum parallel executions. Defaults to 10.

.PARAMETER WhatIf
    Simulates execution without making changes.

.EXAMPLE
    .\PSRemoteRemoveZabbix.ps1 -Credential (Get-Credential) -WhatIf

.EXAMPLE
    .\PSRemoteRemoveZabbix.ps1 -SearchBase "OU=Servers,DC=domain,DC=com" -MaxThreads 5
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScriptPath = "\\server\share\Zabbix\RemoveZabbix.ps1",

    [string]$LogFile = "C:\Temp\ScriptExecutionLog.txt",

    [PSCredential]$Credential,

    [string]$SearchBase,

    [string]$Filter = 'OperatingSystem -like "*Server*"',

    [ValidateRange(1, 50)]
    [int]$MaxThreads = 10,

    [int]$TimeoutSeconds = 300
)

# Requires statements
#Requires -Version 5.1
#Requires -RunAsAdministrator

# Check and install Active Directory module if missing
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Verbose "Active Directory module loaded successfully"
} catch {
    # Module not available - attempt installation
    Write-Warning "Active Directory module is not installed on this system."

    # Double-check by looking in common RSAT installation paths
    $rsatPaths = @(
        "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules\ActiveDirectory",
        "$env:ProgramFiles\WindowsPowerShell\Modules\ActiveDirectory"
    )

    $foundInPath = $false
    foreach ($path in $rsatPaths) {
        if (Test-Path $path) {
            Write-Host "Found ActiveDirectory module at: $path" -ForegroundColor Green
            $foundInPath = $true
            break
        }
    }

    if ($foundInPath) {
        Write-Host "Module found but not in PSModulePath. Attempting to import directly..." -ForegroundColor Yellow
        # Continue to import section
    } else {
        Write-Host "`nThe Active Directory module is required to run this script." -ForegroundColor Yellow
        Write-Host "This module is part of the Remote Server Administration Tools (RSAT)." -ForegroundColor Yellow

        $install = Read-Host "`nWould you like to attempt to install it now? (Y/N)"

        if ($install -eq 'Y' -or $install -eq 'y') {
            try {
                Write-Host "`nAttempting to install RSAT Active Directory module..." -ForegroundColor Cyan

                # Check OS type and version
                $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
                $buildNumber = [int]$osInfo.BuildNumber
                $isServer = $osInfo.ProductType -ne 1  # ProductType: 1=Workstation, 2=Domain Controller, 3=Server

                if ($isServer) {
                    # Windows Server - use Install-WindowsFeature
                    Write-Host "Detected Windows Server. Installing via Windows Feature..." -ForegroundColor Cyan

                    # Check if already installed
                    $feature = Get-WindowsFeature -Name RSAT-AD-PowerShell -ErrorAction SilentlyContinue

                    if ($feature -and $feature.Installed) {
                        Write-Host "RSAT AD PowerShell tools are already installed. The module may require a system restart." -ForegroundColor Yellow
                        $restart = Read-Host "Would you like to restart your computer now? (Y/N)"
                        if ($restart -eq 'Y' -or $restart -eq 'y') {
                            Restart-Computer -Confirm
                        }
                        exit 0
                    }

                    Install-WindowsFeature -Name RSAT-AD-PowerShell -ErrorAction Stop
                    Write-Host "Active Directory module installed successfully!" -ForegroundColor Green
                    Write-Host "`nIMPORTANT: Please close all PowerShell windows and open a new session." -ForegroundColor Yellow
                    Write-Host "Then run the script again." -ForegroundColor Yellow
                    exit 0

                } elseif ($buildNumber -ge 17763) {
                    # Windows 10 1809+ or Windows 11 - use Windows Capability
                    Write-Host "Detected Windows 10/11. Installing via Windows Capability..." -ForegroundColor Cyan

                    # Check if already installed
                    $rsatInstalled = Get-WindowsCapability -Online | Where-Object {
                        $_.Name -like "Rsat.ActiveDirectory.DS-LDS.Tools*" -and $_.State -eq "Installed"
                    }

                    if ($rsatInstalled) {
                        Write-Host "RSAT AD tools are already installed. The module may require a system restart." -ForegroundColor Yellow
                        $restart = Read-Host "Would you like to restart your computer now? (Y/N)"
                        if ($restart -eq 'Y' -or $restart -eq 'y') {
                            Restart-Computer -Confirm
                        }
                        exit 0
                    }

                    Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ErrorAction Stop
                    Write-Host "Active Directory module installed successfully!" -ForegroundColor Green
                    Write-Host "`nIMPORTANT: Please restart your computer or at minimum close all PowerShell windows." -ForegroundColor Yellow
                    Write-Host "Then open a new PowerShell session and run the script again." -ForegroundColor Yellow
                    exit 0
                } else {
                    # Older Windows versions
                    Write-Host "For your Windows version, please install RSAT manually:" -ForegroundColor Yellow
                    Write-Host "1. Go to Settings > Apps > Optional Features" -ForegroundColor Yellow
                    Write-Host "2. Click 'Add a feature'" -ForegroundColor Yellow
                    Write-Host "3. Search for 'RSAT: Active Directory Domain Services'" -ForegroundColor Yellow
                    Write-Host "4. Install and restart this script" -ForegroundColor Yellow
                    exit 1
                }
            } catch {
                Write-Error "Failed to install Active Directory module: $_"
                Write-Host "`nPlease install RSAT manually:" -ForegroundColor Yellow

                if ($isServer) {
                    Write-Host "For Windows Server, run this command in an elevated PowerShell:" -ForegroundColor Cyan
                    Write-Host "Install-WindowsFeature -Name RSAT-AD-PowerShell" -ForegroundColor Cyan
                } else {
                    Write-Host "For Windows 10/11, run this command in an elevated PowerShell:" -ForegroundColor Cyan
                    Write-Host "Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'" -ForegroundColor Cyan
                }
                exit 1
            }
        } else {
            Write-Host "`nScript execution cancelled. Please install the Active Directory module and try again." -ForegroundColor Yellow
            exit 1
        }
    }
}

# Validate and create log directory
$logDir = Split-Path -Path $LogFile -Parent
if (-not (Test-Path $logDir)) {
    try {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        Write-Verbose "Created log directory: $logDir"
    } catch {
        Write-Error "Failed to create log directory '$logDir': $_"
        exit 1
    }
}

# Validate script path
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found at $ScriptPath. Please verify the path and try again."
    exit 1
}

Write-Host "Validating script path: $ScriptPath" -ForegroundColor Green

# Get servers from Active Directory
try {
    $adParams = @{
        Filter = [scriptblock]::Create($Filter)
        Properties = 'OperatingSystem', 'LastLogonDate'
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

    Write-Host "Found $($servers.Count) server(s) to process" -ForegroundColor Cyan
} catch {
    Write-Error "Failed to query Active Directory: $_"
    exit 1
}

# Initialize log with structured header
$logHeader = @"
========================================
Script Execution Log
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Script Path: $ScriptPath
Target Servers: $($servers.Count)
Max Threads: $MaxThreads
WhatIf Mode: $($WhatIfPreference.IsPresent)
========================================
"@
$logHeader | Out-File -FilePath $LogFile -Force

# Initialize counters
$stats = @{
    Total = $servers.Count
    Success = 0
    AlreadyExecuted = 0
    Failed = 0
    Offline = 0
    NoWinRM = 0
}

# Script block for remote execution
$scriptBlock = {
    param($RemoteScriptPath)

    $result = @{
        Status = 'Unknown'
        Message = ''
        Error = $null
    }

    try {
        # Ensure temp directory exists
        $tempDir = "C:\Temp"
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }

        # Check for one-time execution (using a flag file)
        $flagFile = Join-Path $tempDir "RemoveZabbix_Executed.txt"
        if (Test-Path $flagFile) {
            $result.Status = 'AlreadyExecuted'
            $result.Message = "Script already executed on $(Get-Content $flagFile -ErrorAction SilentlyContinue)"
            return $result
        }

        # Verify script is accessible
        if (-not (Test-Path $RemoteScriptPath)) {
            $result.Status = 'Failed'
            $result.Message = "Script not accessible at $RemoteScriptPath"
            return $result
        }

        # Execute the script
        $output = & $RemoteScriptPath 2>&1

        # Create flag file to prevent re-execution
        Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File -FilePath $flagFile -Force

        $result.Status = 'Success'
        $result.Message = "Script executed successfully. Output: $($output -join '; ')"

    } catch {
        $result.Status = 'Failed'
        $result.Error = $_.Exception.Message
        $result.Message = "Execution failed: $($_.Exception.Message)"
    }

    return $result
}

# Process servers with parallelization
Write-Host "`nProcessing servers..." -ForegroundColor Cyan

$jobs = @()
$completed = 0

foreach ($server in $servers) {
    # Wait if we've hit the max thread limit
    while ((Get-Job -State Running).Count -ge $MaxThreads) {
        Start-Sleep -Milliseconds 100

        # Check for completed jobs
        $finishedJobs = Get-Job -State Completed
        foreach ($job in $finishedJobs) {
            $completed++
            $percentComplete = [math]::Round(($completed / $stats.Total) * 100, 1)
            Write-Progress -Activity "Executing Zabbix Removal Script" `
                -Status "Processing $completed of $($stats.Total) servers ($percentComplete%)" `
                -PercentComplete $percentComplete

            Receive-Job -Job $job | Out-Null
            Remove-Job -Job $job
        }
    }

    # Test WinRM connectivity first
    try {
        $null = Test-WSMan -ComputerName $server -ErrorAction Stop
        $winRMAvailable = $true
    } catch {
        $winRMAvailable = $false
    }

    if (-not $winRMAvailable) {
        $stats.NoWinRM++
        $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $server : WinRM not available or not configured"
        $logEntry | Out-File -FilePath $LogFile -Append
        Write-Warning $logEntry
        continue
    }

    # Test basic connectivity
    if (-not (Test-Connection -ComputerName $server -Count 2 -Quiet)) {
        $stats.Offline++
        $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $server : Offline or unreachable"
        $logEntry | Out-File -FilePath $LogFile -Append
        Write-Warning $logEntry
        continue
    }

    # WhatIf support
    if ($PSCmdlet.ShouldProcess($server, "Execute Zabbix removal script")) {
        try {
            # Prepare Invoke-Command parameters with CredSSP for network share access
            $invokeParams = @{
                ComputerName = $server
                ScriptBlock = $scriptBlock
                ArgumentList = $ScriptPath
                ErrorAction = 'Stop'
                AsJob = $true
                JobName = "RemoveZabbix_$server"
                Authentication = 'Credssp'
            }

            if ($Credential) {
                $invokeParams['Credential'] = $Credential
            }

            if ($TimeoutSeconds -gt 0) {
                $invokeParams['SessionOption'] = (New-PSSessionOption -OperationTimeout ($TimeoutSeconds * 1000))
            }

            # Start the job
            $job = Invoke-Command @invokeParams
            $jobs += $job

        } catch {
            $stats.Failed++
            $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $server : Error starting job - $($_.Exception.Message)"
            $logEntry | Out-File -FilePath $LogFile -Append
            Write-Error $logEntry
        }
    } else {
        Write-Host "WhatIf: Would execute script on $server" -ForegroundColor Yellow
    }
}

# Wait for remaining jobs and process results
Write-Host "`nWaiting for remaining jobs to complete..." -ForegroundColor Cyan
$jobs | Wait-Job -Timeout $TimeoutSeconds | Out-Null

foreach ($job in $jobs) {
    $server = $job.Name -replace '^RemoveZabbix_', ''

    try {
        if ($job.State -eq 'Completed') {
            $result = Receive-Job -Job $job -ErrorAction Stop

            switch ($result.Status) {
                'Success' {
                    $stats.Success++
                    $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $server : SUCCESS - $($result.Message)"
                    Write-Host $logEntry -ForegroundColor Green
                }
                'AlreadyExecuted' {
                    $stats.AlreadyExecuted++
                    $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $server : SKIPPED - $($result.Message)"
                    Write-Host $logEntry -ForegroundColor Yellow
                }
                default {
                    $stats.Failed++
                    $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $server : FAILED - $($result.Message)"
                    Write-Host $logEntry -ForegroundColor Red
                }
            }

            $logEntry | Out-File -FilePath $LogFile -Append

        } elseif ($job.State -eq 'Failed') {
            $stats.Failed++
            $errorMsg = $job.ChildJobs[0].JobStateInfo.Reason.Message
            $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $server : FAILED - Job failed: $errorMsg"
            $logEntry | Out-File -FilePath $LogFile -Append
            Write-Error $logEntry
        } else {
            $stats.Failed++
            $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $server : TIMEOUT - Job did not complete within $TimeoutSeconds seconds"
            $logEntry | Out-File -FilePath $LogFile -Append
            Write-Warning $logEntry
            Stop-Job -Job $job
        }

    } catch {
        $stats.Failed++
        $logEntry = "[$(Get-Date -Format 'HH:mm:ss')] $server : ERROR - $($_.Exception.Message)"
        $logEntry | Out-File -FilePath $LogFile -Append
        Write-Error $logEntry
    } finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

Write-Progress -Activity "Executing Zabbix Removal Script" -Completed

# Generate summary
$summary = @"

========================================
EXECUTION SUMMARY
========================================
Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Total Servers: $($stats.Total)
Successful: $($stats.Success)
Already Executed: $($stats.AlreadyExecuted)
Failed: $($stats.Failed)
Offline: $($stats.Offline)
No WinRM: $($stats.NoWinRM)
========================================
"@

$summary | Out-File -FilePath $LogFile -Append
Write-Host $summary -ForegroundColor Cyan
Write-Host "`nDetailed log: $LogFile" -ForegroundColor Green

# Return exit code based on results
if ($stats.Failed -gt 0) {
    exit 1
} else {
    exit 0
}