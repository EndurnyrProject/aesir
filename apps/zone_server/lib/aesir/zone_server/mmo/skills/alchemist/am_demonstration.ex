defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmDemonstration do
  @moduledoc """
  Demonstration (AM_DEMONSTRATION), a Fire weapon-damage field.

  The field occupies a 3x3 area for 40 + 5 seconds per skill level. Every
  500 ms, each enemy in that area receives a normal physical weapon attack,
  which may miss. A confirmed hit attempts to break a player target's weapon.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 229,
    name: :am_demonstration,
    requires: [],
    display_name: "Demonstration",
    max_level: 5,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :fire,
    range: 9,
    hit_interval: 500,
    unit_duration: [45_000, 50_000, 55_000, 60_000, 65_000],
    sp_cost: List.duplicate(10, 5),
    item_cost: [%{id: 7135, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @radius 1
  @behaviour Ground

  @doc false
  @spec validate(map(), {:ground, integer(), integer()}, pos_integer(), struct()) ::
          :ok | {:error, :skill_unit_overlap}
  def validate(%{map_name: map_name}, {:ground, x, y}, _level, _definition) do
    if demonstration_at?(map_name, x, y), do: {:error, :skill_unit_overlap}, else: :ok
  end

  @doc false
  @spec cast(PlayerState.t(), {:ground, integer(), integer()}, pos_integer(), struct()) ::
          {:ok, PlayerState.t()} | {:error, term()}
  def cast(caster, {:ground, x, y}, level, _definition) do
    if demonstration_at?(caster.map_name, x, y) do
      {:error, :skill_unit_overlap}
    else
      case Unit.place(caster, :am_demonstration, level, {x, y}) do
        {:ok, _group} -> {:ok, caster}
        {:error, _reason} = error -> error
      end
    end
  end

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.square(center, @radius),
       state: %{},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def on_interval(%Group{caster_id: caster_id} = group, _now) do
    case UnitRegistry.get_unit(:player, caster_id) do
      {:ok, {PlayerState, caster, _pid}} ->
        group.map_name
        |> Combat.splash_targets(group.center, @radius, caster_id)
        |> Enum.each(&hit(caster, group, &1))

        {:ok, group}

      {:error, :not_found} ->
        {:expire, group}
    end
  end

  @spec hit(PlayerState.t(), Group.t(), {atom(), integer()}) :: :ok
  defp hit(caster, group, {unit_type, target_id}) do
    case Combat.execute_skill_attack(caster, target_id,
           skill_id: group.skill_id,
           skill_level: group.level,
           skill_ratio: skill_ratio(group.level),
           element: :fire,
           skip_crit: true,
           skip_range: true,
           report_hit: true
         ) do
      {:ok, %{hit?: true}} -> roll_weapon_break(unit_type, target_id, group.level)
      _ -> :ok
    end
  end

  @spec roll_weapon_break(atom(), integer(), pos_integer()) :: :ok
  defp roll_weapon_break(:player, target_id, level) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {PlayerState, target, target_pid}} ->
        (300 * level)
        |> EquipBreak.resolve_slot({:player, target_id, target.stats}, :weapon)
        |> Enum.each(&dispatch_break(&1, target_pid))

      {:error, :not_found} ->
        :ok
    end
  end

  defp roll_weapon_break(_unit_type, _target_id, _level), do: :ok

  @spec dispatch_break({:target, :weapon}, pid()) :: :ok
  defp dispatch_break({:target, :weapon}, target_pid),
    do: PlayerSession.break_equip(target_pid, :right_hand)

  @spec skill_ratio(pos_integer()) :: pos_integer()
  defp skill_ratio(level), do: 100 + 20 * level

  @spec demonstration_at?(String.t(), integer(), integer()) :: boolean()
  defp demonstration_at?(map_name, x, y) do
    Layout.square({x, y}, @radius)
    |> Enum.any?(fn {cell_x, cell_y} ->
      Enum.any?(Storage.get_groups_at_cell(map_name, cell_x, cell_y), &(&1.skill_id == 229))
    end)
  end
end
