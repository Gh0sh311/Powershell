# Zabbix Agent Uninstallation Scripts

## Overview
This collection provides PowerShell scripts to automate the uninstallation of the Zabbix agent across Windows systems in an Active Directory environment.

### Scripts Included:
1. **RemoveZabbix.ps1** - Core uninstallation script that runs on each target server
2. **PSRemoteRemoveZabbix.ps1** - Orchestrates remote execution across multiple AD servers
3. **CollectZabbixLogs.ps1** - Consolidates removal logs from all servers

### RemoveZabbix.ps1
The core script performs the following tasks:
- Stops the "Zabbix Agent" service if it is running
- Uninstalls the Zabbix agent by executing `zabbix_agentd.exe --uninstall`
- Verifies service removal after uninstall
- Deletes the `C:\ProgramData\zabbix_agent` folder and its contents with retry logic
- Logs all actions locally to `C:\Temp\zabbixRemoval.log`

The script includes robust error handling to ensure the folder is deleted even if the service or program is already uninstalled, logging warnings for non-critical failures and throwing errors only for critical issues.

## Requirements
- **Operating System**: Windows (PowerShell 5.1 or later recommended)
- **Active Directory Module**: Required for PSRemoteRemoveZabbix.ps1 and CollectZabbixLogs.ps1
- **Permissions**:
  - Administrative privileges to stop services, uninstall the Zabbix agent, and delete files in `C:\ProgramData`
  - Domain admin credentials for remote execution
  - WinRM must be enabled on target servers
- **Zabbix Installation**: The script assumes the Zabbix agent is installed at `C:\ProgramData\zabbix_agent\bin\zabbix_agentd.exe` and the folder to delete is `C:\ProgramData\zabbix_agent`
- **PowerShell Execution Policy**: The execution policy must allow script execution (e.g., `Bypass` or `RemoteSigned`)

## Usage

### Option 1: Remote Execution Across Multiple Servers (Recommended)

1. **Run PSRemoteRemoveZabbix.ps1**:
   ```powershell
   .\PSRemoteRemoveZabbix.ps1 -Credential (Get-Credential)
   ```
   - Queries Active Directory for all Windows servers
   - Tests WinRM connectivity on each server
   - Executes RemoveZabbix.ps1 remotely on accessible servers
   - Logs results to `C:\Temp\ScriptExecutionLog.txt`

2. **Collect Logs from All Servers**:
   ```powershell
   .\CollectZabbixLogs.ps1 -OutputPath "\\server\share\ConsolidatedRemovalLog.log" -Credential (Get-Credential)
   ```
   - Gathers local logs from all servers
   - Consolidates into a single centralized log file
   - Shows summary of successful collections

### Option 2: Manual Single Server Execution

1. **Save the Script**:
   - Save `RemoveZabbix.ps1` to a network share or local directory

2. **Run the Script**:
   - Open PowerShell as an administrator
   - Navigate to the script directory and execute:
     ```powershell
     .\RemoveZabbix.ps1
     ```
   - Or bypass the execution policy:
     ```powershell
     powershell -ExecutionPolicy Bypass -File RemoveZabbix.ps1
     ```

3. **Expected Behavior**:
   - Checks if the "Zabbix Agent" service is running and stops it if necessary
   - Attempts to uninstall the Zabbix agent using `zabbix_agentd.exe --uninstall`
   - Verifies service removal from system
   - Deletes the `C:\ProgramData\zabbix_agent` folder with retry logic (3 attempts)
   - Logs all actions (success, warnings, or errors) to `C:\Temp\zabbixRemoval.log`
   - Continues folder deletion even if the service or program is already uninstalled

## Script Details

### RemoveZabbix.ps1
- **Paths**:
  - Zabbix executable: `C:\ProgramData\zabbix_agent\bin\zabbix_agentd.exe`
  - Zabbix folder: `C:\ProgramData\zabbix_agent`
  - Log file: `C:\Temp\zabbixRemoval.log`
  - Service name: `Zabbix Agent`
- **Error Handling**:
  - Uses separate `try-catch` blocks for stopping the service and uninstalling the agent
  - Implements retry logic for folder deletion (3 attempts with 2-second delays)
  - Verifies service removal after uninstall
  - Throws errors for critical failures
  - Logs warnings for non-critical issues
- **Logging**:
  - Creates `zabbixRemoval.log` locally if it doesn't exist
  - Appends each action with dynamic timestamp and computer name
  - Example log entry:
    ```
    [2025-10-06 11:30:23] COMPUTER_NAME: Service stopped successfully
    ```

### PSRemoteRemoveZabbix.ps1
- **Features**:
  - Queries Active Directory for all Windows servers
  - Parallel execution (default: 10 threads)
  - WinRM connectivity validation
  - One-time execution flag to prevent re-runs
  - Comprehensive logging and progress tracking
  - CredSSP authentication support for network share access
- **Parameters**:
  - `-Credential`: Domain admin credentials
  - `-SearchBase`: Limit to specific OU
  - `-MaxThreads`: Control parallelization (1-50)
  - `-TimeoutSeconds`: Execution timeout per server

### CollectZabbixLogs.ps1
- **Features**:
  - Collects logs from all servers via admin shares (`\\server\C$\Temp`)
  - Consolidates into single centralized log file
  - Provides collection summary
  - No WinRM required (uses file share access)

## Log File Format

### Individual Server Logs (C:\Temp\zabbixRemoval.log)
```
=== Zabbix Removal Log ===

--- New Entry ---
[2025-10-06 11:30:23] SERVER01: Service stopped successfully
[2025-10-06 11:30:23] SERVER01: Uninstalled successfully
[2025-10-06 11:30:24] SERVER01: Service removal verified
[2025-10-06 11:30:24] SERVER01: Folder deleted successfully
[2025-10-06 11:30:24] SERVER01: Script completed successfully
```

For errors or warnings:
```
[2025-10-06 11:30:23] SERVER02: Warning - Zabbix executable not found, assuming already uninstalled
[2025-10-06 11:30:23] SERVER02: Warning - Deletion attempt 1 failed, retrying
[2025-10-06 11:30:25] SERVER02: Folder deleted successfully
```

### Consolidated Log (from CollectZabbixLogs.ps1)
```
========================================
Consolidated Zabbix Removal Log
Collected: 2025-10-06 17:30:00
Total Servers: 100
========================================

========== SERVER01 ==========
[2025-10-06 11:30:23] SERVER01: Service stopped successfully
[2025-10-06 11:30:23] SERVER01: Uninstalled successfully
...

========== SERVER02 ==========
[2025-10-06 11:32:15] SERVER02: Service stopped successfully
...
```

## Notes
- **Administrative Privileges**: Scripts require administrative rights to stop services, uninstall agents, and delete files in `C:\ProgramData`
- **WinRM Requirements**: Target servers must have WinRM enabled for PSRemoteRemoveZabbix.ps1
- **Double-Hop Authentication**: Local logging avoids credential delegation issues; use CollectZabbixLogs.ps1 to consolidate logs afterward
- **Service Name**: Scripts assume service name is "Zabbix Agent". Update `$serviceName` variable if different
- **Folder Path**: Scripts target `C:\ProgramData\zabbix_agent`. Update `$zabbixFolder` variable if installed elsewhere
- **Retry Logic**: RemoveZabbix.ps1 includes 3 retry attempts for folder deletion to handle file locks
- **One-Time Execution**: PSRemoteRemoveZabbix.ps1 uses flag file (`C:\Temp\RemoveZabbix_Executed.txt`) to prevent re-execution
- **Execution Policy**: If PowerShell blocks script execution, set the execution policy:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
  ```
- **Customization**: Modify script variables for different paths, service names, or behavior

## Troubleshooting

### Common Issues

**Access Denied Errors with PSRemoteRemoveZabbix.ps1**
- Ensure you're using domain admin credentials
- Scripts now use local logging to avoid double-hop authentication issues
- CredSSP is supported but optional (requires additional configuration)

**WinRM Not Available**
- Enable WinRM on target servers: `Enable-PSRemoting -Force`
- Check firewall rules allow WinRM (ports 5985/5986)
- Verify with: `Test-WSMan -ComputerName SERVERNAME`

**Service Not Found**
- Script logs warning and continues to folder deletion
- Not a critical error

**Executable Not Found**
- Script assumes agent already uninstalled
- Proceeds to folder deletion

**Folder Deletion Fails**
- Retry logic (3 attempts) handles temporary file locks
- Check for processes using Zabbix files with Process Explorer
- Verify administrative permissions

**Log Collection Fails**
- Ensure admin shares are enabled (`\\server\C$`)
- Verify credentials have access to target servers
- Check firewall allows SMB (port 445)

## Author
Trond Hoiberg

## License
These scripts are free to use, copy, and modify without restriction.

## Version History
- **2025-10-06**: Added PSRemoteRemoveZabbix.ps1 and CollectZabbixLogs.ps1 for enterprise deployment
  - Implemented local logging to avoid double-hop authentication
  - Added retry logic for folder deletion
  - Added service verification after uninstall
  - Added CredSSP support option
- **2025-10-02**: Initial RemoveZabbix.ps1 release