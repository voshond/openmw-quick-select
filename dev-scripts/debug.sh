#!/bin/bash

# Parse command line arguments
NOLOG=false
FOCUS=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -noLog)
            NOLOG=true
            shift
            ;;
        -focus)
            FOCUS=true
            shift
            ;;
        -dryRun|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -noLog          Disable logging output"
            echo "  -focus          Focus existing OpenMW window or start if not running"
            echo "  -dryRun         Show what processes would be affected without killing them"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Clear the console
clear

# Load utility functions and configuration
SCRIPT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
source "$(dirname "$0")/utils.sh"
init_config "$SCRIPT_DIR"

# Print header
print_header "========================== VOSHOND'S QUICK SELECT DEBUG (Linux) =========================="

# Create target directories if they don't exist
ensure_directory "$MOD_DIR"
ensure_directory "$SCRIPTS_DIR"
ensure_directory "$TEXTURES_DIR"

# Clean directories before copying to ensure a clean state
clean_directory "$SCRIPTS_DIR"
clean_directory "$TEXTURES_DIR"

# Copy all relevant files
print_info "Copying mod files..."
cp -r "$SCRIPT_DIR/scripts/$PROJECT_NAME/"* "$SCRIPTS_DIR/"
cp -r "$SCRIPT_DIR/textures/"* "$TEXTURES_DIR/"
cp "$SCRIPT_DIR/$PROJECT_NAME.omwscripts" "$MOD_DIR/"
print_success "Copied all mod files to $MOD_DIR"

# Handle OpenMW process management
if [ "$DRY_RUN" = true ]; then
    print_info "DRY RUN MODE - Showing what processes would be affected:"
    show_openmw_processes
elif [ "$FOCUS" = true ]; then
    focus_openmw
elif [ "$FOCUS" = false ]; then
    kill_openmw
    start_openmw
fi

echo ""
print_success "Mod files have been copied to: $MOD_DIR"
echo ""
print_info "To use this mod:"
print_info "1. Add the mod directory to your OpenMW data paths in openmw.cfg"
print_info "2. Add 'content=$PROJECT_NAME.omwscripts' to your openmw.cfg"
print_info "3. Start OpenMW and load a save"
print_info "4. Use the quick select hotkeys to access your favorite items"
print_info "5. Enable debug logging in mod settings to see console output"
print_header "========================== DEBUG COMPLETE =========================="
