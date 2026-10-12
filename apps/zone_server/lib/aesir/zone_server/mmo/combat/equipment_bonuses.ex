defmodule Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses do
  @moduledoc """
  Pure read surface combat uses for equipment-granted damage bonuses.

  Every read sums a family's specific-param key with its `:all` key
  (`Map.get(combatant.equip_modifiers, key, 0)`), matching how the status
  modifier tuple keys already sum in the magic calculator. Secondary monster
  group families sum each matching group and the `:all` key once. Mobs carry
  an empty `equip_modifiers` map, so every read is zero for them.
  """

  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys
  alias Aesir.ZoneServer.Mmo.WeaponTypes

  @typedoc "A percent (or per-mille, depending on family) sum read from equip_modifiers."
  @type rate :: integer()

  @doc """
  Physical attack-side rate sums keyed on the defender's traits.

  Race, secondary monster groups, and class share one family group per renewal
  (`race_class`). `bAddEle`
  keys on the defender's own defense element (`defender.element`), not the
  attack's element, so `attack_element` is accepted for call-site symmetry
  with `damage_taken_rates/3` but is not read here. `attacker_modifiers` is
  the attacker's folded status-effect map; its `{:addele, element}` entries sum
  into the element family with equipment.
  """
  @spec attack_rates(Combatant.t(), Combatant.t(), pos_integer() | nil, atom(), map()) :: %{
          race_class: rate(),
          element: rate(),
          size: rate(),
          skill: rate()
        }
  def attack_rates(
        %Combatant{} = attacker,
        %Combatant{} = defender,
        skill_id,
        _attack_element,
        attacker_modifiers \\ %{}
      ) do
    defender_element = element_atom(defender.element)

    %{
      race_class:
        read(attacker, :addrace, defender.race) + read(attacker, :addclass, defender.class) +
          add_damage_class_rate(attacker, defender) +
          read_race2(attacker, :addrace2, defender.race2),
      element:
        read(attacker, :addele, defender_element) +
          status_read(attacker_modifiers, :addele, defender_element),
      size: read(attacker, :addsize, defender.size),
      skill: skill_rate(attacker, :skill_atk, skill_id)
    }
  end

  # Attacker status modifiers keyed like the equipment families (e.g. Basilica's
  # `{:addele, :undead}`), summed with the equipment value into one family.
  defp status_read(modifiers, family, param),
    do: Map.get(modifiers, {family, param}, 0) + Map.get(modifiers, {family, :all}, 0)

  @doc """
  Damage-taken-side rate sums keyed on the attacker's traits, including
  secondary monster groups, read off the defender's own equipment.

  `status_modifiers` is the defender's folded status-effect modifier map; its
  element/race resist keys (`:subele_holy`, `:subrace_demon`) sum into the same
  families equipment feeds, so a status resist and an equipment resist for the
  same element/race stack. Faith (`CR_TRUST`) feeds the element family the same
  way, straight off the defender's precomputed `faith_level` rather than a
  status modifier — the same precomputed-combatant-field approach as
  Dragonology's `RaceModifiers.dragonology_resist_rate/2`, though Faith is read
  here so both damage classes get it from one place. Mobs and callers without
  statuses pass `%{}` and read equipment only.

  The element resist family has two equipment channels that stack: `:subele`
  keyed on the incoming attack's element, and `:sub_def_ele` keyed on the
  attacker's own defensive element (its armor/innate element). Both read off
  the defender's equipment.

  The `skill` family is the defender's per-skill damage reduction
  (`{:sub_skill, skill_id}`), read exactly for the incoming `skill_id` (no
  catch-all): a normal attack (`skill_id == nil`) reduces nothing.

  The sub-resist families additionally carry trigger-condition variants
  (`bonus3 bSubEle,Ele_Fire,3,BF_MAGIC`), which apply only to attacks matching
  their flag. `attack_flag` describes the incoming hit for those; the default
  `0` carries no trigger information, so flagged entries stay inert for callers
  that cannot classify the attack.
  """
  @spec damage_taken_rates(
          Combatant.t(),
          Combatant.t(),
          atom(),
          map(),
          pos_integer() | nil,
          BattleFlags.flag()
        ) :: %{
          race_class: rate(),
          element: rate(),
          size: rate(),
          skill: rate()
        }
  def damage_taken_rates(
        %Combatant{} = defender,
        %Combatant{} = attacker,
        attack_element,
        status_modifiers \\ %{},
        skill_id \\ nil,
        attack_flag \\ 0
      ) do
    rates =
      defense_rates(defender, attacker, attack_element, status_modifiers, skill_id, attack_flag)

    %{
      race_class: rates.race + rates.race2 + rates.class,
      element: rates.element,
      size: rates.size,
      skill: rates.skill
    }
  end

  @doc "Reads separate magic defense channels without merging race, class and secondary groups."
  @spec magic_defense_rates(
          Combatant.t(),
          Combatant.t(),
          atom(),
          map(),
          pos_integer() | nil,
          BattleFlags.flag()
        ) :: %{
          race: rate(),
          race2: rate(),
          class: rate(),
          element: rate(),
          size: rate(),
          skill: rate()
        }
  def magic_defense_rates(defender, attacker, element, status_modifiers, skill_id, attack_flag) do
    defense_rates(defender, attacker, element, status_modifiers, skill_id, attack_flag)
  end

  defp defense_rates(defender, attacker, attack_element, status_modifiers, skill_id, attack_flag) do
    %{
      race:
        read(defender, :subrace, attacker.race, attack_flag) +
          status_subrace(status_modifiers, attacker.race),
      race2: read_race2(defender, :subrace2, attacker.race2),
      class: read(defender, :subclass, attacker.class, attack_flag),
      element:
        read(defender, :subele, attack_element, attack_flag) +
          read(defender, :sub_def_ele, element_atom(attacker.element)) +
          status_subele(status_modifiers, attack_element) +
          faith_resist_rate(defender, attack_element) +
          skin_temper_resist_rate(defender, attack_element),
      size: read(defender, :subsize, attacker.size, attack_flag),
      skill: skill_rate(defender, :sub_skill, skill_id)
    }
  end

  @typedoc """
  How a physical hit reads the attacker's cards: whether it is an arrow attack
  (a bow or gun normal attack, or a skill that uses ammunition), whether its
  range is long, whether this mode adds the range rates to the card product, and
  the attacker's status modifiers.
  """
  @type attack_cardfix_opts :: %{
          arrow?: boolean(),
          ranged?: boolean(),
          range_rates?: boolean(),
          attacker_modifiers: map()
        }

  @doc """
  The attacker's weapon card percentages for one hand of a physical hit, in the
  order they multiply into one per-mille factor.

  Both hands' bonuses act together on the right hand. A melee hit takes the
  element, race (with Dragonology), size, each secondary monster group in
  turn and class. An arrow hit reads the right hand and the ammunition only,
  as race, element, size, the secondary groups summed once, and class. The
  per-monster damage bonus follows, then, where `range_rates?`, the short or
  long attack rate the hit's range selects. The left hand takes only its own
  per-monster damage bonus.
  """
  @spec physical_attack_cardfix(
          Combatant.t(),
          Combatant.t(),
          :right_hand | :left_hand,
          attack_cardfix_opts()
        ) :: [rate()]
  def physical_attack_cardfix(attacker, defender, :left_hand, _opts),
    do: [monster_damage_rate(attacker, defender, :left_add_damage_class)]

  def physical_attack_cardfix(attacker, defender, :right_hand, opts) do
    defender_element = element_atom(defender.element)
    dragon = RaceModifiers.dragonology_atk_rate(attacker, defender.race)
    status_element = status_read(opts.attacker_modifiers, :addele, defender_element)
    other_hand = if opts.arrow?, do: :arrow, else: :weapon

    race = hand_sum(attacker, :addrace, defender.race, other_hand) + dragon
    element = hand_sum(attacker, :addele, defender_element, other_hand) + status_element
    size = hand_sum(attacker, :addsize, defender.size, other_hand)
    class = hand_sum(attacker, :addclass, defender.class, other_hand)

    cards =
      if opts.arrow?,
        do: [race, element, size, race2_sum(attacker, :addrace2, defender.race2), class],
        else: [element, race, size] ++ melee_race2(attacker, defender.race2) ++ [class]

    cards ++
      [monster_damage_rate(attacker, defender, :add_damage_class)] ++ range_rate(attacker, opts)
  end

  # The other hand's (or the ammunition's) family is where that slot's script
  # stores the same bonus.
  defp hand_sum(attacker, family, param, other_hand) do
    {other_family, _param} = BonusKeys.slot_destination({family, param}, other_hand)
    read(attacker, family, param) + read(attacker, other_family, param)
  end

  defp melee_race2(attacker, race2) do
    Enum.map(
      race2,
      &(race2_rate(attacker, :addrace2, &1) + race2_rate(attacker, :left_addrace2, &1))
    )
  end

  defp race2_sum(combatant, family, race2),
    do: Enum.reduce(race2, 0, &(race2_rate(combatant, family, &1) + &2))

  defp race2_rate(combatant, family, group),
    do: Map.get(combatant.equip_modifiers, {family, group}, 0)

  defp monster_damage_rate(_attacker, %Combatant{monster_id: nil}, _family), do: 0

  defp monster_damage_rate(attacker, %Combatant{monster_id: monster_id}, family),
    do: Map.get(attacker.equip_modifiers, {family, monster_id}, 0)

  defp range_rate(_attacker, %{range_rates?: false}), do: []

  defp range_rate(attacker, %{ranged?: true}),
    do: [Map.get(attacker.equip_modifiers, :long_atk_rate, 0)]

  defp range_rate(attacker, _opts), do: [Map.get(attacker.equip_modifiers, :short_atk_rate, 0)]

  @typedoc """
  How a physical hit reads the target's cards: the right hand's attack element,
  then the left hand's when this is a left-hand hit with a different element
  (`elements`), whether the element resists are skipped, the target's status
  modifiers, the hit's battle flag and whether its range is long.
  """
  @type defense_cardfix_opts :: %{
          elements: [atom()],
          ignore_element?: boolean(),
          status_modifiers: map(),
          attack_flag: BattleFlags.flag(),
          ranged?: boolean()
        }

  @doc """
  The target's weapon card reductions against a physical hit, in the order they
  multiply into one per-mille factor: each attack element's resist and the
  attacker's defensive element (unless `ignore_element?`), size, the secondary
  monster groups summed, race (with Dragonology), class, the per-monster
  defense, the near or long defense the hit's range selects, and the DEF-rate
  status.
  """
  @spec physical_defense_cardfix(Combatant.t(), Combatant.t(), defense_cardfix_opts()) ::
          [rate()]
  def physical_defense_cardfix(defender, attacker, opts) do
    rates =
      defense_rates(
        defender,
        attacker,
        hd(opts.elements),
        opts.status_modifiers,
        nil,
        opts.attack_flag
      )

    element_resists =
      if opts.ignore_element?,
        do: [],
        else:
          Enum.map(opts.elements, &element_resist(defender, &1, opts)) ++
            [read(defender, :sub_def_ele, element_atom(attacker.element))]

    element_resists ++
      [
        rates.size,
        race2_sum(defender, :subrace2, attacker.race2),
        rates.race + RaceModifiers.dragonology_resist_rate(defender, attacker.race),
        rates.class,
        def_monster_rate(defender, attacker),
        range_defense_rate(defender, opts),
        Map.get(opts.status_modifiers, :phys_damage_reduction, 0)
      ]
  end

  defp element_resist(defender, element, opts) do
    read(defender, :subele, element, opts.attack_flag) +
      status_subele(opts.status_modifiers, element) + faith_resist_rate(defender, element) +
      skin_temper_resist_rate(defender, element)
  end

  defp range_defense_rate(defender, %{ranged?: true, status_modifiers: modifiers}),
    do: long_range_defense_rate(defender, modifiers, true)

  defp range_defense_rate(defender, _opts),
    do: Map.get(defender.equip_modifiers, :near_atk_def, 0)

  @doc "Percent the attacker's equipment adds to its hits of the named skill."
  @spec skill_atk_rate(Combatant.t(), pos_integer() | nil) :: rate()
  def skill_atk_rate(%Combatant{} = attacker, skill_id),
    do: skill_rate(attacker, :skill_atk, skill_id)

  @doc "Percent the defender's equipment takes off hits of the named skill."
  @spec sub_skill_rate(Combatant.t(), pos_integer() | nil) :: rate()
  def sub_skill_rate(%Combatant{} = defender, skill_id),
    do: skill_rate(defender, :sub_skill, skill_id)

  @doc """
  Percent reduction the defender's equipment and statuses apply to incoming
  long-range physical damage.

  Equipment and status values sum, and melee hits read zero.
  """
  @spec long_range_defense_rate(Combatant.t(), map(), boolean()) :: rate()
  def long_range_defense_rate(%Combatant{} = defender, status_modifiers, true) do
    Map.get(defender.equip_modifiers, :long_atk_def, 0) +
      Map.get(status_modifiers, :long_atk_def, 0)
  end

  def long_range_defense_rate(%Combatant{}, _status_modifiers, false), do: 0

  @doc """
  Magic attack-side rate sums keyed on the defender's traits, including
  secondary monster groups, and the spell's element.
  """
  @spec magic_attack_rates(Combatant.t(), Combatant.t(), pos_integer() | nil, atom()) :: %{
          race: rate(),
          race2: rate(),
          class: rate(),
          element_target: rate(),
          size: rate(),
          atk_ele: rate(),
          skill: rate()
        }
  def magic_attack_rates(
        %Combatant{} = attacker,
        %Combatant{} = defender,
        skill_id,
        spell_element
      ) do
    %{
      race: read(attacker, :magic_addrace, defender.race),
      race2: read_race2(attacker, :magic_addrace2, defender.race2),
      class: read(attacker, :magic_addclass, defender.class),
      element_target: read(attacker, :magic_addele, element_atom(defender.element)),
      size: read(attacker, :magic_addsize, defender.size),
      atk_ele: read(attacker, :magic_atk_ele, spell_element),
      skill: skill_rate(attacker, :skill_atk, skill_id)
    }
  end

  @doc """
  Percent damage bonus the attacker's equipment grants to long-range physical
  attacks (`bLongAtkRate`).

  The bonus belongs to the long-attack damage class, so it is read only when the
  attacker swings a ranged weapon; melee attackers — and every mob, which
  carries no equipment — read zero.
  """
  @spec long_atk_rate(Combatant.t()) :: rate()
  def long_atk_rate(%Combatant{} = attacker) do
    if attacker.weapon |> Map.get(:type) |> WeaponTypes.is_ranged?() do
      Map.get(attacker.equip_modifiers, :long_atk_rate, 0)
    else
      0
    end
  end

  @doc """
  Signed percent bonus the attacker's equipment grants to non-critical physical
  damage (`bNonCritAtkRate`). Each mode's physical recipe decides where, and
  whether, a negative value applies. Mobs carry no equipment and read zero.
  """
  @spec non_crit_atk_rate(Combatant.t()) :: rate()
  def non_crit_atk_rate(%Combatant{} = attacker),
    do: Map.get(attacker.equip_modifiers, :non_crit_atk_rate, 0)

  @doc """
  Percent damage bonus the attacker's equipment grants to close-range physical
  attacks (`bShortAtkRate`).

  The exact counterpart of `long_atk_rate/1`: the bonus belongs to the melee
  damage class, so it is read only when the attacker swings a non-ranged
  weapon. Ranged attackers — and every mob, which carries no equipment — read
  zero.
  """
  @spec short_atk_rate(Combatant.t()) :: rate()
  def short_atk_rate(%Combatant{} = attacker) do
    if attacker.weapon |> Map.get(:type) |> WeaponTypes.is_ranged?() do
      0
    else
      Map.get(attacker.equip_modifiers, :short_atk_rate, 0)
    end
  end

  @doc """
  Percent chance the attacker's equipment grants to land a perfect hit, an
  attack that ignores the defender's flee entirely.

  `bPerfectHitRate` keeps the strongest value while `bPerfectHitAddRate` stacks
  additively; the final chance combines both. It is ungated by weapon or target,
  and mobs read zero because they carry no equipment modifiers.
  """
  @spec perfect_hit_rate(Combatant.t()) :: rate()
  def perfect_hit_rate(%Combatant{} = attacker) do
    strongest = max(0, Map.get(attacker.equip_modifiers, :perfect_hit_rate, 0))
    strongest + Map.get(attacker.equip_modifiers, :perfect_hit, 0)
  end

  @doc """
  Per-mille chance the attacker's equipment grants to drain HP from the damage
  a normal attack deals (`bonus2 bHPDrainRate,rate,per` first argument).
  """
  @spec hp_drain_rate(Combatant.t()) :: rate()
  def hp_drain_rate(%Combatant{} = attacker) do
    Map.get(attacker.equip_modifiers, :hp_drain_rate, 0)
  end

  @doc """
  Percent of the damage dealt the attacker recovers as HP when a drain roll
  succeeds (`bonus2 bHPDrainRate,rate,per` second argument).
  """
  @spec hp_drain_percent(Combatant.t()) :: rate()
  def hp_drain_percent(%Combatant{} = attacker) do
    Map.get(attacker.equip_modifiers, :hp_drain_percent, 0)
  end

  @doc "Flat SP restored by a normal attack against the defender's race."
  @spec sp_drain_race_value(Combatant.t(), Combatant.t()) :: integer()
  def sp_drain_race_value(%Combatant{} = attacker, %Combatant{race: race}) do
    read(attacker, :sp_drain_race, race)
  end

  @doc """
  Radius in cells of the area-of-effect the attacker's equipment adds around the
  primary target of a normal attack (`bSplashRange`). Zero means the attack hits
  only its target.
  """
  @spec splash_range(Combatant.t()) :: non_neg_integer()
  def splash_range(%Combatant{} = attacker) do
    max(Map.get(attacker.equip_modifiers, :splash_range, 0), 0)
  end

  @doc """
  Per-10,000 coma chance granted against the defender's race.

  The exact race and `:all` entries add as a signed sum without clamping.
  """
  @spec coma_race_rate(Combatant.t(), Combatant.t()) :: rate()
  def coma_race_rate(%Combatant{} = attacker, %Combatant{race: race}) do
    read(attacker, :coma_race, race)
  end

  @doc "Per-10,000 coma chance granted against the defender's class."
  @spec coma_class_rate(Combatant.t(), Combatant.t()) :: rate()
  def coma_class_rate(%Combatant{} = attacker, %Combatant{class: class}) do
    read(attacker, :coma_class, class)
  end

  @doc """
  Critical chance percentage points granted against the defender's race.

  The exact race and `:all` entries add without clamping; the critical roll
  converts the result to its tenths-of-a-percent unit and applies its bounds.
  """
  @spec critical_add_race_rate(Combatant.t(), Combatant.t()) :: rate()
  def critical_add_race_rate(%Combatant{} = attacker, %Combatant{race: race}) do
    read(attacker, :critical_add_race, race)
  end

  @doc "Critical chance percentage points added to ordinary ranged attacks."
  @spec critical_long_rate(Combatant.t()) :: rate()
  def critical_long_rate(%Combatant{} = attacker) do
    Map.get(attacker.equip_modifiers, :critical_long, 0)
  end

  @doc """
  Additional signed knockback cells granted to the named skill.

  Reads only the exact skill ID; there is no catch-all skill entry.
  """
  @spec add_skill_blow(Combatant.t(), pos_integer()) :: integer()
  def add_skill_blow(%Combatant{} = attacker, skill_id) do
    Map.get(attacker.equip_modifiers, {:add_skill_blow, skill_id}, 0)
  end

  @doc """
  Percent of the defender's hard DEF ignored by the attacker's equipment,
  capped at 100. Sums the by-race (`bIgnoreDefRace`/`bIgnoreDefRaceRate`) and
  by-class (`bIgnoreDefClass`/`bIgnoreDefClassRate`) contributions against the
  defender's race and class.
  """
  @spec ignore_def_rate(Combatant.t(), Combatant.t()) :: rate()
  def ignore_def_rate(%Combatant{} = attacker, %Combatant{race: race, class: class}) do
    min(read(attacker, :ignore_def_race, race) + read(attacker, :ignore_def_class, class), 100)
  end

  @doc """
  Percent of the defender's hard MDEF ignored by the attacker's equipment,
  capped at 100. Sums the by-race (`bIgnoreMdefRace`/`bIgnoreMdefRaceRate`) and
  by-class (`bIgnoreMdefClassRate`) contributions against the defender's race
  and class.
  """
  @spec ignore_mdef_rate(Combatant.t(), Combatant.t()) :: rate()
  def ignore_mdef_rate(%Combatant{} = attacker, %Combatant{race: race, class: class}) do
    min(read(attacker, :ignore_mdef_race, race) + read(attacker, :ignore_mdef_class, class), 100)
  end

  @doc """
  Percent physical damage reduction against one attacking monster database id.

  Returns zero for non-monster attackers and reads only the exact monster id.
  """
  @spec def_monster_rate(Combatant.t(), Combatant.t()) :: rate()
  def def_monster_rate(_defender, %Combatant{monster_id: nil}), do: 0

  def def_monster_rate(%Combatant{} = defender, %Combatant{monster_id: monster_id}) do
    Map.get(defender.equip_modifiers, {:add_def_monster, monster_id}, 0)
  end

  # Per-monster physical damage bonus (`add_damage_class`), keyed on the target
  # monster's database id. Only mob defenders carry a `monster_id`; against any
  # other target the bonus is zero. Read exactly, with no `:all` fallback.
  @spec add_damage_class_rate(Combatant.t(), Combatant.t()) :: rate()
  defp add_damage_class_rate(_attacker, %Combatant{monster_id: nil}), do: 0

  defp add_damage_class_rate(attacker, %Combatant{monster_id: monster_id}) do
    Map.get(attacker.equip_modifiers, {:add_damage_class, monster_id}, 0)
  end

  @spec read_race2(Combatant.t(), atom(), [atom()]) :: rate()
  defp read_race2(%Combatant{} = combatant, family, race2) when is_list(race2) do
    group_sum =
      Enum.reduce(race2, 0, fn group, acc ->
        acc + Map.get(combatant.equip_modifiers, {family, group}, 0)
      end)

    group_sum + Map.get(combatant.equip_modifiers, {family, :all}, 0)
  end

  @spec read(Combatant.t(), atom(), atom()) :: rate()
  defp read(combatant, family, param) do
    Map.get(combatant.equip_modifiers, {family, param}, 0) +
      Map.get(combatant.equip_modifiers, {family, :all}, 0)
  end

  # The flag-aware read: the unconditional entries plus every trigger-flagged
  # entry of the family whose flag matches this attack. Flagged entries are
  # keyed `{family, {param, flag}}`, so they need a scan of the (small) equip
  # map rather than a direct lookup.
  @spec read(Combatant.t(), atom(), atom(), BattleFlags.flag()) :: rate()
  defp read(combatant, family, param, attack_flag) do
    read(combatant, family, param) +
      flagged_sum(combatant.equip_modifiers, family, param, attack_flag)
  end

  @spec flagged_sum(map(), atom(), atom(), BattleFlags.flag()) :: rate()
  defp flagged_sum(equip_modifiers, family, param, attack_flag) do
    Enum.reduce(equip_modifiers, 0, fn
      {{^family, {entry_param, flag}}, rate}, acc when is_integer(flag) ->
        if entry_param in [param, :all] and BattleFlags.matches_battle?(flag, attack_flag),
          do: acc + rate,
          else: acc

      _entry, acc ->
        acc
    end)
  end

  @spec status_subele(map(), atom()) :: rate()
  defp status_subele(status_modifiers, :water), do: Map.get(status_modifiers, :subele_water, 0)
  defp status_subele(status_modifiers, :earth), do: Map.get(status_modifiers, :subele_earth, 0)
  defp status_subele(status_modifiers, :fire), do: Map.get(status_modifiers, :subele_fire, 0)
  defp status_subele(status_modifiers, :wind), do: Map.get(status_modifiers, :subele_wind, 0)
  defp status_subele(status_modifiers, :holy), do: Map.get(status_modifiers, :subele_holy, 0)
  defp status_subele(_status_modifiers, _element), do: 0

  # Faith (CR_TRUST) grants 5% holy resist per level, precomputed onto
  # `Combatant.faith_level` at build time (0 for mobs).
  @spec faith_resist_rate(Combatant.t(), atom()) :: rate()
  defp faith_resist_rate(%Combatant{faith_level: level}, :holy) when level > 0, do: level * 5
  defp faith_resist_rate(_defender, _attack_element), do: 0

  @spec skin_temper_resist_rate(Combatant.t(), atom()) :: rate()
  defp skin_temper_resist_rate(%Combatant{skin_temper_level: level}, :fire) when level > 0,
    do: level * 5

  defp skin_temper_resist_rate(%Combatant{skin_temper_level: level}, :neutral) when level > 0,
    do: level

  defp skin_temper_resist_rate(_defender, _attack_element), do: 0

  @spec status_subrace(map(), atom()) :: rate()
  defp status_subrace(status_modifiers, :demon), do: Map.get(status_modifiers, :subrace_demon, 0)
  defp status_subrace(_status_modifiers, _race), do: 0

  @spec skill_rate(Combatant.t(), atom(), pos_integer() | nil) :: rate()
  defp skill_rate(_combatant, _family, nil), do: 0

  defp skill_rate(combatant, family, skill_id) when is_integer(skill_id) do
    Map.get(combatant.equip_modifiers, {family, skill_id}, 0)
  end

  @spec element_atom(tuple() | atom()) :: atom()
  defp element_atom({element, _level}), do: element
  defp element_atom(element) when is_atom(element), do: element
end
