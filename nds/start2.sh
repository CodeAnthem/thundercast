#!/usr/bin/env bash
# ==================================================================================================
# Get a git repository onto disk
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2026-09-23
# Description:   Clone or update a repository, then optionally execute a script inside it.
# ==================================================================================================

set -euo pipefail

# ----------------------------------------------------------------------------------
# CONFIG
# ----------------------------------------------------------------------------------
REPO_URL=https://github.com/CodeAnthem/thundercast.git
REPO_DIR=/tmp/thundercast
ENTRY=nds/src/app/main.sh

readonly REPO_URL REPO_DIR ENTRY
readonly -a DEFAULT_BRANCHES=(main master)

# ----------------------------------------------------------------------------------
# RUNTIME
# ----------------------------------------------------------------------------------
NO_EXEC=0
TARGET_BRANCH=""
TARGET_SCRIPT_ARGS=()
REMOTE_HEADS=""

# ----------------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------------
log() { printf '  [%s] - %s\n' "$1" "$2" >&2; }

die() {
    log FAIL "$1"
    shift
    [[ $# -eq 0 ]] || printf '  -> %s\n' "$@" >&2
    exit 1
}

# Caller GIT_* vars would override git -C. Repo hooks must not run on a pre-seeded tree.
git() {
    env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE \
        git -c core.hooksPath=/dev/null "$@"
}

# ----------------------------------------------------------------------------------
# ARGUMENT PARSING
# ----------------------------------------------------------------------------------
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --branch:*)
                TARGET_BRANCH=${1#--branch:}
                [[ -n $TARGET_BRANCH && $TARGET_BRANCH != -* ]] || die "Invalid branch name"
                ;;
            -n|--no-exec) NO_EXEC=1 ;;
            --)
                shift
                TARGET_SCRIPT_ARGS+=("$@")
                return 0
                ;;
            *) TARGET_SCRIPT_ARGS+=("$1") ;;
        esac
        shift
    done
}

# ----------------------------------------------------------------------------------
# BRANCH VALIDATION
# ----------------------------------------------------------------------------------
load_remote_heads() {
    REMOTE_HEADS=${ git ls-remote --heads -- "$REPO_URL"; } || die \
        "Repository is unreachable" \
        "Repository: ${REPO_URL}"
}

has_remote_branch() {
    [[ $'\n'"$REMOTE_HEADS"$'\n' == *$'\trefs/heads/'"$1"$'\n'* ]]
}

select_branch() {
    local branch

    if [[ -n $TARGET_BRANCH ]]; then
        has_remote_branch "$TARGET_BRANCH" || die \
            "Branch '${TARGET_BRANCH}' does not exist in repository" \
            "Repository: ${REPO_URL}" \
            "Please specify a valid branch using --branch:name"
        log INFO "Using branch: ${TARGET_BRANCH}"
        return 0
    fi

    for branch in "${DEFAULT_BRANCHES[@]}"; do
        if has_remote_branch "$branch"; then
            TARGET_BRANCH=$branch
            log INFO "Using default branch: ${TARGET_BRANCH}"
            return 0
        fi
    done

    log WARN "None of the default branches exist"
    printf '  -> %s\n' "Tried: ${DEFAULT_BRANCHES[*]}" "Repository: ${REPO_URL}" >&2
    exit 1
}

# ----------------------------------------------------------------------------------
# SETUP REPOSITORY
# ----------------------------------------------------------------------------------
clone_repo() {
    mkdir -m 700 -- "$REPO_DIR" || die "Could not create destination" "Path: ${REPO_DIR}"
    if git clone --quiet --branch "$TARGET_BRANCH" -- "$REPO_URL" "$REPO_DIR"; then
        log OK "Successfully cloned repository"
        return 0
    fi
    rm -rf -- "$REPO_DIR"
    die "Failed to clone repository"
}

update_repo() {
    local origin current
    [[ -d ${REPO_DIR}/.git ]] || die \
        "Destination exists and is not a git repository" \
        "Path: ${REPO_DIR}"

    origin=${ git -C "$REPO_DIR" config --get remote.origin.url 2>/dev/null || true; }
    [[ $origin == "$REPO_URL" ]] || die \
        "Destination is a different repository" \
        "Path: ${REPO_DIR}" \
        "Origin: ${origin:-<none>}" \
        "Expected: ${REPO_URL}"

    current=${ git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true; }
    [[ $current == "$TARGET_BRANCH" ]] || log INFO "Switching from ${current:-unknown} to ${TARGET_BRANCH}"

    git -C "$REPO_DIR" fetch --quiet origin "$TARGET_BRANCH" || die "Failed to fetch repository"
    git -C "$REPO_DIR" checkout --quiet -f -B "$TARGET_BRANCH" "origin/${TARGET_BRANCH}" || die \
        "Failed to update branch ${TARGET_BRANCH}"
    log OK "Successfully reset repository"
}

place_repo() {
    if [[ -L $REPO_DIR ]]; then
        die "Destination is a symlink" "Path: ${REPO_DIR}"
    fi
    if [[ ! -e $REPO_DIR ]]; then
        clone_repo
        return 0
    fi
    [[ -d $REPO_DIR ]] || die "Destination exists and is not a directory" "Path: ${REPO_DIR}"
    [[ -O $REPO_DIR ]] || die "Destination is owned by another user" "Path: ${REPO_DIR}"
    update_repo
}

# ----------------------------------------------------------------------------------
# SECURITY CHECKS
# ----------------------------------------------------------------------------------
check_untracked_files() {
    local list answer line
    list=${ git -C "$REPO_DIR" clean -ffdx -n; } || die "Failed to list untracked files"
    [[ -n $list ]] || return 0

    log WARN "Untracked or ignored files detected (potential security risk)"
    while IFS= read -r line; do
        printf ' - %s/%s\n' "$REPO_DIR" "${line#Would remove }" >&2
    done <<<"$list"

    # Probe in a subshell: a failed exec would otherwise abort this non-interactive shell.
    if ! (exec 3</dev/tty) 2>/dev/null || ! read -rp " Delete these files to ensure repo purity? [Y/N]: " answer </dev/tty; then
        log WARN "Could not read answer; leaving untracked files in place"
        return 0
    fi
    if [[ ${answer^^} == "Y" ]]; then
        git -C "$REPO_DIR" clean -ffdx --quiet || die "Failed to remove untracked files"
        log OK "Untracked files removed"
        return 0
    fi
    log INFO "Proceeding with untracked files present"
}

# ----------------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------------
parse_arguments "$@"
load_remote_heads
select_branch
place_repo
check_untracked_files

if [[ $NO_EXEC -eq 1 ]]; then
    log INFO "No execution requested, exiting"
    exit 0
fi
if [[ -z $ENTRY ]]; then
    log INFO "No entry script configured, exiting"
    exit 0
fi

entry_path=${REPO_DIR}/${ENTRY}
[[ -f $entry_path ]] || die "Entry script not found" "${entry_path}"

log INFO "Starting ${ENTRY}"
# Failed exec aborts a non-interactive shell. execfail lets noexec /tmp fall through to bash.
shopt -s execfail
[[ -x $entry_path ]] && exec "$entry_path" "${TARGET_SCRIPT_ARGS[@]}" || true
exec bash -euo pipefail -- "$entry_path" "${TARGET_SCRIPT_ARGS[@]}"
