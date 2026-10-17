defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross do
  @moduledoc """
  Grand Cross (CR_GRANDCROSS). Plants a 29-cell holy diamond (a cross with arms of
  four cells, widened next to its center) on the caster's cell for 950 ms,
  costing 20% of current HP plus 37 to 100 SP (a share of current HP always
  leaves the caster alive). A player's own cast holds them in place (no walking
  or Teleport) and bars equipping a shield for 950 ms, keeping the shield worn.

  Each cell is its own unit with three charges. On every 100 ms unit pass a cell
  hits each enemy standing on it whose 300 ms strike interval ran out, spending
  a charge per hit; a cell out of charges is removed once that pass is done.
  Hits go through the skill-owned hybrid recipe (renewal averages raw attack
  contributions before flat defences; classic sums separately defended
  contributions). Enemy damage takes two holy adjustments. Non-player targets
  that are undead-element or demon-race are blinded. A cell on Land Protector
  hits nobody; nothing hits while the caster is gone.

  Pre-renewal: the field also hits its own caster (one holy adjustment and one
  half-rate for a player, nothing for a monster), a 3 s cast, a 1.5 s delay, no
  cooldown, blind 30 s. Renewal: the caster is never hit, a 1 s cast plus 0.5 s
  fixed, a 0.5 s delay, a 1 s cooldown, blind 18 s.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 254,
    name: :cr_grandcross,
    cast_cancel: false,
    requires: [],
    display_name: "Grand Cross",
    max_level: 10,
    ignore_noncrit_atk_bonus: [renewal: true, pre_renewal: false],
    target_type: :self,
    damage_type: :damage,
    damage_kind: :magic,
    element: :holy,
    range: 9,
    hit_interval: 300,
    unit_duration: List.duplicate(950, 10),
    hp_cost_rate: List.duplicate(20, 10),
    sp_cost: [37, 44, 51, 58, 65, 72, 79, 86, 93, 100],
    cast_time: [renewal: List.duplicate(1_000, 10), pre_renewal: List.duplicate(3_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(500, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 10), pre_renewal: List.duplicate(1_500, 10)],
    cooldown: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    duration: [renewal: List.duplicate(18_000, 10), pre_renewal: List.duplicate(30_000, 10)]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SkillRange
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.CastendStrip
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross.Damage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @behaviour Active
  @behaviour Ground

  @self_lock_ms 950

  @impl Active
  def cast(caster, target, level, definition),
    do: cast_with_origin(caster, target, level, definition, :normal)

  @impl Active
  def cast_with_origin(%{instance_id: id} = caster, {:unit, id}, level, definition, origin),
    do: cast_with_origin(caster, :self, level, definition, origin)

  def cast_with_origin(caster, :self, level, _definition, origin) do
    CastendStrip.start(caster, origin, :sc_stripshield, @self_lock_ms, [:sc_ankle])

    case Unit.place(caster, :cr_grandcross, level, {caster.x, caster.y}) do
      {:ok, _group} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  @impl Ground
  def on_place(%Group{} = group), do: placement(group)

  @impl Ground
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  # Pre-renewal's TargetSelf flag lets the field hit its own caster.
  @impl Ground
  def unit_targets(%Group{} = group, _cell, refs) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} ->
        caster_ref = {caster.unit_type, caster.unit_id}
        enemies = SplashTargets.eligible(refs, caster)
        Enum.filter(refs, &(&1 in enemies or (&1 == caster_ref and Group.hits_caster?(group))))

      {:error, _reason} ->
        []
    end
  end

  # The charge is spent before the hit; a cell out of charges is removed after
  # its pass.
  @impl Ground
  def on_unit_hit(%Group{state: %{cell_charges: charges} = state} = group, cell, target, _now) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} ->
        left = Map.fetch!(charges, cell) - 1
        group = %{group | state: %{state | cell_charges: Map.put(charges, cell, left)}}
        {unit_type, target_id} = target
        hit(caster, unit_type, target_id, group.level)

        if left <= 0,
          do: {:ok, group, [{:after_cell, {:remove_cells, group.group_id, [cell]}}]},
          else: {:ok, group}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  defp placement(%Group{origin: origin, level: level}) do
    cells = Layout.grand_cross(origin)
    definition = definition()
    duration = Enum.at(definition.unit_duration, level - 1)

    {:ok,
     %{
       cells: cells,
       state: %{
         hits_caster: GameMode.mode() == :pre_renewal,
         cell_charges: Map.new(cells, &{&1, div(duration, definition.hit_interval)})
       },
       interval: definition.hit_interval,
       duration: duration,
       unit_range: 0,
       path_check: true
     }}
  end

  defp hit(caster, unit_type, target_id, level) do
    with {:ok, prepared} <-
           Combat.prepare_skill_unit_hit(caster, {unit_type, target_id}, definition().id),
         {:ok, physical} <- physical_input(caster) do
      target = prepared.target
      modifiers = ModifierCalculator.get_all_modifiers(caster.unit_type, caster.unit_id)
      defender_modifiers = ModifierCalculator.get_all_modifiers(target.unit_type, target.unit_id)

      attack_flag =
        BattleFlags.build(
          :magic,
          SkillRange.classify(caster, target, definition().id, level),
          true
        )

      magic =
        DamageInputs.magic_context(
          caster,
          target,
          [skill_id: definition().id, element: :holy, attack_flag: attack_flag],
          modifiers,
          defender_modifiers
        )

      inputs = %{
        caster_ref: {caster.unit_type, caster.unit_id},
        target_ref: {target.unit_type, target.unit_id},
        level: level,
        physical: physical,
        matk: DamageInputs.roll_matk(caster.combat_stats),
        magic: magic,
        physical_defense:
          DamageInputs.physical_defense(
            target,
            caster,
            :apply_status_def,
            :omit_equipment_def_ignore,
            defender_modifiers
          ),
        physical_ignore_rate: EquipmentBonuses.ignore_def_rate(caster, target),
        size_rate: size_rate(caster, target),
        element_step:
          &DamageShared.apply_element_step(&1, &2, caster, target, attacker_modifiers: modifiers),
        equipment_atk_rate: EquipmentBonuses.percent_atk_rate(caster, modifiers),
        non_crit_atk_rate: EquipmentBonuses.non_crit_atk_rate(caster)
      }

      amount =
        if Combatant.infinite_defense?(target, attack_flag),
          do: 1,
          else: Damage.calculate(GameMode.mode(), inputs)

      :ok =
        Combat.deliver_skill_unit_hit(prepared, amount,
          skill_level: level,
          element: :holy,
          additional_effect: fn _source, {type, id} -> maybe_blind(caster, type, id, level) end
        )
    end

    :ok
  end

  defp physical_input(%{unit_type: :player} = caster),
    do: {:ok, {:player, DamageInputs.player_attack_parts(caster, [], :primary, false)}}

  defp physical_input(caster) do
    with {:ok, amount} <- DamageInputs.non_player_base_attack(caster, skill_id: definition().id),
         do: {:ok, {:non_player, amount}}
  end

  defp size_rate(%{combat_stats: %{ignore_size_penalty: true}}, _target), do: 100

  defp size_rate(caster, target) do
    hand = Map.get(caster, :right_hand) || Map.get(caster, :left_hand)
    weapon_type = if hand, do: hand.subtype, else: caster.weapon.type

    if Map.get(caster.equip_modifiers, :no_size_fix, 0) > 0,
      do: 100,
      else: SizeModifiers.get_modifier(weapon_type, target.size, caster.riding)
  end

  # Blind lands only on non-player targets that are undead-element or
  # demon-race; players are never blinded by the field. A monster's hit on
  # itself deals nothing, which is a miss, so it never blinds itself.
  @spec maybe_blind(map(), atom(), integer(), pos_integer()) :: :ok
  defp maybe_blind(_caster, :player, _target_id, _level), do: :ok

  defp maybe_blind(caster, unit_type, target_id, level) do
    case Combat.resolve_combatant(unit_type, target_id) do
      {:ok, %{race: race} = target} ->
        if race == :demon or RaceModifiers.undead_target?(target) do
          StatusInterpreter.apply_status(unit_type, target_id, :sc_blind,
            val1: level,
            duration: hd(definition().duration),
            caster_id: caster.unit_id,
            source_type: caster.unit_type
          )
        end

        :ok

      _ ->
        :ok
    end
  end
end
