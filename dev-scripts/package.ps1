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

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($packageDir, $zipFile)

Write-Host "Package created successfully at: $zipFile" -ForegroundColor Green
Write-Host "Files are also available in: $packageDir" 
Write-Host "========================== Package Complete ==========================" -ForegroundColor Yellow