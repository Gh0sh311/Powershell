<#
.SYNOPSIS
    Extracts unique values from a specified text file, ignoring comments and empty lines.
    Saves the results to a new file and displays them in a GridView.

.DESCRIPTION
    This PowerShell script prompts the user to select an input text file and an output file using file dialog boxes.
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
    [Parameter(Mandatory = $false, HelpMessage = "Path to the input text file")]
    [string]$InputFile,

    [Parameter(Mandatory = $false, HelpMessage = "Path to the output text file")]
    [string]$OutputFile
)

Add-Type -AssemblyName System.Windows.Forms

try {
    # Prompt for input file if not provided
    if (-not $InputFile) {
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "Text files (*.txt;*.TXT)|*.txt;*.TXT|All files (*.*)|*.*"
        $openFileDialog.Title = "Select Input Text File"
        if ($openFileDialog.ShowDialog() -eq 'OK') {
            $InputFile = $openFileDialog.FileName
        } else {
            throw "No input file selected."
        }
        $openFileDialog.Dispose()
    }

    # Validate input file
    if (-not (Test-Path -Path $InputFile -PathType Leaf)) {
        throw "Input file '$InputFile' does not exist."
    }

    # Prompt for output file if not provided
    if (-not $OutputFile) {
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Filter = "Text files (*.txt;*.TXT)|*.txt;*.TXT|All files (*.*)|*.*"
        $saveFileDialog.Title = "Select Output Text File Location"
        $saveFileDialog.DefaultExt = "txt"
        $saveFileDialog.AddExtension = $true
        if ($saveFileDialog.ShowDialog() -eq 'OK') {
            $OutputFile = $saveFileDialog.FileName
        } else {
            throw "No output file location selected."
        }
        $saveFileDialog.Dispose()
    }

    # Validate output file path (check if directory is writable)
    $outputDir = Split-Path -Path $OutputFile -Parent
    if ($outputDir -and -not (Test-Path -Path $outputDir -PathType Container)) {
        throw "Output directory '$outputDir' does not exist."
    }

    # Check if output file already exists
    if (Test-Path -Path $OutputFile -PathType Leaf) {
        Write-Warning "Output file '$OutputFile' already exists and will be overwritten."
    }

    # Read the content of the input file
    $content = Get-Content -Path $InputFile -ErrorAction Stop

    # Filter out lines starting with '#' and empty lines, then extract unique values
    $uniqueValues = $content | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' } | Select-Object -Unique

    # Check if there are any unique values
    if (-not $uniqueValues) {
        throw "No valid data found in the input file after filtering comments and empty lines."
    }

    # Save unique values to the output file
    $uniqueValues | Out-File -FilePath $OutputFile -Encoding UTF8 -ErrorAction Stop

    # Display unique values in a GridView
    $uniqueValues | Out-GridView -Title "Unique Values from $InputFile" -ErrorAction Stop

    # Provide feedback on success
    Write-Host "Successfully extracted $($uniqueValues.Count) unique values to '$OutputFile'." -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
finally {
    # Ensure file dialogs are disposed (though already handled above)
    if ($openFileDialog) { $openFileDialog.Dispose() }
    if ($saveFileDialog) { $saveFileDialog.Dispose() }
}