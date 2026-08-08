defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgCleaner do
  @moduledoc "Remover (RG_CLEANER), an instantaneous ground-unit sweep."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 222,
    name: :rg_cleaner,
    requires: [],
    display_name: "Remover",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    range: 1,
    splash_radius: 5,
    sp_cost: [5]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Unit

  @behaviour Active

  @impl Active
  def cast(caster, {:ground, x, y}, _level, _definition) do
    Unit.destroy_in_range(caster.map_name, {x, y}, 5, [:rg_graffiti, :rg_flaggraffiti])
    {:ok, caster}
  end
end
