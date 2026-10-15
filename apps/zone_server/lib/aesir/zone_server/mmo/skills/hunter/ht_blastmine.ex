defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmine do
  @moduledoc """
  Blast Mine (HT_BLASTMINE), a visible single-cell Wind BF_MISC trap.

  The first enemy within one cell sets it off: one roll of the damage stamped
  at placement hits every enemy within one cell of the mine. When its time runs
  out it turns into a used trap without going off.

  Renewal: damage stamped at placement as level × DEX × (3 + base level/100) × (1 + INT/35), split across the enemies hit, two traps, a 0.5 s cast plus 0.3 s fixed and a 1 s delay. Pre-renewal: level × (DEX/2 + 50) × (100 + INT)/100, dealt in full to each, one trap, and an instant cast with no delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 122,
    name: :ht_blastmine,
    no_reiteration: true,
    no_footset: true,
    unit_range: 1,
    is_trap: true,
    requires: [],
    display_name: "Blast Mine",
    max_level: 5,
    ignore_noncrit_atk_bonus: [renewal: true, pre_renewal: false],
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
    item_cost: [renewal: [%{id: 1065, amount: 2}], pre_renewal: [%{id: 1065, amount: 1}]],
    damage_splash: true

  alias Aesir.Commons.GameMode
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
       unit_range: 1,
       visibility: Trap.visibility(:ht_blastmine)
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
  def on_unit_hit(%Group{} = group, _cell, _target, now) do
    with true <- Trap.armed?(group),
         :ok <- detonate(group) do
      {:ok, Trap.spring(group, now)}
    else
      _inert -> {:ok, group}
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
          split: GameMode.mode() == :renewal
        )

        :ok

      :error ->
        {:error, :caster_unavailable}
    end
  end

  defp execute_splash(caster_state, center, radius, %Group{caster_type: :player} = group, opts),
    do: SkillAttack.execute_field_misc_splash(caster_state, center, radius, group, opts)

  defp execute_splash(caster_state, center, radius, %Group{caster_type: :mob}, opts),
    do:
      SkillAttack.execute_misc_splash(
        caster_state,
        center,
        radius,
        Keyword.put(opts, :delivery, :unit)
      )
end
