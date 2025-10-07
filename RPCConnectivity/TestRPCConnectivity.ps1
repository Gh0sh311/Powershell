#Requires -Version 5.1
<#
.SYNOPSIS
    Comprehensive RPC connectivity diagnostic tool with GUI
.DESCRIPTION
    Tests all common causes of "The RPC server is unavailable" errors
.NOTES
    Author: Trond Hoiberg
    Version: 1.0
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'RPC Connectivity Diagnostic Tool'
$form.Size = New-Object System.Drawing.Size(800, 700)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

# Server name label and textbox
$labelServer = New-Object System.Windows.Forms.Label
$labelServer.Location = New-Object System.Drawing.Point(10, 20)
$labelServer.Size = New-Object System.Drawing.Size(120, 20)
$labelServer.Text = 'Target Server:'
$form.Controls.Add($labelServer)

$textboxServer = New-Object System.Windows.Forms.TextBox
$textboxServer.Location = New-Object System.Drawing.Point(140, 18)
$textboxServer.Size = New-Object System.Drawing.Size(250, 20)
$form.Controls.Add($textboxServer)

# IP Version label
$labelIPVersion = New-Object System.Windows.Forms.Label
$labelIPVersion.Location = New-Object System.Drawing.Point(400, 20)
$labelIPVersion.Size = New-Object System.Drawing.Size(70, 20)
$labelIPVersion.Text = 'IP Version:'
$form.Controls.Add($labelIPVersion)

# IP Version radio buttons - GroupBox
$groupBoxIPVersion = New-Object System.Windows.Forms.GroupBox
$groupBoxIPVersion.Location = New-Object System.Drawing.Point(470, 8)
$groupBoxIPVersion.Size = New-Object System.Drawing.Size(300, 35)
$groupBoxIPVersion.Text = ''
$form.Controls.Add($groupBoxIPVersion)

# IPv4 radio button
$radioIPv4 = New-Object System.Windows.Forms.RadioButton
$radioIPv4.Location = New-Object System.Drawing.Point(5, 12)
$radioIPv4.Size = New-Object System.Drawing.Size(60, 20)
$radioIPv4.Text = 'IPv4'
$radioIPv4.Checked = $false
$groupBoxIPVersion.Controls.Add($radioIPv4)

# IPv6 radio button
$radioIPv6 = New-Object System.Windows.Forms.RadioButton
$radioIPv6.Location = New-Object System.Drawing.Point(70, 12)
$radioIPv6.Size = New-Object System.Drawing.Size(60, 20)
$radioIPv6.Text = 'IPv6'
$radioIPv6.Checked = $false
$groupBoxIPVersion.Controls.Add($radioIPv6)

# Both radio button
$radioBoth = New-Object System.Windows.Forms.RadioButton
$radioBoth.Location = New-Object System.Drawing.Point(135, 12)
$radioBoth.Size = New-Object System.Drawing.Size(60, 20)
$radioBoth.Text = 'Both'
$radioBoth.Checked = $true
$groupBoxIPVersion.Controls.Add($radioBoth)

# Test button
$buttonTest = New-Object System.Windows.Forms.Button
$buttonTest.Location = New-Object System.Drawing.Point(10, 50)
$buttonTest.Size = New-Object System.Drawing.Size(100, 25)
$buttonTest.Text = 'Run Diagnostics'
$form.Controls.Add($buttonTest)

# Clear button
$buttonClear = New-Object System.Windows.Forms.Button
$buttonClear.Location = New-Object System.Drawing.Point(120, 50)
$buttonClear.Size = New-Object System.Drawing.Size(100, 25)
$buttonClear.Text = 'Clear Results'
$form.Controls.Add($buttonClear)

# Export button
$buttonExport = New-Object System.Windows.Forms.Button
$buttonExport.Location = New-Object System.Drawing.Point(230, 50)
$buttonExport.Size = New-Object System.Drawing.Size(100, 25)
$buttonExport.Text = 'Export Report'
$form.Controls.Add($buttonExport)

# Exit button
$buttonExit = New-Object System.Windows.Forms.Button
$buttonExit.Location = New-Object System.Drawing.Point(340, 50)
$buttonExit.Size = New-Object System.Drawing.Size(60, 25)
$buttonExit.Text = 'Exit'
$form.Controls.Add($buttonExit)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 85)
$progressBar.Size = New-Object System.Drawing.Size(760, 20)
$progressBar.Style = 'Continuous'
$form.Controls.Add($progressBar)

# Results textbox
$textboxResults = New-Object System.Windows.Forms.TextBox
$textboxResults.Location = New-Object System.Drawing.Point(10, 115)
$textboxResults.Size = New-Object System.Drawing.Size(760, 525)
$textboxResults.Multiline = $true
$textboxResults.ScrollBars = 'Vertical'
$textboxResults.Font = New-Object System.Drawing.Font("Consolas", 9)
$textboxResults.ReadOnly = $true
$form.Controls.Add($textboxResults)

# Status label
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Location = New-Object System.Drawing.Point(10, 645)
$labelStatus.Size = New-Object System.Drawing.Size(760, 20)
$labelStatus.Text = 'Ready'
$form.Controls.Add($labelStatus)

# Global variable to store results
$script:diagnosticResults = ""

function Write-Result {
    param([string]$Message, [string]$Type = "Info")

    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Type) {
        "Success" { "[+]" }
        "Error"   { "[!]" }
        "Warning" { "[*]" }
        "Info"    { "[i]" }
        default   { "[i]" }
    }

    $output = "$timestamp $prefix $Message"
    $script:diagnosticResults += "$output`r`n"
    $textboxResults.AppendText("$output`r`n")
    $textboxResults.SelectionStart = $textboxResults.Text.Length
    $textboxResults.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Test-RPCConnectivity {
    param(
        [string]$ServerName,
        [string]$IPVersion = "Both"
    )

    $script:diagnosticResults = ""
    $textboxResults.Clear()
    $progressBar.Value = 0
    $labelStatus.Text = "Running diagnostics..."

    Write-Result "========================================" "Info"
    Write-Result "RPC CONNECTIVITY DIAGNOSTIC REPORT" "Info"
    Write-Result "Target Server: $ServerName" "Info"
    Write-Result "IP Version Filter: $IPVersion" "Info"
    Write-Result "Test Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Info"
    Write-Result "Source Computer: $env:COMPUTERNAME" "Info"
    Write-Result "========================================" "Info"
    Write-Result "" "Info"

    $totalTests = 14
    $currentTest = 0

    # Test 1: Basic Network Connectivity (Ping)
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 1: Basic Network Connectivity (ICMP Ping)" "Info"
    try {
        # Resolve hostname to IP addresses first
        $resolvedIPs = @()
        try {
            $dnsLookup = [System.Net.Dns]::GetHostEntry($ServerName)
            if ($IPVersion -eq "IPv4") {
                $resolvedIPs = $dnsLookup.AddressList | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
                Write-Result "  Testing with IPv4 only..." "Info"
            } elseif ($IPVersion -eq "IPv6") {
                $resolvedIPs = $dnsLookup.AddressList | Where-Object { $_.AddressFamily -eq 'InterNetworkV6' }
                Write-Result "  Testing with IPv6 only..." "Info"
            } else {
                $resolvedIPs = $dnsLookup.AddressList
            }
        } catch {
            # If DNS fails, try the server name directly
            Write-Result "  DNS pre-lookup failed, attempting direct ping..." "Info"
        }

        # Ping using the appropriate IP address or hostname
        $targetToPing = if ($resolvedIPs.Count -gt 0) { $resolvedIPs[0].ToString() } else { $ServerName }

        $pingResult = Test-Connection -ComputerName $targetToPing -Count 2 -ErrorAction Stop
        Write-Result "SUCCESS: Server is reachable via ICMP" "Success"
        Write-Result "  Average Response Time: $([math]::Round(($pingResult | Measure-Object -Property ResponseTime -Average).Average, 2)) ms" "Info"
        if ($pingResult[0].IPV4Address) {
            Write-Result "  IPv4 Address: $($pingResult[0].IPV4Address)" "Info"
        }
        if ($pingResult[0].IPV6Address) {
            Write-Result "  IPv6 Address: $($pingResult[0].IPV6Address)" "Info"
        }
    } catch {
        Write-Result "FAILED: Cannot ping server - $($_.Exception.Message)" "Error"
        Write-Result "  Possible causes: Server offline, firewall blocking ICMP, network issue" "Warning"
    }
    Write-Result "" "Info"

    # Test 2: DNS Resolution
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 2: DNS Resolution" "Info"
    try {
        $dnsResult = [System.Net.Dns]::GetHostEntry($ServerName)
        Write-Result "SUCCESS: DNS resolution successful" "Success"
        Write-Result "  Hostname: $($dnsResult.HostName)" "Info"

        # Filter addresses based on IP version selection
        $filteredAddresses = $dnsResult.AddressList
        if ($IPVersion -eq "IPv4") {
            $filteredAddresses = $dnsResult.AddressList | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
            Write-Result "  IPv4 Addresses: $($filteredAddresses -join ', ')" "Info"
        } elseif ($IPVersion -eq "IPv6") {
            $filteredAddresses = $dnsResult.AddressList | Where-Object { $_.AddressFamily -eq 'InterNetworkV6' }
            Write-Result "  IPv6 Addresses: $($filteredAddresses -join ', ')" "Info"
        } else {
            $ipv4 = $dnsResult.AddressList | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
            $ipv6 = $dnsResult.AddressList | Where-Object { $_.AddressFamily -eq 'InterNetworkV6' }
            if ($ipv4) { Write-Result "  IPv4 Addresses: $($ipv4 -join ', ')" "Info" }
            if ($ipv6) { Write-Result "  IPv6 Addresses: $($ipv6 -join ', ')" "Info" }
        }
    } catch {
        Write-Result "FAILED: DNS resolution failed - $($_.Exception.Message)" "Error"
        Write-Result "  Possible causes: Invalid hostname, DNS server issue" "Warning"
    }
    Write-Result "" "Info"

    # Test 3: RPC Endpoint Mapper (Port 135)
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 3: RPC Endpoint Mapper (TCP Port 135)" "Info"
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($ServerName, 135, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)

        if ($wait -and $tcpClient.Connected) {
            Write-Result "SUCCESS: Port 135 is open and accepting connections" "Success"
            $tcpClient.Close()
        } else {
            Write-Result "FAILED: Port 135 is not accessible" "Error"
            Write-Result "  Possible causes: Firewall blocking port 135, RPC service not running" "Warning"
            $tcpClient.Close()
        }
    } catch {
        Write-Result "FAILED: Cannot connect to port 135 - $($_.Exception.Message)" "Error"
    }
    Write-Result "" "Info"

    # Test 4: Dynamic RPC Ports (49152-65535)
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 4: Dynamic RPC Port Range" "Info"
    Write-Result "  Testing sample ports in range 49152-65535..." "Info"
    $samplePorts = @(49152, 49153, 49154, 49155, 49156)
    $openPorts = @()
    foreach ($port in $samplePorts) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($ServerName, $port, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(1000, $false)
            if ($wait -and $tcpClient.Connected) {
                $openPorts += $port
            }
            $tcpClient.Close()
        } catch { }
    }
    if ($openPorts.Count -gt 0) {
        Write-Result "  Found $($openPorts.Count) open ports: $($openPorts -join ', ')" "Info"
    } else {
        Write-Result "WARNING: No dynamic RPC ports found open (may be blocked by firewall)" "Warning"
    }
    Write-Result "" "Info"

    # Test 5: Windows Remote Management (WinRM) - Alternative check
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 5: WinRM Service (TCP Port 5985/5986)" "Info"
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($ServerName, 5985, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)

        if ($wait -and $tcpClient.Connected) {
            Write-Result "SUCCESS: WinRM port 5985 is open" "Success"
            $tcpClient.Close()
        } else {
            Write-Result "INFO: WinRM port 5985 not accessible (not necessarily an issue)" "Info"
            $tcpClient.Close()
        }
    } catch {
        Write-Result "INFO: WinRM not available - $($_.Exception.Message)" "Info"
    }
    Write-Result "" "Info"

    # Test 6: SMB/File Sharing (Port 445)
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 6: SMB/CIFS Service (TCP Port 445)" "Info"
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($ServerName, 445, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)

        if ($wait -and $tcpClient.Connected) {
            Write-Result "SUCCESS: SMB port 445 is open" "Success"
            $tcpClient.Close()
        } else {
            Write-Result "WARNING: SMB port 445 not accessible" "Warning"
            $tcpClient.Close()
        }
    } catch {
        Write-Result "FAILED: Cannot connect to port 445 - $($_.Exception.Message)" "Error"
    }
    Write-Result "" "Info"

    # Test 7: Local RPC Service Status
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 7: Local RPC Service Status" "Info"
    try {
        $rpcService = Get-Service -Name "RpcSs" -ErrorAction Stop
        Write-Result "  RPC Service (RpcSs): $($rpcService.Status)" "Info"
        if ($rpcService.Status -eq "Running") {
            Write-Result "SUCCESS: Local RPC service is running" "Success"
        } else {
            Write-Result "ERROR: Local RPC service is not running!" "Error"
        }

        $rpcLocator = Get-Service -Name "RpcLocator" -ErrorAction SilentlyContinue
        if ($rpcLocator) {
            Write-Result "  RPC Locator: $($rpcLocator.Status)" "Info"
        }
    } catch {
        Write-Result "FAILED: Cannot check local RPC service - $($_.Exception.Message)" "Error"
    }
    Write-Result "" "Info"

    # Test 8: Remote Registry Access
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 8: Remote Registry Access" "Info"
    try {
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ServerName)
        $regKey = $reg.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion")
        if ($regKey) {
            $productName = $regKey.GetValue("ProductName")
            Write-Result "SUCCESS: Remote registry accessible" "Success"
            Write-Result "  Remote OS: $productName" "Info"
            $regKey.Close()
        }
        $reg.Close()
    } catch {
        Write-Result "FAILED: Cannot access remote registry - $($_.Exception.Message)" "Error"
        Write-Result "  Possible causes: RemoteRegistry service disabled, firewall, permissions" "Warning"
    }
    Write-Result "" "Info"

    # Test 9: WMI Connectivity
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 9: WMI (Windows Management Instrumentation)" "Info"
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ServerName -ErrorAction Stop
        Write-Result "SUCCESS: WMI query successful" "Success"
        Write-Result "  OS: $($os.Caption)" "Info"
        Write-Result "  Last Boot: $($os.ConvertToDateTime($os.LastBootUpTime))" "Info"
    } catch {
        Write-Result "FAILED: WMI query failed - $($_.Exception.Message)" "Error"
        Write-Result "  Possible causes: WMI service stopped, DCOM issues, firewall" "Warning"
    }
    Write-Result "" "Info"

    # Test 10: Network Path Access
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 10: Network Path Access (UNC Path)" "Info"
    try {
        $uncPath = "\\$ServerName\C$"
        if (Test-Path $uncPath -ErrorAction Stop) {
            Write-Result "SUCCESS: Can access administrative share $uncPath" "Success"
        } else {
            Write-Result "WARNING: Cannot access $uncPath" "Warning"
        }
    } catch {
        Write-Result "FAILED: Cannot access network path - $($_.Exception.Message)" "Error"
        Write-Result "  Possible causes: Permissions, firewall, File and Printer Sharing disabled" "Warning"
    }
    Write-Result "" "Info"

    # Test 11: Firewall Profile Check
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 11: Local Windows Firewall Status" "Info"
    try {
        $firewallProfiles = Get-NetFirewallProfile -ErrorAction Stop
        foreach ($profile in $firewallProfiles) {
            Write-Result "  $($profile.Name) Profile: Enabled=$($profile.Enabled)" "Info"
        }

        # Check for RPC-related firewall rules
        $rpcRules = Get-NetFirewallRule -DisplayName "*RPC*" -Enabled True -ErrorAction SilentlyContinue | Select-Object -First 5
        if ($rpcRules) {
            Write-Result "  Found active RPC-related firewall rules" "Info"
        }
    } catch {
        Write-Result "INFO: Cannot query firewall status - $($_.Exception.Message)" "Info"
    }
    Write-Result "" "Info"

    # Test 12: Time Synchronization
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 12: Time Synchronization" "Info"
    try {
        $w32tm = w32tm /stripchart /computer:$ServerName /samples:1 /dataonly 2>&1
        if ($w32tm -match "(\d+\.\d+)s") {
            $offset = [math]::Abs([double]$matches[1])
            if ($offset -lt 5) {
                Write-Result "SUCCESS: Time is synchronized (offset: $offset seconds)" "Success"
            } else {
                Write-Result "WARNING: Time offset is $offset seconds (should be < 5 minutes)" "Warning"
                Write-Result "  Large time differences can cause authentication issues" "Warning"
            }
        } else {
            Write-Result "INFO: Cannot determine time offset" "Info"
        }
    } catch {
        Write-Result "INFO: Time sync check unavailable - $($_.Exception.Message)" "Info"
    }
    Write-Result "" "Info"

    # Test 13: Domain/Network Type
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 13: Network and Domain Information" "Info"
    try {
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        Write-Result "  Local Computer Domain: $($computerSystem.Domain)" "Info"
        Write-Result "  Domain Role: $($computerSystem.DomainRole)" "Info"

        if ($computerSystem.PartOfDomain) {
            Write-Result "  This computer is part of a domain" "Info"
        } else {
            Write-Result "  This computer is in a workgroup" "Info"
        }
    } catch {
        Write-Result "INFO: Cannot retrieve domain information" "Info"
    }
    Write-Result "" "Info"

    # Test 14: Traceroute/Network Path
    $currentTest++
    $progressBar.Value = [int](($currentTest / $totalTests) * 100)
    Write-Result "TEST 14: Network Path Analysis" "Info"

    # Use a job with timeout to prevent hanging on IPv6 or slow networks
    $traceJob = Start-Job -ScriptBlock {
        param($Server, $IPVer)
        try {
            # Resolve hostname to get the appropriate IP address
            $targetIP = $null
            try {
                $dnsLookup = [System.Net.Dns]::GetHostEntry($Server)
                if ($IPVer -eq "IPv4") {
                    $ipv4Addresses = $dnsLookup.AddressList | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
                    if ($ipv4Addresses) { $targetIP = $ipv4Addresses[0].ToString() }
                } elseif ($IPVer -eq "IPv6") {
                    # Skip traceroute for IPv6 as it often hangs
                    return $null
                } else {
                    # For "Both", prefer IPv4 to avoid IPv6 hanging issues
                    $ipv4Addresses = $dnsLookup.AddressList | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
                    if ($ipv4Addresses) {
                        $targetIP = $ipv4Addresses[0].ToString()
                    } else {
                        $targetIP = $Server
                    }
                }
            } catch {
                $targetIP = $Server
            }

            if ($targetIP) {
                Test-NetConnection -ComputerName $targetIP -TraceRoute -ErrorAction Stop -WarningAction SilentlyContinue | Select-Object -ExpandProperty TraceRoute
            } else {
                return $null
            }
        } catch {
            return $null
        }
    } -ArgumentList $ServerName, $IPVersion

    # Wait max 15 seconds for traceroute
    $traceComplete = Wait-Job -Job $traceJob -Timeout 15

    if ($traceComplete) {
        $traceResult = Receive-Job -Job $traceJob
        if ($traceResult -and $traceResult.Count -gt 0) {
            Write-Result "  Network path ($($traceResult.Count) hops):" "Info"
            $traceResult | ForEach-Object { Write-Result "    -> $_" "Info" }
        } else {
            Write-Result "  INFO: Traceroute not available or skipped" "Info"
        }
    } else {
        Write-Result "  WARNING: Traceroute timed out after 15 seconds (skipped)" "Warning"
    }

    Remove-Job -Job $traceJob -Force -ErrorAction SilentlyContinue
    Write-Result "" "Info"

    # Summary and Recommendations
    Write-Result "========================================" "Info"
    Write-Result "DIAGNOSTIC SUMMARY & RECOMMENDATIONS" "Info"
    Write-Result "========================================" "Info"

    $issues = @()
    if ($script:diagnosticResults -match "FAILED.*ping") { $issues += "Network connectivity" }
    if ($script:diagnosticResults -match "FAILED.*DNS") { $issues += "DNS resolution" }
    if ($script:diagnosticResults -match "FAILED.*135") { $issues += "RPC Endpoint Mapper (port 135)" }
    if ($script:diagnosticResults -match "WARNING.*Dynamic RPC") { $issues += "Dynamic RPC ports blocked" }
    if ($script:diagnosticResults -match "FAILED.*WMI") { $issues += "WMI connectivity" }
    if ($script:diagnosticResults -match "WARNING.*Time offset") { $issues += "Time synchronization" }

    if ($issues.Count -eq 0) {
        Write-Result "No critical issues detected. If RPC errors persist, check:" "Success"
        Write-Result "  1. Application-specific RPC services on target server" "Info"
        Write-Result "  2. User permissions and access rights" "Info"
        Write-Result "  3. Application event logs on both source and target" "Info"
    } else {
        Write-Result "ISSUES DETECTED:" "Error"
        foreach ($issue in $issues) {
            Write-Result "  - $issue" "Error"
        }
        Write-Result "" "Info"
        Write-Result "RECOMMENDED ACTIONS:" "Warning"
        if ($issues -contains "Network connectivity") {
            Write-Result "  1. Verify server is powered on and network cable connected" "Warning"
            Write-Result "  2. Check network connectivity between source and target" "Warning"
        }
        if ($issues -contains "RPC Endpoint Mapper (port 135)") {
            Write-Result "  3. Enable 'File and Printer Sharing' in Windows Firewall" "Warning"
            Write-Result "  4. Add firewall exception for TCP port 135" "Warning"
            Write-Result "  5. Verify RPC service is running on target: services.msc -> RPC" "Warning"
        }
        if ($issues -contains "Dynamic RPC ports blocked") {
            Write-Result "  6. Open dynamic RPC port range (49152-65535) in firewall" "Warning"
            Write-Result "     OR restrict to specific range using: netsh int ipv4 set dynamic tcp start=49152 num=16384" "Warning"
        }
        if ($issues -contains "WMI connectivity") {
            Write-Result "  7. Verify 'Windows Management Instrumentation' service is running" "Warning"
            Write-Result "  8. Check DCOM permissions: dcomcnfg -> Component Services" "Warning"
        }
    }

    Write-Result "" "Info"
    Write-Result "========================================" "Info"
    Write-Result "Diagnostic complete at $(Get-Date -Format 'HH:mm:ss')" "Info"
    Write-Result "========================================" "Info"

    $progressBar.Value = 100
    $labelStatus.Text = "Diagnostics complete"
}

# Test button click event
$buttonTest.Add_Click({
    if ([string]::IsNullOrWhiteSpace($textboxServer.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a server name or IP address.", "Input Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    # Determine which IP version is selected
    $selectedIPVersion = "Both"
    if ($radioIPv4.Checked) {
        $selectedIPVersion = "IPv4"
    } elseif ($radioIPv6.Checked) {
        $selectedIPVersion = "IPv6"
    }

    $buttonTest.Enabled = $false
    $buttonClear.Enabled = $false
    $buttonExport.Enabled = $false

    try {
        Test-RPCConnectivity -ServerName $textboxServer.Text.Trim() -IPVersion $selectedIPVersion
    } finally {
        $buttonTest.Enabled = $true
        $buttonClear.Enabled = $true
        $buttonExport.Enabled = $true
    }
})

# Clear button click event
$buttonClear.Add_Click({
    $textboxResults.Clear()
    $progressBar.Value = 0
    $labelStatus.Text = "Ready"
    $script:diagnosticResults = ""
})

# Export button click event
$buttonExport.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:diagnosticResults)) {
        [System.Windows.Forms.MessageBox]::Show("No diagnostic results to export. Please run diagnostics first.", "No Data", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $saveDialog.DefaultExt = "txt"
    $saveDialog.FileName = "RPC_Diagnostic_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

    if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $script:diagnosticResults | Out-File -FilePath $saveDialog.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Report exported successfully to:`n$($saveDialog.FileName)", "Export Successful", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to export report: $($_.Exception.Message)", "Export Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

# Allow Enter key to trigger test
$textboxServer.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $buttonTest.PerformClick()
    }
})

# Exit button click event
$buttonExit.Add_Click({
    $form.Close()
})

# Show the form
[void]$form.ShowDialog()
