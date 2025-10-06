# Define variables for paths and service name
# Adjust the $logPath variable to point to your desired log file location
# Zabbix can be installed in c:\Program Files (default), so verify where it is installed in your environment
$zabbixBinPath = "C:\ProgramData\zabbix_agent\bin"
$zabbixExe = Join-Path -Path $zabbixBinPath -ChildPath "zabbix_agentd.exe"
$zabbixFolder = "C:\ProgramData\zabbix_agent"
$logPath = "<Path to where you want to save log>\Zabbix"
$logFile = Join-Path -Path $logPath -ChildPath "zabbixRemoval.log"
$serviceName = "Zabbix Agent"

# Get computer name and current timestamp
$computerName = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Function to write to log file
function Write-Log {
    param (
        [string]$Message
    )
    $logMessage = "[$timestamp] $computerName`: $Message"
    Add-Content -Path $logFile -Value $logMessage -ErrorAction Stop
}

try {
    # Check if the log path is accessible
    Write-Host "Checking access to log path $logPath..."
    if (-not (Test-Path $logPath)) {
        throw "Cannot access log path $logPath. Check network connectivity or permissions."
    }

    # Check if the log file exists, create it if it doesn't
    if (-not (Test-Path $logFile)) {
        Write-Host "Creating new log file at $logFile..."
        Set-Content -Path $logFile -Value "Zabbix Removal Log" -ErrorAction Stop
        Write-Log "Log file created"
    }

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

    # Attempt to delete the Zabbix folder
    try {
        Write-Host "Checking for Zabbix folder at $zabbixFolder..."
        if (-not (Test-Path $zabbixFolder)) {
            Write-Host "Warning: Zabbix folder not found at $zabbixFolder. No deletion needed."
            Write-Log "No folder to delete"
        } else {
            Write-Host "Deleting Zabbix folder and its contents..."
            Remove-Item -Path $zabbixFolder -Recurse -Force -ErrorAction Stop
            Write-Host "Zabbix folder deleted successfully."
            Write-Log "Folder deleted successfully"
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