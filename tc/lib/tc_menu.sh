#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — menu / restore (profiles)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# ==================================================================================================

: "${TC_PROFILE_DIR:=${HOME}/.config/tc/profiles}"

tc_cmd_menu() {
    local choice
    echo "tc — ThunderCast host CLI"
    echo "  1) status"
    echo "  2) switch"
    echo "  3) clean"
    echo "  4) config"
    echo "  5) restore (profiles)"
    echo "  0) quit"
    if [[ ! -e /dev/tty ]]; then
        return 0
    fi
    read -rp "choice: " choice < /dev/tty
    case "$choice" in
        1) tc_cmd_status ;;
        2) tc_cmd_switch ;;
        3) tc_cmd_clean "$@" ;;
        4) tc_cmd_config ;;
        5) tc_cmd_restore ;;
        0|q) return 0 ;;
        *) tc_die "unknown choice" ;;
    esac
}

_tc_restore_save() {
    local name="${1:-}" map dest
    map="$(tc_git_map_path)"
    [[ -f "$map" ]] || tc_die "no map to save at ${map}"
    if [[ -z "$name" && -e /dev/tty ]]; then
        read -rp "profile name: " name < /dev/tty
    fi
    [[ -n "$name" ]] || tc_die "usage: tc restore save NAME"
    name="${name//[^A-Za-z0-9._-]/_}"
    mkdir -p "$TC_PROFILE_DIR"
    dest="${TC_PROFILE_DIR}/${name}.map"
    cp -f "$map" "$dest"
    chmod 600 "$dest"
    tc_info "saved ${dest}"
}

_tc_restore_load() {
    local name="${1:-}" src map
    if [[ -z "$name" && -e /dev/tty ]]; then
        echo "profiles in ${TC_PROFILE_DIR}:"
        ls -1 "$TC_PROFILE_DIR"/*.map 2>/dev/null | sed 's|.*/||;s|\.map$||' || echo "(none)"
        read -rp "profile name: " name < /dev/tty
    fi
    [[ -n "$name" ]] || tc_die "usage: tc restore load NAME"
    src="${TC_PROFILE_DIR}/${name}.map"
    [[ -f "$src" ]] || tc_die "missing profile: ${src}"
    map="$(tc_git_map_path)"
    mkdir -p "$(dirname "$map")"
    cp -f "$src" "$map"
    chmod 600 "$map"
    tc_info "loaded ${name} -> ${map}"
}

tc_cmd_restore() {
    case "${1:-}" in
        ""|menu)
            if [[ -e /dev/tty ]]; then
                local choice
                echo "tc restore"
                echo "  1) list profiles"
                echo "  2) save current map"
                echo "  3) load profile"
                echo "  0) quit"
                read -rp "choice: " choice < /dev/tty
                case "$choice" in
                    1) ls -1 "$TC_PROFILE_DIR"/*.map 2>/dev/null | sed 's|.*/||;s|\.map$||' || echo "(none)" ;;
                    2) _tc_restore_save ;;
                    3) _tc_restore_load ;;
                    0) return 0 ;;
                    *) tc_die "unknown choice" ;;
                esac
            else
                ls -1 "$TC_PROFILE_DIR"/*.map 2>/dev/null | sed 's|.*/||;s|\.map$||' || echo "(none)"
            fi
            ;;
        list|ls)
            ls -1 "$TC_PROFILE_DIR"/*.map 2>/dev/null | sed 's|.*/||;s|\.map$||' || echo "(none)"
            ;;
        save)
            shift
            _tc_restore_save "$@"
            ;;
        load)
            shift
            _tc_restore_load "$@"
            ;;
        -h|--help|help)
            cat <<'EOF'
tc restore — save/load tc-git.map profiles

  tc restore              interactive menu
  tc restore list
  tc restore save NAME
  tc restore load NAME

Profiles: $TC_PROFILE_DIR (default ~/.config/tc/profiles)
EOF
            ;;
        *)
            tc_die "unknown restore command: $1"
            ;;
    esac
}
