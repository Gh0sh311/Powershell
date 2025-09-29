<#
.SYNOPSIS
    Searches through a large number of text files for specific words or patterns defined in a CSV file.
    Displays the results in a GridView and exports them to another CSV file.

.DESCRIPTION
    This script automates the process of scanning multiple text files for user-defined patterns.
    It reads a list of patterns from a specified CSV file. Each pattern is then used to search
    through all text files in a target directory (and optionally its subdirectories).
    
    The script collects detailed information about each match, including the file path,
    line number, the matched line content, and the specific pattern that was found.
    
    Finally, it presents these results in an interactive GridView for easy viewing and filtering,
    and saves all findings to a new CSV file for further analysis or record-keeping.

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

.EXAMPLE
    .\SearchFilesForPatterns.ps1 -TextFilesPath 'C:\MyLogs' -PatternsCsvPath '.\keywords.csv' -OutputCsvPath '.\found_items.csv' -Recurse

    This command searches for patterns defined in 'keywords.csv' within all text files
    (txt, log, csv) in 'C:\MyLogs' and its subdirectories, saving results to 'found_items.csv'
    and displaying them in GridView.

.EXAMPLE
    .\SearchFilesForPatterns.ps1 -TextFilesPath '.\Data' -PatternsCsvPath '.\regex_patterns.csv' -OutputCsvPath '.\matches.csv' -CaseSensitive -FileTypes "*.xml"

    This command performs a case-sensitive search for patterns from 'regex_patterns.csv'
    only in XML files under '.\Data', saving results to 'matches.csv'.

.NOTES
    The 'Pattern' column in the PatternsCsvPath can contain regular expressions.
    For literal word matching, ensure your patterns are escaped if they contain
    special regex characters (e.g., `[regex]::Escape("my.pattern")`).
    `Select-String` is optimized for performance, especially with large files.
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

    [switch]$CaseSensitive
)

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
    # $patterns | ForEach-Object { Write-Host "  - $_" } # Uncomment to see loaded patterns
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

# 4. Perform the search using Select-String
$searchResults = @()
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
        
        $currentFileIndex = 0
        $totalFiles = $filesToSearch.Count
        $totalMatches = 0
        
        $filesToSearch | ForEach-Object {
    $currentFileIndex++
    $file = $_  # Explicitly assign the current file object to a variable
    $filePath = $file.FullName
    
    Write-Progress -Activity "Searching files for patterns" `
                   -Status "Processing file $currentFileIndex of $totalFiles':' $($file.Name)" `
                   -PercentComplete (($currentFileIndex / $totalFiles) * 100)
    
    try {
        # Select-String is efficient for searching multiple patterns in a file
        $matches = Select-String -LiteralPath $filePath @selectStringParams -ErrorAction SilentlyContinue
        if ($matches) {
            $totalMatches += $matches.Count
            $matches | ForEach-Object {
                $searchResults += [PSCustomObject]@{
                    FilePath    = $_.Path
                    FileName    = $_.Filename
                    LineNumber  = $_.LineNumber
                    LineContent = $_.Line
                    PatternFound= $_.Pattern
                }
            }
        }
    }
    catch {
        Write-Warning "Could not process file '$filePath': $($_.Exception.Message)"
    }
}
        Write-Progress -Activity "Searching files for patterns" -Status "Search complete." -PercentComplete 100 -Completed
        Write-Host "Search finished. Found $totalMatches matches across $($searchResults.Count) unique findings." -ForegroundColor Green
    }
}
catch {
    Write-Error "An error occurred during the file search: $($_.Exception.Message)"
    exit 1
}

# 5. Display results in GridView
if ($searchResults.Count -gt 0) {
    Write-Host "Displaying results in GridView (close the window to continue script execution)..." -ForegroundColor Cyan
    $searchResults | Out-GridView -Title "Search Results for Patterns"
} else {
    Write-Host "No matches found." -ForegroundColor Yellow
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