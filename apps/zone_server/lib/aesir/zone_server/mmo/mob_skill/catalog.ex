defmodule Aesir.ZoneServer.Mmo.MobSkill.Catalog do
  @moduledoc """
  Static skill-name -> `{archetype, params}` table for mob skills.

  Maps each rAthena mob-skill name to one of the six Phase-2 archetypes and its
  static parameters, or `:stub` for anything not (yet) modelled. A pure lookup:
  no runtime loading, no `:persistent_term`.

  Archetypes and params:

    * `:elemental_nuke` - `%{element: atom}`
    * `:status_attack`  - `%{element: atom, status: sc_atom}` where `status`
      equals the `id:` declared by the matching module under
      `status_effect/effects/`
    * `:ground_nuke`    - `%{element: atom, area: atom}`
    * `:heal`           - `%{}`
    * `:summon_slave`   - `%{}`
    * `:teleport`       - `%{}`
    * `:self_buff`      - `%{status: sc_atom}` where `status` equals the `id:`
      declared by the matching module under `status_effect/effects/`

  Mapping is driven by a skill's *element* and *status*, not its rAthena
  damage `Type`: the archetypes deliberately flavor attacks by element (an
  attribute attack becomes an elemental nuke) regardless of whether rAthena
  types it Weapon or Magic. The rule:

    * a non-neutral attribute element and no status -> `:elemental_nuke`
    * a status -> `:status_attack` (element + status)
    * magic ground-target AoE -> `:ground_nuke`
    * neutral physical melee with no status -> `:stub` (degrades to a normal
      melee hit; e.g. `NPC_CRITICALSLASH`, `SM_BASH`)

  Elements are taken from rAthena's `db/re/skill_db.yml` (`Element:`); the
  "Weapon" element resolves to `:neutral` for these caster-less mob skills, and
  rAthena's "Dark" element is this project's `:shadow`
  (see `Combat.ElementModifiers`).

  Self-buffs without a matching modifier-status module today (`NPC_POWERUP`,
  `CR_AUTOGUARD`, `NPC_STONESKIN`, `NPC_DEFENDER`) stay `:stub`; adding those
  status effect modules is a follow-up, not part of this scope.
  """

  @typedoc "Result of a catalog lookup: an archetype tuple or `:stub`."
  @type lookup :: {atom(), map()} | :stub

  @catalog %{
    "NPC_FIREATTACK" => {:elemental_nuke, %{element: :fire}},
    "NPC_WATERATTACK" => {:elemental_nuke, %{element: :water}},
    "NPC_WINDATTACK" => {:elemental_nuke, %{element: :wind}},
    "NPC_HOLYATTACK" => {:elemental_nuke, %{element: :holy}},
    "NPC_UNDEADATTACK" => {:elemental_nuke, %{element: :undead}},
    "NPC_DARKSTRIKE" => {:elemental_nuke, %{element: :shadow}},
    "NPC_DARKNESSATTACK" => {:elemental_nuke, %{element: :shadow}},
    "MG_FIREBOLT" => {:elemental_nuke, %{element: :fire}},
    "MG_COLDBOLT" => {:elemental_nuke, %{element: :water}},
    "MG_LIGHTNINGBOLT" => {:elemental_nuke, %{element: :wind}},
    "MG_FIREBALL" => {:elemental_nuke, %{element: :fire}},
    "MG_SOULSTRIKE" => {:elemental_nuke, %{element: :ghost}},
    "MG_NAPALMBEAT" => {:elemental_nuke, %{element: :ghost}},
    "WZ_JUPITEL" => {:elemental_nuke, %{element: :wind}},
    "WZ_WATERBALL" => {:elemental_nuke, %{element: :water}},
    "NPC_STUNATTACK" => {:status_attack, %{element: :neutral, status: :sc_stun}},
    "NPC_POISON" => {:status_attack, %{element: :neutral, status: :sc_poison}},
    "NPC_POISONATTACK" => {:status_attack, %{element: :poison, status: :sc_poison}},
    "NPC_BLINDATTACK" => {:status_attack, %{element: :neutral, status: :sc_blind}},
    "NPC_CURSEATTACK" => {:status_attack, %{element: :shadow, status: :sc_curse}},
    "NPC_SILENCEATTACK" => {:status_attack, %{element: :neutral, status: :sc_silence}},
    "NPC_SLEEPATTACK" => {:status_attack, %{element: :neutral, status: :sc_sleep}},
    "MG_FROSTDIVER" => {:status_attack, %{element: :water, status: :sc_freeze}},
    "NPC_BLEEDING" => {:status_attack, %{element: :neutral, status: :sc_bleeding}},
    "WZ_METEOR" => {:ground_nuke, %{element: :fire, area: :around}},
    "WZ_STORMGUST" => {:ground_nuke, %{element: :water, area: :around}},
    "WZ_HEAVENDRIVE" => {:ground_nuke, %{element: :earth, area: :around}},
    "WZ_VERMILION" => {:ground_nuke, %{element: :wind, area: :around}},
    "MG_THUNDERSTORM" => {:ground_nuke, %{element: :wind, area: :around}},
    "NPC_EARTHQUAKE" => {:ground_nuke, %{element: :neutral, area: :around}},
    "NPC_GROUNDATTACK" => {:ground_nuke, %{element: :earth, area: :around}},
    "AL_HEAL" => {:heal, %{}},
    "NPC_ALLHEAL" => {:heal, %{}},
    "NPC_SUMMONSLAVE" => {:summon_slave, %{}},
    "NPC_CALLSLAVE" => {:summon_slave, %{}},
    "AL_TELEPORT" => {:teleport, %{}},
    "NPC_AGIUP" => {:self_buff, %{status: :sc_increaseagi}},
    "SM_ENDURE" => {:self_buff, %{status: :sc_endure}}
  }

  @doc """
  Looks up the archetype and static params for a rAthena mob-skill name.

  Returns `{archetype, params}` for a mapped skill or `:stub` for anything not
  in the table (unmodelled, cosmetic, or physical skills).
  """
  @spec archetype_for(String.t()) :: lookup()
  def archetype_for(skill_name) when is_binary(skill_name) do
    Map.get(@catalog, skill_name, :stub)
  end

  @doc """
  Returns the full skill-name -> `{archetype, params}` table.

  Only the mapped entries are present; stubbed skills are absent (they resolve
  to `:stub` via `archetype_for/1`).
  """
  @spec entries() :: %{String.t() => {atom(), map()}}
  def entries, do: @catalog
end
