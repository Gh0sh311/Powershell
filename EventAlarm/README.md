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

### Default Event IDs - Insider Threat & Lateral Movement Detection

By default, all domain controllers are monitored for these **top 10 critical security Event IDs** optimized for detecting insider threats, compromised accounts, and lateral movement:

| Event ID | Category | Description | Why It's Critical |
|----------|----------|-------------|-------------------|
| **1102** | Audit Log Tampering | **Audit log was cleared** | 🔴 **CRITICAL** - Attacker covering their tracks. This is almost always malicious. |
| **4624** | Logon Activity | **Successful account logon** | Detects lateral movement, especially RDP/Network logons (Types 3, 10). *Filtered by default.* |
| **4625** | Logon Failures | **Failed logon attempt** | Brute force attacks, password spraying, credential stuffing attempts. |
| **4648** | Privilege Escalation | **Logon with explicit credentials (RunAs)** | Detects use of stolen credentials, "Run as administrator" with different account. |
| **4672** | Admin Rights | **Special privileges assigned to new logon** | High-privilege account usage (Domain Admin, Enterprise Admin, etc.). |
| **4720** | Account Creation | **User account was created** | Backdoor account creation by attacker for persistence. |
| **4728** | Group Membership | **Member added to security-enabled global group** | Privilege escalation - especially Domain Admins, Enterprise Admins, Schema Admins. |
| **4732** | Local Admin | **Member added to security-enabled local group** | Local administrator rights granted - common persistence technique. |
| **4719** | Policy Tampering | **System audit policy was changed** | Attacker disabling security logging to hide activity. |
| **4768** | Kerberos Attack | **Kerberos TGT ticket was requested** | Golden ticket attacks, pass-the-ticket, Kerberoasting detection. |

### Event ID 4624 Filtering

**Event ID 4624** can generate significant noise in busy environments. The script includes intelligent filtering:

#### Configuration Variables (Lines 38-44)

```powershell
# Enable/disable 4624 filtering
$script:Filter4624 = $true

# Only alert on these logon types (reduces noise by 90%+)
$script:Filter4624LogonTypes = @(
    3,   # Network logon (file shares, remote admin)
    10   # RemoteInteractive (RDP/Terminal Services)
)

# Optional: Only alert outside business hours
$script:BusinessHoursStart = $null  # Example: 8 for 8 AM
$script:BusinessHoursEnd = $null    # Example: 18 for 6 PM
```

#### Logon Type Reference

| Type | Name | Description | Monitor? |
|------|------|-------------|----------|
| 2 | Interactive | Local console logon | ❌ Usually noisy |
| 3 | Network | Network/file share access | ✅ **Lateral movement** |
| 4 | Batch | Scheduled task | ❌ Usually legitimate |
| 5 | Service | Service started | ❌ Usually legitimate |
| 7 | Unlock | Workstation unlock | ❌ Very noisy |
| 8 | NetworkCleartext | IIS basic auth | ⚠️ Depends on environment |
| 9 | NewCredentials | RunAs with different creds | ✅ Same as 4648 |
| 10 | RemoteInteractive | RDP/Terminal Services | ✅ **Primary attack vector** |
| 11 | CachedInteractive | Cached credentials | ❌ Usually legitimate |

**Recommendation**: Keep filtering enabled with Types 3 and 10 only. Add business hours filtering if you have predictable access patterns.

### Additional High-Value Event IDs

Consider adding these Event IDs for more comprehensive monitoring:

| Event ID | Category | Description | Use Case |
|----------|----------|-------------|----------|
| **4634** | Logoff | Account logoff | Correlate with 4624 for session duration analysis |
| **4688** | Process | New process creation | Detect malicious command execution, PowerShell abuse |
| **4697** | Service | Service installed | Persistence mechanism via new services |
| **4698/4699** | Scheduled Task | Task created/deleted | Persistence via scheduled tasks |
| **4740** | Account Lockout | Account was locked out | Repeated lockouts may indicate brute force |
| **4765** | SID History | SID History added to account | Golden ticket or SID history injection attack |
| **4766** | SID History | SID History add failed | Attempted SID history attack (blocked) |
| **4776** | NTLM Auth | Credential validation (NTLM) | Pass-the-hash detection |
| **4794** | DSRM Password | DSRM admin password set | DC compromise attempt |
| **4964** | Special Groups | Special groups assigned | High-privilege group membership |
| **5140/5145** | File Share | Network share accessed | Data exfiltration, lateral movement via shares |

**To add these**, modify line 25 in the script or use the GUI to configure per-server.

### Customizing Event IDs

**Per-Server Configuration (GUI):**
1. Right-click on any domain controller in the list
2. Select "Configure Event IDs..."
3. Enter comma-separated Event IDs (e.g., `1102, 4720, 4728`)
4. Leave empty to revert to default IDs
5. Custom configurations are displayed in the "Monitored Event IDs" section

**Global Default (Code):**
Modify the `$script:DefaultEventIDs` array starting at line 25:
```powershell
$script:DefaultEventIDs = @(
    1102,  # Audit log cleared
    4624,  # Successful logon (filtered)
    4625,  # Failed logon
    4648,  # Explicit credential use
    4672,  # Special privileges
    4720,  # Account created
    4728,  # Global group membership
    4732,  # Local group membership
    4719,  # Audit policy changed
    4768   # Kerberos TGT
)
```

**Event ID 4624 Filtering (Code):**
Configure filtering behavior starting at line 38:
```powershell
$script:Filter4624 = $true  # Enable filtering
$script:Filter4624LogonTypes = @(3, 10)  # Network + RDP only
$script:BusinessHoursStart = $null  # Set to 8 for 8 AM
$script:BusinessHoursEnd = $null    # Set to 18 for 6 PM
```

## Requirements

- **Windows PowerShell 5.1** (PowerShell Core/7.x is not supported due to WinRM authentication limitations with PSCredential serialization in background jobs)
- **Domain credentials** with permission to:
  - Query domain controllers
  - Access Security event logs on remote systems
- **WinRM (Windows Remote Management)** enabled on all domain controllers
  - Port 5985 (HTTP) or 5986 (HTTPS) must be accessible
  - Script uses WinRM/Invoke-Command for remote queries (not RPC/DCOM)
- **.NET Framework** (for Windows Forms)

### Network Requirements

This script uses **WinRM** (Windows Remote Management) for all remote communications:

- **Required Open Ports**:
  - TCP 5985 (WinRM HTTP) **OR** TCP 5986 (WinRM HTTPS)

- **Does NOT require**:
  - RPC dynamic ports (49152-65535)
  - DCOM/RPC connectivity

**Why WinRM instead of RPC?**
The script was specifically designed to use `Invoke-Command` over WinRM rather than direct `Get-WinEvent -ComputerName` calls, which rely on RPC/DCOM. This approach:
- Works reliably in environments where RPC dynamic ports are restricted
- Provides better firewall compatibility (only 1-2 ports vs 16,000+ ports)
- Offers encrypted communication by default
- More resilient in modern Active Directory environments

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

### Event ID 4624 Filtering

Customize filtering for successful logons (lines 38-44):
```powershell
# Enable/disable filtering (set to $false to see ALL 4624 events)
$script:Filter4624 = $true

# Only alert on these logon types
$script:Filter4624LogonTypes = @(3, 10)  # 3=Network, 10=RDP

# Optional: Only alert outside business hours (24-hour format)
$script:BusinessHoursStart = 8   # 8 AM
$script:BusinessHoursEnd = 18    # 6 PM
```

**Example Configurations:**
```powershell
# Monitor ALL 4624 events (very noisy)
$script:Filter4624 = $false

# Only monitor RDP logons
$script:Filter4624LogonTypes = @(10)

# Monitor Network + RDP only during off-hours (nights/weekends)
$script:Filter4624LogonTypes = @(3, 10)
$script:BusinessHoursStart = 7
$script:BusinessHoursEnd = 19
```

### Monitoring Interval

Change the timer interval (line ~580):
```powershell
$timer.Interval = 30000 # 30 seconds (value in milliseconds)
```

### Alert Retention Period

Modify the alert cleanup period (line ~380):
```powershell
$cutoffTime = (Get-Date).AddHours(-1) # Default: 1 hour
```

### Query Timeout

Adjust the timeout for DC queries (line ~280):
```powershell
if ((Get-Date) - $jobInfo.StartTime -gt [TimeSpan]::FromSeconds(15)) # Default: 15 seconds
```

### Event Lookback Window

Change how far back to search for events (line ~221):
```powershell
StartTime = (Get-Date).AddMinutes(-5) # Default: 5 minutes
```

### Result Check Interval

Adjust how often completed jobs are checked (line ~625):
```powershell
$resultTimer.Interval = 1000 # 1 second (value in milliseconds)
```

## Troubleshooting

### Credential Validation Failed

**Problem**: Authentication fails when starting the script

**Solutions**:
- Ensure you're using domain credentials (DOMAIN\Username or username@domain.com)
- Verify the account has permission to query domain controllers
- Check that WinRM is enabled on at least one DC: `Test-WSMan -ComputerName DC-NAME`

### "There are no more endpoints available from the endpoint mapper"

**Problem**: Script fails with RPC endpoint mapper error

**Root Cause**: This error occurs when using `Get-WinEvent -ComputerName` directly, which requires RPC dynamic ports (49152-65535).

**Solution**: This script has been updated to use WinRM instead. Ensure:
1. WinRM is enabled on DCs: `Test-WSMan -ComputerName DC-NAME`
2. Port 5985 is accessible through firewall
3. Enable WinRM if needed:
   ```powershell
   # On domain controller
   Enable-PSRemoting -Force
   ```

### Yellow Status (Error)

**Problem**: Domain controller shows yellow with error message

**Solutions**:
- Verify WinRM is enabled: `Test-WSMan -ComputerName DC-NAME`
- Check firewall rules allow WinRM traffic (port 5985/5986)
- Test connectivity:
  ```powershell
  Test-NetConnection -ComputerName DC-NAME -Port 5985
  ```
- Ensure credentials have access to Security event log
- Verify PowerShell remoting is configured:
  ```powershell
  Invoke-Command -ComputerName DC-NAME -ScriptBlock { $env:COMPUTERNAME }
  ```

### Orange Status (Timeout)

**Problem**: Query times out after 15 seconds

**Solutions**:
- Check network connectivity to the DC
- Verify DC is online and responsive: `Test-Connection DC-NAME`
- Test WinRM specifically: `Test-WSMan -ComputerName DC-NAME`
- Consider increasing timeout value (default: 15 seconds)
- Check for network latency or packet loss

### No Events Detected

**Problem**: Green status but expected events aren't showing

**Solutions**:
- Verify events exist on the DC:
  ```powershell
  Invoke-Command -ComputerName DC-NAME -ScriptBlock {
      Get-WinEvent -LogName Security -MaxEvents 10
  }
  ```
- Check the event occurred within the lookback window (default 5 minutes)
- Ensure event ID is in the monitored list (check "Monitored Event IDs" section)
- Verify the event log hasn't been cleared

### WinRM Not Enabled

**Problem**: WinRM is not configured on domain controllers

**Solution**: Enable WinRM on the domain controller:
```powershell
# Run on the domain controller as Administrator
Enable-PSRemoting -Force

# Configure firewall rule
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"

# Verify WinRM service is running
Get-Service WinRM | Start-Service
Set-Service WinRM -StartupType Automatic

# Test from client
Test-WSMan -ComputerName DC-NAME
```

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

### Version 2.2
- Migrated from runspaces to PowerShell background jobs for improved stability
- Reduced query timeout from 30 to 15 seconds for faster failure detection
- Added dedicated result-checking timer (1-second interval)
- Improved job lifecycle management with automatic cleanup
- Enhanced error handling for disposed UI controls
- PowerShell 5.1 requirement explicitly documented

### Version 2.3
- **Changed remote communication method from RPC to WinRM**
  - Now uses `Invoke-Command` instead of `Get-WinEvent -ComputerName`
  - Resolves "RPC server is unavailable" and "endpoint mapper" errors
  - Only requires WinRM port (5985/5986) instead of RPC dynamic ports (49152-65535)
- Improved firewall compatibility in restricted environments
- Better reliability in modern Active Directory deployments
- Enhanced credential validation using WinRM connectivity test
- Updated documentation with WinRM requirements and troubleshooting

### Version 2.4 (Current)
- **Updated default Event IDs for insider threat detection**
  - Changed from 7 audit-focused events to 10 critical security events
  - New focus: lateral movement, privilege escalation, and compromised accounts
  - Added: 4624 (logon), 4625 (failed logon), 4648 (RunAs), 4672 (admin rights), 4720 (account created), 4728/4732 (group membership), 4768 (Kerberos)
- **Intelligent Event ID 4624 filtering**
  - Configurable logon type filtering (default: Network + RDP only)
  - Optional business hours filtering to reduce noise
  - Reduces 4624 alerts by 90%+ while maintaining security coverage
- **Enhanced documentation**
  - Comprehensive Event ID reference tables with attack techniques
  - Logon type reference for 4624 filtering
  - Additional high-value Event IDs for extended monitoring
  - Configuration examples for different security postures

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
