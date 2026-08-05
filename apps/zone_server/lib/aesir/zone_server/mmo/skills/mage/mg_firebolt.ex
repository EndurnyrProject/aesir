defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgFirebolt do
  @moduledoc """
  Fire Bolt (MG_FIREBOLT). Single-target fire magic that deals `level` separate
  magic hits at 100% MATK each.

  rAthena renewal: fire element, 100% ratio per hit, hit count equal to the cast
  level, range 9.
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
    cast_time: [500, 800, 1100, 1400, 1700, 2000, 2300, 2600, 2900, 3200],
    fixed_cast_time: [300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200],
    after_cast_delay: [1400, 1400, 1400, 1400, 1400, 1400, 1400, 1400, 1400, 1400],
    sp_cost: [12, 14, 16, 18, 20, 22, 24, 26, 28, 30]

  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, _definition) do
    case MagicAttack.execute_bolt(caster, target_id, 19, level, []) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
