#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard GitHub CLI menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-28
# ==================================================================================================

# Description: Print one device-login line with optional color on code/URL.
# Arguments:
# - line: <String> Raw gh auth login output line
_nds_git_wizard_gh_print_device_line() {
    local line="$1"
    local code url prefix

    nds_ui_init
    case "$line" in
        *one-time\ code*|*First\ copy*)
            if [[ "$line" =~ ([0-9A-Za-z]{4}-[0-9A-Za-z]{4}) ]]; then
                code="${BASH_REMATCH[1]}"
                prefix="${line%%"${code}"*}"
                if [[ "$NDS_UI_COLOR" == true ]]; then
                    printf '%s%s\033[1;93m%s\033[0m\n' "$NDS_UI_INDENT_I" "$prefix" "$code" >&2
                else
                    nds_ui_i "$line"
                fi
            else
                nds_ui_i "$line"
            fi
            ;;
        *login/device*|*Open\ this\ URL*)
            if [[ "$line" =~ (https://[^[:space:]]+) ]]; then
                url="${BASH_REMATCH[1]}"
                prefix="${line%%"${url}"*}"
                if [[ "$NDS_UI_COLOR" == true ]]; then
                    printf '%s%s\033[1;96m%s\033[0m\n' "$NDS_UI_INDENT_I" "$prefix" "$url" >&2
                else
                    nds_ui_i "$line"
                fi
            else
                nds_ui_i "$line"
            fi
            ;;
        *)
            nds_ui_i "$line"
            ;;
    esac
}

# Description: Print device-login lines from captured gh output.
_nds_git_wizard_gh_show_device_prompt() {
    local log="$1" line

    nds_ui_section_header "GitHub device login"
    nds_ui_b "gh stores a short-lived session on this ISO (plain text — no credential store on the live image)."
    nds_ui_b "Complete login on your phone using the code below."
    nds_ui_b "After install, logout is enough. Do not revoke GitHub CLI in Settings → Applications — that deletes SSH keys this session created."
    nds_ui_b ""
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "$line" in
            *one-time\ code*|*login/device*|*First\ copy*|*Open\ this\ URL*)
                _nds_git_wizard_gh_print_device_line "$line"
                ;;
        esac
    done < "$log"
    nds_ui_b ""
}

# Description: Run gh auth login via device code (spinner until code, then wait for auth).
_nds_git_wizard_gh_auth_login() {
    local -a gh_cmd=()
    local rc=0 pid shown=false delay=0.12 spinstr="|/-\\"
    local char logfile="${NDS_RUNTIME_DIR:-/tmp/nds}/gh_auth.log"

    nds_git_warm_gh || return 1
    nds_git_warm_gh_cmd gh_cmd || return 1
    git_gh_unset_blocking_tokens

    mkdir -p "$(dirname "$logfile")"
    : >"$logfile"

    info "Starting GitHub device login (waiting for one-time code)..."
    (
        BROWSER=false "${gh_cmd[@]}" auth login \
            --hostname github.com \
            --git-protocol ssh \
            --scopes repo,admin:public_key \
            --skip-ssh-key \
            --insecure-storage
    ) >>"$logfile" 2>&1 &
    pid=$!

    nds_step_start "GitHub device login"
    while kill -0 "$pid" 2>/dev/null; do
        if ! $shown && grep -qiE 'one-time code|login/device' "$logfile" 2>/dev/null; then
            printf '\r\033[K' >&2
            _nds_git_wizard_gh_show_device_prompt "$logfile"
            nds_step_start "Waiting for GitHub authorization"
            shown=true
        fi
        char="${spinstr:0:1}"
        if $shown; then
            printf '\r\033[K%s[%s%s] Waiting for GitHub authorization' \
                "$NDS_UI_INDENT_B" "$char" "$char" >&2
        else
            printf '\r\033[K%s[%s%s] GitHub device login' \
                "$NDS_UI_INDENT_B" "$char" "$char" >&2
        fi
        spinstr="${spinstr:1}${spinstr:0:1}"
        sleep "$delay"
    done
    wait "$pid" || rc=$?

    if [[ "$rc" -eq 0 ]]; then
        printf '\r\033[K' >&2
        if $shown; then
            nds_step_complete "Waiting for GitHub authorization"
        else
            nds_step_complete "GitHub device login"
        fi
        return 0
    fi
    printf '\r\033[K' >&2
    nds_step_fail "GitHub device login"
    warn "GitHub login failed"
    nds_ui_i "Open https://github.com/login/device on your phone and enter the one-time code."
    nds_ui_i "If this keeps failing, unset GITHUB_TOKEN / GH_TOKEN in your shell and retry."
    nds_ui_i "You can also choose manual registration from the menu."
    return 1
}

# Description: Interactive gh device login and scope refresh.
nds_git_wizard_gh_ensure_auth() {
    local -a gh_cmd=()

    nds_git_warm_gh || return 1
    nds_git_warm_gh_cmd gh_cmd || return 1

    if git_gh_session_ready; then
        return 0
    fi

    if ! git_gh_session_active; then
        _nds_git_wizard_gh_auth_login || return 1
        git_gh_session_mark_scopes_ok
        success "GitHub login successful"
        return 0
    fi

    if ! git_gh_has_key_scope; then
        nds_step_start_spin "Extending GitHub session"
        git_gh_unset_blocking_tokens
        BROWSER=false "${gh_cmd[@]}" auth refresh -h github.com -s repo,admin:public_key || {
            nds_step_fail "Extending GitHub session"
            return 1
        }
        nds_step_complete "Extending GitHub session"
        git_gh_session_mark_scopes_ok
    fi
    return 0
}

# Description: Ensure gh is available and authenticated.
# Returns:
# - <Bool> 0 on success
nds_git_wizard_gh_prepare() {
    if ! git_gh_bin_ready 2>/dev/null; then
        info "Preparing GitHub CLI (download once if needed)..."
    fi
    nds_git_warm_gh || {
        error "Could not install gh CLI"
        return 1
    }
    if git_gh_session_ready; then
        return 0
    fi
    nds_git_wizard_gh_ensure_auth || return 1
    return 0
}

# Description: gh path — register a deploy key on one repository.
# Arguments:
# - owner:     <String> Repository owner
# - repo:      <String> Repository name
# - read_only: <String> true (default) or false
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_gh_deploy() {
    local owner="$1" repo="$2" read_only="${3:-true}"
    local label="Registering deploy key on ${owner}/${repo}"

    nds_git_wizard_gh_prepare || return 1
    nds_step_start_spin "$label"
    if ! nds_git_register_deploy_for_repo "$owner" "$repo" "$read_only"; then
        nds_step_fail "$label"
        return 1
    fi
    nds_step_complete "$label"
    if [[ "$read_only" == "false" ]]; then
        success "Write deploy key registered on ${owner}/${repo}"
    else
        success "Read-only deploy key registered on ${owner}/${repo}"
    fi
    debug "Private key: $(nds_git_deploy_key_path "$owner" "$repo")"
    debug "Target: /$(nds_git_deploy_key_target_rel "$owner" "$repo")"
    nds_git_ssh_config_refresh || true
    return 0
}

# Description: gh path — register account SSH key (log in as machine user).
# Arguments:
# - repos: <String...> owner/repo for logging
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_gh_account() {
    local -a repos=("$@")
    local pub label="Registering SSH key on GitHub account"

    nds_ui_b "Log in to gh as the machine GitHub user — not your personal account."
    nds_ui_b ""

    # Download + device login before keygen so the user is not waiting after
    # "Git SSH key generated" with no status.
    nds_git_wizard_gh_prepare || return 1

    if [[ ! -f "$(nds_git_session_pubkey_path)" ]]; then
        info "Generating session SSH key..."
        nds_git_key_generate "$(nds_git_session_key_path)" || return 1
    fi
    pub="$(nds_git_session_pubkey_path)"
    nds_git_keys_register "$(nds_git_session_key_path)" || true
    nds_git_auth_set_mode account

    nds_step_start_spin "$label"
    if nds_git_register_for_repos "$pub" "${repos[@]}"; then
        nds_step_complete "$label"
        success "SSH key registered on GitHub account ($(nds_git_ssh_key_title))"
        nds_ui_i "Private key will be copied to $(nds_git_target_key_abs) on the target."
        return 0
    fi
    nds_step_fail "$label"
    return 1
}

# Description: Ask overwrite|alternate|cancel for a GH title collision.
# Sets NDS_GH_KEY_TITLE_COLLISION and NDS_GIT_SSH_KEY_TITLE_COLLISION.
# Arguments:
# - prompt: <String> User-facing message
nds_git_ui_ask_gh_title_collision() {
    local prompt="${1:?prompt}"
    local choice

    choice="${NDS_GH_KEY_TITLE_COLLISION:-${NDS_GIT_SSH_KEY_TITLE_COLLISION:-}}"
    if [[ -n "$choice" ]]; then
        return 0
    fi
    if declare -f nds_cfg_ask_numbered_choice &>/dev/null; then
        nds_cfg_set GIT_SSH_KEY_TITLE_COLLISION ""
        nds_ui_b ""
        nds_ui_b "$prompt"
        nds_ui_b ""
        nds_cfg_ask_numbered_choice GIT_SSH_KEY_TITLE_COLLISION \
            "overwrite|alternate|cancel" \
            "overwrite=Remove the old key and register this one|alternate=Use an alternate title|cancel=Cancel — choose a different approach"
        choice="$(nds_cfg_get GIT_SSH_KEY_TITLE_COLLISION)"
    else
        return 1
    fi
    case "$choice" in
        overwrite|alternate|cancel)
            NDS_GH_KEY_TITLE_COLLISION="$choice"
            NDS_GIT_SSH_KEY_TITLE_COLLISION="$choice"
            export NDS_GH_KEY_TITLE_COLLISION NDS_GIT_SSH_KEY_TITLE_COLLISION
            nds_cfg_set GIT_SSH_KEY_TITLE_COLLISION "$choice"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
