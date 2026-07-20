defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDemonbane do
  @moduledoc """
  Demon Bane (AL_DEMONBANE).

  Passive that adds flat physical ATK against undead and demon targets. The
  bonus is applied in the physical damage pipeline (`Combat.DamageCalculator`
  via `Combat.RaceModifiers.demon_bane_atk/2`), read from the combatant's
  precomputed `demon_bane_level`. This module is a catalog/skill-tree entry only
  and contributes no passive callback of its own.
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
