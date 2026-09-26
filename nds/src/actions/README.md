# NDS actions

Each subdirectory is one operator-facing flow. Discovery loads **`setup.sh` only** for
presets / preview / setup. Shared shot-caller and pipeline code lives in **`logic/`**
beside that action (loaded when that action's `setup.sh` is sourced).
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
| `action cook` | Run the flow |

The file header must include `# Description:` (discovery reads the first 20 lines).

## Optional hooks

| Function | Purpose |
|----------|---------|
| `action_extend_settings_manager` | After action import, before settings init + heavy modules |
| `action_config` | Tweak preset priority/display after bundle enable |
| `action_presets_paths` | Extra preset dirs/files (one path per line) |
| `action_presets_extend` | Custom load/inject after builtins |
| `action_on_accept` | After preview confirm, before `action cook` |

## Lifecycle

1. Bootstrap: mode, session, utilities manager, shared `ui/`, actionManager
2. Discover / select action
3. Import action `setup.sh`
4. Pipeline cook: enable groups, seed, load the recipe, pins, wizard or validate, then `action_cook`
5. Enable action preset bundle → seed defaults
6. Configure → preview → confirm → `action cook`

## Where things live (compose vs realize)

| Concern | Location |
|---------|----------|
| Disk / LUKS / Disko (dumb API) | `utilities/disk/` |
| the NixOS installer / store | `utilities/nixos/` |
| classic `configuration.nix` builder | `utilities/nixcfg/` |
| hardware-configuration.nix / artifact name | `utilities/hwconfig/` |
| facter write + sanitize | `utilities/facter/` |
| sops age enroll | `utilities/sops/` |
| deploy keys on target | `utilities/targetSeed/` |
| **Part A realize engine** (plans, steps, preflight, verify, diag) | `realize/` (`realize`) |
| classicInstall / installFlake / apply **setup** | `actions/*/setup.sh` (thin composers → `realize`) |
| Flake gate / hosts / leaf / probe / scaffold helpers | `actions/installFlake/logic/` |
| Open leaf with write access (shared by remoteAction, addFleetHost, toolkit) | `wizard/install/logic/install_leaf_open.sh` |
| Remote catalog cast | `actions/remoteAction/logic/` |
| Toolkit keys/seed | `fleet/nds-actions/toolkit/logic/` |
| Prompts / confirms | `wizard/install/ui/` |
| Finish / backup zip | `app/bundleManager/` (`nds_install_finish`) |

## Flake naming

- `nds_flake_prepare`, … — `actions/installFlake/logic/install_flake_helpers.sh`
- `nds_flake_probe_clone`, `nds_flake_apply_disko_strategy`, `nds_flake_install_prepare_and_verify` — `actions/installFlake/logic/install_flake_probe.sh`
- `confirm`, `realize` — `realize/main.sh` (confirm before compose when the composer git-pushes)
- `_realize_plan_*` / `nixos_*` / `disk_*` — realize + utilities only; composers never call these

## Layering rules (enforced by `app/tests/structure_TEST.sh`)

- No `NDS_CTX_*` snapshot anywhere. Realize reads settings via `recipe_get` once per step and
  hands plain arguments to utilities.
- Utilities (`utilities/*`) never call `realize_*` or install prompts; they are dumb ops.
- Composers (`actions/*/setup.sh`) validate + confirm, then call `realize`. Nothing else installs.