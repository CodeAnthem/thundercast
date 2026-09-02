# Test action

Runs the **full** NDS selftest suite (same as CI / `bash nds/dev/selftest.sh`) from
the live menu. Read-only — no system changes.

Shown only when:

```bash
export NDS_TEST=true
curl -sSL https://raw.githubusercontent.com/CodeAnthem/thundercast/main/nds/start.sh | bash
# pick action: test
```

## Suites

Everything CI runs: structure, actions discover, settingsManager (including sessions / recipes),
validators, inputs, git, tools, bundle, nixWriter, classicConfig, install helpers, facter, …

Operator backlog: [nds/docs/TODO.md](../../../docs/TODO.md).

## Prompt walking

Use **`uiSmoke`** (also `NDS_TEST=true`) — interactive human click-through of prompts.
Interactive menus are not automated; that was an explicit design choice.
