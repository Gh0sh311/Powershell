<#
.SYNOPSIS
    Extracts unique values from a specified text file, ignoring comments and empty lines.
    Saves the results to a new file and displays them in a GridView.

.DESCRIPTION
    This PowerShell script prompts the user to select an input text file and an output file using file dialog boxes.
    It reads the input file, removes lines starting with a specified comment character (default '#') and empty lines,
    extracts unique lines, saves them to the output file with a specified encoding, and displays the results in a GridView.
    The script includes error handling, performance optimization for large files, and logging for auditing.

.PARAMETER InputFile
    The path to the input text file containing the values to process. If not provided, a file dialog prompts the user to select a file.

.PARAMETER OutFile
    The path to the output text file where unique values will be saved. If not provided, a file dialog prompts the user to select a save location.

.PARAMETER CommentChar
    The character that indicates a comment line (default: '#'). Lines starting with this character are ignored.

.PARAMETER Encoding
    The encoding for the output file (default: 'UTF8'). Valid options: 'UTF8', 'ASCII', 'Unicode', 'UTF32'.

.PARAMETER LogFile
    The path to a log file for recording script operations. If not provided, no log file is created.

.EXAMPLE
    .\Extract-UniqueValues.ps1
    Prompts the user to select input and output files, extracts unique values, saves them to the output file, and displays them in a GridView.

.EXAMPLE
    .\Extract-UniqueValues.ps1 -InputFile "list.txt" -OutFile "unique.txt" -CommentChar "//" -Encoding "ASCII" -LogFile "script.log"
    Reads list.txt, ignores lines starting with '//', saves unique values to unique.txt in ASCII encoding, logs operations to script.log, and displays results in a GridView.

    This work is based on https://github.com/palant/malicious-extensions-list/blob/main/list.txt
    Credit to https://github.com/palant
    Created by Trond Hoiberg
    Feel free to modify, use and share.
    This script is provided as-is without any warranty.
    
#>

param (
    [Parameter(Mandatory = $false, HelpMessage = "Path to the input text file")]
    [string]$InputFile,

    [Parameter(Mandatory = $false, HelpMessage = "Path to the output text file")]
    [string]$OutFile,

    [Parameter(Mandatory = $false, HelpMessage = "Character indicating a comment line")]
    [string]$CommentChar = '#',

    [Parameter(Mandatory = $false, HelpMessage = "Encoding for the output file")]
    [ValidateSet('UTF8', 'ASCII', 'Unicode', 'UTF32')]
    [string]$Encoding = 'UTF8',

    [Parameter(Mandatory = $false, HelpMessage = "Path to the log file")]
    [string]$LogFile
)

# Function to write to log file if specified
function Write-Log {
    param (
        [string]$Message
    )
    if ($LogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    }
}

Add-Type -AssemblyName System.Windows.Forms

try {
    # Initialize logging
    if ($LogFile) {
        Write-Log "Script started."
    }

    # Prompt for input file if not provided
    if (-not $InputFile) {
        $of = New-Object System.Windows.Forms.OpenFileDialog
        $of.Filter = "Text files (*.txt;*.TXT)|*.txt;*.TXT|All files (*.*)|*.*"
        $of.Title = "Select Input Text File"
        if ($of.ShowDialog() -eq 'OK') {
            $InputFile = $of.FileName
            Write-Log "Input file selected: $InputFile"
        } else {
            throw "No input file selected."
        }
        $of.Dispose()
    }

    # Validate input file
    if (-not (Test-Path -Path $InputFile -PathType Leaf)) {
        $errorMsg = "Input file '$InputFile' does not exist."
        Write-Log $errorMsg
        throw $errorMsg
    }

    # Prompt for output file if not provided
    if (-not $OutFile) {
        $sf = New-Object System.Windows.Forms.SaveFileDialog
        $sf.Filter = "Text files (*.txt;*.TXT)|*.txt;*.TXT|All files (*.*)|*.*"
        $sf.Title = "Select Output Text File Location"
        $sf.DefaultExt = "txt"
        $sf.AddExtension = $true
        if ($sf.ShowDialog() -eq 'OK') {
            $OutFile = $sf.FileName
            Write-Log "Output file selected: $OutFile"
        } else {
            throw "No output file location selected."
        }
        $sf.Dispose()
    }

    # Validate output file path
    $outDir = Split-Path -Path $OutFile -Parent
    if ($outDir -and -not (Test-Path -Path $outDir -PathType Container)) {
        $errorMsg = "Output directory '$outDir' does not exist."
        Write-Log $errorMsg
        throw $errorMsg
    }

    # Check if output file already exists
    if (Test-Path -Path $OutFile -PathType Leaf) {
        Write-Warning "Output file '$OutFile' already exists and will be overwritten."
        Write-Log "Output file '$OutFile' already exists and will be overwritten."
    }

    # Escape comment character for regex
    $escapedCommentChar = [regex]::Escape($CommentChar)

    # Read file using StreamReader for performance
    $uValue = New-Object System.Collections.Generic.HashSet[string]
    try {
        $reader = [System.IO.StreamReader]::new($InputFile)
        Write-Log "Reading input file: $InputFile"
        while (($line = $reader.ReadLine()) -ne $null) {
            if ($line -notmatch "^\s*$escapedCommentChar" -and $line -notmatch '^\s*$') {
                [void]$uValue.Add($line)
            }
        }
        $reader.Close()
    } catch {
        $errorMsg = "Error reading input file: $($_.Exception.Message)"
        Write-Log $errorMsg
        throw $errorMsg
    } finally {
        if ($reader) { $reader.Dispose() }
    }

    # Check if there are any unique values
    if ($uValue.Count -eq 0) {
        $errorMsg = "No valid data found in the input file after filtering comments and empty lines."
        Write-Log $errorMsg
        throw $errorMsg
    }

    # Save unique values to the output file
    $uValue | Out-File -FilePath $OutFile -Encoding $Encoding -ErrorAction Stop
    Write-Log "Saved $($uValue.Count) unique values to '$OutFile' with $Encoding encoding."

    # Display unique values in a GridView
    $uValue | Out-GridView -Title "Unique Values from $InputFile" -ErrorAction Stop
    Write-Log "Displayed unique values in GridView."

    # Provide feedback on success
    Write-Host "Successfully extracted $($uValue.Count) unique values to '$OutFile'." -ForegroundColor Green
    Write-Log "Script completed successfully."
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    if ($LogFile) {
        Write-Log "Error: $($_.Exception.Message)"
    }
}
finally {
    # Ensure file dialogs and reader are disposed
    if ($of) { $of.Dispose() }
    if ($sf) { $sf.Dispose() }
    if ($reader) { $reader.Dispose() }
}