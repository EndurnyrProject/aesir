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
  alias Aesir.ZoneServer.Mmo.Combat.AtkPercent
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.Critical
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.PreRenewal, as: PreRenewalAttack
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.Renewal, as: RenewalAttack
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscKatar

  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  @emperium_mob_id 1288
  @unsplit_plant_skills [263, 267]
  @cart_revolution 153
  @sacrifice 368
  @meteor_assault 406

  @typedoc """
  Result of damage calculation containing final damage and critical hit status.
  """
  @type damage_result :: %{
          required(:damage) => non_neg_integer(),
          required(:is_critical) => boolean(),
          optional(:plant) => plant()
        }

  @typedoc """
  How an infinite-defense contact divides over its hits: `:emperium` keeps its
  single contact, `:unsplit` multiplies a split skill's contact by its hit
  count, `:ordinary` divides like any other hit.
  """
  @type plant :: :emperium | :unsplit | :ordinary

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
    - `:force_crit` - the hit is a critical. The critical is decided by the
      attack before its hit roll (it always hits), so the calculator never
      rolls one; without `:force_crit` the hit is not critical.
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
    - `:refine_atk` - with `:base_damage`, a classic player's refine bonus,
      added after DEF unless the skill takes no refine bonus. Default `0`.

  Player weapon hits use the active physical-attack component pipeline, including
  mode-specific ratio, element and cardfix ordering. Non-player hits and explicit
  `:base_damage` replacements retain the shared scalar modifier pipeline.
  """
  @spec calculate_damage(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage(attacker, defender, opts) do
    attacker
    |> calculate_damage_with(defender, opts, :primary, :normal)
    |> with_misc_part(attacker, defender, opts)
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

  @doc """
  Calculates Stave Crasher's hit from the coordinator's single MATK roll.

  `opts` must carry that roll as `:matk`, a non-negative integer, and otherwise
  takes the `calculate_damage/3` options. A renewal player adds it to the weapon
  component after the equipment percentage part and before the weapon cards; an
  ordinary renewal non-player hit does not use it. In classic it replaces the
  weapon roll: base ATK, overrefine, status weapon ATK and status ATK rate drop
  out, while size, the non-critical rate, refine, mastery, defense, cards and
  both attribute steps remain, and Maximize Power raises the roll to the band's
  maximum. Returns `{:error, :invalid_matk}` without a valid roll.
  """
  @spec calculate_stave_crasher_damage(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_stave_crasher_damage(attacker, defender, opts) do
    case Keyword.pop(opts, :matk) do
      {matk, opts} when is_integer(matk) and matk >= 0 ->
        stave_crasher_damage(attacker, defender, opts, maximized_matk(attacker, matk))

      _invalid ->
        {:error, :invalid_matk}
    end
  end

  # Classic Maximize Power raises the MATK band's minimum to its maximum, as it
  # does the weapon band; renewal's insertion rolls the band regardless.
  defp maximized_matk(%{combat_stats: %{max_weapon_damage: true, matk_max: max}}, matk) do
    if GameMode.mode() == :pre_renewal, do: max, else: matk
  end

  defp maximized_matk(_attacker, matk), do: matk

  @doc """
  Calculates the damage a weapon attack still deals after the target fled it.

  In classic a fled weapon attack skips its hit block but still runs the rest
  of the weapon recipe on zero damage. That covers the bonuses that follow the
  attribute step (Star Crumb, spirit spheres, Envenom's flat ATK and its
  attribute step), the Magnum Break share (its normal-attack base is zero), the
  0 cap, Weapon Research and Hilt Binding, and both sides' cards. The caller
  repeats the result over the attack's divisions. It delivers a total of at
  least 1 as a connected hit and anything less as the miss. A dual wielder's
  normal attack also returns its left hand's `:left_components` for
  `calculate_secondary_hand_damage/3`. Renewal keeps these bonuses inside the
  hit block, so a fled renewal attack deals 0. Takes the `calculate_damage/3`
  options; the result is never critical.
  """
  @spec calculate_fled_damage(combatant(), combatant(), keyword()) :: {:ok, damage_result()}
  def calculate_fled_damage(attacker, defender, opts) do
    fled =
      if classic?(),
        do: {:ok, classic_fled_damage(select_weapon_hand(attacker, :primary), defender, opts)},
        else: {:ok, %{damage: 0, is_critical: false}}

    with_misc_part(fled, attacker, defender, opts)
  end

  # Classic Soul Destroyer's INT part (`:misc_part`, the skill's base): the misc
  # tail with the hit's range and no element step, carried beside the weapon
  # damage for the target's own settlement. It never rolls flee.
  defp with_misc_part({:ok, result}, attacker, defender, opts) do
    case Keyword.get(opts, :misc_part) do
      base when is_integer(base) ->
        range = if Keyword.get(opts, :ranged, false), do: :long, else: :short

        {:ok, %{damage: misc}} =
          MiscDamageCalculator.calculate_misc_damage(attacker, defender,
            skill_id: Keyword.fetch!(opts, :skill_id),
            attack_flag: BattleFlags.build(:misc, range, true),
            base_damage: base,
            ignore_element: true
          )

        {:ok, Map.put(result, :misc_part, misc)}

      nil ->
        {:ok, result}
    end
  end

  defp with_misc_part(error, _attacker, _defender, _opts), do: error

  # Neither hand has damage, so the attribute step itself is skipped; the Magnum
  # Break share's zero base still takes its element.
  defp classic_fled_damage(attacker, defender, opts) do
    hit = %{
      attacker: attacker,
      defender: defender,
      opts: opts,
      critical: %{damage: 0, is_critical: false},
      modifiers: attacker_status_modifiers(attacker)
    }

    element = hit_element(attacker, hit.modifiers, opts)
    left = fled_left_stage(hit, element)

    damage =
      0
      |> classic_after_element(hit, element, :right_hand)
      |> classic_edp(hit, fn -> left || 0 end)
      |> classic_watk(hit, %{left: fn -> left || 0 end, base: fn -> 0 end})
      |> max(0)
      |> Kernel.+(classic_late_atk(hit))
      |> fled_cards(hit, element)

    result = %{damage: damage, is_critical: false}

    if is_integer(left) and dual_wield?(attacker),
      do: Map.put(result, :left_components, max(left, 0)),
      else: result
  end

  # A normal attack's left hand (a dual wield's weapon or a katar's empty hand)
  # takes its own Star Crumb and the spirit spheres too; a skill never uses it.
  defp fled_left_stage(hit, element) do
    with nil <- Keyword.get(hit.opts, :skill_id),
         %{} <- left_hand_attacker(hit.attacker) do
      classic_after_element(0, hit, element, :left_hand)
    else
      _no_left_hand -> nil
    end
  end

  # Cards only scale damage there is. A player's hit takes its own attack cards
  # and the target's cards; any other attacker's takes only the target's.
  defp fled_cards(0, _hit, _element), do: 0

  defp fled_cards(damage, %{attacker: %{unit_type: :player}} = hit, _element) do
    context =
      player_damage_context(
        hit.attacker,
        hit.defender,
        hit.opts,
        :primary,
        :normal,
        %{source: :weapon},
        hit.critical
      )

    PreRenewalAttack.post_element(damage, context)
  end

  defp fled_cards(damage, hit, element), do: scalar_target_cards(damage, hit, element)

  defp stave_crasher_damage(%{unit_type: :player} = attacker, defender, opts, matk) do
    opts = Keyword.put(opts, :stave_matk, matk)
    calculate_damage_with(attacker, defender, opts, :primary, :normal)
  end

  defp stave_crasher_damage(attacker, defender, opts, matk) do
    case GameMode.mode() do
      :renewal ->
        calculate_damage(attacker, defender, opts)

      :pre_renewal ->
        calculate_damage(attacker, defender, opts ++ [base_damage: matk, skip_status_atk: true])
    end
  end

  defp calculate_damage_with(attacker, defender, opts, attack_path, defense_mode) do
    cond do
      infinite_defense_hit?(attacker, defender, opts) ->
        plant_contact(select_weapon_hand(attacker, attack_path), defender, opts, attack_path)

      fixed_damage = Keyword.get(opts, :fixed_damage) ->
        {:ok, %{damage: fixed_damage, is_critical: false}}

      true ->
        calculate_pipeline_damage(attacker, defender, opts, attack_path, defense_mode)
    end
  end

  defp calculate_pipeline_damage(attacker, defender, opts, attack_path, defense_mode) do
    attacker = select_weapon_hand(attacker, attack_path)

    if attacker.unit_type == :player and not Keyword.has_key?(opts, :base_damage),
      do: calculate_player_pipeline_damage(attacker, defender, opts, attack_path, defense_mode),
      else:
        calculate_ordinary_pipeline_damage(attacker, defender, opts, attack_path, defense_mode)
  end

  # The scalar recipe of non-player hits and of player hits with a replaced base:
  # modifiers and DEF, the post-defense minimum, the attribute step, the critical
  # tail and then the target's cards (battle.cpp:5625-5758). The critical is
  # decided first: it sets a non-player's base to its maximum and, in classic,
  # skips DEF. A classic player's hit takes its refine and masteries after DEF
  # and its attack cards only after the attribute step, Weapon Research and Hilt
  # Binding.
  defp calculate_ordinary_pipeline_damage(
         attacker,
         defender,
         opts,
         attack_path,
         defense_mode
       ) do
    critical? = critical_decision(opts)
    defense_mode = if critical? and classic?(), do: :ignore, else: defense_mode
    skill_ratio = Keyword.get(opts, :skill_ratio, 100)
    bonus_atk = Keyword.get(opts, :bonus_atk, 0)
    modifiers = attacker_status_modifiers(attacker)
    classic_player? = classic?() and attacker.unit_type == :player
    {ratio, atk_percent} = scalar_ratio(skill_ratio, attacker, opts, modifiers)

    with {:ok, base_atk} <- calculate_base_attack(attacker, opts),
         base_atk = classic_scalar_critical_defense(base_atk, defender, opts, critical?),
         patk_atk = apply_patk_multiplier(base_atk, attacker),
         skilled_atk = div(patk_atk * ratio, 100) + bonus_atk,
         modified_atk =
           apply_attack_modifiers(
             skilled_atk,
             attacker,
             defender,
             opts,
             attack_path,
             modifiers,
             atk_percent
           ),
         total_atk = modified_atk + scalar_banes(attacker, defender, classic_player?),
         total_atk = apply_res_reduction(total_atk, defender),
         {:ok, defended} <-
           scalar_defense_stage(
             total_atk,
             defender,
             attacker,
             attack_path,
             ratio_scaled_mode(defense_mode, skill_ratio)
           ) do
      hit = %{
        attacker: attacker,
        defender: defender,
        opts: opts,
        modifiers: modifiers,
        critical?: critical?
      }

      taken =
        defended
        |> scalar_post_defense(hit, classic_player?, total_atk)
        |> renewal_skill_rates(hit)
        |> scalar_element(hit)
        |> classic_player_cards(hit, attack_path, classic_player?)
        |> scalar_critical(hit, critical?)
        |> scalar_target_cards(hit, hit_element(attacker, modifiers, opts))

      {:ok, %{damage: taken, is_critical: critical?}}
    end
  end

  # The scalar hit's skill ratio and the ATK percent left for the modifier stage:
  # classic scales by the ratio with its status adds and multiplies by the
  # percent after; renewal starts the ratio from the percent and multiplies by
  # nothing after.
  defp scalar_ratio(skill_ratio, attacker, opts, modifiers) do
    skill_id = Keyword.get(opts, :skill_id)
    adds = status_skill_ratio(modifiers, skill_id)
    delta = atk_percent_delta(attacker.unit_type, skill_id, modifiers)

    if classic?(),
      do: {skill_ratio + adds, 100 + delta},
      else: {skill_ratio + adds + delta, 100}
  end

  # The banes are a classic player's post-defense masteries; every other hit adds
  # them before DEF.
  defp scalar_banes(_attacker, _defender, true), do: 0

  defp scalar_banes(attacker, defender, false),
    do: demon_bane_bonus(attacker, defender) + beast_bane_bonus(attacker, defender)

  # DEF and the post-defense stage run only for an attack with damage before
  # them; one with nothing stays at 0.
  defp scalar_defense_stage(0, _defender, _attacker, _attack_path, _mode), do: {:ok, 0}

  defp scalar_defense_stage(total_atk, defender, attacker, attack_path, mode),
    do: scalar_defense(total_atk, defender, attacker, attack_path, mode)

  defp scalar_post_defense(damage, _hit, _classic_player?, 0), do: damage

  defp scalar_post_defense(damage, hit, classic_player?, _total_atk),
    do: scalar_post_defense(damage, hit, classic_player?)

  # A classic player's post-defense stage: the refine bonus, the minimum of 1, the
  # weapon masteries and the post-defense status ATK, each where the skill takes
  # it. Every other hit adds the post-defense status ATK of whatever holds it, a
  # classic one after a minimum of 1, and keeps a minimum of 1.
  defp scalar_post_defense(damage, hit, true) do
    skill_id = Keyword.get(hit.opts, :skill_id)

    refine =
      if AtkPercent.stacks_masteries?(skill_id, :refine),
        do: Keyword.get(hit.opts, :refine_atk, 0),
        else: 0

    mastery =
      if AtkPercent.stacks_masteries?(skill_id, :all),
        do: hand_mastery_atk(hit.attacker, hit.defender),
        else: 0

    max(damage + refine, 1) + mastery + post_defense_atk(hit.modifiers, skill_id)
  end

  defp scalar_post_defense(damage, hit, false) do
    status_atk = post_defense_atk(hit.modifiers, Keyword.get(hit.opts, :skill_id))

    if classic?(),
      do: max(damage, 1) + status_atk,
      else: max(damage + status_atk, 1)
  end

  defp classic_player_cards(damage, hit, attack_path, true) do
    cards = attacker_cards(hit.attacker, hit.defender, hit.opts, attack_path, hit.modifiers)
    PhysicalAttack.attacker_cardfix(damage + classic_late_atk(hit), cards)
  end

  defp classic_player_cards(damage, _hit, _attack_path, false), do: damage

  defp post_defense_atk(modifiers, skill_id) do
    if skill_id in Map.get(modifiers, :post_defense_atk_excludes, []),
      do: 0,
      else: Map.get(modifiers, :post_defense_atk, 0)
  end

  # Renewal multiplies a critical after the attribute step, then takes the
  # target's equipment critical reduction; classic has no critical multiplier
  # on this recipe.
  defp scalar_critical(damage, hit, true) do
    if classic?(),
      do: damage,
      else:
        damage
        |> Critical.multiply(Map.get(hit.attacker.combat_stats, :crate, 0))
        |> PhysicalAttack.add_rate(-crit_def_rate(hit.defender))
  end

  defp scalar_critical(damage, _hit, false), do: damage

  # Classic takes the target's equipment critical reduction on a critical
  # normal attack's base, before the ratio and every modifier.
  defp classic_scalar_critical_defense(base_atk, defender, opts, true) do
    if classic?() and is_nil(Keyword.get(opts, :skill_id)),
      do: PhysicalAttack.add_rate(base_atk, -crit_def_rate(defender)),
      else: base_atk
  end

  defp classic_scalar_critical_defense(base_atk, _defender, _opts, false), do: base_atk

  # Only a player target's equipment reduces criticals.
  defp crit_def_rate(%{unit_type: :player} = defender),
    do: EquipmentBonuses.crit_def_rate(defender)

  defp crit_def_rate(_defender), do: 0

  defp classic?, do: GameMode.mode() == :pre_renewal

  # The attack decides its critical before the hit roll and passes it as
  # `:force_crit`.
  defp critical_decision(opts), do: Keyword.get(opts, :force_crit, false)

  # Non-player basic attacks take no attribute step (`attack_attr_none`); renewal
  # players take one only in the Sacrifice group; other hits take their element,
  # and a classic player's hit may gain the Magnum Break share.
  defp scalar_element(damage, %{attacker: attacker, opts: opts} = hit) do
    player? = attacker.unit_type == :player
    element = hit_element(attacker, hit.modifiers, opts)

    cond do
      not player? and is_nil(Keyword.get(opts, :skill_id)) ->
        damage

      player? and GameMode.mode() == :renewal ->
        post_defense_element(damage, hit, element, sacrifice_group?(opts))

      player? ->
        damage
        |> attribute_steps(hit, element, true)
        |> classic_after_element(hit, element, :right_hand)
        |> classic_edp(hit, fn -> scalar_watk_input(hit).left.() end)
        |> classic_watk(hit, scalar_watk_input(hit))
        |> max(0)

      true ->
        post_defense_element(damage, hit, element, true)
    end
  end

  # A replaced-base hit has no weapon parts of its own; the Magnum Break share
  # builds the player's normal-attack inputs when it needs them.
  defp scalar_watk_input(hit) do
    player_hit = %{
      attacker: hit.attacker,
      defender: hit.defender,
      opts: hit.opts,
      attack_path: :primary,
      defense_mode: :normal,
      critical: %{damage: 0, is_critical: Map.get(hit, :critical?, false)},
      modifiers: hit.modifiers
    }

    parts = player_parts(%{player_hit | opts: []}, hit.attacker, :primary)
    context = hand_context(player_hit, hit.attacker, :primary, parts)
    normal_attack = {parts, normal_attack_context(context, hit.attacker, hit.defender)}

    %{
      left: fn -> classic_damage2(player_hit, nil, elem(normal_attack, 1)) end,
      base: fn -> classic_watk_base(player_hit, normal_attack) end
    }
  end

  defp ratio_scaled_mode(:soft_only, skill_ratio), do: {:soft_only, skill_ratio}
  defp ratio_scaled_mode(mode, _skill_ratio), do: mode

  # The modifier pipeline yields a float; every defense path truncates it on the
  # way out, so the DEF-ignoring path must too or a float reaches the HP pools.
  defp scalar_defense(damage, _defender, _attacker, _path, :ignore),
    do: {:ok, trunc(damage)}

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
    do: defended_damage(damage, defender, attacker)

  defp calculate_player_pipeline_damage(attacker, defender, opts, attack_path, defense_mode) do
    hit = %{
      attacker: attacker,
      defender: defender,
      opts: opts,
      attack_path: attack_path,
      defense_mode: defense_mode,
      critical: %{damage: 0, is_critical: critical_decision(opts)},
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

  defp player_parts(hit, attacker, attack_path) do
    parts =
      DamageInputs.player_attack_parts(
        attacker,
        hit.opts,
        attack_path,
        hit.critical.is_critical and Keyword.get(hit.opts, :critical_max_weapon, true)
      )

    cond do
      parts.source == :shield ->
        parts

      classic?() ->
        classic_parts(parts, hit, attacker, attack_path)

      true ->
        %{parts | mastery_atk: renewal_mastery_atk(hit, attacker, attack_path)}
    end
  end

  # A renewal hand's mastery ATK, only for a skill that stacks masteries: its
  # weapon masteries with the banes, Envenom, Hilt Binding, its own Star Crumb,
  # the spirit spheres and the statuses counted as masteries.
  defp renewal_mastery_atk(hit, attacker, attack_path) do
    if AtkPercent.stacks_masteries?(Keyword.get(hit.opts, :skill_id), :all) do
      hand = if attack_path == :secondary, do: :left_hand, else: :right_hand

      hand_mastery_atk(attacker, hit.defender, attack_path) + renewal_envenom_atk(hit.opts) +
        hilt_binding_atk(attacker, hit.opts) + star_atk(attacker, hand) +
        spirit_sphere_atk(attacker, hit.opts) + Map.get(hit.modifiers, :mastery_atk, 0)
    else
      0
    end
  end

  # A classic hand's post-defense bonuses: its refine bonus and its own weapon
  # masteries with the banes, each only for a skill that stacks it.
  defp classic_parts(parts, hit, attacker, attack_path) do
    skill_id = Keyword.get(hit.opts, :skill_id)

    %{
      parts
      | mastery_atk:
          if(AtkPercent.stacks_masteries?(skill_id, :all),
            do: hand_mastery_atk(attacker, hit.defender, attack_path),
            else: 0
          ),
        refine_atk:
          if(AtkPercent.stacks_masteries?(skill_id, :refine), do: parts.refine_atk, else: 0)
    }
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

  # Classic runs one attribute step on each hand's post-defense damage. A
  # dual-wield normal attack calculates its left hand here too, after the right
  # hand's step and before the Magnum Break share, and hands the result to the
  # second hand's call.
  defp classic_player_damage(%{attack_path: :secondary} = hit) do
    parts = player_parts(hit, hit.attacker, :secondary)
    context = hand_context(hit, hit.attacker, :secondary, parts)

    staged =
      case Keyword.fetch(hit.opts, :left_components) do
        {:ok, staged} -> staged
        :error -> parts |> classic_hand_stage(context, hit, hit.attacker) |> max(0)
      end

    damage = PreRenewalAttack.post_element(staged + classic_late_atk(hit), context)
    {:ok, %{hit.critical | damage: damage}}
  end

  defp classic_player_damage(hit) do
    parts = player_parts(hit, hit.attacker, hit.attack_path)
    context = hand_context(hit, hit.attacker, hit.attack_path, parts)

    {stave_parts, stave_context} =
      classic_stave_base(parts, context, Keyword.get(hit.opts, :stave_matk))

    right = classic_hand_stage(stave_parts, stave_context, hit, hit.attacker)
    left = classic_left_stage(hit)

    watk_input = %{
      left: fn -> classic_damage2(hit, left, context) end,
      base: fn -> classic_watk_base(hit, normal_attack_inputs(hit, parts, context)) end
    }

    damage =
      right
      |> classic_edp(hit, watk_input.left)
      |> classic_watk(hit, watk_input)
      |> max(0)
      |> Kernel.+(classic_late_atk(hit))
      |> PreRenewalAttack.post_element(context)

    result = %{hit.critical | damage: damage}

    {:ok,
     if(is_integer(left) and dual_wield?(hit.attacker),
       do: Map.put(result, :left_components, max(left, 0)),
       else: result
     )}
  end

  # One classic hand up to its attribute steps and the bonuses that follow them,
  # before the 0 cap.
  defp classic_hand_stage(parts, context, hit, attacker) do
    element = hit_element(attacker, hit.modifiers, hit.opts)

    parts
    |> PreRenewalAttack.pre_element(context)
    |> attribute_steps(hit, element, true)
    |> classic_after_element(hit, element, parts.hand)
  end

  # Classic adds a player's Star Crumb and spirit sphere ATK after the attribute
  # step, even to a hit the step nullified, then Envenom's flat ATK, which takes
  # the element once more together with them. Renewal has none of these here.
  defp classic_after_element(damage, hit, element, hand) do
    if classic?() do
      skill_id = Keyword.get(hit.opts, :skill_id)

      damage
      |> Kernel.+(
        if AtkPercent.stacks_masteries?(skill_id, :star),
          do: star_atk(hit.attacker, hand),
          else: 0
      )
      |> Kernel.+(
        if AtkPercent.stacks_masteries?(skill_id, :all), do: player_sphere_atk(hit), else: 0
      )
      |> classic_envenom(element, hit)
    else
      damage
    end
  end

  defp star_atk(%{unit_type: :player} = attacker, :left_hand),
    do: Map.get(physical_snapshot(attacker), :left_star_atk, 0)

  defp star_atk(%{unit_type: :player} = attacker, _hand), do: classic_star_atk(attacker)
  defp star_atk(_attacker, _hand), do: 0

  defp player_sphere_atk(%{attacker: %{unit_type: :player} = attacker, opts: opts}),
    do: spirit_sphere_atk(attacker, opts)

  defp player_sphere_atk(_hit), do: 0

  # Weapon Research and Hilt Binding join every classic player weapon hit after
  # the 0 cap, before the attacker's cards.
  defp classic_late_atk(%{attacker: %{unit_type: :player} = attacker, opts: opts}),
    do:
      Map.get(physical_snapshot(attacker), :weapon_research_atk, 0) +
        hilt_binding_atk(attacker, opts)

  defp classic_late_atk(_hit), do: 0

  # A classic normal attack's left hand reaches the attribute step too: a
  # dual-wield left weapon, or a katar's empty left hand (no weapon ATK). Skills
  # never use it.
  defp classic_left_stage(hit) do
    with nil <- Keyword.get(hit.opts, :skill_id),
         %{} = attacker <- left_hand_attacker(hit.attacker) do
      classic_left_hand_stage(hit, attacker)
    else
      _no_left_hand -> nil
    end
  end

  # The attacker with a left hand where a normal attack has one: its own left
  # weapon, or a katar's empty left hand (no weapon ATK, neutral). `nil` without.
  defp left_hand_attacker(attacker) do
    cond do
      dual_wield?(attacker) -> attacker
      katar?(attacker) -> %{attacker | left_hand: empty_left_hand(attacker)}
      true -> nil
    end
  end

  defp classic_left_hand_stage(hit, attacker) do
    secondary = select_weapon_hand(attacker, :secondary)
    parts = player_parts(hit, secondary, :secondary)
    context = hand_context(hit, secondary, :secondary, parts)
    classic_hand_stage(parts, context, hit, secondary)
  end

  # Renewal's weapon element property rate, which Meteor Assault never takes.
  defp watk_element_rate(_modifiers, @meteor_assault), do: 0
  defp watk_element_rate(modifiers, _skill_id), do: Map.get(modifiers, :watk_element_rate, 0)

  # Advanced Katar Mastery's percent for a player wielding a katar.
  defp katar_atk_rate(%{unit_type: :player} = attacker) do
    if katar?(attacker), do: AscKatar.damage_rate(attacker.advanced_katar_level), else: 0
  end

  defp katar_atk_rate(_attacker), do: 0

  defp katar?(%{right_hand: %WeaponHand{subtype: :katar}}), do: true
  defp katar?(_attacker), do: false

  defp empty_left_hand(%{right_hand: %WeaponHand{} = katar}) do
    %{katar | element: :neutral, base_atk: 0, refine_atk: 0, overrefine_band: 0, slot: :left_hand}
  end

  # The left hand's damage where classic Magnum Break checks it: on a normal
  # attack the left hand's own attribute-stage damage, on a skill the left hand's
  # untouched normal-attack base; 0 for an attacker that has no left hand.
  defp classic_damage2(_hit, left, _context) when is_integer(left), do: left

  defp classic_damage2(hit, nil, context) do
    with false <- is_nil(Keyword.get(hit.opts, :skill_id)),
         %{} = attacker <- left_hand_attacker(hit.attacker) do
      left_normal_base(hit, attacker, context)
    else
      _no_left_hand -> 0
    end
  end

  defp left_normal_base(hit, attacker, context) do
    secondary = select_weapon_hand(attacker, :secondary)
    parts = player_parts(%{hit | opts: []}, secondary, :secondary)
    PreRenewalAttack.normal_base(parts, normal_attack_context(context, secondary, hit.defender))
  end

  # A normal attack's context: no skill size override, no skill exemption from
  # the non-critical equipment rate, and the ATK percent a normal attack takes.
  defp normal_attack_context(context, attacker, defender) do
    %{
      context
      | size_rate: trunc(apply_size_modifier(100, attacker, defender, [])),
        ignore_noncrit_atk_bonus: false,
        atk_rate: AtkPercent.delta(:player, nil, attacker_status_modifiers(attacker))
    }
  end

  # The ATK percent's points over 100. Renewal's Sacrifice skips every status
  # ratio stage, the percent included; classic applies the percent after the
  # ratio regardless.
  defp atk_percent_delta(unit_type, skill_id, modifiers) do
    if skill_id == @sacrifice and not classic?(),
      do: 0,
      else: AtkPercent.delta(unit_type, skill_id, modifiers)
  end

  # The status adds to the skill ratio (Over Thrust, Frenzy), which Sacrifice skips.
  defp status_skill_ratio(_modifiers, @sacrifice), do: 0
  defp status_skill_ratio(modifiers, _skill_id), do: Map.get(modifiers, :skill_ratio, 0)

  defp classic_edp(damage, hit, left \\ fn -> 0 end) do
    with :pre_renewal <- GameMode.mode(),
         false <- Keyword.get(hit.opts, :ignore_element, false),
         false <- ignore_atk_card?(Keyword.get(hit.opts, :skill_id)),
         %{val3: rate} <- held_edp(hit.attacker),
         true <- damage > 0 or left.() > 0 do
      damage + div(damage * rate, 100)
    else
      _ineligible -> damage
    end
  end

  defp held_edp(attacker),
    do: StatusStorage.get_status(attacker.unit_type, attacker.unit_id, :sc_edp)

  # Classic Magnum Break (SC_WATK_ELEMENT): a player's hit, unless it ignores
  # elements or attack cards, gains `val2` percent of its normal-attack base taken
  # as the status element, plus the right weapon's Star Crumb bonus and the
  # spirit sphere bonus, when either hand still has positive damage after the
  # attribute step.
  defp classic_watk(damage, hit, input) do
    with {element, percent} <- classic_watk_status(hit),
         true <- damage > 0 or input.left.() > 0 do
      base =
        element_step(input.base.(), element, hit, allow_negative: true) +
          classic_star_atk(hit.attacker) + spirit_sphere_atk(hit.attacker, hit.opts)

      damage + div(base * percent, 100)
    else
      _no_share -> damage
    end
  end

  defp classic_watk_status(%{attacker: %{unit_type: :player}} = hit) do
    if GameMode.mode() == :pre_renewal and not Keyword.get(hit.opts, :ignore_element, false) and
         not ignore_atk_card?(Keyword.get(hit.opts, :skill_id)) do
      Enum.find_value(hit.modifiers, fn
        {{:pseudo_element_atk, element}, percent} when is_integer(percent) -> {element, percent}
        _modifier -> nil
      end)
    end
  end

  defp classic_watk_status(_hit), do: nil

  defp ignore_atk_card?(nil), do: false

  defp ignore_atk_card?(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> definition.ignore_atk_card
      :error -> false
    end
  end

  # The normal attack behind the Magnum Break share: a normal attack is its own,
  # a skill rolls a fresh one (critical when the skill hit is).
  defp normal_attack_inputs(hit, parts, context) do
    if is_nil(Keyword.get(hit.opts, :skill_id)) do
      {parts, context}
    else
      {player_parts(%{hit | opts: []}, hit.attacker, :primary),
       normal_attack_context(context, hit.attacker, hit.defender)}
    end
  end

  defp classic_watk_base(hit, {parts, context}) do
    PreRenewalAttack.magnum_break_base(PreRenewalAttack.normal_base(parts, context), context, %{
      refine_atk: parts.refine_atk,
      mastery_atk: hand_mastery_atk(hit.attacker, hit.defender)
    })
  end

  # Hilt Binding's ATK, which Cart Revolution never takes.
  defp hilt_binding_atk(attacker, opts) do
    if Keyword.get(opts, :skill_id) == @cart_revolution,
      do: 0,
      else: Map.get(physical_snapshot(attacker), :hilt_binding_atk, 0)
  end

  # battle_addmastery: the hand's weapon masteries (the left hand's for its own
  # weapon type) plus the banes.
  defp hand_mastery_atk(attacker, defender, attack_path \\ :primary) do
    key = if attack_path == :secondary, do: :left_weapon_mastery_atk, else: :weapon_mastery_atk

    Map.get(physical_snapshot(attacker), key, 0) +
      demon_bane_bonus(attacker, defender) + beast_bane_bonus(attacker, defender)
  end

  defp classic_star_atk(attacker),
    do: Map.get(physical_snapshot(attacker), :star_atk, 0)

  defp physical_snapshot(attacker), do: Map.get(attacker.combat_stats, :physical_attack) || %{}

  # Three per spirit sphere: by default the spheres held, or the count the skill
  # passes for its own sphere use.
  defp spirit_sphere_atk(attacker, opts),
    do: 3 * Keyword.get(opts, :spirit_spheres, Map.get(attacker, :spirit_spheres, 0))

  # Classic Stave Crasher's base is the MATK roll in place of the weapon roll,
  # sized like it; base ATK and overrefine do not apply to it, the status weapon
  # ATK lives in the weapon roll it replaces, and the ATK percent still scales
  # the skill-scaled damage as it does every weapon attack.
  defp classic_stave_base(parts, context, nil), do: {parts, context}

  defp classic_stave_base(parts, context, matk) do
    {%{parts | weapon_atk: matk, status_atk: 0, flat_atk: 0, overrefine_atk: 0},
     %{context | flat_bonus: 0}}
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

  # battle_calc_element_damage: the post-defense attribute recipe, then the 0 cap
  # (`attribute_recover: no`).
  defp post_defense_element(damage, hit, element, primary?) do
    damage
    |> attribute_steps(hit, element, primary?)
    |> classic_after_element(hit, element, :right_hand)
    |> classic_edp(hit)
    |> max(0)
  end

  # The attribute steps of battle_calc_element_damage. `primary?` says whether the
  # hit's own element applies here (classic and non-player hits, and the
  # Sacrifice group); the forced-neutral skills then take a neutral step. A hit
  # that ignores elements or has no damage left takes none.
  defp attribute_steps(damage, hit, element, primary?) do
    if Keyword.get(hit.opts, :ignore_element, false) or damage <= 0 do
      damage
    else
      damage =
        if primary?, do: element_step(damage, element, hit, allow_negative: true), else: damage

      if Keyword.get(hit.opts, :skill_id) in forced_neutral_skills(),
        do: element_step(damage, :neutral, hit, allow_negative: true),
        else: damage
    end
  end

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
        endow = DamageShared.endow_element(modifiers)
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
    ModifierCalculator.get_battle_modifiers(unit_type, unit_id)
  end

  defp player_damage_context(attacker, defender, opts, attack_path, defense_mode, parts, critical) do
    {attacker_type, attacker_id} = get_unit_type_and_id(attacker)
    {defender_type, defender_id} = get_unit_type_and_id(defender)
    attacker_modifiers = ModifierCalculator.get_battle_modifiers(attacker_type, attacker_id)
    defender_modifiers = ModifierCalculator.get_battle_modifiers(defender_type, defender_id)
    element = Keyword.get(opts, :element) || resolve_attack_element(attacker, attacker_modifiers)
    skill_id = Keyword.get(opts, :skill_id)

    elements =
      if attack_path == :secondary,
        do: Enum.uniq([right_attack_element(attacker, attacker_modifiers, opts), element]),
        else: [element]

    %{
      size_rate:
        if(parts.source == :shield,
          do: 100,
          else: trunc(apply_size_modifier(100, attacker, defender, opts))
        ),
      attacker_cards: attacker_cards(attacker, defender, opts, attack_path, attacker_modifiers),
      defender_cards: defender_cards(defender, attacker, opts, elements),
      defense:
        player_defense_context(defender, attacker, attack_path, defense_mode, defender_modifiers),
      defense_mode:
        if(defense_mode in [:simple, :ignore, :soft_only], do: defense_mode, else: :normal),
      skill_id: skill_id,
      skill_ratio: Keyword.get(opts, :skill_ratio, 100),
      base_atk_rate: Keyword.get(opts, :base_atk_rate, 100),
      bonus_atk: Keyword.get(opts, :bonus_atk, 0),
      post_defense_atk: post_defense_atk(attacker_modifiers, skill_id),
      skill_atk_rate: EquipmentBonuses.skill_atk_rate(attacker, skill_id),
      skill_taken_rate: EquipmentBonuses.sub_skill_rate(defender, skill_id),
      flat_bonus:
        Map.get(attacker_modifiers, :damage_bonus, 0) + Map.get(attacker_modifiers, :atk_bonus, 0),
      atk_rate: atk_percent_delta(attacker_type, skill_id, attacker_modifiers),
      status_skill_ratio: status_skill_ratio(attacker_modifiers, skill_id),
      damage_multiplier: Map.get(attacker_modifiers, :damage_multiplier, 0),
      equipment_atk_rate: EquipmentBonuses.percent_atk_rate(attacker, attacker_modifiers),
      katar_atk_rate: katar_atk_rate(attacker),
      watk_element_rate: watk_element_rate(attacker_modifiers, skill_id),
      edp_level:
        case held_edp(attacker) do
          %{val1: level} -> level
          nil -> 0
        end,
      stave_matk: Keyword.get(opts, :stave_matk, 0),
      patk: Map.get(attacker.combat_stats, :patk, 0),
      res: Map.get(defender.combat_stats, :res, 0),
      critical?: critical.is_critical,
      crate: Map.get(attacker.combat_stats, :crate, 0),
      crit_def_rate: crit_def_rate(defender),
      crit_atk_rate:
        Map.get(attacker.equip_modifiers, :crit_atk_rate, 0) +
          Map.get(attacker_modifiers, :crit_atk_rate, 0),
      non_crit_atk_rate: EquipmentBonuses.non_crit_atk_rate(attacker),
      ignore_noncrit_atk_bonus: ignore_noncrit_atk_bonus?(skill_id)
    }
    |> Map.merge(range_rates(attacker, opts))
  end

  # The equipment short- or long-attack rate the hit's range selects.
  defp range_rates(attacker, opts) do
    if ranged_hit?(attacker, opts),
      do: %{
        short_atk_rate: 0,
        long_atk_rate: Map.get(attacker.equip_modifiers, :long_atk_rate, 0)
      },
      else: %{
        short_atk_rate: Map.get(attacker.equip_modifiers, :short_atk_rate, 0),
        long_atk_rate: 0
      }
  end

  # A skill absent from the catalog cannot carry the flag, so its hit stays
  # eligible, as does an ordinary swing.
  defp ignore_noncrit_atk_bonus?(nil), do: false

  defp ignore_noncrit_atk_bonus?(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> definition.ignore_noncrit_atk_bonus
      :error -> false
    end
  end

  # The attacker's cards for one hand of a physical hit: none for a non-player or
  # a hit that ignores them (IgnoreAtkCard), the left hand's own per-monster
  # bonus for a left-hand hit, both hands' bonuses for the right hand. Classic
  # adds the hit's range rate to the product.
  defp attacker_cards(%{unit_type: :player} = attacker, defender, opts, attack_path, modifiers) do
    skill_id = Keyword.get(opts, :skill_id)

    if attack_path == :ignore_attacker_cards or ignore_atk_card?(skill_id) do
      []
    else
      hand = if attack_path == :secondary, do: :left_hand, else: :right_hand

      EquipmentBonuses.physical_attack_cardfix(attacker, defender, hand, %{
        arrow?: arrow_attack?(attacker, skill_id),
        ranged?: ranged_hit?(attacker, opts),
        range_rates?: classic?(),
        attacker_modifiers: modifiers,
        katar_rate: if(classic?(), do: katar_atk_rate(attacker), else: 0)
      })
    end
  end

  defp attacker_cards(_attacker, _defender, _opts, _attack_path, _modifiers), do: []

  # An arrow attack is a bow or gun normal attack, or a skill that uses
  # ammunition: its definition declares an ammo type, so the equipped stack is
  # the ammunition the cast fired.
  defp arrow_attack?(attacker, nil),
    do: attacker.weapon |> Map.get(:type) |> WeaponTypes.requires_ammo?()

  defp arrow_attack?(_attacker, skill_id),
    do: match?({:ok, %{require_ammo: [_ | _]}}, Catalog.by_id(skill_id))

  # The target's cards against a physical hit, only for a player target:
  # `weapon` with the element resists of `elements` (the right hand's attack
  # element, then a left-hand hit's own when it differs), `status` without them.
  defp defender_cards(%{unit_type: :player} = defender, attacker, opts, elements) do
    {unit_type, unit_id} = get_unit_type_and_id(defender)
    ranged? = ranged_hit?(attacker, opts)

    cards = %{
      elements: elements,
      ignore_element?: false,
      status_modifiers: ModifierCalculator.get_battle_modifiers(unit_type, unit_id),
      attack_flag:
        BattleFlags.build(
          :weapon,
          if(ranged?, do: :long, else: :short),
          not is_nil(Keyword.get(opts, :skill_id))
        ),
      ranged?: ranged?
    }

    %{
      weapon: EquipmentBonuses.physical_defense_cardfix(defender, attacker, cards),
      status:
        EquipmentBonuses.physical_defense_cardfix(defender, attacker, %{
          cards
          | ignore_element?: true
        })
    }
  end

  defp defender_cards(_defender, _attacker, _opts, _elements), do: nil

  # The right hand's attack element for a left-hand hit's target cards: the
  # skill's element, an endow, or the right weapon's own.
  defp right_attack_element(attacker, modifiers, opts) do
    Keyword.get(opts, :element) || DamageShared.endow_element(modifiers) ||
      right_weapon_element(attacker)
  end

  defp right_weapon_element(%{right_hand: %WeaponHand{element: element}})
       when not is_nil(element),
       do: element

  defp right_weapon_element(_attacker), do: :neutral

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

  defp infinite_defense_hit?(attacker, defender, opts) do
    range = if ranged_hit?(attacker, opts), do: :long, else: :short
    flag = BattleFlags.build(:weapon, range, Keyword.has_key?(opts, :skill_id))
    Combatant.infinite_defense?(defender, flag)
  end

  # A landed weapon hit on an infinite-defense target skips the whole recipe:
  # each hand deals 1. Only the Emperium's right hand takes the attribute step;
  # its left hand would only when the right dealt nothing before that step.
  defp plant_contact(attacker, defender, opts, :primary) do
    damage =
      if emperium?(defender) do
        modifiers = attacker_status_modifiers(attacker)

        DamageShared.apply_element_step(
          1,
          hit_element(attacker, modifiers, opts),
          attacker,
          defender,
          attacker_modifiers: modifiers
        )
      else
        1
      end

    {:ok,
     %{damage: damage, is_critical: critical_decision(opts), plant: plant_kind(defender, opts)}}
  end

  defp plant_contact(_attacker, defender, opts, :secondary),
    do:
      {:ok, %{damage: 1, is_critical: critical_decision(opts), plant: plant_kind(defender, opts)}}

  defp emperium?(defender), do: Map.get(defender, :monster_id) == @emperium_mob_id

  # Triple Attack and Finger Offensive keep their whole hit count against an
  # infinite-defense target; classic requires the target's DEF to be exactly 100.
  defp plant_kind(defender, opts) do
    cond do
      emperium?(defender) ->
        :emperium

      Keyword.get(opts, :skill_id) in @unsplit_plant_skills and
          (not classic?() or defender.combat_stats.def == 100) ->
        :unsplit

      true ->
        :ordinary
    end
  end

  @doc """
  Normalizes a calculated hit over its `divisions` (see
  `DamageShared.normalize_damage_divisions/2`). An infinite-defense contact on
  the Emperium keeps its single damage; a `:unsplit` contact multiplies by the
  hit count even for a split skill.
  """
  @spec normalize_divisions(damage_result(), integer()) :: {damage_result(), non_neg_integer()}
  def normalize_divisions(%{plant: :emperium} = result, divisions),
    do: {result, abs(divisions)}

  def normalize_divisions(%{plant: :unsplit} = result, divisions),
    do: normalize_divisions(Map.delete(result, :plant), abs(divisions)) |> keep_plant(:unsplit)

  def normalize_divisions(result, divisions) do
    {damage, divisions} = DamageShared.normalize_damage_divisions(result.damage, divisions)
    {%{result | damage: damage}, divisions}
  end

  defp keep_plant({result, divisions}, plant), do: {Map.put(result, :plant, plant), divisions}

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

  defp calculate_unit_base_attack(attacker, opts) do
    DamageInputs.non_player_base_attack(attacker,
      critical: Keyword.get(opts, :force_crit, false),
      skill_id: Keyword.get(opts, :skill_id)
    )
  end

  @doc """
  Applies the scalar recipe's modifier stages to `base_damage`, without DEF.

  In reference order: size, status ATK channels and, in classic, the equipment
  skill rates; then, in renewal, the equipment skill rates, the hit's
  post-defense attribute step (none for a non-player basic attack, the Sacrifice
  group only for a renewal player) and a player target's cards. The attribute
  step is an actual application: it can burn a web.

  `opts` accepts `:element` to force the attack element, `:skill_id` to scope the
  skill rates, and `:skip_status_atk` to leave status ATK channels unapplied.
  """
  @spec apply_modifier_pipeline(integer(), combatant(), combatant(), keyword()) ::
          {:ok, integer()}
  def apply_modifier_pipeline(base_damage, attacker, defender, opts \\ []) do
    modifiers = attacker_status_modifiers(attacker)
    hit = %{attacker: attacker, defender: defender, opts: opts, modifiers: modifiers}
    classic_player? = classic?() and attacker.unit_type == :player

    atk_percent =
      100 + atk_percent_delta(attacker.unit_type, Keyword.get(opts, :skill_id), modifiers)

    damage =
      base_damage
      |> apply_attack_modifiers(attacker, defender, opts, :primary, modifiers, atk_percent)
      |> renewal_skill_rates(hit)
      |> scalar_element(hit)
      |> classic_player_cards(hit, :primary, classic_player?)
      |> scalar_target_cards(hit, hit_element(attacker, modifiers, opts))

    {:ok, damage}
  end

  # The scalar recipe's pre-defense modifiers: size and the flat status channels,
  # then classic's equipment skill rates and the ATK percent after them, or a
  # renewal player's cards and range rate, which act on the whole scalar where
  # its components would take them. Element and the rest of the cards follow DEF.
  defp apply_attack_modifiers(
         base_damage,
         attacker,
         defender,
         opts,
         attack_path,
         modifiers,
         atk_percent
       ) do
    damage =
      base_damage
      |> apply_size_modifier(attacker, defender, opts)
      |> add_status_flats(modifiers, Keyword.get(opts, :skip_status_atk, false))
      |> trunc()

    cond do
      classic?() ->
        damage
        |> skill_rates(attacker, defender, opts)
        |> atk_percent_stage(atk_percent, modifiers)

      attacker.unit_type == :player ->
        damage
        |> atk_percent_stage(atk_percent, modifiers)
        |> PhysicalAttack.attacker_cardfix(
          attacker_cards(attacker, defender, opts, attack_path, modifiers)
        )
        |> PhysicalAttack.range_damage(range_rates(attacker, opts))

      true ->
        atk_percent_stage(damage, atk_percent, modifiers)
    end
  end

  # Status weapon ATK and status ATK live in the unit's base roll, which a
  # replaced base does not have; only the flat channels act here, and
  # `skip_status_atk` leaves even those out.
  defp add_status_flats(damage, _modifiers, true), do: damage

  defp add_status_flats(damage, modifiers, false),
    do: damage + Map.get(modifiers, :damage_bonus, 0) + Map.get(modifiers, :atk_bonus, 0)

  # The ATK percent as one truncating product, then the generic damage multiplier.
  defp atk_percent_stage(damage, atk_percent, modifiers) do
    damage
    |> Kernel.*(atk_percent)
    |> div(100)
    |> DamageShared.apply_damage_multiplier(modifiers)
    |> trunc()
  end

  # Renewal adds the equipment skill rates after the post-defense stage, before
  # the attribute step; classic adds them before DEF.
  defp renewal_skill_rates(damage, hit) do
    if classic?(), do: damage, else: skill_rates(damage, hit.attacker, hit.defender, hit.opts)
  end

  defp skill_rates(damage, attacker, defender, opts) do
    skill_id = Keyword.get(opts, :skill_id)

    damage
    |> PhysicalAttack.add_rate(EquipmentBonuses.skill_atk_rate(attacker, skill_id))
    |> PhysicalAttack.add_rate(-EquipmentBonuses.sub_skill_rate(defender, skill_id))
  end

  # A player target's cards, after the attribute step.
  defp scalar_target_cards(damage, hit, element) do
    case defender_cards(hit.defender, hit.attacker, hit.opts, [element]) do
      nil -> damage
      %{weapon: cards} -> PhysicalAttack.defender_cardfix(damage, cards)
    end
  end

  @doc """
  Applies the Renewal defense reduction formula.

  Formula: Attack * (4000 + eDEF) / (4000 + eDEF*10) - sDEF

  Where:
  - eDEF = equipment/hard defense
  - sDEF = soft defense (VIT-based)
  """
  @spec apply_defense_formula(number(), combatant(), combatant() | nil) :: {:ok, integer()}
  def apply_defense_formula(total_atk, defender, attacker \\ nil) do
    {:ok, defended} = defended_damage(total_atk, defender, attacker)
    {:ok, DamageShared.clamp_min_one(defended)}
  end

  # DEF leaves the damage as it lands, at or below zero included; the
  # post-defense stage applies the minimum.
  defp defended_damage(total_atk, defender, attacker),
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
    modifiers = ModifierCalculator.get_battle_modifiers(unit_type, unit_id)

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

    final_damage = trunc(base_damage)

    Logger.debug(
      "Defense calculation: total_atk=#{trunc(total_atk)}, hard_def=#{modified_hard_def}, soft_def=#{modified_soft_def}, final_damage=#{final_damage}"
    )

    {:ok, final_damage}
  end

  defp defense_base_damage(:simple, total_atk, hard_def, soft_def),
    do: total_atk - (hard_def + soft_def)

  defp attacker_level(nil), do: nil
  defp attacker_level(%{progression: %{base_level: base_level}}), do: base_level

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

  @doc """
  Whether a physical hit is ranged: the hit's explicit `:ranged` classification
  when given, otherwise a ranged weapon class or an attack range above 3 cells.
  """
  @spec ranged_hit?(map(), keyword()) :: boolean()
  def ranged_hit?(attacker, opts) do
    case Keyword.fetch(opts, :ranged) do
      {:ok, ranged?} when is_boolean(ranged?) ->
        ranged?

      _unclassified ->
        attacker.weapon |> Map.get(:type) |> WeaponTypes.is_ranged?() or
          Map.get(attacker, :attack_range, 1) > 3
    end
  end

  defp resolve_attack_element(attacker, attacker_modifiers) do
    DamageShared.endow_element(attacker_modifiers) || Map.get(attacker.weapon, :element, :neutral)
  end

  defp apply_size_modifier(damage, attacker, defender, opts) do
    # `bNoSizeFix` on the attacker's equipment ignores the size modifier entirely,
    # like the status-driven `ignore_size_penalty` above.
    if attacker.unit_type != :player or Keyword.get(opts, :ignore_size, false) or
         Map.get(attacker.combat_stats, :ignore_size_penalty, false) or
         Map.get(Map.get(attacker, :equip_modifiers, %{}), :no_size_fix, 0) > 0 do
      damage
    else
      modifier = SizeModifiers.get_modifier(attacker.weapon.type, defender.size, attacker.riding)
      damage * modifier / 100
    end
  end

  defp get_unit_type_and_id(combatant) do
    case combatant.unit_type do
      :player -> {:player, combatant.unit_id}
      :mob -> {:mob, combatant.unit_id}
      :homunculus -> {:homunculus, combatant.unit_id}
      _ -> {:unknown, combatant.unit_id}
    end
  end
end
