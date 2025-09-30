<#
.SYNOPSIS
    Extracts unique values from a specified text file, ignoring comments and empty lines.
    Saves the results to a new file and displays them in a GridView.

.DESCRIPTION
    his PowerShell script prompts the user to select an input text file and an output file using file dialog boxes.
    It reads the input file, removes lines starting with '#' and empty lines, extracts unique lines,
    saves them to the output file, and displays the results in a GridView. The script includes
    error handling for file operations and parameter validation.

.PARAMETER InputFile
    The path to the input text file containing the values to process. If not provided, a file dialog prompts the user to select a file.

.PARAMETER OutputFile
    The path to the output text file where unique values will be saved. If not provided, a file dialog prompts the user to select a save location.

.EXAMPLE
    .\Extract-UniqueValues.ps1
    Prompts the user to select input and output files, extracts unique values, saves them to the output file, and displays them in a GridView.

.EXAMPLE
    .\Extract-UniqueValues.ps1 -InputFile "list.txt" -OutputFile "unique.txt"
    Reads list.txt, extracts unique values, saves them to unique.txt, and displays them in a GridView.
#>

param (
    [Parameter(Mandatory=$false, HelpMessage="Path to the input text file")]
    [string]$InputFile,

    [Parameter(Mandatory=$false, HelpMessage="Path to the output text file")]
    [string]$OutputFile
)

Add-Type -AssemblyName System.Windows.Forms

try {
    # Prompt for input file if not provided
    if (-not $InputFile) {
        $ofDialog = New-Object System.Windows.Forms.OpenFileDialog
        $ofDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        $ofDialog.Title = "Select Input Text File"
        if ($ofDialog.ShowDialog() -eq 'OK') {
            $InputFile = $ofDialog.FileName
        } else {
            throw "No input file selected."
        }
    }

    # Validate input file
    if (-not (Test-Path $InputFile -PathType Leaf)) {
        throw "Input file '$InputFile' does not exist."
    }

    # Prompt for output file if not provided
    if (-not $OutputFile) {
        $sfDialog = New-Object System.Windows.Forms.SaveFileDialog
        $sfDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        $sfDialog.Title = "Select Output Text File Location"
        $sfDialog.DefaultExt = "txt"
        $sfDialog.AddExtension = $true
        if ($sfDialog.ShowDialog() -eq 'OK') {
            $OutputFile = $sfDialog.FileName
        } else {
            throw "No output file location selected."
        }
    }

    # Read the content of the input file
    $content = Get-Content -Path $InputFile -ErrorAction Stop

    # Filter out lines starting with '#' and empty lines, then extract unique values
    $unqValues = $content | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' } | Select-Object -Unique

    # Check if there are any unique values
    if (-not $unqValues) {
        throw "No valid data found in the input file after filtering comments and empty lines."
    }

    # Save unique values to the output file
    $unqValues | Out-File -FilePath $OutputFile -Encoding UTF8 -ErrorAction Stop

    # Display unique values in a GridView
    $unqValues | Out-GridView -Title "Unique Values from $InputFile" -ErrorAction Stop

    Write-Host "Successfully extracted unique values to $OutputFile and displayed in GridView." -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show("An error occurred: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Cyan
}

