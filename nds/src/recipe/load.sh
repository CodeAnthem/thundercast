#!/usr/bin/env bash
# ==================================================================================================
# NDS - Recipe load
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Load a recipe file or NDS_<KEY> env into a named array.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_recipe_unescape() {
    local _nds_load_src=$1 _nds_load_out="" _nds_load_i=0 _nds_load_c _nds_load_n
    while (( _nds_load_i < ${#_nds_load_src} )); do
        _nds_load_c=${_nds_load_src:_nds_load_i:1}
        if [[ "$_nds_load_c" == '\' ]]; then
            _nds_load_n=${_nds_load_src:_nds_load_i+1:1}
            if [[ "$_nds_load_n" == '\' || "$_nds_load_n" == '"' ]]; then
                _nds_load_out+=$_nds_load_n
                _nds_load_i=$((_nds_load_i + 2))
                continue
            fi
        fi
        _nds_load_out+=$_nds_load_c
        _nds_load_i=$((_nds_load_i + 1))
    done
    printf '%s' "$_nds_load_out"
}

_nds_recipe_escape() {
    local _nds_load_src=$1
    _nds_load_src=${_nds_load_src//\\/\\\\}
    _nds_load_src=${_nds_load_src//\"/\\\"}
    printf '%s' "$_nds_load_src"
}

_nds_recipe_normBool() {
    case "${1,,}" in
        true|enabled|yes|y|1) printf '%s\n' true ;;
        false|disabled|no|n|0) printf '%s\n' false ;;
        *) printf '%s\n' "$1" ;;
    esac
}

_nds_recipe_le() {
    local _nds_load_raw _nds_load_part _nds_load_out=0 _nds_load_shift=0
    local -a _nds_load_parts=()
    _nds_load_raw=$(od -An -tu1 -N "$3" -j "$2" "$1")
    read -ra _nds_load_parts <<< "$_nds_load_raw"
    for _nds_load_part in "${_nds_load_parts[@]}"; do
        _nds_load_out=$(( _nds_load_out + _nds_load_part * (1 << (8 * _nds_load_shift)) ))
        _nds_load_shift=$((_nds_load_shift + 1))
    done
    printf '%s\n' "$_nds_load_out"
}

_nds_recipe_extractZip() {
    local _nds_load_zip=$1 _nds_load_dest=$2
    if command -v unzip >/dev/null 2>&1; then
        unzip -q -o "$_nds_load_zip" -d "$_nds_load_dest"
        return
    fi
    local _nds_load_size _nds_load_offset=0 _nds_load_sig _nds_load_method
    local _nds_load_csize _nds_load_nlen _nds_load_elen _nds_load_name
    _nds_load_size=$(stat -c '%s' "$_nds_load_zip")
    while (( _nds_load_offset + 30 <= _nds_load_size )); do
        _nds_load_sig=${ _nds_recipe_le "$_nds_load_zip" "$_nds_load_offset" 4; }
        [[ "$_nds_load_sig" -eq 67324752 ]] || break
        _nds_load_method=${ _nds_recipe_le "$_nds_load_zip" $((_nds_load_offset + 8)) 2; }
        if (( _nds_load_method != 0 )); then
            error "recipe: zip entry is compressed and unzip is not available"
            return 1
        fi
        _nds_load_csize=${ _nds_recipe_le "$_nds_load_zip" $((_nds_load_offset + 18)) 4; }
        _nds_load_nlen=${ _nds_recipe_le "$_nds_load_zip" $((_nds_load_offset + 26)) 2; }
        _nds_load_elen=${ _nds_recipe_le "$_nds_load_zip" $((_nds_load_offset + 28)) 2; }
        _nds_load_name=$(dd if="$_nds_load_zip" bs=1 skip=$((_nds_load_offset + 30)) count="$_nds_load_nlen" 2>/dev/null)
        mkdir -p "${_nds_load_dest}/$(dirname "$_nds_load_name")"
        if [[ "$_nds_load_name" != */ ]]; then
            dd if="$_nds_load_zip" bs=1 skip=$((_nds_load_offset + 30 + _nds_load_nlen + _nds_load_elen)) \
                count="$_nds_load_csize" of="${_nds_load_dest}/${_nds_load_name}" 2>/dev/null
        fi
        _nds_load_offset=$((_nds_load_offset + 30 + _nds_load_nlen + _nds_load_elen + _nds_load_csize))
    done
}

_nds_recipe_applyValue() {
    local _nds_load_name=$1 _nds_load_key=$2 _nds_load_value=$3 _nds_load_dir=${4:-}
    local _nds_load_type _nds_load_group
    if ! nds_schema_hasKey "$_nds_load_key"; then
        error "${_nds_load_key}: unknown key"
        return 1
    fi
    _nds_load_group=${_NDS_SCHEMA_FIELD_GROUP[$_nds_load_key]}
    if ! _nds_schema_isEnabled "$_nds_load_group"; then
        debug "${_nds_load_key}: ignored"
        return 0
    fi
    if nds_schema_isLocked "$_nds_load_key"; then
        warn "${_nds_load_key}: ignored locked key"
        return 0
    fi
    _nds_load_type=${_NDS_SCHEMA_FIELD_TYPE[$_nds_load_key]}
    if [[ "$_nds_load_type" == bool ]]; then
        _nds_load_value=${ _nds_recipe_normBool "$_nds_load_value"; }
    fi
    if [[ -n "$_nds_load_dir" && -n "$_nds_load_value" ]]; then
        case "$_nds_load_type" in
            secret|file|dir)
                if [[ "$_nds_load_value" != /* && "$_nds_load_value" != '~'* ]]; then
                    _nds_load_value="${_nds_load_dir}/${_nds_load_value}"
                fi
                ;;
        esac
    fi
    nds_recipe_set "$_nds_load_name" "$_nds_load_key" "$_nds_load_value"
}

nds_recipe_fileKey() {
    local _nds_load_file=$1 _nds_load_want=$2 _nds_load_line _nds_load_value
    [[ -f "$_nds_load_file" ]] || { error "recipe: file not found"; return 1; }
    while IFS= read -r _nds_load_line || [[ -n "$_nds_load_line" ]]; do
        [[ "$_nds_load_line" == "${_nds_load_want}="* ]] || continue
        _nds_load_key=${_nds_load_line%%=*}
        _nds_load_value=${_nds_load_line#*=}
        if [[ "$_nds_load_value" == '"'*'"' && ${#_nds_load_value} -ge 2 ]]; then
            _nds_load_value=${_nds_load_value:1:${#_nds_load_value}-2}
            _nds_load_value=${ _nds_recipe_unescape "$_nds_load_value"; }
        fi
        printf '%s\n' "$_nds_load_value"
        return 0
    done < "$_nds_load_file"
    error "${_nds_load_want}: missing"
    return 1
}

nds_recipe_unpackBundle() {
    local _nds_load_src=$1 _nds_load_dest
    _nds_load_dest="${ nds_session_dir work; }/restore"
    rm -rf "$_nds_load_dest"
    mkdir -p "$_nds_load_dest"
    case "$_nds_load_src" in
        *.zip) _nds_recipe_extractZip "$_nds_load_src" "$_nds_load_dest" ;;
        *.tar.gz|*.tgz) tar -xzf "$_nds_load_src" -C "$_nds_load_dest" ;;
        *)
            error "--restore: expected a zip or tar.gz"
            return 1
            ;;
    esac
    [[ -f "${_nds_load_dest}/nds-restore.recipe" ]] || {
        error "bundle: nds-restore.recipe missing"
        return 1
    }
    printf '%s\n' "${_nds_load_dest}/nds-restore.recipe"
}

nds_recipe_loadFile() {
    local _nds_load_name=$1 _nds_load_file=$2
    local _nds_load_line _nds_load_key _nds_load_value _nds_load_dir _nds_load_dest
    if [[ "$_nds_load_file" == *.zip ]]; then
        _nds_load_dest="${ nds_session_dir work; }/restore"
        rm -rf "$_nds_load_dest"
        mkdir -p "$_nds_load_dest" || return 1
        _nds_recipe_extractZip "$_nds_load_file" "$_nds_load_dest" || return 1
        _nds_load_file="${_nds_load_dest}/nds-restore.recipe"
    fi
    [[ -f "$_nds_load_file" ]] || { error "recipe: file not found"; return 1; }
    _nds_load_dir=$(cd "$(dirname "$_nds_load_file")" && pwd)
    while IFS= read -r _nds_load_line || [[ -n "$_nds_load_line" ]]; do
        [[ -z "$_nds_load_line" || "$_nds_load_line" == '#'* || "$_nds_load_line" == '['* ]] && continue
        if [[ "$_nds_load_line" == 'export '* || "$_nds_load_line" == $'export\t'* ]]; then
            error "recipe: export is not allowed"
            return 1
        fi
        if [[ "$_nds_load_line" != *=* ]]; then
            error "recipe: malformed line"
            return 1
        fi
        _nds_load_key=${_nds_load_line%%=*}
        _nds_load_value=${_nds_load_line#*=}
        if [[ ! "$_nds_load_key" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
            error "${_nds_load_key}: invalid key"
            return 1
        fi
        if [[ "$_nds_load_value" == '"'*'"' && ${#_nds_load_value} -ge 2 ]]; then
            _nds_load_value=${_nds_load_value:1:${#_nds_load_value}-2}
            _nds_load_value=${ _nds_recipe_unescape "$_nds_load_value"; }
        fi
        _nds_recipe_applyValue "$_nds_load_name" "$_nds_load_key" "$_nds_load_value" "$_nds_load_dir" || return 1
    done < "$_nds_load_file"
}

nds_recipe_loadEnv() {
    local _nds_load_name=$1 _nds_load_key _nds_load_env _nds_load_plain _nds_load_value _nds_load_group
    while IFS= read -r _nds_load_group; do
        [[ -n "$_nds_load_group" ]] || continue
        while IFS= read -r _nds_load_key; do
            [[ -n "$_nds_load_key" ]] || continue
            if [[ ${_NDS_SCHEMA_FIELD_TYPE[$_nds_load_key]} == secret ]]; then
                _nds_load_plain=NDS_${_nds_load_key%_FILE}
                if [[ "$_nds_load_plain" != "NDS_${_nds_load_key}" && -n ${!_nds_load_plain-} ]]; then
                    error "${_nds_load_key}: secret values are not accepted; use NDS_${_nds_load_key}"
                    return 1
                fi
            fi
            _nds_load_env=NDS_${_nds_load_key}
            _nds_load_value=${!_nds_load_env-}
            [[ -n "$_nds_load_value" ]] || continue
            _nds_recipe_applyValue "$_nds_load_name" "$_nds_load_key" "$_nds_load_value" || return 1
        done < <(nds_schema_groupFields "$_nds_load_group")
    done < <(nds_schema_groups)
}
