# Domain Controller Security Event Monitor

A PowerShell GUI application that monitors all domain controllers in your Active Directory domain for critical security events in real-time.

Created by Trond Hoiberg.

## Overview

This tool provides a visual dashboard for monitoring security events across all domain controllers, with color-coded status indicators and detailed event information. It's designed for security administrators who need to quickly identify and respond to security-critical events.

## Features

- **Automatic DC Discovery** - Automatically detects all domain controllers in the current domain
- **Real-time Monitoring** - Continuously monitors Security event logs every 30 seconds
- **Per-Server Event ID Configuration** - Customize which Event IDs to monitor for each domain controller
- **Monitored IDs Display** - View all monitored Event IDs and custom configurations in the GUI
- **Visual Status Indicators**:
  - 🔴 Red: Active security alerts detected
  - 🟢 Green: No alerts, monitoring normally
  - 🟡 Yellow: Connection or query error
  - 🟠 Orange: Query timeout
  - ⚪ Gray: Initializing
- **Async Processing** - Non-blocking queries keep the GUI responsive
- **Event Details** - Displays full event information in a dedicated panel
- **Auto-cleanup** - Removes alerts older than 1 hour
- **Secure Credential Handling** - Uses PowerShell's secure credential system
- **Robust Error Handling** - Includes timeout protection and connection testing

## Monitored Event IDs

### Default Event IDs

By default, all domain controllers are monitored for these Event IDs:

| Event ID | Description |
|----------|-------------|
| 1102 | Audit log was cleared |
| 4719 | System audit policy was changed |
| 4765 | SID History was added to an account |
| 4766 | An attempt to add SID History to an account failed |
| 4794 | An attempt was made to set the Directory Services Restore Mode administrator password |
| 4897 | Role separation enabled |
| 4964 | Special groups have been assigned to a new logon |

### Customizing Event IDs

**Per-Server Configuration (GUI):**
1. Right-click on any domain controller in the list
2. Select "Configure Event IDs..."
3. Enter comma-separated Event IDs (e.g., `1102, 4720, 4728`)
4. Leave empty to revert to default IDs
5. Custom configurations are displayed in the "Monitored Event IDs" section

**Global Default (Code):**
Modify the `$script:DefaultEventIDs` array in line 22:
```powershell
$script:DefaultEventIDs = @(1102, 4719, 4765, 4766, 4794, 4897, 4964)
```

## Requirements

- **Windows PowerShell 5.1** (PowerShell Core/7.x is not supported due to WinRM authentication limitations with PSCredential serialization in background jobs)
- **Domain credentials** with permission to:
  - Query domain controllers
  - Access Security event logs on remote systems
- **WinRM** enabled on all domain controllers
- **.NET Framework** (for Windows Forms)

## Installation

1. Download `DCSecurityMonitor.ps1` to your local system
2. Ensure your execution policy allows running scripts:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Usage

### Basic Usage

1. Run the script:
   ```powershell
   .\DCSecurityMonitor.ps1
   ```

2. Enter domain credentials when prompted (must have appropriate permissions)

3. The GUI will open showing all domain controllers

4. Monitor the status indicators and event details panel

### Running from Different Location

```powershell
cd C:\Path\To\Script
.\DCSecurityMonitor.ps1
```

### Configuring Per-Server Event IDs

After the GUI opens, you can customize which Event IDs to monitor for specific servers:

1. **Right-click** on any domain controller in the list
2. Select **"Configure Event IDs..."** from the context menu
3. Enter Event IDs as comma-separated values (e.g., `1102, 4720, 4728, 4732`)
4. Click **OK** to save
5. The "Monitored Event IDs" section will update to show custom configurations

**Example Use Cases:**
- Monitor specific DCs for user creation events (4720)
- Add group membership changes (4728, 4732) for RODC monitoring
- Configure different IDs for test vs production DCs

## Configuration

### Monitoring Interval

Change the timer interval (line 343):
```powershell
$timer.Interval = 30000 # 30 seconds (value in milliseconds)
```

### Alert Retention Period

Modify the alert cleanup period (line 245):
```powershell
$cutoffTime = (Get-Date).AddHours(-1) # Default: 1 hour
```

### Query Timeout

Adjust the timeout for DC queries (line 241):
```powershell
if ((Get-Date) - $jobInfo.StartTime -gt [TimeSpan]::FromSeconds(15)) # Default: 15 seconds
```

### Event Lookback Window

Change how far back to search for events (line 197):
```powershell
StartTime = (Get-Date).AddMinutes(-5) # Default: 5 minutes
```

### Result Check Interval

Adjust how often completed jobs are checked (line 588):
```powershell
$resultTimer.Interval = 1000 # 1 second (value in milliseconds)
```

## Troubleshooting

### Credential Validation Failed

**Problem**: Authentication fails when starting the script

**Solutions**:
- Ensure you're using domain credentials (DOMAIN\Username or username@domain.com)
- Verify the account has permission to query domain controllers
- Check that WinRM is enabled on at least one DC

### Yellow Status (Error)

**Problem**: Domain controller shows yellow with error message

**Solutions**:
- Verify WinRM is enabled: `Test-WSMan -ComputerName DC-NAME`
- Check firewall rules allow WinRM traffic
- Ensure credentials have access to Security event log

### Orange Status (Timeout)

**Problem**: Query times out after 15 seconds

**Solutions**:
- Check network connectivity to the DC
- Verify DC is online and responsive
- Consider increasing timeout value (default: 15 seconds)

### No Events Detected

**Problem**: Green status but expected events aren't showing

**Solutions**:
- Verify events exist: `Get-WinEvent -ComputerName DC-NAME -LogName Security -MaxEvents 10`
- Check the event occurred within the lookback window (default 5 minutes)
- Ensure event ID is in the monitored list

## Security Considerations

- **Credentials**: Stored securely using PowerShell's PSCredential system
- **Memory Cleanup**: Credentials are cleared from memory on exit
- **Read-Only**: Script only reads event logs, makes no system changes
- **Encryption**: WinRM communication is encrypted by default
- **Least Privilege**: Use an account with minimum required permissions

## Architecture

### Async Processing

The script uses PowerShell background jobs to query domain controllers asynchronously:
- Main GUI thread remains responsive
- Multiple concurrent queries via PowerShell jobs
- Job results checked every second via dedicated timer
- 15-second timeout protection per query

### Alert Management

- Alerts stored by RecordId to prevent duplicates
- Automatic cleanup of alerts older than 1 hour
- Persistent red status until alerts expire

### Resource Management

- Proper disposal of background jobs
- Job cancellation and cleanup on new queries
- Credential cleanup on exit
- Timer cleanup on form close
- Final cleanup of all jobs on application exit

## Version History

### Version 1.0
- Initial release with basic monitoring
- Custom credential dialog

### Version 2.0
- Async runspace-based queries
- Improved credential security with custom credential dialog
- Connection testing and timeout handling
- Alert deduplication and auto-cleanup
- Enhanced error handling
- Proper resource disposal

### Version 2.1
- Per-server Event ID configuration via right-click context menu
- Monitored Event IDs display panel showing default and custom configurations
- Real-time update of monitored IDs when configurations change
- Support for different Event IDs per domain controller

### Version 2.2 (Current)
- Migrated from runspaces to PowerShell background jobs for improved stability
- Reduced query timeout from 30 to 15 seconds for faster failure detection
- Added dedicated result-checking timer (1-second interval)
- Improved job lifecycle management with automatic cleanup
- Enhanced error handling for disposed UI controls
- PowerShell 5.1 requirement explicitly documented

## License

This script is provided as-is for use in Active Directory environments. Modify and distribute as needed.

## Author

Created by Trond Hoiberg for domain security monitoring and incident response.

## Contributing

To add new features or improvements:
1. Test thoroughly in a lab environment
2. Ensure backward compatibility
3. Document any new configuration options
4. Update this README with changes
