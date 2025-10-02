# Extract unique values from a compiled list with Chrome Extension 

## Overview
`Extract-UniqueValues.ps1` is a PowerShell script designed to process a text file by extracting unique lines, excluding comments and empty lines. The script offers flexibility through command-line parameters or interactive file selection via dialog boxes. It saves the unique values to a specified output file with customizable encoding and displays them in a graphical GridView. The script includes robust error handling, performance optimization for large files, and optional logging for auditing purposes.

## Features
- **Flexible Input/Output**: Supports both command-line file paths and interactive file selection using OpenFileDialog and SaveFileDialog.
- **Customizable Comment Filtering**: Allows users to specify a custom comment character (default: `#`) to ignore comment lines.
- **Encoding Options**: Supports multiple output file encodings (`UTF8`, `ASCII`, `Unicode`, `UTF32`).
- **Performance Optimization**: Uses `StreamReader` and `HashSet` for efficient processing of large files.
- **Logging**: Optionally logs operations to a specified file for debugging and auditing.
- **Error Handling**: Includes comprehensive validation and error handling for file operations and data processing.
- **User Feedback**: Displays results in a GridView and provides console feedback on success or failure.

## Requirements
- **Operating System**: Windows with PowerShell 5.1 or later.
- **Dependencies**: Requires the `System.Windows.Forms` .NET assembly for file dialog functionality (included in Windows).
- **Permissions**: Write access to the output directory and read access to the input file.

## Installation
1. Save the script as `Extract-UniqueValues.ps1` in a desired directory.
2. Ensure PowerShell execution policy allows running scripts:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```
3. No additional dependencies are required, as the script uses built-in PowerShell and .NET components.

## Usage
Run the script in PowerShell using one of the following methods:

### Interactive Mode
```powershell
.\Extract-UniqueValues.ps1
```
- Prompts the user to select an input text file and an output file location via dialog boxes.
- Processes the input file, saves unique values to the output file, and displays results in a GridView.

### Command-Line Mode
```powershell
.\Extract-UniqueValues.ps1 -InputFile "list.txt" -OutFile "unique.txt" -CommentChar "//" -Encoding "ASCII" -LogFile "script.log"
```
- Reads `list.txt`, ignores lines starting with `//`, saves unique values to `unique.txt` in ASCII encoding, logs operations to `script.log`, and displays results in a GridView.

## Parameters
- `-InputFile <string>`: Path to the input text file. If not provided, a file dialog prompts for selection.
- `-OutFile <string>`: Path to the output text file. If not provided, a file dialog prompts for selection.
- `-CommentChar <string>`: Character indicating a comment line (default: `#`). Lines starting with this character are ignored.
- `-Encoding <string>`: Encoding for the output file (default: `UTF8`). Valid options: `UTF8`, `ASCII`, `Unicode`, `UTF32`.
- `-LogFile <string>`: Path to a log file for recording script operations. If not provided, no logging occurs.

## Examples
1. **Basic Interactive Usage**:
   ```powershell
   .\Extract-UniqueValues.ps1
   ```
   - Opens dialog boxes to select input and output files.
   - Ignores lines starting with `#` and empty lines, saves unique values, and displays them in a GridView.

2. **Custom Comment and Encoding with Logging**:
   ```powershell
   .\Extract-UniqueValues.ps1 -InputFile "data.txt" -OutFile "output.txt" -CommentChar ";" -Encoding "Unicode" -LogFile "log.txt"
   ```
   - Processes `data.txt`, ignores lines starting with `;`, saves unique values to `output.txt` in Unicode encoding, logs operations to `log.txt`, and displays results in a GridView.

## Error Handling
The script includes robust error handling for:
- Invalid or non-existent input/output file paths.
- Unwritable output directories.
- Empty or invalid input files after filtering.
- File read/write errors.
Errors are displayed in the console, and if logging is enabled, they are recorded in the specified log file.

## Logging
When a `-LogFile` is specified, the script logs:
- Script start and completion.
- File selection details.
- File processing steps.
- Success or error messages with timestamps.

## Notes
- The script uses `StreamReader` for efficient reading of large files, minimizing memory usage.
- A `HashSet` ensures fast and accurate extraction of unique lines.
- File dialogs and resources are properly disposed of to prevent memory leaks.
- The output file will be overwritten if it already exists, with a warning displayed to the user.

## License
This script is provided as-is, with no warranty. You may modify and distribute it freely, provided you retain the original author’s comments and documentation.
The list.txt is based on https://github.com/palant/malicious-extensions-list/blob/main/list.txt
Credit to https://github.com/palant
I have added to it using findings from various security companies.
Trond Hoiberg 2 october 2025