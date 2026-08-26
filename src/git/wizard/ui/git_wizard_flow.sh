#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard flow (menu state machine)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-26
# Description:   Per-repo conversation: existing-key y/n, then paste/path or gh/generate.
#                Related-repo coverage is asked only after flake inputs are known.
# ==================================================================================================

# Description: Ask whether the installed machine should keep private-git SSH access.
# Skipped when GIT_PERSIST_ACCESS or NDS_GIT_PERSIST_ACCESS is already true/false.
nds_git_wizard_ask_persist_access() {
    local existing normalized rc
    existing="$(nds_feat_cfg_get GIT_PERSIST_ACCESS 2>/dev/null || true)"
    [[ -z "$existing" ]] && existing="${NDS_GIT_PERSIST_ACCESS:-}"
    normalized="$(_nds_git_persist_normalize "$existing")"
    if [[ -n "$normalized" ]]; then
        nds_feat_cfg_set GIT_PERSIST_ACCESS "$normalized"
        return 0
    fi

    nds_cfg_section_title "Keep repository access on the installed machine?"
    nds_ui_b "Yes: copy SSH keys and nds-switch onto the machine so nixos-rebuild can fetch private flakes."
    nds_ui_b "No:  keys stay on this ISO. nds-switch is not installed."
    nds_ui_b ""
    nds_aa_ask_numbered_choice GIT_PERSIST_ACCESS \
        "yes|no" \
        "yes=Keep access on the installed machine|no=Install-time access only (do not copy keys or nds-switch)" \
        "yes" \
        true
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    if [[ "$(nds_feat_cfg_get GIT_PERSIST_ACCESS)" == "yes" ]]; then
        nds_feat_cfg_set GIT_PERSIST_ACCESS "true"
    else
        nds_feat_cfg_set GIT_PERSIST_ACCESS "false"
    fi
    return 0
}

# Description: Ask whether this repository already has a private key (y/n, default n).
# Does not inherit GIT_EXISTING_KEY from a previous repo in this session.
nds_git_wizard_ask_key_source() {
    local default="false" confirm

    if [[ -n "${NDS_GIT_IMPORT_KEY:-}" || -n "${NDS_GIT_IMPORT_KEY_PATH:-}" \
        || -n "${NDS_DEPLOY_KEY_PATH:-}" ]]; then
        default="true"
    fi

    if nds_mode_is_unattended; then
        nds_feat_cfg_set GIT_EXISTING_KEY "$default"
    else
        while true; do
            if [[ "$default" == "true" ]]; then
                nds_ui_tty_read -rsn1 -p "${NDS_UI_INDENT_I}Have an existing private key? [y] (y/n): " confirm
            else
                nds_ui_tty_read -rsn1 -p "${NDS_UI_INDENT_I}Have an existing private key? [n] (y/n): " confirm
            fi
            echo >&2
            case "${confirm,,}" in
                y)
                    nds_feat_cfg_set GIT_EXISTING_KEY true
                    break
                    ;;
                n)
                    nds_feat_cfg_set GIT_EXISTING_KEY false
                    break
                    ;;
                "")
                    nds_feat_cfg_set GIT_EXISTING_KEY "$default"
                    break
                    ;;
                *)
                    nds_ui_b "Press y or n"
                    ;;
            esac
        done
    fi
    if nds_feat_cfg_true GIT_EXISTING_KEY; then
        nds_feat_cfg_set GIT_KEY_SOURCE have
    else
        nds_feat_cfg_set GIT_KEY_SOURCE new
    fi
    return 0
}

# Description: Ask paste/path (existing key) or gh/generate (new key).
# Arguments:
# - is_gh: <Bool> GitHub host (adds gh option)
# Returns:
# - Sets GIT_AUTH_ROUTE; NDS_ACTION_BACK on back
nds_git_wizard_ask_auth_method() {
    local is_gh="$1"
    local existing rc default

    existing="$(nds_feat_cfg_get GIT_EXISTING_KEY 2>/dev/null || true)"
    default="$(nds_feat_cfg_get GIT_AUTH_ROUTE 2>/dev/null || true)"
    if [[ "$existing" == "true" ]]; then
        [[ "$default" == "path" ]] || default="paste"
        nds_cfg_section_title "How do you want to provide the key?"
        nds_aa_ask_numbered_choice GIT_AUTH_ROUTE \
            "paste|path" \
            "paste=Paste a private SSH key (hidden)|path=Provide a private SSH key path" \
            "$default" \
            true
    elif [[ "$is_gh" == "true" ]]; then
        [[ "$default" == "generate" ]] || default="gh"
        nds_cfg_section_title "How do you want to create the key?"
        nds_aa_ask_numbered_choice GIT_AUTH_ROUTE \
            "gh|generate" \
            "gh=Use gh CLI (existing login, or device login)|generate=Create a key (print or QR) and add it on github.com yourself" \
            "$default" \
            true
    else
        nds_feat_cfg_set GIT_AUTH_ROUTE generate
        nds_ui_b "Non-GitHub host — generate a key and register it on the forge."
        return 0
    fi
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
    return 0
}

# Description: True when this session already used gh or a gh login is active.
_nds_git_wizard_used_gh() {
    local method route
    method="$(nds_feat_cfg_get GIT_SSH_KEY_REGISTER_METHOD 2>/dev/null || true)"
    route="$(nds_feat_cfg_get GIT_AUTH_ROUTE 2>/dev/null || true)"
    [[ "$method" == "gh" || "$route" == "gh" ]] && return 0
    declare -f nds_gh_session_ready &>/dev/null && nds_gh_session_ready 2>/dev/null && return 0
    return 1
}

# Description: Ask how to cover related private repos once flake inputs are known.
# Arguments:
# - n: <Int> Number of same-owner repositories still missing access
# Returns:
# - Sets GIT_CLOSURE_COVERAGE; NDS_ACTION_BACK on back
nds_git_wizard_ask_closure_coverage() {
    local n="${1:-0}"
    local existing rc default
    existing="$(nds_feat_cfg_get GIT_CLOSURE_COVERAGE 2>/dev/null || true)"
    if [[ -n "$existing" ]]; then
        return 0
    fi

    nds_cfg_section_title "Related private repositories"
    if [[ "$n" -gt 1 ]]; then
        nds_ui_b "Flake inputs under the same owner still need SSH access (${n} repositories)."
    else
        nds_ui_b "A related flake input still needs SSH access."
    fi
    nds_ui_b "These were not known until the flake lock was read."
    nds_ui_b ""

    if _nds_git_wizard_used_gh; then
        default="gh"
        nds_aa_ask_numbered_choice GIT_CLOSURE_COVERAGE \
            "gh|generate|existing" \
            "gh=Register deploy keys for these repos via gh|generate=Create a key per repo (print or QR) and add it yourself|existing=Paste or path an existing key for each repo" \
            "$default" \
            true
    else
        default="generate"
        nds_aa_ask_numbered_choice GIT_CLOSURE_COVERAGE \
            "generate|existing" \
            "generate=Create a key per repo (print or QR) and add it yourself|existing=Paste or path an existing key for each repo" \
            "$default" \
            true
    fi
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
    return 0
}

# Description: Run path/paste/gh/generate for the current strategy and URL set.
# Arguments:
# - need:    <String> read or write (this call)
# - urls:    <String...> Probe URLs
# - --repos: <String...> owner/repo for gh (optional)
nds_git_wizard_execute_auth_choice() {
    local need="$1"
    shift
    local -a urls=() repos=()
    local choice strategy method parsing_repos=false arg rec_url

    while [[ $# -gt 0 ]]; do
        arg="$1"
        shift
        if [[ "$arg" == "--repos" ]]; then
            parsing_repos=true
            repos=("$@")
            break
        fi
        urls+=("$arg")
    done

    choice="$(nds_feat_cfg_get GIT_AUTH_ROUTE)"
    strategy="$(nds_feat_cfg_get GIT_ACCESS_STRATEGY)"
    [[ -n "$strategy" ]] || strategy="deploy-this"

    case "$choice" in
        path|import)
            nds_git_wizard_menu_import_path "${urls[@]}" || return 1
            ;;
        paste)
            nds_git_wizard_menu_import_paste "${urls[@]}" || return 1
            ;;
        gh)
            nds_feat_cfg_set GIT_SSH_KEY_REGISTER_METHOD gh
            nds_gh_ensure || {
                error "Could not prepare gh CLI (nixpkgs#gh)"
                return 1
            }
            case "$strategy" in
                account-this|account-all)
                    nds_feat_cfg_set GIT_SSH_KEY_TYPE account
                    if [[ ${#repos[@]} -gt 0 ]]; then
                        nds_git_wizard_menu_gh_account "${repos[@]}" || return 1
                    else
                        nds_git_wizard_menu_gh_account || return 1
                    fi
                    ;;
                *)
                    nds_feat_cfg_set GIT_SSH_KEY_TYPE deploy
                    nds_git_wizard_register_deploy_for_urls "$need" "${urls[@]}" || return 1
                    ;;
            esac
            ;;
        generate|manual|new)
            nds_feat_cfg_set GIT_SSH_KEY_REGISTER_METHOD manual
            case "$strategy" in
                account-this|account-all)
                    nds_feat_cfg_set GIT_SSH_KEY_TYPE account
                    if [[ ${#repos[@]} -gt 0 ]]; then
                        nds_git_wizard_register_account "${repos[@]}" || return 1
                    else
                        nds_git_wizard_register_account || return 1
                    fi
                    ;;
                *)
                    nds_feat_cfg_set GIT_SSH_KEY_TYPE deploy
                    nds_git_wizard_register_deploy_for_urls "$need" "${urls[@]}" || return 1
                    ;;
            esac
            ;;
        *) return 1 ;;
    esac

    if declare -f _nds_git_wizard_record_url_choice &>/dev/null; then
        for rec_url in "${urls[@]}"; do
            _nds_git_wizard_record_url_choice "$rec_url"
        done
    fi
    return 0
}

# Description: Top-level route menu for a private git URL (GitHub vs generic).
# No skip / no retry — private access is required. Supports 0=back.
# Arguments:
# - need:        <String> read or write (this call)
# - scope_label: <String> e.g. this repository
# - urls:        <String...> URLs to probe
# - --repos:     <String...> owner/repo for gh (optional)
# Returns:
# - 0 action done, 1 failure, NDS_ACTION_BACK go back
nds_git_wizard_route_menu() {
    local need="$1"
    shift
    local scope_label="$1"
    shift
    local -a urls=() repos=()
    local parsing_repos=false arg host="" is_gh=false rc

    while [[ $# -gt 0 ]]; do
        arg="$1"
        shift
        if [[ "$arg" == "--repos" ]]; then
            parsing_repos=true
            repos=("$@")
            break
        fi
        urls+=("$arg")
    done

    if [[ ${#urls[@]} -gt 0 ]]; then
        host="$(_nds_git_url_parse "${urls[0]}" 2>/dev/null | cut -f1)" || host=""
        nds_git_host_is_github "$host" 2>/dev/null && is_gh=true
        scope_label="$(nds_git_url_display "${urls[0]}")"
        nds_cfg_section_title "$scope_label"
    fi

    nds_git_wizard_ask_key_source
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    nds_git_wizard_ask_auth_method "$is_gh"
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    nds_feat_cfg_set GIT_ACCESS_STRATEGY "deploy-this"

    if [[ ${#repos[@]} -gt 0 ]]; then
        nds_git_wizard_execute_auth_choice "$need" "${urls[@]}" --repos "${repos[@]}"
    else
        nds_git_wizard_execute_auth_choice "$need" "${urls[@]}"
    fi
}

# Description: Owner from a git URL (stdout).
_nds_git_wizard_url_owner() {
    local url="$1" parsed
    parsed=$(_nds_git_url_parse "$(_nds_git_url_toSsh "$url")") || return 1
    printf '%s\n' "$(cut -f2 <<<"$parsed")"
}

# Description: Store per-URL existing_key + key_mode after a successful auth choice.
_nds_git_wizard_record_url_choice() {
    local url="$1" mode existing
    declare -f nds_git_access_set &>/dev/null || return 0
    mode="$(nds_feat_cfg_get GIT_AUTH_ROUTE 2>/dev/null || true)"
    case "$mode" in
        path|import) mode="path" ;;
        generate|manual|new) mode="generate" ;;
        paste|gh) ;;
        *) return 0 ;;
    esac
    existing="$(nds_feat_cfg_get GIT_EXISTING_KEY 2>/dev/null || true)"
    [[ "$existing" == "true" ]] || existing="false"
    nds_git_access_set key_mode "$url" "$mode"
    nds_git_access_set existing_key "$url" "$existing"
}

# Description: One-repo conversation: section title is the repo; then existing-key / method / apply.
# Uses NDS_GIT_KEY_MODE[url] when set (unattended paste/path/gh/generate).
# Arguments:
# - url: <String> Git URL
nds_git_wizard_converse_url() {
    local url="$1"
    local ssh_url disp host="" is_gh=false mapped_mode mapped_existing rc

    ssh_url=$(_nds_git_url_toSsh "$url")
    disp="$(nds_git_url_display "$ssh_url")"
    host="$(_nds_git_url_parse "$ssh_url" 2>/dev/null | cut -f1)" || host=""
    nds_git_host_is_github "$host" 2>/dev/null && is_gh=true
    nds_cfg_section_title "$disp"

    mapped_mode="$(nds_git_access_get key_mode "$ssh_url" 2>/dev/null || true)"
    mapped_existing="$(nds_git_access_get existing_key "$ssh_url" 2>/dev/null || true)"
    if [[ -n "$mapped_mode" ]]; then
        nds_feat_cfg_set GIT_AUTH_ROUTE "$mapped_mode"
        if [[ "$mapped_existing" == "true" || "$mapped_mode" == "paste" || "$mapped_mode" == "path" ]]; then
            nds_feat_cfg_set GIT_EXISTING_KEY true
            nds_feat_cfg_set GIT_KEY_SOURCE have
        else
            nds_feat_cfg_set GIT_EXISTING_KEY false
            nds_feat_cfg_set GIT_KEY_SOURCE new
        fi
        nds_git_wizard_execute_auth_choice "read" "$ssh_url" || return 1
        return 0
    fi

    nds_feat_cfg_set GIT_IMPORT_KEY_PATH ""
    if [[ "${_NDS_GIT_RELATED_IMPORT:-}" == "1" \
        && "$(nds_feat_cfg_get GIT_CLOSURE_COVERAGE 2>/dev/null || true)" == "existing" ]]; then
        nds_feat_cfg_set GIT_EXISTING_KEY true
        nds_feat_cfg_set GIT_KEY_SOURCE have
    else
        nds_git_wizard_ask_key_source
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
    fi
    nds_git_wizard_ask_auth_method "$is_gh"
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
    nds_git_wizard_execute_auth_choice "read" "$ssh_url" || return 1
    return 0
}

# Description: Repeat the per-repo conversation for each related flake input.
# Paste/path do not reuse NDS_GIT_IMPORT_KEY from the root repo.
# Arguments:
# - urls: <String...> Git URLs still missing access
nds_git_wizard_import_each_url() {
    local url rc=0 nested=false
    local strategy

    if [[ -n "${NDS_CFG_AA_NAME:-}" ]]; then
        nested=true
    else
        _nds_git_wizard_ensure_aa
    fi
    strategy="$(nds_feat_cfg_get GIT_ACCESS_STRATEGY 2>/dev/null || true)"
    if [[ -z "$strategy" ]]; then
        nds_feat_cfg_set GIT_ACCESS_STRATEGY "deploy-this"
    fi

    _NDS_GIT_RELATED_IMPORT=1
    for url in "$@"; do
        nds_git_wizard_converse_url "$url"
        rc=$?
        if [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" || "$rc" -ne 0 ]]; then
            unset _NDS_GIT_RELATED_IMPORT
            [[ "$nested" == true ]] || _nds_git_wizard_release_aa
            return "$rc"
        fi
    done
    unset _NDS_GIT_RELATED_IMPORT
    [[ "$nested" == true ]] || _nds_git_wizard_release_aa
    return 0
}

# Description: Closure route when account key does not cover all inputs.
nds_git_wizard_route_menu_closure_account() {
    nds_ui_b "Account key still missing some repositories — add a key per repo."
    nds_ui_b ""
    nds_feat_cfg_set GIT_ACCESS_STRATEGY "deploy-this"
    nds_git_wizard_import_each_url "$@"
}

# Description: Closure route — ask coverage now that related private repos are known.
nds_git_wizard_route_menu_closure() {
    local -a failed=("$@") same_owner=() other=()
    local owner root_owner url coverage rc

    [[ ${#failed[@]} -gt 0 ]] || return 0

    root_owner="$(_nds_git_wizard_url_owner "${failed[0]}")" || root_owner=""
    for url in "${failed[@]}"; do
        owner="$(_nds_git_wizard_url_owner "$url")" || owner=""
        if [[ -n "$root_owner" && "$owner" == "$root_owner" ]]; then
            same_owner+=("$url")
        else
            other+=("$url")
        fi
    done

    if [[ ${#same_owner[@]} -gt 0 ]]; then
        nds_git_wizard_ask_closure_coverage "${#same_owner[@]}"
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
        coverage="$(nds_feat_cfg_get GIT_CLOSURE_COVERAGE 2>/dev/null || true)"
        case "$coverage" in
            gh)
                nds_feat_cfg_set GIT_ACCESS_STRATEGY "deploy-all"
                nds_feat_cfg_set GIT_SSH_KEY_REGISTER_METHOD gh
                nds_feat_cfg_set GIT_SSH_KEY_TYPE deploy
                nds_feat_cfg_set GIT_EXISTING_KEY false
                nds_feat_cfg_set GIT_KEY_SOURCE new
                nds_feat_cfg_set GIT_AUTH_ROUTE gh
                nds_gh_ensure || true
                nds_git_wizard_register_deploy_for_urls "read" "${same_owner[@]}" || return 1
                ;;
            generate)
                nds_feat_cfg_set GIT_ACCESS_STRATEGY "deploy-all"
                nds_feat_cfg_set GIT_SSH_KEY_REGISTER_METHOD manual
                nds_feat_cfg_set GIT_SSH_KEY_TYPE deploy
                nds_feat_cfg_set GIT_EXISTING_KEY false
                nds_feat_cfg_set GIT_KEY_SOURCE new
                nds_feat_cfg_set GIT_AUTH_ROUTE generate
                nds_git_wizard_register_deploy_for_urls "read" "${same_owner[@]}" || return 1
                ;;
            existing)
                nds_feat_cfg_set GIT_ACCESS_STRATEGY "deploy-this"
                nds_git_wizard_import_each_url "${same_owner[@]}" || return $?
                ;;
            *)
                nds_git_wizard_import_each_url "${same_owner[@]}" || return $?
                ;;
        esac
    fi

    if [[ ${#other[@]} -gt 0 ]]; then
        nds_feat_cfg_set GIT_CLOSURE_COVERAGE ""
        nds_git_wizard_import_each_url "${other[@]}" || return $?
    fi
    return 0
}

# Description: Bind a temporary AA from store when wizard runs outside a feature entry.
_nds_git_wizard_ensure_aa() {
    if [[ -n "${NDS_CFG_AA_NAME:-}" ]]; then
        _NDS_GIT_WIZ_AA_OWNED=false
        return 0
    fi
    declare -gA _NDS_GIT_WIZ_AA=()
    nds_cfg_aa_from_store _NDS_GIT_WIZ_AA
    nds_cfg_aa_bind _NDS_GIT_WIZ_AA
    _NDS_GIT_WIZ_AA_OWNED=true
}

_nds_git_wizard_release_aa() {
    if [[ "${_NDS_GIT_WIZ_AA_OWNED:-false}" == "true" ]]; then
        nds_cfg_aa_to_store _NDS_GIT_WIZ_AA
        nds_cfg_aa_unbind
        _NDS_GIT_WIZ_AA_OWNED=false
    fi
}

# Description: Wizard step for a single root flake repo.
# Arguments:
# - host:   <String> Git host
# - owner:  <String> Repo owner
# - repo:   <String> Repo name
# - need:   <String|optional> read (default) or write
# - reason: <String|optional> Why this access is required
nds_git_auth_wizard_step_repo() {
    local host="$1" owner="$2" repo="$3"
    local need="${4:-read}"
    local reason="${5:-}"
    local root_url rc=0

    _nds_git_wizard_ensure_aa
    root_url="$(_nds_git_url_formatSsh "$host" "$owner" "$repo")"
    nds_git_wizard_screen_single "$host" "$owner" "$repo" "$need" "$reason"
    nds_git_wizard_route_menu "$need" "this repository" "$root_url" --repos "${owner}/${repo}" || rc=$?
    _nds_git_wizard_release_aa
    return "$rc"
}

# Description: Wizard step when flake.lock inputs lack access.
# Uses the account fallback only when this session actually registered an account key.
nds_git_auth_wizard_step_closure() {
    local -a failed=("$@")
    local strategy type rc=0

    _nds_git_wizard_ensure_aa
    nds_git_wizard_screen_closure "${failed[@]}"

    strategy="$(nds_feat_cfg_get GIT_ACCESS_STRATEGY 2>/dev/null || true)"
    type="$(nds_feat_cfg_get GIT_SSH_KEY_TYPE 2>/dev/null || true)"
    if [[ "$strategy" == "account-all" || "$strategy" == "account-this" || "$type" == "account" ]]; then
        nds_git_wizard_route_menu_closure_account "${failed[@]}" || rc=$?
    else
        nds_git_wizard_route_menu_closure "${failed[@]}" || rc=$?
    fi
    _nds_git_wizard_release_aa
    return "$rc"
}
