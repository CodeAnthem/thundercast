# Test action

Runs the **full** NDS selftest suite (same as CI / `bash src/tests/run.sh`) from
the live menu. Read-only — no system changes.

Shown only when:

```bash
export NDS_TEST=true
sudo -E bash src/app/main.sh
# pick action: test
```

## Suites

Everything CI runs: structure, actions discover, settingsManager, validators,
inputs, git, tools, bundle, nixWriter, classicConfig, install helpers, facter, …

## Prompt walking

Use **`uiSmoke`** (also `NDS_TEST=true`) — interactive human click-through of prompts.
Interactive menus are not automated; that was an explicit design choice.
