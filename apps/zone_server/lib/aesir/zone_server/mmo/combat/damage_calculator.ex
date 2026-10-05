defmodule Aesir.ZoneServer.Mmo.Combat.DamageCalculator do
  @moduledoc """
  Unified damage calculation system for all unit types.

  This module consolidates the duplicate damage calculation logic that was
  previously split between player and mob combat systems. It provides a
  single physical-damage entry point with mode-specific player arithmetic.

  ## Key Features

  - Unified damage calculation for all unit types (players, mobs, future units)
  - Composable modifier pipeline (size, race, element, status effects)
  - Mode-specific player attack components and defense formulas
  - Critical hit processing

  ## Usage

      attacker_combatant = %{...}  # Standardized combatant structure
      defender_combatant = %{...}  # Standardized combatant structure

      case DamageCalculator.calculate_damage(attacker_combatant, defender_combatant) do
        {:ok, damage_result} ->
          # damage_result contains: %{damage: integer(), is_critical: boolean()}
        {:error, reason} ->
          # Handle error
      end
  """

  require Logger

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.PreRenewal, as: PreRenewalAttack
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.Renewal, as: RenewalAttack

  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  @emperium_mob_id 1288

  @typedoc """
  Result of damage calculation containing final damage and critical hit status.
  """
  @type damage_result :: %{
          damage: non_neg_integer(),
          is_critical: boolean()
        }

  @typedoc """
  Standardized combatant structure for damage calculations.
  References the Combatant struct defined in the Combatant module.
  """
  @type combatant :: Combatant.t()

  @doc """
  Calculates physical damage using the booted ruleset.

  This is the main entry point for all damage calculations, regardless of
  unit type (player, mob, future units). The function handles:

  1. Base attack calculation (delegated to unit-specific logic)
  2. Modifier applications (size, race, element, status effects)
  3. Mode-specific defense and component ordering
  4. Critical hit processing

  ## Parameters
    - attacker: Standardized combatant structure for attacker
    - defender: Standardized combatant structure for defender

  ## Returns
    - {:ok, damage_result} on success
    - {:error, reason} on failure

  ## Examples

      attacker = build_player_combatant(player_stats)
      defender = build_mob_combatant(mob_data)

      case DamageCalculator.calculate_damage(attacker, defender) do
        {:ok, %{damage: 150, is_critical: false}} ->
          apply_damage_to_target(defender, 150)
        {:error, reason} ->
          handle_damage_error(reason)
      end
  """
  @spec calculate_damage(combatant(), combatant()) :: {:ok, damage_result()} | {:error, atom()}
  def calculate_damage(attacker, defender), do: calculate_damage(attacker, defender, [])

  @doc """
  Calculates damage with skill modifiers.

  Options:
    - `:skill_ratio` - percent of base attack the skill deals (default `100`).
      A Bash at level 10 passes `400` for 400% weapon damage.
    - `:skip_crit` - when `true`, never rolls a critical (skills don't crit
      unless flagged). Default `false`.
    - `:critical_max_weapon` - when `false`, a critical keeps normal weapon
      variance instead of maximum weapon damage. Default `true`.
    - `:bonus_atk` - flat ATK added after the skill-ratio step and before the
      modifier/defense pipeline (e.g. Envenom's `+15×level` mastery). Default `0`.
    - `:fixed_damage` - when set to an integer, short-circuits the entire
      pipeline and returns that flat value, bypassing base attack, skill ratio,
      modifiers, defense, criticals, and any flee/hit consideration (e.g. Stone
      Fling's fixed `50`). Default `nil`.
    - `:element` - overrides the attack element for this hit only, taking
      priority over both the weapon element and an `SC_WATK_ELEMENT` endow
      (e.g. Envenom's poison, Sand Attack's earth). Default `nil` (resolve
      normally).

  Player weapon hits use the active physical-attack component pipeline, including
  mode-specific ratio, element and cardfix ordering. Non-player hits and explicit
  `:base_damage` replacements retain the shared scalar modifier pipeline.
  """
  @spec calculate_damage(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage(attacker, defender, opts) do
    calculate_damage_with(
      attacker,
      defender,
      opts,
      :primary,
      :normal
    )
  end

  @doc """
  Calculates left-hand weapon damage without attacker cardfix or equipment DEF-ignore.

  The selected left hand supplies weapon ATK, refine, overrefine, subtype, and
  element. Global attacker modifiers and every defender-side channel remain active.
  Returns `{:error, :no_left_hand}` when no left-hand snapshot is available.
  """
  @spec calculate_secondary_hand_damage(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_secondary_hand_damage(%Combatant{left_hand: nil}, _defender, _opts),
    do: {:error, :no_left_hand}

  def calculate_secondary_hand_damage(attacker, defender, opts) do
    calculate_damage_with(
      attacker,
      defender,
      opts,
      :secondary,
      :normal
    )
  end

  @doc """
  Calculates physical damage while omitting only attacker equipment cardfix.

  Equipment-derived DEF-ignore, skill and range rates, status/passive modifiers,
  and defender-side channels remain active.
  """
  @spec calculate_damage_ignoring_attacker_cards(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage_ignoring_attacker_cards(attacker, defender, opts) do
    calculate_damage_with(
      attacker,
      defender,
      opts,
      :ignore_attacker_cards,
      :normal
    )
  end

  @doc """
  Calculates physical skill damage while omitting the defender's status DEF.

  This restricted entry point preserves equipment DEF and the rest of the
  weapon-damage pipeline. It exists for skills whose mechanic explicitly
  ignores status DEF without exposing a general bypass option.
  """
  @spec calculate_damage_ignoring_status_def(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage_ignoring_status_def(attacker, defender, opts) do
    calculate_damage_with(
      attacker,
      defender,
      opts,
      :primary,
      :ignore_status
    )
  end

  @doc """
  Calculates physical skill damage using the simplified (flat) defense reduction.

  For a skill with simplified defense (e.g. Asura Strike), the renewal
  `Attack * (4000 + eDEF) / (4000 + eDEF*10)` curve is replaced by a flat
  subtraction of hard + soft DEF (`total_atk - (eDEF + sDEF)`). Every other
  channel - status DEF modifiers, equipment DEF-ignore, divine protection, phys
  damage reduction, and the min-1 clamp - is unchanged.
  """
  @spec calculate_damage_simple_defense(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage_simple_defense(attacker, defender, opts) do
    calculate_damage_with(
      attacker,
      defender,
      opts,
      :primary,
      :simple
    )
  end

  @doc """
  Calculates physical skill damage while skipping the defender's DEF entirely.

  Used by skills the classic ruleset declares as ignoring defense (e.g. Asura
  Strike); every other channel of the pipeline is unchanged.
  """
  @spec calculate_damage_ignoring_defense(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage_ignoring_defense(attacker, defender, opts) do
    calculate_damage_with(attacker, defender, opts, :primary, :ignore)
  end

  @doc """
  Calculates physical skill damage subtracting only the defender's soft DEF.

  Used by skills the classic ruleset declares as ignoring hard DEF while still
  losing the VIT-based soft DEF (e.g. classic Acid Terror).
  """
  @spec calculate_damage_soft_defense_only(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage_soft_defense_only(attacker, defender, opts) do
    calculate_damage_with(attacker, defender, opts, :primary, :soft_only)
  end

  defp calculate_damage_with(attacker, defender, opts, attack_path, defense_mode) do
    case Keyword.get(opts, :fixed_damage) do
      nil -> calculate_pipeline_damage(attacker, defender, opts, attack_path, defense_mode)
      fixed_damage -> {:ok, %{damage: fixed_damage, is_critical: false}}
    end
  end

  defp calculate_pipeline_damage(attacker, defender, opts, attack_path, defense_mode) do
    attacker = select_weapon_hand(attacker, attack_path)

    cond do
      emperium_plant_contact?(defender, opts) ->
        calculate_emperium_plant_contact(attacker, defender, opts)

      attacker.unit_type == :player and not Keyword.has_key?(opts, :base_damage) ->
        calculate_player_pipeline_damage(attacker, defender, opts, attack_path, defense_mode)

      true ->
        calculate_ordinary_pipeline_damage(attacker, defender, opts, attack_path, defense_mode)
    end
  end

  # The scalar recipe of non-player hits and of player hits with a replaced base:
  # modifiers and DEF, the post-defense minimum, the attribute step, the critical
  # tail and then the target's cards (battle.cpp:5625-5758).
  defp calculate_ordinary_pipeline_damage(
         attacker,
         defender,
         opts,
         attack_path,
         defense_mode
       ) do
    skill_ratio = Keyword.get(opts, :skill_ratio, 100)
    bonus_atk = Keyword.get(opts, :bonus_atk, 0)
    modifiers = attacker_status_modifiers(attacker)

    with {:ok, base_atk} <- calculate_base_attack(attacker, opts),
         patk_atk = apply_patk_multiplier(base_atk, attacker),
         skilled_atk = div(patk_atk * skill_ratio, 100) + bonus_atk,
         modified_atk =
           apply_attack_modifiers(skilled_atk, attacker, defender, opts, attack_path, modifiers),
         total_atk = modified_atk + demon_bane_bonus(attacker, defender),
         total_atk = total_atk + beast_bane_bonus(attacker, defender),
         total_atk = apply_res_reduction(total_atk, defender),
         {:ok, defended} <-
           scalar_defense(
             total_atk,
             defender,
             attacker,
             attack_path,
             ratio_scaled_mode(defense_mode, skill_ratio)
           ),
         hit = %{
           attacker: attacker,
           defender: defender,
           opts: opts,
           modifiers: modifiers,
           watk_base: modified_atk
         },
         elemental = scalar_element(max(defended, 1), hit),
         {:ok, result} <- finalize_damage(elemental, attacker, defender, opts) do
      taken =
        apply_equipment_taken_families(
          result.damage,
          attacker,
          defender,
          Keyword.get(opts, :skill_id),
          hit_element(attacker, modifiers, opts),
          opts
        )

      {:ok, %{result | damage: taken}}
    end
  end

  # Non-player basic attacks take no attribute step (`attack_attr_none`); renewal
  # players take one only in the Sacrifice group; other hits take their element.
  defp scalar_element(damage, %{attacker: attacker, opts: opts} = hit) do
    player? = attacker.unit_type == :player

    cond do
      not player? and is_nil(Keyword.get(opts, :skill_id)) ->
        damage

      player? and GameMode.mode() == :renewal ->
        post_defense_element(
          damage,
          hit,
          hit_element(attacker, hit.modifiers, opts),
          sacrifice_group?(opts)
        )

      true ->
        post_defense_element(damage, hit, hit_element(attacker, hit.modifiers, opts), true)
    end
  end

  defp ratio_scaled_mode(:soft_only, skill_ratio), do: {:soft_only, skill_ratio}
  defp ratio_scaled_mode(mode, _skill_ratio), do: mode

  # The modifier pipeline yields a float; every defense path truncates it on the
  # way out, so the DEF-ignoring path must too or a float reaches the HP pools.
  defp scalar_defense(damage, _defender, _attacker, _path, :ignore),
    do: {:ok, DamageShared.clamp_min_one(damage)}

  defp scalar_defense(damage, defender, attacker, _path, {:soft_only, ratio}),
    do:
      apply_defense_formula(
        damage,
        defender,
        attacker,
        :apply_status_def,
        :apply_equipment_def_ignore,
        {:soft_only, ratio}
      )

  defp scalar_defense(damage, defender, attacker, _path, :ignore_status),
    do: apply_defense_formula_ignoring_status_def(damage, defender, attacker)

  defp scalar_defense(damage, defender, attacker, _path, :simple),
    do: apply_defense_formula_simple(damage, defender, attacker)

  defp scalar_defense(damage, defender, attacker, :secondary, :normal),
    do: apply_defense_formula_without_equipment_def_ignore(damage, defender, attacker)

  defp scalar_defense(damage, defender, attacker, _path, :normal),
    do: apply_defense_formula(damage, defender, attacker)

  defp calculate_player_pipeline_damage(attacker, defender, opts, attack_path, defense_mode) do
    with {:ok, critical} <- finalize_damage(0, attacker, defender, opts) do
      hit = %{
        attacker: attacker,
        defender: defender,
        opts: opts,
        attack_path: attack_path,
        defense_mode: defense_mode,
        critical: critical,
        modifiers: attacker_status_modifiers(attacker)
      }

      case GameMode.mode() do
        :renewal ->
          hit
          |> Map.put(:elements, hand_elements(attacker, hit.modifiers, opts))
          |> renewal_player_damage()

        :pre_renewal ->
          classic_player_damage(hit)
      end
    end
  end

  defp player_parts(hit, attacker, attack_path) do
    parts =
      DamageInputs.player_attack_parts(
        attacker,
        hit.opts,
        attack_path,
        hit.critical.is_critical and Keyword.get(hit.opts, :critical_max_weapon, true)
      )

    mastery =
      parts.mastery_atk + demon_bane_bonus(attacker, hit.defender) +
        beast_bane_bonus(attacker, hit.defender) + renewal_envenom_atk(hit.opts)

    if parts.source == :shield, do: parts, else: %{parts | mastery_atk: mastery}
  end

  defp hand_context(hit, attacker, attack_path, parts) do
    player_damage_context(
      attacker,
      hit.defender,
      hit.opts,
      attack_path,
      hit.defense_mode,
      parts,
      hit.critical
    )
  end

  # Classic runs one attribute step on each hand's post-defense damage.
  defp classic_player_damage(hit) do
    parts = player_parts(hit, hit.attacker, hit.attack_path)
    context = hand_context(hit, hit.attacker, hit.attack_path, parts)
    element = hit_element(hit.attacker, hit.modifiers, hit.opts)
    # NOTE: Task 27 completes wd->basedamage (Star Crumb, Spirit Sphere).
    hit = Map.put(hit, :watk_base, PreRenewalAttack.normal_base(parts, context))

    damage =
      parts
      |> PreRenewalAttack.pre_element(context)
      |> post_defense_element(hit, element, true)
      |> PreRenewalAttack.post_element(context)

    {:ok, %{hit.critical | damage: damage}}
  end

  # Renewal attributes each component of both hands before the ratio and defense,
  # in the reference call order; the second hand of a dual-wield attack reuses
  # the components its first hand's call already adjusted.
  defp renewal_player_damage(%{attack_path: :secondary} = hit) do
    parts = player_parts(hit, hit.attacker, :secondary)
    context = hand_context(hit, hit.attacker, :secondary, parts)

    components =
      case Keyword.fetch(hit.opts, :left_components) do
        {:ok, adjusted} ->
          adjusted

        :error ->
          [left] =
            component_elements(
              [RenewalAttack.prepare_components(parts, context)],
              [elem(hit.elements, 1)],
              hit
            )

          left
      end

    {:ok, %{hit.critical | damage: renewal_hand_damage(components, context, hit)}}
  end

  defp renewal_player_damage(hit) do
    parts = player_parts(hit, hit.attacker, hit.attack_path)
    context = hand_context(hit, hit.attacker, hit.attack_path, parts)
    {right_element, left_element} = hit.elements
    right = RenewalAttack.prepare_components(parts, context)
    left = left_components(hit, right)

    [right, left] = component_elements([right, left], [right_element, left_element], hit)

    result = %{hit.critical | damage: renewal_hand_damage(right, context, hit)}

    {:ok,
     if(dual_wield?(hit.attacker), do: Map.put(result, :left_components, left), else: result)}
  end

  # The left hand's components exist on every renewal attack. Without a second
  # weapon its weapon ATK is 0 but its equipment ATK equals the right hand's
  # (equipAtk2 takes the same equipment ATK), and its attribute steps still run.
  defp left_components(hit, right) do
    if dual_wield?(hit.attacker) do
      secondary = select_weapon_hand(hit.attacker, :secondary)
      parts = player_parts(hit, secondary, :secondary)
      RenewalAttack.prepare_components(parts, hand_context(hit, secondary, :secondary, parts))
    else
      %{right | weapon_atk: 0, hand: :left_hand}
    end
  end

  defp dual_wield?(%{right_hand: %WeaponHand{}, left_hand: %WeaponHand{}}), do: true
  defp dual_wield?(_attacker), do: false

  defp renewal_hand_damage(components, context, hit) do
    element =
      if components.hand == :left_hand, do: elem(hit.elements, 1), else: elem(hit.elements, 0)

    components
    |> RenewalAttack.after_component_elements(context)
    |> RenewalAttack.calculate_components(context)
    |> post_defense_element(hit, element, sacrifice_group?(hit.opts))
    |> RenewalAttack.finish_attack(context)
  end

  # battle_calc_damage_parts: status ATK of every hand (neutral), the pseudo-element
  # weapon share, weapon ATK, then equipment ATK, each step over all hands in turn.
  # Right-hand weapon status ATK doubles after its step.
  defp component_elements(hands, elements, hit) do
    step = &element_step(&1, &2, hit)

    hands
    |> Enum.map(&%{&1 | status_atk: step.(&1.status_atk, :neutral)})
    |> pseudo_element_shares(hit)
    |> Enum.zip(elements)
    |> Enum.map(fn {hand, element} -> %{hand | weapon_atk: step.(hand.weapon_atk, element)} end)
    |> Enum.zip(elements)
    |> Enum.map(fn {hand, element} -> %{hand | flat_atk: step.(hand.flat_atk, element)} end)
    |> Enum.map(&double_right_status/1)
  end

  defp double_right_status(%{hand: :right_hand, source: :weapon} = hand),
    do: %{hand | status_atk: hand.status_atk * 2}

  defp double_right_status(hand), do: hand

  # Renewal Magnum Break (SC_SUB_WEAPONPROPERTY): a share of each hand's weapon ATK
  # takes the status element first and joins the weapon ATK before its own step.
  defp pseudo_element_shares(hands, hit) do
    Enum.reduce(hit.modifiers, hands, fn
      {{:pseudo_element_atk, element}, percent}, hands when is_integer(percent) and percent > 0 ->
        shares = Enum.map(hands, &div(&1.weapon_atk * percent, 100))
        adjusted = Enum.map(shares, &element_step(&1, element, hit))

        hands
        |> Enum.zip(adjusted)
        |> Enum.map(fn {hand, share} -> %{hand | weapon_atk: hand.weapon_atk + share} end)

      _modifier, hands ->
        hands
    end)
  end

  defp element_step(damage, element, hit, opts \\ []) do
    DamageShared.apply_element_step(
      damage,
      element,
      hit.attacker,
      hit.defender,
      Keyword.put(opts, :attacker_modifiers, hit.modifiers)
    )
  end

  # battle_calc_element_damage: the post-defense attribute recipe. `primary?` says
  # whether the hit's own element applies here (classic and non-player hits, and
  # the Sacrifice group); the forced-neutral skills then take a neutral step, and
  # classic Envenom adds its flat ATK and takes its element again. Damage is then
  # capped at 0 (`attribute_recover: no`).
  defp post_defense_element(damage, hit, element, primary?) do
    if Keyword.get(hit.opts, :ignore_element, false) or damage <= 0 do
      max(damage, 0)
    else
      damage =
        if primary?, do: element_step(damage, element, hit, allow_negative: true), else: damage

      damage =
        if Keyword.get(hit.opts, :skill_id) in forced_neutral_skills(),
          do: element_step(damage, :neutral, hit, allow_negative: true),
          else: damage

      damage
      |> classic_envenom(element, hit)
      |> classic_pseudo_element(hit)
      |> max(0)
    end
  end

  # Classic Magnum Break (SC_WATK_ELEMENT): for players, a share of the normal-attack
  # base takes the status element and joins the damage before the 0 cap.
  defp classic_pseudo_element(damage, %{attacker: %{unit_type: :player}, watk_base: base} = hit) do
    if GameMode.mode() == :pre_renewal do
      Enum.reduce(hit.modifiers, damage, fn
        {{:pseudo_element_atk, element}, percent}, acc when is_integer(percent) and percent > 0 ->
          acc + div(element_step(base, element, hit, allow_negative: true) * percent, 100)

        _modifier, acc ->
          acc
      end)
    else
      damage
    end
  end

  defp classic_pseudo_element(damage, _hit), do: damage

  # Cart Revolution and Stave Crasher in both modes; Investigate, Asura Strike,
  # Shield Boomerang and Shield Chain in renewal.
  defp forced_neutral_skills do
    case GameMode.mode() do
      :renewal -> [153, 365, 266, 271, 251, 480]
      :pre_renewal -> [153, 365]
    end
  end

  # PA_SACRIFICE, RK_DRAGONBREATH(_WATER), NC_SELFDESTRUCTION and HFLI_SBR44 re-take
  # their element even for renewal players.
  defp sacrifice_group?(opts), do: Keyword.get(opts, :skill_id) in [368, 2008, 5004, 2267, 8012]

  # Renewal Envenom's flat ATK is player mastery ATK (battle.cpp:3811-3812); classic
  # adds it after the attribute step and takes the element again (3719-3723).
  defp renewal_envenom_atk(opts) do
    if GameMode.mode() == :renewal, do: Keyword.get(opts, :envenom_atk, 0), else: 0
  end

  defp classic_envenom(damage, element, hit) do
    case {GameMode.mode(), Keyword.get(hit.opts, :envenom_atk, 0)} do
      {:pre_renewal, atk} when atk > 0 ->
        element_step(damage + atk, element, hit, allow_negative: true)

      _other ->
        damage
    end
  end

  # battle_get_weapon_element: a skill element applies to both hands; otherwise
  # each hand takes its weapon element and an endow overrides both.
  defp hand_elements(attacker, modifiers, opts) do
    case Keyword.get(opts, :element) do
      nil ->
        endow = Map.get(modifiers, :attack_element)
        {resolve_attack_element(attacker, modifiers), endow || left_weapon_element(attacker)}

      forced ->
        {forced, forced}
    end
  end

  defp left_weapon_element(%{left_hand: %WeaponHand{element: element}}) when not is_nil(element),
    do: element

  defp left_weapon_element(_attacker), do: :neutral

  defp hit_element(attacker, modifiers, opts),
    do: Keyword.get(opts, :element) || resolve_attack_element(attacker, modifiers)

  defp attacker_status_modifiers(attacker) do
    {unit_type, unit_id} = get_unit_type_and_id(attacker)
    ModifierCalculator.get_all_modifiers(unit_type, unit_id)
  end

  defp player_damage_context(attacker, defender, opts, attack_path, defense_mode, parts, critical) do
    {attacker_type, attacker_id} = get_unit_type_and_id(attacker)
    {defender_type, defender_id} = get_unit_type_and_id(defender)
    attacker_modifiers = ModifierCalculator.get_all_modifiers(attacker_type, attacker_id)
    defender_modifiers = ModifierCalculator.get_all_modifiers(defender_type, defender_id)
    element = Keyword.get(opts, :element) || resolve_attack_element(attacker, attacker_modifiers)
    skill_id = Keyword.get(opts, :skill_id)

    attack_rates =
      EquipmentBonuses.attack_rates(attacker, defender, skill_id, element, attacker_modifiers)

    ranged? = ranged_hit?(attacker, opts)
    flag = BattleFlags.build(:weapon, if(ranged?, do: :long, else: :short), not is_nil(skill_id))

    taken_rates =
      EquipmentBonuses.damage_taken_rates(
        defender,
        attacker,
        element,
        defender_modifiers,
        skill_id,
        flag
      )

    card_rates =
      if attack_path in [:secondary, :ignore_attacker_cards],
        do: %{race_class: 0, element: 0, size: 0},
        else: Map.take(attack_rates, [:race_class, :element, :size])

    %{
      size_rate:
        if(parts.source == :shield,
          do: 100,
          else: trunc(apply_size_modifier(100, attacker, defender, opts))
        ),
      attacker_rates: card_rates,
      defender_rates: %{
        race_class:
          taken_rates.race_class + RaceModifiers.dragonology_resist_rate(defender, attacker.race),
        monster: EquipmentBonuses.def_monster_rate(defender, attacker),
        element: taken_rates.element,
        size: taken_rates.size,
        long_def: EquipmentBonuses.long_range_defense_rate(defender, defender_modifiers, ranged?),
        ranged: EquipmentBonuses.ranged_damage_taken_rate(defender, defender_modifiers, ranged?)
      },
      defense:
        player_defense_context(defender, attacker, attack_path, defense_mode, defender_modifiers),
      defense_mode:
        if(defense_mode in [:simple, :ignore, :soft_only], do: defense_mode, else: :normal),
      skill_id: skill_id,
      skill_ratio: Keyword.get(opts, :skill_ratio, 100),
      base_atk_rate: Keyword.get(opts, :base_atk_rate, 100),
      bonus_atk: Keyword.get(opts, :bonus_atk, 0),
      post_defense_atk:
        if(skill_id in Map.get(attacker_modifiers, :post_defense_atk_excludes, []),
          do: 0,
          else: Map.get(attacker_modifiers, :post_defense_atk, 0)
        ),
      skill_atk_rate: attack_rates.skill,
      skill_taken_rate: taken_rates.skill,
      global_race_rate: RaceModifiers.dragonology_atk_rate(attacker, defender.race),
      weapon_bonus: Map.get(attacker_modifiers, :watk, 0),
      flat_bonus:
        Map.get(attacker_modifiers, :damage_bonus, 0) + Map.get(attacker_modifiers, :atk_bonus, 0),
      atk_rate: Map.get(attacker_modifiers, :atk_rate, 0),
      damage_multiplier: Map.get(attacker_modifiers, :damage_multiplier, 0),
      equipment_atk_rate: Map.get(attacker.equip_modifiers, :atk_rate, 0),
      long_atk_rate: EquipmentBonuses.long_atk_rate(attacker),
      short_atk_rate: EquipmentBonuses.short_atk_rate(attacker),
      patk: Map.get(attacker.combat_stats, :patk, 0),
      res: Map.get(defender.combat_stats, :res, 0),
      critical?: critical.is_critical,
      crate: Map.get(attacker.combat_stats, :crate, 0),
      crit_atk_rate:
        Map.get(attacker.equip_modifiers, :crit_atk_rate, 0) +
          Map.get(attacker_modifiers, :crit_atk_rate, 0),
      physical_reduction: Map.get(defender_modifiers, :phys_damage_reduction, 0)
    }
  end

  defp player_defense_context(defender, attacker, attack_path, defense_mode, modifiers) do
    status_mode =
      if defense_mode == :ignore_status, do: :ignore_status_def, else: :apply_status_def

    ignore_mode =
      if attack_path == :secondary,
        do: :omit_equipment_def_ignore,
        else: :apply_equipment_def_ignore

    {hard, soft} =
      DamageInputs.physical_defense(defender, attacker, status_mode, ignore_mode, modifiers)

    %{
      hard_def: hard,
      soft_def: soft,
      attacker_level: attacker_level(attacker),
      ignore_soft_def?: defense_mode == :ignore_status
    }
  end

  # A plant-mode Emperium contact is 1 damage that takes the weapon's attribute
  # step (battle.cpp:4980-4996).
  defp calculate_emperium_plant_contact(attacker, defender, opts) do
    modifiers = attacker_status_modifiers(attacker)

    damage =
      DamageShared.apply_element_step(
        1,
        hit_element(attacker, modifiers, opts),
        attacker,
        defender,
        attacker_modifiers: modifiers
      )

    with {:ok, result} <- finalize_damage(1, attacker, defender, opts) do
      {:ok, %{result | damage: damage}}
    end
  end

  defp emperium_plant_contact?(
         %Combatant{unit_type: :mob, monster_id: @emperium_mob_id},
         opts
       ) do
    is_nil(Keyword.get(opts, :skill_id)) and
      Mechanics.mob_formulas().emperium_damage_mode() == :plant
  end

  defp emperium_plant_contact?(_defender, _opts), do: false

  # P.Atk (renewal 4th-job attacker stat): a percentage multiplier on base ATK
  # applied before the skill ratio. rAthena battle.cpp:5532.
  defp apply_patk_multiplier(base_atk, attacker) do
    patk = Map.get(attacker.combat_stats, :patk, 0)
    div(base_atk * (100 + patk), 100)
  end

  # Res (renewal 4th-job defender stat): a soft-capped reduction applied to
  # total ATK before the DEF formula. rAthena battle.cpp:5608.
  defp apply_res_reduction(total_atk, defender) do
    res = Map.get(defender.combat_stats, :res, 0)
    DamageShared.res_reduction(total_atk, res)
  end

  # Demon Bane (AL_DEMONBANE): flat ATK added before the defense formula when the
  # defender is undead/demon. Additive, unlike the multiplicative race modifier.
  defp demon_bane_bonus(attacker, defender) do
    RaceModifiers.demon_bane_atk(attacker, defender)
  end

  defp beast_bane_bonus(attacker, defender) do
    RaceModifiers.beast_bane_atk(attacker, defender.race)
  end

  # `:force_crit` guarantees the critical (Auto Counter's counter strike) and
  # wins over `:skip_crit`; otherwise the roll is skipped or rolled per opts.
  defp finalize_damage(damage, attacker, defender, opts) do
    cond do
      Keyword.get(opts, :force_crit, false) ->
        apply_forced_critical_hit(damage, attacker)

      Keyword.get(opts, :skip_crit, false) ->
        {:ok, %{damage: damage, is_critical: false}}

      true ->
        apply_critical_hit(
          damage,
          attacker,
          defender,
          Keyword.get(opts, :critical_rate_bonus, 0)
        )
    end
  end

  @doc """
  Calculates base attack value based on unit type and stats.

  This function delegates to unit-specific base attack calculation logic
  while providing a unified interface.

  Player combatants carry a physical snapshot separating status, flat equipment
  and mastery ATK; only the selected hand supplies weapon variance. The aggregate
  display ATK is not an input to this calculation.
  """
  @spec calculate_base_attack(combatant()) :: {:ok, integer()} | {:error, atom()}
  def calculate_base_attack(attacker), do: calculate_base_attack(attacker, [])

  @doc """
  Calculates base attack with optional narrow base replacement.

  `:base_damage` must be a non-negative integer. When present it replaces only
  the unit-specific base attack roll; P.Atk, skill ratio, combat modifiers,
  RES/DEF, minimum damage, and critical processing remain in the normal damage
  pipeline.

  `:shield_base` replaces a player attacker's weapon ATK and mastery with the
  pre-computed shield contribution. Other unit types ignore it.
  """
  @spec calculate_base_attack(combatant(), keyword()) :: {:ok, integer()} | {:error, atom()}
  def calculate_base_attack(attacker, opts) do
    case Keyword.fetch(opts, :base_damage) do
      {:ok, damage} when is_integer(damage) and damage >= 0 -> {:ok, damage}
      {:ok, _invalid} -> {:error, :invalid_base_damage}
      :error -> calculate_unit_base_attack(attacker, opts)
    end
  end

  defp calculate_unit_base_attack(%{unit_type: :player} = attacker, opts) do
    parts =
      DamageInputs.player_attack_parts(
        attacker,
        opts,
        :primary,
        Keyword.get(opts, :force_crit, false)
      )

    {:ok, Mechanics.physical_attack().base_attack(parts)}
  end

  defp calculate_unit_base_attack(attacker, _opts),
    do: DamageInputs.non_player_base_attack(attacker)

  @doc """
  Applies the scalar recipe's modifier stages to `base_damage`, without DEF.

  In reference order: size, status ATK channels and the attacker's equipment
  families; then the hit's post-defense attribute step (none for a non-player
  basic attack, the Sacrifice group only for a renewal player) and the target's
  equipment damage-taken families. The attribute step is an actual application:
  it can burn a web.

  `opts` accepts `:element` to force the attack element, `:skill_id` to scope the
  skill families, and `:skip_status_atk` to leave status ATK channels unapplied.
  """
  @spec apply_modifier_pipeline(integer(), combatant(), combatant(), keyword()) ::
          {:ok, integer()}
  def apply_modifier_pipeline(base_damage, attacker, defender, opts \\ []) do
    modifiers = attacker_status_modifiers(attacker)
    hit = %{attacker: attacker, defender: defender, opts: opts, modifiers: modifiers}

    damage =
      base_damage
      |> apply_attack_modifiers(attacker, defender, opts, :primary, modifiers)
      |> then(&scalar_element(&1, Map.put(hit, :watk_base, &1)))
      |> apply_equipment_taken_families(
        attacker,
        defender,
        Keyword.get(opts, :skill_id),
        hit_element(attacker, modifiers, opts),
        opts
      )

    {:ok, damage}
  end

  # The scalar recipe's pre-defense modifiers: size, status ATK channels and the
  # attacker's equipment families. Element and the target's cards follow DEF.
  defp apply_attack_modifiers(base_damage, attacker, defender, opts, attack_path, modifiers) do
    skill_id = Keyword.get(opts, :skill_id)
    attack_element = hit_element(attacker, modifiers, opts)

    base_damage
    |> apply_size_modifier(attacker, defender, opts)
    |> apply_status_effect_damage_modifiers(modifiers, Keyword.get(opts, :skip_status_atk, false))
    |> apply_equipment_attack_families(
      attacker,
      modifiers,
      defender,
      skill_id,
      attack_element,
      attack_path
    )
    |> trunc()
  end

  @doc """
  Applies the Renewal defense reduction formula.

  Formula: Attack * (4000 + eDEF) / (4000 + eDEF*10) - sDEF

  Where:
  - eDEF = equipment/hard defense
  - sDEF = soft defense (VIT-based)
  """
  @spec apply_defense_formula(number(), combatant(), combatant() | nil) :: {:ok, integer()}
  def apply_defense_formula(total_atk, defender, attacker \\ nil),
    do: apply_defense_formula(total_atk, defender, attacker, :apply_status_def)

  defp apply_defense_formula_ignoring_status_def(total_atk, defender, attacker),
    do:
      apply_defense_formula(
        total_atk,
        defender,
        attacker,
        :ignore_status_def,
        :apply_equipment_def_ignore
      )

  defp apply_defense_formula_without_equipment_def_ignore(total_atk, defender, attacker),
    do:
      apply_defense_formula(
        total_atk,
        defender,
        attacker,
        :apply_status_def,
        :omit_equipment_def_ignore
      )

  defp apply_defense_formula_simple(total_atk, defender, attacker),
    do:
      apply_defense_formula(
        total_atk,
        defender,
        attacker,
        :apply_status_def,
        :apply_equipment_def_ignore,
        :simple
      )

  defp apply_defense_formula(total_atk, defender, attacker, status_def_mode),
    do:
      apply_defense_formula(
        total_atk,
        defender,
        attacker,
        status_def_mode,
        :apply_equipment_def_ignore
      )

  defp apply_defense_formula(total_atk, defender, attacker, status_def_mode, def_ignore_mode),
    do:
      apply_defense_formula(
        total_atk,
        defender,
        attacker,
        status_def_mode,
        def_ignore_mode,
        :renewal
      )

  defp apply_defense_formula(
         total_atk,
         defender,
         attacker,
         status_def_mode,
         def_ignore_mode,
         def_formula
       ) do
    {unit_type, unit_id} = get_unit_type_and_id(defender)
    modifiers = ModifierCalculator.get_all_modifiers(unit_type, unit_id)

    {modified_hard_def, modified_soft_def} =
      DamageInputs.physical_defense(
        defender,
        attacker,
        status_def_mode,
        def_ignore_mode,
        modifiers
      )

    base_damage =
      case def_formula do
        :renewal ->
          Mechanics.defense().apply_def(total_atk, %{
            hard_def: modified_hard_def,
            soft_def: modified_soft_def,
            attacker_level: attacker_level(attacker),
            ignore_soft_def?: status_def_mode == :ignore_status_def
          })

        :simple ->
          effective_hard_def = if modified_hard_def == -400, do: -399, else: modified_hard_def
          defense_base_damage(:simple, total_atk, effective_hard_def, modified_soft_def)

        {:soft_only, ratio} ->
          total_atk - div(modified_soft_def * ratio, 100)
      end

    final_damage =
      base_damage
      |> apply_phys_damage_reduction(modifiers)
      |> DamageShared.clamp_min_one()

    Logger.debug(
      "Defense calculation: total_atk=#{trunc(total_atk)}, hard_def=#{modified_hard_def}, soft_def=#{modified_soft_def}, final_damage=#{final_damage}"
    )

    {:ok, final_damage}
  end

  defp defense_base_damage(:simple, total_atk, hard_def, soft_def),
    do: total_atk - (hard_def + soft_def)

  defp attacker_level(nil), do: nil
  defp attacker_level(%{progression: %{base_level: base_level}}), do: base_level

  @doc """
  Applies critical hit calculation to final damage without a target race bonus.
  """
  @spec apply_critical_hit(integer(), combatant()) :: {:ok, CriticalHits.critical_result()}
  def apply_critical_hit(base_damage, attacker),
    do: apply_critical_hit_with_rate(base_damage, attacker, critical_rate(attacker, nil, 0))

  @doc """
  Applies critical hit calculation with equipment chance keyed on the defender's race.
  """
  @spec apply_critical_hit(integer(), combatant(), combatant()) ::
          {:ok, CriticalHits.critical_result()}
  def apply_critical_hit(base_damage, attacker, defender),
    do: apply_critical_hit(base_damage, attacker, defender, 0)

  @doc "Applies critical hit calculation with an additional flat chance percentage."
  @spec apply_critical_hit(integer(), combatant(), combatant(), integer()) ::
          {:ok, CriticalHits.critical_result()}
  def apply_critical_hit(base_damage, attacker, defender, additional_rate) do
    apply_critical_hit_with_rate(
      base_damage,
      attacker,
      critical_rate(attacker, defender, additional_rate)
    )
  end

  @doc "Rolls the attacker's critical against a defender using the damage calculator's rate."
  @spec roll_critical?(combatant(), combatant(), integer()) :: boolean()
  def roll_critical?(attacker, defender, additional_rate \\ 0) do
    CriticalHits.is_critical_hit?(critical_rate(attacker, defender, additional_rate))
  end

  defp critical_rate(attacker, defender, additional_rate) do
    base_rate =
      computed_critical_rate(attacker) ||
        CriticalHits.calculate_critical_rate(%{
          luk: attacker.base_stats.luk,
          base_level: Map.get(Map.get(attacker, :progression) || %{}, :base_level, 0)
        })

    race_rate =
      if is_nil(defender),
        do: 0,
        else: EquipmentBonuses.critical_add_race_rate(attacker, defender)

    CriticalHits.calculate_critical_rate(%{
      critical: base_rate + (race_rate + additional_rate) * 10
    })
  end

  defp apply_critical_hit_with_rate(base_damage, attacker, rate) do
    attacker_for_crit = %{
      luk: attacker.base_stats.luk,
      critical: rate,
      combat_stats: attacker.combat_stats,
      equip_modifiers: attacker.equip_modifiers
    }

    critical_result = CriticalHits.calculate_critical_hit(attacker_for_crit, base_damage)

    Logger.debug(
      "Critical hit check: base_damage=#{base_damage}, final_damage=#{critical_result.damage}#{if critical_result.is_critical, do: " (CRITICAL)", else: ""}"
    )

    {:ok, critical_result}
  end

  @doc """
  Applies the Renewal critical multiplier unconditionally, flagging the hit as a
  critical without rolling.

  For effects that deal a guaranteed critical regardless of the attacker's crit
  rate (Auto Counter's counter strike). Reuses `CriticalHits.apply_critical_damage/2`
  so the CRate and equipment critical-damage channels stay identical to a rolled
  critical.
  """
  @spec apply_forced_critical_hit(integer(), combatant()) :: {:ok, CriticalHits.critical_result()}
  def apply_forced_critical_hit(base_damage, attacker) do
    attacker_for_crit = %{
      combat_stats: attacker.combat_stats,
      equip_modifiers: attacker.equip_modifiers
    }

    {:ok,
     %{
       damage: CriticalHits.apply_critical_damage(base_damage, attacker_for_crit),
       is_critical: true,
       critical_rate: 1_000
     }}
  end

  defp computed_critical_rate(%{combat_stats: %{critical_rate: critical_rate}})
       when is_integer(critical_rate),
       do: critical_rate

  defp computed_critical_rate(%{combat_stats: %{critical: critical}})
       when is_integer(critical),
       do: critical * 10

  defp computed_critical_rate(_attacker), do: nil

  # Private helper functions

  defp select_weapon_hand(
         %Combatant{unit_type: :player, right_hand: right, left_hand: left} = attacker,
         attack_path
       )
       when not is_nil(right) or not is_nil(left) do
    selected = if attack_path == :secondary, do: left, else: right || left

    weapon =
      if attack_path == :secondary or is_nil(right),
        do: selected_weapon(attacker.weapon, selected),
        else: %{attacker.weapon | type: selected.subtype}

    %{attacker | weapon: weapon}
  end

  defp select_weapon_hand(attacker, _attack_path), do: attacker

  defp selected_weapon(weapon, nil), do: weapon

  defp selected_weapon(weapon, hand) do
    %{weapon | type: hand.subtype, element: hand.element}
  end

  # Attacker percent damage families. Each family (race+class, element, size,
  # skill, long-attack, short-attack) is one sequential multiplicative step. The
  # two range families are mutually exclusive — the weapon is either ranged or
  # not — so only one of them is ever non-zero. Every contributor to a family
  # sums into a single accumulator before the multiply, so passives (Dragonology)
  # and equipment never compound against each other — mirroring the magic
  # pipeline's cardfix model. A family summing to 0 is identity, preserving the
  # float damage untouched.
  defp apply_equipment_attack_families(
         damage,
         attacker,
         attacker_modifiers,
         defender,
         skill_id,
         attack_element,
         attack_path
       ) do
    %{race_class: card_race_class, element: card_element, size: card_size, skill: skill} =
      EquipmentBonuses.attack_rates(
        attacker,
        defender,
        skill_id,
        attack_element,
        attacker_modifiers
      )

    {card_race_class, card_element, card_size} =
      case attack_path do
        path when path in [:secondary, :ignore_attacker_cards] -> {0, 0, 0}
        :primary -> {card_race_class, card_element, card_size}
      end

    race_class =
      card_race_class + RaceModifiers.dragonology_atk_rate(attacker, defender.race)

    damage
    |> apply_family_step(race_class)
    |> apply_family_step(card_element)
    |> apply_family_step(card_size)
    |> apply_family_step(skill)
    |> apply_family_step(EquipmentBonuses.long_atk_rate(attacker))
    |> apply_family_step(EquipmentBonuses.short_atk_rate(attacker))
  end

  # Defender percent damage-taken families, read off the defender's own
  # equipment and status effects, keyed on the attacker's traits / the effective
  # attack element. Dragonology's resist rate sums into the race+class family like
  # any other contributor; the defender's status resist keys (subele/subrace) sum
  # into the element/race families through EquipmentBonuses. The ranged family is
  # a taken-rate step gated on the hit being ranged — the per-hit `:ranged` opt
  # (thrown-weapon skills), a ranged weapon class, or a long attack range (ranged
  # mobs) — matching the `is_short` determination used at hit delivery. The
  # families follow the attribute step, so an immune hit stays 0.
  defp apply_equipment_taken_families(damage, attacker, defender, skill_id, attack_element, opts) do
    {unit_type, unit_id} = get_unit_type_and_id(defender)
    status_modifiers = ModifierCalculator.get_all_modifiers(unit_type, unit_id)

    # A physical hit is a weapon attack, ranged or melee by the same rule that
    # decides `is_short` at hit delivery, and skill-sourced whenever a skill id
    # is present. Trigger-flagged resists match against that classification.
    attack_flag =
      BattleFlags.build(
        :weapon,
        if(ranged_hit?(attacker, opts), do: :long, else: :short),
        skill_id != nil
      )

    %{race_class: race_class, element: element, size: size, skill: skill} =
      EquipmentBonuses.damage_taken_rates(
        defender,
        attacker,
        attack_element,
        status_modifiers,
        skill_id,
        attack_flag
      )

    race_class = race_class + RaceModifiers.dragonology_resist_rate(defender, attacker.race)

    ranged =
      EquipmentBonuses.ranged_damage_taken_rate(
        defender,
        status_modifiers,
        ranged_hit?(attacker, opts)
      )

    long_def =
      EquipmentBonuses.long_range_defense_rate(
        defender,
        status_modifiers,
        ranged_hit?(attacker, opts)
      )

    damage
    |> apply_taken_step(race_class)
    |> apply_taken_step(EquipmentBonuses.def_monster_rate(defender, attacker))
    |> apply_taken_step(element)
    |> apply_taken_step(size)
    |> apply_taken_step(skill)
    |> apply_taken_step(long_def)
    |> apply_taken_rate_step(ranged)
  end

  @doc """
  Whether a physical hit is ranged: an explicit `ranged: true` option, a ranged
  weapon class, or an attack range above 3 cells.
  """
  @spec ranged_hit?(map(), keyword()) :: boolean()
  def ranged_hit?(attacker, opts) do
    Keyword.get(opts, :ranged, false) or
      attacker.weapon |> Map.get(:type) |> WeaponTypes.is_ranged?() or
      Map.get(attacker, :attack_range, 1) > 3
  end

  defp apply_family_step(damage, 0), do: damage
  defp apply_family_step(damage, sum), do: div(trunc(damage) * (100 + sum), 100)

  defp apply_taken_step(damage, 0), do: damage
  defp apply_taken_step(damage, sum), do: div(trunc(damage) * (100 - sum), 100)

  defp apply_taken_rate_step(damage, 0), do: damage
  defp apply_taken_rate_step(damage, sum), do: div(trunc(damage) * (100 + sum), 100)

  defp resolve_attack_element(attacker, attacker_modifiers) do
    Map.get_lazy(attacker_modifiers, :attack_element, fn ->
      Map.get(attacker.weapon, :element, :neutral)
    end)
  end

  defp apply_size_modifier(damage, attacker, defender, opts) do
    # `bNoSizeFix` on the attacker's equipment ignores the size modifier entirely,
    # like the status-driven `ignore_size_penalty` above.
    if Keyword.get(opts, :ignore_size, false) or
         Map.get(attacker.combat_stats, :ignore_size_penalty, false) or
         Map.get(Map.get(attacker, :equip_modifiers, %{}), :no_size_fix, 0) > 0 do
      damage
    else
      modifier = SizeModifiers.get_modifier(attacker.weapon.type, defender.size, attacker.riding)
      damage * modifier / 100
    end
  end

  defp apply_status_effect_damage_modifiers(damage, modifiers, true),
    do: DamageShared.apply_damage_multiplier(damage, modifiers)

  defp apply_status_effect_damage_modifiers(damage, modifiers, false) do
    damage_bonus = Map.get(modifiers, :damage_bonus, 0)
    atk_bonus = Map.get(modifiers, :atk_bonus, 0)
    # :watk is flat weapon ATK granted by statuses (SC_LOUD / Crazy Uproar, Impositio
    # Manus); it is added as flat ATK alongside :atk_bonus / :damage_bonus.
    weapon_atk = Map.get(modifiers, :watk, 0)
    # :atk_rate is an additive percent delta on physical damage (SC_INCATKRATE,
    # Curse's -25, Provoke). Applied after flat ATK, before the damage multiplier.
    atk_rate = Map.get(modifiers, :atk_rate, 0)

    flat_atk = damage_bonus + atk_bonus + weapon_atk
    scaled_atk = (damage + flat_atk) * (100 + atk_rate) / 100

    DamageShared.apply_damage_multiplier(scaled_atk, modifiers)
  end

  # :phys_damage_reduction is the percent of final physical damage the defender
  # shrugs off (SC_DEF_RATE consumable family, rAthena battle.cpp:1151). Clamped
  # to 0..100 before applying.
  defp apply_phys_damage_reduction(damage, modifiers) do
    reduction = clamp_reduction(Map.get(modifiers, :phys_damage_reduction, 0))
    damage * (100 - reduction) / 100
  end

  defp clamp_reduction(value), do: value |> max(0) |> min(100)

  defp get_unit_type_and_id(combatant) do
    case combatant.unit_type do
      :player -> {:player, combatant.unit_id}
      :mob -> {:mob, combatant.unit_id}
      :homunculus -> {:homunculus, combatant.unit_id}
      _ -> {:unknown, combatant.unit_id}
    end
  end
end
