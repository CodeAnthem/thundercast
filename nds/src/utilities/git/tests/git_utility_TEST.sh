#!/usr/bin/env bash
# ==================================================================================================
# Git utility - store / URL / overlay selfchecks (bashTestSuite)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-09-02
# ==================================================================================================

suite_git_utility() {
    local URL SSH_URL GENERIC_URL BAD_URL SCP_URL QURL PREF_URL
    local host owner repoName provider httpsSafe sshSameSafe gitSshSafe
    local viaHttps viaScp qHost qSafe sshHost sshRepo genericProvider
    local needWriteDefault acc repoUid acc2 sshHost2 accountRepos
    local keyPath storedKeyPath target storedTarget qTarget ssh https
    local needWriteSet debug_out key pub pref_safe got_kp _pref_env
    local prev_workdir="${GIT_WORKDIR:-}"
    local prev_interactive="${GIT_INTERACTIVE-}"

    if ! declare -f git_store_index &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git utility not loaded"
        return 0
    fi

    export GIT_INTERACTIVE=0
    GIT_WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/git_test.XXXXXX")"
    export GIT_WORKDIR
    git_onLoad || {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git_onLoad failed"
        rm -rf "$GIT_WORKDIR"
        return 0
    }

    URL="https://github.com/CodeAnthem/dp_cluster.git"
    SSH_URL="git+ssh://git@github.com/CodeAnthem/thundercore.git"
    GENERIC_URL="git@gitlab.example.com:g/r.git"
    BAD_URL="git@example.invalid:x/y.git"

    _git_util_ok() {
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ gitutil: $1"
    }
    _git_util_fail() {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ gitutil: $1"
    }
    _git_util_assert() {
        local name="$1"; shift
        if "$@"; then _git_util_ok "$name"; else _git_util_fail "$name"; fi
    }
    _git_util_assert_false() {
        local name="$1"; shift
        if "$@"; then _git_util_fail "$name"; else _git_util_ok "$name"; fi
    }
    _git_util_assert_eq() {
        local name="$1" got="$2" want="$3"
        if [[ "$got" == "$want" ]]; then _git_util_ok "$name"
        else _git_util_fail "$name ($got != $want)"; fi
    }

    _git_util_assert "validate https" git_url_validate "$URL"
    _git_util_assert_false "reject empty" git_url_validate ""
    _git_util_assert_false "reject garbage" git_url_validate "not a url"

    _git_util_assert "index https" git_store_index "$URL"
    host=${ git_store_get "$URL" host; }
    owner=${ git_store_get "$URL" owner; }
    repoName=${ git_store_get "$URL" repoName; }
    provider=${ git_store_get "$URL" provider; }
    _git_util_assert_eq "https host" "$host" "github.com"
    _git_util_assert_eq "https owner" "$owner" "CodeAnthem"
    _git_util_assert_eq "https repoName" "$repoName" "dp_cluster"
    _git_util_assert_eq "https provider" "$provider" "github"
    httpsSafe=${ git_store_getSafeUrl "$URL"; }
    _git_util_assert "index scp same identity" git_store_index "git@github.com:CodeAnthem/dp_cluster.git"
    _git_util_assert "index git+ssh same identity" git_store_index "git+ssh://git@github.com/CodeAnthem/dp_cluster.git"
    sshSameSafe=${ git_store_getSafeUrl "git@github.com:CodeAnthem/dp_cluster.git"; }
    gitSshSafe=${ git_store_getSafeUrl "git+ssh://git@github.com/CodeAnthem/dp_cluster.git"; }
    _git_util_assert_eq "safeUrl token" "$httpsSafe" "github_com_CodeAnthem_dp_cluster"
    _git_util_assert_eq "safeUrl scp form" "$sshSameSafe" "$httpsSafe"
    _git_util_assert_eq "safeUrl git+ssh form" "$gitSshSafe" "$httpsSafe"

    SCP_URL="git@github.com:CodeAnthem/dp_cluster.git"
    git_store_set "$SCP_URL" accessVerified "true"
    viaHttps=${ git_store_get "$URL" accessVerified; }
    viaScp=${ git_store_get "$SCP_URL" accessVerified; }
    _git_util_assert_eq "multi-form set/get" "$viaHttps" "true"
    _git_util_assert_eq "multi-form scp read" "$viaScp" "true"
    _git_util_assert "multi-form canRead https" git_store_canRead "$URL"
    _git_util_assert "multi-form canRead scp" git_store_canRead "$SCP_URL"

    QURL="https://github.com/CodeAnthem/dp_cluster.git?ref=main#frag"
    _git_util_assert "index query fragment" git_store_index "$QURL"
    qHost=${ git_store_get "$QURL" host; }
    qSafe=${ git_store_getSafeUrl "$QURL"; }
    _git_util_assert_eq "query host" "$qHost" "github.com"
    _git_util_assert_eq "query same safeUrl" "$qSafe" "$httpsSafe"

    _git_util_assert "index git+ssh" git_store_index "$SSH_URL"
    sshHost=${ git_store_get "$SSH_URL" host; }
    sshRepo=${ git_store_get "$SSH_URL" repoName; }
    _git_util_assert_eq "git+ssh host" "$sshHost" "github.com"
    _git_util_assert_eq "git+ssh repoName" "$sshRepo" "thundercore"

    _git_util_assert "index generic" git_store_index "$GENERIC_URL"
    genericProvider=${ git_store_get "$GENERIC_URL" provider; }
    _git_util_assert_eq "generic host provider label" "$genericProvider" "gitlab"
    needWriteDefault=${ git_store_get "$URL" needWrite; }
    _git_util_assert_eq "needWrite false after index" "$needWriteDefault" "false"
    acc=${ git_store_getAccountUID "$URL"; }
    _git_util_assert_eq "getAccountUID" "$acc" "github.com/CodeAnthem"
    repoUid=${ git_store_getRepoUID "$URL"; }
    _git_util_assert_eq "getRepoUID" "$repoUid" "github_CodeAnthem_dp_cluster"

    acc2=${ git_store_getAccountUID "$SSH_URL"; }
    _git_util_assert_eq "getAccountUID auto-index" "$acc2" "github.com/CodeAnthem"
    sshHost2=${ git_store_get "$SSH_URL" host; }
    _git_util_assert_eq "auto-index host" "$sshHost2" "github.com"

    accountRepos=${ git_store_getAllReposOfAccountUID "github.com/CodeAnthem"; }
    if printf '%s' "$accountRepos" | grep -q "dp_cluster" && printf '%s' "$accountRepos" | grep -q "thundercore"; then
        _git_util_ok "getAllReposOfAccountUID"
    else
        _git_util_fail "getAllReposOfAccountUID"
    fi

    keyPath=${ git_store_getKeyPath "$URL"; }
    storedKeyPath=${ git_store_get "$URL" keyPath; }
    _git_util_assert_eq "keyPath stored" "$keyPath" "$storedKeyPath"

    target=${ git_store_getTargetDir "$URL"; }
    storedTarget=${ git_store_get "$URL" targetDir; }
    _git_util_assert_eq "targetDir stored" "$target" "$storedTarget"
    qTarget=${ git_store_getTargetDir "$QURL"; }
    _git_util_assert_eq "targetDir same identity" "$qTarget" "$target"

    ssh=${ git_store_getUrlSsh "$URL"; }
    _git_util_assert_eq "toSsh" "$ssh" "git@github.com:CodeAnthem/dp_cluster.git"
    https=${ git_store_getUrlHttps "$URL"; }
    _git_util_assert_eq "toHttps" "$https" "https://github.com/CodeAnthem/dp_cluster.git"

    git_store_needWrite "$URL" true
    needWriteSet=${ git_store_get "$URL" needWrite; }
    _git_util_assert_eq "needWrite true after setter" "$needWriteSet" "true"
    git_store_set "$URL" accessVerified "true"
    _git_util_assert "canRead when verified" git_store_canRead "$URL"
    _git_util_assert "canWrite when needWrite" git_store_canWrite "$URL"

    git_gh_setAccountUsingGh "$URL"
    _git_util_assert "account is using gh" git_gh_isAccountUsingGh "$URL"
    _git_util_assert_false "other account not using gh" git_gh_isAccountUsingGh "$GENERIC_URL"

    debug_out=${ git_store_debug 2>&1; }
    if printf '%s' "$debug_out" | grep -q "CodeAnthem/dp_cluster"; then
        _git_util_ok "debug has repo url"
    else
        _git_util_fail "debug has repo url"
    fi

    key="${GIT_WORKDIR}/keys/testkey"
    _git_util_assert "keys create" git_helper_keys_create "$key" "test"
    _git_util_assert "keys isValid" git_helper_keys_isValid "$key"
    pub=${ git_helper_keys_getPublic "$key"; }
    if [[ "$pub" == ssh-ed25519* ]]; then _git_util_ok "keys getPublic"; else _git_util_fail "keys getPublic"; fi

    _git_util_assert "index invalid host" git_store_index "$BAD_URL"
    git_store_set "$BAD_URL" needWrite "false"
    git_store_set "$BAD_URL" isPrivate "true"
    git_store_set "$BAD_URL" accessVerified "false"
    _git_util_assert_false "verifyAccess non-interactive fails" git_store_verifyAccess "$BAD_URL" "test reason"
    _git_util_assert_false "generic addDeployKey unsupported" git_generic_addDeployKey "$BAD_URL"
    _git_util_assert_false "interactive off" git_helper_interactive_isEnabled

    PREF_URL="https://github.com/CodeAnthem/overlay-test.git"
    git_store_setEnvPrefix "NDS_REPO"
    _git_util_assert "index overlay url" git_store_index "$PREF_URL"
    pref_safe=${ git_store_getSafeUrl "$PREF_URL"; }
    export "NDS_REPO_${pref_safe}_keyPath=/tmp/fake-overlay-key"
    git_store_set "$PREF_URL" keyPath ""
    _git_store_overlayEnv "$pref_safe" keyPath
    got_kp=${ git_store_get "$PREF_URL" keyPath; }
    _git_util_assert_eq "overlay prefix hydrates keyPath" "$got_kp" "/tmp/fake-overlay-key"
    git_store_set "$PREF_URL" keyPath "/tmp/from-store"
    git_store_exportField "$PREF_URL" keyPath
    _pref_env="NDS_REPO_${pref_safe}_keyPath"
    _git_util_assert_eq "exportField writes prefix env" "${!_pref_env}" "/tmp/from-store"
    git_store_setEnvPrefix "GIT_REPO"

    if declare -f _git_gh_store_path_from_output &>/dev/null; then
        local store_line
        store_line=${ _git_gh_store_path_from_output \
            $'copying path \'/nix/store/aaa-foo\' from cache...\n  /nix/store/bbb-gh-2.74.0\n/nix/store/bbb-gh-2.74.0\n'; }
        _git_util_assert_eq "gh store path last line" "$store_line" "/nix/store/bbb-gh-2.74.0"
    else
        _git_util_fail "gh store path helper missing"
    fi

    if declare -f git_gh_bin_ready &>/dev/null; then
        local saved_path_bin="$PATH" saved_gh_bin="${NDS_GH_BIN:-}" saved_git_gh="${NDS_GIT_GH_BIN:-}"
        PATH="/var/empty"
        unset NDS_GH_BIN NDS_GIT_GH_BIN GH_BIN
        if git_gh_bin_ready; then
            if command -v gh &>/dev/null; then
                _git_util_ok "gh_bin_ready smoke (host gh)"
            else
                _git_util_fail "gh_bin_ready true without PATH/BIN"
            fi
        else
            _git_util_ok "gh_bin_ready smoke (false without bin)"
        fi
        PATH="$saved_path_bin"
        if [[ -n "$saved_gh_bin" ]]; then export NDS_GH_BIN="$saved_gh_bin"; else unset NDS_GH_BIN; fi
        if [[ -n "$saved_git_gh" ]]; then export NDS_GIT_GH_BIN="$saved_git_gh"; else unset NDS_GIT_GH_BIN; fi
    else
        _git_util_fail "git_gh_bin_ready missing"
    fi

    git_onExit || true
    rm -rf "$GIT_WORKDIR"
    if [[ -n "$prev_workdir" ]]; then
        GIT_WORKDIR="$prev_workdir"
        export GIT_WORKDIR
    else
        unset GIT_WORKDIR
    fi
    if [[ -n "${prev_interactive+x}" ]]; then
        GIT_INTERACTIVE="$prev_interactive"
        export GIT_INTERACTIVE
    else
        unset GIT_INTERACTIVE
    fi
}
