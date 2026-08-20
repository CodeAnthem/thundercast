# NDS actions

Each subdirectory is one operator-facing flow. Discovery loads **`setup.sh` only** —
presets, preview, and setup live in that one file. Do not split actions into `logic/` + `ui/`.

## Layout

```
actions/<name>/
  setup.sh                 Required — presets / preview / setup
  README.md                Optional operator notes
```

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

1. Bootstrap: mode, session, tools, shared `ui/`, actionHandler
2. Discover / select action
3. Import action `setup.sh`
4. `nds_app_prepareAction`: settingsManager, optional `action_extend_settings_manager`, catalog, then git / bundle / install
5. Enable action preset bundle → seed defaults
6. Configure → preview → confirm → `action_setup`

## Flake naming

- `nds_flake_prepare`, `nds_flake_detect_disko`, … — `src/install/flake/logic/install_flake_helpers.sh`
- `nds_flake_install_prepare_and_verify`, `nds_flake_install_confirm` — `src/install/flake/logic/install_flake_pipeline.sh`
