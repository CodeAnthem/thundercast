#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — switch (pull flake + nixos-rebuild) + --config / --force
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# Env:           TCAST_FLAKE_ROOT, TCAST_FLAKE_HOST, TCAST_FLAKE_REF, TCAST_GIT_SSH_WRAPPER
# Config file:   $TCAST_CONFIG_DIR/switch.conf + $TCAST_CONFIG_DIR/git.map
# ==================================================================================================

_tcast_switch_comin_masked=0
_tcast_switch_comin_was_active=0

_tcast_switch_comin_pause() {
    systemctl cat comin.service >/dev/null 2>&1 || return 0
    if systemctl is-active --quiet comin.service; then
        _tcast_switch_comin_was_active=1
    fi
    tcast_info "pausing comin for rebuild"
    systemctl mask --runtime comin.service
    _tcast_switch_comin_masked=1
    systemctl stop comin.service || tcast_die "could not stop comin"
}

_tcast_switch_comin_resume() {
    if [[ "${_tcast_switch_comin_masked}" == 1 ]]; then
        systemctl unmask --runtime comin.service || true
        _tcast_switch_comin_masked=0
    fi
    if [[ "${_tcast_switch_comin_was_active}" == 1 ]]; then
        tcast_info "starting comin"
        systemctl start comin.service || tcast_info "failed to start comin"
        _tcast_switch_comin_was_active=0
    fi
}

_tcast_switch_in_progress() {
    pgrep -f '/switch-to-configuration' >/dev/null 2>&1
}

_tcast_switch_map_list() {
    local map
    map="$(tcast_git_map_path)"
    echo "map: ${map}"
    if [[ ! -f "$map" ]] || ! grep -qE '^[^#[:space:]]' "$map" 2>/dev/null; then
        echo "(no entries)"
        return 0
    fi
    grep -vE '^(#|$)' "$map" | while IFS=$'\t' read -r repo key; do
        printf '  %s\t%s\n' "$repo" "$key"
    done
}

_tcast_switch_map_remove() {
    local map repo tmp
    map="$(tcast_git_map_path)"
    [[ -f "$map" ]] || tcast_die "no map at ${map}"
    if [[ -n "${1:-}" ]]; then
        repo="${1,,}"
    else
        tcast_ui_ask "owner/repo to remove: " || tcast_die "need owner/repo"
        repo="${REPLY,,}"
    fi
    [[ -n "$repo" ]] || tcast_die "owner/repo required"
    tmp="$(mktemp)"
    grep -v "^${repo}"$'\t' "$map" >"$tmp" || true
    mv "$tmp" "$map"
    chmod 600 "$map"
    tcast_info "removed ${repo} (if present)"
}

# Description: Interactive / CLI config for switch (map + flake settings).
tcast_switch_config() {
    local label
    case "${1:-}" in
        ""|menu)
            while true; do
                tcast_ui_section "tcast switch --config"
                echo "  config dir: ${TCAST_CONFIG_DIR}"
                echo "  flake: ${TCAST_FLAKE_ROOT} #${TCAST_FLAKE_HOST} (${TCAST_FLAKE_REF})"
                if ! tcast_ui_menu "Switch settings" \
                    "list deploy-key map" \
                    "add repo key" \
                    "remove repo" \
                    "set flake root" \
                    "set flake host attr" \
                    "set remote ref" \
                    "show GIT_SSH_COMMAND hint" \
                    "quit"
                then
                    return 0
                fi
                label="$REPLY"
                case "$label" in
                    "list deploy-key map") _tcast_switch_map_list ;;
                    "add repo key") tcast_git_ssh_init ;;
                    "remove repo") _tcast_switch_map_remove ;;
                    "set flake root")
                        tcast_ui_ask "TCAST_FLAKE_ROOT [${TCAST_FLAKE_ROOT}]: " || continue
                        [[ -n "$REPLY" ]] && tcast_conf_set switch FLAKE_ROOT "$REPLY" && TCAST_FLAKE_ROOT="$REPLY"
                        ;;
                    "set flake host attr")
                        tcast_ui_ask "TCAST_FLAKE_HOST [${TCAST_FLAKE_HOST}]: " || continue
                        [[ -n "$REPLY" ]] && tcast_conf_set switch FLAKE_HOST "$REPLY" && TCAST_FLAKE_HOST="$REPLY"
                        ;;
                    "set remote ref")
                        tcast_ui_ask "TCAST_FLAKE_REF [${TCAST_FLAKE_REF}]: " || continue
                        [[ -n "$REPLY" ]] && tcast_conf_set switch FLAKE_REF "$REPLY" && TCAST_FLAKE_REF="$REPLY"
                        ;;
                    "show GIT_SSH_COMMAND hint")
                        echo "export GIT_SSH_COMMAND=$(command -v tcast-git-ssh 2>/dev/null || echo tcast-git-ssh)"
                        echo "map: $(tcast_git_map_path)"
                        ;;
                    quit) return 0 ;;
                esac
            done
            ;;
        list|ls) _tcast_switch_map_list ;;
        add|init) shift; tcast_git_ssh_init "$@" ;;
        remove|rm) shift; _tcast_switch_map_remove "$@" ;;
        hint)
            echo "export GIT_SSH_COMMAND=$(command -v tcast-git-ssh 2>/dev/null || echo tcast-git-ssh)"
            echo "map: $(tcast_git_map_path)"
            echo "conf: $(tcast_conf_path switch)"
            ;;
        -h|--help|help)
            cat <<'EOF'
tcast switch --config — deploy-key map + flake settings for switch

  tcast switch --config              interactive menu
  tcast switch --config list
  tcast switch --config add owner/repo /path/to/key
  tcast switch --config remove owner/repo
  tcast switch --config hint

Durable files (survive package upgrades):
  $TCAST_CONFIG_DIR/switch.conf
  $TCAST_CONFIG_DIR/git.map
EOF
            ;;
        *)
            tcast_die "unknown switch --config command: $1"
            ;;
    esac
}

_tcast_switch_park_hostfacts() {
    local flake_root="$1" host_name="$2"
    local host_dir stash_dir="" f
    host_dir=$(find hosts -mindepth 2 -maxdepth 2 -type d -name "$host_name" 2>/dev/null | head -1 || true)
    if [[ -n "$host_dir" ]]; then
        for f in facter.json hardware-configuration.nix nds-boot.nix machine.nix; do
            [[ -f "${host_dir}/${f}" ]] || continue
            if git check-ignore -q "${host_dir}/${f}" 2>/dev/null \
                || ! git ls-files --error-unmatch "${host_dir}/${f}" &>/dev/null; then
                stash_dir="${stash_dir:-$(mktemp -d /tmp/tc-switch-hostfacts.XXXXXX)}"
                mkdir -p "${stash_dir}/${host_dir}"
                mv "${host_dir}/${f}" "${stash_dir}/${host_dir}/"
                tcast_info "parked ${host_dir}/${f} -> ${stash_dir}"
            fi
        done
    fi
    printf '%s\n' "$stash_dir"
}

_tcast_switch_restore_hostfacts() {
    local flake_root="$1" stash_dir="$2" parked rel
    [[ -n "$stash_dir" && -d "$stash_dir" ]] || return 0
    while IFS= read -r -d '' parked; do
        rel="${parked#"${stash_dir}/"}"
        if [[ -e "${flake_root}/${rel}" ]]; then
            tcast_info "keeping remote ${rel}; parked copy at ${parked}"
        else
            mkdir -p "$(dirname "${flake_root}/${rel}")"
            mv "$parked" "${flake_root}/${rel}"
            tcast_info "restored ${rel}"
        fi
    done < <(find "$stash_dir" -type f -print0 2>/dev/null)
    rm -rf "$stash_dir"
}

tcast_cmd_switch() {
    local wrap ahead behind stash_dir branch force=0
    local flake_root host_name remote_ref
    local -a rest=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)
                shift
                tcast_env_init
                tcast_switch_config "$@"
                return $?
                ;;
            --force|-f)
                force=1
                shift
                ;;
            -h|--help|help)
                cat <<'EOF'
tcast switch — pull flake checkout and nixos-rebuild switch

  tcast switch
  tcast switch --force         discard local commits/dirty files; match remote then rebuild
  tcast switch --config […]   configure map / flake root / settings

Env (override switch.conf):
  TCAST_FLAKE_ROOT   Flake root (default /etc/nixos)
  TCAST_FLAKE_HOST   nixosConfigurations attr
  TCAST_FLAKE_REF    Remote ref (default origin/main)

Updates of the tc package: flake lock + rebuild (no curl self-update).
EOF
                return 0
                ;;
            *)
                rest+=("$1")
                shift
                ;;
        esac
    done
    [[ ${#rest[@]} -eq 0 ]] || tcast_die "unknown argument: ${rest[0]} (try: tcast switch --help)"

    tcast_need_root switch
    tcast_env_init
    flake_root="${TCAST_FLAKE_ROOT}"
    host_name="${TCAST_FLAKE_HOST}"
    remote_ref="${TCAST_FLAKE_REF}"

    [[ -d "$flake_root" ]] || tcast_die "flake root missing: ${flake_root}"
    [[ -d "${flake_root}/.git" ]] || tcast_die "not a git checkout: ${flake_root}"

    if wrap="$(tcast_resolve_git_ssh)"; then
        export GIT_SSH_COMMAND="$wrap"
    fi

    cd "$flake_root" || tcast_die "cannot cd to ${flake_root}"

    if [[ -z "$(git config --local user.email 2>/dev/null || true)" ]]; then
        git config --local user.email "tc@$(hostname -s 2>/dev/null || echo host)"
    fi
    if [[ -z "$(git config --local user.name 2>/dev/null || true)" ]]; then
        git config --local user.name "tc"
    fi

    if git rev-parse --is-shallow-repository 2>/dev/null | grep -qx true; then
        tcast_info "unshallowing clone for updates"
        git fetch --unshallow origin 2>/dev/null || git fetch origin
    else
        git fetch origin
    fi

    ahead=$(git rev-list --count "${remote_ref}..HEAD" 2>/dev/null || echo 0)
    behind=$(git rev-list --count "HEAD..${remote_ref}" 2>/dev/null || echo 0)

    if [[ "$force" -eq 1 ]]; then
        stash_dir="$(_tcast_switch_park_hostfacts "$flake_root" "$host_name")"
        tcast_info "force: reset --hard ${remote_ref}"
        git reset --hard "$remote_ref" || tcast_die "git reset --hard failed"
        git clean -fd -e hosts || true
        _tcast_switch_restore_hostfacts "$flake_root" "$stash_dir"
    else
        if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
            tcast_die "local changes in ${flake_root}
Use:  tcast switch --force   (discards local edits; matches ${remote_ref})"
        fi
        if [[ "${ahead:-0}" -gt 0 ]]; then
            tcast_die "local branch is ahead of ${remote_ref} by ${ahead} commit(s).
Use:  tcast switch --force   (reset to ${remote_ref} then rebuild)"
        fi

        if [[ "${behind:-0}" -eq 0 ]]; then
            tcast_info "already up to date with ${remote_ref}"
        else
            tcast_info "fast-forward ${behind} commit(s) from ${remote_ref}"
            stash_dir="$(_tcast_switch_park_hostfacts "$flake_root" "$host_name")"
            branch="${remote_ref#origin/}"
            if ! git pull --ff-only origin "$branch"; then
                [[ -n "$stash_dir" ]] && tcast_info "host facts parked at ${stash_dir}"
                tcast_die "fast-forward failed — try: tcast switch --force"
            fi
            _tcast_switch_restore_hostfacts "$flake_root" "$stash_dir"
        fi
    fi

    if _tcast_switch_in_progress; then
        tcast_die "switch-to-configuration already running (comin deploy?). retry when idle."
    fi

    trap _tcast_switch_comin_resume EXIT
    _tcast_switch_comin_pause

    tcast_info "nixos-rebuild switch --flake ${flake_root}#${host_name}"
    nixos-rebuild switch --flake "${flake_root}#${host_name}" || tcast_die "nixos-rebuild failed"
}
