defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross do
  @moduledoc """
  Grand Cross (CR_GRANDCROSS). Plants a 9-cell holy cross on the caster's cell that
  ticks every 300 ms for about 900 ms, costing 20% of max HP plus 37 to 100 SP and
  refusing a cast the HP cost would not survive. A player caster is rooted for the
  field's life and loses the shield's DEF and MDEF while it lasts; every tick hits
  each offensive target on the cross, the player caster included, through the
  skill-owned hybrid recipe (renewal averages raw attack contributions before flat
  defences; classic sums separately defended contributions). Enemy damage takes two
  holy adjustments; self-damage one holy adjustment and one half-rate. Mob casters
  skip the HP, root, and self-damage rules. Demon-race and undead-element mobs on
  the field are blinded.

  Renewal: a 1 s cast plus 0.5 s fixed, a 0.5 s delay, a 1 s cooldown, blind 18 s.
  Pre-renewal: a 3 s cast, a 1.5 s delay, no cooldown, blind 30 s.
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
    cast_time: [renewal: List.duplicate(1_000, 10), pre_renewal: List.duplicate(3_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(500, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 10), pre_renewal: List.duplicate(1_500, 10)],
    cooldown: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    duration: [renewal: List.duplicate(18_000, 10), pre_renewal: List.duplicate(30_000, 10)]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
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
      {:ok, %{race: race} = target} ->
        if race == :demon or RaceModifiers.undead_target?(target) do
          StatusInterpreter.apply_status(:mob, target_id, :sc_blind,
            duration: hd(definition().duration)
          )
        end

        :ok

      _ ->
        :ok
    end
  end

  defp maybe_blind(_unit_type, _target_id), do: :ok
end
