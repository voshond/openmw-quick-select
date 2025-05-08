param(
    [switch]$noLog,
    [switch]$focus,
    [switch]$resetSettings
)

# Clear the console
Clear-Host

# Copy mod files to ModOrganizer folder
$sourceDir = Get-Location
$modDir = "C:\Users\Martin\AppData\Local\ModOrganizer\Morrowind\mods\voshond's Quick Select (OpenMW)"
$scriptsDir = "$modDir\scripts\voshondsQuickSelect"

# Check if target directory exists, create if not
if (-not (Test-Path $modDir)) {
    New-Item -ItemType Directory -Path $modDir -Force
    Write-Host "Created mod directory: $modDir"
}

if (-not (Test-Path $scriptsDir)) {
    New-Item -ItemType Directory -Path $scriptsDir -Force
    Write-Host "Created scripts directory: $scriptsDir"
}

# Clean directories before copying to ensure a clean state
if (Test-Path $scriptsDir) {
    Remove-Item -Path "$scriptsDir\*" -Recurse -Force
    Write-Host "Cleaned scripts directory"
}

# Copy all relevant files
Copy-Item -Path "$sourceDir\scripts\voshondsQuickSelect\*" -Destination $scriptsDir -Recurse -Force
Copy-Item -Path "$sourceDir\icons" -Destination $modDir -Recurse -Force
Copy-Item -Path "$sourceDir\voshondsQuickSelect.omwscripts" -Destination $modDir -Force
Write-Host "Copied all mod files to $modDir"

# Reset settings if requested
if ($resetSettings) {
    $settingsPath = "$env:USERPROFILE\Documents\My Games\OpenMW\settings-default.cfg"
    $jsonPath = "$env:USERPROFILE\Documents\My Games\OpenMW\player-SettingsVoshondsQuickSelect.json"
    
    # Delete settings JSON if it exists to reset mod settings
    if (Test-Path $jsonPath) {
        Remove-Item -Path $jsonPath -Force
        Write-Host "Reset mod settings by removing $jsonPath"
    }
    
    Write-Host "Settings have been reset. The mod will use default settings on next game launch."
}

# Find the main OpenMW process - get all processes and filter for the game window
$openmwProcesses = Get-Process -Name "openmw" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" }

if ($focus) {
    if ($openmwProcesses) {
        # OpenMW is running, bring window to foreground
        Write-Host "Focusing existing OpenMW window..."
        
        # Setup the Win32 API functions with a unique class name
        try {
            # Only add the type if it doesn't already exist
            if (-not ([System.Management.Automation.PSTypeName]'Win32FocusHelper').Type) {
                Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32FocusHelper {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern int SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@
            }
            
            # Focus the main window (first window with a non-empty title if multiple found)
            $mainProcess = $openmwProcesses | Select-Object -First 1
            Write-Host "Found OpenMW window with title: $($mainProcess.MainWindowTitle)"
            
            # Try multiple methods to focus the window
            [Win32FocusHelper]::ShowWindow($mainProcess.MainWindowHandle, 9) # SW_RESTORE = 9
            [Win32FocusHelper]::BringWindowToTop($mainProcess.MainWindowHandle)
            $result = [Win32FocusHelper]::SetForegroundWindow($mainProcess.MainWindowHandle)
            
            if (!$result) {
                Write-Host "Primary focus method failed, trying alternate methods..."
                
                # Try to set window position (HWND_TOPMOST = -1)
                [Win32FocusHelper]::SetWindowPos($mainProcess.MainWindowHandle, [IntPtr](-1), 0, 0, 0, 0, 0x0003) # SWP_NOMOVE | SWP_NOSIZE = 0x0003
                
                # As a last resort, simulate Alt+Tab to switch to the application
                # ALT virtual key = 0x12, TAB virtual key = 0x09
                # KEYEVENTF_KEYDOWN = 0, KEYEVENTF_KEYUP = 2
                [Win32FocusHelper]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero) # ALT down
                [Win32FocusHelper]::keybd_event(0x09, 0, 0, [UIntPtr]::Zero) # TAB down
                [Win32FocusHelper]::keybd_event(0x09, 0, 2, [UIntPtr]::Zero) # TAB up
                [Win32FocusHelper]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero) # ALT up
                
                Start-Sleep -Milliseconds 500
                [Win32FocusHelper]::SetForegroundWindow($mainProcess.MainWindowHandle)
            }
            
            Write-Host "Window focusing attempt completed."
        }
        catch {
            Write-Host "Failed to focus window: $_"
        }
    }
    else {
        # OpenMW is not running, start it
        Write-Host "OpenMW is not running. Starting it now..."
        
        # Start OpenMW
        $openmwExe = "D:\Games\Morrowind\OpenMW current\openmw.exe"
        $openmwArgs = "--script-verbose --skip-menu"
        # $openmwArgs = "--script-verbose --skip-menu --load `"C:\Users\Martin\Documents\My Games\OpenMW\saves\Vorythn_Indarys\testing.omwsave`""


        if (Test-Path $openmwExe) {
            Write-Host "Starting OpenMW..."
            if ($noLog) {
                Start-Process $openmwExe -ArgumentList $openmwArgs
            }
            else {
                Start-Process $openmwExe -ArgumentList $openmwArgs
            }
            
            # Wait a moment for the process to start
            Write-Host "Waiting for OpenMW to start..."
            Start-Sleep -Seconds 5
            
            # Try to focus the newly started window
            $newOpenmwProcess = Get-Process -Name "openmw" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1
            if ($newOpenmwProcess) {
                Write-Host "Focusing newly started OpenMW window..."
                try {
                    [Win32FocusHelper]::SetForegroundWindow($newOpenmwProcess.MainWindowHandle)
                }
                catch {
                    Write-Host "Failed to focus new window: $_"
                }
            }
        }
        else {
            Write-Host "Error: OpenMW executable not found at $openmwExe"
        }
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
    $openmwArgs = "--script-verbose --skip-menu"
    # $openmwArgs = "--script-verbose --skip-menu --load `"C:\Users\Martin\Documents\My Games\OpenMW\saves\Vorythn_Indarys\testing.omwsave`""

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