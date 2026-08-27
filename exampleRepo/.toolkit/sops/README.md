# sops map (toolkit-managed)

`secrets.map` lists secret *files*. Toolkit compiles `.sops.yaml` from this plus `machines/*/age.pub`.

Do not put age public keys in this file. Membership:

- `operator` yaml → operator pub
- paths with `%s` → operator + that host’s `age.pub`
- other ids (luks, swarm_*) → operator + hosts that list the id in `machines/<name>/groups`

Normal use: toolkit Init / Apply. You should not hand-edit `.sops.yaml` (Apply overwrites it).
