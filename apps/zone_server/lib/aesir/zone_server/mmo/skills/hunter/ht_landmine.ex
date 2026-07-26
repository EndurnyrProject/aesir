defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtLandmine do
  @moduledoc """
  Land Mine (HT_LANDMINE), a hidden single-cell Earth BF_MISC trap.

  Enemy contact deals placement-stamped damage, attempts Stun, and lets the
  ground-unit manager transition the mine to its visible used phase.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 116,
    name: :ht_landmine,
    display_name: "Land Mine",
    max_level: 5,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :misc,
    element: :earth,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [200_000, 160_000, 120_000, 80_000, 40_000],
    cast_time: List.duplicate(500, 5),
    fixed_cast_time: List.duplicate(300, 5),
    after_cast_delay: List.duplicate(1_000, 5),
    sp_cost: List.duplicate(10, 5),
    item_cost: [%{id: 1065, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
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
       visible?: false
     }}
  end

  # Traps have no periodic effect; they only react to on_touch and expire on
  # their duration. NOTE: a no-op tick at hit_interval; harmless until the trap
  # triggers or expires.
  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()} | :expire
  def on_touch(%Group{} = group, mover) do
    if Trap.enemy?(group, mover) do
      fire(group, mover)
    else
      {:ok, group}
    end
  end

  defp fire(%Group{state: %{base_damage: base_damage}} = group, {_mover_type, mover_id}) do
    definition = definition()

    case Trap.resolve_caster(group) do
      {:ok, caster_state} ->
        case Combat.execute_misc_attack(caster_state, mover_id,
               skill_id: definition.id,
               skill_level: group.level,
               base_damage: Trap.roll_damage(base_damage),
               element: definition.element
             ) do
          :ok ->
            StatusInterpreter.apply_status(opposing_type(group.caster_type), mover_id, :sc_stun,
              source_id: group.caster_id,
              source_type: group.caster_type,
              success_rate: 10,
              duration: 4_500
            )

            :expire

          {:error, _reason} ->
            {:ok, group}
        end

      :error ->
        {:ok, group}
    end
  end

  defp opposing_type(:player), do: :mob
  defp opposing_type(:mob), do: :player
end
