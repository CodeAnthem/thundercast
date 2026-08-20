#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration prompts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-19
# Description:   Interactive field prompts — all types in one place
# ==================================================================================================

# Description: Normalize yes/no/true/false aliases to true or false.
nds_cfg_normalize_toggle() {
    case "${1,,}" in
        true|enabled|yes|y|1) echo "true" ;;
        false|disabled|no|n|0) echo "false" ;;
        *) echo "$1" ;;
    esac
}

# Description: Format a toggle for display (yes/no).
nds_cfg_display_toggle() {
    nds_ui_format_bool "$1"
}

# Description: Map a stored choice value to its display label.
nds_cfg_display_choice() {
    local value="$1" labels="$2" pair option label
    [[ -z "$labels" ]] && { echo "$value"; return 0; }
    IFS='|' read -ra pairs <<< "$labels"
    for pair in "${pairs[@]}"; do
        option="${pair%%=*}"
        label="${pair#*=}"
        [[ "$value" == "$option" ]] && { echo "$label"; return 0; }
    done
    echo "$value"
}

# Description: Print choice options with descriptions (uses nds_ui_choice_row).
# Arguments:
# - options: <String> Pipe-separated option keys
# - labels:  <String> key=description pairs separated by |
nds_cfg_print_choice_options() {
    local options="$1" labels="$2"
    local option pair desc
    local -a pairs
    [[ -n "$labels" ]] || return 0
    IFS='|' read -ra pairs <<< "$labels"
    for option in ${options//|/ }; do
        desc=""
        for pair in "${pairs[@]}"; do
            [[ "${pair%%=*}" == "$option" ]] && { desc="${pair#*=}"; break; }
        done
        nds_ui_choice_row "$option" "$option" "$desc"
    done
    nds_ui_b ""
}

# Description: Print numbered choice options (1, 2, 3…).
# Arguments:
# - options: <String> Pipe-separated option keys
# - labels:  <String> key=description pairs separated by |
nds_cfg_print_numbered_choice_options() {
    local options="$1" labels="$2"
    local option pair desc i=1
    local -a pairs
    [[ -n "$labels" ]] || return 0
    IFS='|' read -ra pairs <<< "$labels"
    for option in ${options//|/ }; do
        desc=""
        for pair in "${pairs[@]}"; do
            [[ "${pair%%=*}" == "$option" ]] && { desc="${pair#*=}"; break; }
        done
        nds_ui_choice_row "$i" "$option" "$desc"
        i=$((i + 1))
    done
    nds_ui_b ""
}

# Description: Choice prompt with numbered rows; single-key select (like action menu).
# Arguments:
# - var:     <String> Config variable name
# - options: <String> Pipe-separated option keys
# - labels:  <String> key=description pairs separated by |
# - default: <String|optional> Default option key (Enter accepts when set)
# Description: Prompt for a numbered menu choice and store the selected key.
nds_cfg_ask_numbered_choice() {
    local var="$1" options="$2" labels="${3:-}" default="${4:-}" allow_back="${5:-false}"
    local -a opts=()
    local count=0 digit current resolved prompt

    [[ -n "$default" ]] && [[ -z "$(nds_cfg_get "$var")" ]] && nds_cfg_set "$var" "$default"
    IFS='|' read -ra opts <<< "$options"
    count=${#opts[@]}
    current=$(nds_cfg_get "$var")

    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        resolved="${current:-$default}"
        [[ -n "$resolved" ]] || {
            error "Unattended numbered choice ${var} is empty"
            return 1
        }
        nds_cfg_set "$var" "$resolved"
        return 0
    fi

    [[ -n "$labels" ]] && nds_cfg_print_numbered_choice_options "$options" "$labels"
    prompt="$(nds_ui_numbered_prompt 1 "$count" "$default" "Make your selection" "$allow_back")"

    while true; do
        if digit=$(nds_ui_read_menu_digit "$prompt" 1 "$count" "$allow_back"); then
            if [[ "$allow_back" == "true" && "$digit" == "0" ]]; then
                return "${NDS_ACTION_BACK:-10}"
            fi
            resolved="${opts[$((digit - 1))]}"
            break
        elif [[ -n "$default" ]]; then
            resolved="$default"
            break
        fi
        nds_ui_b "Invalid selection. Choose 1-${count}."
    done

    nds_cfg_set "$var" "$resolved"
    [[ "$current" != "$resolved" ]] && nds_ui_b "  -> Selected: ${resolved}"
    return 0
}

# Description: Print a labelled summary row.
nds_cfg_summary_row() {
    nds_ui_kv_row "$1" "$2"
}

# Description: Print a section heading for a settings group.
nds_cfg_section_title() {
    nds_ui_h "$1:"
    nds_ui_b ""
}

_nds_settings_prompt_value() {
    local var="$1" label="$2" hint="$3" required="${4:-false}"
    local current value

    current=$(nds_cfg_get "$var")
    declare -f _nds_ui_drain_tty &>/dev/null && _nds_ui_drain_tty
    while true; do
        if [[ -n "$hint" ]]; then
            printf "%s%-20s [%s] %s: " "$NDS_UI_INDENT_I" "$label" "$current" "$hint" >&2
        else
            printf "%s%-20s [%s]: " "$NDS_UI_INDENT_I" "$label" "$current" >&2
        fi
        read -r value < /dev/tty
        if [[ -z "$value" ]]; then
            if [[ "$required" == true && -z "$current" ]]; then
                validation_error "$label is required"
                continue
            fi
            return 0
        fi
        printf '%s' "$value"
        return 0
    done
}

# Description: Prompt for a yes/no toggle and store it.
nds_cfg_ask_toggle() {
    local var="$1" label="$2" default="${3:-false}" hint="${4:-(y/n)}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local current value normalized
    current=$(nds_cfg_get "$var")
    declare -f _nds_ui_drain_tty &>/dev/null && _nds_ui_drain_tty
    while true; do
        printf "%s%-20s [%s] %s: " "$NDS_UI_INDENT_I" "$label" "$(nds_cfg_display_toggle "$current")" "$hint" >&2
        read -r value < /dev/tty
        [[ -z "$value" ]] && return 0
        if validate_toggle "$value"; then
            normalized=$(nds_cfg_normalize_toggle "$value")
            if [[ "$current" != "$normalized" ]]; then
                nds_cfg_set "$var" "$normalized"
                nds_ui_b "  -> Updated: $(nds_cfg_display_toggle "$current") -> $(nds_cfg_display_toggle "$normalized")"
            fi
            return 0
        fi
        nds_ui_b "  Error: $(_nds_settings_error_toggle)"
    done
}

# Description: Prompt for a free-form string and store it.
nds_cfg_ask_string() {
    local var="$1" label="$2" default="${3:-}" required="${4:-false}" hint="${5:-}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current
    current=$(nds_cfg_get "$var")
    value=$(_nds_settings_prompt_value "$var" "$label" "$hint" "$required") || return 1
    [[ -z "$value" ]] && return 0
    if [[ "$current" != "$value" ]]; then
        nds_cfg_set "$var" "$value"
        nds_ui_b "  -> Set: $value"
    fi
}

# Description: Prompt for a secret (hidden input) and store it.
nds_cfg_ask_secret() {
    local var="$1" label="$2" minlen="${3:-8}" required="${4:-false}"
    local current value
    current=$(nds_cfg_get "$var")
    declare -f _nds_ui_drain_tty &>/dev/null && _nds_ui_drain_tty
    while true; do
        if [[ -n "$current" ]]; then
            printf "%s%-20s [********]: " "$NDS_UI_INDENT_I" "$label" >&2
        else
            printf "%s%-20s: " "$NDS_UI_INDENT_I" "$label" >&2
        fi
        read -r -s value < /dev/tty
        echo >&2
        if [[ -z "$value" ]]; then
            [[ "$required" == true && -z "$current" ]] && { validation_error "$label is required"; continue; }
            return 0
        fi
        if [[ ${#value} -lt "$minlen" ]]; then
            nds_ui_b "  Error: Must be at least $minlen characters"
            continue
        fi
        nds_cfg_set "$var" "$value"
        nds_ui_b "  -> Set (hidden)"
        return 0
    done
}

# Description: Prompt for an integer and store it.
nds_cfg_ask_int() {
    local var="$1" label="$2" default="$3" min="${4:-}" max="${5:-}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local hint="" value current
    if [[ -n "$min" && -n "$max" ]]; then hint="($min-$max)"
    elif [[ -n "$min" ]]; then hint="(min: $min)"
    elif [[ -n "$max" ]]; then hint="(max: $max)"
    fi
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_settings_prompt_value "$var" "$label" "$hint" false) || continue
        [[ -z "$value" ]] && return 0
        if validate_int "$value" "$min" "$max"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Must be an integer${hint:+ $hint}"
    done
}

# Description: Prompt for a labelled choice and store it.
nds_cfg_ask_choice() {
    local var="$1" label="$2" options="$3" labels="${4:-}" default="${5:-}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local hint="(${options//|/, })" value current display
    current=$(nds_cfg_get "$var")
    while true; do
        [[ -n "$labels" ]] && nds_cfg_print_choice_options "$options" "$labels"
        display=$(nds_cfg_display_choice "$current" "$labels")
        value=$(_nds_settings_prompt_value "$var" "$label" "$hint" false) || continue
        [[ -z "$value" ]] && return 0
        if validate_choice "$value" "$options"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Updated: $display -> $(nds_cfg_display_choice "$value" "$labels")"
            return 0
        fi
        nds_ui_b "  Error: Invalid choice. Options: ${options//|/, }"
    done
}

_nds_settings_ask_validated() {
    local var="$1" label="$2" default="${3:-}" required="${4:-false}" hint="${5:-}" validator="$6" err="$7"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_settings_prompt_value "$var" "$label" "$hint" "$required") || continue
        [[ -z "$value" ]] && return 0
        if "$validator" "$value"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: $err"
    done
}

# Description: Prompt for an IPv4 address and store it.
nds_cfg_ask_ip() {
    _nds_settings_ask_validated "$1" "$2" "${3:-}" "${4:-false}" "(e.g. 192.168.1.1)" validate_ip "Invalid IP address"
}

# Description: Prompt for a hostname and store it.
nds_cfg_ask_hostname() {
    _nds_settings_ask_validated "$1" "$2" "${3:-}" "${4:-true}" "" validate_hostname "$(_nds_settings_error_hostname)"
}

# Description: Prompt for a Unix username and store it.
nds_cfg_ask_username() {
    _nds_settings_ask_validated "$1" "$2" "${3:-admin}" "${4:-true}" "" validate_username "Invalid username"
}

# Description: Prompt for a TCP port and store it.
nds_cfg_ask_port() {
    nds_cfg_ask_int "$1" "$2" "$3" "${4:-1}" "${5:-65535}"
}

# Description: Prompt for a filesystem path and store it.
nds_cfg_ask_path() {
    _nds_settings_ask_validated "$1" "$2" "${3:-}" "${4:-false}" "(absolute path)" validate_path "Path must start with /, ~, or ."
}

# Description: Prompt for a URL and store it.
nds_cfg_ask_url() {
    _nds_settings_ask_validated "$1" "$2" "${3:-}" "${4:-false}" "(https://, ssh://, git@host:owner/repo)" validate_git_url "Invalid URL"
}

# Description: List candidate install disks for the disk picker.
nds_cfg_list_disks() {
    local disks=() disk size
    while IFS= read -r disk; do
        if [[ -b "$disk" && ! "$disk" =~ [0-9]$ && ! "$disk" =~ loop ]]; then
            size=$(lsblk -b -d -o SIZE -n "$disk" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
            disks+=("$disk ($size)")
        fi
    done < <(find /dev -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' 2>/dev/null | sort)
    printf '%s\n' "${disks[@]}"
}

# Description: Prompt for the target disk and store it.
nds_cfg_ask_disk() {
    local var="$1" label="$2" default="${3:-}"
    local first_disk available_disks=() value i current
    first_disk=$(find /dev \( -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' \) 2>/dev/null | sort | head -n1)
    [[ -n "$default" ]] && first_disk="$default"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$first_disk"
    current=$(nds_cfg_get "$var")
    mapfile -t available_disks < <(nds_cfg_list_disks)
    nds_ui_b ""
    nds_ui_b "Available disks:"
    if [[ ${#available_disks[@]} -eq 0 ]]; then
        nds_ui_i "No disks found"
    else
        for i in "${!available_disks[@]}"; do
            nds_ui_i "$((i+1))) ${available_disks[i]}"
        done
    fi
    nds_ui_b ""
    declare -f _nds_ui_drain_tty &>/dev/null && _nds_ui_drain_tty
    while true; do
        printf "%s%-20s [%s]: " "$NDS_UI_INDENT_I" "$label" "$current" >&2
        read -r value < /dev/tty
        [[ -z "$value" ]] && return 0
        if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 1 && value <= ${#available_disks[@]} )); then
            value="${available_disks[$((value-1))]%% *}"
        fi
        if validate_disk "$value"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: '$value' is not a valid block device"
    done
}

# Description: Prompt for a netmask or prefix length and store it.
nds_cfg_ask_mask() {
    local var="$1" label="$2" default="${3:-255.255.255.0}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local current value
    current=$(nds_cfg_get "$var")
    declare -f _nds_ui_drain_tty &>/dev/null && _nds_ui_drain_tty
    while true; do
        printf "%s%-20s [%s] (CIDR or dotted): " "$NDS_UI_INDENT_I" "$label" "$current" >&2
        read -r value < /dev/tty
        [[ -z "$value" ]] && return 0
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            if (( value >= 0 && value <= 32 )); then
                nds_cfg_set "$var" "$(validate_mask_cidr_to_netmask "$value")"
                nds_ui_b "  -> Set: $(nds_cfg_get "$var")"
                return 0
            fi
            nds_ui_b "  Error: CIDR must be 0-32"
            continue
        fi
        if validate_mask "$value"; then
            nds_cfg_set "$var" "$value"
            nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Invalid network mask"
    done
}

# Description: Prompt for a timezone and store it.
nds_cfg_ask_timezone() {
    local var="$1" label="$2" default="${3:-UTC}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local current value matched_tz match_count
    current=$(nds_cfg_get "$var")
    declare -f _nds_ui_drain_tty &>/dev/null && _nds_ui_drain_tty
    while true; do
        printf "%s%-20s [%s] (e.g. Europe/Zurich): " "$NDS_UI_INDENT_I" "$label" "$current" >&2
        read -r value < /dev/tty
        [[ -z "$value" ]] && return 0
        if command -v timedatectl &>/dev/null; then
            if timedatectl list-timezones | grep -qxi "$value"; then
                nds_cfg_set "$var" "$value"
                nds_ui_b "  -> Set: $value"
                return 0
            fi
            match_count=$(timedatectl list-timezones | grep -ci "$value" || echo "0")
            if [[ "$match_count" -eq 1 ]]; then
                matched_tz=$(timedatectl list-timezones | grep -i "$value")
                nds_cfg_set "$var" "$matched_tz"
                nds_ui_b "  -> Auto-matched: $matched_tz"
                return 0
            elif [[ "$match_count" -gt 1 ]]; then
                nds_ui_b "  Multiple matches — be more specific"
                continue
            fi
        elif validate_timezone "$value"; then
            nds_cfg_set "$var" "$value"
            nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Invalid timezone"
    done
}

# Description: Prompt for a locale and store it.
nds_cfg_ask_locale() {
    local var="$1" label="$2" default="${3:-en_US.UTF-8}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current normalized
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_settings_prompt_value "$var" "$label" "(e.g. en_US.UTF-8)" true) || continue
        [[ -z "$value" ]] && return 0
        normalized="${value/.utf8/.UTF-8}"
        if validate_locale "$normalized"; then
            nds_cfg_set "$var" "$normalized"
            [[ "$current" != "$normalized" ]] && nds_ui_b "  -> Set: $normalized"
            return 0
        fi
        nds_ui_b "  Error: Invalid locale"
    done
}

# Description: Prompt for a keyboard layout and store it.
nds_cfg_ask_keyboard() {
    local var="$1" label="$2" default="${3:-us}"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" "$default"
    local value current
    current=$(nds_cfg_get "$var")
    while true; do
        value=$(_nds_settings_prompt_value "$var" "$label" "(us, de, ch)" true) || continue
        [[ -z "$value" ]] && return 0
        value="${value,,}"
        if validate_keyboard "$value"; then
            nds_cfg_set "$var" "$value"
            [[ "$current" != "$value" ]] && nds_ui_b "  -> Set: $value"
            return 0
        fi
        nds_ui_b "  Error: Invalid keyboard layout"
    done
}

# Description: Prompt for a country code and store it.
nds_cfg_ask_country() {
    local var="$1" label="$2"
    [[ -n "$(nds_cfg_get "$var")" ]] || nds_cfg_set "$var" ""
    while true; do
        local value
        value=$(_nds_settings_prompt_value "$var" "$label" "(US, DE, CH — empty = manual)" false) || continue
        [[ -z "$value" ]] && return 0
        value="${value^^}"
        if validate_country "$value"; then
            nds_cfg_set "$var" "$value"
            nds_country_apply "$value" && nds_ui_b "  -> Set: $value (applied region defaults)"
            return 0
        fi
        nds_ui_b "  Error: Unknown country code"
    done
}
