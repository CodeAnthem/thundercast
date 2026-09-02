#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — restore (NixOS system generations)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# Description:   Menu to list / activate previous system configurations.
# ==================================================================================================

_tcast_restore_current_gen() {
    local link
    link="$(readlink -f /nix/var/nix/profiles/system 2>/dev/null || true)"
    if [[ "$link" =~ system-([0-9]+)-link$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

_tcast_restore_list_gens() {
    if ! command -v nix-env &>/dev/null; then
        tcast_die "nix-env not found"
    fi
    nix-env -p /nix/var/nix/profiles/system --list-generations 2>/dev/null
}

_tcast_restore_activate() {
    local gen="$1" link
    [[ "$gen" =~ ^[0-9]+$ ]] || tcast_die "invalid generation: ${gen}"
    link="/nix/var/nix/profiles/system-${gen}-link"
    [[ -x "${link}/bin/switch-to-configuration" ]] \
        || tcast_die "generation ${gen} missing: ${link}"
    tcast_info "activating generation ${gen}"
    "${link}/bin/switch-to-configuration" switch
}

tcast_cmd_restore() {
    local cur label gen line
    local -a labels=() gens=()

    case "${1:-}" in
        -h|--help|help)
            cat <<'EOF'
tcast restore — pick a previous NixOS system configuration

  tcast restore              interactive menu (current + other generations)
  tcast restore list         print generations
  tcast restore <N>          activate generation N
  tcast restore --rollback   activate previous generation (nixos-rebuild --rollback)

Requires root (sudo tcast restore).
EOF
            return 0
            ;;
        list|ls)
            tcast_need_root restore
            cur="$(_tcast_restore_current_gen || echo '?')"
            echo "current generation: ${cur}"
            _tcast_restore_list_gens
            return 0
            ;;
        --rollback|rollback)
            tcast_need_root restore
            tcast_info "nixos-rebuild --rollback"
            nixos-rebuild --rollback
            return $?
            ;;
        "")
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                tcast_need_root restore
                _tcast_restore_activate "$1"
                return $?
            fi
            tcast_die "unknown restore argument: $1 (try: tcast restore --help)"
            ;;
    esac

    tcast_need_root restore
    cur="$(_tcast_restore_current_gen || echo '?')"
    tcast_ui_section "tcast restore — system generations"
    echo "  current: ${cur}"
    echo

    while IFS= read -r line || [[ -n "${line:-}" ]]; do
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ^[[:space:]]*([0-9]+) ]]; then
            gen="${BASH_REMATCH[1]}"
            gens+=("$gen")
            if [[ "$gen" == "$cur" ]]; then
                labels+=("${gen} (current)  ${line#"${BASH_REMATCH[0]}"}")
            else
                labels+=("${gen}  ${line#"${BASH_REMATCH[0]}"}")
            fi
        fi
    done < <(_tcast_restore_list_gens)

    [[ ${#gens[@]} -gt 0 ]] || tcast_die "no system generations found"

    labels+=("quit")
    if ! tcast_ui_menu "Activate generation" "${labels[@]}"; then
        return 0
    fi
    label="$REPLY"
    [[ "$label" == quit ]] && return 0
    gen="${label%% *}"
    [[ "$gen" == "$cur" ]] && {
        tcast_info "already on generation ${cur}"
        return 0
    }
    _tcast_restore_activate "$gen"
}
