# File Hash Checker

## Overview
File Hash Checker is a PowerShell script that provides a graphical user interface (GUI) for verifying the integrity of a file by comparing its cryptographic hash (SHA256, SHA1, or MD5) against a user-provided value. The tool supports file selection, drag-and-drop functionality, hash algorithm selection, a progress bar for hash computation, and clipboard support for copying the computed hash.

## Features
- **File Selection**: Select a file via a "Browse" button or drag-and-drop a file into the GUI.
- **Hash Algorithm Selection**: Choose from SHA256, SHA1, or MD5 algorithms.
- **Hash Verification**: Compare the computed hash of a file against a user-provided hash value.
- **Progress Bar**: Displays progress during hash computation for large files.
- **Clipboard Support**: Copy the computed hash to the clipboard with a single click.
- **Input Validation**: Ensures the provided hash matches the expected format for the selected algorithm.
- **Visual Feedback**: A status light indicates whether the hash matches (green), does not match (red), or no comparison was made (gray).
- **Error Handling**: Displays clear error messages for invalid files or hash computation failures.

## Requirements
- **Operating System**: Windows (PowerShell 5.1 or later)
- **Dependencies**: .NET Framework (for System.Windows.Forms)

## Usage
1. **Run the Script**:
   - Save the script as `FileHashChecker.ps1`.
   - Open PowerShell and navigate to the script's directory.
   - Execute the script: `.\FileHashChecker.ps1`

2. **GUI Instructions**:
   - **Select a File**: Click the "Browse" button or drag and drop a file into the file path textbox.
   - **Choose a Hash Algorithm**: Select SHA256, SHA1, or MD5 from the dropdown menu.
   - **Enter Expected Hash**: Paste the expected hash value into the provided textbox (optional).
   - **Check Hash**: Click the "Check Hash" button to compute the file's hash and compare it with the provided hash (if any).
   - **Copy Hash**: Click the "Copy Hash" button to copy the computed hash to the clipboard (enabled after hash computation).
   - **Exit**: Click the "Exit" button to close the application.

3. **Output**:
   - The computed hash is displayed in the result box.
   - If an expected hash is provided, the result box indicates whether the hashes match.
   - A status light provides visual feedback: green for a match, red for a mismatch, or gray for no comparison or errors.

## Notes
- **Supported Hash Algorithms**: SHA256 (64-character hex), SHA1 (40-character hex), MD5 (32-character hex).
- **Input Validation**: The script removes non-hex characters from the provided hash and validates its length based on the selected algorithm.
- **Performance**: A 1MB buffer is used for hash computation to handle large files efficiently, with a progress bar showing computation progress.
- **Error Handling**: The script checks for invalid file paths and hash formats, displaying appropriate error messages.
- **Updates**:
  - 25th September 2025: Added input validation, hash algorithm selection, drag-and-drop, progress bar, and clipboard support.
  - 2nd October 2025: Fixed assembly loading error and corrected a typo in hash string conversion.

## Author
- **Trond Hoiberg**

## License
This project is provided as-is, with no warranty. Feel free to use, modify, and distribute it as needed.