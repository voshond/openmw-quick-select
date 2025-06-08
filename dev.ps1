# Voshond's Quick Select - Development Script Proxy (PowerShell)
# This script acts as a proxy to call development scripts from the dev-scripts directory

param(
    [Parameter(Position=0)]
    [string]$Command,
    
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

$ScriptDir = $PSScriptRoot
$DevScriptsDir = Join-Path $ScriptDir "dev-scripts"

# Available commands
$AvailableCommands = @("debug", "deploy", "package")

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\dev.ps1 <command> [options]"
    Write-Host ""
    Write-Host "Available commands:"
    Write-Host "  debug     - Debug the mod (copy files and restart OpenMW)"
    Write-Host "  deploy    - Deploy a new version (create tag and release)"
    Write-Host "  package   - Package the mod for distribution"
    Write-Host ""
    Write-Host "Options are passed through to the respective scripts."
    Write-Host "Use '.\dev.ps1 <command> -help' to see command-specific options."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\dev.ps1 debug -focus"
    Write-Host "  .\dev.ps1 deploy -v 1.2.3 -m 'Bug fixes'"
    Write-Host "  .\dev.ps1 package -v 1.2.3"
}

# Check if command is provided
if (-not $Command) {
    Write-Host "Error: No command specified" -ForegroundColor Red
    Write-Host ""
    Show-Usage
    exit 1
}

# Check if command is valid
if ($Command -notin $AvailableCommands) {
    Write-Host "Error: Unknown command '$Command'" -ForegroundColor Red
    Write-Host ""
    Show-Usage
    exit 1
}

# Construct the script path
$ScriptPath = Join-Path $DevScriptsDir "$Command.ps1"

# Check if script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Host "Error: Script not found at $ScriptPath" -ForegroundColor Red
    exit 1
}

# Execute the script with remaining arguments
Write-Host "Executing: $Command $($RemainingArgs -join ' ')"
Write-Host "----------------------------------------"

if ($RemainingArgs) {
    & $ScriptPath @RemainingArgs
} else {
    & $ScriptPath
} 