defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDp do
  @moduledoc """
  Divine Protection (AL_DP).

  Passive that reduces physical damage taken from undead and demon attackers by
  adding `(base level / 25 + 3) * learned level + 0.5` flat soft defence,
  truncated. An attacker counts as undead by race or by an undead defence
  element. The effect is applied in the physical damage pipeline
  (`Combat.DamageCalculator` via `Combat.RaceModifiers.divine_protection_def/2`),
  read from the combatant's precomputed `divine_protection_level`. This module is
  a catalog/skill-tree entry only and contributes no passive callback of its own.

  Renewal: the defender's base level is part of the bonus, and it is added to a
  soft defence that is the defender's status DEF directly.

  Pre-renewal: the same magnitude, including the base-level term. What differs
  is only the soft defence it is added to, which is the classic randomised
  VIT-based value; that is a property of the shared defence model rather than of
  this passive.
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
