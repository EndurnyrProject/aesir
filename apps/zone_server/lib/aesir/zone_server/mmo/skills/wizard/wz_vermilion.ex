defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzVermilion do
  @moduledoc """
  Lord of Vermilion (WZ_VERMILION). A wide wind field whose ticks split their damage
  over many displayed hits and can blind.

  Renewal: 400% plus 100% per level MATK (80% plus 20% per level for a monster caster)
  over 20 displayed hits, a 1 s field, blind 10% plus 5% per level for 18 s, a 4.5 to
  6.3 s cast plus 1.5 s fixed, a 1 s delay, and a 5 s cooldown. Pre-renewal: 80% plus 20%
  per level over 10 hits, a 4 s field, blind 4% per level up to 40% for 30 s, a 10.5 to
  15 s variable cast, a 5 s delay, and no cooldown.
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
    hit_count: [renewal: 20, pre_renewal: 10],
    unit_duration: [renewal: List.duplicate(1_000, 10), pre_renewal: List.duplicate(4_000, 10)],
    duration: [renewal: List.duplicate(18_000, 10), pre_renewal: List.duplicate(30_000, 10)],
    sp_cost: [60, 64, 68, 72, 76, 80, 84, 88, 92, 96],
    cast_time: [
      renewal: [6300, 6100, 5900, 5700, 5500, 5300, 5100, 4900, 4700, 4500],
      pre_renewal: [
        15_000,
        14_500,
        14_000,
        13_500,
        13_000,
        12_500,
        12_000,
        11_500,
        11_000,
        10_500
      ]
    ],
    fixed_cast_time: [renewal: List.duplicate(1_500, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 10), pre_renewal: List.duplicate(5000, 10)],
    cooldown: [renewal: List.duplicate(5_000, 10), pre_renewal: []],
    status: :sc_blind

  alias Aesir.Commons.GameMode
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
           skill_ratio(group.level, group.caster_type == :player),
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
  @doc """
  Renewal deals 400% plus 100% per level for a player caster; a monster caster,
  and every classic caster, deals 80% plus 20% per level.
  """
  @spec skill_ratio(pos_integer(), boolean()) :: pos_integer()
  def skill_ratio(level, player? \\ true) do
    if GameMode.mode() == :renewal and player?, do: 400 + 100 * level, else: 80 + 20 * level
  end

  @doc "Renewal blinds 10 plus 5 per level percent; classic 4 per level, at most 40."
  @spec blind_chance(pos_integer()) :: pos_integer()
  def blind_chance(level) do
    case GameMode.mode() do
      :renewal -> 10 + 5 * level
      :pre_renewal -> min(4 * level, 40)
    end
  end
end
