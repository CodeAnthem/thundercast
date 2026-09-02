#!/usr/bin/env bash
# ==================================================================================================
# GitHub Scripts - ShellCheck install/resolve (shared by product dev/*.sh)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-01
# ==================================================================================================

SHELLCHECK_VERSION="${SHELLCHECK_VERSION:-0.10.0}"
CACHE_ROOT="${XDG_CACHE_HOME:-${HOME}/.cache}/thundercast-shellcheck"
SHELLCHECK_BIN="${SHELLCHECK_BIN:-}"

_ci_shellcheck_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "${os}:${arch}" in
        Linux:x86_64) echo "linux.x86_64" ;;
        Linux:aarch64 | Linux:arm64) echo "linux.aarch64" ;;
        Darwin:x86_64) echo "darwin.x86_64" ;;
        Darwin:arm64) echo "darwin.aarch64" ;;
        *)
            echo "Unsupported platform: ${os} ${arch}" >&2
            return 1
            ;;
    esac
}

_ci_shellcheck_install() {
    local platform archive extract_dir url
    platform="$(_ci_shellcheck_platform)"
    extract_dir="${CACHE_ROOT}/${SHELLCHECK_VERSION}"
    archive="${CACHE_ROOT}/shellcheck-v${SHELLCHECK_VERSION}.${platform}.tar.xz"
    url="https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.${platform}.tar.xz"
    mkdir -p "${CACHE_ROOT}"
    if [[ ! -x "${extract_dir}/shellcheck" ]]; then
        echo "Installing ShellCheck ${SHELLCHECK_VERSION} (${platform}) → ${extract_dir}" >&2
        curl -fsSL "${url}" -o "${archive}"
        rm -rf "${extract_dir}"
        mkdir -p "${extract_dir}"
        tar -xJf "${archive}" -C "${extract_dir}" --strip-components=1 --no-same-owner
        rm -f "${archive}"
    fi
    SHELLCHECK_BIN="${extract_dir}/shellcheck"
}

ci_shellcheck_resolve() {
    if [[ -n "${SHELLCHECK_BIN}" && -x "${SHELLCHECK_BIN}" ]]; then
        return 0
    fi
    if [[ -n "${SHELLCHECK_BIN}" ]]; then
        echo "SHELLCHECK_BIN is set but not executable: ${SHELLCHECK_BIN}" >&2
        return 1
    fi
    if [[ "${NDS_SHELLCHECK_USE_SYSTEM:-}" == "1" ]] && command -v shellcheck &>/dev/null; then
        SHELLCHECK_BIN="$(command -v shellcheck)"
        return 0
    fi
    local cached="${CACHE_ROOT}/${SHELLCHECK_VERSION}/shellcheck"
    if [[ -x "${cached}" ]]; then
        SHELLCHECK_BIN="${cached}"
        return 0
    fi
    _ci_shellcheck_install
}

# Description: Lint script list; print summary.
# Arguments:
# - title: <String> Summary title (e.g. NDS v5.38.0)
# - rcfile: <String> Path to .shellcheckrc
# - scripts: <Nameref> Array of paths
ci_shellcheck_lint() {
    local title="$1" rcfile="$2"
    local -n _scripts="$3"
    local script findings passed=0 failed=0
    local total border margin inner

    for script in "${_scripts[@]}"; do
        if findings=$("${SHELLCHECK_BIN}" -S warning --rcfile="$rcfile" "$script" 2>&1); then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
            printf '%s\n' "$findings" >&2
        fi
    done

    total=$((passed + failed))
    inner=${#title}
    (( inner < 56 )) && inner=56
    margin='  '
    border=$(printf -- '-%.0s' $(seq 1 "$inner"))
    printf '\n' >&2
    printf "%s+%s+\n" "$margin" "$border" >&2
    printf "%s| %s%*s|\n" "$margin" "$title" "$(( inner - ${#title} - 1 ))" '' >&2
    printf "%s| ShellCheck summary%*s|\n" "$margin" "$(( inner - 19 ))" '' >&2
    printf "%s+%s+\n" "$margin" "$border" >&2
    printf '  Passed: %s\n' "$passed" >&2
    printf '  Failed: %s\n' "$failed" >&2
    printf '  Total:  %s\n' "$total" >&2
    if [[ "$failed" -eq 0 ]]; then
        printf '  [OK] - All scripts passed\n' >&2
        return 0
    fi
    printf '  [FAIL] - %s script(s) failed\n' "$failed" >&2
    return 1
}
