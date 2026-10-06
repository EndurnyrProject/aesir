defmodule Aesir.ZoneServer.Mmo.Skill.Caster.Mob do
  @moduledoc false

  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster

  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @impl true
  def kind, do: :mob

  @impl true
  def provides, do: []

  @impl true
  def id(%MobState{instance_id: instance_id}), do: instance_id

  @impl true
  def unit_type(%MobState{}), do: :mob

  @impl true
  def position(%MobState{map_name: map_name, x: x, y: y}), do: {map_name, x, y}

  @impl true
  def attack_range(%MobState{mob_data: %{skill_range: skill_range}}), do: skill_range

  @impl true
  def broadcast_source(%MobState{instance_id: instance_id}), do: {:mob, instance_id}

  @impl true
  def sp(%MobState{sp: sp}), do: sp

  @impl true
  def deduct_sp(%MobState{} = caster, amount), do: %{caster | sp: caster.sp - amount}

  @doc "Returns effective battle stats and held cast statuses for a monster cast."
  @spec cast_stats(MobState.t(), integer()) :: CastTime.inputs()
  def cast_stats(%MobState{} = caster, _skill_id) do
    combatant = MobState.to_combatant(caster)

    statuses =
      :mob
      |> StatusStorage.get_unit_statuses(caster.instance_id)
      |> Enum.reduce(%{}, fn entry, acc ->
        value = Map.get(entry.state || %{}, :cast_time_reduction, 0)

        case entry.type do
          :sc_memorize -> Map.put(acc, :memorize, true)
          :sc_poembragi -> Map.put(acc, :bragi, value)
          :sc_suffragium -> Map.put(acc, :suffragium, value)
          _ -> acc
        end
      end)

    %{
      caster_kind: :mob,
      dex: combatant.base_stats.dex,
      int: combatant.base_stats.int,
      base_level: caster.mob_data.level,
      effective_skill?: true,
      statuses: statuses
    }
  end
end
