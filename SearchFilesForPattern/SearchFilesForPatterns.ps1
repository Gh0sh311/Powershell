<#
.SYNOPSIS
    Searches through a large number of text files for specific words or patterns defined in a CSV file.
    Displays the results in a GridView, exports them to a CSV file, and moves checked files to a dated subfolder.

.DESCRIPTION
    This script automates the process of scanning multiple text files for user-defined patterns.
    It reads a list of patterns from a specified CSV file. Each pattern is then used to search
    through all text files in a target directory (and optionally its subdirectories).
    
    The script collects detailed information about each match, including the file path,
    line number, the matched line content, and the specific pattern that was found.
    
    After processing, each checked file is moved to a subfolder under E:\Transcripts\Checked,
    named with the current date in YYYYMMDD format (e.g., E:\Transcripts\Checked\20250925).
    
    Results are presented in an interactive GridView for easy viewing and filtering,
    saved to a CSV file, and a dialog box is shown if no matches are found.

.PARAMETER TextFilesPath
    Specifies the path to the directory containing the text files to search.
    Example: 'C:\MyLogs' or '.\DataFiles'

.PARAMETER PatternsCsvPath
    Specifies the path to the CSV file containing the patterns to search for.
    This CSV file must have a column named 'Pattern' (case-insensitive) that contains
    the regular expressions or literal words to search for. If no 'Pattern' column is found,
    it will attempt to use the values from the first column.
    Example: '.\patterns.csv'

.PARAMETER OutputCsvPath
    Specifies the path where the search results will be saved as a CSV file.
    Example: '.\searchResults.csv'

.PARAMETER FileTypes
    Specifies an array of file extensions to include in the search.
    Defaults to "*.txt", "*.log", "*.csv". Use "*" to search all file types.
    Example: -FileTypes "*.html", "*.xml"

.PARAMETER Recurse
    If specified, the script will search for text files in subdirectories of TextFilesPath.

.PARAMETER CaseSensitive
    If specified, the pattern matching will be case-sensitive. By default, it is case-insensitive.

.PARAMETER ThrottleLimit
    Specifies the maximum number of parallel threads for file processing. Defaults to 5.
    Increase for faster processing on multi-core systems, but monitor system resources.

.EXAMPLE
    .\SearchFilesForPatterns.ps1 -TextFilesPath 'C:\MyLogs' -PatternsCsvPath '.\keywords.csv' -OutputCsvPath '.\found_items.csv' -Recurse -ThrottleLimit 8

    This command searches for patterns defined in 'keywords.csv' within all text files
    (txt, log, csv) in 'C:\MyLogs' and its subdirectories using up to 8 parallel threads,
    moves checked files to E:\Transcripts\Checked\YYYYMMDD, saves results to 'found_items.csv',
    and displays them in GridView.

.NOTES
    Requires PowerShell 7+ for parallel processing. The 'Pattern' column in PatternsCsvPath can contain regular expressions.
    For literal word matching, ensure patterns are escaped if they contain special regex characters.
    Ensure write permissions to E:\Transcripts\Checked for moving files.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$TextFilesPath,

    [Parameter(Mandatory=$true)]
    [string]$PatternsCsvPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputCsvPath,

    [string[]]$FileTypes = @("*.txt", "*.log", "*.csv"), # Default file types

    [switch]$Recurse,

    [switch]$CaseSensitive,

    [int]$ThrottleLimit = 5
)

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7 or later for parallel processing. Current version: $($PSVersionTable.PSVersion)."
    exit 1
}

# --- Script Start ---
Write-Host "Starting file search for patterns..." -ForegroundColor Cyan

# 1. Validate paths
if (-not (Test-Path $TextFilesPath)) {
    Write-Error "Error: The specified text files path '$TextFilesPath' does not exist."
    exit 1
}
if (-not (Test-Path $PatternsCsvPath)) {
    Write-Error "Error: The specified patterns CSV path '$PatternsCsvPath' does not exist."
    exit 1
}
$baseDestination = "E:\Transcripts\Checked"
if (-not (Test-Path $baseDestination)) {
    Write-Error "Error: The destination folder '$baseDestination' does not exist or is inaccessible."
    exit 1
}

# 2. Read patterns from the CSV file
Write-Host "Reading patterns from '$PatternsCsvPath'..." -ForegroundColor Green
$patterns = @()
try {
    $csvData = Import-Csv -Path $PatternsCsvPath

    if ($csvData.Count -eq 0) {
        Write-Error "Error: The patterns CSV file '$PatternsCsvPath' is empty."
        exit 1
    }

    # Find 'Pattern' column case-insensitively and get the exact name
    $patternColumnName = $csvData | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -ieq 'Pattern' } | Select-Object -ExpandProperty Name -First 1
    
    if ($patternColumnName) {
        $patterns = $csvData.$patternColumnName | Where-Object { $_ -ne $null -and $_ -ne '' }
    } else {
        # If no 'Pattern' column, try to use the first column's values
        Write-Warning "No 'Pattern' column found in '$PatternsCsvPath'. Attempting to use values from the first column."
        $firstColumnName = ($csvData | Select-Object -First 1 | Get-Member -MemberType NoteProperty | Select-Object -First 1).Name
        if ($firstColumnName) {
            $patterns = $csvData.$firstColumnName | Where-Object { $_ -ne $null -and $_ -ne '' }
        } else {
            Write-Error "Error: Could not determine a column to use for patterns in '$PatternsCsvPath'."
            exit 1
        }
    }

    if ($patterns.Count -eq 0) {
        Write-Error "Error: No valid patterns were found in '$PatternsCsvPath'. Ensure the 'Pattern' column (or first column) contains values."
        exit 1
    }
    Write-Host "Successfully loaded $($patterns.Count) patterns." -ForegroundColor Green
}
catch {
    Write-Error "Error reading patterns from CSV '$PatternsCsvPath': $($_.Exception.Message)"
    exit 1
}

# 3. Prepare parameters for Select-String
$selectStringParams = @{
    Pattern = $patterns
}
if ($CaseSensitive) {
    $selectStringParams.Add('CaseSensitive', $true)
}

Write-Host "Searching for patterns in files under '$TextFilesPath'..." -ForegroundColor Green
if ($Recurse) { Write-Host "(Including subdirectories)" -ForegroundColor DarkGreen }
if ($CaseSensitive) { Write-Host "(Case-sensitive search)" -ForegroundColor DarkGreen }
else { Write-Host "(Case-insensitive search)" -ForegroundColor DarkGreen }
Write-Host "Searching file types: $($FileTypes -join ', ')" -ForegroundColor DarkGreen
Write-Host "Using up to $ThrottleLimit parallel threads for processing." -ForegroundColor DarkGreen

# 4. Perform the search using Select-String
$searchResults = New-Object System.Collections.ArrayList
try {
    # Get all files matching the criteria
    $filesToSearchParams = @{
        Path = $TextFilesPath
        Include = $FileTypes
        File = $true
        ErrorAction = 'SilentlyContinue'
    }
    if ($Recurse) {
        $filesToSearchParams.Add('Recurse', $true)
    }

    $filesToSearch = Get-ChildItem @filesToSearchParams

    if (-not $filesToSearch) {
        $recurseText = if ($Recurse) { ' and its subdirectories' } else { '' }
        Write-Warning "No files found matching '$($FileTypes -join ', ')' in '$TextFilesPath'$recurseText."
    } else {
        Write-Host "Found $($filesToSearch.Count) files to search." -ForegroundColor DarkGreen
        
        # Parallel processing: Each file is processed concurrently, returning match objects
        $searchResults = $filesToSearch | ForEach-Object -Parallel {
            # Define MoveCheckedLogFile function inside the parallel block
            function MoveCheckedLogFile {
                param (
                    [Parameter(Mandatory=$true)]
                    [string]$FilePath,
                    [Parameter(Mandatory=$true)]
                    [string]$BaseDestination
                )
                
                try {
                    # Get current date in YYYYMMDD format
                    $dateFolder = [datetime]::Today.ToString('yyyyMMdd')
                    $destinationFolder = Join-Path -Path $BaseDestination -ChildPath $dateFolder
                    
                    # Create the destination folder if it doesn't exist
                    New-Item -Path $destinationFolder -ItemType Directory -Force | Out-Null
                    
                    # Move the file to the destination folder
                    Move-Item -Path $FilePath -Destination $destinationFolder -Force -ErrorAction Stop
                    Write-Host "Moved '$FilePath' to '$destinationFolder'." -ForegroundColor DarkGreen
                }
                catch {
                    Write-Host "Warning: Could not move file '$FilePath': $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }

            $file = $_
            $filePath = $file.FullName
            $selectStringParams = $using:selectStringParams  # Import parameters to parallel context
            $baseDestination = $using:baseDestination  # Import destination path
            
            $fileMatches = New-Object System.Collections.ArrayList
            try {
                $matches = Select-String -LiteralPath $filePath @selectStringParams -ErrorAction SilentlyContinue
                if ($matches) {
                    $matches | ForEach-Object {
                        $null = $fileMatches.Add([PSCustomObject]@{
                            FilePath    = $_.Path
                            FileName    = $_.Filename
                            LineNumber  = $_.LineNumber
                            LineContent = $_.Line
                            PatternFound= $_.Pattern
                        })
                    }
                }
                # Move the file after processing
                MoveCheckedLogFile -FilePath $filePath -BaseDestination $baseDestination
            }
            catch {
                Write-Host "Warning: Could not process file '$filePath': $($_.Exception.Message)" -ForegroundColor Yellow
            }
            return $fileMatches
        } -ThrottleLimit $ThrottleLimit
        
        # Flatten the array of arrays into a single collection
        $searchResults = $searchResults | Where-Object { $_ -ne $null } | ForEach-Object { $_ }
        
        $totalMatches = $searchResults.Count
        Write-Host "Search finished. Found $totalMatches matches across $totalMatches unique findings." -ForegroundColor Green
    }
}
catch {
    Write-Error "An error occurred during the file search: $($_.Exception.Message)"
    exit 1
}

# 5. Display results in GridView or show dialog if no matches
Add-Type -AssemblyName System.Windows.Forms
if ($searchResults.Count -gt 0) {
    Write-Host "Displaying results in GridView (close the window to continue script execution)..." -ForegroundColor Cyan
    $searchResults | Out-GridView -Title "Search Results for Patterns"
} else {
    Write-Host "No matches found." -ForegroundColor Yellow
    [System.Windows.Forms.MessageBox]::Show("All good", "Search Results", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# 6. Export results to CSV file
Write-Host "Exporting results to '$OutputCsvPath'..." -ForegroundColor Cyan
try {
    $searchResults | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Results successfully exported to '$OutputCsvPath'." -ForegroundColor Green
}
catch {
    Write-Error "Error exporting results to CSV: $($_.Exception.Message)"
    exit 1
}

Write-Host "Script finished." -ForegroundColor Cyan