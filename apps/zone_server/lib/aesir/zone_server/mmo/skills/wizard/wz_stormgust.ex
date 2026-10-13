defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzStormgust do
  @moduledoc """
  Storm Gust (WZ_STORMGUST). A 9x9 water field whose cells each strike the
  enemies within one cell of them, so it reaches 11x11. A unit is struck at most
  once every 450 ms by all Storm Gusts together, from the first cell that
  reaches it, and is pushed 2 cells away from that cell.

  A freeze is an on-hit effect: it is rolled only for a hit that dealt damage to a
  target that survived it.

  Renewal: a 4.5 s field dealing 70% plus 50% per level MATK per hit, each hit freezing for 27 s with a
  65% minus 5% per level chance, with a 4.5 to 6.3 s cast plus 1.5 s fixed, a 1 s
  delay, and a 6 s cooldown. Pre-renewal: a 4.6 s field dealing 100% plus 40% per
  level, a 6 to 15 s variable cast, a 5 s delay, and no cooldown. Each hit adds to
  the target's own Storm Gust counter, shared by every Storm Gust that strikes it;
  from the third counted hit each damaging hit tries a 150% chance, 12 s freeze,
  and the counter resets when the freeze lands, when it passes 250, or when a hit
  deals no damage. Death, leaving the server and buff-clearing effects reset it too.
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
    unit_duration: [renewal: List.duplicate(4_500, 10), pre_renewal: List.duplicate(4_600, 10)],
    duration: [renewal: List.duplicate(27_000, 10), pre_renewal: List.duplicate(12_000, 10)],
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
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules

  @behaviour Ground

  @impl Ground
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.square(center, 4),
       state: %{},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       unit_range: 1,
       no_overlap: true,
       path_check: true
     }}
  end

  @impl Ground
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  def unit_targets(%Group{} = group, _cell, refs) do
    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} -> SplashTargets.eligible(refs, caster)
      {:error, _reason} -> []
    end
  end

  @impl Ground
  def on_unit_hit(%Group{} = group, cell, target, _now) do
    with {:ok, caster} <- Combat.resolve_combatant(group.caster_id) do
      hit(GameMode.mode(), group, definition(), caster, cell, target)
    end

    {:ok, group}
  end

  defp hit(:renewal, group, definition, caster, cell, target) do
    freeze = freeze(group, definition, 65 - 5 * group.level)
    _ = attack(group, definition, caster, cell, target, freeze)
    :ok
  end

  # The counter rises before the attack, the third counted damaging hit tries to
  # freeze, and a hit that deals nothing (absorbed, blocked or refused) clears it.
  # A skill-unit cell has no status data to count on.
  defp hit(:pre_renewal, group, definition, caster, cell, {:skill_unit, _id} = target) do
    _ = attack(group, definition, caster, cell, target, nil)
    :ok
  end

  # A target the siege rules refuse is not a valid target at all: the field
  # skips it before counting, and the attack would be refused the same way.
  defp hit(:pre_renewal, group, definition, caster, cell, {unit_type, unit_id} = target) do
    with {:ok, combatant} <- Combat.resolve_combatant(unit_type, unit_id),
         :ok <- Rules.validate_target(caster, combatant, %{skill_id: group.skill_id}) do
      StatusStorage.increment_storm_gust_counter(unit_type, unit_id)

      case attack(group, definition, caster, cell, target, counted_freeze(group, definition),
             report_hit: true
           ) do
        {:ok, %{hit?: true}} -> :ok
        _no_damage -> StatusStorage.reset_storm_gust_counter(unit_type, unit_id)
      end
    end

    :ok
  end

  @spec attack(
          Group.t(),
          struct(),
          struct(),
          Ground.cell(),
          {atom(), integer()},
          function() | nil,
          keyword()
        ) :: :ok | {:ok, map()} | {:error, atom()}
  defp attack(group, definition, caster, cell, {unit_type, target_id}, effect, opts \\ []) do
    Combat.apply_skill_unit_damage(
      caster,
      unit_type,
      target_id,
      group.skill_id,
      group.level,
      definition.element,
      skill_ratio(group.level),
      [
        base_distance: definition.knockback,
        origin: cell,
        additional_effect: effect
      ] ++ opts
    )
  end

  defp counted_freeze(group, definition) do
    try_freeze = freeze(group, definition, 150)

    fn source, {unit_type, unit_id} = target ->
      count = StatusStorage.storm_gust_counter(unit_type, unit_id)

      cond do
        count >= 3 and try_freeze.(source, target) == :ok ->
          StatusStorage.reset_storm_gust_counter(unit_type, unit_id)

        count > 250 ->
          StatusStorage.reset_storm_gust_counter(unit_type, unit_id)

        true ->
          :ok
      end
    end
  end

  defp freeze(group, definition, chance) do
    fn _source, {unit_type, unit_id} ->
      StatusInterpreter.apply_status(unit_type, unit_id, :sc_freeze,
        val1: group.level,
        duration: Enum.at(definition.duration, group.level - 1),
        success_rate: chance,
        caster_id: group.caster_id,
        source_type: group.caster_type
      )
    end
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
end
