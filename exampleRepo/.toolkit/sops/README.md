# sops map (toolkit-managed)

`secrets.map` is `id=path` (quote the path if it has spaces). Toolkit compiles `.sops.yaml` from this plus machine pubs.

Do not put age public keys here. Membership:

- `operator` yaml → operator pub
- paths with `%s` → operator + that host’s `keys/age.pub`
- other ids (luks, swarm_*) → operator + hosts whose `config` lists the id in `groups`

Normal use: toolkit Init / Apply. Do not hand-edit `.sops.yaml`.
