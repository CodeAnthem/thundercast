#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — config (tc-git.map + hints)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# Description:   Minimal interactive map editor (not settingsManager).
# ==================================================================================================

_tc_config_list() {
    local map
    map="$(tc_git_map_path)"
    echo "map: ${map}"
    if [[ ! -f "$map" ]]; then
        echo "(empty — no file yet)"
        return 0
    fi
    if ! grep -qE '^[^#[:space:]]' "$map" 2>/dev/null; then
        echo "(no entries)"
        return 0
    fi
    grep -vE '^(#|$)' "$map" | while IFS=$'\t' read -r repo key; do
        printf '  %s\t%s\n' "$repo" "$key"
    done
}

_tc_config_remove() {
    local map repo tmp
    map="$(tc_git_map_path)"
    [[ -f "$map" ]] || tc_die "no map at ${map}"
    if [[ -n "${1:-}" ]]; then
        repo="${1,,}"
    elif [[ -e /dev/tty ]]; then
        read -rp "owner/repo to remove: " repo < /dev/tty
        repo="${repo,,}"
    else
        tc_die "usage: tc config remove owner/repo"
    fi
    [[ -n "$repo" ]] || tc_die "owner/repo required"
    tmp="$(mktemp)"
    grep -v "^${repo}"$'\t' "$map" >"$tmp" || true
    mv "$tmp" "$map"
    chmod 600 "$map"
    tc_info "removed ${repo} (if present)"
}

_tc_config_menu() {
    local choice
    while true; do
        echo
        echo "tc config"
        echo "  1) list map"
        echo "  2) add repo key"
        echo "  3) remove repo"
        echo "  4) show GIT_SSH_COMMAND hint"
        echo "  0) quit"
        if [[ -e /dev/tty ]]; then
            read -rp "choice: " choice < /dev/tty
        else
            return 0
        fi
        case "$choice" in
            1) _tc_config_list ;;
            2) tc_git_ssh_init ;;
            3) _tc_config_remove ;;
            4)
                echo "export GIT_SSH_COMMAND=$(command -v tc-git-ssh 2>/dev/null || echo tc-git-ssh)"
                echo "map: $(tc_git_map_path)"
                ;;
            0|q|quit) return 0 ;;
            *) echo "unknown choice" ;;
        esac
    done
}

tc_cmd_config() {
    case "${1:-}" in
        "")
            _tc_config_menu
            ;;
        list|ls)
            _tc_config_list
            ;;
        add|init)
            shift
            tc_git_ssh_init "$@"
            ;;
        remove|rm)
            shift
            _tc_config_remove "$@"
            ;;
        hint)
            echo "export GIT_SSH_COMMAND=$(command -v tc-git-ssh 2>/dev/null || echo tc-git-ssh)"
            echo "map: $(tc_git_map_path)"
            ;;
        -h|--help|help)
            cat <<'EOF'
tc config — manage deploy-key map for private flake inputs

  tc config              interactive menu
  tc config list         show tc-git.map
  tc config add …        add owner/repo + key (same as: tc git-ssh init)
  tc config remove …     remove owner/repo
  tc config hint         print GIT_SSH_COMMAND export line
EOF
            ;;
        *)
            tc_die "unknown config command: $1 (try: tc config --help)"
            ;;
    esac
}
