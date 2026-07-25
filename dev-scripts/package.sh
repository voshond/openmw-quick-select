#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
version=""

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            [[ $# -ge 2 ]] || fail "Missing version after $1"
            version="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-v|--version <version>]"
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

command -v python3 >/dev/null 2>&1 || fail "python3 is required for packaging"

arguments=("$REPO_ROOT/tools/package_release.py")
if [[ -n "$version" ]]; then
    arguments+=(--version "$version")
fi

cd "$REPO_ROOT"
python3 "${arguments[@]}"
