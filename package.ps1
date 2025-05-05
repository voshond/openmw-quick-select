param(
    [string]$version = "1.0.0"
)

# Set paths
$sourceDir = Get-Location
$outputDir = Join-Path $sourceDir "dist"
$packageName = "voshondsQuickSelect-v$version"
$packageDir = Join-Path $outputDir $packageName
$zipFile = Join-Path $outputDir "$packageName.zip"

# Create output directories
Write-Host "Creating package directories..."
if (Test-Path $outputDir) {
    Remove-Item $outputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

# Define files/directories to include
$includes = @(
    "scripts\voshondsQuickSelect",
    "icons",
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
    "package.ps1"
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

Write-Host "Package created successfully at: $zipFile"
Write-Host "Files are also available in: $packageDir" 