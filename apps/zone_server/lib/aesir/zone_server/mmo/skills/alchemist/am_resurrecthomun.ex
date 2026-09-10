defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmResurrecthomun do
  @moduledoc """
  Homunculus Resurrection.

  Renewal: a 2 s cast plus 1 s fixed and a 140 to 20 s cooldown. Pre-renewal: a
  2 s cast with no cooldown. Both revive with 20 percent HP per level.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 247,
    name: :am_resurrecthomun,
    display_name: "Homunculus Resurrection",
    max_level: 5,
    target_type: :self,
    sp_cost: [74, 68, 62, 56, 50],
    cast_time: List.duplicate(2_000, 5),
    fixed_cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    cooldown: [renewal: [140_000, 110_000, 80_000, 50_000, 20_000], pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @doc false
  def lifecycle_operation, do: :resurrection

  @impl Active
  def cast(caster, :self, level, _definition),
    do: {:deferred, caster, {:homunculus_lifecycle, {:resurrection, level}}}
end
