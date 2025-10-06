### Robust Event Log Search GUI Script
# ...existing code...
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Check ActiveDirectory module
$adModuleAvailable = $false
try {
    $adModule = Get-Module -ListAvailable -Name ActiveDirectory -ErrorAction Stop
    if ($adModule) {
        $adModuleAvailable = $true
        Import-Module ActiveDirectory -ErrorAction Stop
    }
} catch {
    # ActiveDirectory module not found
}

# Detect AD Domain and retrieve server list
$servers = @()
$currentDomain = $null
$domainError = $null
if ($adModuleAvailable) {
    try {
        $currentDomain = (Get-ADDomain).DNSRoot
        $servers = Get-ADComputer -Filter 'OperatingSystem -like "*Server*"' -Properties Name | Select-Object -ExpandProperty Name | Sort-Object
        $servers = @("localhost") + $servers
    } catch {
        $domainError = "Unable to detect AD domain or retrieve servers: $_"
    }
}

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Event Log Search"
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(500, 400)
$form.AutoScroll = $true

# Server selection
$labelServer = New-Object System.Windows.Forms.Label
$labelServer.Text = "Server Name:"
$labelServer.Location = New-Object System.Drawing.Point(10, 20)
$labelServer.AutoSize = $true
$form.Controls.Add($labelServer)

if ($servers.Count -gt 0) {
    $comboServer = New-Object System.Windows.Forms.ComboBox
    $comboServer.Location = New-Object System.Drawing.Point(120, 20)
    $comboServer.Size = New-Object System.Drawing.Size(350, 20)
    $comboServer.DropDownStyle = "DropDownList"
    $comboServer.Items.AddRange($servers)
    $comboServer.SelectedIndex = 0
    $form.Controls.Add($comboServer)
    $serverControl = $comboServer
} else {
    $textServer = New-Object System.Windows.Forms.TextBox
    $textServer.Location = New-Object System.Drawing.Point(120, 20)
    $textServer.Size = New-Object System.Drawing.Size(350, 20)
    $textServer.Text = "localhost"
    $form.Controls.Add($textServer)
    $serverControl = $textServer
}

# Domain info/error
$nextYPosition = 45
if ($currentDomain) {
    $labelDomain = New-Object System.Windows.Forms.Label
    $labelDomain.Text = "Detected Domain: $currentDomain"
    $labelDomain.Location = New-Object System.Drawing.Point(10, $nextYPosition)
    $labelDomain.AutoSize = $true
    $labelDomain.ForeColor = [System.Drawing.Color]::Green
    $form.Controls.Add($labelDomain)
    $nextYPosition += 20
} elseif ($domainError) {
    $labelDomainError = New-Object System.Windows.Forms.Label
    $labelDomainError.Text = $domainError
    $labelDomainError.Location = New-Object System.Drawing.Point(10, $nextYPosition)
    $labelDomainError.AutoSize = $true
    $labelDomainError.ForeColor = [System.Drawing.Color]::Red
    $labelDomainError.MaximumSize = New-Object System.Drawing.Size(410, 0)
    $form.Controls.Add($labelDomainError)
    $nextYPosition += 40
}

# ActiveDirectory module install option
if (-not $adModuleAvailable) {
    $labelModuleError = New-Object System.Windows.Forms.Label
    $labelModuleError.Text = "ActiveDirectory module not installed."
    $labelModuleError.Location = New-Object System.Drawing.Point(10, $nextYPosition)
    $labelModuleError.AutoSize = $true
    $labelModuleError.ForeColor = [System.Drawing.Color]::Red
    $form.Controls.Add($labelModuleError)
    $nextYPosition += 20

    $buttonInstallModule = New-Object System.Windows.Forms.Button
    $buttonInstallModule.Text = "Install ActiveDirectory Module"
    $buttonInstallModule.Location = New-Object System.Drawing.Point(10, $nextYPosition)
    $buttonInstallModule.Size = New-Object System.Drawing.Size(200, 25)
    $form.Controls.Add($buttonInstallModule)
    $nextYPosition += 30

    $buttonInstallModule.Add_Click({
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (-not $isAdmin) {
                $textResults.Text = "Please run PowerShell as Administrator to install the ActiveDirectory module."
                return
            }
            $textResults.Text = "Installing ActiveDirectory module... Please wait."
            Install-WindowsFeature -Name RSAT-AD-PowerShell -IncludeManagementTools -ErrorAction Stop
            $textResults.Text = "ActiveDirectory module installed successfully. Please restart the script."
            $buttonInstallModule.Enabled = $false
        } catch {
            $textResults.Text = "Failed to install ActiveDirectory module: $_"
        }
    })
}

# Username/Password
$labelUsername = New-Object System.Windows.Forms.Label
$labelUsername.Text = "Username (optional for domain auth):"
$labelUsername.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$labelUsername.AutoSize = $true
$form.Controls.Add($labelUsername)

$textUsername = New-Object System.Windows.Forms.TextBox
$textUsername.Location = New-Object System.Drawing.Point(220, $nextYPosition)
$textUsername.Size = New-Object System.Drawing.Size(250, 20)
$form.Controls.Add($textUsername)
$nextYPosition += 30

$labelPassword = New-Object System.Windows.Forms.Label
$labelPassword.Text = "Password:"
$labelPassword.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$labelPassword.AutoSize = $true
$form.Controls.Add($labelPassword)

$textPassword = New-Object System.Windows.Forms.MaskedTextBox
$textPassword.Location = New-Object System.Drawing.Point(120, $nextYPosition)
$textPassword.Size = New-Object System.Drawing.Size(350, 20)
$textPassword.PasswordChar = '*'
$form.Controls.Add($textPassword)
$nextYPosition += 40

# Event Log selection
$labelLog = New-Object System.Windows.Forms.Label
$labelLog.Text = "Event Log:"
$labelLog.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$labelLog.AutoSize = $true
$form.Controls.Add($labelLog)

$comboLog = New-Object System.Windows.Forms.ComboBox
$comboLog.Location = New-Object System.Drawing.Point(120, $nextYPosition)
$comboLog.Size = New-Object System.Drawing.Size(350, 20)
$comboLog.DropDownStyle = "DropDownList"
$comboLog.Items.AddRange(@("Application", "System", "Security", "ForwardedEvents"))
$comboLog.SelectedIndex = 0
$form.Controls.Add($comboLog)
$nextYPosition += 35

# Event IDs
$labelIDs = New-Object System.Windows.Forms.Label
$labelIDs.Text = "Event IDs (comma-separated):"
$labelIDs.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$labelIDs.AutoSize = $true
$form.Controls.Add($labelIDs)

$textIDs = New-Object System.Windows.Forms.TextBox
$textIDs.Location = New-Object System.Drawing.Point(200, $nextYPosition)
$textIDs.Size = New-Object System.Drawing.Size(270, 20)
$textIDs.Text = "1"
$form.Controls.Add($textIDs)
$nextYPosition += 35

# MaxEvents
$labelMaxEvents = New-Object System.Windows.Forms.Label
$labelMaxEvents.Text = "Max Events (default 100):"
$labelMaxEvents.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$labelMaxEvents.AutoSize = $true
$form.Controls.Add($labelMaxEvents)

$textMaxEvents = New-Object System.Windows.Forms.TextBox
$textMaxEvents.Location = New-Object System.Drawing.Point(200, $nextYPosition)
$textMaxEvents.Size = New-Object System.Drawing.Size(80, 20)
$textMaxEvents.Text = "100"
$form.Controls.Add($textMaxEvents)
$nextYPosition += 35

# Start/End Date
$labelStartDate = New-Object System.Windows.Forms.Label
$labelStartDate.Text = "Start Date/Time:"
$labelStartDate.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$labelStartDate.AutoSize = $true
$form.Controls.Add($labelStartDate)

$dateTimeStartDate = New-Object System.Windows.Forms.DateTimePicker
$dateTimeStartDate.Location = New-Object System.Drawing.Point(120, $nextYPosition)
$dateTimeStartDate.Size = New-Object System.Drawing.Size(150, 20)
$dateTimeStartDate.Format = "Custom"
$dateTimeStartDate.CustomFormat = "yyyy-MM-dd HH:mm"
$dateTimeStartDate.ShowUpDown = $false
$dateTimeStartDate.Value = (Get-Date).AddDays(-1)
$form.Controls.Add($dateTimeStartDate)
$nextYPosition += 30

$labelEndDate = New-Object System.Windows.Forms.Label
$labelEndDate.Text = "End Date/Time:"
$labelEndDate.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$labelEndDate.AutoSize = $true
$form.Controls.Add($labelEndDate)

$dateTimeEndDate = New-Object System.Windows.Forms.DateTimePicker
$dateTimeEndDate.Location = New-Object System.Drawing.Point(120, $nextYPosition)
$dateTimeEndDate.Size = New-Object System.Drawing.Size(150, 20)
$dateTimeEndDate.Format = "Custom"
$dateTimeEndDate.CustomFormat = "yyyy-MM-dd HH:mm"
$dateTimeEndDate.ShowUpDown = $false
$dateTimeEndDate.Value = Get-Date
$form.Controls.Add($dateTimeEndDate)
$nextYPosition += 35

# Search Button
$buttonSearch = New-Object System.Windows.Forms.Button
$buttonSearch.Text = "Search"
$buttonSearch.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$buttonSearch.Size = New-Object System.Drawing.Size(100, 25)
$form.Controls.Add($buttonSearch)

# Cancel Button
$buttonCancel = New-Object System.Windows.Forms.Button
$buttonCancel.Text = "Cancel"
$buttonCancel.Location = New-Object System.Drawing.Point(120, $nextYPosition)
$buttonCancel.Size = New-Object System.Drawing.Size(100, 25)
$buttonCancel.Enabled = $false
$form.Controls.Add($buttonCancel)

# Export to CSV
$buttonExportCsv = New-Object System.Windows.Forms.Button
$buttonExportCsv.Text = "Export to CSV"
$buttonExportCsv.Location = New-Object System.Drawing.Point(230, $nextYPosition)
$buttonExportCsv.Size = New-Object System.Drawing.Size(120, 25)
$buttonExportCsv.Enabled = $false
$form.Controls.Add($buttonExportCsv)
$nextYPosition += 35

# ProgressBar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$progressBar.Size = New-Object System.Drawing.Size(470, 20)
$progressBar.Style = "Marquee"
$progressBar.MarqueeAnimationSpeed = 0
$form.Controls.Add($progressBar)
$nextYPosition += 25

# Results DataGridView
$dataGridResults = New-Object System.Windows.Forms.DataGridView
$dataGridResults.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$dataGridResults.Size = New-Object System.Drawing.Size(470, 200)
$dataGridResults.ReadOnly = $true
$dataGridResults.AllowUserToAddRows = $false
$dataGridResults.AllowUserToDeleteRows = $false
$dataGridResults.SelectionMode = "FullRowSelect"
$dataGridResults.AutoSizeColumnsMode = "Fill"
$dataGridResults.ColumnHeadersHeightSizeMode = "AutoSize"
$form.Controls.Add($dataGridResults)
$nextYPosition += 210

# GridView for results
$buttonShowGrid = New-Object System.Windows.Forms.Button
$buttonShowGrid.Text = "Show in GridView"
$buttonShowGrid.Location = New-Object System.Drawing.Point(10, $nextYPosition)
$buttonShowGrid.Size = New-Object System.Drawing.Size(120, 25)
$buttonShowGrid.Enabled = $false
$form.Controls.Add($buttonShowGrid)

# Clear Results button
$buttonClear = New-Object System.Windows.Forms.Button
$buttonClear.Text = "Clear Results"
$buttonClear.Location = New-Object System.Drawing.Point(140, $nextYPosition)
$buttonClear.Size = New-Object System.Drawing.Size(120, 25)
$buttonClear.Enabled = $false
$form.Controls.Add($buttonClear)

# Store last results and background job
$script:lastResults = $null
$script:searchJob = $null
$script:jobTimer = $null

# Create tooltip provider
$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.AutoPopDelay = 5000
$tooltip.InitialDelay = 500
$tooltip.ReshowDelay = 100

# Set tooltips for controls
if ($serverControl -is [System.Windows.Forms.ComboBox]) {
    $tooltip.SetToolTip($serverControl, "Select a server from the detected domain servers")
} else {
    $tooltip.SetToolTip($serverControl, "Enter the server name or hostname (e.g., localhost, SERVER01)")
}
$tooltip.SetToolTip($textUsername, "Optional: Enter domain username for remote authentication (e.g., DOMAIN\username)")
$tooltip.SetToolTip($textPassword, "Optional: Enter password for authentication")
$tooltip.SetToolTip($comboLog, "Select the event log to search (Application, System, Security, or ForwardedEvents)")
$tooltip.SetToolTip($textIDs, "Enter one or more Event IDs separated by commas (e.g., 1, 2, 3)")
$tooltip.SetToolTip($textMaxEvents, "Maximum number of events to retrieve (default: 100)")
$tooltip.SetToolTip($dateTimeStartDate, "Start date/time for the search range")
$tooltip.SetToolTip($dateTimeEndDate, "End date/time for the search range")
$tooltip.SetToolTip($buttonSearch, "Start searching for events with the specified criteria")
$tooltip.SetToolTip($buttonCancel, "Cancel the currently running search")
$tooltip.SetToolTip($buttonExportCsv, "Export search results to a CSV file")
$tooltip.SetToolTip($buttonShowGrid, "Display search results in a separate grid view window")
$tooltip.SetToolTip($buttonClear, "Clear all search results from the grid")

# Search Button Event
$buttonSearch.Add_Click({
    $server = if ($serverControl -is [System.Windows.Forms.ComboBox]) { $serverControl.SelectedItem.ToString() } else { $serverControl.Text.Trim() }
    $username = $textUsername.Text.Trim()
    $password = $textPassword.Text
    $log = $comboLog.SelectedItem
    $idString = $textIDs.Text.Trim()
    $maxEvents = $textMaxEvents.Text.Trim()
    $startDate = $dateTimeStartDate.Value
    $endDate = $dateTimeEndDate.Value

    # Input validation
    if ([string]::IsNullOrEmpty($server) -or [string]::IsNullOrEmpty($log) -or [string]::IsNullOrEmpty($idString)) {
        [System.Windows.Forms.MessageBox]::Show("Server Name, Event Log, and Event IDs must be provided.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    $ids = $idString -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    if ($ids.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Invalid Event IDs provided.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    $maxEventsInt = 100
    if ($maxEvents -match '^\d+$' -and [int]$maxEvents -gt 0) { $maxEventsInt = [int]$maxEvents }

    if ($endDate -lt $startDate) {
        [System.Windows.Forms.MessageBox]::Show("End Date must be after Start Date.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $credential = $null
    if (-not [string]::IsNullOrEmpty($username) -and -not [string]::IsNullOrEmpty($password)) {
        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)
        # Clear password from memory
        $password = $null
        $textPassword.Text = ""
    }

    $filter = @{ LogName = $log; ID = $ids; StartTime = $startDate; EndTime = $endDate }
    $params = @{ ComputerName = $server; FilterHashtable = $filter; MaxEvents = $maxEventsInt; ErrorAction = "Stop" }
    if ($credential) { $params.Credential = $credential }

    # Start progress animation
    $progressBar.MarqueeAnimationSpeed = 30
    $buttonSearch.Enabled = $false
    $buttonCancel.Enabled = $true
    $dataGridResults.DataSource = $null
    $dataGridResults.Rows.Clear()

    # Clean up previous job if exists
    if ($script:searchJob) {
        Stop-Job -Job $script:searchJob -ErrorAction SilentlyContinue
        Remove-Job -Job $script:searchJob -ErrorAction SilentlyContinue
    }
    if ($script:jobTimer) {
        $script:jobTimer.Stop()
        $script:jobTimer.Dispose()
    }

    # Start background job
    $script:searchJob = Start-Job -ScriptBlock {
        param($params)
        try {
            $events = Get-WinEvent @params
            return @{ Success = $true; Events = $events }
        } catch {
            $errorMsg = $_.Exception.Message
            $errorType = "Unknown"
            if ($errorMsg -match "Access.*denied|permission") {
                $errorType = "AccessDenied"
            } elseif ($errorMsg -match "network|RPC|server.*unavailable") {
                $errorType = "NetworkError"
            } elseif ($errorMsg -match "No events were found") {
                $errorType = "NoEvents"
            }
            return @{ Success = $false; ErrorMessage = $errorMsg; ErrorType = $errorType }
        }
    } -ArgumentList $params

    # Create timer to check job status
    $script:jobTimer = New-Object System.Windows.Forms.Timer
    $script:jobTimer.Interval = 500
    $script:jobTimer.Add_Tick({
        if ($script:searchJob.State -eq 'Completed') {
            $script:jobTimer.Stop()
            $progressBar.MarqueeAnimationSpeed = 0
            $buttonSearch.Enabled = $true
            $buttonCancel.Enabled = $false

            $result = Receive-Job -Job $script:searchJob
            Remove-Job -Job $script:searchJob

            if ($result.Success) {
                $events = $result.Events
                if ($events.Count -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("No events found matching the criteria.", "Search Results", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    $script:lastResults = $null
                    $buttonExportCsv.Enabled = $false
                    $buttonShowGrid.Enabled = $false
                } else {
                    $dataTable = New-Object System.Data.DataTable
                    $dataTable.Columns.Add("Time Created", [DateTime]) | Out-Null
                    $dataTable.Columns.Add("Event ID", [Int]) | Out-Null
                    $dataTable.Columns.Add("Level", [String]) | Out-Null
                    $dataTable.Columns.Add("Message", [String]) | Out-Null

                    foreach ($evt in $events) {
                        $row = $dataTable.NewRow()
                        $row["Time Created"] = $evt.TimeCreated
                        $row["Event ID"] = $evt.Id
                        $row["Level"] = $evt.LevelDisplayName
                        $row["Message"] = $evt.Message
                        $dataTable.Rows.Add($row)
                    }

                    $dataGridResults.DataSource = $dataTable
                    $script:lastResults = $events
                    $buttonExportCsv.Enabled = $true
                    $buttonShowGrid.Enabled = $true
                    $buttonClear.Enabled = $true
                }
            } else {
                $errorPrefix = switch ($result.ErrorType) {
                    "AccessDenied" { "Access Denied: " }
                    "NetworkError" { "Network Error: " }
                    "NoEvents" { "No Events: " }
                    default { "Error: " }
                }
                [System.Windows.Forms.MessageBox]::Show("$errorPrefix$($result.ErrorMessage)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                $script:lastResults = $null
                $buttonExportCsv.Enabled = $false
                $buttonShowGrid.Enabled = $false
            }
        } elseif ($script:searchJob.State -eq 'Failed') {
            $script:jobTimer.Stop()
            $progressBar.MarqueeAnimationSpeed = 0
            $buttonSearch.Enabled = $true
            $buttonCancel.Enabled = $false
            [System.Windows.Forms.MessageBox]::Show("Job failed: $($script:searchJob.ChildJobs[0].JobStateInfo.Reason.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            Remove-Job -Job $script:searchJob
        }
    })
    $script:jobTimer.Start()
})

# Cancel Button Event
$buttonCancel.Add_Click({
    if ($script:searchJob) {
        Stop-Job -Job $script:searchJob -ErrorAction SilentlyContinue
        Remove-Job -Job $script:searchJob -ErrorAction SilentlyContinue
    }
    if ($script:jobTimer) {
        $script:jobTimer.Stop()
        $script:jobTimer.Dispose()
    }
    $progressBar.MarqueeAnimationSpeed = 0
    $buttonSearch.Enabled = $true
    $buttonCancel.Enabled = $false
    [System.Windows.Forms.MessageBox]::Show("Search cancelled by user.", "Cancelled", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Export to CSV Event
$buttonExportCsv.Add_Click({
    if ($script:lastResults) {
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
        $saveDialog.Title = "Export Event Log Results to CSV"
        $saveDialog.FileName = "EventLogResults.csv"
        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                $script:lastResults | Select-Object TimeCreated, Id, LevelDisplayName, Message | Export-Csv -Path $saveDialog.FileName -NoTypeInformation -Encoding UTF8
                [System.Windows.Forms.MessageBox]::Show("Results exported to $($saveDialog.FileName)", "Export Successful", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to export CSV: $_", "Export Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    }
})

# Show in GridView Event
$buttonShowGrid.Add_Click({
    if ($script:lastResults) {
        $script:lastResults | Select-Object TimeCreated, Id, LevelDisplayName, Message | Out-GridView -Title "Event Log Results"
    }
})

# Clear Results Event
$buttonClear.Add_Click({
    $dataGridResults.DataSource = $null
    $dataGridResults.Rows.Clear()
    $script:lastResults = $null
    $buttonExportCsv.Enabled = $false
    $buttonShowGrid.Enabled = $false
    $buttonClear.Enabled = $false
})

# Adjust form size based on content
$form.ClientSize = New-Object System.Drawing.Size(490, $nextYPosition)

# Show the form
try {
    $form.ShowDialog() | Out-Null
} finally {
    $form.Dispose()
}