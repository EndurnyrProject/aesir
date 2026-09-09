defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzStormgust do
  @moduledoc """
  Storm Gust (WZ_STORMGUST). A 5x5 water field ticking every 450 ms for 4.5 s that
  pushes 2 cells on every hit.

  Renewal: 70% plus 50% per level MATK per hit, each hit freezing with a 65% minus 5%
  per level chance, with a 4.5 to 6.3 s cast plus 1.5 s fixed, a 1 s delay, and a 6 s
  cooldown. Pre-renewal: 100% plus 40% per level, a freeze on the third accumulated hit
  (the count resets once the freeze lands), a 6 to 15 s variable cast, a 5 s delay,
  and no cooldown. The classic counter is kept per field, not per target across fields.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 89,
    name: :wz_stormgust,
    requires: [],
    display_name: "Storm Gust",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :water,
    knockback: 2,
    splash_radius: 2,
    hit_interval: 450,
    unit_duration: List.duplicate(4_500, 10),
    sp_cost: List.duplicate(78, 10),
    cast_time: [
      renewal: [4500, 4700, 4900, 5100, 5300, 5500, 5700, 5900, 6100, 6300],
      pre_renewal: [6000, 7000, 8000, 9000, 10_000, 11_000, 12_000, 13_000, 14_000, 15_000]
    ],
    fixed_cast_time: [renewal: List.duplicate(1500, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1000, 10), pre_renewal: List.duplicate(5000, 10)],
    cooldown: [renewal: List.duplicate(6000, 10), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  # the source freezes a target on its 3rd accumulated hit; the counter never resets.
  @freeze_threshold 3

  @behaviour Ground

  @impl Ground
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.square(center, definition.splash_radius),
       state: %{hit_counts: %{}},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  def on_interval(%Group{center: {cx, cy} = center, map_name: map_name} = group, _now) do
    definition = definition()

    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} ->
        updated_counts =
          map_name
          |> Combat.splash_targets(center, definition.splash_radius, group.caster_id)
          |> Enum.reduce(group.state.hit_counts, fn {unit_type, target_id}, counts ->
            hit(group, definition, caster, unit_type, target_id, cx, cy)
            bump_and_maybe_freeze(counts, unit_type, target_id, freeze_chance(group.level))
          end)

        {:ok, %{group | state: %{group.state | hit_counts: updated_counts}}}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  @spec hit(Group.t(), struct(), struct(), atom(), integer(), integer(), integer()) :: :ok
  defp hit(%Group{} = group, definition, caster, unit_type, target_id, cx, cy) do
    Combat.apply_skill_unit_damage(
      caster,
      unit_type,
      target_id,
      group.skill_id,
      group.level,
      definition.element,
      skill_ratio(group.level),
      base_distance: definition.knockback,
      origin: {cx, cy}
    )

    :ok
  end

  # base_skillratio (100) - 30 + 50 * skill_lv.
  @doc "Renewal deals 70% plus 50% per level; classic 100% plus 40% per level."
  @spec skill_ratio(non_neg_integer()) :: non_neg_integer()
  def skill_ratio(level) do
    case GameMode.mode() do
      :renewal -> 70 + 50 * level
      :pre_renewal -> 100 + 40 * level
    end
  end

  @doc """
  Renewal freezes each hit with a 65 minus 5 per level percent chance and keeps
  no counter (`nil` in classic, where the third accumulated hit freezes).
  """
  @spec freeze_chance(pos_integer()) :: pos_integer() | nil
  def freeze_chance(level) do
    case GameMode.mode() do
      :renewal -> 65 - 5 * level
      :pre_renewal -> nil
    end
  end

  @spec bump_and_maybe_freeze(map(), atom(), integer(), pos_integer() | nil) :: map()
  # Classic counts hits and freezes on the third; renewal rolls a chance per hit.
  defp bump_and_maybe_freeze(counts, unit_type, target_id, nil) do
    count = Map.get(counts, target_id, 0) + 1

    frozen? =
      count >= @freeze_threshold and
        StatusInterpreter.apply_status(unit_type, target_id, :sc_freeze, []) == :ok

    Map.put(counts, target_id, if(frozen?, do: 0, else: count))
  end

  defp bump_and_maybe_freeze(counts, unit_type, target_id, chance) do
    if :rand.uniform(100) <= chance do
      StatusInterpreter.apply_status(unit_type, target_id, :sc_freeze, [])
    end

    counts
  end
end
