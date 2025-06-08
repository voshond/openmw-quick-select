#!/bin/bash

# Voshond's Quick Select - Development Script Proxy
# This script acts as a proxy to call development scripts from the dev-scripts directory

SCRIPT_DIR="$(pwd)"
DEV_SCRIPTS_DIR="$SCRIPT_DIR/dev-scripts"

# Available commands
AVAILABLE_COMMANDS=("debug" "deploy" "package")

# Function to show usage
show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Available commands:"
    echo "  debug     - Debug the mod (copy files and restart OpenMW)"
    echo "  deploy    - Deploy a new version (create tag and release)"
    echo "  package   - Package the mod for distribution"
    echo ""
    echo "Options are passed through to the respective scripts."
    echo "Use '$0 <command> --help' to see command-specific options."
    echo ""
    echo "Examples:"
    echo "  $0 debug -focus"
    echo "  $0 deploy -v 1.2.3 -m 'Bug fixes'"
    echo "  $0 package -v 1.2.3"
}

# Check if command is provided
if [ $# -eq 0 ]; then
    echo "Error: No command specified"
    echo ""
    show_usage
    exit 1
fi

COMMAND="$1"
shift  # Remove the command from arguments

# Check if command is valid
if [[ ! " ${AVAILABLE_COMMANDS[@]} " =~ " ${COMMAND} " ]]; then
    echo "Error: Unknown command '$COMMAND'"
    echo ""
    show_usage
    exit 1
fi

# Construct the script path
SCRIPT_PATH="$DEV_SCRIPTS_DIR/${COMMAND}.sh"

# Check if script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: Script not found at $SCRIPT_PATH"
    exit 1
fi

# Make sure the script is executable
chmod +x "$SCRIPT_PATH"

# Execute the script with remaining arguments
echo "Executing: $COMMAND $@"
echo "----------------------------------------"
exec "$SCRIPT_PATH" "$@" 