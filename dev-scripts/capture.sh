#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/utils.sh"
init_config "$REPO_ROOT"

dry_run=false
keep_runtime=false
setup_mode=false
save_override=""
content_list_override=""
timeout_seconds=120

fail() {
    print_error "$*"
    exit 1
}

usage() {
    cat <<'EOF'
Usage: capture.sh [options]

Options:
  --save <path>           Override the presentation save configured in config.json
  --content-list <path>   Override the exact OpenMW content list
  --timeout <seconds>     Per-stage timeout (default: 120)
  --setup                 Open the persistent capture profile for manual setup
  --keep-runtime          Preserve the isolated capture profile and logs
  --dry-run               Validate and print the capture plan without changing anything
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --save)
            [[ $# -ge 2 ]] || fail "Missing path after --save"
            save_override="$2"
            shift 2
            ;;
        --content-list)
            [[ $# -ge 2 ]] || fail "Missing path after --content-list"
            content_list_override="$2"
            shift 2
            ;;
        --timeout)
            [[ $# -ge 2 ]] || fail "Missing seconds after --timeout"
            timeout_seconds="$2"
            shift 2
            ;;
        --setup)
            setup_mode=true
            shift
            ;;
        --keep-runtime)
            keep_runtime=true
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || fail "--timeout must be a positive integer"

resolve_repo_path() {
    local value="$1"
    if [[ "$value" = /* ]]; then
        printf '%s\n' "$value"
    else
        printf '%s/%s\n' "$REPO_ROOT" "$value"
    fi
}

presentation_value() {
    jq -er ".presentation.linux.$1" "$CONFIG_FILE"
}

base_config="$(presentation_value baseConfig)"
save_path="${save_override:-$(presentation_value save)}"
content_list="$(resolve_repo_path "${content_list_override:-$(presentation_value contentList)}")"
output_dir="$(resolve_repo_path "$(presentation_value outputDir)")"
capture_width="$(presentation_value captureWidth)"
capture_height="$(presentation_value captureHeight)"

[[ -f "$base_config" ]] || fail "OpenMW base config does not exist: $base_config"
[[ -f "$save_path" ]] || fail "Presentation save does not exist: $save_path"
[[ -f "$content_list" ]] || fail "Presentation content list does not exist: $content_list"
[[ "$capture_width" =~ ^[1-9][0-9]*$ ]] || fail "captureWidth must be a positive integer"
[[ "$capture_height" =~ ^[1-9][0-9]*$ ]] || fail "captureHeight must be a positive integer"

content_count="$(sed -e 's/\r$//' -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$content_list" | wc -l)"
[[ "$content_count" -gt 0 ]] || fail "Presentation content list is empty: $content_list"

presentation_root="$REPO_ROOT/dev-content"
presentation_manifest="$presentation_root/voshondsQuickSelectPresentation.omwscripts"
presentation_scripts="$presentation_root/scripts/voshondsQuickSelectPresentation"
settings_template="$presentation_root/presentation/settings.cfg"
setup_profile="$REPO_ROOT/.presentation-profile"
setup_config="$setup_profile/config"
setup_userdata="$setup_profile/userdata"
setup_save_dir="$setup_userdata/saves/QuickSelectPresentation"
setup_save="$setup_save_dir/Presentation.omwsave"

[[ -f "$presentation_manifest" ]] || fail "Missing presentation manifest: $presentation_manifest"
[[ -d "$presentation_scripts" ]] || fail "Missing presentation scripts: $presentation_scripts"
[[ -f "$settings_template" ]] || fail "Missing capture settings: $settings_template"

required_commands=(cc flatpak gamescope identify jq magick ydotool)
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required"
done

print_header "===================== QUICKSELECT PRESENTATION CAPTURE ====================="
print_info "OpenMW: Flatpak $OPENMW_FLATPAK"
print_info "Base config: $base_config"
print_info "Content profile: $content_list ($content_count entries)"
print_info "Save: $save_path"
print_info "Framebuffer: ${capture_width}x${capture_height}"
print_info "Output: $output_dir"
if [[ "$setup_mode" = true ]]; then
    print_info "Mode: interactive setup"
    print_info "Persistent profile: $setup_profile"
elif [[ -f "$setup_save" ]]; then
    print_info "Persistent setup profile: available"
else
    print_info "Persistent setup profile: not created (run with --setup)"
fi

if [[ "$dry_run" = true ]]; then
    print_success "Capture plan is valid; no files or processes were changed."
    exit 0
fi

write_settings() {
    local destination="$1"
    sed \
        -e "s/^resolution x = .*/resolution x = $capture_width/" \
        -e "s/^resolution y = .*/resolution y = $capture_height/" \
        "$settings_template" > "$destination"
}

write_content_config() {
    local destination="$1"
    local include_presentation="$2"

    {
        printf '# Generated by dev-scripts/capture.sh. Do not edit.\n'
        printf 'replace=content\n'
        printf 'data="%s"\n' "$MOD_DIR"
        while IFS= read -r content_file || [[ -n "$content_file" ]]; do
            content_file="${content_file%$'\r'}"
            [[ -n "$content_file" ]] || continue
            [[ "$content_file" =~ ^[[:space:]]*# ]] && continue
            [[ "$content_file" == "voshondsQuickSelectPresentation.omwscripts" ]] && continue
            printf 'content=%s\n' "$content_file"
        done < "$content_list"
        if [[ "$include_presentation" = true ]]; then
            printf 'content=voshondsQuickSelectPresentation.omwscripts\n'
        fi
    } > "$destination"
}

if [[ "$setup_mode" = true ]]; then
    print_info "Stopping any running OpenMW instance..."
    kill_openmw
    deploy_mod_files "$REPO_ROOT"

    # A setup session must never inherit a presentation overlay left behind by
    # an interrupted capture.
    rm -rf -- "$MOD_DIR/scripts/voshondsQuickSelectPresentation"
    rm -rf -- "$MOD_DIR/textures/voshondsQuickSelectPresentation"
    rm -f -- "$MOD_DIR/voshondsQuickSelectPresentation.omwscripts"

    mkdir -p "$setup_config" "$setup_save_dir"
    if [[ ! -f "$setup_save" ]]; then
        cp "$save_path" "$setup_save"
        print_info "Initialized setup save from: $save_path"
    fi
    write_settings "$setup_config/settings.cfg"
    write_content_config "$setup_config/openmw.cfg" false

    print_header "=================== PRESENTATION PROFILE SETUP ==================="
    print_info "Adjust Quick Select under Options > Scripts."
    print_info "Settings persist automatically in this capture profile."
    print_info "Save the game only if you also change assignments or game state."
    print_info "Exit OpenMW when setup is complete."

    gamescope \
        --output-width "$capture_width" \
        --output-height "$capture_height" \
        --nested-width "$capture_width" \
        --nested-height "$capture_height" \
        --fullscreen \
        --grab \
        --force-windows-fullscreen \
        -- \
        flatpak run \
        --nosocket=wayland \
        --socket=x11 \
        --env=SDL_VIDEODRIVER=x11 \
        --command=openmw "$OPENMW_FLATPAK" \
        --config "$setup_config" \
        --user-data "$setup_userdata" \
        --skip-menu \
        --load-savegame "$setup_save" \
        > "$setup_profile/flatpak.log" 2>&1

    print_success "Presentation settings saved in: $setup_profile"
    print_info "Run './dev.sh capture' to render with these settings."
    exit 0
fi

runtime_dir="$(mktemp -d "$REPO_ROOT/.presentation-runtime.XXXXXX")"
runtime_config="$runtime_dir/config"
runtime_userdata="$runtime_dir/userdata"
runtime_exports="$runtime_dir/exports"
runtime_log="$runtime_dir/flatpak.log"
runtime_save_dir="$runtime_userdata/saves/QuickSelectPresentation"
runtime_save="$runtime_save_dir/Presentation.omwsave"
presentation_target="$MOD_DIR/scripts/voshondsQuickSelectPresentation"
presentation_manifest_target="$MOD_DIR/voshondsQuickSelectPresentation.omwscripts"
presentation_texture_target="$MOD_DIR/textures/voshondsQuickSelectPresentation"
openmw_pid=""
gamepad_pid=""
capture_succeeded=false
presentation_deployed=false

cleanup() {
    local exit_code=$?

    if [[ -n "$gamepad_pid" ]] && kill -0 "$gamepad_pid" 2>/dev/null; then
        kill "$gamepad_pid" 2>/dev/null || true
        wait "$gamepad_pid" 2>/dev/null || true
    fi

    if [[ -n "$openmw_pid" ]] && kill -0 "$openmw_pid" 2>/dev/null; then
        kill "$openmw_pid" 2>/dev/null || true
        wait "$openmw_pid" 2>/dev/null || true
    fi

    if [[ "$presentation_deployed" = true ]]; then
        rm -rf -- "$presentation_target"
        rm -rf -- "$presentation_texture_target"
        rm -f -- "$presentation_manifest_target"
    fi

    if [[ "$capture_succeeded" = true && "$keep_runtime" = false ]]; then
        rm -rf -- "$runtime_dir"
    else
        print_info "Capture runtime preserved at: $runtime_dir"
    fi

    return "$exit_code"
}
trap cleanup EXIT

print_info "Stopping any running OpenMW instance..."
kill_openmw

deploy_mod_files "$REPO_ROOT"

mkdir -p "$MOD_DIR/scripts"
rm -rf -- "$presentation_target"
cp -r "$presentation_scripts" "$presentation_target"
cp "$presentation_manifest" "$presentation_manifest_target"
presentation_deployed=true

mkdir -p "$presentation_texture_target"
magick \
    -size 2048x16 \
    xc:black \
    -alpha set \
    -channel A \
    -fx 'i < 420 ? 0.90 : (i > 1550 ? 0 : 0.90 * pow((1550 - i) / 1130, 1.35))' \
    -channel RGBA \
    -depth 8 \
    -define tga:compression=none \
    "$presentation_texture_target/left_fade.tga"

mkdir -p "$runtime_config" "$runtime_save_dir" "$runtime_exports/presentation"
write_settings "$runtime_config/settings.cfg"
write_content_config "$runtime_config/openmw.cfg" true

capture_save_source="$save_path"
if [[ -z "$save_override" && -f "$setup_save" ]]; then
    capture_save_source="$setup_save"
    print_info "Using the persistent presentation setup save."
fi
cp "$capture_save_source" "$runtime_save"

for storage_file in player_storage.bin global_storage.bin; do
    if [[ -f "$setup_config/$storage_file" ]]; then
        cp "$setup_config/$storage_file" "$runtime_config/$storage_file"
    fi
done

print_info "Starting isolated OpenMW capture session..."
gamepad_helper="$runtime_dir/presentation-gamepad"
gamepad_log="$runtime_dir/presentation-gamepad.log"
cc -std=c11 -O2 -Wall -Wextra \
    "$REPO_ROOT/dev-scripts/presentation-gamepad.c" \
    -o "$gamepad_helper"
"$gamepad_helper" > "$gamepad_log" 2>&1 &
gamepad_pid=$!
for _ in {1..30}; do
    if grep -q 'VQS_PRESENTATION_GAMEPAD_READY' "$gamepad_log" 2>/dev/null; then
        break
    fi
    kill -0 "$gamepad_pid" 2>/dev/null || fail "Virtual presentation gamepad failed to start."
    sleep 0.1
done
grep -q 'VQS_PRESENTATION_GAMEPAD_READY' "$gamepad_log" \
    || fail "Timed out creating virtual presentation gamepad."

gamescope \
    --output-width "$capture_width" \
    --output-height "$capture_height" \
    --nested-width "$capture_width" \
    --nested-height "$capture_height" \
    --fullscreen \
    --grab \
    --force-windows-fullscreen \
    -- \
    flatpak run \
    --nosocket=wayland \
    --socket=x11 \
    --env=SDL_VIDEODRIVER=x11 \
    --command=openmw "$OPENMW_FLATPAK" \
    --config "$runtime_config" \
    --user-data "$runtime_userdata" \
    --skip-menu \
    --load-savegame "$runtime_save" \
    > "$runtime_log" 2>&1 &
openmw_pid=$!

combined_logs() {
    local openmw_log="$runtime_config/openmw.log"
    if [[ -f "$openmw_log" ]]; then
        cat "$openmw_log"
    fi
    if [[ -f "$runtime_log" ]]; then
        cat "$runtime_log"
    fi
}

wait_for_ready() {
    local expected_index="$1"
    local started_at=$SECONDS
    local token

    while (( SECONDS - started_at < timeout_seconds )); do
        if ! kill -0 "$openmw_pid" 2>/dev/null; then
            print_error "OpenMW exited before presentation slide $expected_index became ready." >&2
            combined_logs | tail -80 >&2 || true
            return 1
        fi

        token="$({
            combined_logs \
                | grep -oE 'VQS_PRESENTATION_READY\|[0-9]+\|[a-z0-9-]+\|[0-9]+\|[^[:space:]]+' \
                | awk -F '|' -v expected="$expected_index" '$2 == expected { value = $0 } END { print value }'
        } || true)"
        if [[ -n "$token" ]]; then
            printf '%s\n' "$token"
            return 0
        fi
        sleep 0.1
    done

    print_error "Timed out waiting for presentation slide $expected_index." >&2
    combined_logs | tail -80 >&2 || true
    return 1
}

focus_openmw_window() {
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -a "OpenMW" 2>/dev/null \
            || wmctrl -a "openmw" 2>/dev/null \
            || wmctrl -a "gamescope" 2>/dev/null \
            || true
    fi
    sleep 0.4
}

activate_script_result() {
    # Gamescope grabs the pointer, so clamp its in-game cursor to the top-left,
    # move to the first script result, and emit the mouse activation OpenMW
    # requires for this list.
    ydotool mousemove -- -10000 -10000
    sleep 0.15
    ydotool mousemove -- 800 230
    sleep 0.15
    ydotool click 0xC0 >/dev/null
    sleep 0.1
    ydotool click 0xC0 >/dev/null
}

perform_slide_action() {
    local action="$1"
    case "$action" in
        none)
            ;;
        open-script-settings)
            # MainMenu opens with Return focused. Move to Options and activate it.
            for _ in 1 2 3 4; do
                ydotool key 108:1 108:0
                sleep 0.08
            done
            ydotool key 28:1 28:0
            sleep 0.5

            # The native menu maps shoulder buttons directly to Options tabs.
            # Four presses move from Prefs to Scripts without pointer geometry.
            for _ in 1 2 3 4; do
                kill -USR1 "$gamepad_pid"
                sleep 0.15
            done

            ydotool key 15:1 15:0
            sleep 0.15
            ydotool type --key-delay 40 "voshond's Quick Select"
            sleep 0.3
            # OpenMW only handles mouse activation for this list.
            activate_script_result
            sleep 0.5

            # Move into the populated settings pane and scroll down far enough
            # to show several configurable options in the captured slide.
            ydotool mousemove -- 800 400
            for _ in 1 2 3; do
                ydotool mousemove --wheel -- 0 -1
                sleep 0.08
            done
            sleep 0.3
            ;;
        *)
            fail "Unsupported presentation capture action: $action"
            ;;
    esac
}

finish_slide_action() {
    local action="$1"
    case "$action" in
        none)
            ;;
        open-script-settings)
            # Close Options, then MainMenu. The presentation script consumes
            # the second Escape without treating it as an abort.
            ydotool key 1:1 1:0
            sleep 0.3
            ydotool key 1:1 1:0
            sleep 0.3
            ;;
        *)
            fail "Unsupported presentation capture action: $action"
            ;;
    esac
}

wait_for_screenshot() {
    local expected_count="$1"
    local expected_dimensions="$2"
    local screenshot_dir="$runtime_userdata/screenshots"
    local started_at=$SECONDS
    local files=()
    local candidate
    local dimensions
    local first_size
    local second_size

    while (( SECONDS - started_at < timeout_seconds )); do
        mapfile -t files < <(
            find "$screenshot_dir" -maxdepth 1 -type f -name '*.png' -print 2>/dev/null | sort
        )
        if [[ "${#files[@]}" -ge "$expected_count" ]]; then
            candidate="${files[$((expected_count - 1))]}"
            first_size="$(stat -c '%s' "$candidate" 2>/dev/null || printf '0')"
            dimensions="$(identify -format '%wx%h' "$candidate" 2>/dev/null || true)"
            if [[ "$first_size" -gt 0 && "$dimensions" == "$expected_dimensions" ]]; then
                sleep 0.25
                second_size="$(stat -c '%s' "$candidate" 2>/dev/null || printf '0')"
                dimensions="$(identify -format '%wx%h' "$candidate" 2>/dev/null || true)"
                if [[ "$first_size" == "$second_size" && "$dimensions" == "$expected_dimensions" ]]; then
                    printf '%s\n' "$candidate"
                    return 0
                fi
            fi
        fi
        sleep 0.1
    done

    print_error "Timed out waiting for screenshot $expected_count." >&2
    return 1
}

validate_dimensions() {
    local image="$1"
    local expected="$2"
    local actual
    actual="$(identify -format '%wx%h' "$image" 2>/dev/null || true)"
    [[ "$actual" == "$expected" ]] || fail "Expected $expected image, got $actual: $image"
}

slide_index=1
slide_total=0
feature_number=0

while :; do
    if ! ready_token="$(wait_for_ready "$slide_index")"; then
        fail "Could not capture presentation slide $slide_index."
    fi
    IFS='|' read -r _ ready_index slug slide_total export_spec capture_action <<< "$ready_token"
    [[ "$ready_index" == "$slide_index" ]] || fail "Unexpected presentation index: $ready_token"

    print_info "Capturing slide $ready_index/$slide_total: $slug"
    focus_openmw_window
    perform_slide_action "${capture_action:-none}"
    ydotool key 88:1 88:0
    if ! screenshot_path="$(wait_for_screenshot "$slide_index" "${capture_width}x${capture_height}")"; then
        fail "OpenMW did not write screenshot $slide_index."
    fi
    validate_dimensions "$screenshot_path" "${capture_width}x${capture_height}"

    if [[ "$export_spec" == "full" ]]; then
        feature_number=$((feature_number + 1))
        staged_path="$runtime_exports/presentation/$(printf '%02d' "$feature_number")-$slug.png"
        cp "$screenshot_path" "$staged_path"
    elif [[ "$export_spec" =~ ^1300x372\+[0-9]+\+[0-9]+$ ]]; then
        staged_path="$runtime_exports/hero.png"
        magick "$screenshot_path" -crop "$export_spec" +repage "$staged_path"
        validate_dimensions "$staged_path" "1300x372"
    else
        fail "Unsupported presentation export specification: $export_spec"
    fi

    if [[ "$slide_index" -ge "$slide_total" ]]; then
        if [[ "${capture_action:-none}" == "open-script-settings" ]]; then
            print_info "Closing isolated OpenMW session after native menu capture..."
            kill "$openmw_pid" 2>/dev/null || true
            wait "$openmw_pid" 2>/dev/null || true
            openmw_pid=""
        else
            finish_slide_action "${capture_action:-none}"
            ydotool key 109:1 109:0
        fi
        break
    fi
    finish_slide_action "${capture_action:-none}"
    ydotool key 109:1 109:0
    slide_index=$((slide_index + 1))
done

if [[ -n "$openmw_pid" ]]; then
    print_info "Waiting for OpenMW to exit..."
    if ! wait "$openmw_pid"; then
        fail "OpenMW exited with an error after the presentation run."
    fi
    openmw_pid=""
fi

publish_file() {
    local source_file="$1"
    local destination_file="$2"
    local temporary_file="${destination_file}.capture.tmp"

    mkdir -p "$(dirname "$destination_file")"
    cp "$source_file" "$temporary_file"
    mv "$temporary_file" "$destination_file"
    print_success "Published $destination_file"
}

publish_file "$runtime_exports/hero.png" "$output_dir/hero.png"
while IFS= read -r feature_file; do
    publish_file "$feature_file" "$output_dir/presentation/${feature_file##*/}"
done < <(find "$runtime_exports/presentation" -maxdepth 1 -type f -name '*.png' -print | sort)

capture_succeeded=true
print_header "======================== PRESENTATION CAPTURE COMPLETE ======================="
