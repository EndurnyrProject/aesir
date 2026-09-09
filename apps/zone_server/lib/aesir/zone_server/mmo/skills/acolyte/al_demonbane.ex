defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDemonbane do
  @moduledoc """
  Demon Bane (AL_DEMONBANE).

  Passive that adds flat physical ATK against undead and demon targets: the
  learned level times `base level / 20 + 3`, truncated. A target counts as
  undead by race or by an undead defence element, so a demi-human with undead
  armour is hit by the bonus too. The bonus is applied in the physical damage
  pipeline (`Combat.DamageCalculator` via
  `Combat.RaceModifiers.demon_bane_atk/2`), read from the combatant's
  precomputed `demon_bane_level`. This module is a catalog/skill-tree entry only
  and contributes no passive callback of its own.

  Renewal: the caster's base level is part of the bonus, so it grows with the
  character, and the mastery ATK it feeds is added after the defence formula.

  Pre-renewal: the same magnitude, including the base-level term. What differs
  is only where the pipeline adds mastery ATK, which is a property of the shared
  damage model rather than of this passive.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 23,
    name: :al_demonbane,
    display_name: "Demon Bane",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
