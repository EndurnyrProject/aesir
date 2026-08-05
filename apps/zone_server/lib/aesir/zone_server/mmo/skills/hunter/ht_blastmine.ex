defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmine do
  @moduledoc """
  Blast Mine (HT_BLASTMINE), a visible single-cell Wind BF_MISC trap.

  Enemy contact or natural armed expiry rolls one placement-stamped damage
  value and splits it across living enemies in the trap-centered 3x3 area. The
  manager owns the visible used phase after either detonation path.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 122,
    name: :ht_blastmine,
    requires: [],
    display_name: "Blast Mine",
    max_level: 5,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :misc,
    element: :wind,
    range: 3,
    splash_radius: 1,
    hit_interval: 1_000,
    unit_duration: [25_000, 20_000, 15_000, 10_000, 5_000],
    cast_time: List.duplicate(500, 5),
    fixed_cast_time: List.duplicate(300, 5),
    after_cast_delay: List.duplicate(1_000, 5),
    sp_cost: List.duplicate(10, 5),
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
  @spec on_natural_expiry(Group.t()) :: :ok | {:error, :caster_unavailable}
  def on_natural_expiry(%Group{} = group), do: detonate(group)

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()} | :expire
  def on_touch(%Group{} = group, mover) do
    if Trap.enemy?(group, mover) do
      case detonate(group) do
        :ok -> :expire
        {:error, :caster_unavailable} -> {:ok, group}
      end
    else
      {:ok, group}
    end
  end

  defp detonate(%Group{center: center, state: %{base_damage: base_damage}} = group) do
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

        :ok

      :error ->
        {:error, :caster_unavailable}
    end
  end
end
