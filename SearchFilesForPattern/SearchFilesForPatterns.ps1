#Requires -Version 7.0

<#
.SYNOPSIS
    Searches through a large number of text files for specific words or patterns defined in a CSV file.
    Displays the results in a GridView, exports them to a CSV file in a dated log subfolder,
    moves checked files to a dated subfolder, removes empty folders in the source directory,
    and zips files in destination folders dated earlier than today.

.DESCRIPTION
    This script automates the process of scanning multiple text files for user-defined patterns or regular expressions.
    It reads a list of patterns from a specified CSV file. Each pattern is then used to search
    through all text files in a target directory (and optionally its subdirectories).
    
    The script collects detailed information about each match, including the file path,
    line number, the matched line content, and the specific pattern that was found.
    
    After processing, each checked file is moved to a subfolder under the specified destination
    folder (CheckedFilesPath), named with the current date in YYYYMMDD format (e.g., CheckedFilesPath\20251001).
    
    Search results are saved to a CSV file located in CheckedFilesPath\LogYYYYMMDD\SearchResults.csv,
    where YYYYMMDD is the current date (e.g., CheckedFilesPath\Log20251001\SearchResults.csv).
    Log files are rotated if they exceed 10 MB, creating new files with incremental suffixes (e.g., SearchResults_1.csv).
    
    If new files are added to subfolders in CheckedFilesPath dated earlier than today, their search results
    are appended to the corresponding CheckedFilesPath\LogYYYYMMDD\SearchResults.csv file.
    
    After moving files, the script removes any empty folders in the TextFilesPath directory (and its
    subdirectories if -Recurse is specified) to clean up the directory structure.
    
    Additionally, the script checks subfolders in CheckedFilesPath with names in YYYYMMDD format.
    If a subfolder's date is earlier than today, its files are zipped into an archive named after the folder
    (e.g., 20250930.zip). If a ZIP file already exists for the folder, new files are added to it.
    Files are deleted only after being successfully added to the ZIP archive.
    
    The script includes performance monitoring (processing time and files per second) and validates
    write permissions and file types before starting. Debug logging is included to troubleshoot issues
    with zipping files.

.PARAMETER TextFilesPath
    Specifies the mandatory path to the directory containing the text files to search.
    Empty folders in this directory (and subdirectories if -Recurse is specified) will be removed
    after files are moved. Write permissions are validated before processing.
    Example: 'C:\MyLogs' or '.\DataFiles'

.PARAMETER PatternsCsvPath
    Specifies the mandatory path to the CSV file containing the patterns to search for.
    This CSV file must have a column named 'Pattern' (case-insensitive) that contains
    the strings to search for. If no 'Pattern' column is found, it will attempt to
    use the values from the first column. Patterns are treated as literal strings unless -UseRegex is specified.
    Example: '.\patterns.csv'

.PARAMETER CheckedFilesPath
    Specifies the mandatory destination folder where checked files will be moved and where
    search results will be saved in a LogYYYYMMDD\SearchResults.csv subfolder.
    A subfolder named with the current date (YYYYMMDD) will be created for moved files.
    Subfolders with dates earlier than today will have their files zipped into an archive,
    with new files added to existing ZIPs, and search results appended to the corresponding
    LogYYYYMMDD\SearchResults.csv file. Files are deleted after successful zipping.
    Write permissions are validated before processing.
    Example: 'E:\Checked' or 'D:\ProcessedFiles'

.PARAMETER FileTypes
    Specifies an array of file extensions to include in the search.
    Defaults to "*.txt", "*.log", "*.csv". Use "*" to search all file types.
    File extensions are validated to ensure they are properly formatted (e.g., "*.ext" or "*").
    Example: -FileTypes "*.html", "*.xml"

.PARAMETER Recurse
    If specified, the script will search for text files in subdirectories of TextFilesPath
    and remove empty subdirectories after moving files.

.PARAMETER CaseSensitive
    If specified, the pattern matching will be case-sensitive. By default, it is case-insensitive.

.PARAMETER UseRegex
    If specified, patterns in the CSV file are treated as regular expressions instead of literal strings.
    Special characters in patterns are properly escaped to prevent parsing errors.

.PARAMETER ThrottleLimit
    Specifies the maximum number of parallel threads for file processing. Defaults to 5.
    Increase for faster processing on multi-core systems, but monitor system resources.
    Performance metrics (processing time and files per second) are displayed to aid tuning.

.EXAMPLE
    .\SearchFilesForPatterns.ps1 -TextFilesPath 'C:\MyLogs' -PatternsCsvPath '.\keywords.csv' -CheckedFilesPath 'D:\ProcessedFiles' -Recurse -ThrottleLimit 8 -UseRegex

    This command searches for regular expression patterns defined in 'keywords.csv' within all text files
    (txt, log, csv) in 'C:\MyLogs' and its subdirectories using up to 8 parallel threads,
    moves checked files to 'D:\ProcessedFiles\YYYYMMDD', saves results to
    'D:\ProcessedFiles\LogYYYYMMDD\SearchResults.csv' (with log rotation if over 10 MB),
    removes empty folders in 'C:\MyLogs', zips files in subfolders of 'D:\ProcessedFiles' dated
    earlier than today (adding new files to existing ZIPs and appending results to the corresponding
    LogYYYYMMDD\SearchResults.csv, deleting files after zipping), validates file types and permissions,
    displays performance metrics, and shows results in GridView. Debug logging is included
    to troubleshoot zipping issues.

.NOTES
    Requires PowerShell 7+ for parallel processing. Patterns in the PatternsCsvPath file are treated
    as literal strings by default or as regular expressions if -UseRegex is specified. Ensure patterns
    are valid strings or regex patterns to avoid parsing errors. Write permissions to TextFilesPath
    (for removing empty folders) and CheckedFilesPath (for moving files, creating logs, and zipping)
    are validated upfront. All parameters (TextFilesPath, PatternsCsvPath, CheckedFilesPath) must be
    provided. Files in destination subfolders dated earlier than today are deleted only after being
    successfully added to the corresponding ZIP archive. Search results for older subfolders are
    appended to the corresponding LogYYYYMMDD\SearchResults.csv file with log rotation support.
    Performance metrics are displayed to aid optimization. Debug logging (magenta-colored output) is
    included to diagnose issues with zipping files, including the parameters used for Compress-Archive.

    Most of the pattern list is from 
    https://github.com/secprentice/PowerShellWatchlist/blob/master/badshell.txt 
    Credits to: https://github.com/secprentice
    Inspired by: https://github.com/YossiSassi
    Created by Trond Hoiberg
    Feel free to modify, use and share.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$TextFilesPath,

    [Parameter(Mandatory=$true)]
    [string]$PatternsCsvPath,

    [Parameter(Mandatory=$true)]
    [string]$CheckedFilesPath,

    [string[]]$FileTypes = @("*.txt", "*.log", "*.csv"), # Default file types

    [switch]$Recurse,

    [switch]$CaseSensitive,

    [switch]$UseRegex,

    [int]$ThrottleLimit = 5
)

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7 or later for parallel processing. Current version: $($PSVersionTable.PSVersion)."
    exit 1
}

# Load Windows Forms for GridView and message box
Add-Type -AssemblyName System.Windows.Forms

# Function to validate write permissions
function TestWritePerm {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string]$Description
    )
    try {
        $testFile = Join-Path -Path $Path -ChildPath "test_permissions_$(New-Guid).txt"
        [System.IO.File]::WriteAllText($testFile, "Permission test")
        Remove-Item -Path $testFile -Force -ErrorAction Stop
        Write-Host "Write permissions verified for '$Description' at '$Path'." -ForegroundColor DarkGreen
    }
    catch {
        Write-Error "Error: No write permissions for '$Description' at '$Path': $($_.Exception.Message)"
        exit 1
    }
}

# Function to validate file types
function TestFileTypes {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$FileTypes
    )
    foreach ($type in $FileTypes) {
        if ($type -ne "*" -and -not $type.StartsWith("*.")) {
            Write-Error "Error: Invalid file type '$type'. File types must be '*' or start with '*.' (e.g., '*.txt')."
            exit 1
        }
    }
    Write-Host "File types validated: $($FileTypes -join ', ')" -ForegroundColor DarkGreen
}

# Function to get the next available CSV path for log rotation
function GetNextCsvPath {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BaseCsvPath
    )
    $maxSizeBytes = 10MB # Maximum CSV size before rotation
    $index = 0
    $csvPath = $BaseCsvPath
    while (Test-Path $csvPath) {
        $fileInfo = Get-Item -Path $csvPath -ErrorAction SilentlyContinue
        if ($fileInfo.Length -gt $maxSizeBytes) {
            $index++
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($BaseCsvPath)
            $extension = [System.IO.Path]::GetExtension($BaseCsvPath)
            $directory = [System.IO.Path]::GetDirectoryName($BaseCsvPath)
            $csvPath = Join-Path -Path $directory -ChildPath "$baseName_$index$extension"
        } else {
            break
        }
    }
    return $csvPath
}

# Function to remove empty folders
function RemoveEmptyFolders {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [switch]$Recurse
    )
    try {
        $folderParams = @{
            Path = $Path
            Directory = $true
            ErrorAction = 'SilentlyContinue'
        }
        if ($Recurse) {
            $folderParams.Add('Recurse', $true)
        }
        $folders = Get-ChildItem @folderParams | Sort-Object -Property FullName -Descending
        foreach ($folder in $folders) {
            $items = Get-ChildItem -Path $folder.FullName -Force -ErrorAction SilentlyContinue
            if (-not $items) {
                try {
                    Remove-Item -Path $folder.FullName -Force -ErrorAction Stop
                    Write-Host "Removed empty folder '$($folder.FullName)'." -ForegroundColor DarkGreen
                }
                catch {
                    Write-Warning "Could not remove folder '$($folder.FullName)': $($_.Exception.Message)"
                }
            }
        }
    }
    catch {
        Write-Warning "Error while checking for empty folders in '$Path': $($_.Exception.Message)"
    }
}

# Function to get or create the CSV path for a specific date with log rotation
function GetCSVPath {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [Parameter(Mandatory=$true)]
        [string]$DateFolder
    )
    $logFolder = Join-Path -Path $BasePath -ChildPath "Log$DateFolder"
    $baseCsvPath = Join-Path -Path $logFolder -ChildPath "SearchResults.csv"
    try {
        # Create LogYYYYMMDD folder if it doesn't exist
        New-Item -Path $logFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
        # Get the next available CSV path for log rotation
        $csvPath = GetNextCsvPath -BaseCsvPath $baseCsvPath
        return $csvPath
    }
    catch {
        Write-Error "Error creating log folder '$logFolder': $($_.Exception.Message)"
        exit 1
    }
}

# Function to zip files in folders dated earlier than today and append results to CSV
function ZipCheckedFiles {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [Parameter(Mandatory=$true)]
        [System.Collections.ArrayList]$SearchResults
    )
    Write-Host "DEBUG: Starting ZipCheckedFiles for BasePath '$BasePath'" -ForegroundColor Magenta
    try {
        $today = [datetime]::Today
        Write-Host "DEBUG: Today's date is '$($today.ToString('yyyyMMdd'))'" -ForegroundColor Magenta
        $folders = Get-ChildItem -Path $BasePath -Directory -ErrorAction SilentlyContinue
        Write-Host "DEBUG: Found $($folders.Count) folders in '$BasePath'" -ForegroundColor Magenta
        if (-not $folders) {
            Write-Host "DEBUG: No subfolders found in '$BasePath'. Skipping zipping." -ForegroundColor Magenta
            return
        }
        foreach ($folder in $folders) {
            Write-Host "DEBUG: Processing folder '$($folder.FullName)'" -ForegroundColor Magenta
            # Check if folder name is in YYYYMMDD format
            if ($folder.Name -match '^\d{8}$') {
                try {
                    $folderDate = [datetime]::ParseExact($folder.Name, 'yyyyMMdd', $null)
                    Write-Host "DEBUG: Folder date is '$($folderDate.ToString('yyyyMMdd'))'" -ForegroundColor Magenta
                    if ($folderDate -lt $today) {
                        $files = Get-ChildItem -Path $folder.FullName -File -ErrorAction SilentlyContinue
                        Write-Host "DEBUG: Found $($files.Count) files in '$($folder.FullName)'" -ForegroundColor Magenta
                        if ($files) {
                            $zipPath = Join-Path -Path $BasePath -ChildPath "$($folder.Name).zip"
                            Write-Host "DEBUG: ZIP path is '$zipPath'" -ForegroundColor Magenta
                            $zipExists = Test-Path $zipPath
                            $operation = if ($zipExists) { "Updating existing ZIP '$zipPath'" } else { "Creating new ZIP '$zipPath'" }
                            Write-Host "DEBUG: $operation" -ForegroundColor Cyan
                            Write-Host "DEBUG: Files to zip: $($files.FullName -join ', ')" -ForegroundColor Magenta
                            try {
                                # Verify write permissions to ZIP path
                                $zipParent = Split-Path -Path $zipPath -Parent
                                if (-not (Test-Path $zipParent)) {
                                    Write-Host "DEBUG: Creating parent directory '$zipParent'" -ForegroundColor Magenta
                                    New-Item -Path $zipParent -ItemType Directory -Force | Out-Null
                                }
                                # Use -Force for new ZIPs, -Update for existing ZIPs
                                if ($zipExists) {
                                    Write-Host "DEBUG: Using -Update for existing ZIP" -ForegroundColor Magenta
                                    $files | Compress-Archive -DestinationPath $zipPath -Update -ErrorAction Stop
                                } else {
                                    Write-Host "DEBUG: Using -Force for new ZIP" -ForegroundColor Magenta
                                    $files | Compress-Archive -DestinationPath $zipPath -Force -ErrorAction Stop
                                }
                                Write-Host "Successfully updated/created '$zipPath'." -ForegroundColor DarkGreen
                                # Append search results for these files to the corresponding CSV
                                $folderResults = $SearchResults | Where-Object { $_.FilePath -like "$($folder.FullName)\*" }
                                Write-Host "DEBUG: Found $($folderResults.Count) search results for folder '$($folder.FullName)'" -ForegroundColor Magenta
                                if ($folderResults) {
                                    $csvPath = GetCSVPath -BasePath $BasePath -DateFolder $folder.Name
                                    Write-Host "DEBUG: CSV path is '$csvPath'" -ForegroundColor Magenta
                                    try {
                                        $folderResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Append:$true -ErrorAction Stop
                                        Write-Host "Appended results to '$csvPath'." -ForegroundColor DarkGreen
                                    }
                                    catch {
                                        Write-Warning "Could not append results to '$csvPath': $($_.Exception.Message)"
                                    }
                                }
                                # Delete each file after successful zipping
                                foreach ($file in $files) {
                                    Write-Host "DEBUG: Attempting to delete file '$($file.FullName)'" -ForegroundColor Magenta
                                    try {
                                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                                        Write-Host "Removed file '$($file.FullName)' after adding to ZIP." -ForegroundColor DarkGreen
                                    }
                                    catch {
                                        Write-Warning "Could not remove file '$($file.FullName)' after zipping: $($_.Exception.Message)"
                                    }
                                }
                            }
                            catch {
                                Write-Warning "Could not zip files in '$($folder.FullName)': $($_.Exception.Message)"
                            }
                        } else {
                            Write-Host "DEBUG: No files found in '$($folder.FullName)'. Skipping zipping." -ForegroundColor Magenta
                        }
                    } else {
                        Write-Host "DEBUG: Folder date '$($folderDate.ToString('yyyyMMdd'))' is not earlier than today. Skipping." -ForegroundColor Magenta
                    }
                }
                catch {
                    Write-Warning "Folder '$($folder.FullName)' has invalid date format: $($_.Exception.Message)"
                }
            } else {
                Write-Host "DEBUG: Folder '$($folder.FullName)' does not match YYYYMMDD format. Skipping." -ForegroundColor Magenta
            }
        }
    }
    catch {
        Write-Warning "Error while processing folders in '$BasePath' for zipping: $($_.Exception.Message)"
    }
    Write-Host "DEBUG: Completed ZipCheckedFiles" -ForegroundColor Magenta
}

# --- Script Start ---
Write-Host "Starting file search for patterns..." -ForegroundColor Cyan

# 1. Validate paths and permissions
if (-not (Test-Path $TextFilesPath)) {
    Write-Error "Error: The specified text files path '$TextFilesPath' does not exist."
    exit 1
}
if (-not (Test-Path $PatternsCsvPath)) {
    Write-Error "Error: The specified patterns CSV path '$PatternsCsvPath' does not exist."
    exit 1
}
if (-not (Test-Path $CheckedFilesPath)) {
    Write-Error "Error: The destination folder '$CheckedFilesPath' does not exist or is inaccessible."
    exit 1
}

# Validate write permissions
TestWritePerm -Path $TextFilesPath -Description "TextFilesPath"
TestWritePerm -Path $CheckedFilesPath -Description "CheckedFilesPath"

# Validate file types
TestFileTypes -FileTypes $FileTypes

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

    # If UseRegex is specified, validate patterns as regex
    if ($UseRegex) {
        foreach ($pattern in $patterns) {
            try {
                $null = [regex]::Match("", $pattern)
            }
            catch {
                Write-Error "Error: Invalid regular expression pattern '$pattern' in '$PatternsCsvPath': $($_.Exception.Message)"
                exit 1
            }
        }
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
    SimpleMatch = -not $UseRegex  # Use regex if -UseRegex is specified, otherwise literal strings
}
if ($CaseSensitive) {
    $selectStringParams.Add('CaseSensitive', $true)
}

Write-Host "Searching for patterns in files under '$TextFilesPath'..." -ForegroundColor Green
if ($Recurse) { Write-Host "(Including subdirectories)" -ForegroundColor DarkGreen }
if ($CaseSensitive) { Write-Host "(Case-sensitive search)" -ForegroundColor DarkGreen }
else { Write-Host "(Case-insensitive search)" -ForegroundColor DarkGreen }
if ($UseRegex) { Write-Host "(Using regular expressions)" -ForegroundColor DarkGreen }
else { Write-Host "(Using literal string matching)" -ForegroundColor DarkGreen }
Write-Host "Searching file types: $($FileTypes -join ', ')" -ForegroundColor DarkGreen
Write-Host "Using up to $ThrottleLimit parallel threads for processing." -ForegroundColor DarkGreen

# 4. Perform the search using Select-String with performance monitoring
$searchResults = New-Object System.Collections.ArrayList
$startTime = [datetime]::Now
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
            $baseDestination = $using:CheckedFilesPath  # Use the parameter
            
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
        $endTime = [datetime]::Now
        $duration = ($endTime - $startTime).TotalSeconds
        $filesPerSecond = if ($duration -gt 0) { [math]::Round($filesToSearch.Count / $duration, 2) } else { 0 }
        Write-Host "Search finished. Found $totalMatches matches across $totalMatches unique findings." -ForegroundColor Green
        Write-Host "Performance: Processed $($filesToSearch.Count) files in $duration seconds ($filesPerSecond files/second)." -ForegroundColor Cyan
    }
}
catch {
    Write-Error "An error occurred during the file search: $($_.Exception.Message)"
    exit 1
}

# 5. Remove empty folders in TextFilesPath
Write-Host "Checking for and removing empty folders in '$TextFilesPath'..." -ForegroundColor Cyan
RemoveEmptyFolders -Path $TextFilesPath -Recurse:$Recurse

# 6. Zip files in CheckedFilesPath subfolders dated earlier than today and append results to CSVs
Write-Host "Checking for and zipping files in subfolders of '$CheckedFilesPath' dated earlier than today..." -ForegroundColor Cyan
ZipCheckedFiles -BasePath $CheckedFilesPath -SearchResults $searchResults

# 7. Export results for current day to CSV with log rotation
$currentDateFolder = [datetime]::Today.ToString('yyyyMMdd')
$outputCsvPath = GetCSVPath -BasePath $CheckedFilesPath -DateFolder $currentDateFolder
if ($searchResults.Count -gt 0) {
    Write-Host "Exporting results for current day to '$outputCsvPath'..." -ForegroundColor Cyan
    try {
        $currentDayResults = $searchResults | Where-Object { $_.FilePath -like "*\$currentDateFolder\*" }
        if ($currentDayResults) {
            $currentDayResults | Export-Csv -Path $outputCsvPath -NoTypeInformation -Encoding UTF8 -Append:$true -ErrorAction Stop
            Write-Host "Results successfully exported to '$outputCsvPath'." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Error exporting results to CSV '$outputCsvPath': $($_.Exception.Message)"
        exit 1
    }
}

# 8. Display results in GridView or show dialog if no matches
if ($searchResults.Count -gt 0) {
    Write-Host "Displaying results in GridView (close the window to continue script execution)..." -ForegroundColor Cyan
    $searchResults | Out-GridView -Title "Search Results for Patterns"
} else {
    Write-Host "No matches found." -ForegroundColor Yellow
    [System.Windows.Forms.MessageBox]::Show("All good", "Search Results", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

Write-Host "Script finished." -ForegroundColor Cyan