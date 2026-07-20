defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDp do
  @moduledoc """
  Divine Protection (AL_DP).

  Passive that reduces physical damage taken from undead and demon attackers.
  The effect is a flat soft-DEF applied in the physical damage pipeline
  (`Combat.DamageCalculator` via `Combat.RaceModifiers.divine_protection_def/2`),
  read from the combatant's precomputed `divine_protection_level`. This module is
  a catalog/skill-tree entry only and contributes no passive callback of its own.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 22,
    name: :al_dp,
    display_name: "Divine Protection",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
