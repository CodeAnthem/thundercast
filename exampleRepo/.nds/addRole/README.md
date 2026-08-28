# NDS hooks for **addRole** (ISO). Sourced once; they must not do work at source time.

Put functions in `.nds/lib/`. Here, only register:

```bash
nds_hook_register post_install dp_note_age_pubkey
```

Or name the file after the event (`post_install.sh`) and define `run()`.

Events: `post_scaffold` (after host files, before push), `pre_install`, `post_install`.

Every-action registers: `.nds/common/`. Role extras: `.roles/<role>/hooks/*.sh`.
