# Copilot Instructions for PowerShell Security Monitoring Scripts

## Project Overview
This repository contains modular PowerShell scripts for security monitoring, file analysis, and automation. Each script is self-contained, with its own parameters, error handling, and user interface (often using Windows Forms for dialogs and GridView display).

## Key Architectural Patterns
- **Script-Centric Design**: Each major function is implemented as a standalone script in its own folder (e.g., `SearchFilesForPattern`, `Robocopy-GUI`, `Bad-extensions-list`). Scripts do not share code or modules.
- **Parameterization**: Scripts use PowerShell `param()` blocks for configuration. Most parameters are mandatory and validated at runtime.
- **Windows Forms UI**: Many scripts use `System.Windows.Forms` for dialogs, file selection, and result display (e.g., GridView, message boxes).
- **Parallel Processing**: Scripts like `SearchFilesForPatterns.ps1` require PowerShell 7+ and use `ForEach-Object -Parallel` for performance.
- **File and Directory Operations**: Scripts move, copy, or delete files and folders, often with date-based organization (e.g., `CheckedFilesPath\YYYYMMDD`).
- **Logging and Error Handling**: Results and logs are written to CSV files, with log rotation (e.g., 10MB limit) and robust error handling. Debug output uses colored console messages.
- **Archiving**: Some scripts zip files after processing, ensuring files are deleted only after successful archiving.

## Developer Workflows
- **Run Scripts Directly**: Scripts are executed via PowerShell, e.g., `.\SearchFilesForPatterns.ps1 -TextFilesPath ...`. No build or test system is present.
- **Execution Policy**: Ensure PowerShell execution policy allows running scripts (`RemoteSigned` or `Bypass`).
- **Script-Specific Usage**: Each script has its own README and usage instructions. Always consult the relevant README for parameters and expected behavior.
- **Debugging**: Use verbose/debug output in the console (magenta for debug, green for success, yellow for warnings).

## Project-Specific Conventions
- **Date-Based Organization**: Processed files and logs are stored in folders named by date (`YYYYMMDD`).
- **CSV Pattern Files**: Pattern matching scripts expect a CSV with a `Pattern` column (case-insensitive).
- **Log Rotation**: Log files are rotated when exceeding 10MB, with incremental suffixes (e.g., `SearchResults_1.csv`).
- **Archiving Old Data**: Files in folders dated earlier than today are zipped and deleted after successful archiving.
- **Error Handling**: Scripts exit on critical errors (e.g., missing permissions, invalid parameters) and log warnings for recoverable issues.

## Integration Points
- **No External Modules**: All functionality is implemented using built-in PowerShell and .NET assemblies (e.g., `System.Windows.Forms`).
- **No CI/CD or Automated Tests**: Manual execution only; no test or build automation.
- **No Inter-Script Communication**: Scripts do not call each other or share state.

## Examples
- **SearchFilesForPatterns.ps1**: Searches files for patterns from a CSV, moves and zips files, logs results, and displays findings in a GridView.
- **Robocopy-GUI.ps1**: Provides a GUI for Robocopy operations, including progress bar and logging.
- **Extract-Unique-IDs-From-List.ps1**: Extracts unique lines from a text file, supports comment filtering, and displays results in a GridView.

## References
- See each script's README for detailed usage and conventions.
- Author: Trond Hoiberg

---

**If any conventions or workflows are unclear, please provide feedback so this guide can be improved.**
