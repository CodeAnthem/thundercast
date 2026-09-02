# UI smoke action

Interactive **prompt walk** — no partition, no `nixos-install`, no flake clone, no GitHub API.

Shown in the action menu only when:

```bash
export NDS_TEST=true
sudo -E bash nds/src/app/main.sh
```

## What it does

Cycles through shared prompts, settingsManager field asks, install confirms
(with fake disk/IP), git collision/hints, and failure display so you can verify
menu wiring after a UI change.

## Related

| Action | Flag | Purpose |
|--------|------|---------|
| `test` | `NDS_TEST=true` | Full CI selftest suite (automated, read-only) |
| `uiSmoke` | `NDS_TEST=true` | This interactive prompt walk |

Automated selftests: `bash nds/dev/selftest.sh` (also CI).
