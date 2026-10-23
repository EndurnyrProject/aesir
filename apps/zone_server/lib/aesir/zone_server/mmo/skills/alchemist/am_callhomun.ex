defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCallhomun do
  @moduledoc """
  Call Homunculus.

  Both modes cost 10 SP. With a homunculus already out (alive or dead) the use
  fails when it starts. Without a homunculus the cast end needs an Embryo, which
  the lifecycle handler consumes. Renewal recalls a resting homunculus with a
  Seed of Life and stamps a 30-minute timer; pre-renewal recalls it for no
  item.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 243,
    name: :am_callhomun,
    display_name: "Call Homunculus",
    max_level: 1,
    target_type: :self,
    sp_cost: [10],
    duration: [renewal: [1_800_000], pre_renewal: []],
    damage_kind: :none

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @embryo_id 7142
  @seed_of_life_id 7140

  @doc false
  def lifecycle_operation, do: :call

  @impl Active
  def begin_attempt(%PlayerState{} = caster, _target, _level, _definition) do
    case caster.homunculus_summary do
      %{lifecycle: :dead} -> {:error, :dead}
      %{lifecycle: :active} -> {:error, :invalid_lifecycle}
      _absent_or_resting -> {:ok, caster}
    end
  end

  def begin_attempt(caster, _target, _level, _definition), do: {:ok, caster}

  @impl Active
  def castend_requirement(caster, _target, _level, _definition) do
    if Enum.all?(required_items(caster.homunculus_summary, GameMode.mode()), fn id ->
         Inventory.held_amount(caster.inventory, id) > 0
       end),
       do: :ok,
       else: {:error, :missing_catalyst}
  end

  defp required_items(nil, _mode), do: [@embryo_id]
  defp required_items(%{lifecycle: :rested}, :renewal), do: [@seed_of_life_id]
  defp required_items(_homunculus, :renewal), do: [@embryo_id, @seed_of_life_id]
  defp required_items(_homunculus, :pre_renewal), do: []

  @impl Active
  def cast(caster, :self, _level, _definition),
    do: {:deferred, caster, {:homunculus_lifecycle, :call}}
end
