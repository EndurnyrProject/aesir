defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmRest do
  @moduledoc """
  Rest.

  Renewal adds a 20 s cooldown; pre-renewal has none. Both cost 50 SP. The use
  fails when it starts unless the homunculus is out, alive and holds at least
  80 percent of its HP.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 244,
    name: :am_rest,
    display_name: "Vaporize",
    max_level: 1,
    target_type: :self,
    sp_cost: [50],
    cooldown: [renewal: [20_000], pre_renewal: []],
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @doc false
  def lifecycle_operation, do: :rest

  @impl Active
  def begin_attempt(%PlayerState{} = caster, _target, _level, _definition) do
    case caster.homunculus_summary do
      nil -> {:error, :no_companion}
      %{lifecycle: :dead} -> {:error, :dead}
      %{lifecycle: :active, hp: hp, max_hp: max_hp} when hp > 0 -> check_hp(caster, hp, max_hp)
      _resting -> {:error, :invalid_lifecycle}
    end
  end

  def begin_attempt(caster, _target, _level, _definition), do: {:ok, caster}

  defp check_hp(caster, hp, max_hp) do
    if hp < div(max_hp * 80, 100), do: {:error, :hp_gate}, else: {:ok, caster}
  end

  @impl Active
  def cast(caster, :self, _level, _definition),
    do: {:deferred, caster, {:homunculus_lifecycle, :rest}}
end
