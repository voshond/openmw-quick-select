#!/bin/bash

# Load utility functions and configuration
SCRIPT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
source "$(dirname "$0")/utils.sh"
init_config "$SCRIPT_DIR"

# Default version from config
version="$PROJECT_VERSION"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            version="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-v|--version <version>]"
            exit 1
            ;;
    esac
done

# Set paths
package_name="$PROJECT_NAME-v$version"
package_dir="$DIST_DIR/$package_name"
zip_file="$DIST_DIR/$package_name.zip"

# Create output directories
print_header "========================== CREATING PACKAGE: $package_name =========================="
print_info "Creating package directories..."
if [ -d "$DIST_DIR" ]; then
    rm -rf "$DIST_DIR"
fi
ensure_directory "$DIST_DIR"
ensure_directory "$package_dir"

# Load includes and excludes from JSON config
mapfile -t includes < <(jq -r '.packaging.includes[]' "$CONFIG_FILE")
mapfile -t excludes < <(jq -r '.packaging.excludes[]' "$CONFIG_FILE")

# Copy files to package directory
print_info "Copying files to package directory..."
for item in "${includes[@]}"; do
    source_path="$SCRIPT_DIR/$item"
    destination="$package_dir/$item"
    
    # Create destination directory if it doesn't exist
    destination_dir=$(dirname "$destination")
    ensure_directory "$destination_dir"
    
    # Copy the item
    if [ -d "$source_path" ]; then
        # If it's a directory, copy it recursively
        cp -r "$source_path" "$destination"
        print_info "Copied directory: $item"
    elif [ -f "$source_path" ]; then
        # If it's a file, copy it
        cp "$source_path" "$destination"
        print_info "Copied file: $item"
    else
        print_warning "$source_path does not exist, skipping..."
    fi
done

# Create zip file
print_info "Creating zip archive: $zip_file"
if [ -f "$zip_file" ]; then
    rm -f "$zip_file"
fi

# Check if zip command is available
if command_exists zip; then
    cd "$DIST_DIR"
    zip -r "$package_name.zip" "$package_name"
    cd "$SCRIPT_DIR"
    print_success "Zip archive created successfully"
else
    print_error "zip command not found. Please install zip utility."
    exit 1
fi

print_success "Package created successfully at: $zip_file"
print_info "Files are also available in: $package_dir"
print_header "========================== PACKAGE COMPLETE ==========================" 