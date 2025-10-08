#Requires -Version 5.1

<#
.SYNOPSIS
    GUI-based file type detector using magic bytes and Base64 prefix analysis
.DESCRIPTION
    Detects file types by analyzing file signatures (magic bytes) regardless of file extension.
    Features:
    - Visual GUI interface for easy operation
    - Reads file signatures from JSON database
    - Shows detected file types and Base64 prefixes
    - Export results to CSV or JSON
    - Progress tracking for large scans
    - Performance optimized for scanning many files
.NOTES
    Developer: Trond Hoiberg
    Version: 2.1 (GUI Edition with Hidden Content Detection)

    Based on original work by Yossi Sassi (1nTh35h311)
    Original project: https://github.com/YossiSassi/Detect-FileTypeFromBase64Prefix
    Reference: https://github.com/YossiSassi/Detect-FileTypeFromBase64Prefix/blob/main/README.md

    Credits:
    - Original concept and detection logic: Yossi Sassi (https://github.com/YossiSassi)
    - GUI implementation and enhancements: Trond Hoiberg
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$script:scanResults = [System.Collections.ArrayList]::new()
$script:signatures = $null
$script:isScanning = $false
$script:readSize = 64

#region Security & Validation Functions

function Test-JsonSignatureSafe {
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Signatures
    )

    $validationErrors = [System.Collections.ArrayList]::new()

    if (-not $Signatures -or $Signatures.Count -eq 0) {
        $null = $validationErrors.Add("No signatures found in JSON file")
        return @{
            IsValid = $false
            Errors = $validationErrors
        }
    }

    # Security limits
    $maxSignatures = 1000
    $maxOffsetBytes = 1048576  # 1 MB max offset
    $maxSigLength = 1024       # 1 KB max signature
    $maxNameLength = 200

    if ($Signatures.Count -gt $maxSignatures) {
        $null = $validationErrors.Add("Too many signatures ($($Signatures.Count)). Maximum allowed: $maxSignatures")
    }

    $validSigCount = 0

    for ($i = 0; $i -lt $Signatures.Count; $i++) {
        $sig = $Signatures[$i]
        $sigNum = $i + 1

        # Validate required fields exist
        if (-not $sig.PSObject.Properties['name']) {
            $null = $validationErrors.Add("Signature #$sigNum is missing 'name' field")
            continue
        }

        if (-not $sig.PSObject.Properties['offset']) {
            $null = $validationErrors.Add("Signature #$sigNum ('$($sig.name)') is missing 'offset' field")
            continue
        }

        if (-not $sig.PSObject.Properties['sigHex'] -and -not $sig.PSObject.Properties['sigAscii']) {
            $null = $validationErrors.Add("Signature #$sigNum ('$($sig.name)') must have either 'sigHex' or 'sigAscii'")
            continue
        }

        # Validate name
        if ([string]::IsNullOrWhiteSpace($sig.name)) {
            $null = $validationErrors.Add("Signature #$sigNum has empty name")
            continue
        }

        if ($sig.name.Length -gt $maxNameLength) {
            $null = $validationErrors.Add("Signature '$($sig.name)' name too long (max $maxNameLength chars)")
            continue
        }

        # Check for suspicious characters in name (potential code injection)
        # Allow parentheses () for descriptive names like "GIF Image (89a)"
        if ($sig.name -match '[;`${}|&<>\[\]]') {
            $null = $validationErrors.Add("Signature '$($sig.name)' contains suspicious characters")
            continue
        }

        # Validate offset
        try {
            $offset = [int]$sig.offset
            if ($offset -lt 0) {
                $null = $validationErrors.Add("Signature '$($sig.name)' has negative offset: $offset")
                continue
            }
            if ($offset -gt $maxOffsetBytes) {
                $null = $validationErrors.Add("Signature '$($sig.name)' offset too large: $offset (max $maxOffsetBytes)")
                continue
            }
        }
        catch {
            $null = $validationErrors.Add("Signature '$($sig.name)' has invalid offset: $($sig.offset)")
            continue
        }

        # Validate sigHex if present
        if ($sig.PSObject.Properties['sigHex']) {
            $hexClean = $sig.sigHex -replace '\s',''

            # Check for valid hex characters only
            if ($hexClean -notmatch '^[0-9A-Fa-f]+$') {
                $null = $validationErrors.Add("Signature '$($sig.name)' has invalid hex characters in sigHex")
                continue
            }

            # Check length
            if ($hexClean.Length -gt ($maxSigLength * 2)) {
                $null = $validationErrors.Add("Signature '$($sig.name)' sigHex too long (max $maxSigLength bytes)")
                continue
            }

            # Must be even length (pairs of hex digits)
            if ($hexClean.Length % 2 -ne 0) {
                $null = $validationErrors.Add("Signature '$($sig.name)' sigHex has odd number of characters")
                continue
            }
        }

        # Validate sigAscii if present
        if ($sig.PSObject.Properties['sigAscii']) {
            if ([string]::IsNullOrEmpty($sig.sigAscii)) {
                $null = $validationErrors.Add("Signature '$($sig.name)' has empty sigAscii")
                continue
            }

            if ($sig.sigAscii.Length -gt $maxSigLength) {
                $null = $validationErrors.Add("Signature '$($sig.name)' sigAscii too long (max $maxSigLength chars)")
                continue
            }

            # Check for suspicious PowerShell/script content
            if ($sig.sigAscii -match '(\$\w+|Invoke-|iex|&\s*\(|`|\||;)') {
                $null = $validationErrors.Add("Signature '$($sig.name)' sigAscii contains suspicious script-like content")
                continue
            }
        }

        # Check for unexpected properties (could indicate malicious JSON)
        $allowedProperties = @('name', 'sigHex', 'sigAscii', 'offset')
        $unexpectedProps = $sig.PSObject.Properties.Name | Where-Object { $_ -notin $allowedProperties }
        if ($unexpectedProps) {
            $null = $validationErrors.Add("Signature '$($sig.name)' has unexpected properties: $($unexpectedProps -join ', ')")
        }

        $validSigCount++
    }

    if ($validSigCount -eq 0) {
        $null = $validationErrors.Add("No valid signatures found after validation")
    }

    return @{
        IsValid = ($validationErrors.Count -eq 0)
        Errors = $validationErrors
        ValidSignatureCount = $validSigCount
    }
}

function Test-PathSafe {
    param(
        [string]$Path
    )

    # Protected system paths
    $protectedPaths = @(
        "$env:SystemRoot",
        "$env:SystemRoot\System32",
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}",
        "$env:ProgramData\Microsoft",
        "$env:USERPROFILE\AppData\Local\Microsoft"
    )

    $resolvedPath = $null
    try {
        $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
    }
    catch {
        return @{
            IsSafe = $false
            Reason = "Path does not exist or is not accessible"
        }
    }

    foreach ($protected in $protectedPaths) {
        if ($resolvedPath.Path -like "$protected*") {
            return @{
                IsSafe = $false
                Reason = "Scanning system directories is not recommended. Path: $protected"
                IsWarningOnly = $true  # Allow but warn
            }
        }
    }

    return @{
        IsSafe = $true
        Reason = "Path is safe to scan"
    }
}

#endregion

#region Helper Functions

function Get-FileEntropy {
    <#
    .SYNOPSIS
        Calculates Shannon entropy of file data to detect encryption/compression
    .DESCRIPTION
        Entropy ranges from 0 (all same byte) to 8 (perfectly random)
        High entropy (>7.5) often indicates: encryption, compression, or hidden data
    #>
    param(
        [byte[]]$Bytes
    )

    if (-not $Bytes -or $Bytes.Length -eq 0) {
        return 0
    }

    # Count frequency of each byte value (0-255)
    $frequency = @{}
    for ($i = 0; $i -lt 256; $i++) {
        $frequency[$i] = 0
    }

    foreach ($byte in $Bytes) {
        $frequency[$byte]++
    }

    # Calculate Shannon entropy
    $entropy = 0.0
    $length = $Bytes.Length

    foreach ($count in $frequency.Values) {
        if ($count -gt 0) {
            $probability = $count / $length
            $entropy -= $probability * [Math]::Log($probability, 2)
        }
    }

    return [Math]::Round($entropy, 2)
}

function Test-SuspiciousFile {
    <#
    .SYNOPSIS
        Detects suspicious characteristics indicating hidden/encrypted content
    #>
    param(
        [byte[]]$Bytes,
        [long]$FileSize,
        [string]$DetectedType
    )

    $flags = @()

    # Calculate entropy
    $entropy = Get-FileEntropy -Bytes $Bytes
    $entropyRounded = [Math]::Round($entropy, 2)

    # Known compressed/encrypted formats are expected to have high entropy
    $expectedHighEntropy = @('ZIP', 'RAR', '7-Zip', 'GZIP', 'Compressed', 'Archive', 'Encrypted', 'PDF')
    $isExpectedHigh = $false
    foreach ($format in $expectedHighEntropy) {
        if ($DetectedType -like "*$format*") {
            $isExpectedHigh = $true
            break
        }
    }

    # Context-aware entropy thresholds based on file type
    $isImageFile = $DetectedType -match 'PNG|JPEG|GIF|BMP|TIFF|WebP'

    # Extremely high entropy (approaching theoretical maximum)
    if ($entropy -ge 7.95) {
        if (-not $isExpectedHigh) {
            $flags += "🔒 Extremely High Entropy ($entropyRounded) - Near random/encrypted"
        }
    }
    # Very high entropy for images (steganography indicator)
    elseif ($entropy -ge 7.8 -and $isImageFile) {
        $flags += "🖼️ Possible Steganography (Entropy: $entropyRounded, typical JPEG: 7.0-7.6)"
    }
    # High entropy for unknown files
    elseif ($entropy -ge 7.5 -and $DetectedType -eq 'Unknown') {
        $flags += "🔒 Encrypted/Hidden Data (Entropy: $entropyRounded)"
    }

    # Low entropy for binary formats (could be padding attack)
    if ($entropy -lt 3.0 -and $FileSize -gt 1KB) {
        $flags += "⚠️ Suspiciously Low Entropy ($entropyRounded) - Possible padding"
    }

    # Null byte padding detection (common in malware)
    if ($Bytes.Length -ge 1KB) {
        $nullCount = ($Bytes | Where-Object { $_ -eq 0 }).Count
        $nullPercent = ($nullCount / $Bytes.Length) * 100

        if ($nullPercent -gt 50) {
            $flags += "⚠️ Excessive Null Bytes ($([Math]::Round($nullPercent, 1))%)"
        } elseif ($nullPercent -gt 30 -and -not $isExpectedHigh) {
            $flags += "⚠️ High Null Byte Percentage ($([Math]::Round($nullPercent, 1))%)"
        }
    }

    # Chi-square test for randomness (detects uniform byte distribution)
    if ($Bytes.Length -ge 1KB) {
        $freq = @{}
        foreach ($b in $Bytes) {
            if ($freq.ContainsKey($b)) {
                $freq[$b]++
            } else {
                $freq[$b] = 1
            }
        }

        $expected = $Bytes.Length / 256.0
        $chiSquare = 0
        foreach ($count in $freq.Values) {
            $chiSquare += [Math]::Pow($count - $expected, 2) / $expected
        }

        # Chi-square for random data is ~255, structured data varies significantly
        # Very low chi-square indicates uniform distribution (encrypted/random)
        if ($chiSquare -lt 200 -and $entropy -ge 7.5 -and -not $isExpectedHigh) {
            $flags += "🔢 Uniform byte distribution (Chi²: $([Math]::Round($chiSquare, 1))) - Possible encryption"
        }
    }

    # Check for trailing data in JPEG files (polyglot/appended files)
    if ($DetectedType -match 'JPEG' -and $Bytes.Length -ge 100) {
        $jpegEnd = -1
        for ($i = $Bytes.Length - 2; $i -ge ([Math]::Max(0, $Bytes.Length - 50000)); $i--) {
            if ($Bytes[$i] -eq 0xFF -and $Bytes[$i+1] -eq 0xD9) {
                $jpegEnd = $i + 1
                break
            }
        }

        if ($jpegEnd -gt 0 -and $jpegEnd -lt ($Bytes.Length - 10)) {
            $trailingBytes = $Bytes.Length - $jpegEnd - 1
            $flags += "📎 Trailing data after JPEG ($trailingBytes bytes) - Possible polyglot"
        }
    }

    # Check for trailing data in PNG files
    if ($DetectedType -match 'PNG' -and $Bytes.Length -ge 100) {
        # PNG ends with IEND chunk: 00 00 00 00 49 45 4E 44 AE 42 60 82
        $pngEndPattern = @(0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82)
        $pngEnd = -1

        for ($i = $Bytes.Length - 8; $i -ge ([Math]::Max(0, $Bytes.Length - 10000)); $i--) {
            $match = $true
            for ($j = 0; $j -lt 8; $j++) {
                if ($Bytes[$i + $j] -ne $pngEndPattern[$j]) {
                    $match = $false
                    break
                }
            }
            if ($match) {
                $pngEnd = $i + 7
                break
            }
        }

        if ($pngEnd -gt 0 -and $pngEnd -lt ($Bytes.Length - 10)) {
            $trailingBytes = $Bytes.Length - $pngEnd - 1
            $flags += "📎 Trailing data after PNG ($trailingBytes bytes) - Possible polyglot"
        }
    }

    return @{
        Entropy = $entropyRounded
        Flags = $flags
        IsSuspicious = ($flags.Count -gt 0)
    }
}

function Read-FilePrefix {
    param(
        [string]$FilePath,
        [int]$ByteCount
    )

    try {
        $fs = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $buf = New-Object byte[] $ByteCount
            $read = $fs.Read($buf, 0, $ByteCount)
            if ($read -lt $ByteCount) {
                $buf = $buf[0..($read-1)]
            }
            return ,$buf  # Unary comma forces array return
        }
        finally {
            $fs.Close()
            $fs.Dispose()
        }
    }
    catch {
        Write-Verbose "Failed to read $FilePath : $_"
        return $null
    }
}

function ConvertTo-HexString {
    param([byte[]]$Bytes)

    if (-not $Bytes -or $Bytes.Length -eq 0) { return "" }
    return ($Bytes | ForEach-Object { $_.ToString("X2") }) -join ''
}

function Test-FileSignature {
    param(
        [byte[]]$FileBytes,
        [object]$Signature
    )

    $hexAll = ConvertTo-HexString -Bytes $FileBytes
    $offset = [int]$Signature.offset

    # Check hex signature
    if ($Signature.sigHex) {
        $sigHex = ($Signature.sigHex -replace '\s','').ToUpper()
        $sigLen = $sigHex.Length
        $startPos = $offset * 2

        if ($hexAll.Length -ge ($startPos + $sigLen)) {
            $substr = $hexAll.Substring($startPos, $sigLen)
            if ($substr -eq $sigHex) {
                return $true
            }
        }
    }

    # Check ASCII signature
    if ($Signature.sigAscii) {
        $sigBytes = [System.Text.Encoding]::ASCII.GetBytes($Signature.sigAscii)
        $sigHex = ConvertTo-HexString -Bytes $sigBytes
        $sigLen = $sigHex.Length
        $startPos = $offset * 2

        if ($hexAll.Length -ge ($startPos + $sigLen)) {
            $substr = $hexAll.Substring($startPos, $sigLen)
            if ($substr -eq $sigHex) {
                return $true
            }
        }
    }

    return $false
}

function Get-FileTypeFromBytes {
    param(
        [byte[]]$Bytes,
        [object[]]$Signatures
    )

    $signatureMatches = [System.Collections.ArrayList]::new()

    foreach ($sig in $Signatures) {
        if (Test-FileSignature -FileBytes $Bytes -Signature $sig) {
            $null = $signatureMatches.Add($sig.name)
        }
    }

    if ($signatureMatches.Count -gt 0) {
        return @{
            Detected = ($signatureMatches -join '; ')
            Confidence = if ($signatureMatches.Count -eq 1) { 'High' } else { 'Ambiguous' }
        }
    }

    return @{
        Detected = 'Unknown'
        Confidence = 'None'
    }
}

function Update-ResultsDisplay {
    param([System.Windows.Forms.ListView]$ListView)

    $ListView.Items.Clear()

    foreach ($result in $script:scanResults) {
        $item = New-Object System.Windows.Forms.ListViewItem($result.FileName)
        $item.SubItems.Add($result.Detected) | Out-Null
        $item.SubItems.Add($result.SizeKB) | Out-Null
        $item.SubItems.Add($result.Entropy) | Out-Null
        $item.SubItems.Add($result.Flags) | Out-Null
        $item.SubItems.Add($result.Confidence) | Out-Null
        $item.SubItems.Add($result.Base64Prefix) | Out-Null
        $item.SubItems.Add($result.Path) | Out-Null

        # Color coding - prioritize suspicious flags
        if ($result.Flags -ne '') {
            $item.BackColor = [System.Drawing.Color]::LightCoral
            $item.ForeColor = [System.Drawing.Color]::DarkRed
        }
        elseif ($result.Detected -eq 'Unknown') {
            $item.ForeColor = [System.Drawing.Color]::Gray
        }
        elseif ($result.Confidence -eq 'High') {
            $item.ForeColor = [System.Drawing.Color]::Green
        }
        elseif ($result.Confidence -eq 'Ambiguous') {
            $item.ForeColor = [System.Drawing.Color]::Orange
        }

        $ListView.Items.Add($item) | Out-Null
    }

    $statusLabel.Text = "Total files scanned: $($script:scanResults.Count)"
}

function Start-FileScan {
    param(
        [string]$Path,
        [bool]$Recurse,
        [int]$Base64PrefixLength
    )

    if ($script:isScanning) {
        [System.Windows.Forms.MessageBox]::Show("Scan already in progress!", "Busy", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    if (-not (Test-Path $Path)) {
        [System.Windows.Forms.MessageBox]::Show("Path does not exist: $Path", "Invalid Path", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    if (-not $script:signatures) {
        [System.Windows.Forms.MessageBox]::Show("Signatures not loaded. Please load signature JSON file first.", "No Signatures", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $script:isScanning = $true
    $script:scanResults.Clear()
    $buttonScan.Enabled = $false
    $buttonStop.Enabled = $true
    $progressBar.Value = 0
    $statusLabel.Text = "Scanning..."

    # Get file list
    try {
        $files = if ($Recurse) {
            Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue
        } else {
            Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue
        }

        $totalFiles = $files.Count
        $processedFiles = 0

        foreach ($file in $files) {
            # Check if scan was stopped
            if (-not $script:isScanning) {
                break
            }

            try {
                # Skip zero-byte files
                if ($file.Length -eq 0) {
                    $processedFiles++
                    continue
                }

                # Skip files larger than 100 MB (safety limit)
                if ($file.Length -gt 100MB) {
                    Write-Verbose "Skipping large file: $($file.Name) ($([math]::Round($file.Length / 1MB, 2)) MB)"
                    $processedFiles++
                    continue
                }

                # Read file bytes
                $bytes = Read-FilePrefix -FilePath $file.FullName -ByteCount $script:readSize

                if ($bytes) {
                    # Detect file type
                    $detection = Get-FileTypeFromBytes -Bytes $bytes -Signatures $script:signatures

                    # Analyze for hidden/suspicious content
                    $suspiciousAnalysis = Test-SuspiciousFile -Bytes $bytes -FileSize $file.Length -DetectedType $detection.Detected

                    # Generate Base64 prefix
                    $b64 = [Convert]::ToBase64String($bytes)
                    $b64Prefix = if ($b64.Length -le $Base64PrefixLength) {
                        $b64
                    } else {
                        $b64.Substring(0, $Base64PrefixLength) + "..."
                    }

                    # Add to results
                    $result = [PSCustomObject]@{
                        FileName = $file.Name
                        Path = $file.FullName
                        SizeKB = [math]::Round($file.Length / 1KB, 2)
                        Detected = $detection.Detected
                        Confidence = $detection.Confidence
                        Entropy = $suspiciousAnalysis.Entropy
                        Flags = if ($suspiciousAnalysis.Flags.Count -gt 0) { $suspiciousAnalysis.Flags -join '; ' } else { '' }
                        Base64Prefix = $b64Prefix
                    }

                    $null = $script:scanResults.Add($result)
                }
            }
            catch {
                Write-Verbose "Error processing $($file.FullName): $_"
            }

            # Update progress
            $processedFiles++
            $percentComplete = [int](($processedFiles / $totalFiles) * 100)
            $progressBar.Value = $percentComplete
            $statusLabel.Text = "Scanning... $processedFiles / $totalFiles files ($percentComplete%)"

            # Update UI every 10 files
            if ($processedFiles % 10 -eq 0) {
                Update-ResultsDisplay -ListView $listView
                [System.Windows.Forms.Application]::DoEvents()
            }
        }

        # Final update
        Update-ResultsDisplay -ListView $listView
        $progressBar.Value = 100
        $statusLabel.Text = "Scan complete. Found $($script:scanResults.Count) files."

    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error during scan: $($_.Exception.Message)", "Scan Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $script:isScanning = $false
        $buttonScan.Enabled = $true
        $buttonStop.Enabled = $false
    }
}

#endregion

#region GUI Setup

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'File Type Detector - Magic Bytes Scanner'
$form.Size = New-Object System.Drawing.Size(1200, 700)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(800, 500)

# Signature file selection
$labelSigFile = New-Object System.Windows.Forms.Label
$labelSigFile.Location = New-Object System.Drawing.Point(10, 15)
$labelSigFile.Size = New-Object System.Drawing.Size(100, 20)
$labelSigFile.Text = 'Signature File:'
$form.Controls.Add($labelSigFile)

$textboxSigFile = New-Object System.Windows.Forms.TextBox
$textboxSigFile.Location = New-Object System.Drawing.Point(120, 12)
$textboxSigFile.Size = New-Object System.Drawing.Size(400, 20)
$textboxSigFile.Text = '.\file_Signatures.json'
$form.Controls.Add($textboxSigFile)

$buttonBrowseSig = New-Object System.Windows.Forms.Button
$buttonBrowseSig.Location = New-Object System.Drawing.Point(530, 10)
$buttonBrowseSig.Size = New-Object System.Drawing.Size(80, 25)
$buttonBrowseSig.Text = 'Browse...'
$form.Controls.Add($buttonBrowseSig)

$buttonLoadSig = New-Object System.Windows.Forms.Button
$buttonLoadSig.Location = New-Object System.Drawing.Point(620, 10)
$buttonLoadSig.Size = New-Object System.Drawing.Size(100, 25)
$buttonLoadSig.Text = 'Load Signatures'
$form.Controls.Add($buttonLoadSig)

# Scan path selection
$labelPath = New-Object System.Windows.Forms.Label
$labelPath.Location = New-Object System.Drawing.Point(10, 50)
$labelPath.Size = New-Object System.Drawing.Size(100, 20)
$labelPath.Text = 'Scan Path:'
$form.Controls.Add($labelPath)

$textboxPath = New-Object System.Windows.Forms.TextBox
$textboxPath.Location = New-Object System.Drawing.Point(120, 47)
$textboxPath.Size = New-Object System.Drawing.Size(400, 20)
$textboxPath.Text = '.\'
$form.Controls.Add($textboxPath)

$buttonBrowsePath = New-Object System.Windows.Forms.Button
$buttonBrowsePath.Location = New-Object System.Drawing.Point(530, 45)
$buttonBrowsePath.Size = New-Object System.Drawing.Size(80, 25)
$buttonBrowsePath.Text = 'Browse...'
$form.Controls.Add($buttonBrowsePath)

# Options
$checkboxRecurse = New-Object System.Windows.Forms.CheckBox
$checkboxRecurse.Location = New-Object System.Drawing.Point(120, 75)
$checkboxRecurse.Size = New-Object System.Drawing.Size(150, 20)
$checkboxRecurse.Text = 'Scan subdirectories'
$checkboxRecurse.Checked = $false
$form.Controls.Add($checkboxRecurse)

$labelB64Len = New-Object System.Windows.Forms.Label
$labelB64Len.Location = New-Object System.Drawing.Point(280, 77)
$labelB64Len.Size = New-Object System.Drawing.Size(120, 20)
$labelB64Len.Text = 'Base64 Prefix Chars:'
$form.Controls.Add($labelB64Len)

$numericB64Len = New-Object System.Windows.Forms.NumericUpDown
$numericB64Len.Location = New-Object System.Drawing.Point(410, 75)
$numericB64Len.Size = New-Object System.Drawing.Size(60, 20)
$numericB64Len.Minimum = 8
$numericB64Len.Maximum = 128
$numericB64Len.Value = 24
$form.Controls.Add($numericB64Len)

# Control buttons
$buttonScan = New-Object System.Windows.Forms.Button
$buttonScan.Location = New-Object System.Drawing.Point(480, 73)
$buttonScan.Size = New-Object System.Drawing.Size(100, 25)
$buttonScan.Text = 'Start Scan'
$buttonScan.BackColor = [System.Drawing.Color]::LightGreen
$form.Controls.Add($buttonScan)

$buttonStop = New-Object System.Windows.Forms.Button
$buttonStop.Location = New-Object System.Drawing.Point(590, 73)
$buttonStop.Size = New-Object System.Drawing.Size(100, 25)
$buttonStop.Text = 'Stop Scan'
$buttonStop.Enabled = $false
$buttonStop.BackColor = [System.Drawing.Color]::LightCoral
$form.Controls.Add($buttonStop)

$buttonClear = New-Object System.Windows.Forms.Button
$buttonClear.Location = New-Object System.Drawing.Point(700, 73)
$buttonClear.Size = New-Object System.Drawing.Size(80, 25)
$buttonClear.Text = 'Clear'
$form.Controls.Add($buttonClear)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 110)
$progressBar.Size = New-Object System.Drawing.Size(1165, 20)
$progressBar.Style = 'Continuous'
$form.Controls.Add($progressBar)

# Results ListView
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(10, 140)
$listView.Size = New-Object System.Drawing.Size(1165, 450)
$listView.View = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.Columns.Add("File Name", 180) | Out-Null
$listView.Columns.Add("Detected Type", 150) | Out-Null
$listView.Columns.Add("Size (KB)", 70) | Out-Null
$listView.Columns.Add("Entropy", 60) | Out-Null
$listView.Columns.Add("Suspicious Flags", 300) | Out-Null
$listView.Columns.Add("Confidence", 80) | Out-Null
$listView.Columns.Add("Base64 Prefix", 180) | Out-Null
$listView.Columns.Add("Full Path", 350) | Out-Null
$listView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($listView)

# Export buttons
$buttonExportCsv = New-Object System.Windows.Forms.Button
$buttonExportCsv.Location = New-Object System.Drawing.Point(10, 600)
$buttonExportCsv.Size = New-Object System.Drawing.Size(100, 25)
$buttonExportCsv.Text = 'Export CSV'
$buttonExportCsv.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($buttonExportCsv)

$buttonExportJson = New-Object System.Windows.Forms.Button
$buttonExportJson.Location = New-Object System.Drawing.Point(120, 600)
$buttonExportJson.Size = New-Object System.Drawing.Size(100, 25)
$buttonExportJson.Text = 'Export JSON'
$buttonExportJson.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($buttonExportJson)

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 635)
$statusLabel.Size = New-Object System.Drawing.Size(1165, 20)
$statusLabel.Text = 'Ready. Load signatures to begin.'
$statusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($statusLabel)

#endregion

#region Event Handlers

# Browse signature file
$buttonBrowseSig.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
    $openFileDialog.Title = "Select Signature JSON File"

    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $textboxSigFile.Text = $openFileDialog.FileName
    }
})

# Load signatures
$buttonLoadSig.Add_Click({
    $sigPath = $textboxSigFile.Text

    if (-not (Test-Path $sigPath)) {
        [System.Windows.Forms.MessageBox]::Show("Signature file not found: $sigPath", "File Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # Check file size (max 10 MB for JSON)
    $fileInfo = Get-Item -Path $sigPath
    if ($fileInfo.Length -gt 10MB) {
        [System.Windows.Forms.MessageBox]::Show("Signature file is too large ($([math]::Round($fileInfo.Length / 1MB, 2)) MB). Maximum allowed: 10 MB", "File Too Large", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    try {
        # Load JSON
        $jsonContent = Get-Content -Raw -Path $sigPath -ErrorAction Stop

        # Parse JSON
        $parsedSigs = $null
        try {
            $parsedSigs = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Invalid JSON format: $($_.Exception.Message)", "JSON Parse Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        # Security validation
        $validation = Test-JsonSignatureSafe -Signatures $parsedSigs

        if (-not $validation.IsValid) {
            $errorMsg = "Signature validation failed:`n`n"
            $errorMsg += ($validation.Errors | Select-Object -First 10) -join "`n"

            if ($validation.Errors.Count -gt 10) {
                $errorMsg += "`n`n... and $($validation.Errors.Count - 10) more errors"
            }

            [System.Windows.Forms.MessageBox]::Show($errorMsg, "Validation Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        # Filter to only valid signatures
        $validSignatures = [System.Collections.ArrayList]::new()
        foreach ($sig in $parsedSigs) {
            # Re-validate each signature individually
            if ($sig.PSObject.Properties['name'] -and
                $sig.PSObject.Properties['offset'] -and
                ($sig.PSObject.Properties['sigHex'] -or $sig.PSObject.Properties['sigAscii'])) {
                $null = $validSignatures.Add($sig)
            }
        }

        $script:signatures = $validSignatures

        # Calculate required read size based on valid signatures
        $maxNeeded = 0
        foreach ($sig in $script:signatures) {
            $sigLen = 0
            if ($sig.sigHex) {
                $sigLen = ([regex]::Matches($sig.sigHex, '..')).Count
            }
            elseif ($sig.sigAscii) {
                $sigLen = [System.Text.Encoding]::ASCII.GetByteCount($sig.sigAscii)
            }
            $needed = [int]$sig.offset + $sigLen
            if ($needed -gt $maxNeeded) { $maxNeeded = $needed }
        }
        $script:readSize = [Math]::Max(64, $maxNeeded)

        # Cap read size at 10 MB for safety
        if ($script:readSize -gt 10MB) {
            $script:readSize = 10MB
            $statusLabel.Text = "WARNING: Read size capped at 10 MB for safety"
        }

        $statusLabel.Text = "Loaded $($script:signatures.Count) validated signatures. Read size: $($script:readSize) bytes. Ready to scan."
        [System.Windows.Forms.MessageBox]::Show("Successfully loaded and validated $($script:signatures.Count) file signatures.`n`nValid signatures: $($validation.ValidSignatureCount)", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to load signatures: $($_.Exception.Message)", "Load Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $script:signatures = $null
    }
})

# Browse scan path
$buttonBrowsePath.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select folder to scan"
    $folderBrowser.ShowNewFolderButton = $false

    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $textboxPath.Text = $folderBrowser.SelectedPath
    }
})

# Start scan
$buttonScan.Add_Click({
    $path = $textboxPath.Text
    $recurse = $checkboxRecurse.Checked
    $b64Len = [int]$numericB64Len.Value

    # Validate path safety
    $pathCheck = Test-PathSafe -Path $path
    if (-not $pathCheck.IsSafe) {
        if ($pathCheck.PSObject.Properties['IsWarningOnly'] -and $pathCheck.IsWarningOnly) {
            # Show warning but allow user to proceed
            $result = [System.Windows.Forms.MessageBox]::Show(
                "$($pathCheck.Reason)`n`nDo you want to proceed anyway?",
                "Warning - System Directory",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
                return
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show($pathCheck.Reason, "Invalid Path", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
    }

    Start-FileScan -Path $path -Recurse $recurse -Base64PrefixLength $b64Len
})

# Stop scan
$buttonStop.Add_Click({
    $script:isScanning = $false
    $statusLabel.Text = "Scan stopped by user."
})

# Clear results
$buttonClear.Add_Click({
    $script:scanResults.Clear()
    $listView.Items.Clear()
    $progressBar.Value = 0
    $statusLabel.Text = "Results cleared. Ready to scan."
})

# Export CSV
$buttonExportCsv.Add_Click({
    if ($script:scanResults.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No results to export. Run a scan first.", "No Data", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
    $saveFileDialog.Title = "Export Results to CSV"
    $saveFileDialog.FileName = "FileTypeDetection_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $script:scanResults | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Results exported successfully to:`n$($saveFileDialog.FileName)", "Export Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Export failed: $($_.Exception.Message)", "Export Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

# Export JSON
$buttonExportJson.Add_Click({
    if ($script:scanResults.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No results to export. Run a scan first.", "No Data", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
    $saveFileDialog.Title = "Export Results to JSON"
    $saveFileDialog.FileName = "FileTypeDetection_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $script:scanResults | ConvertTo-Json -Depth 4 | Out-File -FilePath $saveFileDialog.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Results exported successfully to:`n$($saveFileDialog.FileName)", "Export Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Export failed: $($_.Exception.Message)", "Export Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

# ListView double-click to show full details
$listView.Add_DoubleClick({
    if ($listView.SelectedItems.Count -gt 0) {
        $item = $listView.SelectedItems[0]
        $fullPath = $item.SubItems[7].Text  # Updated index for Full Path

        $msgForm = New-Object System.Windows.Forms.Form
        $msgForm.Text = "File Details"
        $msgForm.Size = New-Object System.Drawing.Size(700, 400)
        $msgForm.StartPosition = 'CenterParent'

        $txtDetails = New-Object System.Windows.Forms.TextBox
        $txtDetails.Location = New-Object System.Drawing.Point(10, 10)
        $txtDetails.Size = New-Object System.Drawing.Size(660, 320)
        $txtDetails.Multiline = $true
        $txtDetails.ReadOnly = $true
        $txtDetails.ScrollBars = 'Vertical'
        $txtDetails.Font = New-Object System.Drawing.Font("Consolas", 9)

        $suspiciousFlags = $item.SubItems[4].Text
        $warningText = if ($suspiciousFlags -ne '') {
            "`n`n⚠️ SECURITY ALERT ⚠️`n$suspiciousFlags"
        } else {
            ""
        }

        $details = @"
File Name: $($item.SubItems[0].Text)
Detected Type: $($item.SubItems[1].Text)
Size: $($item.SubItems[2].Text) KB
Entropy: $($item.SubItems[3].Text) / 8.0
Confidence: $($item.SubItems[5].Text)
Base64 Prefix: $($item.SubItems[6].Text)
Full Path: $fullPath$warningText

---
Entropy Information:
  0.0 - 3.0  : Very low (repetitive data, padding)
  3.0 - 5.0  : Low (plain text, structured data)
  5.0 - 7.0  : Moderate (typical files, some compression)
  7.0 - 7.5  : High (compressed files, encrypted data)
  7.5 - 8.0  : Very high (encryption, steganography, random data)
"@
        $txtDetails.Text = $details
        $msgForm.Controls.Add($txtDetails)

        $btnClose = New-Object System.Windows.Forms.Button
        $btnClose.Location = New-Object System.Drawing.Point(250, 235)
        $btnClose.Size = New-Object System.Drawing.Size(75, 25)
        $btnClose.Text = 'Close'
        $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $msgForm.Controls.Add($btnClose)
        $msgForm.AcceptButton = $btnClose

        [void]$msgForm.ShowDialog()
    }
})

#endregion

# Show the form
[void]$form.ShowDialog()

# Cleanup
$form.Dispose()
