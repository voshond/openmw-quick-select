param(
    [string]$version = "",
    [string]$message = ""
)

Write-Host "========================== Starting Deploy ==========================" -ForegroundColor Magenta
# Function to validate version format
function Test-VersionFormat {
    param (
        [string]$Version
    )
    return $Version -match '^\d+\.\d+\.\d+$'
}

# Check Git is installed
try {
    $gitVersion = git --version
    Write-Host "Found Git: $gitVersion"
}
catch {
    Write-Host "Error: Git is not installed or not in the PATH." -ForegroundColor Red
    exit 1
}

# Check for uncommitted changes
$status = git status --porcelain
if ($status) {
    Write-Host "Error: You have uncommitted changes. Commit or stash them before creating a release." -ForegroundColor Red
    Write-Host "Uncommitted changes:"
    Write-Host $status
    Write-Host "========================== Deploy Failed ==========================" -ForegroundColor Red
    exit 1
}

# Ask for version number if not provided
if (-not $version -or -not (Test-VersionFormat $version)) {
    do {
        $version = Read-Host "Enter version number (format: x.y.z)"
    } while (-not (Test-VersionFormat $version))
}

# Confirm with user
Write-Host "Creating release v$version" -ForegroundColor Cyan

# Check if tag already exists
$tagExists = git tag -l "v$version"
if ($tagExists) {
    Write-Host "Error: Tag v$version already exists." -ForegroundColor Red
    Write-Host "========================== Deploy Failed ==========================" -ForegroundColor Red
    exit 1
}

# Ask for release notes if not provided
if (-not $message) {
    $message = Read-Host "Enter release notes (or press Enter to skip)"
}

# Update CHANGELOG.md
$changelogPath = Join-Path $PSScriptRoot "CHANGELOG.md"
$changelogContent = Get-Content -Path $changelogPath -Raw
$releaseHeader = "## Version $version"

# Check if version already exists in changelog
if ($changelogContent -match "## Version $version") {
    Write-Host "Warning: Version $version already exists in CHANGELOG.md" -ForegroundColor Yellow
}
else {
    # Add new version with timestamp
    $date = Get-Date -Format "yyyy-MM-dd"
    $newEntry = "$releaseHeader ($date)`n`n"
    if ($message) {
        $newEntry += "$message`n`n"
    }

    # Insert after first line
    $lines = $changelogContent -split "`n"
    $updatedChangelog = $lines[0] + "`n`n" + $newEntry + ($lines[1..($lines.Length - 1)] -join "`n")
    
    Set-Content -Path $changelogPath -Value $updatedChangelog
    Write-Host "Updated CHANGELOG.md with new version information" -ForegroundColor Green
    
    # Commit changelog changes
    git add $changelogPath
    git commit -m "Update CHANGELOG for v$version"
    Write-Host "Committed changelog changes" -ForegroundColor Green
}

# Package the mod
Write-Host "Packaging the mod..." -ForegroundColor Cyan
& "$PSScriptRoot\package.ps1" -version $version

# Create and push Git tag
$tagMessage = "Release v$version"
if ($message) {
    $tagMessage += "`n`n$message"
}

Write-Host "Creating Git tag v$version..." -ForegroundColor Cyan
git tag -a "v$version" -m $tagMessage

Write-Host "Pushing changes and tag to remote repository..." -ForegroundColor Cyan
git push
git push origin "v$version"

Write-Host "Deploy completed successfully!" -ForegroundColor Green
Write-Host "GitHub Actions workflow will now create the release automatically." -ForegroundColor Cyan
Write-Host "Check the progress at: https://github.com/voshond/openmw-quick-select/actions" -ForegroundColor Cyan
Write-Host "========================== Deploy Complete ==========================" -ForegroundColor Magenta
