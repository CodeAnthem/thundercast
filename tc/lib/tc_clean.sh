#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — clean (generations + GC)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# Env:           TC_CLEAN_KEEP_GENS, TC_CLEAN_OLDER_THAN
# ==================================================================================================

tc_cmd_clean() {
    local keep_gens="${TC_CLEAN_KEEP_GENS:-2}"
    local older_than="${TC_CLEAN_OLDER_THAN:-7d}"
    local dry_run=0 optimise=0

    _tc_clean_run() {
        if [[ "$dry_run" -eq 1 ]]; then
            tc_info "[dry-run] $*"
        else
            tc_info "$*"
            "$@"
        fi
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=1; shift ;;
            --keep-gens)
                [[ $# -ge 2 ]] || tc_die "--keep-gens requires a number"
                keep_gens="$2"
                shift 2
                ;;
            --older-than)
                [[ $# -ge 2 ]] || tc_die "--older-than requires a value"
                older_than="$2"
                shift 2
                ;;
            --optimise) optimise=1; shift ;;
            -h|--help)
                cat <<EOF
tc clean — remove unused Nix store paths and old system generations.

Options:
  --dry-run          Print actions without executing
  --keep-gens N      Keep N system generations (default: ${keep_gens})
  --older-than T     Passed to nix-collect-garbage (default: ${older_than})
  --optimise         Run nix store optimise after garbage collection
EOF
                return 0
                ;;
            *)
                tc_die "unknown option: $1 (try: tc clean --help)"
                ;;
        esac
    done

    [[ "$(id -u)" -eq 0 ]] || tc_die "run as root"

    shopt -s nullglob
    for d in /tmp/tc-switch-hostfacts.* /tmp/nds-switch-hostfacts.*; do
        [[ -d "$d" ]] || continue
        _tc_clean_run rm -rf "$d"
    done

    if command -v nix-env &>/dev/null; then
        _tc_clean_run nix-env -p /nix/var/nix/profiles/system --delete-generations "+${keep_gens}"
    fi

    if command -v nix-collect-garbage &>/dev/null; then
        _tc_clean_run nix-collect-garbage --delete-older-than "$older_than"
        _tc_clean_run nix-collect-garbage -d
    fi

    if [[ "$optimise" -eq 1 ]] && command -v nix &>/dev/null; then
        _tc_clean_run nix store optimise
    fi

    tc_info "done"
}
