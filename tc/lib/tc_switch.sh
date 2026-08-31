#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — switch (pull flake + nixos-rebuild)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# Env:           TC_FLAKE_ROOT, TC_FLAKE_HOST, TC_FLAKE_REF, TC_GIT_SSH_WRAPPER
# ==================================================================================================

_tc_switch_comin_masked=0
_tc_switch_comin_was_active=0

_tc_switch_comin_pause() {
    systemctl cat comin.service >/dev/null 2>&1 || return 0
    if systemctl is-active --quiet comin.service; then
        _tc_switch_comin_was_active=1
    fi
    tc_info "pausing comin for rebuild"
    systemctl mask --runtime comin.service
    _tc_switch_comin_masked=1
    systemctl stop comin.service || tc_die "could not stop comin"
}

_tc_switch_comin_resume() {
    if [[ "${_tc_switch_comin_masked}" == 1 ]]; then
        systemctl unmask --runtime comin.service || true
        _tc_switch_comin_masked=0
    fi
    if [[ "${_tc_switch_comin_was_active}" == 1 ]]; then
        tc_info "starting comin"
        systemctl start comin.service || tc_info "failed to start comin"
        _tc_switch_comin_was_active=0
    fi
}

_tc_switch_in_progress() {
    pgrep -f '/switch-to-configuration' >/dev/null 2>&1
}

tc_cmd_switch() {
    local wrap ahead behind host_dir stash_dir branch rel parked
    local flake_root="${TC_FLAKE_ROOT}"
    local host_name="${TC_FLAKE_HOST}"
    local remote_ref="${TC_FLAKE_REF}"

    case "${1:-}" in
        -h|--help|help)
            cat <<'EOF'
tc switch — pull flake checkout and nixos-rebuild switch

  tc switch

Env:
  TC_FLAKE_ROOT   Flake root (default /etc/nixos)
  TC_FLAKE_HOST   nixosConfigurations attr (default: hostname -s)
  TC_FLAKE_REF    Remote ref (default origin/main)

Updates: bump the ThunderCast flake input / rebuild — no remote script curl.
EOF
            return 0
            ;;
        "")
            ;;
        *)
            tc_die "unknown argument: $1 (try: tc switch --help)"
            ;;
    esac

    [[ -d "$flake_root" ]] || tc_die "flake root missing: ${flake_root}"
    [[ -d "${flake_root}/.git" ]] || tc_die "not a git checkout: ${flake_root}"

    if wrap="$(tc_resolve_git_ssh)"; then
        export GIT_SSH_COMMAND="$wrap"
    fi

    cd "$flake_root"

    if [[ -z "$(git config --local user.email 2>/dev/null || true)" ]]; then
        git config --local user.email "tc@$(hostname -s 2>/dev/null || echo host)"
    fi
    if [[ -z "$(git config --local user.name 2>/dev/null || true)" ]]; then
        git config --local user.name "tc"
    fi

    if git rev-parse --is-shallow-repository 2>/dev/null | grep -qx true; then
        tc_info "unshallowing clone for updates"
        git fetch --unshallow origin 2>/dev/null || git fetch origin
    else
        git fetch origin
    fi

    ahead=$(git rev-list --count "${remote_ref}..HEAD" 2>/dev/null || echo 0)
    behind=$(git rev-list --count "HEAD..${remote_ref}" 2>/dev/null || echo 0)

    if [[ "${ahead:-0}" -gt 0 ]]; then
        tc_die "local branch is ahead of ${remote_ref} by ${ahead} commit(s).
Install-time secrets (facter.json) must stay untracked/gitignored.
To match remote:  git reset --hard ${remote_ref}"
    fi

    if [[ "${behind:-0}" -eq 0 ]]; then
        tc_info "already up to date with ${remote_ref}"
    else
        tc_info "fast-forward ${behind} commit(s) from ${remote_ref}"
        host_dir=$(find hosts -mindepth 2 -maxdepth 2 -type d -name "$host_name" 2>/dev/null | head -1 || true)
        stash_dir=""
        if [[ -n "$host_dir" ]]; then
            for f in facter.json hardware-configuration.nix nds-boot.nix machine.nix; do
                [[ -f "${host_dir}/${f}" ]] || continue
                if git check-ignore -q "${host_dir}/${f}" 2>/dev/null \
                    || ! git ls-files --error-unmatch "${host_dir}/${f}" &>/dev/null; then
                    stash_dir="${stash_dir:-$(mktemp -d /tmp/tc-switch-hostfacts.XXXXXX)}"
                    mkdir -p "${stash_dir}/${host_dir}"
                    mv "${host_dir}/${f}" "${stash_dir}/${host_dir}/"
                    tc_info "parked ${host_dir}/${f} -> ${stash_dir}"
                fi
            done
        fi

        branch="${remote_ref#origin/}"
        if ! git pull --ff-only origin "$branch"; then
            [[ -n "$stash_dir" ]] && tc_info "host facts parked at ${stash_dir}"
            tc_die "fast-forward failed — resolve manually in ${flake_root}"
        fi

        if [[ -n "$stash_dir" && -d "$stash_dir" ]]; then
            while IFS= read -r -d '' parked; do
                rel="${parked#"${stash_dir}/"}"
                if [[ -e "${flake_root}/${rel}" ]]; then
                    tc_info "keeping remote ${rel}; parked copy at ${parked}"
                else
                    mkdir -p "$(dirname "${flake_root}/${rel}")"
                    mv "$parked" "${flake_root}/${rel}"
                    tc_info "restored ${rel}"
                fi
            done < <(find "$stash_dir" -type f -print0 2>/dev/null)
            rm -rf "$stash_dir"
        fi
    fi

    if _tc_switch_in_progress; then
        tc_die "switch-to-configuration already running (comin deploy?). retry when idle."
    fi

    trap _tc_switch_comin_resume EXIT
    _tc_switch_comin_pause

    tc_info "nixos-rebuild switch --flake ${flake_root}#${host_name}"
    nixos-rebuild switch --flake "${flake_root}#${host_name}" || tc_die "nixos-rebuild failed"
}
