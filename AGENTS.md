# Agent notes

## Context sources

| Path | Use |
|------|------|
| `.cursor/rules/*.mdc` | Binding constraints; human-owned |
| `.cursor/project.md` | Durable project knowledge (layout, maturity, VERSION paths, tests) |
| `**/.wip/` | Local scratch only; not shared policy or structure docs |

## Rule placement

| Kind | Location | Frontmatter |
|------|----------|-------------|
| Cross-repo | Cursor User Rules | — |
| Repo-wide | `.cursor/rules/` | `alwaysApply: true` |
| Product / area | `.cursor/rules/` | `alwaysApply: false` + path `globs` |
| Language | `.cursor/rules/` | extension `globs` |
| Hotspot | `.cursor/rules/` | narrow path `globs` |
| Temporary | chat or `.wip/` — never commit as a rule | — |

## When editing rules

- `.cursor/rules/` is maintained by the human. Add or change a rule only when asked.
- Never delete or empty a rule file unless the user explicitly requests that deletion.
- One concern per file; prefer updating an existing rule over adding a parallel one.
- Keep committed rules short and actionable. Session notes and experiments stay in chat or `.wip/`.
- Structure, VERSION paths, maturity, and Bash baselines belong in `.cursor/project.md`, not in rules.
- Living open work / ops gates live in `<product>/.wip/OPEN.md` (update when plans change).
