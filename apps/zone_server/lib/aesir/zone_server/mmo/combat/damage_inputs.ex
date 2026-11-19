defmodule Aesir.ZoneServer.Mmo.Combat.DamageInputs do
  @moduledoc """
  Shared input preparation for ordinary combat and skill-owned calculations.

  Resolves existing snapshot components, rolls and defense channels without
  selecting skill recipes or delivering damage.
  """
  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @magic_attack_flag BattleFlags.build(:magic, :long, true)
  @zero_equip_rates %{
    attack: %{race: 0, race2: 0, class: 0, element_target: 0, size: 0, atk_ele: 0, skill: 0},
    taken: %{race: 0, race2: 0, class: 0, element: 0, size: 0, magic_size: 0, skill: 0},
    ignore_mdef: 0
  }

  @doc """
  A unit's total `stat`, with equipment and status contributions.

  A live player reads its own stats. A monster's combatant stats already carry
  its status changes. Any other unit, or a player no longer in the registry,
  sums its base stat, its equipment stat and its status stat.
  """
  @spec effective_stat(Combatant.t(), :str | :agi | :vit | :int | :dex | :luk) :: integer()
  def effective_stat(%Combatant{unit_type: :player, unit_id: unit_id} = unit, stat) do
    case UnitRegistry.get_unit(:player, unit_id) do
      {:ok, {_module, %{stats: %PlayerStats{} = stats}, _pid}} ->
        PlayerStats.get_effective_stat(stats, stat)

      _missing ->
        summed_stat(unit, stat)
    end
  end

  def effective_stat(%Combatant{unit_type: :mob, base_stats: stats}, stat),
    do: Map.fetch!(stats, stat)

  def effective_stat(%Combatant{} = unit, stat), do: summed_stat(unit, stat)

  @doc "A unit's effective LUK (`effective_stat/2`)."
  @spec effective_luk(Combatant.t()) :: integer()
  def effective_luk(%Combatant{} = unit), do: effective_stat(unit, :luk)

  defp summed_stat(unit, stat) do
    status_bonus =
      unit.unit_type
      |> ModifierCalculator.get_battle_modifiers(unit.unit_id)
      |> Map.get(stat, 0)

    Map.get(unit.base_stats, stat, 0) + Map.get(unit.equip_modifiers, stat, 0) + status_bonus
  end

  @doc "Rolls selected player components without reconstructing display ATK."
  @spec player_attack_parts(Combatant.t(), keyword(), atom(), boolean()) :: PhysicalAttack.parts()
  def player_attack_parts(attacker, opts, attack_path, critical?) do
    snapshot = attacker.combat_stats.physical_attack

    right = Map.get(attacker, :right_hand)
    left = Map.get(attacker, :left_hand)
    hand = if attack_path == :secondary, do: left, else: right || left

    parts = %{
      status_atk: snapshot.status_atk,
      flat_atk: snapshot.flat_atk + Keyword.get(opts, :weight_atk, 0),
      mastery_atk: snapshot.mastery_atk,
      hand: if(hand, do: hand.slot, else: :right_hand),
      source: :weapon,
      weapon_atk: 0,
      ammo_atk: 0,
      refine_atk: 0,
      overrefine_atk: 0
    }

    case Keyword.get(opts, :shield_base) do
      nil -> roll_player_weapon(parts, snapshot, hand, attacker, opts, critical?)
      shield -> %{parts | source: :shield, weapon_atk: shield, flat_atk: 0, mastery_atk: 0}
    end
  end

  # A classic bare hand still rolls its weapon ATK (its bAtk plus status weapon
  # ATK) as its maximum, from an unscaled DEX minimum. A renewal bare hand
  # reads its weapon ATK unrolled, and zero when it has no bAtk.
  defp roll_player_weapon(parts, snapshot, nil, attacker, opts, critical?) do
    inputs = %{
      arrow?:
        GameMode.mode() == :renewal and arrow_attack?(attacker, Keyword.get(opts, :skill_id)),
      critical?: critical?
    }

    parts = %{parts | ammo_atk: ammo_attack(attacker, inputs)}

    case {GameMode.mode(), bare_hand_watk(attacker, snapshot)} do
      {_mode, 0} ->
        parts

      {:renewal, watk} ->
        %{parts | weapon_atk: watk}

      {:pre_renewal, maximum} ->
        %{parts | weapon_atk: bare_hand_roll(maximum, snapshot.dex, attacker, critical?)}
    end
  end

  defp roll_player_weapon(parts, snapshot, hand, attacker, opts, critical?) do
    combat_stats = attacker.combat_stats

    inputs = %{
      base_atk: hand.base_atk,
      status_watk: status_watk(attacker, hand),
      refine_atk: hand.refine_atk,
      weapon_level: hand.weapon_level,
      primary_stat:
        if(WeaponTypes.is_ranged?(hand.subtype), do: snapshot.dex, else: snapshot.str),
      dex: snapshot.dex,
      arrow?:
        arrow_attack?(attacker, Keyword.get(opts, :skill_id)) and
          (GameMode.mode() == :renewal or
             (WeaponTypes.requires_ammo?(hand.subtype) and
                (hand.subtype == :bow or not critical?))),
      critical?: critical?,
      max_weapon_damage?: Map.get(combat_stats, :max_weapon_damage, false)
    }

    {minimum, maximum} = Mechanics.physical_attack().weapon_bounds(inputs)

    %{
      parts
      | weapon_atk: DamageShared.roll(minimum, maximum + 1),
        ammo_atk: ammo_attack(attacker, inputs),
        refine_atk: hand.refine_atk,
        overrefine_atk: DamageShared.overrefine_roll(hand.overrefine_band)
    }
  end

  @doc "Whether a hit uses ammunition: an ammo-consuming normal attack or an ammo-requiring skill."
  @spec arrow_attack?(Combatant.t(), non_neg_integer() | nil) :: boolean()
  def arrow_attack?(%{right_hand: %{subtype: subtype}}, nil),
    do: WeaponTypes.requires_ammo?(subtype)

  def arrow_attack?(attacker, nil),
    do: attacker.weapon |> Map.get(:type) |> WeaponTypes.requires_ammo?()

  def arrow_attack?(_attacker, skill_id),
    do: match?({:ok, %{require_ammo: [_ | _]}}, Catalog.by_id(skill_id))

  defp ammo_attack(_attacker, %{arrow?: false}), do: 0

  defp ammo_attack(attacker, inputs) do
    ammo_atk = Map.get(attacker, :ammo_atk, 0)

    case {GameMode.mode(), attacker} do
      {:renewal, %{equip_modifiers: %{ammo_subtype: :cannonball}}} -> 0
      {:pre_renewal, _} when not inputs.critical? -> DamageShared.roll(0, ammo_atk)
      _ -> ammo_atk
    end
  end

  # The bare right hand's weapon ATK: its bAtk plus status weapon ATK, held in
  # `0..65_535`. Renewal applies no status weapon ATK to a hand with none.
  defp bare_hand_watk(attacker, snapshot) do
    bare = Map.get(snapshot, :bare_right_atk, 0)

    if GameMode.mode() == :renewal and bare == 0 do
      0
    else
      status =
        :player |> ModifierCalculator.get_battle_modifiers(attacker.unit_id) |> Map.get(:watk, 0)

      WeaponHand.weapon_atk(bare, status)
    end
  end

  defp bare_hand_roll(maximum, dex, attacker, critical?) do
    if critical? or Map.get(attacker.combat_stats, :max_weapon_damage, false) do
      maximum
    else
      minimum = min(max(dex, 0), maximum)
      DamageShared.roll(minimum, maximum)
    end
  end

  # The status weapon ATK a hand's roll takes. Classic: the right hand always,
  # the left hand only when its weapon has ATK, plus the level-4 key for a
  # level-4 weapon. Renewal: the right hand when it has weapon ATK (a weapon's,
  # or a bare hand's bAtk), else the left; a second weapon never.
  defp status_watk(attacker, hand) do
    modifiers = ModifierCalculator.get_battle_modifiers(:player, attacker.unit_id)

    case GameMode.mode() do
      :pre_renewal -> classic_status_watk(hand, modifiers)
      :renewal -> renewal_status_watk(attacker, hand, modifiers)
    end
  end

  defp classic_status_watk(%{slot: :left_hand, base_atk: 0}, _modifiers), do: 0

  defp classic_status_watk(hand, modifiers) do
    level4 = if hand.weapon_level == 4, do: Map.get(modifiers, :level4_watk, 0), else: 0
    Map.get(modifiers, :watk, 0) + level4
  end

  defp renewal_status_watk(attacker, hand, modifiers) do
    right_weapon? =
      weapon_atk?(Map.get(attacker, :right_hand)) or
        Map.get(attacker.combat_stats.physical_attack, :bare_right_atk, 0) > 0

    if (hand.slot == :right_hand and right_weapon?) or
         (hand.slot == :left_hand and not right_weapon?),
       do: Map.get(modifiers, :watk, 0),
       else: 0
  end

  defp weapon_atk?(%{base_atk: base_atk, refine_atk: refine_atk}), do: base_atk + refine_atk > 0
  defp weapon_atk?(_hand), do: false

  @doc """
  Rolls a non-player's base attack (`battle_calc_base_damage` for a monster
  or homunculus): its weapon roll `atk_min..atk_max - 1` plus its status ATK
  (`atk`).

  `:critical` takes the maximum instead of a roll; in renewal the critical base
  is then multiplied by 14/10. Under Mental Charge a classic non-player's base
  is its maximum MATK, and in either mode a normal attack (no `:skill_id`)
  rolls its MATK bounds instead, with no status ATK.
  """
  @spec non_player_base_attack(Combatant.t(), keyword()) :: {:ok, integer()} | {:error, atom()}
  def non_player_base_attack(attacker, opts \\ [])

  def non_player_base_attack(%{unit_type: type} = attacker, opts)
      when type in [:mob, :homunculus] do
    critical? = Keyword.get(opts, :critical, false)
    stats = attacker.combat_stats
    charged? = StatusStorage.has_status?(type, attacker.unit_id, :sc_change)

    cond do
      charged? and GameMode.mode() == :pre_renewal ->
        {:ok, stats.matk_max}

      charged? and is_nil(Keyword.get(opts, :skill_id)) ->
        {:ok, critical_base(weapon_attack(stats.matk_min, stats.matk_max, critical?), critical?)}

      true ->
        weapon = weapon_attack(stats.atk_min, stats.atk_max, critical?)
        {:ok, critical_base(stats.atk + weapon, critical?)}
    end
  end

  def non_player_base_attack(_attacker, _opts), do: {:error, :unknown_unit_type}

  defp weapon_attack(min_atk, max_atk, false),
    do: DamageShared.roll(min(min_atk, max_atk), max_atk)

  defp weapon_attack(_min_atk, max_atk, true), do: max_atk

  defp critical_base(base, true) do
    if GameMode.mode() == :renewal, do: div(base * 14, 10), else: base
  end

  defp critical_base(base, false), do: base

  @doc """
  A player's status-window DEF as `{hard, soft}`: the battle values with every
  equipment and status modifier, before any attacker-dependent step.
  """
  @spec status_window_defense(PlayerStats.t()) :: {integer(), integer()}
  def status_window_defense(%PlayerStats{} = stats) do
    modifiers = stats.modifiers.status_effects

    case Map.get(modifiers, :def_set) do
      nil ->
        defender = %{
          unit_type: :player,
          combat_stats: stats.combat_stats,
          equip_modifiers: stats.modifiers.equipment
        }

        apply_status_effect_defense_modifiers(
          stats.combat_stats.def,
          calculate_soft_defense(defender),
          modifiers
        )

      value ->
        {value, value}
    end
  end

  @doc """
  A player's status-window MDEF as `{hard, soft}`: the battle values with every
  status modifier, before any attacker-dependent step.
  """
  @spec status_window_magic_defense(PlayerStats.t()) :: {integer(), integer()}
  def status_window_magic_defense(%PlayerStats{} = stats) do
    modifiers = stats.modifiers.status_effects

    case Map.get(modifiers, :mdef_set) do
      nil -> ordinary_mdef_values(stats.combat_stats, modifiers)
      value -> {value, value}
    end
  end

  @doc "Resolves physical DEF using the existing status and equipment omission modes."
  @spec physical_defense(Combatant.t(), Combatant.t() | nil, atom(), atom(), map()) ::
          {integer(), integer()}
  def physical_defense(defender, attacker, status_def_mode, def_ignore_mode, modifiers) do
    {unit_type, unit_id} = get_unit_type_and_id(defender)

    case StatusStorage.get_status(unit_type, unit_id, :sc_defset) do
      %{val1: value} when is_integer(value) ->
        hard_def = ignore_hard_def(value, attacker, defender, def_ignore_mode)
        soft_def = if status_def_mode == :ignore_status_def, do: 0, else: value
        {hard_def, soft_def}

      _missing ->
        ordinary_defense_values(
          defender,
          attacker,
          status_def_mode,
          def_ignore_mode,
          modifiers
        )
    end
  end

  defp ordinary_defense_values(
         defender,
         attacker,
         status_def_mode,
         def_ignore_mode,
         modifiers
       ) do
    hard_def = ignore_hard_def(defender.combat_stats.def, attacker, defender, def_ignore_mode)

    soft_def =
      if status_def_mode == :ignore_status_def do
        0
      else
        calculate_soft_defense(defender) + divine_protection_bonus(attacker, defender)
      end

    {modified_hard_def, modified_soft_def} =
      apply_status_effect_defense_modifiers(hard_def, soft_def, modifiers)

    if status_def_mode == :ignore_status_def do
      {modified_hard_def, 0}
    else
      {modified_hard_def, modified_soft_def}
    end
  end

  defp calculate_soft_defense(%{unit_type: :player} = defender) do
    rate = max(0, 100 + Map.get(defender.equip_modifiers, :def2_rate, 0))

    soft_def =
      Map.get(defender.combat_stats, :soft_def) ||
        Mechanics.player_formulas().soft_def(%{
          vit: defender.base_stats.vit,
          agi: defender.base_stats.agi,
          base_level: defender.progression.base_level
        })

    div(soft_def * rate, 100)
  end

  defp calculate_soft_defense(%{unit_type: :homunculus} = defender) do
    defender.combat_stats.soft_def
  end

  defp calculate_soft_defense(%{unit_type: :mob} = defender) do
    defender.combat_stats.soft_def
  end

  defp calculate_soft_defense(%{unit_type: :skill_unit} = defender) do
    defender.combat_stats.soft_def
  end

  defp ignore_hard_def(hard_def, _attacker, _defender, :omit_equipment_def_ignore),
    do: hard_def

  defp ignore_hard_def(hard_def, nil, _defender, :apply_equipment_def_ignore), do: hard_def

  defp ignore_hard_def(hard_def, attacker, defender, :apply_equipment_def_ignore) do
    rate = EquipmentBonuses.ignore_def_rate(attacker, defender)
    div(hard_def * (100 - rate), 100)
  end

  defp divine_protection_bonus(nil, _defender), do: 0

  defp divine_protection_bonus(attacker, defender) do
    RaceModifiers.divine_protection_def(defender, attacker)
  end

  defp apply_status_effect_defense_modifiers(hard_def, soft_def, modifiers) do
    hard_def_bonus = Map.get(modifiers, :def_bonus, 0)
    soft_def_bonus = Map.get(modifiers, :vit_bonus, 0)
    def_rate = Map.get(modifiers, :def_rate, 0)
    def2_rate = Map.get(modifiers, :def2_rate, 0)

    defense_multiplier = 1.0 + Map.get(modifiers, :defense_multiplier, 0.0)

    {
      rate_scaled_defense(hard_def + hard_def_bonus, defense_multiplier, def_rate),
      rate_scaled_defense(soft_def + soft_def_bonus, defense_multiplier, def2_rate)
    }
  end

  # The reference applies a defense rate as `def -= def * rate / 100`
  # (`status_calc_def`: Provoke, Fling, Signum Crucis), i.e. the signed rate
  # scales the already-modified defense and the division truncates toward zero,
  # so a 25% cut off 101 DEF leaves 76, not 75.
  defp rate_scaled_defense(defense, multiplier, rate) when rate == 0,
    do: trunc(defense * multiplier)

  defp rate_scaled_defense(defense, multiplier, rate) do
    scaled = trunc(defense * multiplier)
    scaled + div(scaled * rate, 100)
  end

  @doc """
  Captures magic channels using status maps already read by the caller.

  `opts` carries the hit's `:element`, `:skill_id`, `:skill_ratio`,
  `:bonus_matk`, `:ignore_mdef` and `:attack_flag` (the battle flag whose range
  class selects range-flagged resists, default a long-range magic skill hit),
  and the skill's card flags: `:ignore_atk_card` drops every attacker card
  channel, `:ignore_def_card` every target card channel, and `:ignore_element`
  the element channels on both sides.
  """
  @spec magic_context(Combatant.t(), Combatant.t(), keyword(), map(), map()) ::
          MagicDamage.context()
  def magic_context(attacker, defender, opts, modifiers, defender_modifiers) do
    element = Keyword.get(opts, :element, :neutral)
    skill_id = Keyword.get(opts, :skill_id)
    attack_flag = Keyword.get(opts, :attack_flag, @magic_attack_flag)

    equip =
      equipment_rates(
        attacker,
        defender,
        {modifiers, defender_modifiers},
        {skill_id, attack_flag},
        element
      )

    {hard, soft} = mdef_values(defender, defender_modifiers)

    attack = %{
      size: equip.attack.size + status_rate(modifiers, :magic_addsize, Map.get(defender, :size)),
      race2: equip.attack.race2,
      element_target:
        equip.attack.element_target +
          status_rate(modifiers, :magic_addele, defender_element(defender)),
      atk_ele: equip.attack.atk_ele + status_rate(modifiers, :magic_atk_ele, element),
      race:
        equip.attack.race + status_rate(modifiers, :magic_addrace, Map.get(defender, :race)) +
          RaceModifiers.dragonology_matk_rate(attacker, Map.get(defender, :race)),
      class: equip.attack.class
    }

    taken = %{
      element: equip.taken.element,
      size: equip.taken.size,
      magic_size: equip.taken.magic_size,
      race2: equip.taken.race2,
      race:
        equip.taken.race +
          RaceModifiers.dragonology_resist_rate(defender, Map.get(attacker, :race)),
      class: equip.taken.class,
      magic: Map.get(defender_modifiers, :magic_damage_reduction, 0)
    }

    {attack, taken} = apply_card_flags(attack, taken, opts)

    %{
      attack: attack,
      taken: taken,
      skill_ratio: Keyword.get(opts, :skill_ratio, 100),
      bonus_matk: Keyword.get(opts, :bonus_matk, 0),
      skill_atk_rate: equip.attack.skill,
      skill_taken_rate: equip.taken.skill,
      damage_multiplier: Map.get(modifiers, :damage_multiplier, 0),
      smatk: Map.get(attacker.combat_stats, :smatk, 0),
      mres: Map.get(defender.combat_stats, :mres, 0),
      hard_mdef: hard,
      soft_mdef: soft,
      ignore_mdef_rate: equip.ignore_mdef,
      ignore_mdef?: Keyword.get(opts, :ignore_mdef, false)
    }
  end

  defp apply_card_flags(attack, taken, opts) do
    attack = if Keyword.get(opts, :ignore_atk_card, false), do: zero(attack), else: attack
    taken = if Keyword.get(opts, :ignore_def_card, false), do: zero(taken), else: taken

    if Keyword.get(opts, :ignore_element, false),
      do: {%{attack | element_target: 0, atk_ele: 0}, %{taken | element: 0}},
      else: {attack, taken}
  end

  defp zero(rates), do: Map.new(rates, fn {channel, _rate} -> {channel, 0} end)

  @doc """
  Renewal SC_MAGICALBULLET's weapon ATK term (`battle.cpp` `battle_attack_sc_bonus`).

  With `tmdef` the target's hard plus soft MDEF: when `matk_min > tmdef` and the
  band is not degenerate, the half-open MATK roll minus `tmdef`; otherwise
  `matk_min - tmdef`. Either result is floored at 0.
  """
  @spec magical_bullet_atk(CombatStats.t(), CombatStats.t()) :: non_neg_integer()
  def magical_bullet_atk(attacker_stats, defender_stats) do
    tmdef = (defender_stats.mdef || 0) + (defender_stats.soft_mdef || 0)
    matk_min = attacker_stats.matk_min
    matk_max = attacker_stats.matk_max

    if matk_min > tmdef,
      do: max(DamageShared.roll(matk_min, matk_max) - tmdef, 0),
      else: max(matk_min - tmdef, 0)
  end

  @doc "Rolls the half-open MATK band, falling back to its deterministic scalar."
  @spec roll_matk(CombatStats.t()) :: non_neg_integer()
  def roll_matk(combat_stats) do
    DamageShared.roll(
      combat_stats.matk_min || combat_stats.matk,
      combat_stats.matk_max || combat_stats.matk
    )
  end

  defp status_rate(modifiers, family, value) do
    Map.get(modifiers, {family, value}, 0) + Map.get(modifiers, {family, :all}, 0)
  end

  defp defender_element(defender) do
    case Map.get(defender, :element, :neutral) do
      {element, _level} -> element
      element -> element
    end
  end

  defp mdef_values(defender, modifiers) do
    {unit_type, unit_id} = magic_unit_ref(defender)

    case StatusStorage.get_status(unit_type, unit_id, :sc_mdefset) do
      %{val1: value} when is_integer(value) ->
        {value, value}

      _missing ->
        ordinary_mdef_values(defender.combat_stats, modifiers)
    end
  end

  defp ordinary_mdef_values(combat_stats, modifiers) do
    mdef_rate = Map.get(modifiers, :mdef_rate, 0)
    {rate_scaled_defense(combat_stats.mdef, 1.0, mdef_rate), combat_stats.soft_mdef}
  end

  defp equipment_rates(
         %Combatant{} = attacker,
         %Combatant{} = defender,
         {attacker_modifiers, defender_modifiers},
         {skill_id, attack_flag},
         element
       ) do
    %{
      attack:
        EquipmentBonuses.magic_attack_rates(
          attacker,
          defender,
          skill_id,
          element,
          attacker_modifiers
        ),
      taken:
        EquipmentBonuses.magic_defense_rates(
          defender,
          attacker,
          element,
          defender_modifiers,
          skill_id,
          attack_flag
        ),
      ignore_mdef: EquipmentBonuses.ignore_mdef_rate(attacker, defender)
    }
  end

  defp equipment_rates(_attacker, _defender, _modifiers, _skill, _element),
    do: @zero_equip_rates

  defp magic_unit_ref(%{unit_type: type, unit_id: id}) when type in [:player, :mob],
    do: {type, id}

  defp magic_unit_ref(%{unit_id: id}), do: {:unknown, id}

  defp get_unit_type_and_id(%{unit_type: type, unit_id: id})
       when type in [:player, :mob, :homunculus], do: {type, id}

  defp get_unit_type_and_id(%{unit_id: id}), do: {:unknown, id}
end
