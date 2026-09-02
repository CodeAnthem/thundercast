#!/usr/bin/env bash
# ==================================================================================================
# installFlake - pure helper units (hosts / prepare / roles / lock / leaf)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

suite_flake_helpers() {
    local out tmp lock_dir roles_dir

    _fh_ok() {
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ flake_helpers: $1"
    }
    _fh_fail() {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ flake_helpers: $1"
    }
    _fh_eq() {
        local name="$1" got="$2" want="$3"
        if [[ "$got" == "$want" ]]; then _fh_ok "$name"
        else _fh_fail "$name ($got != $want)"; fi
    }

    if declare -f _nds_install_flake_normalize_eval_hosts &>/dev/null; then
        out=${ _nds_install_flake_normalize_eval_hosts '"alpha\nbeta"'; }
        if [[ "$out" == $'alpha\nbeta' ]]; then
            _fh_ok "normalize quoted nix eval string"
        else
            _fh_fail "normalize quoted (got $(printf '%q' "$out"))"
        fi
        out=${ _nds_install_flake_normalize_eval_hosts $'alpha\nbeta'; }
        if [[ "$out" == $'alpha\nbeta' ]]; then
            _fh_ok "normalize real newlines"
        else
            _fh_fail "normalize newlines (got $(printf '%q' "$out"))"
        fi
    else
        _fh_fail "normalize_eval_hosts missing"
    fi

    if declare -f _nds_install_nix_flake_system_ref &>/dev/null; then
        out=${ _nds_install_nix_flake_system_ref "control-01"; }
        _fh_eq "system ref host attr" "$out" \
            'nixosConfigurations."control-01".config.system.build.toplevel'
    else
        _fh_fail "system_ref missing"
    fi

    if declare -f nds_flake_prepare &>/dev/null; then
        nds_cfg_set FLAKE_HOST ""
        nds_cfg_set NETWORK_HOSTNAME "from-net"
        nds_flake_prepare remote
        out=$(nds_cfg_get FLAKE_HOST)
        _fh_eq "prepare copies NETWORK_HOSTNAME → FLAKE_HOST" "$out" "from-net"

        nds_cfg_set FLAKE_HOST "from-flake"
        nds_cfg_set NETWORK_HOSTNAME "from-net"
        nds_flake_prepare remote
        out=$(nds_cfg_get NETWORK_HOSTNAME)
        _fh_eq "prepare FLAKE_HOST wins → NETWORK_HOSTNAME" "$out" "from-flake"
    else
        _fh_fail "flake_prepare missing"
    fi

    if declare -f _nds_install_flake_discover_roles &>/dev/null; then
        roles_dir=$(mktemp -d "${TMPDIR:-/tmp}/nds_roles.XXXXXX")
        mkdir -p "${roles_dir}/.roles/worker" "${roles_dir}/.roles/toolkit" \
            "${roles_dir}/profiles/legacy"
        : >"${roles_dir}/.roles/worker/opts.nix"
        : >"${roles_dir}/.roles/toolkit/opts.nix"
        : >"${roles_dir}/profiles/legacy/opts.nix"
        out=${ _nds_install_flake_discover_roles "$roles_dir"; }
        if [[ "$out" == "worker" ]]; then
            _fh_ok "discover_roles prefers .roles, skips toolkit"
        else
            _fh_fail "discover_roles ($out)"
        fi
        rm -rf "$roles_dir"
    fi

    if declare -f _nds_install_flake_lock_node_field &>/dev/null; then
        lock_dir=$(mktemp -d "${TMPDIR:-/tmp}/nds_lock.XXXXXX")
        cat >"${lock_dir}/flake.lock" <<'EOF'
{
  "nodes": {
    "thundercast": {
      "locked": {
        "rev": "deadbeef0123456789",
        "type": "git",
        "url": "https://github.com/CodeAnthem/thundercast.git"
      }
    }
  }
}
EOF
        out=${ _nds_install_flake_lock_node_field "${lock_dir}/flake.lock" thundercast url; }
        _fh_eq "lock url field" "$out" "https://github.com/CodeAnthem/thundercast.git"
        out=${ _nds_install_flake_lock_node_field "${lock_dir}/flake.lock" thundercast rev; }
        _fh_eq "lock rev field" "$out" "deadbeef0123456789"
        rm -rf "$lock_dir"
    fi

    if declare -f _nds_git_is_install_leaf &>/dev/null; then
        NDS_FLAKE_REPO_URL="git@github.com:Org/leaf.git"
        if _nds_git_is_install_leaf Org leaf; then
            _fh_ok "leaf match owner/repo from flake URL"
        else
            _fh_fail "leaf should match Org/leaf"
        fi
        if _nds_git_is_install_leaf CodeAnthem thundercast; then
            _fh_fail "leaf must not match unrelated owner/repo"
        else
            _fh_ok "leaf rejects unrelated owner/repo"
        fi
        unset NDS_FLAKE_REPO_URL
    fi
}
