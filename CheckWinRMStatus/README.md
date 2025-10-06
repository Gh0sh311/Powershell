# Check WinRM Status

A PowerShell script that checks if WinRM (Windows Remote Management) is enabled on all servers in an Active Directory domain.

**Made by Trond Hoiberg**

## Description

This script queries Active Directory for all server computers and tests whether WinRM is enabled and accessible on each server. It tests both HTTP (port 5985) and HTTPS (port 5986) connections and provides detailed reporting.

## Features

- Automatically discovers all servers in the domain from Active Directory
- Tests WinRM connectivity on both HTTP and HTTPS ports
- Color-coded console output for easy status identification
- Exports results to both CSV and TXT formats
- Generates summary statistics
- Lists servers with WinRM disabled/unreachable

## Requirements

- **PowerShell 5.1 or later**
- **Active Directory PowerShell Module** (RSAT-AD-PowerShell)
- **Appropriate permissions:**
  - Read access to Active Directory
  - Network connectivity to target servers
  - Firewall rules allowing WinRM ports (5985/5986)

## Installation

1. Clone or download this repository to your local machine
2. Ensure the Active Directory module is installed:
   ```powershell
   Import-Module ActiveDirectory
   ```

## Usage

Navigate to the script directory and run:

```powershell
.\Check-WinRMStatus.ps1
```

The script will:
1. Query Active Directory for all servers
2. Test WinRM connectivity on each server
3. Display real-time progress with color-coded results
4. Generate output files with detailed results

## Output Files

The script generates two output files:

### 1. Results.txt
A human-readable text file containing:
- List of all servers with WinRM enabled (with port information)
- List of all servers with WinRM disabled/unreachable (with error details)
- Summary counts

### 2. WinRM-Status-Report-[timestamp].csv
A CSV file with detailed information for each server:
- ServerName
- DNSHostName
- OperatingSystem
- WinRMEnabled (True/False)
- WinRMPort
- Status
- ErrorMessage

## Example Output

### Console Output
```
Retrieving all servers from Active Directory...
Found 25 servers in the domain.

Testing WinRM connectivity on each server...

Testing SERVER01... [SUCCESS]
Testing SERVER02... [SUCCESS - HTTPS]
Testing SERVER03... [FAILED]

========== SUMMARY ==========
Total Servers: 25
WinRM Enabled: 23
WinRM Disabled/Unreachable: 2
```

### Results.txt Format
```
==========================================
WinRM Status Report
Generated: 2025-10-06 14:30:45
==========================================

SERVERS WITH WINRM ENABLED:
==========================================
SERVER01 - server01.domain.com - Port: 5985 (HTTP)
SERVER02 - server02.domain.com - Port: 5986 (HTTPS)

SERVERS WITH WINRM DISABLED/UNREACHABLE:
==========================================
SERVER03 - server03.domain.com - Error: Connection timeout

==========================================
SUMMARY:
==========================================
Total servers with WinRM enabled: 23
Total servers with WinRM disabled/unreachable: 2
==========================================
```

## Troubleshooting

### "Module ActiveDirectory not found"
Install the Active Directory PowerShell module:
```powershell
Install-WindowsFeature RSAT-AD-PowerShell
```

### "Access Denied" errors
Ensure your account has:
- Read permissions in Active Directory
- Network access to target servers
- Appropriate firewall rules for WinRM ports

### Connection failures
- Verify the target server is online
- Check if WinRM service is running on the target server
- Confirm firewall rules allow ports 5985 (HTTP) and 5986 (HTTPS)
- Test manually: `Test-WSMan -ComputerName <servername>`

## License

Free to use and modify.

## Author

Trond Hoiberg
