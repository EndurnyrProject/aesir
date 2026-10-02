defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Tick do
  @moduledoc """
  One Battle Chant interval: every living unit on the field other than the
  caster rolls `50 + 5 * level` percent; on success a party member receives a
  random blessing and an enemy a random affliction. Guild mates outside the
  party, neutral players, and other unit types are left alone. A vanished
  caster expires the field.

  Runs inside `Skill.Unit.Manager`, where resolving the caster is safe. The
  group's `state.rng` may carry an injected zero-based roll for tests.
  """

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Effects
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Applies this interval's effects to the units standing in the field."
  @spec run(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def run(%Group{caster_type: caster_type, caster_id: caster_id} = group, _now) do
    with {:ok, caster} <- Combat.resolve_combatant(caster_type, caster_id),
         {:ok, {_module, caster_state, _pid}} <- UnitRegistry.get_unit(caster_type, caster_id) do
      group
      |> occupants()
      |> Enum.each(&maybe_affect(group, caster, caster_state, &1))

      {:ok, group}
    else
      _gone -> {:expire, group}
    end
  end

  defp occupants(%Group{map_name: map_name, cells: cells} = group) do
    cells
    |> Enum.flat_map(fn {x, y} -> SpatialIndex.get_all_units_in_range(map_name, x, y, 0) end)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == {group.caster_type, group.caster_id}))
  end

  defp maybe_affect(%Group{level: level} = group, caster, caster_state, {type, id} = target) do
    with true <- roll(group) <= 50 + 5 * level,
         {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(type, id),
         true <- Unit.living?(state) do
      affect(group, caster, caster_state, target, state)
    else
      _skip -> :ok
    end
  end

  defp affect(
         %Group{party_id: party} = group,
         _caster,
         _caster_state,
         {:player, _} = target,
         state
       )
       when is_integer(party) and party > 0 and state.party_id == party,
       do: Effects.bless(group, target)

  defp affect(group, caster, caster_state, {type, _id} = target, state)
       when type in [:player, :mob] do
    if Targeting.validate_enemy(caster, state) == :ok,
      do: Effects.afflict(group, caster_state, target),
      else: :ok
  end

  defp affect(_group, _caster, _caster_state, _target, _state), do: :ok

  defp roll(%Group{state: %{rng: rng}}) when is_function(rng, 1), do: rng.(100)
  defp roll(_group), do: :rand.uniform(100)
end
