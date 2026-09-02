#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — clean (generations + GC) + --config
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# Config file:   $TCAST_CONFIG_DIR/clean.conf
# ==================================================================================================

tcast_clean_config() {
    case "${1:-}" in
        ""|menu)
            while true; do
                tcast_ui_section "tcast clean --config"
                echo "  KEEP_GENS=${TCAST_CLEAN_KEEP_GENS:-2}  OLDER_THAN=${TCAST_CLEAN_OLDER_THAN:-7d}"
                if ! tcast_ui_menu "Clean settings" \
                    "set keep generations" \
                    "set older-than" \
                    "quit"
                then
                    return 0
                fi
                case "$REPLY" in
                    "set keep generations")
                        tcast_ui_ask "KEEP_GENS [${TCAST_CLEAN_KEEP_GENS:-2}]: " || continue
                        [[ -n "$REPLY" ]] && tcast_conf_set clean KEEP_GENS "$REPLY" && TCAST_CLEAN_KEEP_GENS="$REPLY"
                        ;;
                    "set older-than")
                        tcast_ui_ask "OLDER_THAN [${TCAST_CLEAN_OLDER_THAN:-7d}]: " || continue
                        [[ -n "$REPLY" ]] && tcast_conf_set clean OLDER_THAN "$REPLY" && TCAST_CLEAN_OLDER_THAN="$REPLY"
                        ;;
                    quit) return 0 ;;
                esac
            done
            ;;
        -h|--help|help)
            cat <<'EOF'
tcast clean --config — durable GC defaults

  tcast clean --config

File: $TCAST_CONFIG_DIR/clean.conf (survives package upgrades)
EOF
            ;;
        *)
            tcast_die "unknown clean --config command: $1"
            ;;
    esac
}

tcast_cmd_clean() {
    local keep_gens older_than dry_run=0 optimise=0

    case "${1:-}" in
        --config)
            shift
            tcast_conf_apply_clean_env
            : "${TCAST_CLEAN_KEEP_GENS:=2}"
            : "${TCAST_CLEAN_OLDER_THAN:=7d}"
            tcast_clean_config "$@"
            return $?
            ;;
    esac

    tcast_conf_apply_clean_env
    keep_gens="${TCAST_CLEAN_KEEP_GENS:-2}"
    older_than="${TCAST_CLEAN_OLDER_THAN:-7d}"

    _tcast_clean_run() {
        if [[ "$dry_run" -eq 1 ]]; then
            tcast_info "[dry-run] $*"
        else
            tcast_info "$*"
            "$@"
        fi
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=1; shift ;;
            --keep-gens)
                [[ $# -ge 2 ]] || tcast_die "--keep-gens requires a number"
                keep_gens="$2"
                shift 2
                ;;
            --older-than)
                [[ $# -ge 2 ]] || tcast_die "--older-than requires a value"
                older_than="$2"
                shift 2
                ;;
            --optimise) optimise=1; shift ;;
            -h|--help)
                cat <<EOF
tcast clean — remove unused Nix store paths and old system generations.

  tcast clean [--dry-run] [--keep-gens N] [--older-than T] [--optimise]
  tcast clean --config

Defaults from \$TCAST_CONFIG_DIR/clean.conf when set (else keep=${keep_gens}, older=${older_than}).
EOF
                return 0
                ;;
            *)
                tcast_die "unknown option: $1 (try: tcast clean --help)"
                ;;
        esac
    done

    tcast_need_root clean

    shopt -s nullglob
    for d in /tmp/tc-switch-hostfacts.* /tmp/nds-switch-hostfacts.*; do
        [[ -d "$d" ]] || continue
        _tcast_clean_run rm -rf "$d"
    done

    if command -v nix-env &>/dev/null; then
        _tcast_clean_run nix-env -p /nix/var/nix/profiles/system --delete-generations "+${keep_gens}"
    fi

    if command -v nix-collect-garbage &>/dev/null; then
        _tcast_clean_run nix-collect-garbage --delete-older-than "$older_than"
        _tcast_clean_run nix-collect-garbage -d
    fi

    if [[ "$optimise" -eq 1 ]] && command -v nix &>/dev/null; then
        _tcast_clean_run nix store optimise
    fi

    tcast_info "done"
}
