#!/bin/bash

# Load utility functions and configuration
SCRIPT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
source "$(dirname "$0")/utils.sh"
init_config "$SCRIPT_DIR"

# Initialize variables
version=""
message=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            version="$2"
            shift 2
            ;;
        -m|--message)
            message="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-v|--version <version>] [-m|--message <message>]"
            echo "  -v, --version    Version number (format: x.y.z)"
            echo "  -m, --message    Release notes message"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-v|--version <version>] [-m|--message <message>]"
            exit 1
            ;;
    esac
done

# Clear the console
clear

print_header "========================== DEPLOYING $DISPLAY_NAME =========================="

# Check Git status and uncommitted changes
check_git_status

# Ask for version number if not provided or invalid
while [ -z "$version" ] || ! validate_version "$version"; do
    read -p "Enter version number (format: x.y.z): " version
done

# Confirm with user
print_info "Creating release v$version"

# Check if tag already exists
if tag_exists "v$version"; then
    print_error "Tag v$version already exists."
    exit 1
fi

# Ask for release notes if not provided
if [ -z "$message" ]; then
    read -p "Enter release notes (or press Enter to skip): " message
fi

# Update CHANGELOG.md
update_changelog "$version" "$message" "$SCRIPT_DIR"

# Package the mod
print_info "Packaging the mod..."
if [ -f "$(dirname "$0")/package.sh" ]; then
    bash "$(dirname "$0")/package.sh" --version "$version"
else
    print_warning "package.sh not found, skipping packaging step"
fi

# Create and push Git tag
tag_message="Release v$version"
if [ -n "$message" ]; then
    tag_message="$tag_message

$message"
fi

print_info "Creating Git tag v$version..."
git tag -a "v$version" -m "$tag_message"

print_info "Pushing changes and tag to remote repository..."
git push
git push origin "v$version"

print_success "Deploy completed successfully!"
print_info "GitHub Actions workflow will now create the release automatically."
print_info "Check the progress at: https://github.com/voshond/openmw-quick-select/actions"
print_header "========================== DEPLOY COMPLETE ==========================" 