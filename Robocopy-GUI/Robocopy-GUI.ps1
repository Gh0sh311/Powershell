<#
.SYNOPSIS
    Every now and then i need to use Robocopy and to simplify a bit, i made this.

.DESCRIPTION
    This script generates a GUI that will make it easier to use Robocopy. It has most of the common parameters that i use when using Robocopy.
    It will present a dialog asking if you are sure if you use the Move option. 

.NOTES
    Requires PowerShell 5.1+
    Feel free to modify/use
    Trond Hoiberg 30th September 2025
#>

# Load required assemblies for Windows Forms and Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form window
$frm = New-Object System.Windows.Forms.Form
$frm.Text = "Robocopy GUI"  # Set window title
$frm.Size = New-Object System.Drawing.Size(800, 600)  # Set window dimensions
$frm.StartPosition = "CenterScreen"  # Center the window on the screen

# Initialize ToolTip object for providing hover descriptions
$ttip = New-Object System.Windows.Forms.ToolTip
$ttip.AutoPopDelay = 5000  # Duration tooltip remains visible
$ttip.InitialDelay = 500  # Delay before tooltip appears
$ttip.ReshowDelay = 500  # Delay for subsequent tooltips

# Source path label
$lblSource = New-Object System.Windows.Forms.Label
$lblSource.Text = "Source Path:"
$lblSource.Location = New-Object System.Drawing.Point(10, 10)
$lblSource.Size = New-Object System.Drawing.Size(100, 20)
$frm.Controls.Add($lblSource)

# Textbox for entering source path (local or UNC)
$txtSource = New-Object System.Windows.Forms.TextBox
$txtSource.Location = New-Object System.Drawing.Point(120, 10)
$txtSource.Size = New-Object System.Drawing.Size(550, 20)
$ttip.SetToolTip($txtSource, "Enter a local path (e.g., C:\Folder) or UNC path (e.g., \\server\share\folder).")
$frm.Controls.Add($txtSource)

# Button to browse for source folder
$btnBrowseSource = New-Object System.Windows.Forms.Button
$btnBrowseSource.Text = "Browse"
$btnBrowseSource.Location = New-Object System.Drawing.Point(680, 10)
$btnBrowseSource.Size = New-Object System.Drawing.Size(75, 23)
$btnBrowseSource.Add_Click({
    # Open folder browser dialog for selecting source
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select Source Folder (supports UNC paths)"
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $txtSource.Text = $folderBrowser.SelectedPath
    }
})
$frm.Controls.Add($btnBrowseSource)

# Destination path label
$lblDestination = New-Object System.Windows.Forms.Label
$lblDestination.Text = "Destination Path:"
$lblDestination.Location = New-Object System.Drawing.Point(10, 40)
$lblDestination.Size = New-Object System.Drawing.Size(100, 20)
$frm.Controls.Add($lblDestination)

# Textbox for entering destination path (local or UNC)
$txtDestination = New-Object System.Windows.Forms.TextBox
$txtDestination.Location = New-Object System.Drawing.Point(120, 40)
$txtDestination.Size = New-Object System.Drawing.Size(550, 20)
$ttip.SetToolTip($txtDestination, "Enter a local path (e.g., D:\Folder) or UNC path (e.g., \\server\share\folder).")
$frm.Controls.Add($txtDestination)

# Button to browse for destination folder
$btnBrowseDestination = New-Object System.Windows.Forms.Button
$btnBrowseDestination.Text = "Browse"
$btnBrowseDestination.Location = New-Object System.Drawing.Point(680, 40)
$btnBrowseDestination.Size = New-Object System.Drawing.Size(75, 23)
$btnBrowseDestination.Add_Click({
    # Open folder browser dialog for selecting destination
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select Destination Folder (supports UNC paths)"
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $txtDestination.Text = $folderBrowser.SelectedPath
    }
})
$frm.Controls.Add($btnBrowseDestination)

# Group box for operation selection (Copy or Move)
$grpOperation = New-Object System.Windows.Forms.GroupBox
$grpOperation.Text = "Operation"
$grpOperation.Location = New-Object System.Drawing.Point(10, 70)
$grpOperation.Size = New-Object System.Drawing.Size(200, 60)
$frm.Controls.Add($grpOperation)

# Radio button for Copy operation
$radioCopy = New-Object System.Windows.Forms.RadioButton
$radioCopy.Text = "Copy"
$radioCopy.Location = New-Object System.Drawing.Point(10, 20)
$radioCopy.Checked = $true
$grpOperation.Controls.Add($radioCopy)

# Radio button for Move operation
$radioMove = New-Object System.Windows.Forms.RadioButton
$radioMove.Text = "Move"
$radioMove.Location = New-Object System.Drawing.Point(120, 20)
$grpOperation.Controls.Add($radioMove)

# Checkbox for enabling progress estimation (optional for speed optimization)
$chkProgressEst = New-Object System.Windows.Forms.CheckBox
$chkProgressEst.Text = "Enable Progress Estimation (may slow start for large dirs)"
$chkProgressEst.Location = New-Object System.Drawing.Point(250, 80)
$chkProgressEst.Size = New-Object System.Drawing.Size(350, 20)
$chkProgressEst.Checked = $true
$ttip.SetToolTip($chkProgressEst, "Counts files beforehand for accurate progress; disable for faster startup on large sources.")
$frm.Controls.Add($chkProgressEst)

# Tab control for organizing advanced options
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 150)
$tabControl.Size = New-Object System.Drawing.Size(765, 190)
$frm.Controls.Add($tabControl)

# Tab for Copy Options
$tabCopyOptions = New-Object System.Windows.Forms.TabPage
$tabCopyOptions.Text = "Copy Options"
$tabControl.Controls.Add($tabCopyOptions)

# Checkbox for /COPY:DAT (data, attributes, timestamps)
$chkCopyDAT = New-Object System.Windows.Forms.CheckBox
$chkCopyDAT.Text = "Copy Data, Attributes, Timestamps (/COPY:DAT)"
$chkCopyDAT.Location = New-Object System.Drawing.Point(10, 10)
$chkCopyDAT.Size = New-Object System.Drawing.Size(300, 20)
$chkCopyDAT.Checked = $true
$ttip.SetToolTip($chkCopyDAT, "Copies file data, attributes, and timestamps.")
$tabCopyOptions.Controls.Add($chkCopyDAT)

# Checkbox for /COPYALL (all file info)
$chkCopyAll = New-Object System.Windows.Forms.CheckBox
$chkCopyAll.Text = "Copy All File Info (/COPYALL) - Requires Admin"
$chkCopyAll.Location = New-Object System.Drawing.Point(10, 40)
$chkCopyAll.Size = New-Object System.Drawing.Size(350, 20)
$ttip.SetToolTip($chkCopyAll, "Copies all file info including auditing (REQUIRES ADMINISTRATOR RIGHTS). Uncheck if running as normal user.")
$tabCopyOptions.Controls.Add($chkCopyAll)

# Checkbox for /CREATE (directory structure only)
$chkNoCopy = New-Object System.Windows.Forms.CheckBox
$chkNoCopy.Text = "No Copy, Only Directory Structure (/CREATE)"
$chkNoCopy.Location = New-Object System.Drawing.Point(10, 70)
$chkNoCopy.Size = New-Object System.Drawing.Size(300, 20)
$ttip.SetToolTip($chkNoCopy, "Creates directory structure but does not copy files.")
$tabCopyOptions.Controls.Add($chkNoCopy)

# Checkbox for /MIR (mirror, with deletions)
$chkMirror = New-Object System.Windows.Forms.CheckBox
$chkMirror.Text = "Mirror Directory (/MIR)"
$chkMirror.Location = New-Object System.Drawing.Point(10, 100)
$chkMirror.Size = New-Object System.Drawing.Size(300, 20)
$ttip.SetToolTip($chkMirror, "Mirrors source to destination, deleting files in destination not in source. Includes /E.")
$tabCopyOptions.Controls.Add($chkMirror)

# Checkbox for /E (subdirectories, including empty)
$chkSubdirs = New-Object System.Windows.Forms.CheckBox
$chkSubdirs.Text = "Include Subdirectories (/E)"
$chkSubdirs.Location = New-Object System.Drawing.Point(10, 130)
$chkSubdirs.Size = New-Object System.Drawing.Size(300, 20)
$chkSubdirs.Checked = $true
$ttip.SetToolTip($chkSubdirs, "Copies subdirectories, including empty ones.")
$tabCopyOptions.Controls.Add($chkSubdirs)

# Checkbox for including empty directories (redundant with /E but explicit)
$chkEmptyDirs = New-Object System.Windows.Forms.CheckBox
$chkEmptyDirs.Text = "Include Empty Directories (/E)"
$chkEmptyDirs.Location = New-Object System.Drawing.Point(320, 130)
$chkEmptyDirs.Size = New-Object System.Drawing.Size(300, 20)
$chkEmptyDirs.Checked = $true
$ttip.SetToolTip($chkEmptyDirs, "Ensures empty directories are copied. Included with /E.")
$tabCopyOptions.Controls.Add($chkEmptyDirs)

# Tab for File Selection
$tabFileSelection = New-Object System.Windows.Forms.TabPage
$tabFileSelection.Text = "File Selection"
$tabControl.Controls.Add($tabFileSelection)

# Checkbox for /LEV:0 (top-level files only)
$chkOnlyFiles = New-Object System.Windows.Forms.CheckBox
$chkOnlyFiles.Text = "Copy Only Files, No Subdirs (/LEV:0)"
$chkOnlyFiles.Location = New-Object System.Drawing.Point(10, 10)
$chkOnlyFiles.Size = New-Object System.Drawing.Size(300, 20)
$ttip.SetToolTip($chkOnlyFiles, "Copies only top-level files, ignoring subdirectories.")
$tabFileSelection.Controls.Add($chkOnlyFiles)

# Label and textbox for /MINAGE (exclude newer files)
$lblMinAge = New-Object System.Windows.Forms.Label
$lblMinAge.Text = "Min Age (days):"
$lblMinAge.Location = New-Object System.Drawing.Point(10, 40)
$lblMinAge.Size = New-Object System.Drawing.Size(100, 20)
$tabFileSelection.Controls.Add($lblMinAge)

$txtMinAge = New-Object System.Windows.Forms.TextBox
$txtMinAge.Location = New-Object System.Drawing.Point(110, 40)
$txtMinAge.Size = New-Object System.Drawing.Size(100, 20)
$ttip.SetToolTip($txtMinAge, "Exclude files newer than specified days (e.g., 30).")
$tabFileSelection.Controls.Add($txtMinAge)

# Label and textbox for /MAXAGE (exclude older files)
$lblMaxAge = New-Object System.Windows.Forms.Label
$lblMaxAge.Text = "Max Age (days):"
$lblMaxAge.Location = New-Object System.Drawing.Point(220, 40)
$lblMaxAge.Size = New-Object System.Drawing.Size(100, 20)
$tabFileSelection.Controls.Add($lblMaxAge)

$txtMaxAge = New-Object System.Windows.Forms.TextBox
$txtMaxAge.Location = New-Object System.Drawing.Point(320, 40)
$txtMaxAge.Size = New-Object System.Drawing.Size(100, 20)
$ttip.SetToolTip($txtMaxAge, "Exclude files older than specified days (e.g., 365).")
$tabFileSelection.Controls.Add($txtMaxAge)

# Label and textbox for include patterns
$lblIncludeFiles = New-Object System.Windows.Forms.Label
$lblIncludeFiles.Text = "Include Files (e.g., *.txt):"
$lblIncludeFiles.Location = New-Object System.Drawing.Point(10, 70)
$lblIncludeFiles.Size = New-Object System.Drawing.Size(140, 20)
$tabFileSelection.Controls.Add($lblIncludeFiles)

$txtIncludeFiles = New-Object System.Windows.Forms.TextBox
$txtIncludeFiles.Location = New-Object System.Drawing.Point(150, 70)
$txtIncludeFiles.Size = New-Object System.Drawing.Size(300, 20)
$ttip.SetToolTip($txtIncludeFiles, "Include files matching pattern (e.g., *.txt, *.doc). Separate multiple with spaces.")
$tabFileSelection.Controls.Add($txtIncludeFiles)

# Label and textbox for exclude files (/XF)
$lblExcludeFiles = New-Object System.Windows.Forms.Label
$lblExcludeFiles.Text = "Exclude Files (e.g., *.bak):"
$lblExcludeFiles.Location = New-Object System.Drawing.Point(10, 100)
$lblExcludeFiles.Size = New-Object System.Drawing.Size(140, 20)
$tabFileSelection.Controls.Add($lblExcludeFiles)

$txtExcludeFiles = New-Object System.Windows.Forms.TextBox
$txtExcludeFiles.Location = New-Object System.Drawing.Point(150, 100)
$txtExcludeFiles.Size = New-Object System.Drawing.Size(300, 20)
$ttip.SetToolTip($txtExcludeFiles, "Exclude files matching pattern (e.g., *.bak). Separate multiple with spaces.")
$tabFileSelection.Controls.Add($txtExcludeFiles)

# Label and textbox for exclude directories (/XD)
$lblExcludeDirs = New-Object System.Windows.Forms.Label
$lblExcludeDirs.Text = "Exclude Dirs (e.g., temp):"
$lblExcludeDirs.Location = New-Object System.Drawing.Point(10, 130)
$lblExcludeDirs.Size = New-Object System.Drawing.Size(140, 20)
$tabFileSelection.Controls.Add($lblExcludeDirs)

$txtExcludeDirs = New-Object System.Windows.Forms.TextBox
$txtExcludeDirs.Location = New-Object System.Drawing.Point(150, 130)
$txtExcludeDirs.Size = New-Object System.Drawing.Size(300, 20)
$ttip.SetToolTip($txtExcludeDirs, "Exclude directories by name (e.g., temp, logs). Separate multiple with spaces.")
$tabFileSelection.Controls.Add($txtExcludeDirs)

# Tab for Retry Options
$tabRetryOptions = New-Object System.Windows.Forms.TabPage
$tabRetryOptions.Text = "Retry Options"
$tabControl.Controls.Add($tabRetryOptions)

# Label and textbox for /R (retries)
$lblRetries = New-Object System.Windows.Forms.Label
$lblRetries.Text = "Retries:"
$lblRetries.Location = New-Object System.Drawing.Point(10, 10)
$lblRetries.Size = New-Object System.Drawing.Size(50, 20)
$tabRetryOptions.Controls.Add($lblRetries)

$txtRetries = New-Object System.Windows.Forms.TextBox
$txtRetries.Text = "3"
$txtRetries.Location = New-Object System.Drawing.Point(60, 10)
$txtRetries.Size = New-Object System.Drawing.Size(50, 20)
$ttip.SetToolTip($txtRetries, "Number of retries on failed copies (default: 3).")
$tabRetryOptions.Controls.Add($txtRetries)

# Label and textbox for /W (wait time)
$lblWait = New-Object System.Windows.Forms.Label
$lblWait.Text = "Wait (sec):"
$lblWait.Location = New-Object System.Drawing.Point(120, 10)
$lblWait.Size = New-Object System.Drawing.Size(60, 20)
$tabRetryOptions.Controls.Add($lblWait)

$txtWait = New-Object System.Windows.Forms.TextBox
$txtWait.Text = "5"
$txtWait.Location = New-Object System.Drawing.Point(180, 10)
$txtWait.Size = New-Object System.Drawing.Size(50, 20)
$ttip.SetToolTip($txtWait, "Wait time between retries in seconds (default: 5).")
$tabRetryOptions.Controls.Add($txtWait)

# Label and textbox for /MT (multi-thread count for speed)
$lblMultiThread = New-Object System.Windows.Forms.Label
$lblMultiThread.Text = "Multi-Threads (/MT):"
$lblMultiThread.Location = New-Object System.Drawing.Point(240, 10)
$lblMultiThread.Size = New-Object System.Drawing.Size(100, 20)
$tabRetryOptions.Controls.Add($lblMultiThread)

$txtMultiThread = New-Object System.Windows.Forms.TextBox
$txtMultiThread.Text = "8"
$txtMultiThread.Location = New-Object System.Drawing.Point(340, 10)
$txtMultiThread.Size = New-Object System.Drawing.Size(50, 20)
$ttip.SetToolTip($txtMultiThread, "Number of threads for copying (1-128; default 8 in recent versions; higher for speed on large ops).")
$tabRetryOptions.Controls.Add($txtMultiThread)

# Tab for Logging Options
$tabLoggingOptions = New-Object System.Windows.Forms.TabPage
$tabLoggingOptions.Text = "Logging Options"
$tabControl.Controls.Add($tabLoggingOptions)

# Checkbox for /LOG (create log file)
$chkLog = New-Object System.Windows.Forms.CheckBox
$chkLog.Text = "Create Log File (/LOG:file)"
$chkLog.Location = New-Object System.Drawing.Point(10, 10)
$chkLog.Size = New-Object System.Drawing.Size(300, 20)
$ttip.SetToolTip($chkLog, "Outputs status to a log file. Specify path below.")
$tabLoggingOptions.Controls.Add($chkLog)

# Textbox for log file path
$txtLogFile = New-Object System.Windows.Forms.TextBox
$txtLogFile.Location = New-Object System.Drawing.Point(10, 40)
$txtLogFile.Size = New-Object System.Drawing.Size(200, 20)
$ttip.SetToolTip($txtLogFile, "Path to the log file (e.g., C:\Logs\robocopy.log).")
$tabLoggingOptions.Controls.Add($txtLogFile)

# Button to browse for log file
$btnBrowseLog = New-Object System.Windows.Forms.Button
$btnBrowseLog.Text = "Browse"
$btnBrowseLog.Location = New-Object System.Drawing.Point(220, 40)
$btnBrowseLog.Size = New-Object System.Drawing.Size(75, 23)
$btnBrowseLog.Add_Click({
    # Open save dialog for log file selection
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "Log Files (*.log)|*.log|All Files (*.*)|*.*"
    $saveFileDialog.Title = "Select Log File Location"
    if ($saveFileDialog.ShowDialog() -eq "OK") {
        $txtLogFile.Text = $saveFileDialog.FileName
    }
})
$tabLoggingOptions.Controls.Add($btnBrowseLog)

# Checkbox for /UNILOG (Unicode log)
$chkUnicodeLog = New-Object System.Windows.Forms.CheckBox
$chkUnicodeLog.Text = "Unicode Log (/UNILOG:file)"
$chkUnicodeLog.Location = New-Object System.Drawing.Point(10, 70)
$chkUnicodeLog.Size = New-Object System.Drawing.Size(300, 20)
$ttip.SetToolTip($chkUnicodeLog, "Outputs status to a Unicode log file. Uses same path as /LOG.")
$tabLoggingOptions.Controls.Add($chkUnicodeLog)

# Checkbox for /V (verbose output)
$chkVerbose = New-Object System.Windows.Forms.CheckBox
$chkVerbose.Text = "Verbose Output (/V)"
$chkVerbose.Location = New-Object System.Drawing.Point(10, 100)
$chkVerbose.Size = New-Object System.Drawing.Size(300, 20)
$ttip.SetToolTip($chkVerbose, "Includes skipped files in output.")
$tabLoggingOptions.Controls.Add($chkVerbose)

# Checkbox for /NP (no progress in output)
$chkNoProgress = New-Object System.Windows.Forms.CheckBox
$chkNoProgress.Text = "No Progress (/NP)"
$chkNoProgress.Location = New-Object System.Drawing.Point(10, 130)
$chkNoProgress.Size = New-Object System.Drawing.Size(300, 20)
$chkNoProgress.Checked = $true
$ttip.SetToolTip($chkNoProgress, "Suppresses progress percentage in output.")
$tabLoggingOptions.Controls.Add($chkNoProgress)

# Progress bar for operation status
$pBar = New-Object System.Windows.Forms.ProgressBar
$pBar.Location = New-Object System.Drawing.Point(10, 370)
$pBar.Size = New-Object System.Drawing.Size(765, 23)
$pBar.Minimum = 0
$pBar.Maximum = 100
$pBar.Value = 0
$frm.Controls.Add($pBar)

# Multiline textbox for output and logs
$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = "Vertical"
$txtOutput.Location = New-Object System.Drawing.Point(10, 400)
$txtOutput.Size = New-Object System.Drawing.Size(765, 100)
$frm.Controls.Add($txtOutput)

# Execute button to start Robocopy operation
$btnExecute = New-Object System.Windows.Forms.Button
$btnExecute.Text = "Execute"
$btnExecute.Location = New-Object System.Drawing.Point(350, 500)
$btnExecute.Size = New-Object System.Drawing.Size(100, 23)
$btnExecute.Add_Click({
    $source = $txtSource.Text
    $destination = $txtDestination.Text
    
    # Basic validation for required paths
    if ([string]::IsNullOrWhiteSpace($source) -or [string]::IsNullOrWhiteSpace($destination)) {
        $txtOutput.Text = "Error: Source and destination paths must be provided."
        return
    }
    
    # Validate paths (local or UNC) for accessibility
    $uncPattern = '^\\\\[\w\-.]+\\[\w\-.]+'
    $isSourceValid = ($source -match $uncPattern -or (Test-Path -Path $source -PathType Container))
    $isDestinationValid = ($destination -match $uncPattern -or (Test-Path -Path $destination -PathType Container))
    
    if (-not $isSourceValid) {
        $txtOutput.Text = "Error: Invalid or inaccessible source path. Please check the path and network permissions."
        return
    }
    if (-not $isDestinationValid) {
        $txtOutput.Text = "Error: Invalid or inaccessible destination path. Please check the path and network permissions."
        return
    }
    
    # Build Robocopy options string based on user selections
    $options = ""
    
    # Append copy options
    if ($chkCopyDAT.Checked) {
        $options += " /COPY:DAT"
    }
    if ($chkCopyAll.Checked) {
        $options += " /COPYALL"
    }
    if ($chkNoCopy.Checked) {
        $options += " /CREATE"
    }
    if ($chkMirror.Checked) {
        $options += " /MIR"
    }
    if ($chkSubdirs.Checked) {
        $options += " /E"
    }
    if ($chkEmptyDirs.Checked -and $chkSubdirs.Checked) {
        $options += " /E"
    }
    if ($radioMove.Checked) {
        $options += " /MOVE"
        $operation = "Moving"
    } else {
        $operation = "Copying"
    }
    
    # Append file selection options
    if ($chkOnlyFiles.Checked) {
        $options += " /LEV:0"
    }
    if ($txtMinAge.Text -match '^\d+$') {
        $options += " /MINAGE:$($txtMinAge.Text)"
    }
    if ($txtMaxAge.Text -match '^\d+$') {
        $options += " /MAXAGE:$($txtMaxAge.Text)"
    }
    if (-not [string]::IsNullOrWhiteSpace($txtIncludeFiles.Text)) {
        $options += " $($txtIncludeFiles.Text)"
    }
    if (-not [string]::IsNullOrWhiteSpace($txtExcludeFiles.Text)) {
        $options += " /XF $($txtExcludeFiles.Text)"
    }
    if (-not [string]::IsNullOrWhiteSpace($txtExcludeDirs.Text)) {
        $options += " /XD $($txtExcludeDirs.Text)"
    }
    
    # Append retry options
    if ($txtRetries.Text -match '^\d+$') {
        $options += " /R:$($txtRetries.Text)"
    } else {
        $txtOutput.AppendText("Warning: Invalid retry count, using default (3).`r`n")
        $options += " /R:3"
    }
    if ($txtWait.Text -match '^\d+$') {
        $options += " /W:$($txtWait.Text)"
    } else {
        $txtOutput.AppendText("Warning: Invalid wait time, using default (5).`r`n")
        $options += " /W:5"
    }
    
    # Append multi-thread option for speed
    if ($txtMultiThread.Text -match '^\d+$' -and [int]$txtMultiThread.Text -ge 1 -and [int]$txtMultiThread.Text -le 128) {
        $options += " /MT:$($txtMultiThread.Text)"
    } else {
        $txtOutput.AppendText("Warning: Invalid multi-thread count, omitting /MT.`r`n")
    }
    
    # Append logging options
    if ($chkLog.Checked -and -not [string]::IsNullOrWhiteSpace($txtLogFile.Text)) {
        $options += " /LOG:`"$($txtLogFile.Text)`""
    }
    if ($chkUnicodeLog.Checked -and -not [string]::IsNullOrWhiteSpace($txtLogFile.Text)) {
        $options += " /UNILOG:`"$($txtLogFile.Text)`""
    }
    if ($chkVerbose.Checked) {
        $options += " /V"
    }
    if ($chkNoProgress.Checked) {
        $options += " /NP"
    }
    
    # Security: Confirm destructive operations
    $isDestructive = $chkMirror.Checked -or $radioMove.Checked
    if ($isDestructive) {
        $confirm = [System.Windows.Forms.MessageBox]::Show("This operation may delete or move files permanently. Proceed?", "Confirmation", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($confirm -ne "Yes") {
            $txtOutput.Text = "Operation cancelled by user."
            return
        }
    }
    
    $txtOutput.AppendText("$operation from $source to $destination with options: $options`r`n")
    
    # Optional progress estimation (skippable for speed)
    $totalFiles = 0
    $processedFiles = 0
    if ($chkProgressEst.Checked) {
        try {
            $files = Get-ChildItem -Path $source -Recurse -File -ErrorAction SilentlyContinue
            $totalFiles = $files.Count
        } catch {
            $txtOutput.AppendText("Warning: Could not count files for progress estimation.`r`n")
            $totalFiles = 0
        }
    }
    
    # Run Robocopy asynchronously in a runspace to avoid UI freeze
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('source', $source)
    $runspace.SessionStateProxy.SetVariable('destination', $destination)
    $runspace.SessionStateProxy.SetVariable('options', $options)
    $runspace.SessionStateProxy.SetVariable('txtOutput', $txtOutput)
    $runspace.SessionStateProxy.SetVariable('pBar', $pBar)
    $runspace.SessionStateProxy.SetVariable('frm', $frm)
    $runspace.SessionStateProxy.SetVariable('totalFiles', $totalFiles)
    
    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        # Execute Robocopy and capture output
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = "robocopy"
        $process.StartInfo.Arguments = "`"$source`" `"$destination`" $options"
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        $process.StartInfo.CreateNoWindow = $true
        $process.EnableRaisingEvents = $true
        
        $processedFiles = 0
        $process.Add_OutputDataReceived({
            param($sender, $e)
            if ($e.Data -and $e.Data -match "\s+Files\s+:") {
                if ($totalFiles -gt 0) {
                    $processedFiles++
                    $pBar.Value = [math]::Min(100, ($processedFiles / $totalFiles) * 100)
                    $frm.Refresh()
                }
            }
            if ($e.Data) {
                $txtOutput.Invoke({ $txtOutput.AppendText($e.Data + "`r`n"); $txtOutput.ScrollToCaret() })
            }
        })
        
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        $pBar.Value = 100

        # Display stderr and exit code
        $exitCode = $process.ExitCode
        $txtOutput.Invoke({
            if ($stderr) {
                $txtOutput.AppendText("`r`n--- Errors/Warnings ---`r`n" + $stderr + "`r`n")
            }
            $txtOutput.AppendText("`r`nOperation completed with exit code: $exitCode`r`n")

            # Provide helpful message for common errors
            if ($exitCode -ge 8) {
                $txtOutput.AppendText("ERROR: Copy failed. If you see 'Manage Auditing user right' error, uncheck '/COPYALL' option.`r`n")
            } elseif ($exitCode -eq 0) {
                $txtOutput.AppendText("SUCCESS: No files were copied (all files up to date).`r`n")
            } elseif ($exitCode -eq 1) {
                $txtOutput.AppendText("SUCCESS: Files were copied successfully.`r`n")
            }
            $txtOutput.ScrollToCaret()
        })
    }) | Out-Null
    
    $async = $ps.BeginInvoke()
    
    # Periodically refresh UI while runspace runs (simulates DoEvents)
    while (-not $async.IsCompleted) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
    }

    try {
        $ps.EndInvoke($async)
    } catch {
        $txtOutput.AppendText("`r`nError: $($_.Exception.Message)`r`n")
    } finally {
        $ps.Dispose()
        $runspace.Close()
        $runspace.Dispose()
    }
})
$frm.Controls.Add($btnExecute)

# Display the form dialog
$frm.ShowDialog() | Out-Null