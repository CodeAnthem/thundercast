#!/usr/bin/env bash
# ==================================================================================================
# NDS - Toolkit create/restore helpers (operator age, SSH, sops policy)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-18 | Modified: 2026-08-28
# Description:   Generate operator credentials; never commit private keys
# ==================================================================================================

# Description: Runtime directory for toolkit private material (bundle only).
_nds_toolkit_secrets_dir() {
    printf '%s/secrets/toolkit\n' "${NDS_RUNTIME_DIR:-/tmp/nds}"
}

# Description: Generate operator age key, toolkit user SSH key, and write pubs to the leaf.
# Arguments:
# - flake_root: <String> Leaf checkout
# Returns:
# - <Bool> 0 on success
nds_toolkit_generate_operator() {
    local flake_root="$1"
    local dest pub_age
    dest="$(_nds_toolkit_secrets_dir)"
    mkdir -p "$dest" || return 1

    if [[ ! -f "${dest}/operator_age.txt" ]]; then
        if ! nds_age_keygen -o "${dest}/operator_age.txt" \
            2>>"${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"; then
            error "age-keygen failed — cannot create operator key"
            return 1
        fi
        chmod 600 "${dest}/operator_age.txt"
    fi
    pub_age="$(nds_age_keygen -y "${dest}/operator_age.txt" 2>/dev/null)" || {
        error "Could not derive operator age public key"
        return 1
    }
    mkdir -p "${dest}" || return 1
    printf '%s\n' "$pub_age" > "${dest}/operator_age.pub"

    if [[ ! -f "${dest}/toolkit_ssh" ]]; then
        ssh-keygen -t ed25519 -N "" -f "${dest}/toolkit_ssh" -C "nds-toolkit" >/dev/null || {
            error "ssh-keygen failed — cannot create toolkit SSH key"
            return 1
        }
        chmod 600 "${dest}/toolkit_ssh"
    fi

    nds_toolkit_write_sops_policy "$flake_root" "$pub_age" || return 1
    nds_bundle_register_file "secrets/toolkit/operator_age.txt" "${dest}/operator_age.txt"
    nds_bundle_register_file "secrets/toolkit/operator_age.pub" "${dest}/operator_age.pub"
    nds_bundle_register_file "secrets/toolkit/toolkit_ssh" "${dest}/toolkit_ssh"
    nds_bundle_register_file "secrets/toolkit/toolkit_ssh.pub" "${dest}/toolkit_ssh.pub"
    return 0
}

# Description: Ensure .sops.yaml exists. Do not rewrite recipients — toolkit Init owns that.
# Arguments:
# - flake_root: <String> Leaf checkout
# - pubkey:     <String> unused (kept for callers)
nds_toolkit_write_sops_policy() {
    local flake_root="$1"
    local sops_yaml="${flake_root}/.sops.yaml"
    : "${2:-}"

    mkdir -p "${flake_root}/secrets/swarm" "${flake_root}/secrets/hosts"
    if [[ ! -f "$sops_yaml" ]]; then
        cat > "$sops_yaml" << EOF
# Recipients come from toolkit (Sops → Operator → Init, then Apply & push).
creation_rules: []
EOF
    fi
    return 0
}

# Description: Load toolkit secrets from a restore zip or directory.
# Arguments:
# - source: <String> Path to nds_bundle.zip or extracted secrets/toolkit dir
# Returns:
# - <Bool> 0 when operator_age.txt is in the runtime toolkit dir
nds_toolkit_restore_from_bundle() {
    local source="$1"
    local dest extract
    dest="$(_nds_toolkit_secrets_dir)"
    mkdir -p "$dest" || return 1

    if [[ -d "$source" && -f "${source}/operator_age.txt" ]]; then
        cp -a "${source}/." "$dest/"
    elif [[ -f "$source" ]]; then
        extract=$(mktemp -d)
        if command -v unzip &>/dev/null; then
            unzip -q -o "$source" -d "$extract" || {
                rm -rf "$extract"
                error "Cannot unzip toolkit bundle: $source"
                return 1
            }
        else
            error "unzip not found — cannot restore toolkit bundle"
            rm -rf "$extract"
            return 1
        fi
        if [[ -f "${extract}/secrets/toolkit/operator_age.txt" ]]; then
            cp -a "${extract}/secrets/toolkit/." "$dest/"
        elif [[ -f "${extract}/operator_age.txt" ]]; then
            cp -a "${extract}/." "$dest/"
        else
            rm -rf "$extract"
            error "Bundle has no secrets/toolkit/operator_age.txt"
            return 1
        fi
        rm -rf "$extract"
    else
        error "Toolkit restore source not found: $source"
        return 1
    fi
    chmod 600 "${dest}/operator_age.txt" "${dest}/toolkit_ssh" 2>/dev/null || true
    [[ -f "${dest}/operator_age.txt" ]]
}

# Description: Copy operator age + toolkit SSH onto the installed system.
# Arguments:
# - target_root: <String> Installed system root (default: /mnt)
nds_toolkit_install_keys_to_target() {
    local target_root="${1:-/mnt}"
    local dest
    dest="$(_nds_toolkit_secrets_dir)"
    [[ -f "${dest}/operator_age.txt" ]] || return 0
    [[ -d "${target_root}/etc" ]] || return 0
    mkdir -p "${target_root}/etc/sops/age" "${target_root}/root/.ssh"
    cp "${dest}/operator_age.txt" "${target_root}/etc/sops/age/operator.txt"
    chmod 600 "${target_root}/etc/sops/age/operator.txt"
    if [[ -f "${dest}/toolkit_ssh" ]]; then
        cp "${dest}/toolkit_ssh" "${target_root}/root/.ssh/id_ed25519"
        cp "${dest}/toolkit_ssh.pub" "${target_root}/root/.ssh/id_ed25519.pub"
        chmod 600 "${target_root}/root/.ssh/id_ed25519"
    fi
    info "Installed operator age key and toolkit SSH on the target"
}

# Description: Copy the Thundercast fetch deploy key onto the target if the ISO has one.
# Arguments:
# - target_root: <String> Installed system root (default: /mnt)
nds_toolkit_ensure_cast_fetch_key() {
    local target_root="${1:-/mnt}"
    local src="" dest base
    local f

    [[ -d "${target_root}/root" ]] || return 0
    for f in /root/.ssh/nds_deploy_*thundercast; do
        [[ -f "$f" && "$f" != *.pub ]] || continue
        src="$f"
        break
    done
    [[ -n "$src" ]] || return 0
    mkdir -p "${target_root}/root/.ssh"
    chmod 700 "${target_root}/root/.ssh"
    base="$(basename "$src")"
    dest="${target_root}/root/.ssh/${base}"
    if [[ ! -f "$dest" ]]; then
        cp "$src" "$dest"
        chmod 600 "$dest"
        [[ -f "${src}.pub" ]] && cp "${src}.pub" "${dest}.pub"
        info "Installed Thundercast fetch key ${base} on the target"
    fi
    return 0
}

# Description: Seed /var/lib/nds-toolkit from the catalog clone (or CAST_REPO_URL).
# Uses a relative symlink so the path stays valid after /mnt becomes /.
# Arguments:
# - target_root: <String> Installed system root (default: /mnt)
nds_toolkit_seed_scripts_to_target() {
    local target_root="${1:-/mnt}"
    local dest="${target_root}/var/lib/nds-toolkit"
    local repo src_git

    if [[ -x "${dest}/current/toolkit.sh" ]]; then
        info "toolkitScripts already seeded at ${dest}/current"
        return 0
    fi
    mkdir -p "$dest" || return 1
    rm -rf "${dest}/src"

    repo="$(nds_cfg_get CAST_REPO_URL 2>/dev/null || true)"
    repo="${repo:-${NDS_CAST_DEFAULT_URL:-https://github.com/CodeAnthem/thundercast.git}}"

    src_git="${NDS_CAST_PROBE_DIR:-}"
    if [[ -f "${src_git}/toolkitScripts/toolkit.sh" && -d "${src_git}/.git" ]]; then
        if ! git clone --no-hardlinks "$src_git" "${dest}/src" 2>/dev/null; then
            git clone "$src_git" "${dest}/src" || {
                error "Could not clone toolkitScripts from catalog checkout"
                return 1
            }
        fi
    else
        git clone --depth 1 "$repo" "${dest}/src" || {
            error "Could not clone toolkitScripts from ${repo}"
            return 1
        }
    fi

    if [[ ! -f "${dest}/src/toolkitScripts/toolkit.sh" ]]; then
        error "Checkout has no toolkitScripts/toolkit.sh"
        return 1
    fi
    # Probe clones copy a live-ISO origin; toolkit-update must fetch Thundercast.
    git -C "${dest}/src" remote remove origin >/dev/null 2>&1 || true
    git -C "${dest}/src" remote add origin "$repo" || true
    chmod +x "${dest}/src/toolkitScripts/toolkit.sh" || true
    if [[ -f "${dest}/src/toolkitScripts/tc-sops.sh" ]]; then
        chmod +x "${dest}/src/toolkitScripts/tc-sops.sh" || true
    fi
    ln -sfn src/toolkitScripts "${dest}/current"
    mkdir -p "${target_root}/root/.nds/bin" "${target_root}/root/bin"
    if [[ -x "${dest}/src/toolkitScripts/tc-sops.sh" ]]; then
        ln -sfn /var/lib/nds-toolkit/current/tc-sops.sh \
            "${target_root}/root/.nds/bin/tc-sops"
        ln -sfn /var/lib/nds-toolkit/current/tc-sops.sh \
            "${target_root}/root/bin/tc-sops"
    fi
    info "Seeded toolkitScripts at ${dest}/current"
    return 0
}

# Description: Put operator age + toolkit SSH into the install zip (hooks run after
# bundle_create resets inline nds_bundle_register_file calls).
nds_toolkit_bundle_contrib() {
    local dest f
    dest="$(_nds_toolkit_secrets_dir)"
    [[ -d "$dest" ]] || return 0
    declare -f nds_bundle_register_file &>/dev/null || return 0
    for f in operator_age.txt operator_age.pub toolkit_ssh toolkit_ssh.pub; do
        [[ -f "${dest}/${f}" ]] || continue
        nds_bundle_register_file "secrets/toolkit/${f}" "${dest}/${f}"
    done
}

if declare -f nds_bundle_register_hook &>/dev/null; then
    nds_bundle_register_hook nds_toolkit_bundle_contrib
fi
