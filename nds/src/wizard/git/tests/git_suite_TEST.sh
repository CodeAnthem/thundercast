#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git tools tests (read-only / temp dirs)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-31
# ==================================================================================================

suite_git() {
    local parsed host owner repo urls tmpdir key_src dest out perms repos register_url

    if declare -f nds_git_access_logic_selfcheck &>/dev/null || \
        nds_import_file "${SCRIPT_DIR}/wizard/git/tests/git_access_TEST.sh" 2>/dev/null; then
        if nds_git_access_logic_selfcheck; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ git_access_logic: normalize + wants_gh + write need"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ git_access_logic: normalize + wants_gh"
        fi
    fi

    if nds_import_file "${SCRIPT_DIR}/wizard/git/tests/git_auth_prompts_TEST.sh" 2>/dev/null \
        && nds_git_auth_prompts_selfcheck; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git_auth_prompts: AA keys + wizard dispatch"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git_auth_prompts: AA keys + wizard dispatch"
    fi

    out=${ nds_git_normalize_url "https://github.com/CodeAnthem/dp_cluster.git"; }
    if [[ "$out" == "git@github.com:CodeAnthem/dp_cluster.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ normalize_url: HTTPS → SSH (underscore repo name)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ normalize_url: got $out"
    fi

    declare -gA NDS_GIT_METHOD=()
    nds_git_access_set method "https://github.com/CodeAnthem/dp_cluster.git" "account"
    if [[ "${ nds_git_access_get method "git@github.com:CodeAnthem/dp_cluster.git"; }" == "account" ]]; then
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
    if [[ "${ nds_git_access_get method "git@github.com:CodeAnthem/dp_cluster.git"; }" == "import" ]] \
       && [[ "${ nds_git_access_get method "git@github.com:CodeAnthem/thundercast.git"; }" == "import" ]] \
       && [[ "${ nds_git_access_get key_path "git@github.com:CodeAnthem/dp_cluster.git"; }" == "$rec_key" ]]; then
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

    parsed=${ _nds_git_url_parse "https://github.com/CodeAnthem/dp_cluster.git"; }
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    if [[ "$host" == "github.com" && "$owner" == "CodeAnthem" && "$repo" == "dp_cluster" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_url_parse: https github URL"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_url_parse: https github URL"
    fi

    out=${ _nds_git_url_toSsh "https://github.com/org/repo.git"; }
    if [[ "$out" == "git@github.com:org/repo.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_url_toSsh: normalizes HTTPS to SSH"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_url_toSsh: expected git@github.com:org/repo.git got $out"
    fi

    out=${ _nds_git_url_toSsh "ssh://git@github.com/org/thundercast.git"; }
    if [[ "$out" == "git@github.com:org/thundercast.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_url_toSsh: normalizes ssh:// to git@"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_url_toSsh: ssh:// normalize got $out"
    fi

    out=${ _nds_git_url_toSsh "git+ssh://git@github.com/org/thundercast.git"; }
    if [[ "$out" == "git@github.com:org/thundercast.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_url_toSsh: normalizes git+ssh:// to git@"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_url_toSsh: git+ssh:// normalize got $out"
    fi

    out="${ nds_git_url_display "git@github.com:CodeAnthem/dp_cluster.git"; }"
    if [[ "$out" == "github.com/CodeAnthem/dp_cluster" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ url_display: host/owner/repo"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ url_display: expected github.com/CodeAnthem/dp_cluster got $out"
    fi

    tmpdir=$(mktemp -d)
    urls=${ _nds_git_flake_collect_git_remote_urls "$tmpdir" "git@github.com:org/root.git"; }
    if grep -q 'git@github.com:org/root.git' <<<"$urls"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ closure collect: includes root URL"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ closure collect: root URL missing"
    fi

    cp "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fixtures/flake.lock.sample" "${tmpdir}/flake.lock"
    urls=${ _nds_git_flake_collect_git_remote_urls "$tmpdir" ""; }
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
    urls=${ _flake_lock_ssh_urls "${tmpdir}/flake.lock.ssh"; }
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

    register_url="${ nds_git_account_ssh_register_url "github.com"; }"
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
    if [[ "${ nds_git_owner_slug "${CONFIG_DATA[FLAKE_REPO_URL]}"; }" == "codeanthem" ]] \
       && [[ "${ nds_git_cfg_owner_slug; }" == "codeanthem" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ owner_slug: from URL arg + FLAKE_REPO_URL cfg bridge"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ owner_slug: expected codeanthem"
    fi
    if [[ "${ nds_git_secrets_basename; }" == "git-codeanthem-key" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ secrets_basename: git-<owner>-key"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ secrets_basename: expected git-codeanthem-key"
    fi
    if [[ "${ nds_git_ssh_key_title; }" == "nds-codeanthem-control-toolkit" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ ssh_key_title: owner + FLAKE_HOST"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ ssh_key_title: expected nds-codeanthem-control-toolkit"
    fi

    if declare -f nds_git_wizard_resolve_key_display &>/dev/null; then
        export NDS_GIT_SSH_KEY_USE_QR=true
        _nds_git_test_display=""
        nds_git_wizard_resolve_key_display _nds_git_test_display
        if [[ "$_nds_git_test_display" == "qr" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ resolve_key_display: NDS_GIT_SSH_KEY_USE_QR=true"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ resolve_key_display: expected qr from env"
        fi
        unset NDS_GIT_SSH_KEY_USE_QR _nds_git_test_display
    fi

    if declare -f nds_git_deploy_key_basename &>/dev/null; then
        if [[ "${ nds_git_deploy_key_basename CodeAnthem dp_cluster; }" == "nds_deploy_codeanthem_dp_cluster" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ deploy_key_basename: nds_deploy_owner_repo"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ deploy_key_basename: expected nds_deploy_codeanthem_dp_cluster"
        fi
        if declare -f _nds_git_discover_in_dir &>/dev/null; then
            local disc_tmp disc_out
            disc_tmp=$(mktemp -d)
            : >"${disc_tmp}/nds_deploy_codeanthem_dp_cluster"
            : >"${disc_tmp}/nds_deploy_codeanthem_dp_cluster.pub"
            disc_out="${ _nds_git_discover_in_dir "$disc_tmp"; }"
            if grep -qx "${disc_tmp}/nds_deploy_codeanthem_dp_cluster" <<<"$disc_out" \
                && ! grep -q '\.pub' <<<"$disc_out"; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ discover_in_dir: nds_deploy_* (skips .pub)"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ discover_in_dir: missed nds_deploy_* or included .pub"
            fi
            rm -rf "$disc_tmp"
        fi
        if [[ "${ nds_git_deploy_key_title CodeAnthem dp_cluster; }" == "nds_control-toolkit" ]] \
            && [[ "${ nds_git_deploy_key_register_title CodeAnthem dp_cluster false; }" == "nds_control-toolkit_write" ]] \
            && [[ "${ nds_git_deploy_key_register_title CodeAnthem dp_cluster true; }" == "nds_control-toolkit" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ deploy_key_title: nds_<hostname>; _write suffix when pushing"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ deploy_key_title: expected nds_control-toolkit / _write"
        fi
    fi

    if declare -f flake_listLockGitEntries &>/dev/null; then
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
        if flake_listLockGitEntries "$lock_file" | grep -q $'ssh://git@github.com/CodeAnthem/thundercast\tabc123def456\tsha256-TEST'; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake_listLockGitEntries: parses git inputs from flake.lock"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake_listLockGitEntries: parse failed"
        fi
        rm -rf "$lock_tmp"
    fi

    if declare -f _nds_git_identity_for_url &>/dev/null; then
        local id_tmp id_key env_out sib
        id_tmp=$(mktemp -d)
        export NDS_RUNTIME_DIR="${id_tmp}/nds-runtime"
        export NDS_GIT_DEPLOY_KEYS_DIR="${id_tmp}/ssh"
        mkdir -p "$NDS_RUNTIME_DIR" "$NDS_GIT_DEPLOY_KEYS_DIR"
        id_key="${ nds_git_deploy_key_path CodeAnthem thundercast; }"
        ssh-keygen -t ed25519 -N "" -f "$id_key" -C test >/dev/null 2>&1 || true
        nds_git_keys_register "$id_key" || true
        key=${ _nds_git_identity_for_url "git@github.com:CodeAnthem/thundercast.git" 2>/dev/null || true; }
        if [[ "$key" == "$id_key" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ identity_for_url: deploy key per repository"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ identity_for_url: expected ${id_key}, got ${key:-empty}"
        fi
        env_out="${ _nds_git_ssh_env_for_url "git@github.com:CodeAnthem/thundercore.git" 2>/dev/null || true; }"
        if grep -Fq "$id_key" <<<"$env_out"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ ssh_env_for_url: offers registered key on same-owner sibling"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ ssh_env_for_url: sibling probe does not offer ${id_key}"
        fi
        sib=${ _nds_git_identity_for_url "git@github.com:CodeAnthem/thundercore.git" 2>/dev/null || true; }
        if [[ -n "$sib" && -f "$sib" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ identity_for_url: falls back to a registered key for siblings"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ identity_for_url: no identity for same-owner sibling"
        fi
        unset NDS_RUNTIME_DIR NDS_GIT_DEPLOY_KEYS_DIR
        rm -rf "$id_tmp"
    fi

    if declare -f nds_git_auth_set_mode &>/dev/null; then
        nds_git_auth_set_mode deploy
        if [[ "${ nds_git_auth_mode; }" == "deploy" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ git auth mode: deploy"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ git auth mode: expected deploy"
        fi
    fi

    if declare -f nds_git_deploy_key_register_url &>/dev/null; then
        register_url="${ nds_git_deploy_key_register_url github.com CodeAnthem dp_cluster; }"
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

    out="${ nds_git_export_maps; }"
    if grep -q 'NDS_GIT_KEY_BODY' <<<"$out"; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ export_maps: must not emit NDS_GIT_KEY_BODY"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ export_maps: omits NDS_GIT_KEY_BODY"
    fi
    unset 'NDS_GIT_KEY_BODY[git@github.com:CodeAnthem/dp_cluster.git]'
    unset 'NDS_GIT_KEY_PATH[git@github.com:CodeAnthem/dp_cluster.git]'

    dest="${ nds_git_key_dest_for_import "git@github.com:CodeAnthem/dp_cluster.git" "deploy-this"; }"
    out="${ nds_git_key_dest_for_import "git@github.com:CodeAnthem/dp_cluster.git" "account-all"; }"
    if [[ "$dest" == "${tmpdir}/nds_deploy_codeanthem_dp_cluster" \
        && "$out" == "${tmpdir}/nds_imported_codeanthem_dp_cluster" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ key_dest_for_import: deploy vs imported paths"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ key_dest_for_import: deploy=${dest} imported=${out}"
    fi

    if declare -f nds_git_wizard_ask_key_source | grep -q 'Have an existing private key' \
        && grep -q 'nds_ask_user_to_proceed "Have an existing private key?"' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && ! grep -q 'nds_aa_ask_toggle GIT_EXISTING_KEY' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && declare -f nds_git_wizard_ask_auth_method | grep -q 'paste|path' \
        && declare -f nds_git_wizard_ask_auth_method | grep -q 'gh|generate'; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: existing-key y/n (proceed helper), then paste/path or gh/generate"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: missing y/n existing-key or paste/path/gh/generate menus"
    fi
    if grep -q 'GIT_ACCESS_STRATEGY "deploy-this"' \
        "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && ! grep -q 'nds_git_wizard_ask_closure_coverage' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && grep -q 'nds_git_wizard_import_each_url "${failed' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && ! grep -q 'nds_git_wizard_ask_access_strategy' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && ! grep -q 'Deploy key: read-only' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: first repo is this-repo only; related repos use per-repo import"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: early SSH key strategy menu or batch closure coverage still present"
    fi
    if grep -q 'nds_ui_section_header "Git access"' \
        "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_screens.sh" \
        && grep -q 'is private.' \
        "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_screens.sh" \
        && grep -q 'nds_ui_kv_row "Permission"' \
        "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_screens.sh" \
        && grep -q 'nds_git_access_normalize_need' \
        "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_screens.sh" \
        && ! grep -q 'Related private repositories still need SSH access' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_screens.sh" \
        && ! grep -q 'nds_ui_kv_row "Repository"' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_screens.sh" \
        && ! grep -q 'NDS already probes keys' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_screens.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: Git access intro names the repo once (no batch closure screen)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: missing Git access header or batch closure screen still present"
    fi
    if grep -q 'nds_git_access_deploy_read_only' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_new.sh" \
        && grep -q 'tick the checkbox' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_manual.sh" \
        && grep -q 'nds_git_deploy_key_register_title' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_manual.sh" \
        && grep -q 'git_gh_register_deploy_key' \
        "${SCRIPT_DIR}/wizard/git/keys/logic/git_keys_gh.sh" \
        && grep -q 'read_only' \
        "${SCRIPT_DIR}/wizard/git/keys/logic/git_keys_gh.sh" \
        && ! grep -q 'NDS_GH_DEPLOY_READ_ONLY' \
            "${SCRIPT_DIR}/wizard/git/keys/logic/git_keys_gh.sh" \
        && ! grep -q 'NDS_CURRENT_ACTION.*remoteAction' \
            "${SCRIPT_DIR}/wizard/git/keys/logic/git_keys_gh.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: write deploy keys follow per-call need, not env or remoteAction"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: write-access still keyed on env, remoteAction, or missing read_only"
    fi
    if grep -q 'nds_app_actionManager_logic_callFeature nds_git_access_run' \
        "${SCRIPT_DIR}/wizard/install/logic/install_leaf_open.sh" \
        && grep -q 'write \\' \
        "${SCRIPT_DIR}/wizard/install/logic/install_leaf_open.sh" \
        && grep -q 'This action git-pushes host files to the install flake.' \
        "${SCRIPT_DIR}/wizard/install/logic/install_leaf_open.sh" \
        && ! grep -q 'GIT_ACCESS_NEED' \
        "${SCRIPT_DIR}/wizard/install/logic/install_leaf_open.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ install: open_leaf passes write + reason as git access args"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ install: open_leaf missing write/reason args on git access"
    fi
    if awk '
        /nds_install_flake_probe_leaf_write/ { if (!w) w=NR }
        /nds_git_ensure_flake_closure_access/ { c=NR }
        END { exit !(w && c && w < c) }
    ' "${SCRIPT_DIR}/wizard/install/logic/install_leaf_open.sh" \
        && grep -q 'nds_git_auth_wizard_step_repo' \
            "${SCRIPT_DIR}/wizard/install/logic/install_leaf_open.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ install: leaf write is checked before related-repo wizard"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ install: leaf write still runs after flake-input closure"
    fi
    if grep -q 'nds_deploy_\*' \
        "${SCRIPT_DIR}/wizard/git/access/logic/git_access_discover.sh" \
        && grep -q 'nds_git_register_keys_in_dir' \
        "${SCRIPT_DIR}/wizard/git/access/logic/git_access_discover.sh" \
        && grep -q 'folder of nds_deploy' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_import.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git discover: nds_deploy_* restore-bundle folder"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git discover: still misses nds_deploy_* / key folders"
    fi
    if grep -q 'nds_step_start_spin "Checking git access"' \
        "${SCRIPT_DIR}/wizard/git/access/logic/git_access.sh" \
        && grep -q 'nds_step_cancel' \
        "${SCRIPT_DIR}/wizard/git/access/logic/git_access.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git_access: spinner while probing, cancel before wizard"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git_access: probe is still a static line (no start_spin/cancel)"
    fi
    if grep -q 'nds_step_start_spin "Verifying git input access"' \
        "${SCRIPT_DIR}/wizard/git/access/logic/git_access_auth.sh" \
        && grep -B20 'nds_git_auth_wizard_step_closure' \
            "${SCRIPT_DIR}/wizard/git/access/logic/git_access_auth.sh" | grep -q 'nds_step_cancel'; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git_access: closure spinner cancelled before related-repo wizard"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git_access: closure wizard can run under Verifying git input access spinner"
    fi
    if grep -q 'nds_step_cancel' "${SCRIPT_DIR}/ui/section.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ ui: new_section cancels leftover step spinner"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ ui: new_section does not cancel an in-progress spinner"
    fi
    if grep -q 'Key received' "${SCRIPT_DIR}/ui/prompts.sh" \
        && grep -q 'received %d line' "${SCRIPT_DIR}/ui/prompts.sh" \
        && grep -q 'Checking SSH key' "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_import.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git import: paste acks immediately, spinner while probing"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git import: paste still silent until probe finishes"
    fi
    if grep -q 'nds_git_ssh_env_for_keys' \
        "${SCRIPT_DIR}/wizard/git/lib/git_probe.sh" \
        && grep -q 'nds_git_keys_list' \
        "${SCRIPT_DIR}/wizard/git/lib/git_ssh.sh" \
        && grep -q 'nds_git_keys_list' \
        "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && grep -q 'GIT_ACCESS_STRATEGY "account-all"' \
        "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git probe: pasted key is the identity; reuse on remaining URLs"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git probe: still probes with identity_for_url instead of the pasted key"
    fi
    if grep -q 'That key could not read this repository' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_import.sh" \
        && grep -q 'return 1' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_import.sh" \
        && ! grep -q 'nds_step_fail "SSH key probe"' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_import.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git import: failed probe stays on this repo (no fake FAIL+continue)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git import: probe fail still continues as success"
    fi
    if grep -q 'nds_install_log "git: access not satisfied' \
            "${SCRIPT_DIR}/utilities/git/store/git_store_error.sh" \
        && ! grep -q 'err "access not satisfied' \
            "${SCRIPT_DIR}/utilities/git/store/git_store_error.sh" \
        && grep -q 'nds_install_log "git: ls-remote failed' \
            "${SCRIPT_DIR}/utilities/git/providers/git_generic_access.sh" \
        && ! grep -q 'err "ls-remote failed"' \
            "${SCRIPT_DIR}/utilities/git/providers/git_generic_access.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git probe: auth/ls-remote failures log only (no console FAIL)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git probe: failAccess or ls-remote still prints console FAIL"
    fi
    if grep -q 'clone --quiet' "${SCRIPT_DIR}/utilities/git/providers/git_generic_ops.sh" \
        && grep -q '_nixos_gitInstallEnv' "${SCRIPT_DIR}/utilities/nixos/ops/nixos_flake.sh" \
        && grep -q '"${git_env\[@\]}" nix eval' "${SCRIPT_DIR}/utilities/nixos/ops/nixos_flake.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git/nix: quiet clone + GIT_SSH on flake eval/build"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git/nix: clone still noisy or flake eval missing GIT_SSH"
    fi
    if grep -q 'impure-envs = GIT_SSH GIT_SSH_COMMAND GIT_TERMINAL_PROMPT' \
            "${SCRIPT_DIR}/utilities/nixos/ops/nixos_store.sh" \
        && grep -q 'nds_git_ssh_probe_url' \
            "${SCRIPT_DIR}/wizard/git/access/logic/git_access_prefetch.sh" \
        && ! grep -q 'nds_git_ssh_probe_url' \
            "${SCRIPT_DIR}/wizard/git/access/logic/git_access_auth.sh" \
        && grep -q 'Nix could not prefetch' \
            "${SCRIPT_DIR}/wizard/git/access/logic/git_access_prefetch.sh" \
        && ! grep -q 'return "\$rc"' \
            "${SCRIPT_DIR}/wizard/git/access/logic/git_access_prefetch.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git prefetch: SSH probe at prefetch only; impure-envs; failure propagates"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git prefetch: missing impure-envs, closure loop probe, or broken failure propagation"
    fi
    if grep -q 'nds_runtime_purge_stale' "${SCRIPT_DIR}/app/sessionControl/session_runtime.sh" \
        && grep -q 'GIT_WORKDIR="${RUNTIME_DIR}/gitUtility"' \
            "${SCRIPT_DIR}/app/sessionControl/session_runtime.sh" \
        && grep -q 'git_util\.\*' "${SCRIPT_DIR}/app/sessionControl/session_runtime.sh" \
        && grep -q 'NDS_RUNTIME_DIR}/gitUtility' "${SCRIPT_DIR}/utilities/git/main.sh" \
        && grep -q 'local workdir="${1:-${GIT_WORKDIR:-}}"' \
            "${SCRIPT_DIR}/utilities/git/main.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ runtime: git utility under RUNTIME_DIR; stale /tmp purge on init"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ runtime: missing unified gitUtility workdir or stale temp purge"
    fi
    if declare -f nds_runtime_purge_stale &>/dev/null \
        && declare -f git_onLoad &>/dev/null; then
        local stale="${TMPDIR:-/tmp}/nds_selftest_stale_$$" rt=""
        mkdir -p "$stale"
        nds_runtime_purge_stale
        if [[ ! -d "$stale" ]]; then
            rt="${TMPDIR:-/tmp}/nds_selftest_rt_$$"
            export NDS_RUNTIME_DIR="$rt"
            mkdir -p "$NDS_RUNTIME_DIR"
            unset GIT_WORKDIR
            git_onLoad
            if [[ "$GIT_WORKDIR" == "${NDS_RUNTIME_DIR}/gitUtility" \
                && -d "${GIT_WORKDIR}/git_repo" ]]; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ git_onLoad: defaults to NDS_RUNTIME_DIR/gitUtility"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ git_onLoad: expected ${NDS_RUNTIME_DIR}/gitUtility (got: ${GIT_WORKDIR:-unset})"
            fi
            rm -rf "$rt"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ nds_runtime_purge_stale: did not remove ${stale}"
        fi
        unset NDS_RUNTIME_DIR GIT_WORKDIR
    fi
    if grep -q 'Try another key' \
        "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && grep -q 'nds_git_probe_access_with_key' \
        "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && ! grep -A35 '^nds_git_wizard_ask_auth_method()' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" | grep -q 'nds_ui_section_header'; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: retry paste on same screen; reuse key on remaining repos"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: still skips paste/path or redraws on related-repo retry"
    fi
    if grep -q 'nds_ask_user_to_proceed "Show QR codes?"' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_manual.sh" \
        && grep -q 'Show QR codes?' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_manual.sh" \
        && grep -q 'Please add this key, see info below' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_manual.sh" \
        && grep -q 'I added this deploy key' \
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_manual.sh" \
        && ! grep -q 'nds_aa_ask_toggle GIT_SSH_KEY_USE_QR' \
            "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_manual.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: add-key card + QR y/n (default n)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: missing add-key card or QR still uses aa toggle"
    fi
    if grep -q '_nds_ui_drain_tty' "${SCRIPT_DIR}/ui/input.sh" \
        && grep -q 'nds_ask_user_to_proceed "Have an existing private key?"' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: TTY drain + proceed helper for existing-key prompt"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: missing TTY drain / guarded read"
    fi
    if grep -q 'nds_ui_section_header "Git access"' \
        "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && grep -q 'How do you want to create the key?' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && grep -q 'How do you want to provide the key?' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && grep -q 'nds_ui_read_menu_digit digit' \
            "${SCRIPT_DIR}/app/settingsManager/ui/settings_ask.sh" \
        && grep -A35 '^nds_ui_read_menu_digit()' \
            "${SCRIPT_DIR}/ui/prompts.sh" | grep -q 'nds_ui_tty_read -rsn1 -s' \
        && grep -A35 '^nds_ui_read_menu_digit()' \
            "${SCRIPT_DIR}/ui/prompts.sh" | grep -q 'Paste is not supported' \
        && ! grep -q 'digit=$(nds_ui_read_menu_digit' \
            "${SCRIPT_DIR}/app/settingsManager/ui/settings_ask.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: section jump before key method; numbered menus are single-key+nameref"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: missing section jump or numbered menu still uses subshell digit read"
    fi
    if grep -q 'Clear the gh session from this ISO?" n' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_screens.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ leftover gh: Enter defaults to keep session"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover gh: prompt still has no default (blocks on failure)"
    fi
    if grep -q 'nested=true' "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh" \
        && grep -q '_nds_git_wizard_ensure_aa' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ wizard: import_each_url binds AA when unbound"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ wizard: import_each_url missing AA bind"
    fi
    if declare -f nds_git_wizard_converse_url &>/dev/null \
        && declare -f nds_git_wizard_import_each_url &>/dev/null \
        && ! grep -q 'missing repositories' \
            "${SCRIPT_DIR}/wizard/git/wizard/ui/git_wizard_flow.sh"; then
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
        if [[ "${ nds_git_access_get existing_key "$mode_url"; }" == "true" ]] \
            && [[ "${ nds_git_access_get key_mode "$mode_url"; }" == "paste" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ access map: existing_key + key_mode"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ access map: existing_key/key_mode round-trip"
        fi
        out="${ nds_git_export_maps; }"
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
        "${SCRIPT_DIR}/wizard/git/keys/ui/git_keys_import.sh"; then
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
    if [[ "${ nds_git_bundle_key_dest_name "$bundle_key"; }" == "nds_deploy_codeanthem_bundle" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ bundle_key_dest_name: keeps deploy basename"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ bundle_key_dest_name: unexpected name"
    fi
    portable_out="${ nds_git_export_maps --portable; }"
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
    unset NDS_FLAKE_INSTALL_PATH NDS_FLAKE_REPO_URL
    if nds_install_git_keys_to_target "${tmpdir}/mnt" "" \
        && [[ -f "${tmpdir}/mnt/root/.ssh/nds_deploy_org_repo" ]] \
        && [[ -x "${tmpdir}/mnt/var/lib/tcast/bin/tcast-git-ssh" ]] \
        && [[ -x "${tmpdir}/mnt/var/lib/tcast/bin/tcast" ]] \
        && [[ -f "${tmpdir}/mnt/var/lib/tcast/git.map" ]]; then
        perms=$(stat -c '%a' "${tmpdir}/mnt/root/.ssh/nds_deploy_org_repo" 2>/dev/null || echo "")
        if [[ "$perms" == "600" ]] \
            && grep -q 'org/repo' "${tmpdir}/mnt/var/lib/tcast/git.map" \
            && grep -qF 'Wi0dh2l9GKJl' "${tmpdir}/mnt/root/.ssh/known_hosts"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ SSH keys + tcast-git-ssh + tcast installed on target"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ SSH key target map/perms/hostkeys (got ${perms})"
        fi
        if [[ -x "${tmpdir}/mnt/var/lib/tcast/bin/tcast-git-ssh" ]] \
            && [[ -f "${tmpdir}/mnt/var/lib/tcast/git.map" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ target: tcast-git-ssh + git.map"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ target: missing tcast-git-ssh or git.map"
        fi
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ SSH keys install on target"
    fi

    nds_cfg_set GIT_PERSIST_ACCESS "false"
    mkdir -p "${tmpdir}/mnt-ephemeral"
    if nds_install_git_keys_to_target "${tmpdir}/mnt-ephemeral" "" \
        && [[ ! -x "${tmpdir}/mnt-ephemeral/var/lib/tcast/bin/tcast" ]] \
        && [[ ! -f "${tmpdir}/mnt-ephemeral/root/.ssh/nds_deploy_org_repo" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ persist=false: no keys and no tcast"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ persist=false: expected no keys and no tcast"
    fi
    nds_cfg_set GIT_PERSIST_ACCESS ""
    unset NDS_GIT_PERSIST_ACCESS
    export NDS_GIT_PERSIST_ACCESS=false
    mkdir -p "${tmpdir}/mnt-env"
    if ! nds_git_persist_access \
        && nds_install_git_keys_to_target "${tmpdir}/mnt-env" "" \
        && [[ ! -x "${tmpdir}/mnt-env/var/lib/tcast/bin/tcast" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ persist env: NDS_GIT_PERSIST_ACCESS=false skips tcast"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ persist env: NDS_GIT_PERSIST_ACCESS=false should skip tcast"
    fi
    unset NDS_GIT_PERSIST_ACCESS

    unset NDS_GIT_DEPLOY_KEYS_DIR

    if declare -f nds_git_github_official_host_keys &>/dev/null; then
        ed25519=${ nds_git_github_official_host_keys | awk '/ssh-ed25519/{print $3; exit}'; }
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

    if [[ -f "${ _nds_tc_src bin/tcast 2>/dev/null || true; }" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ tcast/bin/tcast present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ tcast/bin/tcast missing"
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

    if declare -f git_gh_bin_ready &>/dev/null; then
        unset NDS_GIT_GH_BIN NDS_GIT_GH_PREFETCH_DONE
        if ! git_gh_bin_ready; then
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
        if git_gh_bin_ready; then
            local -a cmd=()
            local saved_path="$PATH"
            PATH="/var/empty:${tmpdir}"
            git_gh_ensure_cmd cmd
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
        if ! git_gh_bin_ready; then
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
        if ! git_gh_cmd_nofetch nofetch_cmd; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_cmd_nofetch: false without PATH/BIN"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh_cmd_nofetch: expected false without binary"
        fi
        PATH="$saved_path2"
    fi

    if declare -f git_gh_hosts_yml_has_github &>/dev/null; then
        local gh_cfg_dir hosts_file
        gh_cfg_dir=$(mktemp -d)
        hosts_file="${gh_cfg_dir}/hosts.yml"
        printf 'github.com:\n    user: test\n' >"$hosts_file"
        GH_CONFIG_DIR="$gh_cfg_dir"
        if git_gh_hosts_yml_has_github; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ hosts_yml_has_github: detects leftover session"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ hosts_yml_has_github: missed github.com entry"
        fi
        # Binary present but auth status fails — still detect via hosts.yml
        if declare -f git_gh_host_logged_in &>/dev/null; then
            local fake_gh="${gh_cfg_dir}/gh"
            printf '#!/bin/sh\necho "not logged in" >&2\nexit 1\n' >"$fake_gh"
            chmod +x "$fake_gh"
            local saved_bin="${NDS_GIT_GH_BIN:-}" saved_path3="$PATH"
            unset NDS_GIT_GH_BIN
            # Fake gh first; keep /usr/bin so grep/getent still work
            PATH="${gh_cfg_dir}:/usr/bin:/bin"
            if git_gh_host_logged_in; then
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
        if ! git_gh_hosts_yml_has_github; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ hosts_yml_has_github: false when absent"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ hosts_yml_has_github: true without file"
        fi
        unset GH_CONFIG_DIR
        rm -rf "$gh_cfg_dir"
    fi

    if declare -f _git_gh_persist_bin_cache &>/dev/null; then
        local cache_tmp bin_tmp saved_cache
        cache_tmp=$(mktemp)
        bin_tmp=$(mktemp)
        printf '#!/bin/sh\necho ok\n' >"$bin_tmp"
        chmod +x "$bin_tmp"
        saved_cache="${GIT_GH_BIN_CACHE_FILE:-${NDS_GIT_GH_BIN_CACHE_FILE:-}}"
        GIT_GH_BIN_CACHE_FILE="$cache_tmp"
        NDS_GIT_GH_BIN_CACHE_FILE="$cache_tmp"
        NDS_GH_BIN_CACHE_FILE="$cache_tmp"
        export GIT_GH_BIN_CACHE_FILE NDS_GIT_GH_BIN_CACHE_FILE NDS_GH_BIN_CACHE_FILE
        export NDS_GIT_GH_BIN="$bin_tmp" NDS_GH_BIN="$bin_tmp"
        _git_gh_persist_bin_cache
        unset NDS_GIT_GH_BIN NDS_GH_BIN
        if _git_gh_restore_bin_cache && [[ "${NDS_GIT_GH_BIN:-${NDS_GH_BIN:-}}" == "$bin_tmp" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh bin cache: persist + restore"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh bin cache: persist + restore"
        fi
        unset NDS_GIT_GH_BIN NDS_GH_BIN
        if [[ -n "$saved_cache" ]]; then
            GIT_GH_BIN_CACHE_FILE="$saved_cache"
            NDS_GIT_GH_BIN_CACHE_FILE="$saved_cache"
            NDS_GH_BIN_CACHE_FILE="$saved_cache"
        else
            unset GIT_GH_BIN_CACHE_FILE NDS_GIT_GH_BIN_CACHE_FILE NDS_GH_BIN_CACHE_FILE
        fi
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

    if declare -f git_gh_host_logged_in &>/dev/null; then
        if ! git_gh_host_logged_in 2>/dev/null; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_host_logged_in: false without session"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_host_logged_in: host has an active gh login"
        fi
    fi

    if declare -f git_gh_session_cleanup &>/dev/null; then
        if git_gh_session_cleanup 2>/dev/null; then
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
        hosts_out="${ nds_flake_list_hosts "$flake_tmp" 2>/dev/null || true; }"
        if [[ -z "$hosts_out" ]] \
            && ! grep -q 'control-toolkit' <<<"$hosts_out" \
            && ! grep -q 'worker-01' <<<"$hosts_out"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake_list_hosts: no host-dir fallback when flake has no nixosConfigurations"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake_list_hosts: unexpected names: ${hosts_out:-empty}"
        fi
        rm -rf "$flake_tmp"
    fi

    rm -rf "$tmpdir"
}
