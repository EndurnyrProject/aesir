---
name: aesir-items
description: How to work on items in Aesir - the YAML item DB and its importer, the script_overrides seam, interpreted on_use/on_equip scripts, equip bonus keys, itemskill casts, and the importer/cache hazards. Use when adding items, consumable scripts, equipment bonuses, or bonus keys.
---

# Items, scripts, and equip bonuses in Aesir

## The item database

- The item DB is **mode-scoped**: `apps/zone_server/priv/db/<mode>/items/{equip,usable,etc}.yml`
  where `<mode>` is `re/` or `pre-re/` (selected at boot by `AESIR_DB_MODE`; see
  `aesir-game-modes`). The files are **fully regenerated** by
  `mix aesir.import.items [<rathena_root>]` — any hand-edit is erased on the next reimport;
  the importer writes to the active mode's dir.
- The seam for hand-authored scripts is the mode dir's `items/script_overrides.yml`:
  keyed by item id, merged over the
  generated `on_use` at load time by `ItemManagement.Loader`, never touched by the importer.
  Use it only for scripts the transpiler genuinely cannot emit — if the transpiler *should*
  handle it, fix the transpiler instead.
- Items load at runtime into `:persistent_term` via `ItemManagement.Items` (with `reload/0`)
  — the canonical runtime-catalog shape.
- `_transpile_report.md` (coverage/stub report) is gitignored — a coverage regression leaves
  no diff; sanity-check counts after importer changes.

## Script format: always Elixir DSL source, always interpreted

Item scripts (`on_use`, `on_equip`) are stored in YAML as **Elixir DSL source strings**
(`bonus(ctx, :int, 3)`, `ctx` threading, `if ... do ... end`) — never nested-list YAML
encodings.

- `on_use` is compiled at boot by `ItemManagement.ScriptCompiler` into
  `CompiledItemScripts` (reference it with `@compile {:no_warn_undefined, ...}` since it's
  boot-generated).
- `on_equip` runs through `EquipScript`: `parse!/1` (string_to_quoted + closed-vocabulary
  walk) → tuple program IR, `eval(program, refine)` at stats recompute; `to_source/1` is the
  importer-side inverse. The parser must keep folding unary minus (negative bonuses exist).
- **Never compile item scripts to per-item module clauses** — the BEAM JIT dies above
  ~6-7k clauses in one function; the corpus needs ~14k.
- The rAthena front end is unified: item scripts parse via `Npc.Transpiler.Parser`
  (`RathenaScript.Transpiler`), with bonus vocabulary in the transpiler layer and constants
  in `rathena_script/resolver.ex`.

## Bonus keys

`rathena_script/bonus_keys.ex` domains the valid bonus destinations (flat atoms plus
parameterized `{family, param}` tuples). Adding a new `bXxx` key means:

1. Add the key/domain to `BonusKeys` (watch dual-table keys and the flag-param shape where
   a 1-arg bonus implies 100 into a `*Rate` family).
2. Wire the reader — where combat/stats actually consumes the merged value. An unread key
   is a silent no-op; the bonus/modifier guard tests must be updated when keys are added.
3. Re-run the importer and check the resolved-coverage count actually moved.

Conventions to keep: race atoms — player combatant race is `:player_human`, mob demihuman
is `:demihuman` (RC_DemiHuman gear does not affect players in renewal; in pre-re players
ARE demi-human — a mode divergence, see `aesir-game-modes`); `:race2` params are
case-insensitive; `:item` params pass verbatim.

## itemskill and status-granting consumables

- `itemskill` in an item script routes through `Skill.Interpreter.item_cast/4` — bypasses
  learned/SP/catalyst/cooldown checks, still validates shape, still arms cooldown +
  aftercast delay. Don't route item casts through `cast/4`.
- A consumable that starts an `SC_*` status needs the resolver `@statuses` entry AND the
  status effect module **in the same commit** (`resolver_completeness_test.exs` enforces
  this — see the `aesir-status-effects` skill).

## Importer hazards (each has burned a session)

- **Stale beams**: `mix aesir.import.items` executes whatever is compiled — run
  `mix compile` first and verify the output actually changed.
- **Bootstrap hazard**: the importer loads the *existing* item DB while regenerating it, so
  an on-disk format older than the loader crashes the import. Migrate formats with a
  standalone `mix run --no-start` transform first, then rerun the importer canonically.
- **Stale ETF caches**: `priv/db/<mode>/*/.cache/*.etf` tracks source paths and YAML mtimes — after an
  `ItemDefinition` struct-shape change, delete the caches or boots poison silently.
- Run importers from the repo root (CWD-relative output paths).
