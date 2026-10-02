#!/usr/bin/env bash
# ==================================================================================================
# NDS - Recipe contract
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/schema" --depth 0

_RECIPE_FIX="$(cd "$(dirname "${BASH_SOURCE[0]}")/fixtures" && pwd)"

_recipe_clear() {
    unset R
    declare -gA R=()
}

_recipe_detect() {
    printf '%s\n' from-detect
}

_recipe_checks=()
_recipe_check() {
    _recipe_checks+=("$1")
    return 0
}

_recipe_watch() {
    _errors=()
    _warns=()
    _error_saved=$(declare -f error)
    _warn_saved=$(declare -f warn)
    error() { _errors+=("$1"); }
    warn() { _warns+=("$1"); }
}

_recipe_unwatch() {
    eval "$_error_saved"
    eval "$_warn_saved"
}

_recipe_joined() {
    local IFS=' '
    printf '%s' "$*"
}

_recipe_le() {
    local _recipe_value=$1 _recipe_width=$2 _recipe_i
    for ((_recipe_i = 0; _recipe_i < _recipe_width; _recipe_i++)); do
        printf "\\$(printf '%03o' $(( (_recipe_value >> (8 * _recipe_i)) & 255 )))"
    done
}

_recipe_crc32() {
    local _recipe_file=$1 _recipe_i _recipe_j _recipe_c _recipe_crc=4294967295 _recipe_byte _recipe_raw
    local -a _recipe_table=()
    for ((_recipe_i = 0; _recipe_i < 256; _recipe_i++)); do
        _recipe_c=$_recipe_i
        for ((_recipe_j = 0; _recipe_j < 8; _recipe_j++)); do
            if (( _recipe_c & 1 )); then
                _recipe_c=$(( (_recipe_c >> 1) ^ 3988292384 ))
            else
                _recipe_c=$((_recipe_c >> 1))
            fi
        done
        _recipe_table[_recipe_i]=$_recipe_c
    done
    _recipe_raw=$(od -An -tu1 -v "$_recipe_file")
    for _recipe_byte in $_recipe_raw; do
        _recipe_crc=$(( ((_recipe_crc >> 8) ^ _recipe_table[(_recipe_crc ^ _recipe_byte) & 255]) & 4294967295 ))
    done
    printf '%s\n' $(( _recipe_crc ^ 4294967295 ))
}

_recipe_zip_init() {
    _zip_path=$1
    : > "$_zip_path"
    _zip_names=()
    _zip_crcs=()
    _zip_sizes=()
    _zip_offs=()
}

_recipe_zip_add() {
    local _recipe_file=$1 _recipe_name=$2 _recipe_crc _recipe_size _recipe_offset
    _recipe_crc=${ _recipe_crc32 "$_recipe_file"; }
    _recipe_size=$(stat -c '%s' "$_recipe_file")
    _recipe_offset=$(stat -c '%s' "$_zip_path")
    {
        printf 'PK\003\004'
        _recipe_le 20 2
        _recipe_le 0 2
        _recipe_le 0 2
        _recipe_le 0 2
        _recipe_le 0 2
        _recipe_le "$_recipe_crc" 4
        _recipe_le "$_recipe_size" 4
        _recipe_le "$_recipe_size" 4
        _recipe_le ${#_recipe_name} 2
        _recipe_le 0 2
        printf '%s' "$_recipe_name"
        cat "$_recipe_file"
    } >> "$_zip_path"
    _zip_names+=("$_recipe_name")
    _zip_crcs+=("$_recipe_crc")
    _zip_sizes+=("$_recipe_size")
    _zip_offs+=("$_recipe_offset")
}

_recipe_zip_end() {
    local _recipe_cd _recipe_i _recipe_name
    _recipe_cd=$(stat -c '%s' "$_zip_path")
    for ((_recipe_i = 0; _recipe_i < ${#_zip_names[@]}; _recipe_i++)); do
        _recipe_name=${_zip_names[_recipe_i]}
        {
            printf 'PK\001\002'
            _recipe_le 20 2
            _recipe_le 20 2
            _recipe_le 0 2
            _recipe_le 0 2
            _recipe_le 0 2
            _recipe_le 0 2
            _recipe_le "${_zip_crcs[_recipe_i]}" 4
            _recipe_le "${_zip_sizes[_recipe_i]}" 4
            _recipe_le "${_zip_sizes[_recipe_i]}" 4
            _recipe_le ${#_recipe_name} 2
            _recipe_le 0 2
            _recipe_le 0 2
            _recipe_le 0 2
            _recipe_le 0 2
            _recipe_le 0 4
            _recipe_le "${_zip_offs[_recipe_i]}" 4
            printf '%s' "$_recipe_name"
        } >> "$_zip_path"
    done
    {
        printf 'PK\005\006'
        _recipe_le 0 2
        _recipe_le 0 2
        _recipe_le ${#_zip_names[@]} 2
        _recipe_le ${#_zip_names[@]} 2
        _recipe_le $(( $(stat -c '%s' "$_zip_path") - _recipe_cd )) 4
        _recipe_le "$_recipe_cd" 4
        _recipe_le 0 2
    } >> "$_zip_path"
}

suite_recipe() {
    local got rc out a b mode gen_saved gen_n path tmp zip
    _recipe_clear

    bts_section "Store"
    nds_recipe_set R HOST alpha
    nds_recipe_set R FLAG true
    nds_recipe_set R EMPTY ""
    got=${ nds_recipe_get R HOST; }
    if [[ "$got" == alpha ]]; then
        bts_pass "get returns the stored value"
    else
        bts_fail "get was '${got}'"
    fi
    got=${ nds_recipe_get R MISSING fallback; }
    if [[ "$got" == fallback ]]; then
        bts_pass "get returns the default when the key is missing"
    else
        bts_fail "get default was '${got}'"
    fi
    if nds_recipe_has R HOST && ! nds_recipe_has R EMPTY && ! nds_recipe_has R MISSING; then
        bts_pass "has is true only for a present non-empty key"
    else
        bts_fail "has disagreed with presence"
    fi
    if nds_recipe_is R HOST alpha && nds_recipe_true R FLAG && ! nds_recipe_true R HOST; then
        bts_pass "is and true match the stored value"
    else
        bts_fail "is or true disagreed"
    fi
    got=${ nds_recipe_keys R; }
    if [[ "$got" == $'EMPTY\nFLAG\nHOST' ]]; then
        bts_pass "keys are sorted"
    else
        bts_fail "keys were '${got}'"
    fi

    bts_section "Conditions"
    nds_schema_group zzprobe "Probe"
    nds_schema_field zzprobe PROBE_A string --default alpha
    nds_schema_field zzprobe PROBE_FLAG string
    nds_schema_field zzprobe PROBE_EQ string --when 'PROBE_A=alpha'
    nds_schema_field zzprobe PROBE_NE string --when 'PROBE_A!=beta'
    nds_schema_field zzprobe PROBE_BARE string --when 'PROBE_A'
    nds_schema_field zzprobe PROBE_AND string --when 'PROBE_A=alpha,PROBE_FLAG=yes'
    nds_schema_field zzprobe PROBE_DETECT string --detect _recipe_detect
    nds_schema_field zzprobe PROBE_LOCK string
    nds_schema_field zzprobe PROBE_SECRET_FILE secret \
        --generate nds_generate_password --generate-when 'PROBE_A=go'
    nds_schema_group zzcheck "Check" --check _recipe_check
    nds_schema_lock PROBE_LOCK
    _recipe_clear
    nds_recipe_set R PROBE_A alpha
    if ! nds_schema_isActive R PROBE_EQ; then
        bts_pass "a field in a disabled group is inactive"
    else
        bts_fail "disabled group field was active"
    fi
    nds_schema_enable zzprobe
    if nds_schema_isActive R PROBE_EQ && nds_schema_isActive R PROBE_NE && nds_schema_isActive R PROBE_BARE; then
        bts_pass "equals, not-equals, and a bare key hold"
    else
        bts_fail "matching conditions were inactive"
    fi
    nds_recipe_set R PROBE_FLAG yes
    if nds_schema_isActive R PROBE_AND; then
        bts_pass "comma conditions are AND"
    else
        bts_fail "AND condition was inactive"
    fi
    nds_recipe_set R PROBE_FLAG no
    if nds_schema_isActive R PROBE_AND; then
        bts_fail "AND condition held with one term false"
    else
        bts_pass "comma AND fails when one term fails"
    fi
    nds_recipe_set R PROBE_A beta
    if nds_schema_isActive R PROBE_EQ; then
        bts_fail "equals held for the wrong value"
    else
        bts_pass "equals fails when the value differs"
    fi
    if nds_schema_isActive R PROBE_BARE; then
        bts_pass "a bare key holds for any non-empty value"
    else
        bts_fail "bare key was inactive for a non-empty value"
    fi
    if nds_schema_isActive R PROBE_NE; then
        bts_fail "not-equals held when the value matched"
    else
        bts_pass "not-equals fails when the value matches"
    fi
    nds_recipe_set R PROBE_A ""
    if nds_schema_isActive R PROBE_BARE; then
        bts_fail "bare key held for an empty value"
    else
        bts_pass "an empty value does not satisfy a bare key"
    fi
    rc=0
    nds_schema_field zzprobe PROBE_BAD string --when 'nope' 2>/dev/null || rc=$?  # malformed condition
    if [[ "$rc" -eq 1 ]] && ! nds_schema_hasKey PROBE_BAD; then
        bts_pass "a malformed condition is an error"
    else
        bts_fail "malformed condition rc was ${rc}"
    fi

    bts_section "Seed"
    _recipe_clear
    nds_recipe_seed R
    got=${ nds_recipe_get R PROBE_A; }
    if [[ "$got" == alpha ]]; then
        bts_pass "seed applies a default to an empty key"
    else
        bts_fail "seed default was '${got}'"
    fi
    got=${ nds_recipe_get R PROBE_DETECT; }
    if [[ "$got" == from-detect ]]; then
        bts_pass "seed applies a detect function"
    else
        bts_fail "seed detect was '${got}'"
    fi
    nds_recipe_set R PROBE_A kept
    nds_recipe_seed R
    got=${ nds_recipe_get R PROBE_A; }
    if [[ "$got" == kept ]]; then
        bts_pass "seed leaves a set key alone"
    else
        bts_fail "seed overwrote '${got}'"
    fi

    bts_section "Validate"
    nds_schema_field zzcheck PROBE_REQ string --required
    nds_schema_enable install zzcheck
    _recipe_clear
    _recipe_checks=()
    _recipe_watch
    rc=0
    nds_recipe_validate R || rc=$?
    _recipe_unwatch
    if [[ "$rc" -ge 1 ]] && [[ "$(_recipe_joined "${_errors[@]}")" == *PROBE_REQ* ]]; then
        bts_pass "validate returns the problem count and names the key"
    else
        bts_fail "validate rc was ${rc} errors '${_errors[*]-}'"
    fi
    if [[ ${#_recipe_checks[@]} -eq 1 && "${_recipe_checks[0]}" == R ]]; then
        bts_pass "a group check is called once with the array name"
    else
        bts_fail "group check args were '${_recipe_checks[*]-}'"
    fi

    bts_section "Seal"
    tmp=$(mktemp -d)
    out="${tmp}/incomplete.recipe"
    _recipe_clear
    nds_recipe_loadFile R "${_RECIPE_FIX}/incomplete.recipe" 2>/dev/null || true
    rc=0
    nds_recipe_seal R "$out" 2>/dev/null || rc=$?  # missing PROBE_REQ
    if [[ "$rc" -eq 1 && ! -e "$out" ]]; then
        bts_pass "seal refuses an incomplete recipe and writes nothing"
    else
        bts_fail "incomplete seal rc was ${rc}"
    fi
    _recipe_clear
    nds_recipe_set R PROBE_REQ set
    nds_recipe_set R COOK_PHASES 'disk write_classic'
    nds_recipe_set R INSTALL_MODE local
    nds_recipe_set R PROBE_A 'a"b\c'
    a="${tmp}/a.recipe"
    b="${tmp}/b.recipe"
    nds_recipe_seal R "$a"
    nds_recipe_seal R "$b"
    mode=$(stat -c '%a' "$a")
    if cmp -s "$a" "$b" && [[ "$mode" == 600 ]]; then
        bts_pass "sealing twice is byte-identical"
    else
        bts_fail "seal bytes differed or mode was ${mode}"
    fi
    rm -rf "$tmp"

    bts_section "Load"
    nds_schema_enable region network access flake cook install
    _recipe_clear
    nds_recipe_loadFile R "${_RECIPE_FIX}/classic_min.recipe"
    got=${ nds_recipe_get R COOK_PHASES; }
    local mode_got tz_got
    mode_got=${ nds_recipe_get R INSTALL_MODE; }
    tz_got=${ nds_recipe_get R REGION_TIMEZONE; }
    if [[ "$got" == "disk write_classic hardware_nix copy_configs install_classic bootloader verify" \
        && "$mode_got" == local && "$tz_got" == UTC ]]; then
        bts_pass "loadFile accepts KEY=v and KEY=\"v\""
    else
        bts_fail "classic load was phases '${got}' mode '${mode_got}' tz '${tz_got}'"
    fi
    tmp=$(mktemp)
    printf '%s\n' '# comment' '[ignored]' 'PROBE_A="a\"b\\c"' > "$tmp"
    _recipe_clear
    nds_recipe_set R PROBE_A placeholder
    nds_recipe_loadFile R "$tmp"
    got=${ nds_recipe_get R PROBE_A; }
    if [[ "$got" == 'a"b\c' ]]; then
        bts_pass "loadFile unescapes quotes and backslashes and ignores comments"
    else
        bts_fail "unescaped value was '${got}'"
    fi
    printf '%s\n' 'export COOK_PHASES=disk' > "$tmp"
    rc=0
    nds_recipe_loadFile R "$tmp" 2>/dev/null || rc=$?  # export prefix
    if [[ "$rc" -eq 1 ]]; then
        bts_pass "loadFile rejects an export prefix"
    else
        bts_fail "export prefix rc was ${rc}"
    fi
    printf '%s\n' 'NOT_A_KEY=1' > "$tmp"
    rc=0
    nds_recipe_loadFile R "$tmp" 2>/dev/null || rc=$?  # unknown key
    if [[ "$rc" -eq 1 ]]; then
        bts_pass "loadFile rejects an unknown key"
    else
        bts_fail "unknown key rc was ${rc}"
    fi
    printf '%s\n' 'PROBE_LOCK="other"' > "$tmp"
    _recipe_clear
    R[PROBE_LOCK]=kept
    if nds_recipe_set R PROBE_LOCK other 2>/dev/null; then
        bts_fail "set wrote a locked key"
        return
    fi
    bts_pass "set rejects a locked key"
    _recipe_watch
    nds_recipe_loadFile R "$tmp"
    _recipe_unwatch
    got=${ nds_recipe_get R PROBE_LOCK; }
    if [[ "$got" == kept && "$(_recipe_joined "${_warns[@]}")" == *PROBE_LOCK* ]]; then
        bts_pass "loadFile ignores a locked key with a warning"
    else
        bts_fail "locked value was '${got}' warns '${_warns[*]-}'"
    fi
    _recipe_clear
    nds_recipe_loadFile R "${_RECIPE_FIX}/restore/nds-restore.recipe"
    got=${ nds_recipe_get R ACCESS_ADMIN_PASSWORD_FILE; }
    if [[ "$got" == "${_RECIPE_FIX}/restore/secrets/admin" ]]; then
        bts_pass "loadFile resolves a relative secret path against the recipe directory"
    else
        bts_fail "relative secret was '${got}'"
    fi
    nds_test_session
    zip=$(mktemp --suffix=.zip)
    _recipe_zip_init "$zip"
    _recipe_zip_add "${_RECIPE_FIX}/restore/nds-restore.recipe" nds-restore.recipe
    _recipe_zip_add "${_RECIPE_FIX}/restore/secrets/admin" secrets/admin
    _recipe_zip_end
    _recipe_clear
    nds_recipe_loadFile R "$zip"
    got=${ nds_recipe_get R ACCESS_ADMIN_PASSWORD_FILE; }
    path=${ nds_session_dir work; }
    if [[ "$got" == "${path}/restore/secrets/admin" && -f "$got" ]]; then
        bts_pass "loadFile loads nds-restore.recipe from a zip"
    else
        bts_fail "zip secret was '${got}'"
    fi
    rm -f "$zip" "$tmp"
    nds_test_session_drop
    _recipe_clear
    export NDS_ACCESS_ADMIN_USER=zoe
    export NDS_NOT_A_SCHEMA_KEY=nope
    nds_recipe_loadEnv R
    got=${ nds_recipe_get R ACCESS_ADMIN_USER; }
    if [[ "$got" == zoe ]] && ! nds_recipe_has R NOT_A_SCHEMA_KEY; then
        bts_pass "loadEnv reads only schema keys"
    else
        bts_fail "loadEnv user was '${got}'"
    fi
    unset NDS_ACCESS_ADMIN_USER NDS_NOT_A_SCHEMA_KEY
    export NDS_ACCESS_ADMIN_PASSWORD=plain
    _recipe_watch
    rc=0
    nds_recipe_loadEnv R || rc=$?
    _recipe_unwatch
    unset NDS_ACCESS_ADMIN_PASSWORD
    if [[ "$rc" -eq 1 && "$(_recipe_joined "${_errors[@]}")" == *'secret values are not accepted'* ]]; then
        bts_pass "loadEnv rejects a plain secret value"
    else
        bts_fail "plain secret rc was ${rc} errors '${_errors[*]-}'"
    fi
    _recipe_clear
    printf '%s\n' 'ACCESS_SSH_ENABLE=yes' > "$tmp"
    nds_recipe_loadFile R "$tmp"
    got=${ nds_recipe_get R ACCESS_SSH_ENABLE; }
    if [[ "$got" == true ]]; then
        bts_pass "loadFile normalises a bool"
    else
        bts_fail "bool was '${got}'"
    fi
    rm -f "$tmp"
    _recipe_clear
    nds_recipe_loadFile R "${_RECIPE_FIX}/flake_local.recipe"
    got=${ nds_recipe_get R FLAKE_HOST; }
    if [[ "$got" == control ]]; then
        bts_pass "loadFile reads the flake fixture"
    else
        bts_fail "flake host was '${got}'"
    fi

    bts_section "Materialize"
    nds_test_session
    gen_saved=$(declare -f nds_generate_password)
    gen_n=0
    nds_generate_password() {
        gen_n=$((gen_n + 1))
        printf '%s\n' pw > "$3"
        chmod 600 "$3"
    }
    _recipe_clear
    nds_recipe_set R PROBE_A stay
    nds_recipe_materialize R
    if [[ "$gen_n" -eq 0 ]]; then
        bts_pass "materialize skips a secret whose generate-when is false"
    else
        bts_fail "materialize generated when the condition was false"
    fi
    nds_recipe_set R PROBE_A go
    nds_recipe_materialize R
    path=${ nds_recipe_get R PROBE_SECRET_FILE; }
    if [[ "$gen_n" -eq 1 && -f "$path" ]]; then
        bts_pass "materialize generates an empty secret when generate-when holds"
    else
        bts_fail "materialize count was ${gen_n} path '${path}'"
    fi
    nds_recipe_materialize R
    got=${ nds_recipe_get R PROBE_SECRET_FILE; }
    if [[ "$gen_n" -eq 1 && "$got" == "$path" ]]; then
        bts_pass "materialize leaves an existing secret path alone"
    else
        bts_fail "materialize rewrote the path count ${gen_n}"
    fi
    rm -f "$path"
    nds_recipe_materialize R
    got=${ nds_recipe_get R PROBE_SECRET_FILE; }
    if [[ "$gen_n" -eq 2 && -f "$got" ]]; then
        bts_pass "materialize generates again when the secret file is absent"
    else
        bts_fail "absent secret count was ${gen_n}"
    fi
    eval "$gen_saved"
    nds_test_session_drop

    bts_section "Portable"
    nds_schema_enable disk git cook install access
    _recipe_clear
    nds_recipe_set R COOK_PHASES 'disk write_classic'
    nds_recipe_set R INSTALL_MODE remote
    nds_recipe_set R REMOTE_TARGET_IP 10.1.1.1
    nds_recipe_set R DISK_TARGET /dev/vda
    nds_recipe_set R DISK_STRATEGY nds
    nds_recipe_set R GIT_KEYS_DIR /tmp/keys
    nds_recipe_set R GIT_PERSIST_ACCESS true
    nds_recipe_set R LEAF_PUSH_DIR /tmp/leaf
    nds_recipe_set R LEAF_PUSH_MESSAGE 'push it'
    nds_recipe_set R TARGET_SEED_DIR /tmp/seed
    nds_recipe_set R ACCESS_ADMIN_USER admin
    nds_recipe_set R ACCESS_ADMIN_PASSWORD_AUTO true
    nds_recipe_set R ACCESS_ADMIN_PASSWORD_FILE /tmp/admin-secret
    out=$(mktemp)
    nds_recipe_export R "$out" --portable
    got=$(<"$out")
    rm -f "$out"
    if [[ "$got" == *COOK_PHASES* && "$got" == *GIT_PERSIST_ACCESS* \
        && "$got" != *DISK_TARGET* && "$got" != *REMOTE_TARGET_IP* \
        && "$got" != *GIT_KEYS_DIR* && "$got" != *LEAF_PUSH_DIR* \
        && "$got" != *LEAF_PUSH_MESSAGE* && "$got" != *TARGET_SEED_DIR* \
        && "$got" != *ACCESS_ADMIN_PASSWORD_FILE* ]]; then
        bts_pass "portable export omits machine paths and secrets"
    else
        bts_fail "portable export was '${got}'"
    fi
}
