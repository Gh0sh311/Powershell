# Define variables for paths and service name
# Logs locally to avoid double-hop authentication issues with network shares
# Zabbix can be installed in c:\Program Files (default), so verify where it is installed in your environment
$zabbixBinPath = "C:\ProgramData\zabbix_agent\bin"
$zabbixExe = Join-Path -Path $zabbixBinPath -ChildPath "zabbix_agentd.exe"
$zabbixFolder = "C:\ProgramData\zabbix_agent"
$localLogPath = "C:\Temp"
$logFile = Join-Path -Path $localLogPath -ChildPath "zabbixRemoval.log"
$serviceName = "Zabbix Agent"

# Get computer name
$computerName = $env:COMPUTERNAME

# Function to write to log file
function Write-Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $computerName`: $Message"
    Add-Content -Path $logFile -Value $logMessage -ErrorAction Stop
}

try {
    # Check if the local log directory is accessible
    Write-Host "Checking access to local log path $localLogPath..."
    if (-not (Test-Path $localLogPath)) {
        Write-Host "Creating local log directory..."
        New-Item -Path $localLogPath -ItemType Directory -Force | Out-Null
    }

    # Check if the log file exists, create it if it doesn't (otherwise append)
    if (-not (Test-Path $logFile)) {
        Write-Host "Creating new log file at $logFile..."
        Set-Content -Path $logFile -Value "=== Zabbix Removal Log ===" -ErrorAction Stop
        Write-Host "Log file created."
    } else {
        Write-Host "Log file exists. Appending removal log for $computerName..."
    }

    # Add separator for new server entry
    Add-Content -Path $logFile -Value "`n--- New Entry ---" -ErrorAction Stop

    # Attempt to stop the Zabbix Agent service
    try {
        Write-Host "Checking status of $serviceName service..."
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Write-Host "Stopping $serviceName service..."
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            Write-Log "Service stopped successfully"
        } else {
            Write-Host "$serviceName service is not running or does not exist."
            Write-Log "Service not running or does not exist"
        }
    }
    catch {
        Write-Host "Warning: Failed to stop $serviceName service: $_"
        Write-Log "Warning - Failed to stop service: $_"
        # Continue execution even if service stop fails
    }

    # Attempt to uninstall the Zabbix agent
    try {
        Write-Host "Checking for Zabbix executable at $zabbixExe..."
        if (-not (Test-Path $zabbixExe)) {
            Write-Host "Warning: Zabbix executable not found at $zabbixExe. Assuming already uninstalled."
            Write-Log "Warning - Zabbix executable not found, assuming already uninstalled"
        } else {
            Write-Host "Uninstalling Zabbix agent..."
            $process = Start-Process -FilePath $zabbixExe -ArgumentList "--uninstall" -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -eq 0) {
                Write-Host "Zabbix agent uninstalled successfully."
                Write-Log "Uninstalled successfully"

                # Verify service was removed
                Start-Sleep -Seconds 2
                $serviceCheck = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($serviceCheck) {
                    Write-Host "Warning: Service still exists after uninstall attempt."
                    Write-Log "Warning - Service still exists after uninstall"
                } else {
                    Write-Host "Verified: Service successfully removed from system."
                    Write-Log "Service removal verified"
                }
            } else {
                Write-Host "Warning: Failed to uninstall Zabbix agent. Exit code: $($process.ExitCode)"
                Write-Log "Warning - Failed to uninstall - Exit code $($process.ExitCode)"
            }
        }
    }
    catch {
        Write-Host "Warning: Failed to execute uninstall command: $_"
        Write-Log "Warning - Failed to execute uninstall: $_"
        # Continue execution even if uninstall fails
    }

    # Attempt to delete the Zabbix folder with retry logic
    try {
        Write-Host "Checking for Zabbix folder at $zabbixFolder..."
        if (-not (Test-Path $zabbixFolder)) {
            Write-Host "Warning: Zabbix folder not found at $zabbixFolder. No deletion needed."
            Write-Log "No folder to delete"
        } else {
            Write-Host "Deleting Zabbix folder and its contents..."
            $maxRetries = 3
            $retryCount = 0
            $deleted = $false

            while ($retryCount -lt $maxRetries -and -not $deleted) {
                try {
                    Remove-Item -Path $zabbixFolder -Recurse -Force -ErrorAction Stop
                    Write-Host "Zabbix folder deleted successfully."
                    Write-Log "Folder deleted successfully"
                    $deleted = $true
                }
                catch {
                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Write-Host "Warning: Deletion attempt $retryCount failed. Retrying in 2 seconds... ($_)"
                        Write-Log "Warning - Deletion attempt $retryCount failed, retrying"
                        Start-Sleep -Seconds 2
                    } else {
                        Write-Host "Error: Failed to delete Zabbix folder after $maxRetries attempts: $_"
                        Write-Log "Error - Failed to delete folder after $maxRetries attempts: $_"
                        throw "Failed to delete Zabbix folder after $maxRetries attempts: $_"
                    }
                }
            }
        }
    }
    catch {
        Write-Host "Error: Failed to delete Zabbix folder: $_"
        Write-Log "Error - Failed to delete folder: $_"
        throw "Failed to delete Zabbix folder: $_"
    }

    Write-Host "Script completed successfully."
    Write-Log "Script completed successfully"
}
catch {
    Write-Host "Error: $_"
    Write-Log "Error - $_"
    exit 1
}