# ==================================================================================================
# Thundercast - toolkit menus
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-20
# ==================================================================================================

tcast_menu_status() {
    tcast_leaf_require
    tcast_leaf_fetch
    tcast_register_ensure_defaults
    tcast_ui_section "Status"
    tcast_ui_blank
    tcast_ui_line "nds-switch / NixOS: /etc/nixos"
    tcast_ui_line "comin clone:        /var/lib/comin/repository"
    tcast_ui_line "toolkit leaf:       $(tcast_leaf)"
    tcast_ui_line "leaf rev:           $(tcast_leaf_status_line)"
    if tcast_operator_ready; then
        tcast_ui_line "operator:           registered"
    else
        tcast_ui_line "operator:           not registered (Sops → Operator → Init)"
    fi
    tcast_ui_line "operator init:     $(tcast_register_meta_get initialized_at 2>/dev/null || echo never)"
    tcast_ui_line "operator rotated:  $(tcast_register_meta_get last_rotated_at 2>/dev/null || echo never)"
    tcast_ui_line "last host joined:  $(tcast_register_meta_get last_enrolled_host 2>/dev/null || echo —)  $(tcast_register_meta_get last_enrolled_at 2>/dev/null || true)"
    tcast_ui_line "last recipients:   $(tcast_register_meta_get last_recipients_at 2>/dev/null || echo never)"
    tcast_ui_line "last secret value: $(tcast_register_meta_get last_secret_value_at 2>/dev/null || echo never)"
    tcast_ui_line "last node age rot: $(tcast_register_meta_get last_node_age_rotate_at 2>/dev/null || echo never)"
    tcast_ui_blank
    tcast_ui_line "health:"
    tcast_sops_health | sed 's/^/    /' >&2 || true
    tcast_ui_blank
    tcast_ui_pause
}

tcast_menu_update() {
    local dest src local_ver remote_ver choice
    dest="${TCAST_TOOLKIT_DEST:-/var/lib/nds-toolkit}"
    src="${dest}/src"
    tcast_ui_section "Update tools"
    tcast_ui_blank
    local_ver="$(tcast_toolkit_version)"
    tcast_ui_line "installed: ${local_ver}"
    if [[ -d "${src}/.git" ]]; then
        tcast_ui_line "git:      $(git -C "$src" rev-parse --short HEAD 2>/dev/null || echo unknown)"
        tcast_ui_line "origin:   $(git -C "$src" remote get-url origin 2>/dev/null || echo none)"
    fi
    tcast_ui_blank
    tcast_ui_print_menu "Update now (changelog + confirm)"
    tcast_ui_pick "${TCAST_UI_LAST_MAX}"
    choice="$TCAST_UI_CHOICE"
    case "$choice" in
        1)
            if command -v toolkit-update >/dev/null; then
                toolkit-update || true
            else
                tcast_ui_line "toolkit-update wrapper not on PATH"
            fi
            tcast_ui_pause
            ;;
        0|q) return 0 ;;
    esac
}

tcast_menu_nodes_list() {
    local h role pub
    tcast_ui_section "Nodes — inventory"
    tcast_ui_blank
    tcast_ui_line "roles: $(tcast_nodes_roles | tr '\n' ' ')"
    tcast_ui_blank
    tcast_ui_line "register:"
    while IFS= read -r h; do
        [[ -n "$h" ]] || continue
        role="$(tcast_register_host_get "$h" role 2>/dev/null || echo ?)"
        pub="$(tcast_register_host_get "$h" age_pub 2>/dev/null || echo none)"
        [[ "$pub" == age1* ]] && pub="age1…${pub: -6}"
        tcast_ui_line "  ${h}  role=${role}  age=${pub}"
    done < <(tcast_register_host_list)
    tcast_ui_blank
    tcast_ui_line "host folders:"
    tcast_nodes_host_dirs | sed 's/^/    /' >&2
    tcast_ui_pause
}

tcast_menu_nodes_add() {
    local roles=() r hostname role system n i choice
    tcast_ui_section "Nodes — add from role"
    tcast_ui_blank
    mapfile -t roles < <(tcast_nodes_roles)
    if ((${#roles[@]} == 0)); then
        tcast_ui_line "no .roles/ in the leaf clone"
        tcast_ui_pause
        return 0
    fi
    tcast_ui_print_menu "${roles[@]}"
    tcast_ui_pick "${TCAST_UI_LAST_MAX}"
    choice="$TCAST_UI_CHOICE"
    [[ "$choice" == "0" || "$choice" == "q" ]] && return 0
    role="${roles[$((choice - 1))]}"
    tcast_ui_read_line 'Hostname: '
    hostname="$TCAST_UI_LINE"
    [[ -n "$hostname" ]] || return 0
    tcast_ui_read_line 'System [x86_64-linux]: '
    system="$TCAST_UI_LINE"
    system="${system:-x86_64-linux}"
    tcast_nodes_scaffold "$hostname" "$role" "$system"
    tcast_ui_line "Use Apply & push under Sops when ready. Install from Nodes → Install."
    tcast_ui_pause
}

tcast_menu_nodes_install() {
    local hosts=() choice host
    tcast_ui_section "Nodes — install / restore"
    tcast_ui_blank
    tcast_ui_line "Install from this VM (nixos-anywhere) is not in this tools VERSION."
    tcast_ui_line "After Apply & push, run NDS remoteAction on the target with FLAKE_HOST set."
    tcast_ui_line "Restore: copy the host backup zip onto the ISO; NDS restore uses nds-restore.env."
    tcast_ui_blank
    mapfile -t hosts < <(tcast_nodes_host_dirs)
    if ((${#hosts[@]} == 0)); then
        tcast_ui_pause
        return 0
    fi
    tcast_ui_print_menu "${hosts[@]}"
    tcast_ui_pick "${TCAST_UI_LAST_MAX}"
    choice="$TCAST_UI_CHOICE"
    [[ "$choice" == "0" || "$choice" == "q" ]] && return 0
    host="${hosts[$((choice - 1))]}"
    tcast_ui_line "selected ${host} — push the leaf, then install with NDS (existing host)."
    tcast_ui_pause
}

tcast_menu_nodes() {
    local choice
    while true; do
        tcast_ui_section "Nodes"
        tcast_ui_blank
        tcast_ui_print_menu \
            "Inventory" \
            "Add host from role" \
            "Install / restore (NDS on target)"
        tcast_ui_pick "${TCAST_UI_LAST_MAX}"
        choice="$TCAST_UI_CHOICE"
        case "$choice" in
            1) tcast_menu_nodes_list ;;
            2) tcast_menu_nodes_add ;;
            3) tcast_menu_nodes_install ;;
            0|q) return 0 ;;
        esac
    done
}

tcast_menu_sops_secrets() {
    local choice scopes=() id host rel key val
    while true; do
        tcast_ui_section "Sops — secrets"
        tcast_ui_blank
        tcast_ui_print_menu "Add / encrypt" "Change value" "Remove file"
        tcast_ui_pick "${TCAST_UI_LAST_MAX}"
        choice="$TCAST_UI_CHOICE"
        case "$choice" in
            1)
                mapfile -t scopes < <(tcast_register_scope_list)
                tcast_ui_section "Sops — add secret"
                tcast_ui_print_menu "${scopes[@]}"
                tcast_ui_pick "${TCAST_UI_LAST_MAX}"
                choice="$TCAST_UI_CHOICE"
                [[ "$choice" == "0" || "$choice" == "q" ]] && continue
                id="${scopes[$((choice - 1))]}"
                host=""
                if [[ "$(tcast_register_scope_get "$id" type 2>/dev/null || true)" == "host" ]]; then
                    tcast_ui_read_line 'Hostname: '
                    host="$TCAST_UI_LINE"
                fi
                rel="$(tcast_sops_scope_path "$id" "$host")" || { tcast_ui_line "cannot resolve path"; tcast_ui_pause; continue; }
                tcast_ui_read_line 'YAML key [value]: '
                key="$TCAST_UI_LINE"
                key="${key:-value}"
                tcast_ui_read_secret 'Secret value: '
                val="$TCAST_UI_LINE"
                tcast_sops_put_value "$rel" "$key" "$val"
                tcast_ui_line "encrypted ${rel} — Apply & push when ready"
                tcast_ui_pause
                ;;
            2)
                tcast_ui_read_line 'Relative path (secrets/…): '
                rel="$TCAST_UI_LINE"
                [[ -n "$rel" ]] || continue
                tcast_ui_read_line 'YAML key [value]: '
                key="$TCAST_UI_LINE"
                key="${key:-value}"
                tcast_ui_read_secret 'New value: '
                val="$TCAST_UI_LINE"
                tcast_sops_put_value "$rel" "$key" "$val"
                tcast_ui_pause
                ;;
            3)
                tcast_ui_read_line 'Relative path to delete: '
                rel="$TCAST_UI_LINE"
                [[ -n "$rel" ]] || continue
                tcast_sops_remove_file "$rel" && tcast_ui_line "removed ${rel}"
                tcast_ui_pause
                ;;
            0|q) return 0 ;;
        esac
    done
}

tcast_menu_sops_scopes() {
    local choice scopes=() id host pub
    while true; do
        tcast_ui_section "Sops — scopes"
        tcast_ui_blank
        while IFS= read -r id; do
            [[ -n "$id" ]] || continue
            tcast_ui_line "${id}: $(tcast_register_scope_get "$id" members 2>/dev/null || echo —)"
        done < <(tcast_register_scope_list)
        tcast_ui_blank
        tcast_ui_print_menu "Add node pubkey to a scope" "Remove node from a scope"
        tcast_ui_pick "${TCAST_UI_LAST_MAX}"
        choice="$TCAST_UI_CHOICE"
        case "$choice" in
            1)
                mapfile -t scopes < <(tcast_register_scope_list)
                tcast_ui_print_menu "${scopes[@]}"
                tcast_ui_pick "${TCAST_UI_LAST_MAX}"
                choice="$TCAST_UI_CHOICE"
                [[ "$choice" == "0" || "$choice" == "q" ]] && continue
                id="${scopes[$((choice - 1))]}"
                tcast_ui_read_line 'Hostname: '
                host="$TCAST_UI_LINE"
                tcast_ui_read_line 'age1… pubkey: '
                pub="$TCAST_UI_LINE"
                tcast_nodes_enroll_age "$host" "$pub"
                tcast_register_scope_add_member "$id" "$host"
                tcast_sops_write_policy
                tcast_ui_line "added ${host} to ${id} — Apply & push to updatekeys"
                tcast_ui_pause
                ;;
            2)
                mapfile -t scopes < <(tcast_register_scope_list)
                tcast_ui_print_menu "${scopes[@]}"
                tcast_ui_pick "${TCAST_UI_LAST_MAX}"
                choice="$TCAST_UI_CHOICE"
                [[ "$choice" == "0" || "$choice" == "q" ]] && continue
                id="${scopes[$((choice - 1))]}"
                tcast_ui_read_line 'Hostname to remove: '
                host="$TCAST_UI_LINE"
                tcast_register_scope_remove_member "$id" "$host"
                tcast_sops_write_policy
                tcast_ui_pause
                ;;
            0|q) return 0 ;;
        esac
    done
}

tcast_menu_sops_operator() {
    local choice
    tcast_ui_section "Sops — operator"
    tcast_ui_blank
    tcast_ui_line "private key: ${TCAST_TOOLKIT_OP_KEY}"
    tcast_ui_line "never copied to git"
    tcast_ui_blank
    if tcast_operator_ready; then
        tcast_ui_print_menu "Init (create if missing)" "Rotate operator key"
        tcast_ui_pick "${TCAST_UI_LAST_MAX}"
        choice="$TCAST_UI_CHOICE"
        case "$choice" in
            1) tcast_sops_operator_init; tcast_ui_pause ;;
            2)
                tcast_ui_yesno "Rotate operator key? Overlap until comin." || return 0
                tcast_sops_operator_rotate
                tcast_ui_pause
                ;;
            0|q) return 0 ;;
        esac
        return 0
    fi
    tcast_ui_print_menu "Init (create if missing)"
    tcast_ui_pick "${TCAST_UI_LAST_MAX}"
    choice="$TCAST_UI_CHOICE"
    case "$choice" in
        1) tcast_sops_operator_init; tcast_ui_pause ;;
        0|q) return 0 ;;
    esac
}

tcast_menu_sops_apply() {
    tcast_ui_section "Sops — apply & push"
    tcast_ui_blank
    tcast_git_status_short | sed 's/^/    /' >&2
    tcast_ui_blank
    tcast_ui_yesno "Validate, updatekeys, commit, push?" || return 0
    tcast_sops_apply_recipients
    tcast_git_commit_push "toolkit: apply sops/register" || tcast_ui_line "push failed"
    tcast_ui_pause
}

tcast_menu_sops() {
    local choice
    while true; do
        tcast_ui_section "Sops"
        tcast_ui_blank
        if tcast_operator_ready; then
            tcast_ui_print_menu \
                "Secrets (add / change / remove)" \
                "Scopes (enroll / unenroll age pubs)" \
                "Operator (init / rotate)" \
                "Apply & push (encrypt/updatekeys + git)"
            tcast_ui_pick "${TCAST_UI_LAST_MAX}"
            choice="$TCAST_UI_CHOICE"
            case "$choice" in
                1) tcast_menu_sops_secrets ;;
                2) tcast_menu_sops_scopes ;;
                3) tcast_menu_sops_operator ;;
                4) tcast_menu_sops_apply ;;
                0|q) return 0 ;;
            esac
        else
            tcast_ui_line "No operator key registered on this console."
            tcast_ui_line "Secrets, scopes, and apply stay hidden until Init."
            tcast_ui_blank
            tcast_ui_print_menu "Operator (init)"
            tcast_ui_pick "${TCAST_UI_LAST_MAX}"
            choice="$TCAST_UI_CHOICE"
            case "$choice" in
                1) tcast_menu_sops_operator ;;
                0|q) return 0 ;;
            esac
        fi
    done
}

# Description: Origin moved and local edits touch the same files.
tcast_menu_leaf_collision() {
    local choice f
    tcast_ui_section "Leaf git"
    tcast_ui_blank
    tcast_ui_line "Unsaved changes overlap incoming commits (${TCAST_LEAF_BEHIND:-?} behind $(tcast_leaf_remote_ref))."
    tcast_ui_line "Reset discards them. Keep editing, then Sops → Apply & push."
    tcast_ui_blank
    tcast_ui_line "overlapping files:"
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        tcast_ui_line "  ${f}"
    done <<< "${TCAST_LEAF_COLLISIONS:-}"
    tcast_ui_blank
    tcast_ui_print_menu \
        "Discard local changes and sync" \
        "Keep editing (Apply & push when ready)"
    tcast_ui_pick "${TCAST_UI_LAST_MAX}"
    choice="$TCAST_UI_CHOICE"
    case "$choice" in
        1)
            tcast_leaf_reset_to_origin
            tcast_info "leaf reset to $(tcast_leaf_remote_ref)"
            tcast_ui_pause
            ;;
        2)
            tcast_ui_line "Keeping local edits. Save with Sops → Apply & push, then restart toolkit to sync."
            tcast_ui_pause
            ;;
        *)
            tcast_ui_line "Staying behind origin until you sync or Apply & push."
            tcast_ui_pause
            ;;
    esac
}

tcast_menu_leaf_sync() {
    tcast_leaf_require
    tcast_leaf_sync
    [[ "${TCAST_LEAF_SYNC_NEED_PROMPT:-0}" == 1 ]] || return 0
    if tcast_ui_batch; then
        tcast_info "leaf is ${TCAST_LEAF_BEHIND:-?} behind with unsaved changes — not auto-pulling"
        return 0
    fi
    tcast_menu_leaf_collision
}

tcast_menu_main() {
    local choice sops_label
    tcast_leaf_require
    tcast_menu_leaf_sync
    tcast_register_ensure_defaults
    while true; do
        tcast_ui_section "Main"
        tcast_ui_blank
        if tcast_operator_ready; then
            sops_label="Sops"
        else
            sops_label="Sops (operator init only)"
        fi
        printf '    1) Status\n' >&2
        printf '    2) Nodes\n' >&2
        printf '    3) %s\n' "$sops_label" >&2
        printf '    4) Update tools\n' >&2
        printf '    q) Quit\n' >&2
        tcast_ui_read_key '  Choice: '
        choice="$TCAST_UI_KEY"
        case "${choice,,}" in
            1) tcast_menu_status ;;
            2) tcast_menu_nodes ;;
            3) tcast_menu_sops ;;
            4) tcast_menu_update ;;
            q|0) exit 0 ;;
            *) tcast_ui_line "1-4 or q" ;;
        esac
    done
}
