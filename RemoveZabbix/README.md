# Zabbix Agent Uninstallation Script

## Overview
The `RemoveZabbix.ps1` PowerShell script automates the uninstallation of the Zabbix agent on Windows systems. It performs the following tasks:
- Stops the "Zabbix Agent" service if it is running.
- Uninstalls the Zabbix agent by executing `zabbix_agentd.exe --uninstall`.
- Deletes the `C:\ProgramData\zabbix_agent` folder and its contents.
- Logs all actions, including the computer name and timestamp, to a network share at `<Path>\Zabbix\zabbixRemoval.log`.

The script includes robust error handling to ensure the folder is deleted even if the service or program is already uninstalled, logging warnings for non-critical failures and throwing errors only for critical issues (e.g., failure to access the log path or delete the folder).

## Requirements
- **Operating System**: Windows (PowerShell 5.1 or later recommended).
- **Permissions**:
  - Administrative privileges to stop services, uninstall the Zabbix agent, and delete files in `C:\ProgramData`.
  - Write access to the network share `<Path>\Zabbix\zabbixRemoval.log` for logging.
- **Zabbix Installation**: The script assumes the Zabbix agent is installed at `C:\ProgramData\zabbix_agent\bin\zabbix_agentd.exe` and the folder to delete is `C:\ProgramData\zabbix_agent`.
- **PowerShell Execution Policy**: The execution policy must allow script execution (e.g., `Bypass` or `RemoteSigned`).

## Usage
1. **Save the Script**:
   - Save the script as `RemoveZabbix.ps1` in a local directory.

2. **Run the Script**:
   - Open PowerShell as an administrator:
     - Right-click PowerShell and select "Run as administrator."
   - Navigate to the script directory and execute:
     ```powershell
     .\RemoveZabbix.ps1
     ```
   - Alternatively, bypass the execution policy:
     ```powershell
     powershell -ExecutionPolicy Bypass -File RemoveZabbix.ps1
     ```

3. **Expected Behavior**:
   - The script checks if the "Zabbix Agent" service is running and stops it if necessary.
   - Attempts to uninstall the Zabbix agent using `zabbix_agentd.exe --uninstall`.
   - Deletes the `C:\ProgramData\zabbix_agent` folder and its contents.
   - Logs all actions (success, warnings, or errors) to `<Path>\Zabbix\zabbixRemoval.log`.
   - Continues folder deletion even if the service or program is already uninstalled.

## Script Details
- **Paths**:
  - Zabbix executable: `C:\ProgramData\zabbix_agent\bin\zabbix_agentd.exe`
  - Zabbix folder: `C:\ProgramData\zabbix_agent`
  - Log file: `<Path>\Zabbix\zabbixRemoval.log`
  - Service name: `Zabbix Agent`
- **Error Handling**:
  - Uses separate `try-catch` blocks for stopping the service and uninstalling the agent, allowing folder deletion to proceed even if these steps fail (e.g., service not found or program already uninstalled).
  - Throws errors for critical failures (e.g., inaccessible log path, failure to create log file, or failure to delete the folder).
  - Logs warnings for non-critical issues (e.g., service not running, executable missing, uninstall failure).
- **Logging**:
  - Creates `zabbixRemoval.log` with a header if it doesn’t exist.
  - Appends each action with a timestamp and computer name.
  - Example log entry:
    ```
    [2025-10-02 11:30:23] COMPUTER_NAME: Service stopped successfully
    ```

## Log File Format
The log file (`zabbixRemoval.log`) is stored at `\<Path>\Zabbix` and follows this format:
```
Zabbix Removal Log
[2025-10-02 11:30:23] COMPUTER_NAME: Service stopped successfully
[2025-10-02 11:30:23] COMPUTER_NAME: Uninstalled successfully
[2025-10-02 11:30:23] COMPUTER_NAME: Folder deleted successfully
[2025-10-02 11:30:23] COMPUTER_NAME: Script completed successfully
```
For errors or warnings:
```
[2025-10-02 11:30:23] COMPUTER_NAME: Warning - Zabbix executable not found, assuming already uninstalled
[2025-10-02 11:30:23] COMPUTER_NAME: Error - Failed to delete folder: Access to the path is denied.
```

## Notes
- **Administrative Privileges**: The script requires administrative rights to stop services, uninstall the agent, and delete files in `C:\ProgramData`.
- **Network Share Access**: Ensure the user or service account has write permissions to the network share. If access fails, the script will exit early with an error.
- **Service Name**: The script assumes the service name is "Zabbix Agent". If the service name differs, update the `$serviceName` variable in the script.
- **Folder Path**: The script targets `C:\ProgramData\zabbix_agent` for deletion. If the Zabbix folder is elsewhere, update the `$zabbixFolder` variable.
- **Locked Files**: If folder deletion fails due to locked files, ensure no processes are using Zabbix files. The script stops the service to minimize this risk, but manual checks (e.g., using Process Explorer) may be needed.
- **Execution Policy**: If PowerShell blocks script execution, set the execution policy:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
  ```
- **Customization**: To modify paths, service names, or add features (e.g., retry logic for folder deletion), edit the script variables or logic as needed.

## Troubleshooting
- **Service Not Found**: If the "Zabbix Agent" service is missing, the script logs a warning and continues.
- **Executable Not Found**: If `zabbix_agentd.exe` is missing, the script assumes the agent is already uninstalled and proceeds to folder deletion.
- **Folder Deletion Fails**: Check for file locks or insufficient permissions. Use tools like Process Explorer to identify locking processes.
- **Network Share Errors**: Verify network connectivity and permissions to `<Path>\Zabbix`.

Feel free to use or modify the script
Trond Hoiberg 2 october 2025.