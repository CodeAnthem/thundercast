# NDS actions

Each subdirectory is one operator-facing flow. Discovery loads **`setup.sh` only** for
presets / preview / setup. Shared shot-caller and pipeline code lives in **`logic/`**
beside that action (loaded by `nds_app_loadFeatures` after an action is chosen).
Prompts and confirm screens live under **`wizard/`**, not here.

## Layout

```
actions/<name>/
  setup.sh                 Required — presets / preview / setup
  logic/                   Optional — action-local pipelines / shot callers
  README.md                Optional operator notes
```

Fleet packs (`fleet/nds-actions/toolkit`, `addFleetHost`) follow the same pattern.

## Required functions

| Function | Purpose |
|----------|---------|
| `action_presets` **or** `action_config` | Preset ids (one per line) and/or menu tweaks |
| `action_preview` | Describe what will happen (no mutations) |
| `action_setup` | Run the flow |

The file header must include `# Description:` (discovery reads the first 20 lines).

## Optional hooks

| Function | Purpose |
|----------|---------|
| `action_extend_settings_manager` | After action import, before settings init + heavy modules |
| `action_config` | Tweak preset priority/display after bundle enable |
| `action_presets_paths` | Extra preset dirs/files (one path per line) |
| `action_presets_extend` | Custom load/inject after builtins |
| `action_on_accept` | After preview confirm, before `action_setup` |

## Lifecycle

1. Bootstrap: mode, session, utilities manager, shared `ui/`, actionManager
2. Discover / select action
3. Import action `setup.sh`
4. `nds_app_prepareAction`: settingsManager, optional `action_extend_settings_manager`, catalog, then utilities + wizard + action-local logic + bundleManager
5. Enable action preset bundle → seed defaults
6. Configure → preview → confirm → `action_setup`

## Where things live (compose vs realize)

| Concern | Location |
|---------|----------|
| Disk / LUKS / Disko (dumb API) | `utilities/disk/` |
| nixos-install / store | `utilities/nixos/` |
| classic `configuration.nix` builder | `utilities/nixcfg/` |
| hardware-configuration.nix / artifact name | `utilities/hwconfig/` |
| facter write + sanitize | `utilities/facter/` |
| sops age enroll | `utilities/sops/` |
| deploy keys on target | `utilities/targetSeed/` |
| **Part A realize engine** (plans, steps, preflight, verify, diag) | `realize/` (`nds_realize_run`) |
| classicInstall / installFlake / apply **setup** | `actions/*/setup.sh` (thin composers → `nds_realize_run`) |
| Flake gate / hosts / leaf / probe / scaffold helpers | `actions/installFlake/logic/` |
| Open leaf with write access (shared by remoteAction, addFleetHost, toolkit) | `wizard/install/logic/install_leaf_open.sh` |
| Remote catalog cast | `actions/remoteAction/logic/` |
| Toolkit keys/seed | `fleet/nds-actions/toolkit/logic/` |
| Prompts / confirms | `wizard/install/ui/` |
| Finish / backup zip | `app/bundleManager/` (`nds_install_finish`) |

## Flake naming

- `nds_flake_prepare`, … — `actions/installFlake/logic/install_flake_helpers.sh`
- `nds_flake_probe_clone`, `nds_flake_apply_disko_strategy`, `nds_flake_install_prepare_and_verify` — `actions/installFlake/logic/install_flake_probe.sh`
- `nds_realize_confirm`, `nds_realize_run` — `realize/main.sh` (confirm before compose when the composer git-pushes)
- `_nds_realize_plan_*` / `nixos_*` / `disk_*` — realize + utilities only; composers never call these

## Layering rules (enforced by `app/tests/structure_TEST.sh`)

- No `NDS_CTX_*` snapshot anywhere. Realize reads settings via `nds_cfg_get` once per step and
  hands plain arguments to utilities.
- Utilities (`utilities/*`) never call `nds_realize_*` or install prompts; they are dumb ops.
- Composers (`actions/*/setup.sh`) validate + confirm, then call `nds_realize_run`. Nothing else installs.