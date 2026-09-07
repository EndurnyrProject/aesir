defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross do
  @moduledoc """
  Grand Cross (CR_GRANDCROSS). Self-centered holy hybrid ground skill.

  The caster plants a holy cross field centered on their own cell (`Layout.cross/1`,
  9 cells) that ticks every 300 ms for roughly 900 ms (3 ticks). The cast costs
  20% of the caster's max HP plus SP, and refuses when current HP would not
  survive the deduction (resolved by `Skill.Cost` from `hp_cost_rate`). On a
  player cast the caster is rooted in place (`sc_grandcross_root`) for the field's
  lifetime so it stays centered on them.

  Each tick hits every offensive target standing on a cross cell - including the
  caster, via the `hits_caster` targeting exception - using the skill-owned
  `CrGrandcross.Damage` recipe. Renewal averages raw attack contributions before
  flat physical/magic defense; classic sums separately defended contributions.
  Enemy damage receives two holy adjustments. Player self-damage receives one
  holy adjustment and one half-rate; mob casters exclude themselves. Non-caster
  undead-element or undead/demon-race mob targets are blinded for 18 s at 100%.

  On a player cast the caster is rooted in place (`sc_grandcross_root`) for the
  field's lifetime so it stays centered on them, and loses their own shield's
  DEF/MDEF for the same window (so they take the field's holy damage unshielded).

  Mob casters carry no HP-rate/root cost machinery: they skip the player gates,
  and the field never damages the mob itself.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 254,
    name: :cr_grandcross,
    requires: [],
    display_name: "Grand Cross",
    max_level: 10,
    target_type: :self,
    damage_type: :damage,
    damage_kind: :magic,
    element: :holy,
    range: 9,
    hit_interval: 300,
    unit_duration: List.duplicate(900, 10),
    hp_cost_rate: List.duplicate(20, 10),
    sp_cost: [37, 44, 51, 58, 65, 72, 79, 86, 93, 100],
    cast_time: List.duplicate(1_000, 10)

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross.Damage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @behaviour Active
  @behaviour Ground

  @arm_length 2
  @blind_duration 18_000
  @blind_races [:undead, :demon]
  @root_duration 950

  @impl Active
  def cast(%{instance_id: id} = caster, {:unit, id}, level, definition),
    do: cast(caster, :self, level, definition)

  def cast(caster, :self, level, _definition) do
    case Unit.place(caster, :cr_grandcross, level, {caster.x, caster.y}) do
      {:ok, _group} ->
        root_player_caster(caster)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @impl Ground
  def on_place(%Group{} = group), do: placement(group)

  # A player caster is rooted for the field's lifetime and loses their own
  # shield's defensive contribution for the same window: the shield DEF/MDEF is
  # captured now and carried on the status as val1/val2, which the status emits
  # as negative flat modifiers. Mob casters have no shield and are never rooted.
  @spec root_player_caster(struct()) :: :ok
  defp root_player_caster(%PlayerState{character_id: caster_id, stats: stats}) do
    %{def: shield_def, mdef: shield_mdef} = Stats.shield_defense_contribution(stats)

    StatusInterpreter.apply_status(:player, caster_id, :sc_grandcross_root,
      duration: @root_duration,
      val1: shield_def,
      val2: shield_mdef
    )

    :ok
  end

  defp root_player_caster(_mob_caster), do: :ok

  @impl Ground
  def on_interval(%Group{origin: origin, map_name: map_name, level: level} = group, _now) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} ->
        caster_ref = {caster.unit_type, caster.unit_id}
        hits_caster? = Group.hits_caster?(group) and caster.unit_type == :player
        footprint = MapSet.new(group.cells)

        map_name
        |> Combat.splash_targets(origin, @arm_length, caster, hits_caster?)
        |> Enum.filter(&on_footprint?(&1, footprint))
        |> Enum.each(fn {unit_type, target_id} = target_ref ->
          hit(caster, unit_type, target_id, level, target_ref == caster_ref)
        end)

        {:ok, group}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  defp placement(%Group{origin: origin, level: level}) do
    {ox, oy} = origin || {0, 0}
    cells = Enum.map(Layout.cross(@arm_length), fn {dx, dy} -> {ox + dx, oy + dy} end)
    definition = definition()

    {:ok,
     %{
       cells: cells,
       state: %{hits_caster: true},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1, 900),
       lifecycle_policy: %LifecyclePolicy{max_instances_per_caster: 1}
     }}
  end

  defp hit(caster, unit_type, target_id, level, self?) do
    with {:ok, prepared} <-
           Combat.prepare_skill_unit_hit(caster, {unit_type, target_id}, definition().id),
         {:ok, physical} <- physical_input(caster) do
      target = prepared.target
      modifiers = ModifierCalculator.get_all_modifiers(caster.unit_type, caster.unit_id)
      defender_modifiers = ModifierCalculator.get_all_modifiers(target.unit_type, target.unit_id)

      magic =
        DamageInputs.magic_context(
          caster,
          target,
          [skill_id: definition().id, element: :holy],
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
        neutral_modifier: DamageShared.apply_element(1, :neutral, target, modifiers),
        equipment_atk_rate: Map.get(caster.equip_modifiers, :atk_rate, 0)
      }

      amount = Damage.calculate(GameMode.mode(), inputs)
      :ok = Combat.deliver_skill_unit_hit(prepared, amount, skill_level: level, element: :holy)
      unless self?, do: maybe_blind(unit_type, target_id)
    end

    :ok
  end

  defp physical_input(%{unit_type: :player} = caster),
    do: {:ok, {:player, DamageInputs.player_attack_parts(caster, [], :primary, false)}}

  defp physical_input(caster) do
    with {:ok, amount} <- DamageInputs.non_player_base_attack(caster),
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

  @spec on_footprint?({atom(), integer()}, MapSet.t()) :: boolean()
  defp on_footprint?({unit_type, target_id}, footprint) do
    case SpatialIndex.get_unit_position(unit_type, target_id) do
      {:ok, {x, y, _map_name}} -> MapSet.member?(footprint, {x, y})
      _ -> false
    end
  end

  # Blind lands only on mob targets that are undead-element or undead/demon-race;
  # players are never blinded by the field.
  @spec maybe_blind(atom(), integer()) :: :ok
  defp maybe_blind(:mob, target_id) do
    case Combat.resolve_combatant(:mob, target_id) do
      {:ok, %{race: race, element: element}} ->
        if race in @blind_races or undead_element?(element) do
          StatusInterpreter.apply_status(:mob, target_id, :sc_blind, duration: @blind_duration)
        end

        :ok

      _ ->
        :ok
    end
  end

  defp maybe_blind(_unit_type, _target_id), do: :ok

  defp undead_element?({:undead, _level}), do: true
  defp undead_element?(:undead), do: true
  defp undead_element?(_element), do: false
end
