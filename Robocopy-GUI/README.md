# Robocopy GUI Script

## Synopsis
This PowerShell script provides a graphical user interface (GUI) to simplify the use of Robocopy, a robust file copy utility included with Windows. The script includes commonly used Robocopy parameters and options to facilitate file and directory copying or moving operations.

## Description
The Robocopy GUI script creates a Windows Forms interface that allows users to configure and execute Robocopy commands without needing to manually construct command-line arguments. Key features include:
- Input fields for source and destination paths (supporting both local and UNC paths).
- Options to select between copy or move operations.
- Support for common Robocopy parameters such as `/COPY:DAT`, `/COPYALL`, `/MIR`, `/E`, and more.
- File and directory filtering options (e.g., include/exclude patterns, minimum/maximum file age).
- Retry and multi-threading options for robust and efficient file transfers.
- Logging capabilities, including verbose output and Unicode log files.
- A progress bar and output window to monitor the operation.
- A confirmation dialog for destructive operations (e.g., `/MIR` or `/MOVE`).

The script validates inputs, such as ensuring valid source and destination paths, and provides tooltips for user guidance. It also supports asynchronous execution to prevent the GUI from freezing during long operations.

## Requirements
- **PowerShell Version**: 5.1 or higher
- **Operating System**: Windows (Robocopy is a Windows utility)
- **Assemblies**: 
  - `System.Windows.Forms`
  - `System.Drawing`

## Usage
1. Save the script with a `.ps1` extension (e.g., `RobocopyGUI.ps1`).
2. Run the script in PowerShell:
   ```powershell
   .\RobocopyGUI.ps1
   ```
3. The GUI will appear, allowing you to:
   - Specify source and destination paths using text fields or folder browser dialogs.
   - Choose between "Copy" or "Move" operations.
   - Configure copy options, file selection, retry settings, and logging preferences.
   - Click "Execute" to start the Robocopy operation.
4. Monitor the progress in the output window and progress bar.

**Note**: If the `/MOVE` or `/MIR` options are selected, a confirmation dialog will prompt you to confirm the operation, as these can delete files.

## Notes
- **Author**: Trond Hoiberg
- **Date**: 30th September 2025
- **License**: Feel free to modify and use the script as needed.
- **Limitations**:
  - Progress estimation may slow down the start of operations for large directories. This can be disabled for faster startup.
  - The script assumes Robocopy is available in the system PATH.
- **Customization**: Users can extend the script by adding more Robocopy options or modifying the GUI layout.

## Important: Running as Normal User vs Administrator

### /COPYALL Option Requires Administrator Rights
The `/COPYALL` option attempts to copy **all file information** including:
- Data (D)
- Attributes (A)
- Timestamps (T)
- NTFS Security (S)
- Owner information (O)
- Auditing information (U)

**The auditing information (U) requires the "Manage Auditing" user right**, which is only available when running PowerShell as an administrator.

### Recommended Settings for Normal Users
If you're running the script as a **normal user** (not administrator):
1. **Uncheck** the "Copy All File Info (/COPYALL) - Requires Admin" option
2. **Keep checked** the "Copy Data, Attributes, Timestamps (/COPY:DAT)" option (default)

This will copy files successfully without requiring administrator privileges.

### Error: "You do not have the Manage Auditing user right"
If you see this error in the output:
```
ERROR : You do not have the Manage Auditing user right.
*****  You need this to copy auditing information (/COPY:U or /COPYALL).
```

**Solution**: Uncheck the `/COPYALL` option in the "Copy Options" tab and run the operation again. The `/COPY:DAT` option will still copy your files with data, attributes, and timestamps.

## Example
To copy all files and subdirectories from `C:\Source` to `D:\Destination` with data, attributes, and timestamps, including empty directories:
1. Enter `C:\Source` in the Source Path field.
2. Enter `D:\Destination` in the Destination Path field.
3. Select the "Copy" operation.
4. Check "Copy Data, Attributes, Timestamps (/COPY:DAT)" and "Include Subdirectories (/E)".
5. Click "Execute".

The script will construct and run the command:
```cmd
robocopy "C:\Source" "D:\Destination" /COPY:DAT /E /R:3 /W:5 /NP /MT:8
```

## Contributing
Feel free to fork, modify, or enhance the script. Suggestions for additional Robocopy options or GUI improvements are welcome.