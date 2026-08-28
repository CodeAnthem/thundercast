# .nds/lib — functions only (sourced for every action, no register)

Put reusable ISO helpers here. They must not do work at source time.

Register them from `.nds/common/` (every action) or `.nds/<action>/` / `.roles/<id>/hooks/` (one action).

Do not prefix names with `_nds_` — that is ThunderCast-private. Use a leaf prefix (`dp_…`).
