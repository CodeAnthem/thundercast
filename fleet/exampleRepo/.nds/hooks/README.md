# `.nds/hooks`

ISO lifecycle hooks for **one action**. NDS does not load a catch-all folder.

| Path | When |
|------|------|
| `lib/*.sh` | Every action — functions only, no `nds_hook_register` |
| `<action>/*.sh` | Only when `NDS_ACTION` matches (`toolkit`, `addFleetHost`, …) |

Events: `post_scaffold`, `pre_install`, `post_install`. Register with `nds_hook_register` or name the file after the event.

A new leaf action does **not** inherit another action’s hooks. Role extras stay in `.roles/<id>/hooks/`.
