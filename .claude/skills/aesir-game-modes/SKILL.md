---
name: aesir-game-modes
description: How to identify renewal vs pre-renewal (trans-era classic) content and mechanics - the rAthena research method (#ifdef RENEWAL, Mode-tagged dbs, npc overlays), a divergence cheat sheet, the Aesir mode seam (data + mechanics), and the writing rules for mode-aware code. Use when researching any mechanic in rAthena, deciding whether a formula/item/skill/status/NPC differs between modes, or working on mode-scoped data and content.
---

# Renewal vs pre-renewal in Aesir

Aesir serves two rulesets from one artifact: **renewal** (the flagship) and **pre-renewal**
(trans-era classic: levels 99/70, 2-2 + trans classes, no 3rd/4th jobs, no trait substats).
The mode is chosen at boot by `AESIR_DB_MODE` (`renewal` | `pre_renewal`), frozen for the
node's lifetime, and can never disagree between data and mechanics. Never introduce a
compile-time mode switch (`Application.compile_env`) — the seam is runtime, by decision
(spec `2026-08-24-pre-renewal-mode`).

## Identifying mode differences in rAthena (the research method)

rAthena (checkout `~/Development/personal/rathena`) implements both modes with a
compile-time split. When researching ANY mechanic, always check whether it is mode-gated:

- **Code**: grep the mechanic for `#ifdef RENEWAL` / `#ifndef RENEWAL` /
  `#ifdef RENEWAL_<SUB>` in `src/map/` (densest: `battle.cpp`, `status.cpp`, `pc.cpp`,
  `skill.cpp`). The `#ifndef RENEWAL` / `#else` branch is the pre-renewal formula.
  A mechanic with no `RENEWAL` guard anywhere is mode-shared.
- **The seven toggles** (`src/config/renewal.hpp`): `RENEWAL` (master formula switch),
  `RENEWAL_CAST` (VCT/FCT split), `RENEWAL_DROP` / `RENEWAL_EXP` (level-gap penalties),
  `RENEWAL_LVDMG` (>99 level damage scaling), `RENEWAL_ASPD`, `RENEWAL_STAT` (stat cost /
  HP-SP model). Aesir does NOT mirror the sub-toggles — one mode flag drives everything.
- **Macro helpers** (`src/config/const.hpp`): `RE_LVL_DMOD`/`RE_LVL_MDMOD` (renewal skill
  level scaling), `VARCAST_REDUCTION`, `MOB_HIT`/`MOB_FLEE` (mode-dependent mob baselines),
  `MAP_DEFAULT_*` (start map: renewal `iz_int`, pre-re `new_1-1`).
- **Data**: shared root `db/*.yml` declare `Imports:` rows tagged `Mode: Renewal` /
  `Mode: Prerenewal` pointing into `db/re/` / `db/pre-re/`. A table present only under
  `db/re/` (e.g. `level_penalty.yml`, `elemental_db.yml`) means the system does not exist
  in pre-re at all — absence is the mechanic.
- **NPCs/scripts**: `npc/` root categories are shared; `npc/re/` (475 files) and
  `npc/pre-re/` (173 files) are mode overlays selected by
  `npc/{re,pre-re}/scripts_main.conf`. The `re/`-only delta is mostly 3rd-job content,
  instances, and newer quests.
- **Runtime escapes** (rare): `battle.conf` toggles whose defaults differ per mode
  (`enable_baseatk` vs `enable_baseatk_renewal`) and per-map flags
  (`norenewalexppenalty`, `norenewaldroppenalty`).

## Divergence cheat sheet (what changes between modes)

- **Derived stats**: renewal HIT/FLEE add LUK and CON terms (`hit += luk/3 + 2*con`);
  pre-re is `hit = level + dex`, `flee = level + agi`. Renewal DEF₂ can go negative;
  pre-re floors at 1. Soft-def/soft-mdef formulas differ entirely.
- **Trait substats** (POW/STA/WIS/SPL/CON/CRT and P.Atk/S.Matk/Res/Mres/H.Plus/C.Rate):
  renewal-only. In pre-re they are allocation-refused and all-zero — formulas never read
  them; zeroed traits make downstream consumers (patk multiplier, crate, hplus) naturally
  inert.
- **Cast time**: renewal splits variable (reduced by `sqrt((2*DEX+INT)/530)`) + fixed
  (only gear/buffs reduce it). Pre-re is a single cast scaled by
  `(dex_scale - DEX)/dex_scale` — no fixed component.
- **ASPD**: renewal is a float formula (AGI-dominant, sqrt term, shield/dual-wield
  penalties); pre-re is integer weapon-delay amotion (`amotion -= amotion*(4*agi+dex)/1000`,
  dual wield `(a+b)*7/10`).
- **Element modifiers**: renewal mutates a *ratio* (additive percentage points into the
  attr table); pre-re multiplies *damage* directly. Skill element bonuses (Volcano, Oratio,
  endow-adjacent effects) therefore apply differently per mode.
- **EXP/drop level-gap penalty**: renewal-only (data tables). Pre-re has none — in Aesir
  the `level_penalty*` domains are mode-optional and absent means neutral rates.
- **Stat points**: renewal raise-cost curve vs classic `2 + (value-1)/10`, cap 99.
- **Era content**: pre-re = trans-era. No 3rd/4th jobs, their skills, their gear, doram,
  instances, or renewal-era quests. Those modules/data simply are not reachable in pre-re
  (excluded by skill trees / job data / content sets), not deleted.
- **Race gotcha**: RC_DemiHuman gear does not affect players in renewal (players are
  `RC_Player_Human`); in pre-re players ARE demi-human, so anti-demihuman modifiers hit
  players in PvP. A Phase-2 class of divergence — flag it when touching race modifiers.

## The Aesir seam

- **Data** (live today): `Db.Layout` + `Db.Source` resolve every domain through the mode —
  `priv/db/re/` vs `priv/db/pre-re/`, shared top-level domains ignore mode. Importers write
  to the active mode's dir; run them under `AESIR_DB_MODE=pre_renewal` to produce pre-re
  data. Mode-optional domains (declared with a `modes:` restriction in `Layout`) return no
  sources instead of raising.
- **Mechanics** (Phase-1 architecture, implementation in flight — check the code before
  assuming modules exist): `Aesir.Commons.GameMode.mode/0` is the single accessor;
  `Mmo.Mechanics` facade resolves seven behaviour families
  (`PlayerFormulas`, `MobFormulas`, `CastTime`, `StatCost`, `Defense`, `Elements`, `Sizes`)
  to `.Renewal`/`.PreRenewal` impl modules at boot. Orchestration (`stats.ex`, damage
  calculators and interpreter) stays shared; only leaf formulas dispatch. Design:
  `specs/2026-08-24-pre-renewal-mode/architecture.md` in the vault.
- **Phasing**: Phase 1 = seam + core formulas + pre-re data. Phase 2 = per-skill/status
  behavior divergences (until then, pre-re runs today's renewal-flavored skill/status
  behavior — a known, accepted gap). Phase 3 = classic NPC/content corpus.

## Writing rules for mode-aware work

- **Never** cite rAthena files/functions in Aesir code or docs — describe the mechanic.
  (Vault spec/architecture docs and test comments citing the pre-re formula source are the
  allowed exception for formula provenance.)
- When implementing or touching a skill/status whose behavior differs by mode, document
  BOTH behaviors in the `@moduledoc` even if only renewal is implemented — these notes are
  the Phase-2 audit inventory (~130 modules carry them already).
- New formula work goes through the `Mechanics` family seam, never inline
  `if mode == :renewal` branches scattered in orchestration code.
- Mode-specific tests: formula pairs test impl modules directly (`async: true`, no global state);
  orchestration uses explicit inputs or private process-local Mimic. New tests never mutate
  application/system env or `:persistent_term`; mode-specific integration starts the test process
  with `AESIR_DB_MODE` already set.
- Trans-era boundary check for content: if it requires a 3rd/4th job, a trait stat, or a
  renewal-era system (instances, doram), it is renewal-only content — keep it out of
  pre-re data/skill trees rather than guarding it in code.
