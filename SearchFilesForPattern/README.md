# SearchFilesForPatterns.ps1

## Overview
This PowerShell script automates the process of searching through multiple text files for specific words or patterns defined in a CSV file. It provides detailed functionality for file processing, result logging, file organization, and performance monitoring. The script is designed to run on PowerShell 7 or later due to its use of parallel processing.

## Features
- **Pattern Search**: Searches text files for patterns or regular expressions specified in a CSV file.
- **Result Logging**: Saves search results to a CSV file in a dated log subfolder (`LogYYYYMMDD\SearchResults.csv`) with log rotation for files exceeding 10 MB.
- **File Organization**: Moves processed files to a dated subfolder (`CheckedFilesPath\YYYYMMDD`) and removes empty folders in the source directory.
- **Archiving**: Zips files in subfolders of `CheckedFilesPath` dated earlier than today, appending new files to existing ZIPs and deleting files after successful archiving.
- **Performance Monitoring**: Displays processing time and files per second to aid optimization.
- **User Interface**: Shows results in a GridView or displays a message box if no matches are found.
- **Error Handling**: Validates paths, permissions, and file types before processing, with debug logging for troubleshooting zipping issues.

## Prerequisites
- **PowerShell Version**: Requires PowerShell 7.0 or later for parallel processing.
- **Permissions**: Write permissions are required for the source directory (`TextFilesPath`) and destination directory (`CheckedFilesPath`).
- **CSV File**: A CSV file with a `Pattern` column (or first column) containing search patterns.
- **Windows Forms**: Used for displaying results in GridView and message boxes.

## Parameters
- **TextFilesPath** (Mandatory): Path to the directory containing text files to search. Empty folders are removed after processing.
- **PatternsCsvPath** (Mandatory): Path to the CSV file containing search patterns (column named `Pattern` or first column).
- **CheckedFilesPath** (Mandatory): Destination folder for moved files and log files. Subfolders are created with the current date (`YYYYMMDD`).
- **FileTypes** (Optional): Array of file extensions to search (default: `*.txt`, `*.log`, `*.csv`). Use `*` for all file types.
- **Recurse** (Switch): If specified, searches subdirectories of `TextFilesPath` and removes empty subdirectories.
- **CaseSensitive** (Switch): Enables case-sensitive pattern matching (default: case-insensitive).
- **UseRegex** (Switch): Treats patterns as regular expressions instead of literal strings.
- **ThrottleLimit** (Optional): Maximum number of parallel threads for processing (default: 5).

## Usage
Run the script with the required parameters. Example:

```powershell
.\SearchFilesForPatterns.ps1 -TextFilesPath 'C:\MyLogs' -PatternsCsvPath '.\keywords.csv' -CheckedFilesPath 'D:\ProcessedFiles' -Recurse -ThrottleLimit 8 -UseRegex
```

This command:
- Searches for regular expression patterns from `keywords.csv` in `C:\MyLogs` and its subdirectories.
- Uses up to 8 parallel threads for processing.
- Moves checked files to `D:\ProcessedFiles\YYYYMMDD`.
- Saves results to `D:\ProcessedFiles\LogYYYYMMDD\SearchResults.csv` with log rotation.
- Removes empty folders in `C:\MyLogs`.
- Zips files in subfolders of `D:\ProcessedFiles` dated earlier than today, appending results to the corresponding `LogYYYYMMDD\SearchResults.csv`.
- Displays performance metrics and results in a GridView.

## Output
- **Search Results**: Displayed in a GridView (if matches are found) or a message box (if no matches).
- **Log Files**: Results are saved to `CheckedFilesPath\LogYYYYMMDD\SearchResults.csv`. If the file exceeds 10 MB, a new file with an incremental suffix (e.g., `SearchResults_1.csv`) is created.
- **Moved Files**: Processed files are moved to `CheckedFilesPath\YYYYMMDD`.
- **Zipped Files**: Files in subfolders dated earlier than today are zipped into `YYYYMMDD.zip`, with new files added to existing ZIPs and deleted after successful archiving.
- **Performance Metrics**: Processing time and files per second are displayed in the console.

## Notes
- Patterns are treated as literal strings unless `-UseRegex` is specified.
- Write permissions are validated for `TextFilesPath` and `CheckedFilesPath` before processing.
- Debug logging (magenta-colored output) is included to troubleshoot zipping issues.
- The script ensures files are deleted only after successful addition to ZIP archives.
- Most patterns are sourced from [PowerShellWatchlist](https://github.com/secprentice/PowerShellWatchlist/blob/master/badshell.txt) by [secprentice](https://github.com/secprentice).
- Inspired by [YossiSassi](https://github.com/YossiSassi).
- Created by Trond Hoiberg.

## License
Feel free to modify, use, and share this script.