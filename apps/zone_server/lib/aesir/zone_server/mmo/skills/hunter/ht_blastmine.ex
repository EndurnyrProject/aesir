defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmine do
  @moduledoc """
  Blast Mine (HT_BLASTMINE), a visible single-cell Wind BF_MISC trap.

  Enemy contact or natural armed expiry rolls one placement-stamped damage
  value and splits it across living enemies in the trap-centered 3x3 area. The
  manager owns the visible used phase after either detonation path.

  Renewal: damage stamped at placement as level × DEX × (3 + base level/100) × (1 + INT/35), two traps, a 0.5 s cast plus 0.3 s fixed and a 1 s delay. Pre-renewal: level × (DEX/2 + 50) × (100 + INT)/100, one trap, and an instant cast with no delay.
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
    cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(300, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    sp_cost: List.duplicate(10, 5),
    item_cost: [renewal: [%{id: 1065, amount: 2}], pre_renewal: [%{id: 1065, amount: 1}]]

  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
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
        execute_splash(caster_state, center, definition.splash_radius, group,
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

  defp execute_splash(caster_state, center, radius, %Group{caster_type: :player} = group, opts),
    do: SkillAttack.execute_field_misc_splash(caster_state, center, radius, group, opts)

  defp execute_splash(caster_state, center, radius, %Group{caster_type: :mob}, opts),
    do: SkillAttack.execute_misc_splash(caster_state, center, radius, opts)
end
