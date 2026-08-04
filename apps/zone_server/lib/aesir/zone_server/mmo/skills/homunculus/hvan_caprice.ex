defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanCaprice do
  @moduledoc """
  Caprice randomly executes one canonical elemental bolt at the learned Caprice rank.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8_013,
    name: :hvan_caprice,
    display_name: "Caprice",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    sp_cost: [22, 24, 26, 28, 30],
    cooldown: [2_000, 2_200, 2_400, 2_600, 2_800]

  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @bolts [14, 19, 20, 90]

  @impl Active
  def cast(caster, {:unit, target_ref}, level, _definition) do
    bolt_id = Enum.at(@bolts, :rand.uniform(4) - 1)

    with :ok <- MagicAttack.execute_bolt(caster, target_ref, bolt_id, level, []) do
      {:ok, caster}
    end
  end
end
