defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomdust do
  @moduledoc """
  Venom Dust (AS_VENOMDUST). A five-cell cross of poison whose cells each poison
  the unpoisoned enemies within one cell of them, each enemy at most once a second
  per field, for 5 s per level, 20 SP, and a Red Gemstone.

  Renewal poisons for 18 s; pre-renewal for 60 s.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 140,
    name: :as_venomdust,
    requires: [],
    display_name: "Venom Dust",
    max_level: 10,
    target_type: :ground,
    damage_type: :no_damage,
    element: :poison,
    range: 2,
    hit_interval: 1_000,
    unit_duration: Enum.to_list(5_000..50_000//5_000),
    sp_cost: List.duplicate(20, 10),
    duration: [renewal: List.duplicate(18_000, 10), pre_renewal: List.duplicate(60_000, 10)],
    item_cost: [%{id: 716, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
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
       duration: Enum.at(definition.unit_duration, level - 1),
       unit_range: 1
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def on_interval(%Group{} = group, _now) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, _caster} -> {:ok, group}
      {:error, _reason} -> {:expire, group}
    end
  end

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{} = group, _cell, refs) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} -> SplashTargets.eligible(refs, caster)
      {:error, _reason} -> []
    end
  end

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, _cell, {unit_type, unit_id}, _now) do
    unless StatusStorage.has_status?(unit_type, unit_id, :sc_poison) do
      StatusInterpreter.apply_status(unit_type, unit_id, :sc_poison,
        duration: Enum.at(definition().duration, group.level - 1),
        caster_id: group.caster_id,
        source_type: group.caster_type
      )
    end

    {:ok, group}
  end
end
