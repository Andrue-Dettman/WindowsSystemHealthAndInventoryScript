# Windows System Health and Inventory Script

Powershell script that collects system health info (CPU, memory, disk space, running services, etc) and exports it to JSON and CSV files. Also flags issues like low disk space.

## Running it

```powershell
.\health_report.ps1
```

Settings like the output folder and disk warning threshold are at the top of the script if you want to change them.

## What it checks

- System info - hostname, OS, uptime
- CPU and memory usage
- Disk space on each drive, warns if below 15% free
- Top 5 processes by CPU
- Whether some important Windows services are running (Windows Update, Spooler, BITS, etc)
- Network adapters with IP/MAC

## Output

Creates two files in the `output` folder:
- JSON with all the data
- CSV summary (one row, good for tracking over time)

Example:
```
=== System Health Report ===
Hostname: DESKTOP-ABC123
OS: Microsoft Windows 11 Pro
Uptime: 48.25 hours

CPU: 12%
Memory: 67.3% used (10.78 / 16.0 GB)

Drives:
  C: 34.2% free (52.18 GB)
  D: 8.5% free (12.3 GB) [LOW]

All monitored services running

Saved: .\output\health_report_2026-01-28_14-30-00.json
Saved: .\output\health_summary_2026-01-28_14-30-00.csv
```

## Task Scheduler

You can schedule this to run automatically. Set up a task with:
- Program: `powershell.exe`
- Arguments: `-ExecutionPolicy Bypass -File "C:\path\to\health_report.ps1"`

## Why I made this

I wanted to learn more about using PowerShell for system administration stuff. This pulls info from WMI which is how you get hardware/OS info on Windows. Figured low disk space and stopped services are common things that cause problems so it flags those.
