#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - public toolkit state (git-safe: pubs + timestamps only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-28
# Description:   .toolkit/operator + machines/<host>/ + sops/secrets.map
# ==================================================================================================

tcast_operator_dir() {
    printf '%s/operator\n' "$(tcast_register_dir)"
}

tcast_machines_dir() {
    printf '%s/machines\n' "$(tcast_register_dir)"
}

tcast_sops_map_file() {
    printf '%s/sops/secrets.map\n' "$(tcast_register_dir)"
}

tcast_kv_get() {
    local file="$1" key="$2" line
    [[ -f "$file" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == "${key}="* ]] || continue
        printf '%s\n' "${line#${key}=}"
        return 0
    done < "$file"
    return 1
}

tcast_kv_set() {
    local file="$1" key="$2" value="$3" tmp line found=0
    mkdir -p "$(dirname "$file")"
    tmp="$(mktemp)"
    if [[ -f "$file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "${key}="* ]]; then
                printf '%s=%s\n' "$key" "$value"
                found=1
            else
                printf '%s\n' "$line"
            fi
        done < "$file" > "$tmp"
    fi
    [[ "$found" == 1 ]] || printf '%s=%s\n' "$key" "$value" >> "$tmp"
    mv "$tmp" "$file"
}

tcast_register_ensure() {
    local d
    d="$(tcast_register_dir)"
    mkdir -p "$(tcast_operator_dir)" "$(tcast_machines_dir)" "${d}/sops" || return 1
    [[ -f "$(tcast_operator_dir)/meta" ]] || printf 'version=1\n' > "$(tcast_operator_dir)/meta"
}

tcast_register_meta_get() {
    local key="$1"
    if [[ "$key" == "operator_age_pub" && -f "$(tcast_operator_dir)/age.pub" ]]; then
        tr -d '[:space:]' < "$(tcast_operator_dir)/age.pub"
        return 0
    fi
    tcast_kv_get "$(tcast_operator_dir)/meta" "$key"
}

tcast_register_meta_set() {
    tcast_register_ensure
    if [[ "$1" == "operator_age_pub" ]]; then
        printf '%s\n' "$2" > "$(tcast_operator_dir)/age.pub"
        tcast_kv_set "$(tcast_operator_dir)/meta" operator_age_pub "$2"
        return 0
    fi
    tcast_kv_set "$(tcast_operator_dir)/meta" "$1" "$2"
}

tcast_register_host_dir() {
    printf '%s/%s\n' "$(tcast_machines_dir)" "$1"
}

tcast_register_host_get() {
    local host="$1" key="$2" dir f
    dir="$(tcast_register_host_dir "$host")"
    case "$key" in
        age_pub) f="${dir}/age.pub" ;;
        *) f="${dir}/${key}" ;;
    esac
    [[ -f "$f" ]] || return 1
    tr -d '\n' < "$f"
    printf '\n'
}

tcast_register_host_set() {
    local host="$1" key="$2" value="$3" dir f
    tcast_register_ensure
    dir="$(tcast_register_host_dir "$host")"
    mkdir -p "$dir"
    case "$key" in
        age_pub) f="${dir}/age.pub" ;;
        *) f="${dir}/${key}" ;;
    esac
    printf '%s\n' "$value" > "$f"
}

tcast_register_host_list() {
    local d
    d="$(tcast_machines_dir)"
    [[ -d "$d" ]] || return 0
    find "$d" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

tcast_sops_map_default() {
    cat <<'EOF'
# Toolkit regenerates .sops.yaml from this map + machines/*/age.pub.
# Do not list age recipients here. Columns: id  path
# A path with %s is per-host (secrets/hosts/<hostname>.yaml).
operator          secrets/operator.yaml
host              secrets/hosts/%s.yaml
luks              secrets/luks.yaml
swarm_manager     secrets/swarm/manager.yaml
swarm_worker      secrets/swarm/worker.yaml
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
        id="${line%%[[:space:]]*}"
        [[ -n "$id" ]] && printf '%s\n' "$id"
    done < "$(tcast_sops_map_file)"
}

tcast_register_scope_path_raw() {
    local want="$1" line id path
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == \#* || -z "${line//[[:space:]]/}" ]] && continue
        id="${line%%[[:space:]]*}"
        path="${line#"$id"}"
        path="${path#"${path%%[![:space:]]*}"}"
        if [[ "$id" == "$want" ]]; then
            printf '%s\n' "$path"
            return 0
        fi
    done < "$(tcast_sops_map_file)"
    return 1
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

tcast_register_scope_set() {
    return 0
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
                [[ -f "$(tcast_register_host_dir "$host")/age.pub" ]] && printf '%s\n' "$host"
            done < <(tcast_register_host_list)
            ;;
        *)
            printf '%s\n' operator
            while IFS= read -r host; do
                [[ -n "$host" ]] || continue
                groups="$(cat "$(tcast_register_host_dir "$host")/groups" 2>/dev/null || true)"
                printf '%s\n' "$groups" | grep -qx "$id" && printf '%s\n' "$host"
            done < <(tcast_register_host_list)
            ;;
    esac
}

tcast_register_scope_add_member() {
    local id="$1" token="$2" f
    [[ "$token" == "operator" ]] && return 0
    tcast_register_ensure
    mkdir -p "$(tcast_register_host_dir "$token")"
    if [[ "$(tcast_register_scope_get "$id" type 2>/dev/null || true)" == "host" ]]; then
        return 0
    fi
    f="$(tcast_register_host_dir "$token")/groups"
    grep -qx "$id" "$f" 2>/dev/null && return 0
    printf '%s\n' "$id" >> "$f"
}

tcast_register_scope_remove_member() {
    local id="$1" token="$2" f tmp
    f="$(tcast_register_host_dir "$token")/groups"
    [[ -f "$f" ]] || return 0
    tmp="$(mktemp)"
    grep -vx "$id" "$f" > "$tmp" || true
    mv "$tmp" "$f"
}

tcast_register_import_leaf() {
    tcast_register_ensure_defaults
}
