defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCallhomun do
  @moduledoc """
  Call Homunculus.

  Both modes cost 10 SP; the lifecycle handler consumes the Embryo. Renewal also
  recalls a resting homunculus with a Seed of Life and stamps a 30-minute timer.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 243,
    name: :am_callhomun,
    display_name: "Call Homunculus",
    max_level: 1,
    target_type: :self,
    sp_cost: [10],
    duration: [renewal: [1_800_000], pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @doc false
  def lifecycle_operation, do: :call

  @impl Active
  def cast(caster, :self, _level, _definition),
    do: {:deferred, caster, {:homunculus_lifecycle, :call}}
end
