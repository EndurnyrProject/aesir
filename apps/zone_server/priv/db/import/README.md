# Import overlay

Place local YAML customizations here. Files load after shipped data in lexicographic order, so the last matching entry wins.

Keyed databases replace an entire entry by key. List databases (`spawns`, `warps`, and `shops`) are append-only. Map-shaped databases merge by top-level key.

The tree mirrors shipped data: `import/items/*.yml`, `import/refine/refine.yml`, `import/arrows.yml`, and so on. Restart the server after changes, or use the relevant reload operation where available.

## Merge semantics

All paths below are relative to `priv/db`. Base files load before import files; both sets are sorted lexicographically. Import files are optional and gitignored.

| Domain | Import path | Merge semantics |
|---|---|---|
| items | `import/items/*.yml` | Whole entry override by `id` |
| mobs | `import/mobs/*.yml` | Whole entry override by `id` |
| spawns | `import/spawns/*.yml` | append-only per map (base spawns kept, import spawns added) |
| jobs | `import/jobs/*.yml` | Whole entry override by job `name` |
| quests | `import/quests/*.yml` | Whole entry override by `id` |
| warps | `import/warps/*.yml` | Append-only |
| shops | `import/shops/*.yml` | Append-only |
| statpoint | `import/statpoint/*.yml` | Whole entry override by level |
| item_groups | `import/item_groups/*.yml` | Whole entry override by group key |
| skill_tree | `import/skill_tree/*.yml` | Whole entry override by job name |
| castles | `import/castles/*.yml` | Whole entry override by `id` |
| homunculus species | `import/homunculus/species.yml` | Whole entry override by `id` |
| homunculus experience | `import/homunculus/exp.yml` | Whole entry override by level |
| homunculus skill trees | `import/homunculus/skill_trees.yml` | Whole entry override by `{class_id, skill_id}` |
| produce recipes | `import/produce/recipes.yml` | Whole entry override by recipe `id` |
| ore discovery | `import/produce/ore_discovery.yml` | Whole entry override by `item_id` |
| guild experience | `import/guild/exp.yml` | Whole entry override by level |
| guild skill tree | `import/guild/skill_tree.yml` | Whole entry override by skill `id` |
| refine | `import/refine/refine.yml` | Whole entry override by `group` |
| mob skills | `import/mob_skills/mob_skills.yml` | Map-merge by top-level mob id or global group |
| arrow crafting | `import/arrows.yml` | Whole entry override by source item `id` |
| map flags | `import/map_flags.yml` | Whole entry override by map name |
| drop level penalty | `import/level_penalty.yml` | Map-merge by level-difference breakpoint |
| EXP level penalty | `import/level_penalty_exp.yml` | Map-merge by level-difference breakpoint |
| MVP drop level penalty | `import/level_penalty_mvp_drop.yml` | Map-merge by level-difference breakpoint |
| MVP EXP level penalty | `import/level_penalty_mvp_exp.yml` | Map-merge by level-difference breakpoint |

`import/items/script_overrides.yml` remains the narrow exception: it replaces `on_use` by item `id` for shipped item definitions. An imported item definition is a complete custom entry and is not modified by script overrides.
