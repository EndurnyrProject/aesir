defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGrounddrift do
  @moduledoc """
  Ground Drift (GS_GROUNDDRIFT), a grenade placed on a cell that bursts on the
  first enemy within one cell.

  The burst's element is decided at placement: the caster's weapon element with
  endows applied (ammunition element does not count). That element also picks
  the grenade's visual sub-unit: wind 0, dark 1, poison 2, water 3, fire 4; any
  other element picks one of the five at random at placement. The burst is a
  3x3 weapon splash around the grenade's cell in the snapshotted element, and
  every target it damages takes the sub-unit's follow-up at 50% with the
  ordinary resistance: Stun, Blind, Poison or Freeze for the Duration2 entry 1,
  2, 3 or 4, or, for the fire sub-unit, a 3-cell push away from the grenade and
  no status. A burst grenade is gone at once, and the other units the same
  pass reaches set off nothing. One that sees no enemy for
  3 s per level turns inert and disappears 1.5 s later without bursting.

  Renewal: 200 + 20 per level percent, 3 SP per level, 0.8 s cast plus 0.2 s
  fixed, a 1 s delay, one bullet; follow-ups last 5/20/20/30 s. Pre-renewal:
  100 percent plus a flat 50 per level for a player caster after the ratio,
  ignoring flee and the attacker's cards, 4 SP per level, a 2 s cast, one
  grenade; follow-ups last 5/30/60/12 s.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 521,
    name: :gs_grounddrift,
    display_name: "Ground Drift",
    max_level: 10,
    requires: [],
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :weapon,
    range: -9,
    snake_eye_range: true,
    splash_radius: 1,
    damage_splash: true,
    knockback: 3,
    unit_range: 1,
    hit_interval: 1_000,
    unit_duration: Enum.map(1..10, &(3_000 * &1)),
    ignore_flee: [renewal: false, pre_renewal: true],
    ignore_atk_card: [renewal: false, pre_renewal: true],
    cast_time: [renewal: List.duplicate(800, 10), pre_renewal: List.duplicate(2_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(200, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    sp_cost: [renewal: Enum.map(1..10, &(3 * &1)), pre_renewal: Enum.map(1..10, &(4 * &1))],
    require_weapon: [:grenade],
    require_ammo: [renewal: [:bullet], pre_renewal: [:grenade]],
    ammo_qty: List.duplicate(1, 10)

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @inert_lifetime 1_500
  @variants %{wind: 0, dark: 1, poison: 2, water: 3, fire: 4}
  @followup_durations %{
    renewal: [5_000, 20_000, 20_000, 30_000],
    pre_renewal: [5_000, 30_000, 60_000, 12_000]
  }

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level, caster_type: ct, caster_id: cid}) do
    {:ok, {module, caster, _pid}} = UnitRegistry.get_unit(ct, cid)
    attacker = module.to_combatant(caster)

    element =
      DamageCalculator.attack_element(attacker, ModifierCalculator.get_battle_modifiers(ct, cid))

    armed_for = Enum.at(definition().unit_duration, level - 1)
    now = System.monotonic_time(:millisecond)

    {:ok,
     %{
       cells: [center],
       state: place_state(element, now + armed_for, &:rand.uniform/1),
       interval: definition().hit_interval,
       duration: armed_for + @inert_lifetime,
       unit_range: 1
     }}
  end

  @doc """
  The placement state: the snapshotted `element`, its visual sub-unit
  (`:variant`, wind 0 to fire 4, otherwise `rng.(5) - 1`), and `:armed_until`.
  """
  @spec place_state(atom(), integer(), (pos_integer() -> pos_integer())) :: map()
  def place_state(element, armed_until, rng) do
    %{
      element: element,
      variant: Map.get_lazy(@variants, element, fn -> rng.(5) - 1 end),
      armed_until: armed_until
    }
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{state: %{armed_until: armed_until}} = group, _cell, refs) do
    if System.monotonic_time(:millisecond) < armed_until and
         match?({:ok, _caster}, Trap.resolve_caster(group)),
       do: Enum.filter(refs, &(living?(&1) and Trap.enemy?(group, &1))),
       else: []
  end

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) ::
          {:ok, Group.t()} | {:expire, Group.t()}
  def on_unit_hit(%Group{state: %{burst: true}} = group, _cell, _target, _now),
    do: {:expire, group}

  def on_unit_hit(%Group{} = group, _cell, _target, _now) do
    case Trap.resolve_caster(group) do
      {:ok, caster} ->
        caster
        |> burst(group)
        |> Enum.each(&followup(group, &1))

        {:expire, %{group | state: Map.put(group.state, :burst, true)}}

      :error ->
        {:ok, group}
    end
  end

  defp burst(caster, %Group{center: center, level: level, state: %{element: element}} = group) do
    definition = definition()

    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: ratio(level),
      element: element,
      ignore_flee: definition.ignore_flee,
      base_distance: 0,
      equipment_blow: false,
      typed_results: true
    ]

    execute_splash(caster, center, definition.splash_radius, group, opts)
  end

  defp ratio(level) do
    case GameMode.mode() do
      :renewal -> 200 + 20 * level
      :pre_renewal -> 100
    end
  end

  defp execute_splash(caster, center, radius, %Group{caster_type: :player} = group, opts) do
    opts = Keyword.put(opts, :late_atk_bonus, classic_flat(group.level))
    SkillAttack.execute_field_splash_attack(caster, center, radius, group, opts)
  end

  defp execute_splash(caster, center, radius, %Group{}, opts),
    do:
      SkillAttack.execute_splash_attack(
        caster,
        center,
        radius,
        Keyword.put(opts, :delivery, :unit)
      )

  defp classic_flat(level) do
    case GameMode.mode() do
      :renewal -> 0
      :pre_renewal -> 50 * level
    end
  end

  defp followup(%Group{state: %{variant: 4}, center: {x, y}}, {type, id}),
    do: Knockback.knockback(type, id, x, y, definition().knockback)

  defp followup(%Group{state: %{variant: variant}} = group, {type, id}) do
    StatusInterpreter.apply_status(type, id, followup_status(variant),
      duration: Enum.at(Map.fetch!(@followup_durations, GameMode.mode()), variant),
      caster_id: group.caster_id,
      source_type: group.caster_type,
      success_rate: 50
    )
  end

  defp followup_status(0), do: :sc_stun
  defp followup_status(1), do: :sc_blind
  defp followup_status(2), do: :sc_poison
  defp followup_status(3), do: :sc_freeze

  defp living?({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _gone -> false
    end
  end
end
