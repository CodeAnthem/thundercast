#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings cfg smoke tests (read-only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-28
# ==================================================================================================

suite_cfg() {
    if [[ ${#PRESET_REGISTRY[@]} -eq 0 ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ no presets registered"
        return 0
    fi

    TEST_PASSED=$((TEST_PASSED + 1))
    console "  ✓ presets registered: ${#PRESET_REGISTRY[@]}"

    local required_presets=(disk encryption region network boot access quick)
    local preset
    for preset in "${required_presets[@]}"; do
        if [[ "${PRESET_REGISTRY[$preset]:-}" == "enabled" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ preset enabled: $preset"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ preset missing or disabled: $preset"
        fi
    done

    CONFIG_DATA[NETWORK_HOSTNAME]=""
    if network_validate &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ network_validate should reject empty hostname"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ network_validate rejects empty hostname"
    fi

    CONFIG_DATA[NETWORK_HOSTNAME]="myhost"
    if network_validate &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ network_validate accepts valid hostname"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ network_validate should accept valid hostname"
    fi

    local _ve_enc _ve_pw _ve_ru _ve_key _ve_sd _ve_out
    _ve_enc=$(nds_cfg_get ENCRYPTION)
    _ve_pw=$(nds_cfg_get ENCRYPTION_PASSWORD)
    _ve_ru=$(nds_cfg_get ENCRYPTION_REMOTE_UNLOCK)
    _ve_key=$(nds_cfg_get ENCRYPTION_REMOTE_SSH_KEY)
    _ve_sd=$(nds_cfg_get ENCRYPTION_REMOTE_SHUTDOWN)
    nds_cfg_set ENCRYPTION "true"
    nds_cfg_set ENCRYPTION_PASSWORD "true"
    nds_cfg_set ENCRYPTION_REMOTE_UNLOCK "true"
    nds_cfg_set ENCRYPTION_REMOTE_SSH_KEY "ssh-ed25519 AAAAfake test@host"
    nds_cfg_set ENCRYPTION_REMOTE_SHUTDOWN "15"
    _ve_out=$(nds_cfg_validate_all encryption 2>&1) || true
    if [[ "$_ve_out" == *"30-3600"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ validate_all prints unlock shutdown range error"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ validate_all hid unlock shutdown range error"
    fi
    nds_cfg_set ENCRYPTION "$_ve_enc"
    nds_cfg_set ENCRYPTION_PASSWORD "$_ve_pw"
    nds_cfg_set ENCRYPTION_REMOTE_UNLOCK "$_ve_ru"
    nds_cfg_set ENCRYPTION_REMOTE_SSH_KEY "$_ve_key"
    nds_cfg_set ENCRYPTION_REMOTE_SHUTDOWN "$_ve_sd"

    nds_cfg_snapshot_defaults
    CONFIG_DATA[DISK_TARGET]="/dev/testdisk"
    CONFIG_DATA[REGION_TIMEZONE]="Europe/Test"
    local grouped
    grouped="$(nds_cfg_export_grouped)"
    if [[ "$(grep -c '^export ' <<<"$grouped")" -ge 3 ]] \
       && grep -q 'NDS_REGION_TIMEZONE="Europe/Test"' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: one export per line, portable value present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export malformed"
    fi
    if grep -qE '^# This machine only' <<<"$grouped" \
       && grep -q 'NDS_DISK_TARGET="/dev/testdisk"' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: hardware split holds DISK_TARGET"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export: hardware split missing DISK_TARGET"
    fi
    if grep -qE '^# Menu control' <<<"$grouped" \
       && grep -q 'NDS_SKIP_MENU="false"' <<<"$grouped" \
       && grep -q 'NDS_AUTO_CONFIRM="false"' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: menu skip flags default false"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export: menu skip flags missing"
    fi

    if ! grep -Pz '# Configuration — portable[^\n]*\n\nexport ' <<<"$grouped" \
       && ! grep -Pz '# This machine only[^\n]*\n\nexport ' <<<"$grouped" \
       && ! grep -Pz '# Menu control[^\n]*\n\nexport ' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: no blank line between section comment and exports"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export: unexpected blank line after section comment"
    fi

    CONFIG_DATA[FLAKE_HOST]="control-toolkit"
    CONFIG_DATA[PLATFORM_RUN_ON_VM]="true"
    CONFIG_DATA[PLATFORM_VM_TYPE]="vmware"
    grouped="$(nds_cfg_export_grouped)"
    if awk '/^# This machine only/,/^# Menu control/' <<<"$grouped" | grep -q 'NDS_PLATFORM_RUN_ON_VM' \
       && awk '/^# This machine only/,/^# Menu control/' <<<"$grouped" | grep -q 'NDS_PLATFORM_VM_TYPE' \
       && ! awk '/^# Configuration — portable/,/^# This machine only/' <<<"$grouped" | grep -q 'NDS_PLATFORM_'; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: platform vars in machine-only section"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export: platform vars not in machine-only section"
    fi

    CONFIG_DATA=()
    CONFIG_DEFAULTS=()
    nds_preset_load_file "${SCRIPT_DIR}/app/settingsManager/data/builtin/installFlake.sh" || return 0
    nds_cfg_preset_enable installFlake
    installFlake_defaults
    nds_cfg_snapshot_defaults
    export NDS_FLAKE_REPO_URL="git@github.com:org/flake.git"
    export NDS_INSTALL_MODE="remote"
    nds_cfg_apply_env_all
    grouped="$(nds_cfg_export_grouped)"
    if grep -q 'NDS_FLAKE_REPO_URL="git@github.com:org/flake.git"' <<<"$grouped" \
       && grep -q 'NDS_INSTALL_MODE="remote"' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ env apply + export: FLAKE_REPO_URL and INSTALL_MODE when set"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ env apply + export: missing FLAKE_REPO_URL or INSTALL_MODE"
    fi

    CONFIG_DATA=()
    CONFIG_DEFAULTS=()
    nds_preset_load_file "${SCRIPT_DIR}/app/settingsManager/data/builtin/installFlake.sh" || return 0
    nds_cfg_preset_enable installFlake
    installFlake_defaults
    nds_cfg_snapshot_defaults
    unset NDS_FLAKE_REPO_URL NDS_FLAKE_LOCAL_PATH NDS_FLAKE_SOURCE
    export NDS_FLAKE_LOCATION="git@github.com:org/via-location.git"
    nds_cfg_apply_env_all
    if [[ "$(nds_cfg_get FLAKE_REPO_URL)" == "git@github.com:org/via-location.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ FLAKE_LOCATION syncs to FLAKE_REPO_URL via env"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ FLAKE_LOCATION sync failed (got: $(nds_cfg_get FLAKE_REPO_URL))"
    fi
    unset NDS_FLAKE_LOCATION

    local saved_enc
    saved_enc="$(nds_cfg_get ENCRYPTION)"
    unset NDS_ENCRYPTION
    export NDS_ENCRYPTION="false"
    export NDS_GH_BIN="/nix/store/fake-gh/bin/gh"
    nds_cfg_apply_env_all
    if [[ "$(nds_cfg_get ENCRYPTION)" == "false" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ env: NDS_ENCRYPTION=false reaches CONFIG_DATA"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ env: NDS_ENCRYPTION=false ignored (got: $(nds_cfg_get ENCRYPTION))"
    fi
    if [[ -z "${CONFIG_DATA[GH_BIN]:-}" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ env: NDS_GH_BIN is runtime, not CONFIG_DATA"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ env: NDS_GH_BIN leaked into CONFIG_DATA"
    fi
    export NDS_GIT_IMPORT_KEY="SECRETKEYMATERIAL"
    nds_cfg_apply_env_all
    if [[ "${CONFIG_DATA[GIT_IMPORT_KEY]:-}" != "SECRETKEYMATERIAL" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ env: NDS_GIT_IMPORT_KEY is runtime, not CONFIG_DATA"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ env: NDS_GIT_IMPORT_KEY leaked into CONFIG_DATA"
    fi
    unset NDS_GIT_IMPORT_KEY
    if ! declare -p NDS_GIT_KEY_BODY &>/dev/null; then
        declare -gA NDS_GIT_KEY_BODY=()
    fi
    NDS_GIT_KEY_BODY['__nds_cfg_leak_test__']='SECRETPEM'
    nds_cfg_apply_env_all
    if [[ -z "${CONFIG_DATA[GIT_KEY_BODY]:-}" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ env: NDS_GIT_KEY_BODY is runtime, not CONFIG_DATA"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ env: NDS_GIT_KEY_BODY leaked into CONFIG_DATA"
    fi
    unset 'NDS_GIT_KEY_BODY[__nds_cfg_leak_test__]'
    unset NDS_ENCRYPTION NDS_GH_BIN
    export NDS_GIT_PERSIST_ACCESS=false
    nds_cfg_apply_env_all
    if [[ "$(nds_cfg_get GIT_PERSIST_ACCESS)" == "false" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ env: NDS_GIT_PERSIST_ACCESS=false reaches CONFIG_DATA"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ env: NDS_GIT_PERSIST_ACCESS ignored (got: $(nds_cfg_get GIT_PERSIST_ACCESS))"
    fi
    unset NDS_GIT_PERSIST_ACCESS
    nds_cfg_set GIT_PERSIST_ACCESS ""
    local scoped_tmp saved_scoped="${NDS_SCOPED_CONFIG_FILE:-}"
    scoped_tmp="$(mktemp)"
    printf '%s\n' 'export NDS_ENCRYPTION="false"' >"$scoped_tmp"
    nds_cfg_set ENCRYPTION true
    unset NDS_ENCRYPTION
    export NDS_SCOPED_CONFIG_FILE="$scoped_tmp"
    nds_cfg_apply_env_all
    if [[ "$(nds_cfg_get ENCRYPTION)" == "false" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ env: config file export NDS_ENCRYPTION reaches CONFIG_DATA"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ env: config file export NDS_ENCRYPTION ignored (got: $(nds_cfg_get ENCRYPTION))"
    fi
    printf '%s\n' "declare -gA NDS_GIT_METHOD=( ['git@github.com:nds-test/cfg.git']='account' )" >"$scoped_tmp"
    nds_cfg_apply_env_all
    if [[ "${NDS_GIT_METHOD['git@github.com:nds-test/cfg.git']:-}" == "account" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ env: config file git URL map reaches NDS_GIT_METHOD"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ env: config file git URL map ignored"
    fi
    unset 'NDS_GIT_METHOD[git@github.com:nds-test/cfg.git]'
    rm -f "$scoped_tmp"
    if [[ -n "$saved_scoped" ]]; then export NDS_SCOPED_CONFIG_FILE="$saved_scoped"; else unset NDS_SCOPED_CONFIG_FILE; fi
    unset NDS_ENCRYPTION
    nds_cfg_set ENCRYPTION "${saved_enc:-true}"

    CONFIG_DATA[NETWORK_HOSTNAME]="menu-skip-host"
    export NDS_SKIP_MENU=true NDS_AUTO_CONFIRM=true
    if nds_cfg_menu_or_skip network </dev/null 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ menu_or_skip: skips when env flags set and preset valid"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ menu_or_skip: should skip with NDS_SKIP_MENU + valid network preset"
    fi
    unset NDS_SKIP_MENU NDS_AUTO_CONFIRM

    # Export contract: scalars only (git maps are the array exception)
    grouped="$(nds_cfg_export_grouped)"
    if ! grep -q 'declare -A NDS_FLAKE' <<<"$grouped" \
       && ! grep -q 'declare -A NDS_DISK' <<<"$grouped" \
       && grep -q '^export NDS_' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: no preset arrays, scalar exports present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export: unexpected preset arrays or missing exports"
    fi

    NDS_GIT_METHOD['git@github.com:nds-test/cfg.git']='account'
    grouped="$(nds_cfg_export_grouped)"
    if grep -q 'declare -gA NDS_GIT_METHOD' <<<"$grouped" \
       && grep -q 'nds-test/cfg.git' <<<"$grouped"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ grouped export: git URL map when set"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ grouped export: missing git URL map"
    fi
    unset 'NDS_GIT_METHOD[git@github.com:nds-test/cfg.git]'

    NDS_CURRENT_ACTION="classicInstall"
    NDS_MODE="unattended"
    NDS_AUTO_CONFIRM="true"
    restore="$(nds_cfg_export_restore)"
    if grep -q '^# Settings$' <<<"$restore" \
       && grep -q '^# Runtime$' <<<"$restore" \
       && grep -q '^export NDS_ACTION="classicInstall"' <<<"$restore" \
       && grep -q '^export NDS_MODE="unattended"' <<<"$restore" \
       && grep -q '^export NDS_AUTO_CONFIRM="true"' <<<"$restore" \
       && grep -qE '^curl -sSL .*start.sh \| bash$' <<<"$restore" \
       && ! grep -q $'\u2014' <<<"$restore"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ restore export: settings, runtime, live curl, no em dash"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ restore export: expected settings + runtime + live curl"
    fi
    unset NDS_CURRENT_ACTION NDS_MODE NDS_AUTO_CONFIRM

    NDS_MODE="unattended"
    nds_cfg_set SCAFFOLD_MODE "existing"
    if nds_cfg_ask_numbered_choice SCAFFOLD_MODE "existing|new" \
        "existing=Use an existing host|new=Scaffold a new host from a role" "new" \
        && [[ "$(nds_cfg_get SCAFFOLD_MODE)" == "existing" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ numbered choice: unattended keeps existing over default"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ numbered choice: unattended overwrote existing with default"
    fi
    unset NDS_MODE

    NDS_GIT_METHOD['git@github.com:CodeAnthem/dp_cluster.git']='account'
    NDS_GIT_METHOD['git@github.com:CodeAnthem/thundercast.git']='account'
    NDS_GIT_METHOD['git@github.com:CodeAnthem/thundercore.git']='account'
    restore="$(nds_cfg_export_restore)"
    if grep -q 'dp_cluster.git' <<<"$restore" \
       && grep -q 'thundercast.git' <<<"$restore" \
       && grep -q 'thundercore.git' <<<"$restore" \
       && ! grep -q ')# Runtime' <<<"$restore" \
       && grep -q '^# Runtime$' <<<"$restore"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ restore export: git maps include every closure URL"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ restore export: missing closure git URLs or maps glued to # Runtime"
    fi
    unset 'NDS_GIT_METHOD[git@github.com:CodeAnthem/dp_cluster.git]'
    unset 'NDS_GIT_METHOD[git@github.com:CodeAnthem/thundercast.git]'
    unset 'NDS_GIT_METHOD[git@github.com:CodeAnthem/thundercore.git]'

    local file_tmp saved_action="${NDS_ACTION:-}" saved_scoped="${NDS_SCOPED_CONFIG_FILE:-}"
    file_tmp="$(mktemp)"
    cat >"$file_tmp" <<'EOF'
# Settings
export NDS_DISK_TARGET="/dev/testdisk"
declare -gA NDS_GIT_METHOD=(
  ['git@github.com:nds-test/a.git']='account'
  ['git@github.com:nds-test/b.git']='account'
)
# Runtime
export NDS_ACTION="classicInstall"
export NDS_MODE="unattended"
export NDS_AUTO_CONFIRM="true"
EOF
    unset NDS_ACTION NDS_MODE NDS_AUTO_CONFIRM NDS_DISK_TARGET
    export NDS_SCOPED_CONFIG_FILE="$file_tmp"
    nds_cfg_apply_env_all
    if [[ "$(nds_cfg_get DISK_TARGET)" == "/dev/testdisk" ]] \
       && [[ "${NDS_ACTION:-}" == "classicInstall" ]] \
       && [[ "${NDS_MODE:-}" == "unattended" ]] \
       && [[ "${NDS_GIT_METHOD['git@github.com:nds-test/a.git']:-}" == "account" ]] \
       && [[ "${NDS_GIT_METHOD['git@github.com:nds-test/b.git']:-}" == "account" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ config file: settings + runtime + multi-repo git maps"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ config file: settings/runtime/git maps not applied"
    fi
    rm -f "$file_tmp"
    if [[ -n "$saved_scoped" ]]; then export NDS_SCOPED_CONFIG_FILE="$saved_scoped"; else unset NDS_SCOPED_CONFIG_FILE; fi
    if [[ -n "$saved_action" ]]; then export NDS_ACTION="$saved_action"; else unset NDS_ACTION; fi
    unset 'NDS_GIT_METHOD[git@github.com:nds-test/a.git]'
    unset 'NDS_GIT_METHOD[git@github.com:nds-test/b.git]'
    unset NDS_MODE NDS_AUTO_CONFIRM

    # Screen export: modified env only (no declare -A)
    CONFIG_DATA=()
    CONFIG_DEFAULTS=()
    CONFIG_DATA[ENCRYPTION_ENABLED]="true"
    CONFIG_DATA[DISK_TARGET]="/dev/sda"
    nds_cfg_snapshot_defaults
    CONFIG_DATA[ENCRYPTION_ENABLED]="false"
    CONFIG_DATA[FLAKE_HOST]="control-toolkit"
    local modified
    modified="$(nds_cfg_export_modified)"
    if grep -q 'NDS_ENCRYPTION_ENABLED="false"' <<<"$modified" \
       && grep -q 'NDS_FLAKE_HOST="control-toolkit"' <<<"$modified" \
       && ! grep -q 'declare -A' <<<"$modified"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ export_modified: changed env only, no arrays"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ export_modified: expected changed env only"
    fi

    local _tk="${SCRIPT_DIR}/app/settingsManager/data/builtin/toolkit.sh"
    local _tk_setup="${SCRIPT_DIR}/actions/toolkit/setup.sh"
    local _if="${SCRIPT_DIR}/app/settingsManager/data/builtin/installFlake.sh"
    if grep -q 'nds_cfg_ask_toggle CAST_TOOLKIT_RESTORE' "$_tk" \
        && grep -q 'nds_cfg_ask_hostname FLAKE_HOST' "$_tk" \
        && grep -q 'SCAFFOLD_ROLE "toolkit"' "$_tk" \
        && ! grep -q 'nds_cfg_ask_choice CAST_TOOLKIT_MODE' "$_tk" \
        && grep -q 'nds_cfg_summary_row "Restore"' "$_tk" \
        && grep -q 'nds_cfg_summary_row "Flake"' "$_tk" \
        && grep -q 'nds_cfg_summary_row "Host"' "$_tk" \
        && grep -q 'nds_cfg_preset_set_menu installFlake false' "$_tk_setup" \
        && grep -q 'nds_flake_scaffold_apply' "$_tk_setup" \
        && grep -q 'nds_cfg_is INSTALL_COMPOSER toolkit' "$_if"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ toolkit: restore toggle, host prompt, role+scaffold, installFlake hidden"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ toolkit: missing host/role/scaffold or still shows Your flake"
    fi
}
