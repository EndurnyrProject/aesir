defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlPneuma do
  @moduledoc """
  Pneuma (AL_PNEUMA). Ground-targeted protective field.

  Places a 3x3 skill-unit footprint at the target location. Every occupant on
  those cells receives `sc_pneuma`, which blocks all long-ranged physical hits;
  melee and magic pass through unchanged. There is no hit or shield budget — the
  status lasts for the field's `Duration1` (10s).

  Mirrors Safety Wall structurally; the differences are the blocked damage
  direction (ranged vs. melee), the 3x3 footprint (Safety Wall is single-cell),
  and the absence of a shared hit/shield budget.

  ## rAthena (`db/re/skill_db.yml` id 25)

    - `Unit.Layout: 1` -> a filled `(2*1+1)x(2*1+1)` square = 3x3, so
      `splash_radius: 1` drives `Layout.square/2` exactly like Storm Gust.
    - `Duration1: 10000` -> the field (and the granted status) lasts 10s.
    - `Unit.Interval: -1` -> rAthena applies the status on cell-entry and removes
      it on cell-exit (`skill_unit_onout`), with no periodic tick. Aesir mirrors
      this: `on_interval` re-grants the status on a 1s framework tick to any new
      occupant lacking it, and `on_out` removes it the moment a unit steps off the
      footprint (via the movement-pipeline hook). The status still carries the
      field's 10s duration as a backstop, so it also expires if the unit is still
      standing on the field when the field is torn down.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 25,
    name: :al_pneuma,
    display_name: "Pneuma",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    range: 9,
    splash_radius: 1,
    hit_interval: 1_000,
    unit_duration: [10_000],
    sp_cost: [10]

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.TargetState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.square(center, definition.splash_radius),
       state: %{},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{center: {cx, cy}, map_name: map_name, level: level} = group, _now) do
    definition = definition()
    duration = Enum.at(definition.unit_duration, level - 1)

    map_name
    |> SpatialIndex.get_all_units_in_range(cx, cy, definition.splash_radius)
    |> Enum.filter(fn target -> CombatTarget.combat_unit?(target) and living?(target) end)
    |> Enum.reject(fn {unit_type, unit_id} ->
      StatusStorage.has_status?(unit_type, unit_id, :sc_pneuma)
    end)
    |> Enum.each(fn {unit_type, unit_id} ->
      StatusInterpreter.apply_status(unit_type, unit_id, :sc_pneuma,
        val1: 1,
        caster_id: group.caster_id,
        source_type: group.caster_type,
        duration: duration
      )
    end)

    {:ok, group}
  end

  defp living?({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> TargetState.living?(state)
      {:error, :not_found} -> false
    end
  end

  @impl Ground
  @spec on_out(Group.t(), {atom(), integer()}) :: {:ok, Group.t()}
  def on_out(%Group{} = group, {unit_type, unit_id}) do
    StatusInterpreter.remove_status(unit_type, unit_id, :sc_pneuma)
    {:ok, group}
  end
end
