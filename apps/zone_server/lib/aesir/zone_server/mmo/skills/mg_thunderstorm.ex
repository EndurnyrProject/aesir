defmodule Aesir.ZoneServer.Mmo.Skills.MgThunderstorm do
  @moduledoc """
  Thunderstorm (MG_THUNDERSTORM). Ground-targeted, short-lived skill-unit.

  As a `target_type: :ground` skill, `use Skill` auto-derives the `cast/4` that
  places this unit at the target cell. The unit covers a 5x5 wind field that
  pulses every `hit_interval` ms, hitting every offensive target in the footprint
  with renewal wind magic damage (`Combat.MagicDamageCalculator`, MATK/MDEF/wind)
  at 80% per pulse. The group tracks how many pulses it has fired and expires once
  it has delivered `level` pulses, so each enemy standing in the field for its
  whole life takes `level` hits. If the caster is gone the field still ticks and
  counts the pulse but deals no damage that tick. SP and cooldown are deducted by
  the interpreter from the definition.

  rAthena (`skill_db` id 21): `Hits: -1` filled 5x5, `Element: Wind`,
  ratio `base_skillratio (100) - 20`; client pulses `level` times.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 21,
    name: :mg_thunderstorm,
    display_name: "Thunderstorm",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :wind,
    splash_radius: 2,
    hit_interval: 1_000,
    cast_time: [2700, 2900, 3100, 3300, 3500, 3700, 3900, 4100, 4300, 4500],
    fixed_cast_time: List.duplicate(1_500, 10),
    after_cast_delay: List.duplicate(2_000, 10),
    sp_cost: [29, 34, 39, 44, 49, 54, 59, 64, 69, 74]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout

  # Renewal MG_THUNDERSTORM ratio: base_skillratio (100) - 20.
  @skill_ratio 80

  @behaviour Ground

  @impl Ground
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.square(center, definition.splash_radius),
       state: %{pulses: 0},
       interval: definition.hit_interval,
       duration: (level + 1) * definition.hit_interval
     }}
  end

  @impl Ground
  def on_interval(%Group{center: center, map_name: map_name, level: level} = group, _now) do
    definition = definition()

    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} ->
        map_name
        |> Combat.splash_targets(center, definition.splash_radius, group.caster_id)
        |> Enum.each(fn {unit_type, target_id} ->
          hit(group, definition, caster, unit_type, target_id)
        end)

        advance(group, level)

      {:error, _reason} ->
        {:ok, group}
    end
  end

  @spec hit(Group.t(), struct(), struct(), atom(), integer()) :: :ok
  defp hit(%Group{} = group, definition, caster, unit_type, target_id) do
    Combat.apply_skill_unit_damage(
      caster,
      unit_type,
      target_id,
      group.skill_id,
      group.level,
      definition.element,
      @skill_ratio
    )

    :ok
  end

  @spec advance(Group.t(), non_neg_integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  defp advance(%Group{state: state} = group, level) do
    pulses = state.pulses + 1
    updated = %{group | state: %{state | pulses: pulses}}

    if pulses >= level do
      {:expire, updated}
    else
      {:ok, updated}
    end
  end
end
