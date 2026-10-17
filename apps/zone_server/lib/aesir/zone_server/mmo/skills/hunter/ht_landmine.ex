defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtLandmine do
  @moduledoc """
  Land Mine (HT_LANDMINE), a hidden single-cell Earth BF_MISC trap.

  An enemy within one cell sets it off: the blast deals the damage stamped at
  placement to that enemy alone, and a blast that hits stuns it at 10%. The
  mine is spent whatever the blast does.

  Renewal: damage stamped at placement as level × DEX × (3 + base level/100) × (1 + INT/35), a 4.5 s stun, one trap, a 0.5 s cast plus 0.3 s fixed and a 1 s delay. Pre-renewal: level × (DEX + 75) × (100 + INT)/100, a 5 s stun and an instant cast.

  The stun starts 1 s after the blast.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 116,
    name: :ht_landmine,
    no_reiteration: true,
    no_footset: true,
    unit_range: 1,
    is_trap: true,
    requires: [],
    display_name: "Land Mine",
    max_level: 5,
    ignore_noncrit_atk_bonus: [renewal: true, pre_renewal: false],
    target_type: :ground,
    damage_type: :damage,
    ignore_def_card: true,
    ignore_flee: true,
    damage_kind: :misc,
    element: :earth,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [200_000, 160_000, 120_000, 80_000, 40_000],
    cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(300, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    sp_cost: List.duplicate(10, 5),
    item_cost: [%{id: 1065, amount: 1}]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
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
       unit_range: 1,
       visibility: Trap.visibility(:ht_landmine)
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{} = group, _cell, refs), do: Trap.unit_targets(group, refs)

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, _cell, target, now) do
    with true <- Trap.armed?(group),
         {:ok, caster_state} <- Trap.resolve_caster(group) do
      fire(group, caster_state, target)
      {:ok, Trap.spring(group, now)}
    else
      _inert -> {:ok, group}
    end
  end

  # The mine is spent whatever its blast does.
  defp fire(%Group{state: %{base_damage: base_damage}} = group, caster_state, {type, id} = target) do
    definition = definition()

    result =
      execute_attack(caster_state, target, group,
        skill_id: definition.id,
        skill_level: group.level,
        base_damage: Trap.roll_damage(base_damage),
        element: definition.element,
        report_hit: true
      )

    with {:ok, %{hit?: true}} <- result, do: stun(group, type, id)
    :ok
  end

  # The Stun roll is the blast's additional effect.
  defp stun(group, type, id) do
    StatusInterpreter.apply_status(type, id, :sc_stun,
      source_id: group.caster_id,
      source_type: group.caster_type,
      success_rate: 10,
      duration: stun_duration(),
      start_delay: 1_000
    )
  end

  defp stun_duration do
    case GameMode.mode() do
      :renewal -> 4_500
      :pre_renewal -> 5_000
    end
  end

  defp execute_attack(caster_state, target, %Group{caster_type: :player} = group, opts),
    do: SkillAttack.execute_field_misc_attack(caster_state, target, group, opts)

  defp execute_attack(caster_state, target, %Group{caster_type: :mob}, opts),
    do: SkillAttack.execute_misc_attack(caster_state, target, Keyword.put(opts, :delivery, :unit))
end
