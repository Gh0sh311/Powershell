# RPC Connectivity Diagnostic Tool

## Overview
A comprehensive PowerShell diagnostic tool with GUI for troubleshooting "The RPC server is unavailable" errors. This tool systematically tests all common causes of RPC connectivity failures and provides detailed recommendations for resolution.

## Author
**Trond Hoiberg**

## Features

### Comprehensive Testing
- **Network Connectivity**: ICMP ping tests with response time analysis
- **DNS Resolution**: Validates hostname resolution and IP address mapping
- **RPC Endpoint Mapper**: Tests TCP port 135 accessibility
- **Dynamic RPC Ports**: Scans sample ports in the range 49152-65535
- **WMI Connectivity**: Tests Windows Management Instrumentation access
- **Remote Registry**: Validates remote registry service availability
- **SMB/CIFS**: Checks file sharing services (port 445)
- **WinRM**: Tests Windows Remote Management (ports 5985/5986)
- **Time Synchronization**: Verifies time offset between systems
- **Firewall Analysis**: Reviews local firewall profiles and RPC rules
- **Network Path**: Traceroute analysis to identify routing issues
- **Domain Information**: Displays domain/workgroup configuration

### User Interface
- Clean, intuitive Windows Forms GUI
- Real-time progress tracking with progress bar
- Color-coded results (Success/Error/Warning/Info)
- Timestamped diagnostic output
- Export results to text file
- Clear results functionality

### Intelligent Reporting
- Automatic issue detection
- Context-aware recommendations
- Prioritized action items
- Detailed troubleshooting steps

## Requirements
- Windows PowerShell 5.1 or higher
- Administrative privileges recommended for complete diagnostics
- Network access to target server

## Usage

### Basic Usage
1. Run the script:
   ```powershell
   .\TestRPCConnectivity.ps1
   ```

2. Enter the target server name or IP address in the text box

3. Click **Run Diagnostics** to begin testing

4. Review the results in the output window

5. Optionally export the report using the **Export Report** button

### Keyboard Shortcuts
- Press **Enter** in the server name field to start diagnostics
- Use **Clear Results** to reset the output window

## Understanding the Results

### Result Codes
- `[+]` - **Success**: Test passed successfully
- `[!]` - **Error**: Critical failure detected
- `[*]` - **Warning**: Potential issue identified
- `[i]` - **Info**: Informational message

### Common Issues and Solutions

#### Port 135 Blocked
**Symptoms**: "FAILED: Port 135 is not accessible"

**Solutions**:
- Enable "File and Printer Sharing" in Windows Firewall
- Add firewall exception for TCP port 135
- Verify RPC service is running on target server

#### Dynamic RPC Ports Blocked
**Symptoms**: "WARNING: No dynamic RPC ports found open"

**Solutions**:
- Open dynamic RPC port range (49152-65535) in firewall
- Configure restricted RPC port range:
  ```powershell
  netsh int ipv4 set dynamic tcp start=49152 num=16384
  ```

#### WMI Connectivity Failure
**Symptoms**: "FAILED: WMI query failed"

**Solutions**:
- Verify "Windows Management Instrumentation" service is running
- Check DCOM permissions using `dcomcnfg`
- Ensure user has appropriate WMI permissions

#### Time Synchronization Issues
**Symptoms**: "WARNING: Time offset is X seconds"

**Solutions**:
- Synchronize time with domain controller or time server
- Run: `w32tm /resync /force`
- Verify time service is running: `net start w32time`

## Export Reports
Diagnostic reports can be exported to text files for documentation or sharing with support teams. The export includes:
- Complete test results
- Timestamps for all operations
- Issue summary
- Recommended actions

Default filename format: `RPC_Diagnostic_YYYYMMDD_HHMMSS.txt`

## Technical Details

### Tested Components
1. **ICMP Echo (Ping)**: Basic network reachability
2. **DNS**: Name resolution services
3. **TCP Port 135**: RPC Endpoint Mapper
4. **TCP Ports 49152-65535**: Dynamic RPC port range
5. **TCP Port 5985/5986**: WinRM services
6. **TCP Port 445**: SMB/CIFS file sharing
7. **RPC Service**: Local service status
8. **Remote Registry**: Remote administration capability
9. **WMI**: Windows Management Instrumentation
10. **UNC Paths**: Administrative share access
11. **Windows Firewall**: Profile and rule analysis
12. **Time Service**: Kerberos time synchronization
13. **Domain Configuration**: Domain membership status
14. **Network Path**: Routing and hop analysis

### Timeouts
- TCP connection attempts: 3 seconds (1 second for dynamic port scans)
- WMI queries: Default WMI timeout
- Ping tests: Standard timeout with 2 attempts

## Troubleshooting the Script

### Script Won't Run
**Error**: "Execution of scripts is disabled on this system"

**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Missing .NET Assemblies
The script requires:
- System.Windows.Forms
- System.Drawing

These are included in standard Windows installations.

### Insufficient Permissions
Some tests require administrative privileges:
- Remote Registry access
- Firewall rule enumeration
- Service status queries

Run PowerShell as Administrator for complete diagnostics.

## Version History
- **1.0** - Initial release

## License
This tool is provided as-is for diagnostic purposes.

## Support
For issues or feature requests, please contact the author or your IT support team.
