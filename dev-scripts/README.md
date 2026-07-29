# OpenMW Quick Select - Development Scripts

This directory contains all development and deployment scripts for the OpenMW Quick Select mod. These scripts are accessed through proxy scripts in the project root.

> Release publishing is handled by GitHub Actions. The PowerShell scripts are
> legacy local tooling and are not part of the release path.

## Usage

Instead of running scripts directly from this directory, use the proxy scripts in the project root:

**Linux/macOS:**

```bash
./dev.sh <command> [options]
```

**Windows:**

```powershell
.\dev.ps1 <command> [options]
```

Available commands:

- `debug` - Debug the mod (copy files and restart OpenMW)
- `capture` - On Linux, render the dev-only presentation deck and export
  screenshots
- `deploy` - Deploy a new version (create tag and release)
- `package` - Package the mod for distribution

## Prerequisites

- **jq**: Required for JSON parsing
  - Ubuntu/Debian: `sudo apt install jq`
  - Fedora/RHEL: `sudo dnf install jq`
  - Arch: `sudo pacman -S jq`
- **Python 3.9+**: Required for packaging. The archive uses Python's standard
  library, so no separate ZIP utility is required.
- **git**: Required for deployment
- **wmctrl**: Optional, for window focusing
  - Ubuntu/Debian: `sudo apt install wmctrl`
- **OpenMW Flatpak, Gamescope, ImageMagick, and ydotool**: Required only by
  `capture`. Gamescope provides the fixed capture framebuffer. The `ydotool`
  daemon must be running so the script can trigger OpenMW's screenshot key.

## Configuration

All scripts use the `config.json` file in the project root for configuration. This file contains:

- Project information (name, display name, version)
- Platform-specific debug paths
- OpenMW executable paths
- Packaging include/generated manifest
- Color codes for output

## Commands

### debug

Copies mod files to your local OpenMW mods directory and optionally manages OpenMW processes.

```bash
# Basic debug (copy files only)
./dev.sh debug

# Copy files and focus existing OpenMW window
./dev.sh debug -focus

# Show what processes would be affected without killing them
./dev.sh debug -dryRun

# Disable logging output
./dev.sh debug -noLog

# Show help
./dev.sh debug --help
```

### package

Creates a distributable package of the mod.

```bash
# Package with version from config.json
./dev.sh package

# Package with specific version
./dev.sh package -v 1.2.3
./dev.sh package --version 1.2.3
```

### capture

Loads the configured save with an exact, checked-in content list in an isolated
OpenMW profile. It renders a development-only in-game overlay, captures each
slide, and publishes `media/hero.png` at exactly 1300×372 plus full-resolution
feature images under `media/presentation/`.

```bash
# Validate paths, dependencies, save, and content profile
./dev.sh capture --dry-run

# Render and publish the full deck
./dev.sh capture

# Tune threshold colours, text styles, and other capture settings in-game
./dev.sh capture --setup

# Preserve the isolated profile and logs after success
./dev.sh capture --keep-runtime
```

See [the presentation capture guide](../docs/PRESENTATION_CAPTURE.md) for
configuration, overrides, and release-isolation details.

### deploy

Updates release metadata, commits it, and pushes a release tag. GitHub Actions
then tests, packages, verifies, uploads to Nexus Mods, and publishes the
GitHub release. See [the release guide](../docs/RELEASING.md).

```bash
# Interactive deployment (prompts for version and message)
./dev.sh deploy

# Deploy with specific version
./dev.sh deploy -v 1.2.3

# Deploy with version and release message
./dev.sh deploy -v 1.2.3 -m "Added new features and bug fixes"

# Show help
./dev.sh deploy --help
```

## Utility Functions

The `utils.sh` file contains shared functions used by all scripts:

- Configuration loading and JSON parsing
- Colored output functions
- Version validation
- Directory management
- OpenMW process management
- Git operations
- Changelog updates

## File Structure

```
dev-scripts/
├── README.md       # This file
├── utils.sh        # Shared utility functions
├── debug.sh        # Development/testing script
├── capture.sh      # Automated OpenMW presentation capture
├── debug.ps1       # Windows PowerShell version
├── package.sh      # Packaging script
├── package.ps1     # Windows PowerShell version
├── deploy.sh       # Release deployment script
└── deploy.ps1      # Windows PowerShell version

../config.json      # Main configuration file (project root)
../dev.sh          # Linux/macOS proxy script
../dev.ps1         # Windows PowerShell proxy script
```

## Platform Support

The supported release path is Bash locally and GitHub Actions for publishing.
The PowerShell files remain as legacy local tooling only.

## Error Handling

The supported Bash scripts fail immediately when a command fails:

- Missing dependencies are detected and reported
- Invalid configurations are caught early
- Git status is validated before deployment
- File operations include existence checks
- Colored output helps identify issues quickly

## Direct Script Access

While it's recommended to use the proxy scripts, you can still run supported
Bash scripts directly from this directory if needed:

```bash
cd dev-scripts
./debug.sh --help
./capture.sh --dry-run
./package.sh -v 1.2.3
./deploy.sh -v 1.2.3 -m "Release notes"
```

Note: the scripts resolve the repository root themselves, so they can be run
from any directory.
