param(
    [switch]$noLog,
    [switch]$focus
)

# Copy script files to ModOrganizer folder
$sourceDir = Get-Location
$targetDir = "C:\Users\Martin\AppData\Local\ModOrganizer\Morrowind\mods\voshondsQuickSelect\scripts\QuickSelect"

# Check if target directory exists, create if not
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force
    Write-Host "Created target directory: $targetDir"
}

# Copy all files from current directory to target
Copy-Item -Path "$sourceDir\scripts\voshondsQuickSelect\*" -Destination $targetDir -Recurse -Force
Write-Host "Copied files from $sourceDir to $targetDir"

# Find the main OpenMW process - get all processes and filter for the game window
$openmwProcesses = Get-Process -Name "openmw" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" }

if ($focus -and $openmwProcesses) {
    # Bring OpenMW window to foreground
    Write-Host "Focusing OpenMW window..."
    
    # Setup the Win32 API function
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
    }
"@

    # Focus the main window (first window with a non-empty title if multiple found)
    $mainProcess = $openmwProcesses | Select-Object -First 1
    Write-Host "Found OpenMW window with title: $($mainProcess.MainWindowTitle)"
    
    try {
        [Win32]::SetForegroundWindow($mainProcess.MainWindowHandle)
        Write-Host "Window focused successfully."
    }
    catch {
        Write-Host "Failed to focus window: $_"
    }
}
elseif (-not $focus) {
    # Kill OpenMW process if running
    if ($openmwProcesses) {
        Write-Host "Terminating OpenMW processes..."
        Stop-Process -Name "openmw" -Force
        Start-Sleep -Seconds 1
    }

    # Start OpenMW
    $openmwExe = "D:\Games\Morrowind\OpenMW current\openmw.exe"
    $openmwArgs = "--script-verbose --skip-menu --load `"C:\Users\Martin\Documents\My Games\OpenMW\saves\Vorythn_Indarys\Quicksave.omwsave`""

    if (Test-Path $openmwExe) {
        Write-Host "Starting OpenMW..."
        if ($noLog) {
            Start-Process $openmwExe -ArgumentList $openmwArgs
        }
        else {
            Start-Process $openmwExe -ArgumentList $openmwArgs
        }
    }
    else {
        Write-Host "Error: OpenMW executable not found at $openmwExe"
    }
}