# health_report.ps1
# Gets system health info and saves to JSON/CSV

$outputFolder = ".\output"
$diskWarningThreshold = 15 # percent free before warning

# create output folder if needed
if (!(Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# get basic system info from WMI
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor

$hostname = $env:COMPUTERNAME
$osName = $os.Caption
$osVersion = $os.Version
$uptimeHours = [Math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 2)
$cpuLoad = $cpu.LoadPercentage

# memory info
$totalMemGB = [Math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
$freeMemGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 2) # this is in KB so divide by 1MB to get GB
$usedMemGB = [Math]::Round($totalMemGB - $freeMemGB, 2)
$memUsedPercent = [Math]::Round(($usedMemGB / $totalMemGB) * 100, 1)

# get disk drives (DriveType 3 = local disk, not CD or network)
$drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
$driveList = @()
$lowDiskFlag = $false

foreach ($drive in $drives) {
    $freePercent = 0
    if ($drive.Size -gt 0) {
        $freePercent = [Math]::Round(($drive.FreeSpace / $drive.Size) * 100, 1)
    }

    $isLow = $freePercent -lt $diskWarningThreshold
    if ($isLow) { $lowDiskFlag = $true }

    $driveList += [PSCustomObject]@{
        Drive = $drive.DeviceID
        SizeGB = [Math]::Round($drive.Size / 1GB, 2)
        FreeGB = [Math]::Round($drive.FreeSpace / 1GB, 2)
        FreePercent = $freePercent
        LowDisk = $isLow
    }
}

# top 5 processes using the most CPU
$topProcs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU, @{
    Name = "MemMB"
    Expression = { [Math]::Round($_.WorkingSet / 1MB, 2) }
}

# check if important services are running
$servicesToCheck = @("wuauserv", "Spooler", "BITS", "EventLog", "Dnscache")
$serviceList = @()
$stoppedCount = 0

foreach ($svcName in $servicesToCheck) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        $isRunning = $svc.Status -eq "Running"
        if (!$isRunning) { $stoppedCount++ }
        $serviceList += [PSCustomObject]@{
            Name = $svc.Name
            Status = $svc.Status.ToString()
            Running = $isRunning
        }
    }
}

# network adapters
$adapters = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
$networkList = @()
foreach ($adapter in $adapters) {
    $networkList += [PSCustomObject]@{
        Name = $adapter.Description
        IP = ($adapter.IPAddress -join ", ")
        MAC = $adapter.MACAddress
    }
}

# put it all together
$report = [PSCustomObject]@{
    Timestamp = (Get-Date).ToString("s")
    Hostname = $hostname
    OS = $osName
    OSVersion = $osVersion
    UptimeHours = $uptimeHours
    CPULoad = $cpuLoad
    MemoryTotalGB = $totalMemGB
    MemoryFreeGB = $freeMemGB
    MemoryUsedPercent = $memUsedPercent
    Drives = $driveList
    LowDiskWarning = $lowDiskFlag
    TopProcesses = $topProcs
    Services = $serviceList
    StoppedServices = $stoppedCount
    Network = $networkList
}

# save to JSON (has all the nested data)
$jsonPath = Join-Path $outputFolder "health_report_$timestamp.json"
$report | ConvertTo-Json -Depth 4 | Out-File -Encoding UTF8 $jsonPath

# save summary to CSV (flat, easy to open in excel)
$csvPath = Join-Path $outputFolder "health_summary_$timestamp.csv"
[PSCustomObject]@{
    Timestamp = $report.Timestamp
    Hostname = $hostname
    OS = $osName
    UptimeHours = $uptimeHours
    CPULoad = $cpuLoad
    MemUsedPercent = $memUsedPercent
    LowDisk = $lowDiskFlag
    StoppedServices = $stoppedCount
} | Export-Csv -Path $csvPath -NoTypeInformation

# print out summary
Write-Host ""
Write-Host "=== System Health Report ==="
Write-Host "Hostname: $hostname"
Write-Host "OS: $osName"
Write-Host "Uptime: $uptimeHours hours"
Write-Host ""
Write-Host "CPU: $cpuLoad%"
Write-Host "Memory: $memUsedPercent% used ($usedMemGB / $totalMemGB GB)"
Write-Host ""
Write-Host "Drives:"
foreach ($d in $driveList) {
    $warn = ""
    if ($d.LowDisk) { $warn = " [LOW]" }
    Write-Host "  $($d.Drive) $($d.FreePercent)% free ($($d.FreeGB) GB)$warn"
}
Write-Host ""
if ($stoppedCount -gt 0) {
    Write-Host "Warning: $stoppedCount service(s) not running"
} else {
    Write-Host "All monitored services running"
}
Write-Host ""
Write-Host "Saved: $jsonPath"
Write-Host "Saved: $csvPath"
