#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - public toolkit state (git-safe: pubs + timestamps only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-28
# Description:   Shared .toolkit config/state; per-machine keys + config
# ==================================================================================================

# Layout (all toolkit VMs share this git tree):
#   config                    cluster data (version=1)
#   state                     cluster state (initialized_at, last_enrolled_*)
#   operator/keys/age.pub     cluster operator age pub
#   operator/keys/ssh.pub     cluster operator SSH pub
#   machines/<host>/keys/     that machine's pubs (age.pub)
#   machines/<host>/config    role, system, groups (comma-separated)
#   sops/secrets.map          id=path (%s = hostname)

tcast_operator_dir() {
    printf '%s/operator\n' "$(tcast_register_dir)"
}

tcast_operator_keys_dir() {
    printf '%s/keys\n' "$(tcast_operator_dir)"
}

tcast_machines_dir() {
    printf '%s/machines\n' "$(tcast_register_dir)"
}

tcast_cluster_config_file() {
    printf '%s/config\n' "$(tcast_register_dir)"
}

tcast_cluster_state_file() {
    printf '%s/state\n' "$(tcast_register_dir)"
}

tcast_sops_map_file() {
    printf '%s/sops/secrets.map\n' "$(tcast_register_dir)"
}

tcast_register_host_dir() {
    printf '%s/%s\n' "$(tcast_machines_dir)" "$1"
}

tcast_register_host_keys_dir() {
    printf '%s/keys\n' "$(tcast_register_host_dir "$1")"
}

tcast_register_host_config_file() {
    printf '%s/config\n' "$(tcast_register_host_dir "$1")"
}

# Description: Decode a kv value (optional surrounding double quotes).
tcast_kv_decode() {
    local v="$1"
    if [[ "$v" == \"*\" ]]; then
        v="${v#\"}"
        v="${v%\"}"
        v="${v//\\\"/\"}"
    fi
    printf '%s\n' "$v"
}

# Description: Encode a kv value. Quote when it contains space, =, #, or ".
tcast_kv_encode() {
    local v="$1"
    if [[ "$v" == *[=\#\"[:space:]]* ]]; then
        v="${v//\"/\\\"}"
        printf '"%s"' "$v"
    else
        printf '%s' "$v"
    fi
}

tcast_kv_get() {
    local file="$1" key="$2" line k v
    [[ -f "$file" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == \#* || -z "${line//[[:space:]]/}" ]] && continue
        [[ "$line" == *=* ]] || continue
        k="${line%%=*}"
        v="${line#*=}"
        [[ "$k" == "$key" ]] || continue
        tcast_kv_decode "$v"
        return 0
    done < "$file"
    return 1
}

tcast_kv_set() {
    local file="$1" key="$2" value="$3" tmp line k found=0 enc
    mkdir -p "$(dirname "$file")"
    enc="$(tcast_kv_encode "$value")"
    tmp="$(mktemp)"
    if [[ -f "$file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == *=* ]]; then
                k="${line%%=*}"
                if [[ "$k" == "$key" ]]; then
                    printf '%s=%s\n' "$key" "$enc"
                    found=1
                    continue
                fi
            fi
            printf '%s\n' "$line"
        done < "$file" > "$tmp"
    fi
    [[ "$found" == 1 ]] || printf '%s=%s\n' "$key" "$enc" >> "$tmp"
    mv "$tmp" "$file"
}

tcast_csv_has() {
    local csv="$1" want="$2" item
    [[ -n "$want" ]] || return 1
    IFS=',' read -ra _tcast_csv_items <<< "$csv"
    for item in "${_tcast_csv_items[@]}"; do
        [[ "$item" == "$want" ]] && return 0
    done
    return 1
}

tcast_csv_add() {
    local csv="$1" want="$2"
    tcast_csv_has "$csv" "$want" && { printf '%s\n' "$csv"; return 0; }
    if [[ -z "$csv" ]]; then
        printf '%s\n' "$want"
    else
        printf '%s,%s\n' "$csv" "$want"
    fi
}

tcast_csv_remove() {
    local csv="$1" want="$2" item out=""
    IFS=',' read -ra _tcast_csv_items <<< "$csv"
    for item in "${_tcast_csv_items[@]}"; do
        [[ "$item" == "$want" || -z "$item" ]] && continue
        if [[ -z "$out" ]]; then
            out="$item"
        else
            out="${out},${item}"
        fi
    done
    printf '%s\n' "$out"
}

tcast_register_ensure() {
    local d
    d="$(tcast_register_dir)"
    mkdir -p "$(tcast_operator_keys_dir)" "$(tcast_machines_dir)" "${d}/sops" || return 1
    [[ -f "$(tcast_cluster_config_file)" ]] || printf 'version=1\n' > "$(tcast_cluster_config_file)"
}

tcast_register_meta_get() {
    local key="$1"
    case "$key" in
        operator_age_pub)
            [[ -f "$(tcast_operator_keys_dir)/age.pub" ]] || return 1
            tr -d '[:space:]' < "$(tcast_operator_keys_dir)/age.pub"
            printf '\n'
            ;;
        version)
            tcast_kv_get "$(tcast_cluster_config_file)" version
            ;;
        *)
            tcast_kv_get "$(tcast_cluster_state_file)" "$key"
            ;;
    esac
}

tcast_register_meta_set() {
    tcast_register_ensure
    case "$1" in
        operator_age_pub)
            mkdir -p "$(tcast_operator_keys_dir)"
            printf '%s\n' "$2" > "$(tcast_operator_keys_dir)/age.pub"
            ;;
        version)
            tcast_kv_set "$(tcast_cluster_config_file)" version "$2"
            ;;
        *)
            tcast_kv_set "$(tcast_cluster_state_file)" "$1" "$2"
            ;;
    esac
}

tcast_register_host_get() {
    local host="$1" key="$2" f
    case "$key" in
        age_pub)
            f="$(tcast_register_host_keys_dir "$host")/age.pub"
            [[ -f "$f" ]] || return 1
            tr -d '[:space:]' < "$f"
            printf '\n'
            ;;
        *)
            tcast_kv_get "$(tcast_register_host_config_file "$host")" "$key"
            ;;
    esac
}

tcast_register_host_set() {
    local host="$1" key="$2" value="$3"
    tcast_register_ensure
    mkdir -p "$(tcast_register_host_keys_dir "$host")"
    case "$key" in
        age_pub)
            printf '%s\n' "$value" > "$(tcast_register_host_keys_dir "$host")/age.pub"
            ;;
        *)
            tcast_kv_set "$(tcast_register_host_config_file "$host")" "$key" "$value"
            ;;
    esac
}

tcast_register_host_list() {
    local d
    d="$(tcast_machines_dir)"
    [[ -d "$d" ]] || return 0
    find "$d" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

tcast_sops_map_default() {
    cat <<'EOF'
# id=path  (%s = hostname). Recipients come from pubs, not this file.
operator=secrets/operator.yaml
host=secrets/hosts/%s.yaml
luks=secrets/luks.yaml
swarm_manager=secrets/swarm/manager.yaml
swarm_worker=secrets/swarm/worker.yaml
EOF
}

tcast_register_ensure_defaults() {
    tcast_register_ensure
    if [[ ! -f "$(tcast_sops_map_file)" ]]; then
        tcast_sops_map_default > "$(tcast_sops_map_file)"
    fi
}

tcast_register_scope_list() {
    local line id
    tcast_register_ensure_defaults
    [[ -f "$(tcast_sops_map_file)" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == \#* || -z "${line//[[:space:]]/}" ]] && continue
        [[ "$line" == *=* ]] || continue
        id="${line%%=*}"
        [[ -n "$id" ]] && printf '%s\n' "$id"
    done < "$(tcast_sops_map_file)"
}

tcast_register_scope_path_raw() {
    local want="$1"
    tcast_kv_get "$(tcast_sops_map_file)" "$want"
}

tcast_register_scope_get() {
    local id="$1" key="$2" path pre suf out m
    path="$(tcast_register_scope_path_raw "$id" 2>/dev/null || true)"
    case "$key" in
        path)
            [[ "$path" == *%s* ]] && return 1
            printf '%s\n' "$path"
            ;;
        path_template)
            [[ "$path" == *%s* ]] || return 1
            printf '%s\n' "$path"
            ;;
        path_regex)
            if [[ "$path" == *%s* ]]; then
                pre="${path%%\%s*}"
                suf="${path#*%s}"
                pre="$(printf '%s' "$pre" | sed 's/\./\\./g')"
                suf="$(printf '%s' "$suf" | sed 's/\./\\./g')"
                printf '%s.*%s$\n' "$pre" "$suf"
            else
                printf '%s\n' "$(printf '%s' "$path" | sed 's/\./\\./g')\$"
            fi
            ;;
        type)
            if [[ "$id" == "operator" ]]; then
                printf '%s\n' operator
            elif [[ "$path" == *%s* ]]; then
                printf '%s\n' host
            else
                printf '%s\n' group
            fi
            ;;
        members)
            out=""
            while IFS= read -r m; do
                [[ -z "$m" ]] && continue
                if [[ -z "$out" ]]; then
                    out="$m"
                else
                    out="${out},${m}"
                fi
            done < <(tcast_register_scope_members "$id")
            printf '%s\n' "$out"
            ;;
        *)
            return 1
            ;;
    esac
}

tcast_register_scope_members() {
    local id="$1" host groups
    case "$(tcast_register_scope_get "$id" type 2>/dev/null || echo group)" in
        operator)
            printf '%s\n' operator
            ;;
        host)
            printf '%s\n' operator
            while IFS= read -r host; do
                [[ -n "$host" ]] || continue
                [[ -f "$(tcast_register_host_keys_dir "$host")/age.pub" ]] && printf '%s\n' "$host"
            done < <(tcast_register_host_list)
            ;;
        *)
            printf '%s\n' operator
            while IFS= read -r host; do
                [[ -n "$host" ]] || continue
                groups="$(tcast_register_host_get "$host" groups 2>/dev/null || true)"
                tcast_csv_has "$groups" "$id" && printf '%s\n' "$host"
            done < <(tcast_register_host_list)
            ;;
    esac
}

tcast_register_scope_add_member() {
    local id="$1" token="$2" groups
    [[ "$token" == "operator" ]] && return 0
    tcast_register_ensure
    mkdir -p "$(tcast_register_host_keys_dir "$token")"
    if [[ "$(tcast_register_scope_get "$id" type 2>/dev/null || true)" == "host" ]]; then
        return 0
    fi
    groups="$(tcast_register_host_get "$token" groups 2>/dev/null || true)"
    tcast_register_host_set "$token" groups "$(tcast_csv_add "$groups" "$id")"
}

tcast_register_scope_remove_member() {
    local id="$1" token="$2" groups
    groups="$(tcast_register_host_get "$token" groups 2>/dev/null || true)"
    tcast_register_host_set "$token" groups "$(tcast_csv_remove "$groups" "$id")"
}

tcast_register_import_leaf() {
    tcast_register_ensure_defaults
}
