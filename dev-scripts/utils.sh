#!/bin/bash

# Utility functions for OpenMW Quick Select mod scripts
# Source this file in other scripts: source "$(dirname "$0")/utils.sh"

# Initialize configuration
init_config() {
    local script_dir="$1"
    CONFIG_FILE="$script_dir/config.json"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: config.json not found at $CONFIG_FILE!"
        exit 1
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required to parse config.json. Install it with:"
        echo "  Ubuntu/Debian: sudo apt install jq"
        echo "  Fedora/RHEL: sudo dnf install jq"
        echo "  Arch: sudo pacman -S jq"
        exit 1
    fi
    
    # Load configuration variables
    PROJECT_NAME=$(jq -r '.project.name' "$CONFIG_FILE")
    DISPLAY_NAME=$(jq -r '.project.displayName' "$CONFIG_FILE")
    PROJECT_VERSION=$(jq -r '.project.version' "$CONFIG_FILE")
    
    # Platform-specific paths
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        MOD_DIR=$(jq -r '.paths.linux.modDir' "$CONFIG_FILE")
        OPENMW_CONFIG=$(jq -r '.paths.linux.openmwConfig' "$CONFIG_FILE")
        OPENMW_NATIVE=$(jq -r '.openmw.linux.native' "$CONFIG_FILE")
        OPENMW_FLATPAK=$(jq -r '.openmw.linux.flatpak' "$CONFIG_FILE")
    else
        echo "Unsupported OS type: $OSTYPE"
        exit 1
    fi
    
    # Derived paths
    SCRIPTS_DIR="$MOD_DIR/scripts/$PROJECT_NAME"
    TEXTURES_DIR="$MOD_DIR/textures"
    DIST_DIR="$script_dir/dist"
    
    # Load color codes
    COLOR_RED=$(jq -r '.colors.red' "$CONFIG_FILE")
    COLOR_GREEN=$(jq -r '.colors.green' "$CONFIG_FILE")
    COLOR_YELLOW=$(jq -r '.colors.yellow' "$CONFIG_FILE")
    COLOR_BLUE=$(jq -r '.colors.blue' "$CONFIG_FILE")
    COLOR_MAGENTA=$(jq -r '.colors.magenta' "$CONFIG_FILE")
    COLOR_CYAN=$(jq -r '.colors.cyan' "$CONFIG_FILE")
    COLOR_WHITE=$(jq -r '.colors.white' "$CONFIG_FILE")
    COLOR_RESET=$(jq -r '.colors.reset' "$CONFIG_FILE")
}

# Color printing functions
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${COLOR_RESET}"
}

print_error() { print_color "$COLOR_RED" "ERROR: $1"; }
print_success() { print_color "$COLOR_GREEN" "SUCCESS: $1"; }
print_warning() { print_color "$COLOR_YELLOW" "WARNING: $1"; }
print_info() { print_color "$COLOR_CYAN" "INFO: $1"; }
print_header() { print_color "$COLOR_MAGENTA" "$1"; }

# Validate version format (x.y.z)
validate_version() {
    local version="$1"
    if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_info "Created directory: $dir"
    fi
}

# Clean directory contents
clean_directory() {
    local dir="$1"
    if [ -d "$dir" ]; then
        rm -rf "$dir"/*
        print_info "Cleaned directory: $dir"
    fi
}

# Copy files with error handling
copy_files() {
    local source="$1"
    local destination="$2"
    
    if [ -d "$source" ]; then
        cp -r "$source"/* "$destination/"
    elif [ -f "$source" ]; then
        cp "$source" "$destination"
    else
        print_warning "Source does not exist: $source"
        return 1
    fi
    return 0
}

# Find OpenMW processes (more specific to avoid killing editors)
find_openmw_processes() {
    # Use exact process name matching instead of fuzzy matching
    local native_pid=$(pgrep -x "$OPENMW_NATIVE" 2>/dev/null)
    
    # For Flatpak, be more specific about the full command
    local flatpak_pid=$(pgrep -f "flatpak run $OPENMW_FLATPAK" 2>/dev/null)
    
    # Alternative: also check for the actual OpenMW binary in flatpak
    if [ -z "$flatpak_pid" ]; then
        flatpak_pid=$(pgrep -f "/app/bin/openmw" 2>/dev/null)
    fi
    
    echo "$native_pid $flatpak_pid"
}

# Show what OpenMW processes would be affected (dry run)
show_openmw_processes() {
    local pids=($(find_openmw_processes))
    
    if [ ${#pids[@]} -eq 0 ] || ([ ${#pids[@]} -eq 1 ] && [ -z "${pids[0]}" ]); then
        print_info "No OpenMW processes found"
        return 0
    fi
    
    print_info "OpenMW processes that would be affected:"
    for pid in "${pids[@]}"; do
        if [ -n "$pid" ]; then
            local process_info=$(ps -p "$pid" -o pid,comm,args --no-headers 2>/dev/null)
            if [ -n "$process_info" ]; then
                echo "  $process_info"
            fi
        fi
    done
}

# Kill OpenMW processes (with safety checks)
kill_openmw() {
    local pids=($(find_openmw_processes))
    
    # Show what processes we found before killing anything
    for pid in "${pids[@]}"; do
        if [ -n "$pid" ]; then
            local process_info=$(ps -p "$pid" -o pid,comm,args --no-headers 2>/dev/null)
            if [ -n "$process_info" ]; then
                print_info "Found OpenMW process: $process_info"
            fi
        fi
    done
    
    # Kill the processes
    for pid in "${pids[@]}"; do
        if [ -n "$pid" ]; then
            # Double-check this is actually an OpenMW process
            local process_name=$(ps -p "$pid" -o comm --no-headers 2>/dev/null)
            if [[ "$process_name" == *"openmw"* ]] || [[ "$process_name" == *"flatpak"* ]]; then
                print_info "Terminating OpenMW process (PID: $pid, Name: $process_name)..."
                kill "$pid" 2>/dev/null
                sleep 1
                
                # Force kill if still running
                if kill -0 "$pid" 2>/dev/null; then
                    print_warning "Force killing OpenMW process (PID: $pid)..."
                    kill -9 "$pid" 2>/dev/null
                fi
            else
                print_warning "Skipping PID $pid - doesn't appear to be OpenMW ($process_name)"
            fi
        fi
    done
}

# Start OpenMW via Flatpak
start_openmw() {
    if command_exists flatpak; then
        print_info "Starting OpenMW via Flatpak..."
        flatpak run "$OPENMW_FLATPAK" &
        print_success "OpenMW Flatpak started. Please load your save and enable the mod."
    else
        print_error "Flatpak not available. Please start OpenMW manually."
        return 1
    fi
}

# Focus OpenMW window
focus_openmw() {
    local pids=($(find_openmw_processes))
    
    if [ ${#pids[@]} -gt 0 ] && [ -n "${pids[0]}" ]; then
        print_info "OpenMW is running, attempting to focus window..."
        
        if command_exists wmctrl; then
            wmctrl -a "OpenMW" 2>/dev/null || wmctrl -a "openmw" 2>/dev/null
            print_success "Attempted to focus OpenMW window using wmctrl"
        else
            print_warning "wmctrl not available, cannot focus window automatically"
            print_info "Please manually switch to the OpenMW window"
        fi
    else
        print_info "OpenMW is not running. Starting it..."
        start_openmw
    fi
}

# Check for git and uncommitted changes
check_git_status() {
    if ! command_exists git; then
        print_error "Git is not installed or not in the PATH."
        exit 1
    fi
    
    local git_version=$(git --version)
    print_info "Found Git: $git_version"
    
    local status=$(git status --porcelain)
    if [ -n "$status" ]; then
        print_error "You have uncommitted changes. Commit or stash them before creating a release."
        print_error "Uncommitted changes:"
        echo "$status"
        exit 1
    fi
}

# Check if git tag exists
tag_exists() {
    local tag="$1"
    git tag -l "$tag" | grep -q "$tag"
}

# Update changelog
update_changelog() {
    local version="$1"
    local message="$2"
    local script_dir="$3"
    local changelog_path="$script_dir/CHANGELOG.md"
    
    if [ -f "$changelog_path" ]; then
        local changelog_content=$(cat "$changelog_path")
        local release_header="## Version $version"
        
        # Check if version already exists in changelog
        if echo "$changelog_content" | grep -q "## Version $version"; then
            print_warning "Version $version already exists in CHANGELOG.md"
        else
            # Add new version with timestamp
            local date=$(date +"%Y-%m-%d")
            local new_entry="$release_header ($date)\n\n"
            if [ -n "$message" ]; then
                new_entry+="$message\n\n"
            fi
            
            # Insert after first line
            local first_line=$(head -n 1 "$changelog_path")
            local rest_of_file=$(tail -n +2 "$changelog_path")
            
            # Create updated changelog
            {
                echo "$first_line"
                echo ""
                echo -e "$new_entry"
                echo "$rest_of_file"
            } > "$changelog_path.tmp"
            
            mv "$changelog_path.tmp" "$changelog_path"
            print_success "Updated CHANGELOG.md with new version information"
            
            # Commit changelog changes
            git add "$changelog_path"
            git commit -m "Update CHANGELOG for v$version"
            print_success "Committed changelog changes"
        fi
    fi
} 