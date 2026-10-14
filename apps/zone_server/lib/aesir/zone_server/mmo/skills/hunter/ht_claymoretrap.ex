defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtClaymoretrap do
  @moduledoc """
  Claymore Trap (HT_CLAYMORETRAP), a visible trap-centered Fire BF_MISC mine.

  The first enemy within one cell sets it off: one roll of the damage stamped
  at placement hits every enemy within two cells of the mine, and every other
  armed trap in that area that a Claymore spends turns into a used trap without
  going off.

  Renewal: damage stamped at placement as level × DEX × (3 + base level/100) × (1 + INT/35), split across the enemies hit, with a 0.5 s cast plus 0.3 s fixed and a 1 s delay; when its time runs out it turns into a used trap. Pre-renewal: level × (DEX/2 + 75) × (100 + INT)/100, dealt in full to each, and an instant cast; when its time runs out its trap item returns. Both cost two traps.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 123,
    name: :ht_claymoretrap,
    requires: [],
    display_name: "Claymore Trap",
    max_level: 5,
    ignore_noncrit_atk_bonus: [renewal: true, pre_renewal: false],
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :misc,
    element: :fire,
    range: 3,
    splash_radius: 2,
    hit_interval: 1_000,
    unit_duration: [20_000, 40_000, 60_000, 80_000, 100_000],
    cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(300, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    sp_cost: List.duplicate(15, 5),
    item_cost: [%{id: 1065, amount: 2}],
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
       visibility: Trap.visibility(:ht_claymoretrap)
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{} = group, _cell, refs), do: Trap.unit_targets(group, refs)

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) ::
          {:ok, Group.t()} | {:ok, Group.t(), [Ground.command()]}
  def on_unit_hit(%Group{} = group, _cell, _target, now) do
    if Trap.armed?(group), do: detonate(group, now), else: {:ok, group}
  end

  defp detonate(
         %Group{map_name: map_name, center: center, state: %{base_damage: base_damage}} = group,
         now
       ) do
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

        {:ok, Trap.spring(group, now),
         [{:spend_traps, map_name, center, definition.splash_radius}]}

      :error ->
        {:ok, group}
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
