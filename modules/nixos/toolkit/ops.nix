# ==================================================================================================
# ThunderCast - NixOS installer and operator toolkit by CodeAnthem
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-19 | Modified: 2026-08-20
# Description: toolkit menu wrapper + VERSION-aware tools updater — opts.nixos.toolkit.ops
# ==================================================================================================

{ config, lib, my, pkgs, ... }: with lib; with my.lib; let
# ==================================================================================================
# ModuleVariables
# ==================================================================================================
  optionPath = mkOptionPath [ "toolkit" "ops" ];
  scriptsPath = mkOptionPath [ "toolkit" "scripts" ];
  cfg = lib.attrByPath optionPath {} config;
  scfg = lib.attrByPath scriptsPath {} config;

  wrapper = pkgs.writeShellScriptBin "toolkit" ''
    set -euo pipefail
    dest='${scfg.dest}'
    current="$dest/current/toolkit.sh"
    if [[ ! -x "$current" ]]; then
      echo "toolkit tools missing at $current" >&2
      echo "Run: toolkit-update" >&2
      echo "(Tools do not arrive via nixos-rebuild / comin.)" >&2
      exit 1
    fi
    export TCAST_TOOLKIT_DEST="$dest"
    export TCAST_LEAF_DIR='${scfg.leafDir}'
    export TCAST_LEAF_REPO='${scfg.leafRepo}'
    export TCAST_LEAF_BRANCH='${scfg.leafBranch}'
    exec "$current" "$@"
  '';

  tcSops = pkgs.writeShellScriptBin "tc-sops" ''
    set -euo pipefail
    exec ${wrapper}/bin/toolkit sops "$@"
  '';

  updater = pkgs.writeShellScriptBin "toolkit-update" ''
    set -euo pipefail
    DEST='${scfg.dest}'
    REPO='${scfg.repo}'
    BRANCH='${scfg.branch}'
    SPARSE='${scfg.sparsePath}'
    YES=false
    SEED=false
    for arg in "$@"; do
      case "$arg" in
        --yes|-y) YES=true ;;
        --seed) SEED=true ;;
        --help|-h)
          echo "toolkit-update [--yes] [--seed]"
          echo "Fetch $SPARSE from $REPO ($BRANCH) into $DEST"
          echo "Compares VERSION and shows CHANGELOG. Not part of nixos-rebuild or comin."
          exit 0
          ;;
      esac
    done

    SRC="$DEST/src"
    CURRENT="$DEST/current"
    mkdir -p "$DEST"

    if command -v tc-git-ssh >/dev/null 2>&1; then
      export GIT_SSH_COMMAND="tc-git-ssh"
    elif command -v nds-git-ssh >/dev/null 2>&1; then
      export GIT_SSH_COMMAND="nds-git-ssh"
    elif [[ -x /root/.ssh/nds-git-ssh ]]; then
      export GIT_SSH_COMMAND="/root/.ssh/nds-git-ssh"
    fi

    read_ver() {
      local file="$1"
      if [[ -f "$file" ]]; then
        tr -d '[:space:]' < "$file"
      else
        printf 'unknown'
      fi
    }

    link_current() {
      [[ -f "$SRC/$SPARSE/toolkit.sh" ]] || { echo "toolkit-update: missing $SRC/$SPARSE/toolkit.sh" >&2; exit 1; }
      chmod +x "$SRC/$SPARSE/toolkit.sh" || true
      ln -sfn "$SRC/$SPARSE" "$CURRENT"
    }

    clone_repo() {
      rm -rf "$SRC"
      if git clone --filter=blob:none --sparse "$REPO" "$SRC"; then
        git -C "$SRC" sparse-checkout set "$SPARSE"
        git -C "$SRC" checkout "$BRANCH" 2>/dev/null \
          || git -C "$SRC" checkout -B "$BRANCH" "origin/$BRANCH"
      else
        rm -rf "$SRC"
        git clone --branch "$BRANCH" --single-branch "$REPO" "$SRC"
      fi
      link_current
    }

    # NDS may have cloned from a live-ISO temp path; never fetch that.
    ensure_origin() {
      local url
      url="$(git -C "$SRC" remote get-url origin 2>/dev/null || true)"
      if [[ -z "$url" ]]; then
        git -C "$SRC" remote add origin "$REPO"
      elif [[ "$url" != "$REPO" ]]; then
        echo "toolkit-update: origin was $url"
        echo "toolkit-update: pointing origin at $REPO"
        git -C "$SRC" remote set-url origin "$REPO"
      fi
    }

    if [[ ! -d "$SRC/.git" ]]; then
      echo "toolkit-update: seeding $DEST from $REPO"
      clone_repo
      echo "toolkit-update: seeded $(read_ver "$CURRENT/VERSION") ($(git -C "$SRC" rev-parse --short HEAD))"
      exit 0
    fi

    if [[ "$SEED" == true ]]; then
      echo "toolkit-update: already seeded $(read_ver "$CURRENT/VERSION") ($(git -C "$SRC" rev-parse --short HEAD))"
      link_current
      exit 0
    fi

    ensure_origin
    if ! git -C "$SRC" fetch origin; then
      echo "toolkit-update: fetch failed — re-clone from $REPO"
      clone_repo
      echo "toolkit-update: now $(read_ver "$CURRENT/VERSION") ($(git -C "$SRC" rev-parse --short HEAD))"
      exit 0
    fi
    LOCAL=$(git -C "$SRC" rev-parse HEAD)
    REMOTE=$(git -C "$SRC" rev-parse "origin/$BRANCH")
    local_ver=$(read_ver "$CURRENT/VERSION")
    remote_ver=$(git -C "$SRC" show "origin/$BRANCH:$SPARSE/VERSION" 2>/dev/null | tr -d '[:space:]' || true)
    remote_ver="''${remote_ver:-unknown}"

    if [[ "$LOCAL" == "$REMOTE" ]]; then
      echo "toolkit-update: already up to date ($local_ver / $LOCAL)"
      link_current
      exit 0
    fi

    echo "Installed tools: $local_ver"
    echo "Available:       $remote_ver"
    echo
    echo "Commits:"
    git -C "$SRC" --no-pager log --oneline "$LOCAL..$REMOTE" -- "$SPARSE" || true
    echo
    if git -C "$SRC" cat-file -e "origin/$BRANCH:$SPARSE/CHANGELOG.md" 2>/dev/null; then
      echo "Changelog (incoming):"
      git -C "$SRC" --no-pager diff --no-color "$LOCAL" "origin/$BRANCH" -- "$SPARSE/CHANGELOG.md" || true
      echo
    fi
    echo "This updates bash under $CURRENT only — not NixOS."
    if [[ "$YES" != true ]]; then
      if [[ ! -t 0 ]]; then
        echo "toolkit-update: no TTY — pass --yes" >&2
        exit 1
      fi
      printf 'Update tools from %s to %s? [y/N] ' "$local_ver" "$remote_ver"
      read -r reply
      [[ "$reply" == y || "$reply" == Y ]] || exit 1
    fi
    git -C "$SRC" merge --ff-only "origin/$BRANCH"
    link_current
    echo "toolkit-update: now $(read_ver "$CURRENT/VERSION") ($(git -C "$SRC" rev-parse --short HEAD))"
  '';


in {
# ==================================================================================================
# Options
# ==================================================================================================
  options = lib.setAttrByPath optionPath {
    enable = lib.mkEnableOption "toolkit menu and explicit toolkit-update";
  };


# ==================================================================================================
# Config
# ==================================================================================================
  config = lib.mkIf (cfg.enable or false) {
    environment.systemPackages = [ wrapper updater tcSops ];

    systemd.tmpfiles.rules = [
      "d ${scfg.dest} 0750 root root -"
    ];

    systemd.services.toolkit-scripts-seed = {
      description = "Seed toolkitScripts once if missing (not a NixOS/comin update)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "!${scfg.dest}/current/toolkit.sh";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${updater}/bin/toolkit-update --yes --seed";
      };
    };
  };
}
