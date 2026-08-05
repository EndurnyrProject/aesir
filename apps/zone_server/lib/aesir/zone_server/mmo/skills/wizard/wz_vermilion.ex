defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzVermilion do
  @moduledoc """
  Lord of Vermilion (WZ_VERMILION), a persistent Wind ground field.

  Renewal data is from rAthena `db/re/skill_db.yml:3303-3400`: a 13x13 field,
  1,250 ms interval, 18,000 ms lifetime, `HitCount: -20`, Wind element, and
  the level tables below. The negative hit count preserves total damage while
  showing twenty equal divisions; `Combat.apply_skill_unit_damage/8` represents
  that with a positive packet division count. `src/map/skill.cpp:12488-12494,
  16332` schedules the first unit check on the next 100 ms manager cadence, so
  placement makes the first tick immediately due. `skills/mage/lordofvermilion.cpp:21-39`
  supplies the Renewal MATK ratio and Blind chance/duration; if its caster is
  lost, `skill_unit_onplace_timer`'s source lookup (`skill.cpp:6716-6738`)
  prevents further hits while the field remains until expiry.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 85,
    name: :wz_vermilion,
    requires: [],
    display_name: "Lord of Vermilion",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :wind,
    splash_radius: 6,
    hit_interval: 1_250,
    hit_count: 20,
    unit_duration: List.duplicate(18_000, 10),
    duration: List.duplicate(18_000, 10),
    sp_cost: [60, 64, 68, 72, 76, 80, 84, 88, 92, 96],
    cast_time: [6300, 6100, 5900, 5700, 5500, 5300, 5100, 4900, 4700, 4500],
    fixed_cast_time: List.duplicate(1_500, 10),
    after_cast_delay: List.duplicate(1_000, 10),
    cooldown: List.duplicate(5_000, 10),
    status: :sc_blind

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    definition = definition()
    idx = min(level, definition.max_level) - 1

    {:ok,
     %{
       cells: Layout.square(center, definition.splash_radius),
       state: %{},
       interval: definition.hit_interval,
       initial_delay: 0,
       duration: Enum.at(definition.unit_duration, idx),
       lifecycle_policy: %LifecyclePolicy{on_caster_loss: :skip_action}
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{center: center, map_name: map_name} = group, _now) do
    definition = definition()

    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} ->
        map_name
        |> Combat.splash_targets(center, definition.splash_radius, group.caster_id)
        |> Enum.each(&hit(group, definition, caster, &1))

        {:ok, group}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  @spec hit(Group.t(), struct(), struct(), {atom(), integer()}) :: :ok
  defp hit(group, definition, caster, {unit_type, target_id}) do
    idx = min(group.level, definition.max_level) - 1

    case Combat.apply_skill_unit_damage(
           caster,
           unit_type,
           target_id,
           group.skill_id,
           group.level,
           definition.element,
           skill_ratio(group.level),
           -definition.hit_count
         ) do
      :ok ->
        StatusInterpreter.apply_status(unit_type, target_id, definition.status,
          val1: group.level,
          duration: Enum.at(definition.duration, idx),
          success_rate: blind_chance(group.level)
        )

      _ ->
        :ok
    end

    :ok
  end

  # Renewal `WZ_VERMILION`: base_skillratio (100) + 300 + 100 * skill_lv.
  @spec skill_ratio(pos_integer()) :: pos_integer()
  defp skill_ratio(level), do: 400 + 100 * level

  @spec blind_chance(pos_integer()) :: pos_integer()
  defp blind_chance(level), do: 10 + 5 * level
end
