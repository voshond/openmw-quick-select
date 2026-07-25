#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/utils.sh"
init_config "$REPO_ROOT"
cd "$REPO_ROOT"

trap 'exit_code=$?; print_error "Deploy failed at line $LINENO (exit $exit_code)."; exit "$exit_code"' ERR

fail() {
    print_error "$*"
    exit 1
}

version=""
message=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            [[ $# -ge 2 ]] || fail "Missing version after $1"
            version="$2"
            shift 2
            ;;
        -m|--message)
            [[ $# -ge 2 ]] || fail "Missing release notes after $1"
            message="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-v|--version <version>] [-m|--message <message>]"
            echo "  -v, --version    Version number (format: x.y.z)"
            echo "  -m, --message    Required release notes for CHANGELOG.md and Nexus Mods"
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

print_header "========================== DEPLOYING $DISPLAY_NAME =========================="
check_git_status

while [[ -z "$version" ]] || ! validate_version "$version"; do
    read -r -p "Enter version number (format: x.y.z): " version
done

print_info "Creating release v$version"
if tag_exists "v$version"; then
    fail "Tag v$version already exists."
fi

while [[ -z "$message" ]]; do
    read -r -p "Enter release notes: " message
done

# The tag always points at a commit where config and changelog agree. GitHub
# Actions independently checks that invariant before anything is published.
current_version="$(jq -er '.project.version' "$CONFIG_FILE")"
if [[ "$current_version" != "$version" ]]; then
    temp_config="$(mktemp "$REPO_ROOT/.config.json.XXXXXX")"
    jq --arg version "$version" '.project.version = $version' "$CONFIG_FILE" > "$temp_config"
    mv "$temp_config" "$CONFIG_FILE"
    print_success "Updated config.json version to $version"
fi

update_changelog "$version" "$message" "$REPO_ROOT"
git add -- CHANGELOG.md config.json
git diff --cached --quiet || git commit -m "Release v$version"

# Push the release commit before its tag so the tag event always sees an
# immutable, complete release candidate in GitHub Actions.
print_info "Pushing release commit to remote repository..."
git push

tag_message="Release v$version"
tag_message+=$'\n\n'
tag_message+="$message"
print_info "Creating Git tag v$version..."
git tag -a "v$version" -m "$tag_message"

print_info "Pushing tag to remote repository..."
git push origin "v$version"

print_success "Release tag pushed successfully."
print_info "GitHub Actions will test, package, verify, upload to Nexus Mods, and then publish the GitHub release."
print_info "Check the progress at: https://github.com/voshond/openmw-quick-select/actions"
print_header "========================== DEPLOY COMPLETE =========================="
