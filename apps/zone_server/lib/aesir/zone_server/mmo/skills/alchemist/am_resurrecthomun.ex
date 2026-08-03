defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmResurrecthomun do
  @moduledoc "Homunculus Resurrection."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 247,
    name: :am_resurrecthomun,
    display_name: "Homunculus Resurrection",
    max_level: 5,
    target_type: :self,
    sp_cost: [74, 68, 62, 56, 50],
    cast_time: List.duplicate(2_000, 5),
    fixed_cast_time: List.duplicate(1_000, 5),
    cooldown: [140_000, 110_000, 80_000, 50_000, 20_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @doc false
  def lifecycle_operation, do: :resurrection

  @impl Active
  def cast(caster, :self, level, _definition),
    do: {:deferred, caster, {:homunculus_lifecycle, {:resurrection, level}}}
end
