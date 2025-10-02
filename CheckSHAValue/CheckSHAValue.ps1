# .SYNOPSIS
#     A small utility that checks if the hash of a file matches an expected value.
#
# .DESCRIPTION
#     This script verifies the integrity of a file by comparing its hash (SHA256, SHA1, or MD5)
#     against a user-provided value. It provides a GUI with file selection, drag-and-drop support,
#     algorithm selection, a progress bar, and clipboard functionality.
#
# .NOTES
#     Trond Hoiberg (25th September 2025). Modified to add input validation,
#     hash algorithm selection, drag-and-drop, progress bar, and clipboard support.
#     Updated on 2nd October 2025 to fix assembly loading error, typo in hash string conversion.

# Import required assembly for GUI
Add-Type -AssemblyName System.Windows.Forms

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "File Hash Checker"
$form.Size = New-Object System.Drawing.Size(600,350)
$form.StartPosition = "CenterScreen"
$form.AllowDrop = $true  # Enable drag-and-drop

# Create label for file path
$lblFile = New-Object System.Windows.Forms.Label
$lblFile.Location = New-Object System.Drawing.Point(10,20)
$lblFile.Size = New-Object System.Drawing.Size(560,20)
$lblFile.Text = "Select or drag-and-drop a file to check its hash:"
$form.Controls.Add($lblFile)

# Create textbox for file path
$txtFile = New-Object System.Windows.Forms.TextBox
$txtFile.Location = New-Object System.Drawing.Point(10,40)
$txtFile.Size = New-Object System.Drawing.Size(460,20)
$txtFile.AllowDrop = $true
$form.Controls.Add($txtFile)

# Create browse button
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Location = New-Object System.Drawing.Point(480,38)
$btnBrowse.Size = New-Object System.Drawing.Size(75,23)
$btnBrowse.Text = "Browse"
$form.Controls.Add($btnBrowse)

# Create label for hash algorithm selection
$lblAlgorithm = New-Object System.Windows.Forms.Label
$lblAlgorithm.Location = New-Object System.Drawing.Point(10,70)
$lblAlgorithm.Size = New-Object System.Drawing.Size(560,20)
$lblAlgorithm.Text = "Select hash algorithm:"
$form.Controls.Add($lblAlgorithm)

# Create combobox for hash algorithm selection
$cmbAlgorithm = New-Object System.Windows.Forms.ComboBox
$cmbAlgorithm.Location = New-Object System.Drawing.Point(10,90)
$cmbAlgorithm.Size = New-Object System.Drawing.Size(100,20)
$cmbAlgorithm.Items.AddRange(@("SHA256", "SHA1", "MD5"))
$cmbAlgorithm.SelectedIndex = 0  # Default to SHA256
$form.Controls.Add($cmbAlgorithm)

# Create label for hash input
$lblHash = New-Object System.Windows.Forms.Label
$lblHash.Location = New-Object System.Drawing.Point(10,120)
$lblHash.Size = New-Object System.Drawing.Size(560,20)
$lblHash.Text = "Paste expected hash:"
$form.Controls.Add($lblHash)

# Create textbox for hash input
$txtHash = New-Object System.Windows.Forms.TextBox
$txtHash.Location = New-Object System.Drawing.Point(10,140)
$txtHash.Size = New-Object System.Drawing.Size(460,20)
$form.Controls.Add($txtHash)

# Create check button
$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Location = New-Object System.Drawing.Point(100,170)
$btnCheck.Size = New-Object System.Drawing.Size(100,23)
$btnCheck.Text = "Check Hash"
$form.Controls.Add($btnCheck)

# Create copy to clipboard button
$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Location = New-Object System.Drawing.Point(210,170)
$btnCopy.Size = New-Object System.Drawing.Size(100,23)
$btnCopy.Text = "Copy Hash"
$btnCopy.Enabled = $false  # Disabled until hash is computed
$form.Controls.Add($btnCopy)

# Create exit button
$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Location = New-Object System.Drawing.Point(320,170)
$btnExit.Size = New-Object System.Drawing.Size(75,23)
$btnExit.Text = "Exit"
$form.Controls.Add($btnExit)

# Create progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,200)
$progressBar.Size = New-Object System.Drawing.Size(560,20)
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

# Create RichTextBox for result
$txtResult = New-Object System.Windows.Forms.RichTextBox
$txtResult.Location = New-Object System.Drawing.Point(10,230)
$txtResult.Size = New-Object System.Drawing.Size(560,80)
$txtResult.ReadOnly = $true
$form.Controls.Add($txtResult)

# Create panel for status light
$s = New-Object System.Windows.Forms.Panel
$s.Location = New-Object System.Drawing.Point(480,140)
$s.Size = New-Object System.Drawing.Size(20,20)
$s.BackColor = [System.Drawing.Color]::Gray
$form.Controls.Add($s)

# Drag-and-drop event handlers
$txtFile.Add_DragEnter({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    }
})

$txtFile.Add_DragDrop({
    param($sender, $e)
    $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    if ($files -and $files.Length -gt 0) {
        $txtFile.Text = $files[0]
    }
})

# Browse button click event
$btnBrowse.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
    $openFileDialog.Filter = "All files (*.*)|*.*"
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $txtFile.Text = $openFileDialog.FileName
    }
})

# Validate hash input based on algorithm
function Validate-HashInput {
    param($hash, $algorithm)
    $hash = $hash -replace '[^0-9A-Fa-f]',''  # Remove non-hex characters
    $length = switch ($algorithm) {
        "SHA256" { 64 }
        "SHA1"   { 40 }
        "MD5"    { 32 }
        default  { 64 }
    }
    return ($hash -match '^[0-9A-Fa-f]+$') -and ($hash.Length -eq $length)
}

# Check button click event
$btnCheck.Add_Click({
    $filePath = $txtFile.Text
    $expectedHash = $txtHash.Text -replace '[^0-9A-Fa-f]',''  # Remove non-hex characters
    $algorithm = $cmbAlgorithm.SelectedItem
    $txtResult.Clear()
    $btnCopy.Enabled = $false
    $progressBar.Visible = $true
    $progressBar.Value = 0

    if (-not (Test-Path $filePath)) {
        $txtResult.Text = "File not found. Please select a valid file."
        $s.BackColor = [System.Drawing.Color]::Gray
        $progressBar.Visible = $false
        return
    }

    if ($expectedHash -and -not (Validate-HashInput -hash $expectedHash -algorithm $algorithm)) {
        $txtResult.Text = "Invalid hash format for $algorithm. Expected a $((Validate-HashInput -hash '' -algorithm $algorithm).Length)-character hexadecimal string."
        $s.BackColor = [System.Drawing.Color]::Gray
        $progressBar.Visible = $false
        return
    }

    try {
        # Select hash algorithm
        $hashAlgorithm = switch ($algorithm) {
            "SHA256" { [System.Security.Cryptography.SHA256]::Create() }
            "SHA1"   { [System.Security.Cryptography.SHA1]::Create() }
            "MD5"    { [System.Security.Cryptography.MD5]::Create() }
            default  { [System.Security.Cryptography.SHA256]::Create() }
        }

        # Calculate hash with progress
        $fileStream = [System.IO.File]::OpenRead($filePath)
        $fileSize = $fileStream.Length
        $buffer = New-Object byte[] 1048576  # 1MB buffer
        $totalRead = 0

        while ($true) {
            $bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -eq 0) { break }
            $hashAlgorithm.TransformBlock($buffer, 0, $bytesRead, $buffer, 0)
            $totalRead += $bytesRead
            $progressBar.Value = [Math]::Min(100, [int](($totalRead / $fileSize) * 100))
        }
        $hashAlgorithm.TransformFinalBlock($buffer, 0, 0)
        $hashBytes = $hashAlgorithm.Hash
        $fileStream.Close()
        $hashAlgorithm.Dispose()

        $hashString = [System.BitConverter]::ToString($hashBytes) -replace '-'
        $txtResult.AppendText("Calculated $algorithm Hash:`n$hashString")
        $btnCopy.Enabled = $true
        $btnCopy.Tag = $hashString  # Store hash for copying

        # Compare hashes
        if ($expectedHash -and $hashString.ToLower() -eq $expectedHash.ToLower()) {
            $s.BackColor = [System.Drawing.Color]::Green
            $txtResult.SelectionStart = $txtResult.TextLength
            $txtResult.SelectionLength = 0
            $txtResult.SelectionColor = [System.Drawing.Color]::Green
            $txtResult.SelectionFont = New-Object System.Drawing.Font($txtResult.Font, [System.Drawing.FontStyle]::Bold)
            $txtResult.AppendText("`nHash matches!")
        } elseif ($expectedHash) {
            $s.BackColor = [System.Drawing.Color]::Red
            $txtResult.SelectionStart = $txtResult.TextLength
            $txtResult.SelectionLength = 0
            $txtResult.SelectionColor = [System.Drawing.Color]::Red
            $txtResult.SelectionFont = New-Object System.Drawing.Font($txtResult.Font, [System.Drawing.FontStyle]::Bold)
            $txtResult.AppendText("`nThe value is not correct. This file has been tampered with.")
        } else {
            $s.BackColor = [System.Drawing.Color]::Gray
        }
    }
    catch {
        $txtResult.Text = "Error calculating hash: $_"
        $s.BackColor = [System.Drawing.Color]::Gray
    }
    finally {
        $progressBar.Visible = $false
    }
})

# Copy to clipboard button click event
$btnCopy.Add_Click({
    if ($btnCopy.Tag) {
        [System.Windows.Forms.Clipboard]::SetText($btnCopy.Tag)
        $txtResult.AppendText("`nHash copied to clipboard.")
    }
})

# Exit button click event
$btnExit.Add_Click({
    # Dispose of form and its controls to clean up memory
    $form.Controls | ForEach-Object { $_.Dispose() }
    $form.Dispose()
})

# Show the form
[void]$form.ShowDialog()

# Clean up after form is closed
$form.Controls | ForEach-Object { $_.Dispose() }
$form.Dispose()
