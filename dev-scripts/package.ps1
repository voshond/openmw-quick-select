param(
    [string]$version = "1.0.1"
)

# Set paths
$sourceDir = Get-Location
$outputDir = Join-Path $sourceDir "dist"
$packageName = "voshondsQuickSelect-v$version"
$packageDir = Join-Path $outputDir $packageName
$zipFile = Join-Path $outputDir "$packageName.zip"

# Create output directories
Write-Host "========================== Starting Package ==========================" -ForegroundColor Yellow
Write-Host "Creating package directories..."
if (Test-Path $outputDir) {
    Write-Host "Archiving old dist contents to $outputDir\\archive\\$version" -ForegroundColor Yellow
    $archiveDir = Join-Path $outputDir "archive\\$version"
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    Get-ChildItem -Path $outputDir | Where-Object { $_.Name -ne 'archive' } | Move-Item -Destination $archiveDir -Force
}
else {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

# Define files/directories to include
$includes = @(
    "scripts\voshondsQuickSelect",
    "textures",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    "voshondsQuickSelect.omwscripts"
)

# Define files/directories to exclude
$excludes = @(
    "scripts\Example",
    ".cursorrules",
    "debug.ps1",
    ".git",
    ".gitattributes",
    "dist",
    "package.ps1",
    "deploy.ps1",
    "TODO.md"
)

# Copy files to package directory
Write-Host "Copying files to package directory..."
foreach ($item in $includes) {
    $source = Join-Path $sourceDir $item
    $destination = Join-Path $packageDir $item
    
    # Create destination directory if it doesn't exist
    $destinationDir = Split-Path $destination -Parent
    if (!(Test-Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }
    
    # Copy the item
    if (Test-Path $source -PathType Container) {
        # If it's a directory, copy it recursively
        Copy-Item -Path $source -Destination $destination -Recurse -Force
    }
    else {
        # If it's a file, copy it
        Copy-Item -Path $source -Destination $destination -Force
    }
}

# Create zip file
Write-Host "Creating zip archive: $zipFile"
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

# Try .NET compression first, then fallback to 7z
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($packageDir, $zipFile)
    Write-Host "Zip archive created successfully using .NET compression" -ForegroundColor Green
}
catch {
    Write-Host "Warning: .NET compression failed, trying 7z..." -ForegroundColor Yellow
    
    # Check if 7z is available
    $7zPath = Get-Command "7z" -ErrorAction SilentlyContinue
    if ($7zPath) {
        Push-Location $outputDir
        & 7z a "$packageName.zip" $packageName
        Pop-Location
        Write-Host "Zip archive created successfully using 7z" -ForegroundColor Green
    }
    else {
        Write-Host "Error: No compression utility found. Please install 7-Zip." -ForegroundColor Red
        Write-Host "Download from: https://www.7-zip.org/" -ForegroundColor Cyan
        Write-Host "Or install via package manager:" -ForegroundColor Cyan
        Write-Host "  Chocolatey: choco install 7zip" -ForegroundColor Cyan
        Write-Host "  Scoop: scoop install 7zip" -ForegroundColor Cyan
        Write-Host "  Winget: winget install 7zip.7zip" -ForegroundColor Cyan
        exit 1
    }
}

Write-Host "Package created successfully at: $zipFile" -ForegroundColor Green
Write-Host "Files are also available in: $packageDir" 
Write-Host "========================== Package Complete ==========================" -ForegroundColor Yellow