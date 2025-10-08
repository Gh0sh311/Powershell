# PowerShell Security Monitoring Scripts

## Overview
This repository, maintained by Trond Hoiberg, contains a collection of PowerShell scripts designed for cybersecurity monitoring and analysis. In addition some scripts that can be useful in my daily work. 
As a cybersecurity engineer at a large organization, I develop these tools to monitor PowerShell usage, detect potential misuse, and identify malicious activities by adversaries that may evade Endpoint Detection and Response (EDR) solutions. The scripts focus on analyzing Event Logs, PowerShell Transcript files, and other relevant data sources to enhance security visibility.

## Purpose
The primary objective of these scripts is to provide robust monitoring and analysis capabilities for PowerShell activities within an enterprise environment. By leveraging PowerShell's native capabilities, these tools help identify suspicious behavior, unauthorized access, or malicious scripts that could indicate a security breach.

## Features

### Security Monitoring & Analysis
- **Event Log Analysis**: Advanced GUI-based event log search tool with Active Directory integration for monitoring security events across domain controllers
- **Domain Controller Security Monitor**: Real-time monitoring of all domain controllers for specific security events, including insider threats and lateral movement detection
- **File Type Detection**: GUI-based magic bytes analyzer to detect file types regardless of extension, with Base64 prefix analysis and hidden content detection
- **Pattern Search Engine**: Automated text file scanning for user-defined patterns and regular expressions with comprehensive logging and result management

### System Administration Tools
- **WinRM Status Checker**: Test WinRM connectivity across all domain servers with HTTP/HTTPS port validation
- **RPC Connectivity Diagnostics**: Comprehensive GUI tool for diagnosing "RPC server is unavailable" errors
- **Zabbix Agent Management**: Scripts for removing, collecting logs, and remote management of Zabbix agents
- **Robocopy GUI**: Simplified interface for Robocopy operations with common parameters and safety confirmations

### Utilities
- **File Hash Checker**: GUI utility to verify file integrity using SHA256, SHA1, or MD5 hashing with drag-and-drop support
- **Unique ID Extractor**: Extract unique identifiers from lists for processing and analysis

### Key Capabilities
- **Custom Detection Logic**: Implement tailored detection rules to catch activities that may bypass traditional EDR solutions
- **GUI-Based Tools**: Most tools feature intuitive graphical interfaces for ease of use
- **Active Directory Integration**: Several scripts leverage AD for enterprise-wide operations
- **Scalable and Modular**: Designed to be adaptable for various environments and easily extensible for additional use cases

## Getting Started
### Prerequisites
- PowerShell 5.1 or later (Windows PowerShell or PowerShell Core).
- Administrative privileges to access Event Logs and Transcript files.
- Basic understanding of PowerShell scripting and Windows security concepts.

### Usage
- Each script includes detailed comments and usage instructions within the code.
- Refer to individual script documentation for specific parameters and outputs.

## Contributing
Contributions are welcome! If you have suggestions for improvements or new scripts, please:
1. Fork the repository.
2. Create a new branch for your changes.
3. Submit a pull request with a detailed description of your updates.

## Note
Feel free to modify and use the scripts. 