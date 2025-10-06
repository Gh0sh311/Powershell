# PSRemoteRemoveZabbix.ps1

## Overview

A PowerShell script that remotely executes the Zabbix removal script across multiple Windows servers in Active Directory. Features parallel execution, robust error handling, WinRM validation, and comprehensive logging.

## Author

Trond Hoiberg

## License

Free to use, copy, and modify without restriction.

## Requirements

- PowerShell 5.1 or later
- Administrator privileges
- Active Directory PowerShell module (RSAT)
- WinRM configured on target servers
- Network connectivity to target servers

## Features

- **Active Directory Integration**: Automatically discovers servers from AD
- **Parallel Execution**: Processes multiple servers simultaneously (configurable threads)
- **One-Time Execution**: Prevents duplicate runs on the same server using flag files
- **Comprehensive Logging**: Detailed execution log with timestamps and status
- **Error Handling**: Robust validation and error recovery
- **WinRM Validation**: Pre-checks WinRM availability before execution
- **Credential Support**: Optional credential parameter for remote authentication
- **WhatIf Support**: Simulate execution without making changes
- **Progress Tracking**: Real-time progress updates during execution
- **RSAT Auto-Install**: Offers to install Active Directory module if missing

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ScriptPath` | string | `\\sorcogruppen.no\dfs\Software\Media\SCCM\_ITIM-Transit\Zabbix\RemoveZabbix.ps1` | Path to the RemoveZabbix.ps1 script |
| `LogFile` | string | `C:\Temp\ScriptExecutionLog.txt` | Path to the execution log file |
| `Credential` | PSCredential | Current user | Credentials for remote authentication |
| `SearchBase` | string | Entire domain | AD organizational unit to limit server scope |
| `Filter` | string | `OperatingSystem -like "*Server*"` | Custom AD filter for server selection |
| `MaxThreads` | int | 10 | Maximum number of parallel executions (1-50) |
| `TimeoutSeconds` | int | 300 | Timeout for remote execution in seconds |
| `WhatIf` | switch | - | Simulates execution without making changes |

## Usage Examples

### Basic Execution (Current User Context)
```powershell
.\PSRemoteRemoveZabbix.ps1
```

### Execute with Credentials
```powershell
$cred = Get-Credential
.\PSRemoteRemoveZabbix.ps1 -Credential $cred
```

### Simulate Execution (WhatIf Mode)
```powershell
.\PSRemoteRemoveZabbix.ps1 -Credential (Get-Credential) -WhatIf
```

### Target Specific OU with Custom Thread Count
```powershell
.\PSRemoteRemoveZabbix.ps1 -SearchBase "OU=Servers,DC=domain,DC=com" -MaxThreads 5
```

### Custom Script Path and Log Location
```powershell
.\PSRemoteRemoveZabbix.ps1 -ScriptPath "C:\Scripts\RemoveZabbix.ps1" -LogFile "D:\Logs\ZabbixRemoval.log"
```

### Execute with Longer Timeout
```powershell
.\PSRemoteRemoveZabbix.ps1 -TimeoutSeconds 600 -MaxThreads 15
```

## Execution Flow

1. **Validation Phase**
   - Checks for Active Directory module (offers installation if missing)
   - Validates script path accessibility
   - Creates log directory if needed

2. **Discovery Phase**
   - Queries Active Directory for target servers
   - Applies filters and search base constraints
   - Displays server count

3. **Execution Phase**
   - Tests WinRM availability on each server
   - Tests network connectivity
   - Executes removal script in parallel (respecting MaxThreads limit)
   - Tracks execution status in real-time

4. **Reporting Phase**
   - Displays execution summary
   - Generates detailed log file
   - Returns exit code (0 = success, 1 = failures occurred)

## Remote Execution Behavior

On each target server, the script:

1. Creates `C:\Temp` directory if it doesn't exist
2. Checks for flag file `C:\Temp\RemoveZabbix_Executed.txt`
3. If flag exists, skips execution (already run)
4. If flag doesn't exist:
   - Validates script accessibility
   - Executes RemoveZabbix.ps1
   - Creates flag file with execution timestamp
   - Returns execution status

## Log File Format

```
========================================
Script Execution Log
Started: 2025-01-15 14:30:22
Script Path: \\server\share\RemoveZabbix.ps1
Target Servers: 45
Max Threads: 10
WhatIf Mode: False
========================================
[14:30:25] SERVER01 : SUCCESS - Script executed successfully
[14:30:26] SERVER02 : SKIPPED - Already executed on 2025-01-10 09:15:33
[14:30:27] SERVER03 : FAILED - Script not accessible
[14:30:28] SERVER04 : Offline or unreachable
[14:30:29] SERVER05 : WinRM not available or not configured
...
========================================
EXECUTION SUMMARY
========================================
Completed: 2025-01-15 14:45:18
Total Servers: 45
Successful: 38
Already Executed: 3
Failed: 2
Offline: 1
No WinRM: 1
========================================
```

## Exit Codes

- `0`: All executions successful (or already executed)
- `1`: One or more failures occurred

## Troubleshooting

### Active Directory Module Not Found
The script automatically detects your operating system and offers to install RSAT using the appropriate method:

- **Windows Server**: Uses `Install-WindowsFeature -Name RSAT-AD-PowerShell`
- **Windows 10/11 (build 17763+)**: Uses `Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"`
- **Older Windows versions**: Provides manual installation instructions

**Important**: After RSAT installation, you must close all PowerShell windows and open a new elevated session before running the script again.

**Manual Installation**:

For Windows Server:
```powershell
Install-WindowsFeature -Name RSAT-AD-PowerShell
```

For Windows 10/11:
```powershell
Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
```

### WinRM Not Available
Enable WinRM on target servers:
```powershell
Enable-PSRemoting -Force
```

### Access Denied Errors
Use the `-Credential` parameter with appropriate domain admin credentials.

### Script Path Not Accessible
Ensure the target servers can access the UNC path. Verify network shares and permissions.

### Timeout Issues
Increase the timeout for slow networks or large installations:
```powershell
.\PSRemoteRemoveZabbix.ps1 -TimeoutSeconds 600
```

## Security Considerations

- Requires administrator privileges on both local and remote systems
- Uses Windows Remote Management (WinRM) for remote execution
- Supports credential-based authentication
- Flag file prevents accidental re-execution
- Logs all activities for audit purposes

## Performance Tuning

- **Small Environments (< 20 servers)**: Use default MaxThreads (10)
- **Medium Environments (20-100 servers)**: Increase to 15-20 threads
- **Large Environments (> 100 servers)**: Use 20-30 threads (monitor system resources)
- **Slow Networks**: Reduce threads and increase timeout

## Related Files

- `RemoveZabbix.ps1`: The actual Zabbix removal script executed on target servers
- `ScriptExecutionLog.txt`: Detailed execution log (default location)
