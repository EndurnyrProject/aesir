defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtClaymoretrap do
  @moduledoc """
  Claymore Trap (HT_CLAYMORETRAP), a visible trap-centered Fire BF_MISC mine.

  Enemy contact rolls one placement-stamped damage value and splits it across
  living enemies in the trap-centered 5x5 area, then asks the manager to mark
  every other armed eligible trap in that same area used (visible, inert, for
  1.5 seconds) without invoking any of their own detonation callbacks. Natural
  armed expiry only transitions this trap itself to its used phase.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 123,
    name: :ht_claymoretrap,
    requires: [],
    display_name: "Claymore Trap",
    max_level: 5,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :misc,
    element: :fire,
    range: 3,
    splash_radius: 2,
    hit_interval: 1_000,
    unit_duration: [20_000, 40_000, 60_000, 80_000, 100_000],
    cast_time: List.duplicate(500, 5),
    fixed_cast_time: List.duplicate(300, 5),
    after_cast_delay: List.duplicate(1_000, 5),
    sp_cost: List.duplicate(15, 5),
    item_cost: [%{id: 1065, amount: 2}]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level, caster_type: ct, caster_id: cid} = group) do
    definition = definition()
    {:ok, %{stats: stats}} = UnitRegistry.get_unit_info(ct, cid)

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, stats, group),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       visibility: :public
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_natural_expiry(Group.t()) :: :ok
  def on_natural_expiry(%Group{}), do: :ok

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: Ground.trigger_result()
  def on_touch(%Group{} = group, mover) do
    if Trap.enemy?(group, mover) do
      detonate(group)
    else
      {:ok, group}
    end
  end

  defp detonate(
         %Group{map_name: map_name, center: center, state: %{base_damage: base_damage}} = group
       ) do
    definition = definition()

    case Trap.resolve_caster(group) do
      {:ok, caster_state} ->
        Combat.execute_misc_splash(caster_state, center, definition.splash_radius,
          skill_id: definition.id,
          skill_level: group.level,
          base_damage: Trap.roll_damage(base_damage),
          element: definition.element,
          split: true
        )

        {:expire, [{:spend_traps, map_name, center, definition.splash_radius}]}

      :error ->
        {:ok, group}
    end
  end
end
