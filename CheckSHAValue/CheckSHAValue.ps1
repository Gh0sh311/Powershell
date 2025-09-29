<#
.SYNOPSIS
    A small utility that check if the SHA256 hash of a file matches an expected value.

.DESCRIPTION
    This script verifies the integrity of a file by comparing its
    SHA256 hash against a user-provided value. It provides a simple GUI for users to select
    the file and input the expected hash.
        
.NOTES
    Feel free to modifythis script.
    Trond Hoiberg 25th September 2025
#>

# Import required assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Security

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "File SHA256 Checker"
$form.Size = New-Object System.Drawing.Size(600,300)
$form.StartPosition = "CenterScreen"

# Create label for file path
$labelFile = New-Object System.Windows.Forms.Label
$labelFile.Location = New-Object System.Drawing.Point(10,20)
$labelFile.Size = New-Object System.Drawing.Size(560,20)
$labelFile.Text = "Select a file to check its SHA256 hash:"
$form.Controls.Add($labelFile)

# Create textbox for file path
$textBoxFile = New-Object System.Windows.Forms.TextBox
$textBoxFile.Location = New-Object System.Drawing.Point(10,40)
$textBoxFile.Size = New-Object System.Drawing.Size(460,20)
$form.Controls.Add($textBoxFile)

# Create browse button
$buttonBrowse = New-Object System.Windows.Forms.Button
$buttonBrowse.Location = New-Object System.Drawing.Point(480,38)
$buttonBrowse.Size = New-Object System.Drawing.Size(75,23)
$buttonBrowse.Text = "Browse"
$form.Controls.Add($buttonBrowse)

# Create label for SHA256 input
$labelSHA256 = New-Object System.Windows.Forms.Label
$labelSHA256.Location = New-Object System.Drawing.Point(10,70)
$labelSHA256.Size = New-Object System.Drawing.Size(560,20)
$labelSHA256.Text = "Paste expected SHA256 hash:"
$form.Controls.Add($labelSHA256)

# Create textbox for SHA256 input
$textBoxSHA256 = New-Object System.Windows.Forms.TextBox
$textBoxSHA256.Location = New-Object System.Drawing.Point(10,90)
$textBoxSHA256.Size = New-Object System.Drawing.Size(460,20)
$form.Controls.Add($textBoxSHA256)

# Create check button
$buttonCheck = New-Object System.Windows.Forms.Button
$buttonCheck.Location = New-Object System.Drawing.Point(180,120)
$buttonCheck.Size = New-Object System.Drawing.Size(100,23)
$buttonCheck.Text = "Check Hash"
$form.Controls.Add($buttonCheck)

# Create exit button
$buttonExit = New-Object System.Windows.Forms.Button
$buttonExit.Location = New-Object System.Drawing.Point(320,120)
$buttonExit.Size = New-Object System.Drawing.Size(75,23)
$buttonExit.Text = "Exit"
$form.Controls.Add($buttonExit)

# Create RichTextBox for result
$resultRichTextBox = New-Object System.Windows.Forms.RichTextBox
$resultRichTextBox.Location = New-Object System.Drawing.Point(10,150)
$resultRichTextBox.Size = New-Object System.Drawing.Size(560,60)
$resultRichTextBox.ReadOnly = $true
$form.Controls.Add($resultRichTextBox)

# Create panel for status light
$statusLight = New-Object System.Windows.Forms.Panel
$statusLight.Location = New-Object System.Drawing.Point(480,90)
$statusLight.Size = New-Object System.Drawing.Size(20,20)
$statusLight.BackColor = [System.Drawing.Color]::Gray
$form.Controls.Add($statusLight)

# Browse button click event
$buttonBrowse.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
    $openFileDialog.Filter = "All files (*.*)|*.*"
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $textBoxFile.Text = $openFileDialog.FileName
    }
})

# Check button click event
$buttonCheck.Add_Click({
    $filePath = $textBoxFile.Text
    $expectedHash = $textBoxSHA256.Text -replace '[^0-9A-Fa-f]','' # Remove non-hex characters
    $resultRichTextBox.Clear()
    
    if (Test-Path $filePath) {
        try {
            # Calculate SHA256 hash
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $fileStream = [System.IO.File]::OpenRead($filePath)
            $hashBytes = $sha256.ComputeHash($fileStream)
            $fileStream.Close()
            $sha256.Dispose()
            $hashString = [System.BitConverter]::ToString($hashBytes) -replace '-',''
            
            # Append calculated hash
            $resultRichTextBox.AppendText("Calculated SHA256 Hash:`n$hashString")
            
            # Compare hashes
            if ($expectedHash -and $hashString.ToLower() -eq $expectedHash.ToLower()) {
                $statusLight.BackColor = [System.Drawing.Color]::Green
                $resultRichTextBox.SelectionStart = $resultRichTextBox.TextLength
                $resultRichTextBox.SelectionLength = 0
                $resultRichTextBox.SelectionColor = [System.Drawing.Color]::Green
                $resultRichTextBox.SelectionFont = New-Object System.Drawing.Font($resultRichTextBox.Font, [System.Drawing.FontStyle]::Bold)
                $resultRichTextBox.AppendText("`nHash matches!")
            } elseif ($expectedHash) {
                $statusLight.BackColor = [System.Drawing.Color]::Red
                $resultRichTextBox.SelectionStart = $resultRichTextBox.TextLength
                $resultRichTextBox.SelectionLength = 0
                $resultRichTextBox.SelectionColor = [System.Drawing.Color]::Red
                $resultRichTextBox.SelectionFont = New-Object System.Drawing.Font($resultRichTextBox.Font, [System.Drawing.FontStyle]::Bold)
                $resultRichTextBox.AppendText("`nThe value is not correct. This file has been tampered with.")
            } else {
                $statusLight.BackColor = [System.Drawing.Color]::Gray
            }
        }
        catch {
            $resultRichTextBox.Text = "Error calculating hash: $_"
            $statusLight.BackColor = [System.Drawing.Color]::Gray
        }
    }
    else {
        $resultRichTextBox.Text = "File not found. Please select a valid file."
        $statusLight.BackColor = [System.Drawing.Color]::Gray
    }
})

# Exit button click event
$buttonExit.Add_Click({
    # Dispose of form and its controls to clean up memory
    $form.Controls | ForEach-Object { $_.Dispose() }
    $form.Dispose()
})

# Show the form
[void]$form.ShowDialog()

# Clean up after form is closed
$form.Controls | ForEach-Object { $_.Dispose() }
$form.Dispose()