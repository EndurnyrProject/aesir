defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmRest do
  @moduledoc "Rest."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 244,
    name: :am_rest,
    display_name: "Vaporize",
    max_level: 1,
    target_type: :self,
    sp_cost: [50],
    cooldown: [20_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @doc false
  def lifecycle_operation, do: :rest

  @impl Active
  def cast(caster, :self, _level, _definition),
    do: {:deferred, caster, {:homunculus_lifecycle, :rest}}
end
