# NDS hooks for **addRole** (ISO). Sourced once; they must not do work at source time.

Register a function:

```bash
# nds-hook: post_install
my_fn() { ... }
nds_hook_register post_install my_fn
```

Or name the file after the event (`post_install.sh`, `post_install-age.sh`) and define `run()`.

Events: `post_scaffold` (after host files, before push), `pre_install`, `post_install`.

Same-action-only. For every action, use `.nds/common/`. Role extras: `.roles/<role>/hooks/*.sh`.
