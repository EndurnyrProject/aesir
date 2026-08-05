defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomdust do
  @moduledoc """
  Venom Dust (AS_VENOMDUST), a five-cell Poison field.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 140,
    name: :as_venomdust,
    requires: [],
    display_name: "Venom Dust",
    max_level: 10,
    target_type: :ground,
    damage_type: :no_damage,
    range: 2,
    hit_interval: 1_000,
    unit_duration: Enum.to_list(5_000..50_000//5_000),
    sp_cost: List.duplicate(20, 10),
    item_cost: [%{id: 716, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @behaviour Ground

  @offsets [{0, 0}, {-1, 0}, {1, 0}, {0, -1}, {0, 1}]

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: {x, y}, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Enum.map(@offsets, fn {dx, dy} -> {x + dx, y + dy} end),
       state: %{},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def on_interval(%Group{} = group, _now) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} ->
        group
        |> targets(caster)
        |> Enum.reject(fn {unit_type, unit_id} ->
          StatusStorage.has_status?(unit_type, unit_id, :sc_poison)
        end)
        |> Enum.each(&apply_poison(&1, group))

        {:ok, group}

      {:error, _reason} ->
        {:expire, group}
    end
  end

  defp targets(group, caster) do
    group.cells
    |> Enum.flat_map(fn cell -> Combat.splash_targets(group.map_name, cell, 1, caster) end)
    |> Enum.uniq()
  end

  defp apply_poison({unit_type, unit_id}, group) do
    StatusInterpreter.apply_status(unit_type, unit_id, :sc_poison,
      duration: 18_000,
      caster_id: group.caster_id,
      source_type: group.caster_type
    )

    :ok
  end
end
