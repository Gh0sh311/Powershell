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
$script:RunspacePool = $null
$script:ActiveJobs = @{}
$script:ServerEventIDs = @{}
$script:DefaultEventIDs = @(1102, 4719, 4765, 4766, 4794, 4897, 4964)

#region Functions

function Initialize-RunspacePool {
    $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $script:RunspacePool = [runspacefactory]::CreateRunspacePool(1, 10, $initialSessionState, $Host)
    $script:RunspacePool.Open()
}

function Close-RunspacePool {
    if ($script:RunspacePool) {
        $script:RunspacePool.Close()
        $script:RunspacePool.Dispose()
        $script:RunspacePool = $null
    }
}

function Get-DomainCredential {
    try {
        $cred = Get-Credential -Message "Enter domain credentials with permission to query domain controllers"
        if ($cred) {
            # Validate credentials by attempting to get domain info
            $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            $domainControllers = $domain.DomainControllers | Select-Object -ExpandProperty Name

            # Try each DC until one responds
            $validated = $false
            $lastError = $null

            foreach ($dc in $domainControllers) {
                try {
                    Write-Host "Testing connection to $dc..."

                    # Test connectivity with credentials by querying a single event
                    $null = Get-WinEvent -ComputerName $dc -Credential $cred -LogName System -MaxEvents 1 -ErrorAction Stop
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
        if ($oldJob.Handle -and -not $oldJob.Handle.IsCompleted) {
            $oldJob.PowerShell.Stop()
        }
        $oldJob.PowerShell.Dispose()
        $script:ActiveJobs.Remove($ComputerName)
    }

    # Create PowerShell instance
    $ps = [powershell]::Create()
    $ps.RunspacePool = $script:RunspacePool

    # Add script block
    [void]$ps.AddScript({
        param($Computer, $Username, $Password, $EventIDs)

        $result = @{
            Success = $false
            ComputerName = $Computer
            Events = @()
            Error = $null
        }

        try {
            # Validate parameters
            if ([string]::IsNullOrEmpty($Password)) {
                throw "Password parameter is empty or null"
            }
            if ([string]::IsNullOrEmpty($Username)) {
                throw "Username parameter is empty or null"
            }

            # Reconstruct credential from username and secure string
            $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
            $Cred = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

            # Query events directly - no need to test connection first
            # Get-WinEvent will fail gracefully if connection is not available
            $events = @(Get-WinEvent -ComputerName $Computer -Credential $Cred -FilterHashtable @{
                LogName = 'Security'
                ID = $EventIDs
                StartTime = (Get-Date).AddMinutes(-5)
            } -ErrorAction SilentlyContinue -MaxEvents 100)

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
    })

    # Get Event IDs to monitor for this server (use custom or default)
    if ($script:ServerEventIDs.ContainsKey($ComputerName)) {
        $EventIDs = $script:ServerEventIDs[$ComputerName]
    }
    else {
        $EventIDs = $script:DefaultEventIDs
    }

    # Add parameters - convert credential to username and plain text password for serialization
    # NOTE: Password is passed as plain text because PSCredential objects cannot be serialized across runspaces.
    # The password stays in memory only and is converted back to SecureString in the runspace.
    if ($script:Credential -is [System.Management.Automation.PSCredential]) {
        $password = $script:Credential.GetNetworkCredential().Password
        if ([string]::IsNullOrEmpty($password)) {
            throw "Credential password is empty"
        }

        [void]$ps.AddParameter('Computer', $ComputerName)
        [void]$ps.AddParameter('Username', $script:Credential.UserName)
        [void]$ps.AddParameter('Password', $password)
        [void]$ps.AddParameter('EventIDs', $EventIDs)
    }
    else {
        throw "Invalid credential object type: $($script:Credential.GetType().FullName)"
    }

    # Start async execution
    $handle = $ps.BeginInvoke()

    # Store job info
    $script:ActiveJobs[$ComputerName] = @{
        PowerShell = $ps
        Handle = $handle
        ListItem = $ListItem
        DetailsBox = $DetailsBox
        StartTime = Get-Date
    }
}

function Update-MonitoringResults {
    $completedJobs = @()

    foreach ($computerName in @($script:ActiveJobs.Keys)) {
        $job = $script:ActiveJobs[$computerName]

        # Check for timeout (30 seconds)
        if ((Get-Date) - $job.StartTime -gt [TimeSpan]::FromSeconds(30)) {
            $job.PowerShell.Stop()
            if ($job.ListItem.ListView) {
                $job.ListItem.BackColor = [System.Drawing.Color]::Orange
                $job.ListItem.ForeColor = [System.Drawing.Color]::Black
                $job.ListItem.SubItems[1].Text = "Timeout"
            }
            $completedJobs += $computerName
            continue
        }

        # Check if completed
        if ($job.Handle.IsCompleted) {
            try {
                $result = $job.PowerShell.EndInvoke($job.Handle)

                if (-not $job.ListItem.ListView) {
                    $completedJobs += $computerName
                    continue
                }

                if ($result.Success) {
                    if ($result.Events.Count -gt 0) {
                        # Alert detected
                        if (-not $script:EventAlerts.ContainsKey($computerName)) {
                            $script:EventAlerts[$computerName] = @{}
                        }

                        $job.ListItem.BackColor = [System.Drawing.Color]::Red
                        $job.ListItem.ForeColor = [System.Drawing.Color]::White
                        $job.ListItem.SubItems[1].Text = "ALERT - $($result.Events.Count) event(s)"

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

                        if (-not $job.DetailsBox.IsDisposed) {
                            $job.DetailsBox.Text = $details
                        }
                    }
                    else {
                        # No alerts - set to green
                        if (-not $script:EventAlerts.ContainsKey($computerName) -or $script:EventAlerts[$computerName].Count -eq 0) {
                            $job.ListItem.BackColor = [System.Drawing.Color]::LightGreen
                            $job.ListItem.ForeColor = [System.Drawing.Color]::Black
                            $job.ListItem.SubItems[1].Text = "OK - No alerts"
                        }
                        else {
                            # Previous alerts exist, keep red
                            $job.ListItem.SubItems[1].Text = "Previous alerts active"
                        }
                    }
                }
                else {
                    # Error occurred
                    $job.ListItem.BackColor = [System.Drawing.Color]::Yellow
                    $job.ListItem.ForeColor = [System.Drawing.Color]::Black
                    $job.ListItem.SubItems[1].Text = "Error: $($result.Error)"
                }
            }
            catch {
                if ($job.ListItem.ListView) {
                    $job.ListItem.BackColor = [System.Drawing.Color]::Yellow
                    $job.ListItem.ForeColor = [System.Drawing.Color]::Black
                    $job.ListItem.SubItems[1].Text = "Error: $($_.Exception.Message)"
                }
            }

            $completedJobs += $computerName
        }
    }

    # Clean up completed jobs
    foreach ($computerName in $completedJobs) {
        if ($script:ActiveJobs.ContainsKey($computerName)) {
            $script:ActiveJobs[$computerName].PowerShell.Dispose()
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
        [System.GC]::Collect()
    }
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

# Get domain controllers
if (-not (Get-DomainControllerList)) {
    Clear-Credentials
    exit
}

# Initialize runspace pool
Initialize-RunspacePool

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
    $lblStatus.Text = "Last check: $(Get-Date -Format 'HH:mm:ss')"

    # Clear old alerts
    Clear-OldAlerts

    # Start monitoring jobs for each DC
    for ($i = 0; $i -lt $listView.Items.Count; $i++) {
        $item = $listView.Items[$i]
        $dc = $item.Text
        Start-SecurityEventMonitoring -ComputerName $dc -ListItem $item -DetailsBox $txtDetails
    }
})

# Create timer for checking job results
$resultTimer = New-Object System.Windows.Forms.Timer
$resultTimer.Interval = 1000 # 1 second
$resultTimer.Add_Tick({
    Update-MonitoringResults
})

# Start monitoring
$script:MonitoringActive = $true

# Initial check
$lblStatus.Text = "Initial check: $(Get-Date -Format 'HH:mm:ss')"
for ($i = 0; $i -lt $listView.Items.Count; $i++) {
    $item = $listView.Items[$i]
    $dc = $item.Text
    Start-SecurityEventMonitoring -ComputerName $dc -ListItem $item -DetailsBox $txtDetails
}

$timer.Start()
$resultTimer.Start()

# Show form
$form.Add_FormClosing({
    $timer.Stop()
    $resultTimer.Stop()
    $script:MonitoringActive = $false

    # Stop all running jobs
    foreach ($computerName in @($script:ActiveJobs.Keys)) {
        $script:ActiveJobs[$computerName].PowerShell.Stop()
        $script:ActiveJobs[$computerName].PowerShell.Dispose()
    }
    $script:ActiveJobs.Clear()

    Close-RunspacePool
    Clear-Credentials
})

[void]$form.ShowDialog()

# Final cleanup
Close-RunspacePool
Clear-Credentials

#endregion
