#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings manager sessions, secrets-as-files, and recipes
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-20
# Description:   Isolated SM sessions; validators shared with Part B via nds_sm_validate
# ==================================================================================================

declare -g SM_CURRENT="${SM_CURRENT:-default}"
declare -gA SM_SESSION_IDS=([default]=1)
declare -gA SM_SECRET_KEYS=()

# ==================================================================================================
# Session directory + assoc snapshots
# ==================================================================================================

# Description: Directory for one session's snapshots.
# Arguments:
# - sid: <String> Session id
# Returns:
# - <String> Absolute directory (stdout)
nds_sm_dir() {
    local sid="${1:-${SM_CURRENT}}"
    local root="${NDS_RUNTIME_DIR:-/tmp/nds_sm_${PPID:-$$}}"
    printf '%s/sm/%s\n' "$root" "$sid"
}

# Description: True when sid has a snapshot on disk (survives `sid=$(nds_sm_create)` subshells).
nds_sm_exists() {
    local sid="${1:-}"
    [[ -n "$sid" ]] || return 1
    [[ -n "${SM_SESSION_IDS[$sid]:-}" ]] && return 0
    [[ -f "$(nds_sm_dir "$sid")/store.bash" ]]
}

_nds_sm_declare_p_global() {
    local name="$1"
    local blob
    blob="$(declare -p "$name" 2>/dev/null || printf 'declare -A %s=()\n' "$name")"
    blob="${blob/declare -A/declare -gA}"
    blob="${blob/declare -a/declare -ga}"
    printf '%s\n' "$blob"
}

# Description: Snapshot live CONFIG_DATA / presets into sid's directory.
# Arguments:
# - sid: <String> Session id (default: current)
nds_sm_save() {
    local sid="${1:-${SM_CURRENT}}"
    local dir
    dir="$(nds_sm_dir "$sid")"
    mkdir -p "$dir" || return 1
    {
        _nds_sm_declare_p_global CONFIG_DATA
        _nds_sm_declare_p_global CONFIG_DEFAULTS
        _nds_sm_declare_p_global PRESET_REGISTRY
        _nds_sm_declare_p_global PRESET_META
        _nds_sm_declare_p_global PRESET_SEEDED
    } >"${dir}/store.bash"
    SM_SESSION_IDS["$sid"]=1
    return 0
}

# Description: Restore a session snapshot into the live store.
# Arguments:
# - sid: <String> Session id
nds_sm_restore() {
    local sid="${1:?session id}"
    local dir file
    dir="$(nds_sm_dir "$sid")"
    file="${dir}/store.bash"
    [[ -f "$file" ]] || {
        echo "Error: settings session '${sid}' has no snapshot" >&2
        return 1
    }
    unset CONFIG_DATA CONFIG_DEFAULTS
    declare -gA CONFIG_DATA=()
    declare -gA CONFIG_DEFAULTS=()
    # shellcheck disable=SC1090
    source "$file"
    SM_CURRENT="$sid"
    SM_SESSION_IDS["$sid"]=1
    return 0
}

# Description: Switch the live store to sid (saves the previous session first).
# Arguments:
# - sid: <String> Session id
nds_sm_use() {
    local sid="${1:?session id}"
    local prev="${SM_CURRENT}"
    [[ "$sid" == "$prev" ]] && return 0
    nds_sm_exists "$sid" || {
        echo "Error: unknown settings session '${sid}'" >&2
        return 1
    }
    nds_sm_save "$prev" || return 1
    nds_sm_restore "$sid"
}

# Description: Run a command with sid as the live store, then restore previous.
# Arguments:
# - sid:  <String> Session id
# - args: command + arguments
nds_sm_with() {
    local sid="${1:?session id}"
    shift
    local prev="${SM_CURRENT}" rc=0
    nds_sm_use "$sid" || return 1
    "$@"
    rc=$?
    nds_sm_use "$prev" || return 1
    return "$rc"
}

# Description: Clear the live store and disable every cataloged preset.
_nds_sm_reset_live() {
    CONFIG_DATA=()
    CONFIG_DEFAULTS=()
    PRESET_SEEDED=()
    local name
    for name in "${!PRESET_REGISTRY[@]}"; do
        nds_cfg_preset_disable "$name"
    done
}

# Description: Create an isolated session, enable builtins, load extra presets, seed.
# Prints the session id on stdout. Does not show a menu.
# Arguments:
# - --name ID:     <String> Optional session id
# - --builtin IDS: <String> Comma/space-separated builtin preset ids
# - --extra PATH:  <String> Extra preset file or directory (repeatable)
nds_sm_create() {
    local name="" builtins="" extra
    local -a extras=()
    local -a bundle=()
    local token sid prev

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                name="${2:?--name needs an id}"
                shift 2
                ;;
            --builtin|--builtins)
                builtins="${2:?--builtin needs preset ids}"
                shift 2
                ;;
            --extra)
                extras+=("${2:?--extra needs a path}")
                shift 2
                ;;
            *)
                echo "Error: nds_sm_create: unknown argument '$1'" >&2
                return 1
                ;;
        esac
    done

    prev="${SM_CURRENT}"
    nds_sm_save "$prev" || return 1

    if [[ -z "$name" ]]; then
        name="s${RANDOM}${RANDOM}"
    fi
    sid="$name"
    SM_SESSION_IDS["$sid"]=1
    SM_CURRENT="$sid"
    _nds_sm_reset_live

    if [[ -n "$builtins" ]]; then
        builtins="${builtins//,/ }"
        # shellcheck disable=SC2206
        bundle=($builtins)
        nds_preset_enable_bundle "${SCRIPT_DIR:?SCRIPT_DIR unset}" "${bundle[@]}" || return 1
    fi

    for extra in "${extras[@]}"; do
        [[ -n "$extra" ]] || continue
        if [[ -d "$extra" ]]; then
            nds_preset_load_dir "$extra" || return 1
        elif [[ -f "$extra" ]]; then
            nds_preset_load_file "$extra" || return 1
            nds_cfg_preset_enable "$(basename "$extra" .sh)"
        else
            echo "Error: nds_sm_create: extra preset not found: $extra" >&2
            return 1
        fi
    done

    nds_cfg_seed_defaults
    nds_sm_save "$sid" || return 1
    printf '%s\n' "$sid"
    return 0
}

# ==================================================================================================
# Secrets as files (never values in recipes or git)
# ==================================================================================================

# Description: Mark a store key as secret. Export writes KEY_FILE, never KEY.
# Arguments:
# - key: <String> CONFIG_DATA key (e.g. ACCESS_ADMIN_PASSWORD)
nds_sm_secret_register() {
    local key="${1:?secret key}"
    SM_SECRET_KEYS["$key"]=1
}

# Description: True when key is a registered secret value (not a *_FILE path).
nds_sm_secret_is() {
    [[ -n "${SM_SECRET_KEYS[${1:-}]:-}" ]]
}

# Description: Runtime directory for secret files (0700).
# Returns:
# - <String> Absolute path (stdout)
nds_sm_secrets_dir() {
    local dir
    dir="${NDS_SECRETS_DIR:-}"
    if [[ -z "$dir" ]]; then
        dir="${NDS_RUNTIME_DIR:-/tmp/nds_sm_${PPID:-$$}}/secrets"
    fi
    mkdir -p "$dir"
    chmod 700 "$dir" 2>/dev/null || true
    printf '%s\n' "$dir"
}

# Description: Write a secret value to a 0600 file; return the path.
# Arguments:
# - key:   <String> Store key (used as filename)
# - value: <String> Secret material
# Returns:
# - <String> Absolute file path (stdout)
nds_sm_secret_write() {
    local key="${1:?key}" value="${2:?}"
    local dest
    dest="$(nds_sm_secrets_dir)/${key}"
    printf '%s' "$value" >"$dest" || return 1
    chmod 600 "$dest"
    printf '%s\n' "$dest"
}

# Description: Move in-memory secret values into files and point KEY_FILE at them.
nds_sm_materialize_secrets() {
    local key val file_key path
    for key in "${!SM_SECRET_KEYS[@]}"; do
        val="$(nds_cfg_get "$key")"
        file_key="${key}_FILE"
        if [[ -n "$val" ]]; then
            path="$(nds_sm_secret_write "$key" "$val")" || return 1
            nds_cfg_set "$file_key" "$path"
            nds_cfg_set "$key" ""
        fi
    done
    return 0
}

# Description: Read a secret from KEY_FILE, else in-memory KEY (legacy).
# Arguments:
# - key: <String> Secret store key
# Returns:
# - <String> Secret value (stdout); empty when missing
nds_sm_secret_read() {
    local key="${1:?key}"
    local file val
    file="$(nds_cfg_get "${key}_FILE")"
    if [[ -n "$file" && -f "$file" ]]; then
        cat "$file"
        return 0
    fi
    val="$(nds_cfg_get "$key")"
    printf '%s' "$val"
}

nds_sm_secret_register ACCESS_ADMIN_PASSWORD
nds_sm_secret_register ENCRYPTION_PASSPHRASE
nds_sm_secret_register TOOLKIT_AGE_KEY
nds_sm_secret_register TOOLKIT_SSH_KEY

# ==================================================================================================
# Validate / menu / get (shared by settingsManager UI and Part B)
# ==================================================================================================

# Description: Validate enabled presets (or named list) on the current or given session.
# Same validators the settings menu uses — Part B must call this before apply.
# Arguments:
# - sid?:    <String> Session id (optional; default current)
# - presets: <String...> Optional preset ids (default: all enabled)
nds_sm_validate() {
    local sid=""
    if [[ $# -gt 0 ]] && nds_sm_exists "$1"; then
        sid="$1"
        shift
    fi
    if [[ -n "$sid" && "$sid" != "$SM_CURRENT" ]]; then
        nds_sm_with "$sid" nds_cfg_validate_all "$@"
        return $?
    fi
    nds_cfg_validate_all "$@"
}

# Description: Alias for nds_sm_validate (Part B / session API).
nds_sm_prevalidate() {
    nds_sm_validate "$@"
}

# Description: Show the settings category menu (or skip when unattended).
# Arguments:
# - sid?:    <String> Session id (optional)
# - presets: <String...> Optional preset filter
nds_sm_menu() {
    local sid=""
    if [[ $# -gt 0 ]] && nds_sm_exists "$1"; then
        sid="$1"
        shift
    fi
    if [[ -n "$sid" && "$sid" != "$SM_CURRENT" ]]; then
        nds_sm_with "$sid" nds_cfg_menu_or_skip "$@"
        return $?
    fi
    nds_cfg_menu_or_skip "$@"
}

# Description: Read a key from the current or given session.
# Arguments:
# - sid?: <String> Session id when it matches a known session and a key follows
# - key:  <String> Store key
# - def?: <String> Default
nds_sm_get() {
    if [[ $# -ge 2 ]] && nds_sm_exists "$1"; then
        nds_sm_with "$1" nds_cfg_get "$2" "${3:-}"
        return $?
    fi
    nds_cfg_get "$@"
}

# Description: Write a key on the current or given session.
nds_sm_set() {
    if [[ $# -ge 3 ]] && nds_sm_exists "$1"; then
        nds_sm_with "$1" nds_cfg_set "$2" "$3"
        return $?
    fi
    nds_cfg_set "$1" "$2"
}

# Description: Print KEY=value lines for the live store (no secret values).
nds_sm_get_options() {
    local key
    nds_sm_materialize_secrets || true
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        nds_sm_secret_is "$key" && continue
        printf '%s=%s\n' "$key" "$(nds_cfg_get "$key")"
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)
}

# ==================================================================================================
# Recipe load / export (sectioned + legacy export NDS_*=)
# ==================================================================================================

_nds_sm_section_for_key() {
    local key="$1"
    case "$key" in
        INSTALL_KIND|INSTALL_MODE|INSTALL_COMPOSER) printf 'meta' ;;
        DISK_*) printf 'disk' ;;
        BOOT_*) printf 'boot' ;;
        ENCRYPTION_*) printf 'encryption' ;;
        NETWORK_*) printf 'network' ;;
        ACCESS_*) printf 'access' ;;
        REGION_*) printf 'region' ;;
        FLAKE_*|SCAFFOLD_*|GIT_*) printf 'flake' ;;
        CAST_*|TOOLKIT_*) printf 'custom.toolkit' ;;
        PLATFORM_*) printf 'platform' ;;
        QUICK_*) printf 'quick' ;;
        *_FILE) printf 'secrets' ;;
        *) printf 'misc' ;;
    esac
}

_nds_sm_meta_store_key() {
    case "$1" in
        kind) printf 'INSTALL_KIND' ;;
        target) printf 'INSTALL_MODE' ;;
        action) printf 'INSTALL_COMPOSER' ;;
        *) printf '%s' "$1" ;;
    esac
}

_nds_sm_recipe_set_line() {
    local section="$1" raw="$2" key val
    raw="${raw#"${raw%%[![:space:]]*}"}"
    [[ -z "$raw" || "$raw" == \#* ]] && return 0
    if [[ "$raw" == export\ NDS_* ]]; then
        key="${raw#export NDS_}"
        key="${key%%=*}"
        val="${raw#export NDS_${key}=}"
        val="${val#\"}"
        val="${val%\"}"
        nds_sm_secret_is "$key" && return 0
        nds_cfg_set "$key" "$val"
        return 0
    fi
    [[ "$raw" == *=* ]] || return 0
    key="${raw%%=*}"
    val="${raw#*=}"
    val="${val#\"}"
    val="${val%\"}"
    key="${key%"${key##*[![:space:]]}"}"
    key="${key#"${key%%[![:space:]]*}"}"
    if [[ "$section" == "meta" ]]; then
        key="$(_nds_sm_meta_store_key "$key")"
    fi
    nds_sm_secret_is "$key" && return 0
    nds_cfg_set "$key" "$val"
}

# Description: Load a recipe file into the current (or given) session.
# Accepts sectioned tc-recipe files and legacy `export NDS_*=` recipes.
# Secret VALUES are ignored; *_FILE paths are kept.
# Arguments:
# - sid?: <String> Session id (optional)
# - file: <String> Recipe path
nds_sm_load() {
    local sid="" file section="misc" line
    if [[ $# -ge 2 ]] && nds_sm_exists "$1"; then
        sid="$1"
        file="$2"
        nds_sm_with "$sid" nds_sm_load "$file"
        return $?
    fi
    file="${1:?recipe file}"
    [[ -f "$file" ]] || {
        echo "Error: recipe not found: $file" >&2
        return 1
    }
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        if [[ "$line" =~ ^\[([^]]+)\][[:space:]]*$ ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi
        _nds_sm_recipe_set_line "$section" "$line"
    done <"$file"
    nds_cfg_sync_derived_flake
    return 0
}

_nds_sm_export_body() {
    local mode="$1"
    local key val section
    local -A buckets=()
    local -a order=(meta disk boot encryption network access region flake platform quick custom.toolkit secrets misc)

    nds_sm_materialize_secrets || true

    printf '# tc-recipe v1\n'
    printf '# No secret values — secrets are *_FILE paths only.\n'

    for key in "${!CONFIG_DATA[@]}"; do
        nds_sm_secret_is "$key" && continue
        if [[ "$mode" == git ]]; then
            case "$key" in
                DISK_TARGET|REMOTE_TARGET_IP|ACCESS_ADMIN_PASSWORD|ENCRYPTION_PASSPHRASE) continue ;;
            esac
        fi
        val="$(nds_cfg_get "$key")"
        [[ -n "$val" ]] || continue
        section="$(_nds_sm_section_for_key "$key")"
        buckets["$section"]+="${key}"$'\t'"${val}"$'\n'
    done

    if [[ -n "$(nds_cfg_get INSTALL_KIND)" || -n "$(nds_cfg_get INSTALL_MODE)" ]]; then
        printf '\n[meta]\n'
        [[ -n "$(nds_cfg_get INSTALL_KIND)" ]] && printf 'kind=%s\n' "$(nds_cfg_get INSTALL_KIND)"
        [[ -n "$(nds_cfg_get INSTALL_MODE)" ]] && printf 'target=%s\n' "$(nds_cfg_get INSTALL_MODE)"
        [[ -n "$(nds_cfg_get INSTALL_COMPOSER)" ]] && printf 'action=%s\n' "$(nds_cfg_get INSTALL_COMPOSER)"
    fi

    for section in "${order[@]}"; do
        [[ "$section" == meta ]] && continue
        [[ -n "${buckets[$section]:-}" ]] || continue
        printf '\n[%s]\n' "$section"
        while IFS=$'\t' read -r key val; do
            [[ -n "$key" ]] || continue
            val="${val//\\/\\\\}"
            val="${val//\"/\\\"}"
            printf '%s="%s"\n' "$key" "$val"
        done <<<"${buckets[$section]}"
    done
}

# Description: Export the live (or given) session as a sectioned recipe.
# Arguments:
# - sid?:   <String> Session id (optional)
# - --git:  portable leaf recipe (no disk device / secret files still as paths)
# - path?:  Write to this file instead of stdout
nds_sm_export() {
    local sid="" mode="recipe" dest=""
    if [[ $# -gt 0 ]] && nds_sm_exists "$1"; then
        sid="$1"
        shift
    fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --git) mode="git"; shift ;;
            --recipe) mode="recipe"; shift ;;
            *) dest="$1"; shift ;;
        esac
    done
    if [[ -n "$sid" && "$sid" != "$SM_CURRENT" ]]; then
        if [[ -n "$dest" ]]; then
            nds_sm_with "$sid" nds_sm_export "--${mode}" "$dest"
        else
            nds_sm_with "$sid" nds_sm_export "--${mode}"
        fi
        return $?
    fi
    if [[ -n "$dest" ]]; then
        _nds_sm_export_body "$mode" >"$dest"
        return $?
    fi
    _nds_sm_export_body "$mode"
}
