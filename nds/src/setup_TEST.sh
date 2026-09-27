#!/usr/bin/env bash
# ==================================================================================================
# NDS - Shared test boot
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-27
# Description:   Loads essentials for NDS tests and points scriptInfo at nds/src.
# ==================================================================================================

_NDS_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=../../utilities/essentials/testEnvironment/testEnvironment.sh
source "${_NDS_SRC_DIR}/../../utilities/essentials/testEnvironment/testEnvironment.sh"

nds_test_boot() {
    essentials_test_load logger eventBus importer ui chrome prompt scriptInfo task sessionDir || return 1
    __ESSENTIALS_SCRIPTINFO[script_dir]="$_NDS_SRC_DIR"
    __ESSENTIALS_SCRIPTINFO[script_name]="NDS Test"
    __ESSENTIALS_SCRIPTINFO[script_version]="0.0.0"
}

nds_test_session() {
    _NDS_TEST_SESSION=$(mktemp -d)
    mkdir -p \
        "${_NDS_TEST_SESSION}/recipe" \
        "${_NDS_TEST_SESSION}/secrets" \
        "${_NDS_TEST_SESSION}/config" \
        "${_NDS_TEST_SESSION}/seed" \
        "${_NDS_TEST_SESSION}/work" \
        "${_NDS_TEST_SESSION}/logs" \
        "${_NDS_TEST_SESSION}/mnt"
    _NDS_TARGET_ROOT="${_NDS_TEST_SESSION}/mnt"
}

nds_session_dir() {
    local name=$1
    if [[ -z "${_NDS_TEST_SESSION:-}" ]]; then
        printf '%s\n' "nds_session_dir: no test session" >&2
        return 1
    fi
    printf '%s\n' "${_NDS_TEST_SESSION}/${name}"
}

nds_test_session_drop() {
    if [[ -n "${_NDS_TEST_SESSION:-}" && -d "${_NDS_TEST_SESSION}" ]]; then
        rm -rf "${_NDS_TEST_SESSION}"
    fi
    unset _NDS_TEST_SESSION
    _NDS_TARGET_ROOT=/mnt
}

# A block device cannot be created here. While this dir is set, disk checks
# accept the path and the shims in it stand in for the real binaries.
_nds_test_bin_rcname() {
    local _bin_name=${1^^}
    _bin_name=${_bin_name//[^A-Z0-9]/_}
    printf 'NDS_TEST_BIN_RC_%s\n' "$_bin_name"
}

nds_test_stubBins() {
    local _bin_name _bin_rc
    _NDS_TEST_BIN_DIR=$(mktemp -d)
    _NDS_TEST_BIN_PATH_SAVE=$PATH
    if [[ -z ${NDS_TEST_BIN_LOG:-} ]]; then
        NDS_TEST_BIN_LOG="${_NDS_TEST_BIN_DIR}.log"
        _NDS_TEST_BIN_LOG_OWNED=1
    fi
    : >"$NDS_TEST_BIN_LOG"
    NDS_TEST_BIN_DIR=$_NDS_TEST_BIN_DIR
    export NDS_TEST_BIN_DIR NDS_TEST_BIN_LOG
    for _bin_name in "$@"; do
        _bin_rc=$(_nds_test_bin_rcname "$_bin_name")
        cat >"${_NDS_TEST_BIN_DIR}/${_bin_name}" <<EOF
#!/usr/bin/env bash
{
    printf '%s' '${_bin_name}'
    printf ' %s' "\$@"
    printf '\\n'
} >>"\$NDS_TEST_BIN_LOG"
if [[ '${_bin_name}' == nixos-generate-config ]]; then
    printf '%s\n' '{ fileSystems = {}; }'
fi
if [[ '${_bin_name}' == nix ]]; then
    if [[ "\$*" == *nixosConfigurations* ]]; then
        printf '%s\n' 'control'
    else
        printf '%s\n' '/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-nixos-system-test'
    fi
fi
if [[ '${_bin_name}' == dd ]]; then
    printf '%s' 'GRUB'
fi
if [[ '${_bin_name}' == lsblk ]]; then
    printf '%s\n' 'stubdisk'
fi
if [[ '${_bin_name}' == systemd-detect-virt ]]; then
    printf '%s\n' 'none'
fi
if [[ '${_bin_name}' == blkid ]]; then
    printf '%s\n' 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
fi
if [[ '${_bin_name}' == zip ]]; then
    for arg in "\$@"; do
        if [[ "\$arg" == /* || "\$arg" == *.zip ]]; then
            : > "\$arg"
        fi
    done
fi
if [[ '${_bin_name}' == git ]]; then
    for arg in "\$@"; do
        if [[ "\$arg" == get-url ]]; then
            printf '%s\n' 'git@github.com:owner/repo.git'
        fi
    done
fi
prev=
_root=
for arg in "\$@"; do
    # -o/-f on lsblk, blkid, and findmnt are column names (NAME, value, SOURCE).
    # An absolute path is a real output (age-keygen, ssh-keygen, nixos-facter).
    if [[ "\$prev" == -o || "\$prev" == -f ]]; then
        _out=\$arg
        if [[ "\$_out" != /* ]]; then
            if [[ '${_bin_name}' == age-keygen || '${_bin_name}' == ssh-keygen ]]; then
                mkdir -p "\${TMPDIR:-/tmp}/nds-test-stubs"
                _out="\${TMPDIR:-/tmp}/nds-test-stubs/\${_out##*/}"
            else
                _out=
            fi
        fi
        if [[ -n "\$_out" ]]; then
            printf '%s\\n' '# public key: age1testkey' > "\$_out"
            printf '%s\\n' 'AGE-SECRET-KEY-TESTONLY' >> "\$_out"
            printf '%s\\n' 'ssh-ed25519 AAAAC3R0b3JhdG9y test' > "\$_out.pub"
        fi
    fi
    if [[ '${_bin_name}' == nixos-install && "\$prev" == --root ]]; then
        _root=\$arg
    fi
    if [[ '${_bin_name}' == nix && "\$prev" == --store && -n "\$arg" ]]; then
        mkdir -p "\$arg/boot/grub" "\$arg/nix/store"
        printf '%s\n' grub > "\$arg/boot/grub/grub.cfg"
    fi
    prev=\$arg
done
if [[ '${_bin_name}' == nixos-install && -n "\$_root" ]]; then
    mkdir -p "\$_root/boot/EFI/nixos" "\$_root/boot/grub" "\$_root/nix/store" "\$_root/etc/nixos"
    printf '%s\n' efi > "\$_root/boot/EFI/nixos/grubx64.efi"
    printf '%s\n' grub > "\$_root/boot/grub/grub.cfg"
fi
exit "\${${_bin_rc}:-0}"
EOF
        chmod 755 "${_NDS_TEST_BIN_DIR}/${_bin_name}"
    done
    PATH="${_NDS_TEST_BIN_DIR}:${PATH}"
    export PATH
}

nds_test_stubBins_drop() {
    if [[ -n ${_NDS_TEST_BIN_PATH_SAVE:-} ]]; then
        PATH=$_NDS_TEST_BIN_PATH_SAVE
        export PATH
    fi
    if [[ -n ${_NDS_TEST_BIN_DIR:-} && -d ${_NDS_TEST_BIN_DIR} ]]; then
        rm -rf "$_NDS_TEST_BIN_DIR"
    fi
    if [[ ${_NDS_TEST_BIN_LOG_OWNED:-} == 1 && -n ${NDS_TEST_BIN_LOG:-} ]]; then
        rm -f "$NDS_TEST_BIN_LOG"
    fi
    unset _NDS_TEST_BIN_DIR _NDS_TEST_BIN_PATH_SAVE _NDS_TEST_BIN_LOG_OWNED NDS_TEST_BIN_DIR
}

nds_test_installBins() {
    nds_test_stubBins \
        git nix nix-build nixos-install nixos-enter cryptsetup sgdisk parted partprobe \
        wipefs mkfs.ext4 mkfs.vfat mkfs.fat mkswap swapon mount umount mountpoint \
        lsblk blkid findmnt efibootmgr age-keygen ssh-keygen ssh nixos-facter \
        nixos-generate-config disko zip unzip reboot gh dd
}

nds_test_loadUtilities() {
    local _nds_util
    # shellcheck source=app/utility/utility.sh
    source "${_NDS_SRC_DIR}/app/utility/utility.sh"
    for _nds_util in pkg age disk flake git hwconfig facter nixcfg nixos qr sops targetSeed; do
        nds_requireUtility "$_nds_util" || return 1
    done
}

nds_test_assertResolved() {
    local _nds_name _nds_file _nds_missing=0 _nds_fleet
    local -a _nds_files=()
    _nds_fleet=$(cd "${_NDS_SRC_DIR}/../../fleet/nds-actions" && pwd)
    shopt -s nullglob
    _nds_files=(
        "${_NDS_SRC_DIR}/cook/"*.sh
        "${_NDS_SRC_DIR}/app/"*.sh
        "${_NDS_SRC_DIR}/actions/"*/setup.sh
        "${_nds_fleet}/"*/setup.sh
        "${_nds_fleet}/"*/logic/*.sh
    )
    shopt -u nullglob
    local -a _nds_scan=()
    for _nds_file in "${_nds_files[@]}"; do
        [[ "$_nds_file" == *_TEST.sh ]] && continue
        _nds_scan+=("$_nds_file")
    done
    _nds_files=("${_nds_scan[@]}")
    import_dir "${_NDS_SRC_DIR}/app/session" --depth 0
    import_dir "${_NDS_SRC_DIR}/app/action" --depth 0
    import_dir "${_NDS_SRC_DIR}/cook" --depth 0
    import_dir "${_NDS_SRC_DIR}/wizard" --depth 0
    import_dir "${_NDS_SRC_DIR}/wizard/askers" --depth 0
    import_dir "${_NDS_SRC_DIR}/wizard/git" --depth 0
    # shellcheck source=app/confirm.sh
    source "${_NDS_SRC_DIR}/app/confirm.sh"
    # shellcheck source=app/finish.sh
    source "${_NDS_SRC_DIR}/app/finish.sh"
    # shellcheck source=app/pipeline.sh
    source "${_NDS_SRC_DIR}/app/pipeline.sh"
    for _nds_file in "${_NDS_SRC_DIR}/actions/"*/setup.sh "${_nds_fleet}/"*/setup.sh "${_nds_fleet}/"*/logic/*.sh; do
        [[ -f "$_nds_file" ]] || continue
        # shellcheck disable=SC1090
        source "$_nds_file" || return 1
    done
    while IFS= read -r _nds_name; do
        [[ -n "$_nds_name" ]] || continue
        [[ "$_nds_name" == [A-Za-z]* ]] || _nds_name=${_nds_name:1}
        [[ "$_nds_name" == *[A-Za-z_] ]] || _nds_name=${_nds_name:0:-1}
        [[ -n "$_nds_name" ]] || continue
        if ! declare -F "$_nds_name" >/dev/null; then
            bts_fail "unresolved ${_nds_name}"
            _nds_missing=1
        fi
    done < <(grep -h -oE '(^|[^A-Za-z0-9_./])(disk|nixos|nixcfg|flake|git|gh|facter|hwconfig|sops|targetSeed|pkg|age|qr|step|nds)_[A-Za-z_]+($|[^A-Za-z0-9_.])' \
        "${_nds_files[@]}" | sort -u)
    if [[ "$_nds_missing" -eq 0 ]]; then
        bts_pass "every cook and action command resolves"
    fi
}

nds_test_boot
