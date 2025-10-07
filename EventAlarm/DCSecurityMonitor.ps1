#Requires -Version 5.1

<#
.SYNOPSIS
    Domain Controller Security Event Monitor
.DESCRIPTION
    Monitors all domain controllers in the current domain for specific security events.
    Requires elevated privileges and domain credentials.
    Requires Windows PowerShell 5.1 (not PowerShell Core/7.x due to WinRM authentication limitations).
    Created by Trond Hoiberg
    Feel free to use and modify this script as needed.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$script:Credential = $null
$script:DomainControllers = @()
$script:MonitoringActive = $false
$script:EventAlerts = @{}
$script:ActiveJobs = @{}
$script:ServerEventIDs = @{}
# Default Event IDs focused on insider threats and lateral movement
$script:DefaultEventIDs = @(
    1102,  # Audit log cleared - attacker covering tracks
    4624,  # Successful logon - lateral movement detection
    4625,  # Failed logon - brute force/password spray
    4648,  # Logon with explicit credentials - privilege escalation
    4672,  # Special privileges assigned - admin rights granted
    4720,  # User account created - backdoor account
    4728,  # Member added to global group - privilege escalation
    4732,  # Member added to local group - local admin granted
    4719,  # Audit policy changed - disabling logging
    4768   # Kerberos TGT requested - golden ticket attacks
)

# Event ID 4624 filtering configuration (reduces noise)
# Set to $true to filter 4624 events, $false to see all
$script:Filter4624 = $true
$script:Filter4624LogonTypes = @(3, 10)  # 3=Network, 10=RemoteInteractive (RDP)
# Optionally filter by business hours (24-hour format, $null to disable)
$script:BusinessHoursStart = $null  # Example: 8 for 8 AM
$script:BusinessHoursEnd = $null    # Example: 18 for 6 PM

#region Functions

function Get-DomainCredential {
    try {
        # Create custom credential dialog
        $credForm = New-Object System.Windows.Forms.Form
        $credForm.Text = "Enter Domain Credentials"
        $credForm.Size = New-Object System.Drawing.Size(400, 200)
        $credForm.StartPosition = "CenterScreen"
        $credForm.FormBorderStyle = "FixedDialog"
        $credForm.MaximizeBox = $false
        $credForm.MinimizeBox = $false

        $lblUser = New-Object System.Windows.Forms.Label
        $lblUser.Location = New-Object System.Drawing.Point(10, 20)
        $lblUser.Size = New-Object System.Drawing.Size(100, 20)
        $lblUser.Text = "Username:"
        $credForm.Controls.Add($lblUser)

        $txtUser = New-Object System.Windows.Forms.TextBox
        $txtUser.Location = New-Object System.Drawing.Point(120, 20)
        $txtUser.Size = New-Object System.Drawing.Size(250, 20)
        $credForm.Controls.Add($txtUser)

        $lblPass = New-Object System.Windows.Forms.Label
        $lblPass.Location = New-Object System.Drawing.Point(10, 60)
        $lblPass.Size = New-Object System.Drawing.Size(100, 20)
        $lblPass.Text = "Password:"
        $credForm.Controls.Add($lblPass)

        $txtPass = New-Object System.Windows.Forms.TextBox
        $txtPass.Location = New-Object System.Drawing.Point(120, 60)
        $txtPass.Size = New-Object System.Drawing.Size(250, 20)
        $txtPass.UseSystemPasswordChar = $true
        $credForm.Controls.Add($txtPass)

        $btnOK = New-Object System.Windows.Forms.Button
        $btnOK.Location = New-Object System.Drawing.Point(120, 110)
        $btnOK.Size = New-Object System.Drawing.Size(75, 23)
        $btnOK.Text = "OK"
        $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $credForm.Controls.Add($btnOK)
        $credForm.AcceptButton = $btnOK

        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Location = New-Object System.Drawing.Point(210, 110)
        $btnCancel.Size = New-Object System.Drawing.Size(75, 23)
        $btnCancel.Text = "Cancel"
        $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $credForm.Controls.Add($btnCancel)
        $credForm.CancelButton = $btnCancel

        $result = $credForm.ShowDialog()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            if ([string]::IsNullOrEmpty($txtUser.Text) -or [string]::IsNullOrEmpty($txtPass.Text)) {
                [System.Windows.Forms.MessageBox]::Show("Username and password are required.", "Invalid Input", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return $null
            }

            # Store username and password immediately before clearing
            $username = $txtUser.Text
            $password = $txtPass.Text

            # Create credential object
            $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
            $cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

            # Clear the password textbox
            $txtPass.Text = ""

            # Validate credentials by attempting to get domain info
            $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            $domainControllers = $domain.DomainControllers | Select-Object -ExpandProperty Name

            # Try each DC until one responds
            $validated = $false
            $lastError = $null

            foreach ($dc in $domainControllers) {
                try {
                    Write-Host "Testing connection to $dc..."

                    # Test connectivity with credentials using WinRM (Invoke-Command) instead of RPC (Get-WinEvent)
                    $null = Invoke-Command -ComputerName $dc -Credential $cred -ScriptBlock {
                        Get-WinEvent -LogName System -MaxEvents 1 -ErrorAction Stop
                    } -ErrorAction Stop
                    Write-Host "Successfully connected to $dc" -ForegroundColor Green
                    $validated = $true
                    break
                }
                catch {
                    $lastError = $_.Exception.Message
                    Write-Host "Failed to connect to $dc : $lastError" -ForegroundColor Yellow
                    continue
                }
            }

            if ($validated) {
                return $cred
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Could not validate credentials on any domain controller. Last error: $lastError", "Authentication Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return $null
            }
        }
        return $null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Credential validation failed: $($_.Exception.Message)", "Authentication Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $null
    }
}

function Get-DomainControllerList {
    try {
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $script:DomainControllers = $domain.DomainControllers | ForEach-Object { $_.Name }
        return $true
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to retrieve domain controllers: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Start-SecurityEventMonitoring {
    param (
        [string]$ComputerName,
        [System.Windows.Forms.ListViewItem]$ListItem,
        [System.Windows.Forms.TextBox]$DetailsBox
    )

    # Cancel existing job for this DC if running
    if ($script:ActiveJobs.ContainsKey($ComputerName)) {
        $oldJob = $script:ActiveJobs[$ComputerName]
        if ($oldJob.Job) {
            Stop-Job -Job $oldJob.Job -ErrorAction SilentlyContinue
            Remove-Job -Job $oldJob.Job -Force -ErrorAction SilentlyContinue
        }
        $script:ActiveJobs.Remove($ComputerName)
    }

    # Get Event IDs to monitor for this server (use custom or default)
    if ($script:ServerEventIDs.ContainsKey($ComputerName)) {
        $EventIDs = $script:ServerEventIDs[$ComputerName]
    }
    else {
        $EventIDs = $script:DefaultEventIDs
    }

    # Update UI to show checking status
    if ($ListItem.ListView) {
        $ListItem.BackColor = [System.Drawing.Color]::LightYellow
        $ListItem.SubItems[1].Text = "Checking..."
    }

    # Start PowerShell job (can serialize PSCredential properly)
    $job = Start-Job -ScriptBlock {
        param($Computer, $Cred, $EventIDs, $Filter4624, $Filter4624LogonTypes, $BusinessHoursStart, $BusinessHoursEnd)

        $result = @{
            Success = $false
            ComputerName = $Computer
            Events = @()
            Error = $null
        }

        try {
            # Use Invoke-Command with WinRM instead of Get-WinEvent with RPC
            $events = @(Invoke-Command -ComputerName $Computer -Credential $Cred -ScriptBlock {
                param($EventIDs)
                Get-WinEvent -FilterHashtable @{
                    LogName = 'Security'
                    ID = $EventIDs
                    StartTime = (Get-Date).AddMinutes(-5)
                } -ErrorAction SilentlyContinue -MaxEvents 100
            } -ArgumentList (,$EventIDs) -ErrorAction Stop)

            # Filter Event ID 4624 if enabled
            if ($Filter4624) {
                $events = $events | Where-Object {
                    if ($_.Id -eq 4624) {
                        # Parse logon type from event (Property index 8)
                        try {
                            $logonType = $_.Properties[8].Value
                            $matchesLogonType = $Filter4624LogonTypes -contains $logonType

                            # Check business hours if configured
                            $outsideBusinessHours = $true
                            if ($null -ne $BusinessHoursStart -and $null -ne $BusinessHoursEnd) {
                                $eventHour = $_.TimeCreated.Hour
                                $outsideBusinessHours = ($eventHour -lt $BusinessHoursStart -or $eventHour -ge $BusinessHoursEnd)
                            }

                            # Include if matches logon type AND (no business hours filter OR outside business hours)
                            return $matchesLogonType -and ($null -eq $BusinessHoursStart -or $outsideBusinessHours)
                        }
                        catch {
                            # If parsing fails, include the event
                            return $true
                        }
                    }
                    else {
                        # Not 4624, include it
                        return $true
                    }
                }
            }

            $result.Success = $true
            $result.Events = $events | ForEach-Object {
                @{
                    Time = $_.TimeCreated
                    EventID = $_.Id
                    Message = $_.Message
                    Computer = $Computer
                    RecordId = $_.RecordId
                }
            }
        }
        catch {
            $result.Error = $_.Exception.Message
        }

        return $result
    } -ArgumentList $ComputerName, $script:Credential, $EventIDs, $script:Filter4624, $script:Filter4624LogonTypes, $script:BusinessHoursStart, $script:BusinessHoursEnd

    # Store job info
    $script:ActiveJobs[$ComputerName] = @{
        Job = $job
        ListItem = $ListItem
        DetailsBox = $DetailsBox
        StartTime = Get-Date
    }
}

function Update-MonitoringResults {
    $completedJobs = @()

    foreach ($computerName in @($script:ActiveJobs.Keys)) {
        $jobInfo = $script:ActiveJobs[$computerName]

        if (-not $jobInfo -or -not $jobInfo.Job) {
            $completedJobs += $computerName
            continue
        }

        $job = $jobInfo.Job

        # Check for timeout (15 seconds)
        if ((Get-Date) - $jobInfo.StartTime -gt [TimeSpan]::FromSeconds(15)) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue

            if ($jobInfo.ListItem -and $jobInfo.ListItem.ListView) {
                $jobInfo.ListItem.BackColor = [System.Drawing.Color]::Orange
                $jobInfo.ListItem.ForeColor = [System.Drawing.Color]::Black
                $jobInfo.ListItem.SubItems[1].Text = "Timeout - Server not responding"
            }
            $completedJobs += $computerName
            continue
        }

        # Check if completed
        if ($job.State -eq 'Completed' -or $job.State -eq 'Failed') {
            try {
                $result = Receive-Job -Job $job -ErrorAction Stop

                if (-not $jobInfo.ListItem -or -not $jobInfo.ListItem.ListView) {
                    $completedJobs += $computerName
                    continue
                }

                if ($result -and $result.Success) {
                    if ($result.Events.Count -gt 0) {
                        # Alert detected
                        if (-not $script:EventAlerts.ContainsKey($computerName)) {
                            $script:EventAlerts[$computerName] = @{}
                        }

                        $jobInfo.ListItem.BackColor = [System.Drawing.Color]::Red
                        $jobInfo.ListItem.ForeColor = [System.Drawing.Color]::White
                        $jobInfo.ListItem.SubItems[1].Text = "ALERT - $($result.Events.Count) event(s)"

                        # Store alerts by RecordId to prevent duplicates
                        foreach ($evt in $result.Events) {
                            $script:EventAlerts[$computerName][$evt.RecordId] = $evt
                        }

                        # Update details box
                        $details = "=== ALERT: $computerName ===`r`n"
                        $alertList = $script:EventAlerts[$computerName].Values | Sort-Object Time -Descending
                        foreach ($alert in $alertList) {
                            $details += "`r`nTime: $($alert.Time)`r`n"
                            $details += "Event ID: $($alert.EventID)`r`n"
                            $details += "Record ID: $($alert.RecordId)`r`n"
                            $details += "Message: $($alert.Message)`r`n"
                            $details += "-" * 80 + "`r`n"
                        }

                        if (-not $jobInfo.DetailsBox.IsDisposed) {
                            $jobInfo.DetailsBox.Text = $details
                        }
                    }
                    else {
                        # No alerts - set to green
                        if (-not $script:EventAlerts.ContainsKey($computerName) -or $script:EventAlerts[$computerName].Count -eq 0) {
                            $jobInfo.ListItem.BackColor = [System.Drawing.Color]::LightGreen
                            $jobInfo.ListItem.ForeColor = [System.Drawing.Color]::Black
                            $jobInfo.ListItem.SubItems[1].Text = "OK - No alerts"
                        }
                        else {
                            # Previous alerts exist, keep red
                            $jobInfo.ListItem.SubItems[1].Text = "Previous alerts active"
                        }
                    }
                }
                else {
                    # Error occurred
                    $jobInfo.ListItem.BackColor = [System.Drawing.Color]::Yellow
                    $jobInfo.ListItem.ForeColor = [System.Drawing.Color]::Black
                    $jobInfo.ListItem.SubItems[1].Text = "Error: $($result.Error)"
                }
            }
            catch {
                if ($jobInfo.ListItem -and $jobInfo.ListItem.ListView) {
                    $jobInfo.ListItem.BackColor = [System.Drawing.Color]::Yellow
                    $jobInfo.ListItem.ForeColor = [System.Drawing.Color]::Black
                    $jobInfo.ListItem.SubItems[1].Text = "Error: $($_.Exception.Message)"
                }
            }

            $completedJobs += $computerName
        }
    }

    # Clean up completed jobs
    foreach ($computerName in $completedJobs) {
        if ($script:ActiveJobs.ContainsKey($computerName)) {
            try {
                if ($script:ActiveJobs[$computerName].Job) {
                    Remove-Job -Job $script:ActiveJobs[$computerName].Job -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                # Ignore disposal errors
            }
            $script:ActiveJobs.Remove($computerName)
        }
    }
}

function Clear-OldAlerts {
    # Clear alerts older than 1 hour
    $cutoffTime = (Get-Date).AddHours(-1)

    foreach ($computerName in @($script:EventAlerts.Keys)) {
        $alerts = $script:EventAlerts[$computerName]
        $recentAlerts = @{}

        foreach ($recordId in $alerts.Keys) {
            if ($alerts[$recordId].Time -gt $cutoffTime) {
                $recentAlerts[$recordId] = $alerts[$recordId]
            }
        }

        if ($recentAlerts.Count -gt 0) {
            $script:EventAlerts[$computerName] = $recentAlerts
        }
        else {
            $script:EventAlerts.Remove($computerName)
        }
    }
}

function Clear-Credentials {
    if ($script:Credential) {
        $script:Credential = $null
    }
    if ($script:Username) {
        $script:Username = $null
    }
    if ($script:Password) {
        $script:Password = $null
    }
    [System.GC]::Collect()
}

function Update-MonitoredIDsDisplay {
    param(
        [System.Windows.Forms.TextBox]$TextBox
    )

    try {
        $display = "Default: $($script:DefaultEventIDs -join ', ')"

        if ($script:ServerEventIDs.Count -gt 0) {
            $display += "`r`n`r`nCustom configurations:"
            foreach ($server in $script:ServerEventIDs.Keys | Sort-Object) {
                $display += "`r`n  $server : $($script:ServerEventIDs[$server] -join ', ')"
            }
        }

        if (-not $TextBox.IsDisposed) {
            $TextBox.Text = $display
        }
    }
    catch {
        # Silently handle if control is disposed
    }
}

#endregion

#region Main GUI

# Get credentials
$script:Credential = Get-DomainCredential
if (-not $script:Credential) {
    [System.Windows.Forms.MessageBox]::Show("Valid credentials required to run this application.", "Authentication Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    exit
}

# Verify credential is properly set (debugging)
Write-Host "Credential validated successfully" -ForegroundColor Green
Write-Host "Username: $($script:Credential.UserName)" -ForegroundColor Cyan

# Get domain controllers
if (-not (Get-DomainControllerList)) {
    Clear-Credentials
    exit
}

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Domain Controller Security Event Monitor"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"

# Create ListView for domain controllers
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(10, 10)
$listView.Size = New-Object System.Drawing.Size(760, 280)
$listView.View = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.Columns.Add("Domain Controller", 300) | Out-Null
$listView.Columns.Add("Status", 440) | Out-Null
$form.Controls.Add($listView)

# Add context menu for per-server Event ID configuration
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$menuItemConfig = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemConfig.Text = "Configure Event IDs..."
$menuItemConfig.Add_Click({
    if ($listView.SelectedItems.Count -gt 0) {
        $selectedDC = $listView.SelectedItems[0].Text

        # Get current IDs for this server
        $currentIDs = if ($script:ServerEventIDs.ContainsKey($selectedDC)) {
            $script:ServerEventIDs[$selectedDC] -join ', '
        } else {
            $script:DefaultEventIDs -join ', '
        }

        # Prompt for new IDs
        $inputForm = New-Object System.Windows.Forms.Form
        $inputForm.Text = "Configure Event IDs - $selectedDC"
        $inputForm.Size = New-Object System.Drawing.Size(500, 200)
        $inputForm.StartPosition = "CenterParent"

        $label = New-Object System.Windows.Forms.Label
        $label.Location = New-Object System.Drawing.Point(10, 20)
        $label.Size = New-Object System.Drawing.Size(460, 40)
        $label.Text = "Enter Event IDs to monitor (comma-separated):`nLeave empty to use default IDs"
        $inputForm.Controls.Add($label)

        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Location = New-Object System.Drawing.Point(10, 70)
        $textBox.Size = New-Object System.Drawing.Size(460, 20)
        $textBox.Text = $currentIDs
        $inputForm.Controls.Add($textBox)

        $btnOK = New-Object System.Windows.Forms.Button
        $btnOK.Location = New-Object System.Drawing.Point(200, 110)
        $btnOK.Size = New-Object System.Drawing.Size(75, 23)
        $btnOK.Text = "OK"
        $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $inputForm.Controls.Add($btnOK)
        $inputForm.AcceptButton = $btnOK

        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Location = New-Object System.Drawing.Point(290, 110)
        $btnCancel.Size = New-Object System.Drawing.Size(75, 23)
        $btnCancel.Text = "Cancel"
        $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $inputForm.Controls.Add($btnCancel)

        $result = $inputForm.ShowDialog()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            if ([string]::IsNullOrWhiteSpace($textBox.Text)) {
                # Remove custom config, use default
                $script:ServerEventIDs.Remove($selectedDC)
            }
            else {
                # Parse and store custom IDs
                try {
                    $ids = $textBox.Text -split ',' | ForEach-Object { [int]$_.Trim() }
                    $script:ServerEventIDs[$selectedDC] = $ids
                    [System.Windows.Forms.MessageBox]::Show("Event IDs updated for $selectedDC", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show("Invalid Event ID format. Please use comma-separated numbers.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }

            # Update the monitored IDs display
            Update-MonitoredIDsDisplay -TextBox $txtMonitoredIDs
        }
    }
})
$contextMenu.Items.Add($menuItemConfig) | Out-Null
$listView.ContextMenuStrip = $contextMenu

# Populate ListView with domain controllers
foreach ($dc in $script:DomainControllers) {
    $item = New-Object System.Windows.Forms.ListViewItem($dc)
    $item.SubItems.Add("Initializing...") | Out-Null
    $item.BackColor = [System.Drawing.Color]::LightGray
    $listView.Items.Add($item) | Out-Null
}

# Create Monitored Event IDs display
$lblMonitoredIDs = New-Object System.Windows.Forms.Label
$lblMonitoredIDs.Location = New-Object System.Drawing.Point(10, 300)
$lblMonitoredIDs.Size = New-Object System.Drawing.Size(760, 20)
$lblMonitoredIDs.Text = "Monitored Event IDs (Right-click server to customize):"
$form.Controls.Add($lblMonitoredIDs)

$txtMonitoredIDs = New-Object System.Windows.Forms.TextBox
$txtMonitoredIDs.Location = New-Object System.Drawing.Point(10, 325)
$txtMonitoredIDs.Size = New-Object System.Drawing.Size(760, 40)
$txtMonitoredIDs.Multiline = $true
$txtMonitoredIDs.ReadOnly = $true
$txtMonitoredIDs.BackColor = [System.Drawing.Color]::WhiteSmoke
$txtMonitoredIDs.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtMonitoredIDs.Text = "Default: $($script:DefaultEventIDs -join ', ')"
$form.Controls.Add($txtMonitoredIDs)

# Create details TextBox
$lblDetails = New-Object System.Windows.Forms.Label
$lblDetails.Location = New-Object System.Drawing.Point(10, 375)
$lblDetails.Size = New-Object System.Drawing.Size(760, 20)
$lblDetails.Text = "Event Details:"
$form.Controls.Add($lblDetails)

$txtDetails = New-Object System.Windows.Forms.TextBox
$txtDetails.Location = New-Object System.Drawing.Point(10, 400)
$txtDetails.Size = New-Object System.Drawing.Size(760, 115)
$txtDetails.Multiline = $true
$txtDetails.ScrollBars = "Vertical"
$txtDetails.ReadOnly = $true
$txtDetails.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtDetails)

# Create status label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(10, 525)
$lblStatus.Size = New-Object System.Drawing.Size(760, 20)
$lblStatus.Text = "Monitoring started. Checking every 30 seconds..."
$form.Controls.Add($lblStatus)

# Create timer for monitoring
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30000 # 30 seconds
$timer.Add_Tick({
    try {
        $lblStatus.Text = "Last check: $(Get-Date -Format 'HH:mm:ss')"

        # Clear old alerts
        Clear-OldAlerts

        # Start monitoring jobs for each DC
        for ($i = 0; $i -lt $listView.Items.Count; $i++) {
            $item = $listView.Items[$i]
            $dc = $item.Text
            Start-SecurityEventMonitoring -ComputerName $dc -ListItem $item -DetailsBox $txtDetails
        }
    }
    catch {
        $lblStatus.Text = "Error during monitoring: $($_.Exception.Message)"
        Write-Host "Error in main timer: $($_.Exception.Message)" -ForegroundColor Red
    }
})

# Create timer for checking job results (1000ms for stability)
$resultTimer = New-Object System.Windows.Forms.Timer
$resultTimer.Interval = 1000 # 1 second
$resultTimer.Add_Tick({
    try {
        Update-MonitoringResults
    }
    catch {
        # Silently handle errors to prevent timer from stopping
        Write-Host "Error in result timer: $($_.Exception.Message)" -ForegroundColor Red
    }
})

# Start monitoring
$script:MonitoringActive = $true

# Start timers
$timer.Start()
$resultTimer.Start()

# Do initial check after form loads (non-blocking)
$form.Add_Shown({
    $lblStatus.Text = "Initial check: $(Get-Date -Format 'HH:mm:ss')"
    for ($i = 0; $i -lt $listView.Items.Count; $i++) {
        $item = $listView.Items[$i]
        $dc = $item.Text
        Start-SecurityEventMonitoring -ComputerName $dc -ListItem $item -DetailsBox $txtDetails
    }
})

# Show form
$form.Add_FormClosing({
    $timer.Stop()
    $resultTimer.Stop()
    $script:MonitoringActive = $false

    # Stop all running jobs
    foreach ($computerName in @($script:ActiveJobs.Keys)) {
        if ($script:ActiveJobs[$computerName].Job) {
            Stop-Job -Job $script:ActiveJobs[$computerName].Job -ErrorAction SilentlyContinue
            Remove-Job -Job $script:ActiveJobs[$computerName].Job -Force -ErrorAction SilentlyContinue
        }
    }
    $script:ActiveJobs.Clear()

    Clear-Credentials
})

[void]$form.ShowDialog()

# Final cleanup
Get-Job | Where-Object { $_.Name -like "*" } | Remove-Job -Force -ErrorAction SilentlyContinue
Clear-Credentials

#endregion
