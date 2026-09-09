defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgThunderstorm do
  @moduledoc """
  Thunderstorm (MG_THUNDERSTORM). Ground-targeted, short-lived skill-unit.

  As a `target_type: :ground` skill, `use Skill` auto-derives the `cast/4` that
  places this unit at the target cell. The unit covers a 5x5 wind field and is
  a single burst, not a lingering field: it fires once, immediately, delivering
  the cast level's whole hit count to every offensive target standing in the
  footprint at that moment, and then expires. A target inside the area when the
  burst lands takes all `level` hits; one that is not takes none, so there is no
  walking out of it partway through. If the caster is gone the unit expires
  without dealing damage. SP and cooldown are deducted by the interpreter from
  the definition.

  Renewal: each pulse lands at the full magic ratio, and the cast is slow to
  start but scales gently with level, from 2.7 to 4.5 seconds of variable cast
  plus a flat 1.5 second fixed cast that only gear and buffs can shorten.

  Pre-renewal: each pulse lands at 80% of the magic ratio, and there is no fixed
  cast component at all - the whole cast is variable and grows by a full second
  per level, from 1 second at level 1 to 10 seconds at level 10, so DEX alone
  decides how usable the higher levels are.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 21,
    name: :mg_thunderstorm,
    requires: [],
    display_name: "Thunderstorm",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :wind,
    splash_radius: 2,
    hit_interval: 1_000,
    cast_time: [
      renewal: [2700, 2900, 3100, 3300, 3500, 3700, 3900, 4100, 4300, 4500],
      pre_renewal: [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10_000]
    ],
    fixed_cast_time: List.duplicate(1_500, 10),
    after_cast_delay: List.duplicate(2_000, 10),
    sp_cost: [29, 34, 39, 44, 49, 54, 59, 64, 69, 74]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout

  @behaviour Ground

  @doc """
  Percentage of the caster's magic attack each pulse deals in `mode`.

  Renewal pulses at full strength; classic keeps the older 20-point reduction.
  """
  @spec skill_ratio(GameMode.t()) :: pos_integer()
  def skill_ratio(:renewal), do: 100
  def skill_ratio(:pre_renewal), do: 80

  @impl Ground
  def on_place(%Group{center: center}) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.square(center, definition.splash_radius),
       state: %{},
       interval: definition.hit_interval,
       # The burst is the unit's whole life: fire on the first sweep rather than
       # after an interval, and expire immediately afterwards.
       initial_delay: 0,
       duration: definition.hit_interval
     }}
  end

  @impl Ground
  def on_interval(%Group{center: center, map_name: map_name} = group, _now) do
    definition = definition()

    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} ->
        map_name
        |> Combat.splash_targets(center, definition.splash_radius, group.caster_id)
        |> Enum.each(fn {unit_type, target_id} ->
          hit(group, definition, caster, unit_type, target_id)
        end)

        {:expire, group}

      {:error, _reason} ->
        {:expire, group}
    end
  end

  @spec hit(Group.t(), struct(), struct(), atom(), integer()) :: :ok
  defp hit(%Group{level: level} = group, definition, caster, unit_type, target_id) do
    Combat.apply_skill_unit_damage(
      caster,
      unit_type,
      target_id,
      group.skill_id,
      level,
      definition.element,
      skill_ratio(GameMode.mode()),
      hit_count: level
    )

    :ok
  end
end
