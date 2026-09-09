defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgFirebolt do
  @moduledoc """
  Fire Bolt (MG_FIREBOLT).
  Single-target fire magic that deals `level` separate
  magic hits at 100% of the caster's magic attack each, all resolved and
  reported as one strike.

  Renewal and pre-renewal agree on element, range, hit count and per-hit
  strength. Only the timing differs. Renewal splits the cast into a variable
  part that grows 300ms per level and a fixed part that grows 100ms per level
  and only gear and buffs can shorten, then holds the caster for a flat 1.4
  seconds afterwards.

  Pre-renewal has no fixed component at all: the whole cast is variable and much
  longer, 700ms per level, and the aftercast lock grows with level too, from 1
  second at level 1 to 2.8 seconds at level 10. Classic bolt spam is therefore
  far slower at the high levels.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 19,
    name: :mg_firebolt,
    requires: [],
    display_name: "Fire Bolt",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :fire,
    range: 9,
    cast_time: [
      renewal: [500, 800, 1100, 1400, 1700, 2000, 2300, 2600, 2900, 3200],
      pre_renewal: [700, 1400, 2100, 2800, 3500, 4200, 4900, 5600, 6300, 7000]
    ],
    fixed_cast_time: [300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200],
    after_cast_delay: [
      renewal: List.duplicate(1400, 10),
      pre_renewal: [1000, 1200, 1400, 1600, 1800, 2000, 2200, 2400, 2600, 2800]
    ],
    sp_cost: [12, 14, 16, 18, 20, 22, 24, 26, 28, 30]

  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, _definition) do
    case MagicAttack.execute_bolt(caster, target_id, 19, level, []) do
      {:ok, _ref} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
