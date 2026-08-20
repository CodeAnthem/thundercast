# ==================================================================================================
# Thundercast - public toolkit register (git-safe: pubs + timestamps only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-20
# Description:   KEY=value files under .nds/toolkit-register/ — never private keys
# ==================================================================================================

tcast_register_ensure() {
    local d
    d="$(tcast_register_dir)"
    mkdir -p "${d}/hosts" "${d}/scopes"
    [[ -f "${d}/meta" ]] || printf 'version=1\n' > "${d}/meta"
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

tcast_register_meta_get() {
    tcast_kv_get "$(tcast_register_dir)/meta" "$1"
}

tcast_register_meta_set() {
    tcast_register_ensure
    tcast_kv_set "$(tcast_register_dir)/meta" "$1" "$2"
}

tcast_register_host_file() {
    printf '%s/hosts/%s\n' "$(tcast_register_dir)" "$1"
}

tcast_register_host_get() {
    tcast_kv_get "$(tcast_register_host_file "$1")" "$2"
}

tcast_register_host_set() {
    local host="$1" key="$2" value="$3"
    tcast_register_ensure
    tcast_kv_set "$(tcast_register_host_file "$host")" "$key" "$value"
}

tcast_register_host_list() {
    local d
    d="$(tcast_register_dir)/hosts"
    [[ -d "$d" ]] || return 0
    find "$d" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort
}

tcast_register_scope_file() {
    printf '%s/scopes/%s\n' "$(tcast_register_dir)" "$1"
}

tcast_register_scope_list() {
    local d
    d="$(tcast_register_dir)/scopes"
    [[ -d "$d" ]] || return 0
    find "$d" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort
}

tcast_register_scope_get() {
    tcast_kv_get "$(tcast_register_scope_file "$1")" "$2"
}

tcast_register_scope_set() {
    tcast_register_ensure
    tcast_kv_set "$(tcast_register_scope_file "$1")" "$2" "$3"
}

tcast_register_scope_members() {
    local raw
    raw="$(tcast_register_scope_get "$1" members 2>/dev/null || true)"
    printf '%s\n' "${raw}" | tr ',' '\n' | sed '/^$/d'
}

# Description: Add token to comma members (hostname, operator, or age1…).
tcast_register_scope_add_member() {
    local id="$1" token="$2" members m
    members="$(tcast_register_scope_get "$id" members 2>/dev/null || true)"
    IFS=',' read -ra m <<< "$members"
    for x in "${m[@]:-}"; do
        [[ "$x" == "$token" ]] && return 0
    done
    if [[ -z "$members" ]]; then
        tcast_register_scope_set "$id" members "$token"
    else
        tcast_register_scope_set "$id" members "${members},${token}"
    fi
}

tcast_register_scope_remove_member() {
    local id="$1" token="$2" out="" x
    while IFS= read -r x; do
        [[ -z "$x" || "$x" == "$token" ]] && continue
        if [[ -z "$out" ]]; then
            out="$x"
        else
            out="${out},${x}"
        fi
    done < <(tcast_register_scope_members "$id")
    tcast_register_scope_set "$id" members "$out"
}

tcast_register_ensure_defaults() {
    tcast_register_ensure
    if [[ ! -f "$(tcast_register_scope_file operator)" ]]; then
        tcast_register_scope_set operator path "secrets/operator.yaml"
        tcast_register_scope_set operator path_regex 'secrets/operator\.yaml$'
        tcast_register_scope_set operator type operator
        tcast_register_scope_set operator members operator
    fi
    if [[ ! -f "$(tcast_register_scope_file host)" ]]; then
        tcast_register_scope_set host path_template "secrets/hosts/%s.yaml"
        tcast_register_scope_set host path_regex 'secrets/hosts/.*\.yaml$'
        tcast_register_scope_set host type host
        tcast_register_scope_set host members operator
    fi
    if [[ ! -f "$(tcast_register_scope_file luks)" ]]; then
        tcast_register_scope_set luks path "secrets/luks.yaml"
        tcast_register_scope_set luks path_regex 'secrets/luks\.yaml$'
        tcast_register_scope_set luks type group
        tcast_register_scope_set luks members operator
    fi
}

# Description: Defaults only. Operator pub is written by Init, not by copying
# .nds/operator.age.pub (that unlocked Sops without initialized_at).
tcast_register_import_leaf() {
    tcast_register_ensure_defaults
}
