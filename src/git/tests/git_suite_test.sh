#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git tools tests (read-only / temp dirs)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-18
# ==================================================================================================

suite_git() {
    local parsed host owner repo urls tmpdir key_src dest out perms repos register_url

    if declare -f nds_git_access_logic_selfcheck &>/dev/null || \
        nds_import_file "${SCRIPT_DIR}/git/tests/git_access_test.sh" 2>/dev/null; then
        if nds_git_access_logic_selfcheck; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ git_access_logic: normalize + wants_gh"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ git_access_logic: normalize + wants_gh"
        fi
    fi

    if nds_import_file "${SCRIPT_DIR}/git/tests/git_auth_prompts_test.sh" 2>/dev/null \
        && nds_git_auth_prompts_selfcheck; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git_auth_prompts: AA keys + wizard dispatch"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git_auth_prompts: AA keys + wizard dispatch"
    fi

    out=$(nds_git_normalize_url "https://github.com/CodeAnthem/dp_cluster.git")
    if [[ "$out" == "git@github.com:CodeAnthem/dp_cluster.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ normalize_url: HTTPS → SSH (underscore repo name)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ normalize_url: got $out"
    fi

    declare -gA NDS_GIT_METHOD=()
    nds_git_access_set method "https://github.com/CodeAnthem/dp_cluster.git" "account"
    if [[ "$(nds_git_access_get method "git@github.com:CodeAnthem/dp_cluster.git")" == "account" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ access map: same key for https and ssh forms"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ access map: URL key mismatch"
    fi

    local rec_key
    rec_key="$(mktemp)"
    printf 'dummy\n' >"$rec_key"
    NDS_GIT_SESSION_KEY_PATH="$rec_key"
    NDS_GIT_METHOD=()
    NDS_GIT_KEY_PATH=()
    _nds_git_record_url_access "git@github.com:CodeAnthem/dp_cluster.git"
    _nds_git_record_url_access "git@github.com:CodeAnthem/thundercast.git"
    if [[ "$(nds_git_access_get method "git@github.com:CodeAnthem/dp_cluster.git")" == "import" ]] \
       && [[ "$(nds_git_access_get method "git@github.com:CodeAnthem/thundercast.git")" == "import" ]] \
       && [[ "$(nds_git_access_get key_path "git@github.com:CodeAnthem/dp_cluster.git")" == "$rec_key" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ record closure access: every URL gets method + key path"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ record closure access: maps incomplete"
    fi
    rm -f "$rec_key"
    unset NDS_GIT_SESSION_KEY_PATH
    NDS_GIT_METHOD=()
    NDS_GIT_KEY_PATH=()

    parsed=$(_nds_git_url_parse "https://github.com/CodeAnthem/dp_cluster.git")
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    if [[ "$host" == "github.com" && "$owner" == "CodeAnthem" && "$repo" == "dp_cluster" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_url_parse: https github URL"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_url_parse: https github URL"
    fi

    out=$(_nds_git_url_toSsh "https://github.com/org/repo.git")
    if [[ "$out" == "git@github.com:org/repo.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_url_toSsh: normalizes HTTPS to SSH"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_url_toSsh: expected git@github.com:org/repo.git got $out"
    fi

    out=$(_nds_git_url_toSsh "ssh://git@github.com/org/thundercast.git")
    if [[ "$out" == "git@github.com:org/thundercast.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_url_toSsh: normalizes ssh:// to git@"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_url_toSsh: ssh:// normalize got $out"
    fi

    out=$(_nds_git_url_toSsh "git+ssh://git@github.com/org/thundercast.git")
    if [[ "$out" == "git@github.com:org/thundercast.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_url_toSsh: normalizes git+ssh:// to git@"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_url_toSsh: git+ssh:// normalize got $out"
    fi

    out="$(nds_git_url_display "git@github.com:CodeAnthem/dp_cluster.git")"
    if [[ "$out" == "github.com/CodeAnthem/dp_cluster" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ url_display: host/owner/repo"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ url_display: expected github.com/CodeAnthem/dp_cluster got $out"
    fi

    tmpdir=$(mktemp -d)
    urls=$(_nds_git_flake_collect_git_remote_urls "$tmpdir" "git@github.com:org/root.git")
    if grep -q 'git@github.com:org/root.git' <<<"$urls"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ closure collect: includes root URL"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ closure collect: root URL missing"
    fi

    cp "${TEST_ROOT}/fixtures/flake.lock.sample" "${tmpdir}/flake.lock"
    urls=$(_nds_git_flake_collect_git_remote_urls "$tmpdir" "")
    if grep -q 'git@github.com:org/thundercore' <<<"$urls" \
       && grep -q 'git@github.com:org/thundercast' <<<"$urls"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ closure collect: parses flake.lock git+ssh inputs"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ closure collect: flake.lock inputs missing"
    fi

    printf '%s\n' '{"nodes":{"t":{"locked":{"type":"git","url":"ssh://git@github.com/CodeAnthem/thundercore.git"}}}}' \
        > "${tmpdir}/flake.lock.ssh"
    urls=$(_nds_git_flake_lock_ssh_urls "${tmpdir}/flake.lock.ssh")
    if grep -q 'ssh://git@github.com/CodeAnthem/thundercore.git' <<<"$urls"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ flake.lock: parses ssh://git@ URLs"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ flake.lock: ssh://git@ URL parse failed"
    fi
    rm -rf "$tmpdir"

    repos=$(nds_git_urls_to_github_repos \
        "git@github.com:org/a.git" "git@gitlab.com:other/b.git")
    if [[ "$(wc -l <<<"$repos")" -eq 1 ]] && grep -q 'org/a' <<<"$repos"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ gh repo list: github.com only"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ gh repo list: expected single github repo"
    fi

    if nds_git_urls_all_github "git@github.com:org/a.git" "git@github.com:org/b.git"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ urls_all_github: true for github hosts"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ urls_all_github: expected true for github hosts"
    fi

    if ! nds_git_urls_all_github "git@github.com:org/a.git" "git@gitlab.com:other/b.git"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ urls_all_github: false when mixed hosts"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ urls_all_github: expected false for mixed hosts"
    fi

    register_url="$(nds_git_account_ssh_register_url "github.com")"
    if [[ "$register_url" == "https://github.com/settings/ssh/new" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ account_ssh_register_url: GitHub account keys page"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ account_ssh_register_url: expected github.com/settings/ssh/new"
    fi

    if declare -f nds_git_wizard_route_menu &>/dev/null \
        && declare -f nds_git_wizard_screen_single &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git wizard: flow and screen functions loaded"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git wizard: flow/screen functions missing"
    fi

    CONFIG_DATA[FLAKE_HOST]="control-toolkit"
    CONFIG_DATA[FLAKE_REPO_URL]="git@github.com:CodeAnthem/dp_cluster.git"
    if [[ "$(nds_git_owner_slug "${CONFIG_DATA[FLAKE_REPO_URL]}")" == "codeanthem" ]] \
       && [[ "$(nds_git_cfg_owner_slug)" == "codeanthem" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ owner_slug: from URL arg + FLAKE_REPO_URL cfg bridge"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ owner_slug: expected codeanthem"
    fi
    if [[ "$(nds_git_secrets_basename)" == "git-codeanthem-key" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ secrets_basename: git-<owner>-key"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ secrets_basename: expected git-codeanthem-key"
    fi
    if [[ "$(nds_git_ssh_key_title)" == "nds-codeanthem-control-toolkit" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ ssh_key_title: owner + FLAKE_HOST"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ ssh_key_title: expected nds-codeanthem-control-toolkit"
    fi

    if declare -f nds_git_wizard_resolve_key_display &>/dev/null; then
        export NDS_GIT_SSH_KEY_USE_QR=true
        if [[ "$(nds_git_wizard_resolve_key_display)" == "qr" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ resolve_key_display: NDS_GIT_SSH_KEY_USE_QR=true"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ resolve_key_display: expected qr from env"
        fi
        unset NDS_GIT_SSH_KEY_USE_QR
    fi

    if declare -f nds_git_deploy_key_basename &>/dev/null; then
        if [[ "$(nds_git_deploy_key_basename CodeAnthem dp_cluster)" == "nds_deploy_codeanthem_dp_cluster" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ deploy_key_basename: nds_deploy_owner_repo"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ deploy_key_basename: expected nds_deploy_codeanthem_dp_cluster"
        fi
        if [[ "$(nds_git_deploy_key_title CodeAnthem dp_cluster)" == "nds_control-toolkit" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ deploy_key_title: nds_<hostname> on GitHub"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ deploy_key_title: expected nds_control-toolkit"
        fi
    fi

    if declare -f _nds_git_flake_lock_git_entries &>/dev/null; then
        local lock_tmp lock_file
        lock_tmp=$(mktemp -d)
        lock_file="${lock_tmp}/flake.lock"
        cat >"$lock_file" <<'LOCK'
{
  "nodes": {
    "root": { "locked": { "type": "path" } },
    "thundercast": {
      "locked": {
        "type": "git",
        "url": "ssh://git@github.com/CodeAnthem/thundercast",
        "rev": "abc123def456",
        "narHash": "sha256-TEST"
      }
    }
  }
}
LOCK
        if _nds_git_flake_lock_git_entries "$lock_file" | grep -q $'ssh://git@github.com/CodeAnthem/thundercast\tabc123def456\tsha256-TEST'; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake_lock_git_entries: parses git inputs from flake.lock"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake_lock_git_entries: parse failed"
        fi
        rm -rf "$lock_tmp"
    fi

    if declare -f _nds_git_identity_for_url &>/dev/null; then
        local id_tmp id_key
        id_tmp=$(mktemp -d)
        export NDS_RUNTIME_DIR="${id_tmp}/nds-runtime"
        export NDS_GIT_DEPLOY_KEYS_DIR="${id_tmp}/ssh"
        mkdir -p "$NDS_RUNTIME_DIR" "$NDS_GIT_DEPLOY_KEYS_DIR"
        id_key="$(nds_git_deploy_key_path CodeAnthem thundercast)"
        ssh-keygen -t ed25519 -N "" -f "$id_key" -C test >/dev/null 2>&1 || true
        nds_git_keys_register "$id_key" || true
        key=$(_nds_git_identity_for_url "git@github.com:CodeAnthem/thundercast.git" 2>/dev/null || true)
        if [[ "$key" == "$id_key" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ identity_for_url: deploy key per repository"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ identity_for_url: expected ${id_key}, got ${key:-empty}"
        fi
        unset NDS_RUNTIME_DIR NDS_GIT_DEPLOY_KEYS_DIR
        rm -rf "$id_tmp"
    fi

    if declare -f nds_git_auth_set_mode &>/dev/null; then
        nds_git_auth_set_mode deploy
        if [[ "$(nds_git_auth_mode)" == "deploy" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ git auth mode: deploy"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ git auth mode: expected deploy"
        fi
    fi

    if declare -f nds_git_deploy_key_register_url &>/dev/null; then
        register_url="$(nds_git_deploy_key_register_url github.com CodeAnthem dp_cluster)"
        if [[ "$register_url" == "https://github.com/CodeAnthem/dp_cluster/settings/keys" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ deploy_key_register_url: GitHub repo settings"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ deploy_key_register_url: unexpected ${register_url}"
        fi
    fi

    tmpdir=$(mktemp -d)
    key_src="${tmpdir}/source_key"

    export NDS_RUNTIME_DIR="${tmpdir}/nds-runtime"
    mkdir -p "$NDS_RUNTIME_DIR"
    touch "${tmpdir}/test-key"
    if nds_git_keys_register "${tmpdir}/test-key" \
        && grep -qxF "${tmpdir}/test-key" <(nds_git_keys_list); then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ keys_register: session registry"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ keys_register: session registry"
    fi
    unset NDS_RUNTIME_DIR

    dest="${tmpdir}/session/id_ed25519"
    ssh-keygen -t ed25519 -N "" -f "$key_src" -C test >/dev/null 2>&1
    export NDS_GIT_IMPORT_KEY_PATH="$key_src"
    export NDS_GIT_SESSION_KEY_PATH="$dest"
    if nds_git_auth_try_import_path && [[ -f "$dest" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ SSH key import via NDS_GIT_IMPORT_KEY_PATH"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ SSH key import via NDS_GIT_IMPORT_KEY_PATH"
    fi
    unset NDS_GIT_IMPORT_KEY_PATH NDS_GIT_SESSION_KEY_PATH

    export NDS_RUNTIME_DIR="${tmpdir}/nds-runtime"
    mkdir -p "$NDS_RUNTIME_DIR"
    export NDS_GIT_DEPLOY_KEYS_DIR="$tmpdir"

    if ! nds_git_key_write_body "${tmpdir}/bad_key" "not-a-key" 2>/dev/null \
        && [[ ! -f "${tmpdir}/bad_key" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ key_write_body: rejects invalid text"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ key_write_body: should reject invalid text"
    fi

    dest="${tmpdir}/from_write_body"
    if nds_git_key_write_body "$dest" "$(cat "$key_src")" \
        && [[ -f "$dest" ]] && [[ -f "${dest}.pub" ]] \
        && [[ "$(stat -c '%a' "$dest" 2>/dev/null || echo "")" == "600" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ key_write_body: writes 0600 key + .pub"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ key_write_body: write or permissions"
    fi

    export NDS_GIT_IMPORT_KEY
    NDS_GIT_IMPORT_KEY="$(cat "$key_src")"
    export NDS_GIT_SESSION_KEY_PATH="${tmpdir}/from_import_key"
    if nds_git_auth_try_import_body && [[ -f "$NDS_GIT_SESSION_KEY_PATH" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ SSH key import via NDS_GIT_IMPORT_KEY"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ SSH key import via NDS_GIT_IMPORT_KEY"
    fi
    unset NDS_GIT_IMPORT_KEY NDS_GIT_SESSION_KEY_PATH

    NDS_GIT_KEY_BODY['git@github.com:CodeAnthem/dp_cluster.git']="$(cat "$key_src")"
    if nds_git_access_materialize_key "git@github.com:CodeAnthem/dp_cluster.git" \
        && [[ -f "${tmpdir}/nds_imported_codeanthem_dp_cluster" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ access_materialize_key: NDS_GIT_KEY_BODY → imported path"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ access_materialize_key: NDS_GIT_KEY_BODY"
    fi

    out="$(nds_git_export_maps)"
    if grep -q 'NDS_GIT_KEY_BODY' <<<"$out"; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ export_maps: must not emit NDS_GIT_KEY_BODY"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ export_maps: omits NDS_GIT_KEY_BODY"
    fi
    unset 'NDS_GIT_KEY_BODY[git@github.com:CodeAnthem/dp_cluster.git]'
    unset 'NDS_GIT_KEY_PATH[git@github.com:CodeAnthem/dp_cluster.git]'

    dest="$(nds_git_key_dest_for_import "git@github.com:CodeAnthem/dp_cluster.git" "deploy-this")"
    out="$(nds_git_key_dest_for_import "git@github.com:CodeAnthem/dp_cluster.git" "account-all")"
    if [[ "$dest" == "${tmpdir}/nds_deploy_codeanthem_dp_cluster" \
        && "$out" == "${tmpdir}/nds_imported_codeanthem_dp_cluster" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ key_dest_for_import: deploy vs imported paths"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ key_dest_for_import: deploy=${dest} imported=${out}"
    fi

    if declare -f nds_git_wizard_ask_key_source | grep -q 'Have an existing private key' \
        && grep -q 'read -rsn1' "${SCRIPT_DIR}/git/wizard/ui/git_wizard_flow.sh" \
        && ! grep -q 'nds_aa_ask_toggle GIT_EXISTING_KEY' \
            "${SCRIPT_DIR}/git/wizard/ui/git_wizard_flow.sh" \
        && declare -f nds_git_wizard_ask_auth_method | grep -q 'paste|path' \
        && declare -f nds_git_wizard_ask_auth_method | grep -q 'gh|generate'; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: existing-key y/n (single key), then paste/path or gh/generate"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: missing y/n existing-key or paste/path/gh/generate menus"
    fi
    if grep -q 'paste|path|import' \
        "${SCRIPT_DIR}/git/wizard/ui/git_wizard_flow.sh" \
        && grep -q 'GIT_ACCESS_STRATEGY "deploy-this"' \
            "${SCRIPT_DIR}/git/wizard/ui/git_wizard_flow.sh" \
        && grep -q 'nds_git_wizard_ask_access_strategy' \
            "${SCRIPT_DIR}/git/wizard/ui/git_wizard_flow.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: paste/path skip strategy; gh/generate still ask"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: paste/path should skip SSH key strategy"
    fi
    if grep -q 'nds_ui_section_header "Git access"' \
        "${SCRIPT_DIR}/git/wizard/ui/git_wizard_screens.sh" \
        && grep -q 'This repository is private. NDS needs an SSH key' \
        "${SCRIPT_DIR}/git/wizard/ui/git_wizard_screens.sh" \
        && ! grep -q 'Private repositories' \
            "${SCRIPT_DIR}/git/wizard/ui/git_wizard_screens.sh" \
        && ! grep -q 'NDS already probes keys' \
            "${SCRIPT_DIR}/git/wizard/ui/git_wizard_screens.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: Git access section header; short intro"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: missing Git access header or stale private-repo copy"
    fi
    if grep -F -q 'enable \"Allow write access\"' \
        "${SCRIPT_DIR}/git/keys/ui/git_keys_manual.sh" \
        && grep -q 'addRole|toolkit|remoteAction' \
        "${SCRIPT_DIR}/git/keys/ui/git_keys_manual.sh" \
        && grep -q 'CAST_ACTION' \
        "${SCRIPT_DIR}/git/keys/ui/git_keys_manual.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: leaf write hint for addRole/toolkit, not remoteAction-only"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: write-access hint still keyed on remoteAction only"
    fi
    if grep -q 'read -rsn1' \
        "${SCRIPT_DIR}/git/keys/ui/git_keys_manual.sh" \
        && grep -q 'Generate QR codes for URL and public key' \
        "${SCRIPT_DIR}/git/keys/ui/git_keys_manual.sh" \
        && ! grep -q 'nds_aa_ask_toggle GIT_SSH_KEY_USE_QR' \
            "${SCRIPT_DIR}/git/keys/ui/git_keys_manual.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: QR prompt is y/n (default n)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: QR prompt still uses aa toggle"
    fi
    if grep -q '_nds_ui_drain_tty' "${SCRIPT_DIR}/ui/input.sh" \
        && grep -q 'nds_ui_tty_read' "${SCRIPT_DIR}/git/wizard/ui/git_wizard_flow.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: TTY drain + guarded read before existing-key prompt"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: missing TTY drain / guarded read"
    fi
    if grep -q 'nested=true' "${SCRIPT_DIR}/git/wizard/ui/git_wizard_flow.sh" \
        && grep -q '_nds_git_wizard_ensure_aa' \
            "${SCRIPT_DIR}/git/wizard/ui/git_wizard_flow.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: import_each_url binds AA when unbound"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: import_each_url missing AA bind"
    fi
    if declare -f nds_git_wizard_converse_url &>/dev/null \
        && declare -f nds_git_wizard_import_each_url &>/dev/null \
        && ! grep -q 'missing repositories' \
            "${SCRIPT_DIR}/git/wizard/ui/git_wizard_flow.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: per-repo conversation, no lumped missing-repositories label"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: converse_url missing or lumped missing-repositories label"
    fi
    if declare -f _nds_git_auth_uses_existing_key &>/dev/null; then
        nds_cfg_set GIT_EXISTING_KEY "true"
        nds_cfg_set GIT_KEY_SOURCE "have"
        nds_cfg_set GIT_AUTH_ROUTE "paste"
        if _nds_git_auth_uses_existing_key; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ uses_existing_key: existing_key + paste"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ uses_existing_key: expected true for existing_key + paste"
        fi
        nds_cfg_set GIT_EXISTING_KEY "false"
        nds_cfg_set GIT_KEY_SOURCE "new"
        nds_cfg_set GIT_AUTH_ROUTE "gh"
        if ! _nds_git_auth_uses_existing_key; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ uses_existing_key: false for new + gh"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ uses_existing_key: expected false for new + gh"
        fi
        nds_cfg_set GIT_EXISTING_KEY ""
        nds_cfg_set GIT_KEY_SOURCE ""
        nds_cfg_set GIT_AUTH_ROUTE ""
    fi
    if declare -f nds_git_access_set &>/dev/null; then
        local mode_url="git@github.com:CodeAnthem/thundercast.git"
        nds_git_access_set existing_key "$mode_url" "true"
        nds_git_access_set key_mode "$mode_url" "paste"
        if [[ "$(nds_git_access_get existing_key "$mode_url")" == "true" ]] \
            && [[ "$(nds_git_access_get key_mode "$mode_url")" == "paste" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ access map: existing_key + key_mode"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ access map: existing_key/key_mode round-trip"
        fi
        out="$(nds_git_export_maps)"
        if grep -q 'NDS_GIT_EXISTING_KEY' <<<"$out" \
            && grep -q 'NDS_GIT_KEY_MODE' <<<"$out" \
            && grep -q 'paste' <<<"$out" \
            && ! grep -q 'NDS_GIT_KEY_BODY' <<<"$out"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ export_maps: EXISTING_KEY + KEY_MODE, no KEY_BODY"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ export_maps: missing EXISTING_KEY/KEY_MODE or leaked KEY_BODY"
        fi
        unset "NDS_GIT_EXISTING_KEY[$mode_url]"
        unset "NDS_GIT_KEY_MODE[$mode_url]"
    fi

    if grep -q 'no TTY paste in unattended' \
        "${SCRIPT_DIR}/git/keys/ui/git_keys_import.sh"; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ paste: still forbids TTY paste under AUTO_CONFIRM"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ paste: AUTO_CONFIRM does not forbid TTY paste"
    fi
    if declare -f nds_ui_read_hidden_block | grep -q 'nds_skip_menu'; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ hidden block: still skipped by AUTO_CONFIRM"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ hidden block: reads TTY even when prompts skip"
    fi

    local saved_auto="${NDS_AUTO_CONFIRM:-}"
    export NDS_AUTO_CONFIRM=true
    unset NDS_GIT_IMPORT_KEY
    nds_ui_read_hidden_block() { cat "$key_src"; }
    export NDS_GIT_SESSION_KEY_PATH="${tmpdir}/from_paste_tty"
    if nds_git_wizard_menu_import_paste \
        && [[ -f "$NDS_GIT_SESSION_KEY_PATH" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ paste: AUTO_CONFIRM imports key from TTY/mock body"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ paste: AUTO_CONFIRM TTY/mock import failed"
    fi
    unset -f nds_ui_read_hidden_block
    unset NDS_GIT_SESSION_KEY_PATH
    nds_import_file "${SCRIPT_DIR}/ui/prompts.sh" 2>/dev/null || true
    if [[ -n "$saved_auto" ]]; then export NDS_AUTO_CONFIRM="$saved_auto"; else unset NDS_AUTO_CONFIRM; fi

    export NDS_RUNTIME_DIR="${tmpdir}/nds-runtime"
    mkdir -p "$NDS_RUNTIME_DIR"
    local bundle_key portable_out entry found_git_file=false
    bundle_key="${tmpdir}/nds_deploy_codeanthem_bundle"
    cp "$key_src" "$bundle_key"
    [[ -f "${key_src}.pub" ]] && cp "${key_src}.pub" "${bundle_key}.pub"
    nds_git_keys_register "$bundle_key" || true
    NDS_GIT_KEY_PATH['git@github.com:CodeAnthem/dp_cluster.git']="$bundle_key"

    if nds_git_bundle_key_paths | grep -qxF "$bundle_key"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ bundle_key_paths: includes KEY_PATH file"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ bundle_key_paths: missing KEY_PATH file"
    fi
    if [[ "$(nds_git_bundle_key_dest_name "$bundle_key")" == "nds_deploy_codeanthem_bundle" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ bundle_key_dest_name: keeps deploy basename"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ bundle_key_dest_name: unexpected name"
    fi
    portable_out="$(nds_git_export_maps --portable)"
    if grep -q '/root/.ssh/nds_deploy_codeanthem_bundle' <<<"$portable_out" \
        && grep -q 'secrets/git' <<<"$portable_out" \
        && ! grep -q 'NDS_GIT_KEY_BODY' <<<"$portable_out"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ export_maps --portable: KEY_PATH under /root/.ssh, no KEY_BODY"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ export_maps --portable: missing rewrite or leaked KEY_BODY"
    fi

    if declare -f nds_bundle_register_file &>/dev/null \
        && declare -f nds_bundle_reset_contribs &>/dev/null; then
        nds_bundle_reset_contribs
        nds_git_bundle_contrib
        for entry in "${NDS_BUNDLE_FILES[@]:-}"; do
            case "$entry" in
                secrets/git/nds_deploy_codeanthem_bundle\|*) found_git_file=true ;;
            esac
        done
        if [[ "$found_git_file" == "true" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ git_bundle_contrib: registers secrets/git/<key>"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ git_bundle_contrib: did not register secrets/git/<key>"
        fi
        nds_bundle_reset_contribs
    fi

    unset 'NDS_GIT_KEY_PATH[git@github.com:CodeAnthem/dp_cluster.git]'
    unset NDS_RUNTIME_DIR

    export NDS_GIT_DEPLOY_KEYS_DIR="$tmpdir"
    export NDS_GIT_SESSION_KEY_PATH="${tmpdir}/nds_deploy_org_repo"
    if nds_git_key_generate "$NDS_GIT_SESSION_KEY_PATH" "test-gen" \
        && [[ -f "${NDS_GIT_SESSION_KEY_PATH}.pub" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_key_generate"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_key_generate"
    fi
    if nds_git_key_generate "$NDS_GIT_SESSION_KEY_PATH" "test-gen-reuse" \
        && [[ -f "${NDS_GIT_SESSION_KEY_PATH}.pub" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_key_generate: reuses existing key"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_key_generate: reuse failed"
    fi

    mkdir -p "${tmpdir}/mnt"
    nds_git_keys_register "$NDS_GIT_SESSION_KEY_PATH" || true
    # Unit test: install keys without network RO probe (no flake checkout)
    unset NDS_CTX_FLAKE_INSTALL_PATH NDS_FLAKE_INSTALL_PATH NDS_FLAKE_REPO_URL NDS_CTX_FLAKE_REPO_URL
    if nds_git_install_keys_to_target "${tmpdir}/mnt" "" \
        && [[ -f "${tmpdir}/mnt/root/.ssh/nds_deploy_org_repo" ]] \
        && [[ -x "${tmpdir}/mnt/root/.ssh/nds-git-ssh" ]] \
        && [[ -x "${tmpdir}/mnt/root/.nds/bin/nds-switch" ]] \
        && [[ -f "${tmpdir}/mnt/root/.ssh/nds-git.map" ]]; then
        perms=$(stat -c '%a' "${tmpdir}/mnt/root/.ssh/nds_deploy_org_repo" 2>/dev/null || echo "")
        if [[ "$perms" == "600" ]] \
            && grep -q 'org/repo' "${tmpdir}/mnt/root/.ssh/nds-git.map" \
            && grep -qF 'Wi0dh2l9GKJl' "${tmpdir}/mnt/root/.ssh/known_hosts"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ SSH keys + nds-git-ssh + nds-switch installed on target"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ SSH key target map/perms/hostkeys (got ${perms})"
        fi
        if [[ -L "${tmpdir}/mnt/root/.nds/bin/tc-switch" ]] \
            && [[ -L "${tmpdir}/mnt/root/.ssh/tc-git.map" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ target: tc-switch + tc-git.map aliases"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ target: missing tc-switch or tc-git.map"
        fi
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ SSH keys install on target"
    fi

    nds_cfg_set GIT_PERSIST_ACCESS "false"
    mkdir -p "${tmpdir}/mnt-ephemeral"
    if nds_git_install_keys_to_target "${tmpdir}/mnt-ephemeral" "" \
        && [[ ! -x "${tmpdir}/mnt-ephemeral/root/.nds/bin/nds-switch" ]] \
        && [[ ! -f "${tmpdir}/mnt-ephemeral/root/.ssh/nds_deploy_org_repo" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ persist=false: no keys and no nds-switch"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ persist=false: expected no keys and no nds-switch"
    fi
    nds_cfg_set GIT_PERSIST_ACCESS ""
    unset NDS_GIT_PERSIST_ACCESS
    export NDS_GIT_PERSIST_ACCESS=false
    mkdir -p "${tmpdir}/mnt-env"
    if ! nds_git_persist_access \
        && nds_git_install_keys_to_target "${tmpdir}/mnt-env" "" \
        && [[ ! -x "${tmpdir}/mnt-env/root/.nds/bin/nds-switch" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ persist env: NDS_GIT_PERSIST_ACCESS=false skips nds-switch"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ persist env: NDS_GIT_PERSIST_ACCESS=false should skip nds-switch"
    fi
    unset NDS_GIT_PERSIST_ACCESS

    unset NDS_GIT_DEPLOY_KEYS_DIR

    if declare -f nds_git_github_official_host_keys &>/dev/null; then
        ed25519=$(nds_git_github_official_host_keys | awk '/ssh-ed25519/{print $3; exit}')
        # Official docs.github.com Ed25519 host key (must not regress to the typo WiVhwz… blob)
        if [[ "$ed25519" == "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ github official host key: Ed25519 matches docs"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ github official host key: Ed25519 mismatch"
        fi
        if printf '%s' "$ed25519" | grep -q 'WiVhwzGm9JRs'; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ github host key: known-bad typo blob present"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ github official host key: rejects known-bad typo"
        fi
    fi

    if [[ -f "$(_nds_git_tool_src nds-switch.sh 2>/dev/null || true)" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds-switch.sh present in tools/"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds-switch.sh missing"
    fi

    if declare -f nds_git_discover_key_candidates &>/dev/null; then
        cp "$key_src" "${tmpdir}/id_ed25519_test"
        (
            cd "$tmpdir" || exit 1
            if nds_git_discover_key_candidates | grep -q 'id_ed25519_test'; then
                exit 0
            fi
            exit 1
        ) && {
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ discover_key_candidates: scans cwd"
        } || {
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ discover_key_candidates: cwd scan"
        }
    fi

    unset NDS_GIT_SESSION_KEY_PATH

    if declare -f nds_gh_bin_ready &>/dev/null; then
        unset NDS_GIT_GH_BIN NDS_GIT_GH_PREFETCH_DONE
        if ! nds_gh_bin_ready; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_bin_ready: false without PATH/BIN"
        else
            # Host may have gh installed
            if command -v gh &>/dev/null; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ gh_bin_ready: host gh on PATH"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ gh_bin_ready: unexpected true"
            fi
        fi
        fake_bin="${tmpdir}/fake-gh"
        printf '#!/bin/sh\necho fake-gh\n' >"$fake_bin"
        chmod +x "$fake_bin"
        export NDS_GIT_GH_BIN="$fake_bin"
        if nds_gh_bin_ready; then
            local -a cmd=()
            local saved_path="$PATH"
            PATH="/var/empty:${tmpdir}"
            nds_gh_cmd cmd
            PATH="$saved_path"
            if [[ "${cmd[0]}" == "$fake_bin" ]]; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ gh_cmd: prefers NDS_GIT_GH_BIN over nix shell"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ gh_cmd: expected cached bin, got ${cmd[*]}"
            fi
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh_bin_ready: false with NDS_GIT_GH_BIN set"
        fi
        # Stale PREFETCH_DONE alone must not imply a ready binary
        unset NDS_GIT_GH_BIN
        export NDS_GIT_GH_PREFETCH_DONE=true
        if ! nds_gh_bin_ready; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ ensure_prefetch: stale PREFETCH_DONE does not imply bin ready"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ ensure_prefetch: bin ready without BIN after unset"
        fi
        unset NDS_GIT_GH_BIN NDS_GIT_GH_PREFETCH_DONE

        # cmd_nofetch must never invent a nix-shell fallback
        local -a nofetch_cmd=()
        local saved_path2="$PATH"
        PATH="/var/empty:${tmpdir}"
        unset NDS_GIT_GH_BIN
        if ! nds_gh_cmd_nofetch nofetch_cmd; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_cmd_nofetch: false without PATH/BIN"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh_cmd_nofetch: expected false without binary"
        fi
        PATH="$saved_path2"
    fi

    if declare -f nds_gh_hosts_yml_has_github &>/dev/null; then
        local gh_cfg_dir hosts_file
        gh_cfg_dir=$(mktemp -d)
        hosts_file="${gh_cfg_dir}/hosts.yml"
        printf 'github.com:\n    user: test\n' >"$hosts_file"
        GH_CONFIG_DIR="$gh_cfg_dir"
        if nds_gh_hosts_yml_has_github; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ hosts_yml_has_github: detects leftover session"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ hosts_yml_has_github: missed github.com entry"
        fi
        # Binary present but auth status fails — still detect via hosts.yml
        if declare -f nds_gh_host_logged_in &>/dev/null; then
            local fake_gh="${gh_cfg_dir}/gh"
            printf '#!/bin/sh\necho "not logged in" >&2\nexit 1\n' >"$fake_gh"
            chmod +x "$fake_gh"
            local saved_bin="${NDS_GIT_GH_BIN:-}" saved_path3="$PATH"
            unset NDS_GIT_GH_BIN
            # Fake gh first; keep /usr/bin so grep/getent still work
            PATH="${gh_cfg_dir}:/usr/bin:/bin"
            if nds_gh_host_logged_in; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ gh_host_logged_in: hosts.yml fallback when auth status fails"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ gh_host_logged_in: missed hosts.yml after failed auth status"
            fi
            PATH="$saved_path3"
            if [[ -n "$saved_bin" ]]; then export NDS_GIT_GH_BIN="$saved_bin"; else unset NDS_GIT_GH_BIN; fi
        fi
        rm -f "$hosts_file"
        if ! nds_gh_hosts_yml_has_github; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ hosts_yml_has_github: false when absent"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ hosts_yml_has_github: true without file"
        fi
        unset GH_CONFIG_DIR
        rm -rf "$gh_cfg_dir"
    fi

    if declare -f _nds_git_gh_persist_bin_cache &>/dev/null; then
        local cache_tmp bin_tmp saved_cache
        cache_tmp=$(mktemp)
        bin_tmp=$(mktemp)
        printf '#!/bin/sh\necho ok\n' >"$bin_tmp"
        chmod +x "$bin_tmp"
        saved_cache="${NDS_GIT_GH_BIN_CACHE_FILE:-}"
        NDS_GIT_GH_BIN_CACHE_FILE="$cache_tmp"
        export NDS_GIT_GH_BIN="$bin_tmp"
        _nds_git_gh_persist_bin_cache
        unset NDS_GIT_GH_BIN
        if _nds_git_gh_restore_bin_cache && [[ "$NDS_GIT_GH_BIN" == "$bin_tmp" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh bin cache: persist + restore"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh bin cache: persist + restore"
        fi
        unset NDS_GIT_GH_BIN
        if [[ -n "$saved_cache" ]]; then NDS_GIT_GH_BIN_CACHE_FILE="$saved_cache"; else unset NDS_GIT_GH_BIN_CACHE_FILE; fi
        rm -f "$cache_tmp" "$bin_tmp"
    fi

    if declare -f nds_git_persist_access &>/dev/null; then
        nds_cfg_set GIT_PERSIST_ACCESS "false"
        if ! nds_git_persist_access; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ persist_access: false"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ persist_access: expected false"
        fi
        nds_cfg_set GIT_PERSIST_ACCESS "true"
        if nds_git_persist_access; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ persist_access: true"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ persist_access: expected true"
        fi
        nds_cfg_set GIT_PERSIST_ACCESS ""
        unset NDS_GIT_PERSIST_ACCESS
        export NDS_GIT_PERSIST_ACCESS=no
        if ! nds_git_persist_access; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ persist_access: NDS_GIT_PERSIST_ACCESS=no"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ persist_access: env no should be false"
        fi
        unset NDS_GIT_PERSIST_ACCESS
    fi

    if declare -f nds_gh_host_logged_in &>/dev/null; then
        if ! nds_gh_host_logged_in 2>/dev/null; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_host_logged_in: false without session"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_host_logged_in: host has an active gh login"
        fi
    fi

    if declare -f nds_gh_session_cleanup &>/dev/null; then
        if nds_gh_session_cleanup 2>/dev/null; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_session_cleanup: idempotent when logged out"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh_session_cleanup: failed when logged out"
        fi
    fi

    if declare -f nds_flake_host_in_list &>/dev/null; then
        if nds_flake_host_in_list "control-toolkit" "a" "control-toolkit" "b"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake_host_in_list: match"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake_host_in_list: match"
        fi
        if ! nds_flake_host_in_list "missing" "a" "b"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake_host_in_list: miss"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake_host_in_list: miss"
        fi
    fi

    if declare -f nds_flake_list_hosts &>/dev/null; then
        local flake_tmp hosts_out
        flake_tmp=$(mktemp -d)
        mkdir -p "${flake_tmp}/hosts/x86_64-linux/control-toolkit" \
            "${flake_tmp}/hosts/x86_64-linux/worker-01"
        printf '{ outputs = _: {}; }\n' >"${flake_tmp}/flake.nix"
        hosts_out="$(nds_flake_list_hosts "$flake_tmp" 2>/dev/null || true)"
        if grep -q 'control-toolkit' <<<"$hosts_out" && grep -q 'worker-01' <<<"$hosts_out"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake_list_hosts: host-dir filesystem fallback"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake_list_hosts: fallback got: ${hosts_out:-empty}"
        fi
        rm -rf "$flake_tmp"
    fi

    rm -rf "$tmpdir"
}
