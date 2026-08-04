defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtFlasher do
  @moduledoc """
  Flasher (HT_FLASHER), a hidden contact trap that attempts to Blind its activator.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 120,
    name: :ht_flasher,
    display_name: "Flasher",
    max_level: 5,
    target_type: :ground,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [150_000, 120_000, 90_000, 60_000, 30_000],
    sp_cost: [12, 12, 12, 12, 12],
    item_cost: [%{id: 1065, amount: 2}]

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level} = group) do
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, %{dex: 0, int: 0, base_level: 0}, group),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       visibility: :party_only
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()} | :expire
  def on_touch(%Group{} = group, {:mob, mob_id} = mover) do
    if Trap.enemy?(group, mover) and not plant_boss?(mob_id) do
      blind(group, :mob, mob_id)
      :expire
    else
      {:ok, group}
    end
  end

  def on_touch(%Group{} = group, {unit_type, unit_id} = mover)
      when unit_type in [:player, :homunculus] do
    if Trap.enemy?(group, mover) do
      blind(group, unit_type, unit_id)
      :expire
    else
      {:ok, group}
    end
  end

  defp blind(group, unit_type, unit_id) do
    StatusInterpreter.apply_status(unit_type, unit_id, :sc_blind,
      duration: 18_000,
      success_rate: 100,
      caster_id: group.caster_id,
      source_type: group.caster_type
    )
  end

  defp plant_boss?(mob_id) do
    case UnitRegistry.get_unit(:mob, mob_id) do
      {:ok, {MobState, mob_state, _pid}} ->
        MobState.is_boss?(mob_state) and MobState.get_race(mob_state) == :plant

      _ ->
        false
    end
  end
end
