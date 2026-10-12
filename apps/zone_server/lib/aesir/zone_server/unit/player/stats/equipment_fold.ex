defmodule Aesir.ZoneServer.Unit.Player.Stats.EquipmentFold do
  @moduledoc """
  The deterministic equipment fold of the player stat pipeline.

  Reduces the worn inventory rows into the equipment layer of a `Stats` struct:
  the flat item-DB and refine bonuses, each host and in-range card `on_equip`
  program, the autobonus proc registrations, the direct statuses worn items
  desire, the card cleanup effects retained for unequip, and the resolved
  weapon hands. The item worn in the ammunition slot evaluates its program with
  the `:ammunition` input set, so ammunition-excluded destinations ignore it and
  it arms no autocast. Autocasts register into the per-trigger lists of
  `EquipAutocast.register/3` in the order the worn scripts run, each carrying
  the id of the card that armed it.
  Pure: it reads the item and refine catalogs and writes only to
  the struct it is given.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  @doc """
  Applies equipment modifiers to stats from the equipped inventory items.

  When `equipped_items` is a list or index-keyed map of `InventoryItem`s, this
  rebuilds the worn `Equipment` struct (so weapon-type/shield-dependent
  calculations such as ASPD see the correct gear), caches item instance metadata
  in `worn_items`,
  and folds each host's flat `item_db` bonuses followed by the host and valid
  in-range card `on_equip` programs into modifiers, proc registrations, desired
  direct statuses, and retained card cleanup effects. Surviving active proc
  generations re-evaluate their primary programs through
  the same equipment merge rules. `extra_inputs` is merged into every program's
  inputs: `:character_info` (the wearer's `PlayerState`, read by `strcharinfo`)
  and `:local_time` (read by `gettime`; captured once per fold when absent).
  When `equipped_items` is `nil`, the fold reruns
  from the cached `worn_items` instead - equipment cannot have changed, but the
  program level inputs (`BaseLevel`/`JobLevel`) follow the current progression,
  so a level-up recompute refreshes level-gated bonuses without threading the
  inventory through every call site. An empty cache has nothing to refold, so
  that case preserves legacy modifier state while clearing derived equipment
  proc and direct-status runtime maps.
  """
  @spec apply_equipment_modifiers(
          Stats.t(),
          [InventoryItem.t()] | %{optional(any()) => InventoryItem.t()} | nil,
          EquipScript.inputs() | %{}
        ) :: Stats.t()
  def apply_equipment_modifiers(stats, equipped_items \\ nil, extra_inputs \\ %{})

  def apply_equipment_modifiers(%Stats{worn_items: []} = stats, nil, _extra_inputs) do
    %{
      stats
      | equip_autobonuses: %{},
        active_autobonuses: %{},
        equip_statuses: %{},
        card_unequip_effects: %{}
    }
  end

  def apply_equipment_modifiers(%Stats{} = stats, nil, extra_inputs) do
    stats
    |> fold_equipment(stats.worn_items, extra_inputs)
    |> put_weapon_hands(stats.worn_items)
  end

  def apply_equipment_modifiers(%Stats{} = stats, equipped_items, extra_inputs)
      when is_list(equipped_items) or is_map(equipped_items) do
    worn_items =
      equipped_items
      |> Stats.normalize_items()
      |> Enum.map(
        &%{
          id: &1.id,
          nameid: &1.nameid,
          refine: &1.refine,
          equip: &1.equip,
          card0: &1.card0,
          card1: &1.card1,
          card2: &1.card2,
          card3: &1.card3,
          craft: &1.craft
        }
      )

    stats
    |> Map.put(:equipment, Stats.equipment_from_inventory(equipped_items))
    |> Map.put(:worn_items, worn_items)
    |> fold_equipment(worn_items, extra_inputs)
    |> put_weapon_hands(worn_items)
  end

  defp fold_equipment(stats, worn_items, extra_inputs) do
    fold = equipment_fold_result(stats, worn_items, extra_inputs)
    {equipment_bonuses, granted_skills} = split_granted_skills(fold.bonuses)

    %{
      stats
      | equip_autobonuses: fold.registrations,
        active_autobonuses: fold.active,
        equip_statuses: fold.statuses,
        card_unequip_effects: fold.card_cleanups,
        granted_skills: granted_skills,
        modifiers: %{stats.modifiers | equipment: equipment_bonuses}
    }
  end

  defp equipment_fold_result(stats, worn_items, extra_inputs) do
    inputs =
      stats.progression
      |> equip_script_inputs(equip_stat_params(stats), 0)
      |> Map.put(:equipped_item_counts, equipped_item_counts(worn_items))
      |> Map.merge(extra_inputs)
      |> Map.put_new_lazy(:local_time, &NaiveDateTime.local_now/0)

    fold = fold_worn_items(worn_items, inputs)

    active =
      retain_active_autobonuses(
        stats.active_autobonuses,
        stats.equip_autobonuses,
        fold.registrations
      )

    active_results =
      active
      |> Enum.sort_by(fn {key, _generation} -> fold.registrations[key].source_order end)
      |> Enum.map(fn {key, _generation} ->
        registration = Map.fetch!(fold.registrations, key)
        active_inputs = %{inputs | refine: registration.refine}
        {registration, EquipScript.evaluate(registration.primary, active_inputs)}
      end)

    auto_casts = active_auto_casts(active_results, worn_items) ++ fold.auto_casts

    bonuses =
      active_results
      |> Enum.reduce(fold.bonuses, fn {_registration, result}, acc ->
        merge_equip_modifiers(acc, result.modifiers)
      end)
      |> register_auto_casts(auto_casts)
      |> finalize_equipment_bonuses()

    Map.put(fold, :active, active) |> Map.put(:bonuses, bonuses)
  end

  # Autocasts register in the order the worn scripts run: the active autobonus
  # programs first (attack, then when-hit, then on-skill autobonuses), then each
  # worn item's own script by equipment slot, then every worn item's cards by
  # equipment slot and card slot. That order decides which entry a duplicate
  # merges into and which proc resolves first.
  defp register_auto_casts(bonuses, auto_casts) do
    auto_casts
    |> Enum.sort_by(fn {order, _registration, _card_id} -> order end)
    |> Enum.reduce(bonuses, fn {_order, registration, card_id}, acc ->
      EquipAutocast.register(acc, registration, card_id)
    end)
  end

  defp active_auto_casts(active_results, worn_items) do
    Enum.flat_map(active_results, fn
      {_registration, %{auto_casts: []}} -> []
      {registration, result} -> active_auto_casts(registration, result, worn_items)
    end)
  end

  defp active_auto_casts(registration, result, worn_items) do
    {worn_ordinal, lexical_slot} = registration.source_order
    list = autobonus_list(registration.trigger)
    phase = source_phase(registration.source_identity)
    slot = equip_index!(Enum.at(worn_items, worn_ordinal))
    order = {0, {list, phase, slot, lexical_slot}}

    Enum.map(result.auto_casts, &{order, &1, 0})
  end

  defp autobonus_list(:attack), do: 0
  defp autobonus_list(:when_hit), do: 1
  defp autobonus_list({:on_skill, _skill_id}), do: 2

  defp source_phase({:host, _item_id}), do: 1
  defp source_phase({:card, _slot, _item_id}), do: 3

  defp source_auto_casts([], _item, _card_slot, _source_id), do: []

  defp source_auto_casts(auto_casts, item, nil, _source_id) do
    order = {1, {equip_index!(item), -1}}
    Enum.map(auto_casts, &{order, &1, 0})
  end

  defp source_auto_casts(auto_casts, item, card_slot, card_id) do
    order = {3, {equip_index!(item), card_slot}}
    Enum.map(auto_casts, &{order, &1, card_id})
  end

  defp equip_index!(item) do
    case EquipLocation.equip_index(item.equip) do
      nil ->
        raise ArgumentError,
              "worn item #{inspect(item.nameid)} at position #{inspect(item.equip)} " <>
                "occupies no equipment slot"

      index ->
        index
    end
  end

  defp put_weapon_hands(stats, worn_items) do
    %{
      stats
      | right_hand: weapon_hand(worn_items, :right_hand),
        left_hand: weapon_hand(worn_items, :left_hand)
    }
  end

  defp weapon_hand(worn_items, slot) do
    case Enum.find(worn_items, &worn_in_slot?(&1, slot)) do
      nil -> nil
      item -> weapon_hand(item, slot, ItemManagement.get_item_by_id(item.nameid))
    end
  end

  defp weapon_hand(item, slot, {:ok, %ItemDefinition{type: :weapon} = item_def}) do
    {refine_atk, overrefine_band} = weapon_refine(item_def, item.refine)

    %WeaponHand{
      item_id: item.nameid,
      subtype: item_def.subtype,
      element: weapon_element(item_def, item),
      base_atk: item_def.attack,
      weapon_level: item_def.weapon_level,
      refine_atk: refine_atk,
      overrefine_band: overrefine_band,
      slot: slot
    }
  end

  defp weapon_hand(_item, _slot, _item_result), do: nil

  defp worn_in_slot?(item, slot) do
    locations = EquipLocation.bitmask_to_location_atoms(item.equip)
    slot in locations and (slot == :right_hand or :right_hand not in locations)
  end

  defp weapon_element(%ItemDefinition{attack_element: element}, _item)
       when is_atom(element) and not is_nil(element),
       do: element

  defp weapon_element(_item_def, item) do
    case ItemCraft.from_map(item.craft) do
      {:ok, %ItemCraft{kind: :forged, element: element}} -> element
      _ -> :neutral
    end
  end

  defp weapon_refine(_item_def, refine) when refine <= 0, do: {0, 0}

  defp weapon_refine(%ItemDefinition{weapon_level: level}, refine) do
    case RefineDatabase.level_info(:weapon, level, refine) do
      %{bonus: bonus, randombonus_max: random} -> {div(bonus, 100), div(random, 100)}
      nil -> {0, 0}
    end
  end

  @doc """
  Returns the DEF and MDEF the currently equipped shield contributes.

  Computed as the marginal difference the shield makes to the folded equipment
  DEF/MDEF - the full worn set minus the same set without the left-hand item -
  so shared armor-refine rounding is attributed to the shield correctly rather
  than isolated per-item. A left-hand weapon (dual-wield or a two-hander) is not
  a shield and contributes nothing. Both values are clamped at zero.

  Used to suppress a caster's own shield defense for the lifetime of a skill
  (Grand Cross): the caller applies these as negative flat `:def`/`:mdef` status
  modifiers, so the shield's protection returns when the status ends.
  """
  @spec shield_defense_contribution(Stats.t()) :: %{
          def: non_neg_integer(),
          mdef: non_neg_integer()
        }
  def shield_defense_contribution(%Stats{equipment: %Equipment{} = equipment} = stats) do
    if Stats.shield?(equipment) do
      without_shield = Enum.reject(stats.worn_items, &worn_in_slot?(&1, :left_hand))
      inputs = %{local_time: NaiveDateTime.local_now()}
      full = equipment_fold_result(stats, stats.worn_items, inputs).bonuses
      reduced = equipment_fold_result(stats, without_shield, inputs).bonuses

      %{
        def: max(scaled_equipment_def(full) - scaled_equipment_def(reduced), 0),
        mdef: max(Map.get(full, :mdef, 0) - Map.get(reduced, :mdef, 0), 0)
      }
    else
      %{def: 0, mdef: 0}
    end
  end

  def shield_defense_contribution(%Stats{}), do: %{def: 0, mdef: 0}

  @doc """
  Equipment DEF after the `def_rate` percentage modifier (a negative rate can
  only reduce it to zero).
  """
  @spec scaled_equipment_def(map()) :: integer()
  def scaled_equipment_def(equipment_modifiers) do
    raw_def = Map.get(equipment_modifiers, :def, 0)
    rate = max(0, 100 + Map.get(equipment_modifiers, :def_rate, 0))
    div(raw_def * rate, 100)
  end

  # Sums flat item bonuses across the equipped items. Weapon MATK becomes a
  # variance band while non-weapon MATK stays flat. Refine bonuses, overrefine,
  # and trait riders accumulate in the same pass; armor refine DEF rounds once
  # after the reduction. `aspd_rate` defaults to 100 (no modifier).
  # The wearer's base stats (allocated points plus job bonuses) that an
  # `on_equip` `readparam(bStr)` reads. Deliberately excludes equipment, status
  # and passive contributions: equip scripts run before those in the recompute
  # pipeline, and reading them would make an equipment bonus depend on the very
  # bonuses being computed.
  @stat_param_keys [:str, :agi, :vit, :int, :dex, :luk, :pow, :sta, :wis, :spl, :con, :crt]

  @spec equip_stat_params(Stats.t()) :: %{atom() => integer()}
  defp equip_stat_params(%Stats{base_stats: base, modifiers: %Modifiers{job_bonuses: job}})
       when not is_nil(base) do
    Map.new(@stat_param_keys, fn stat ->
      {stat, Map.get(base, stat, 0) + Map.get(job, stat, 0)}
    end)
  end

  defp equip_stat_params(%Stats{}), do: %{}

  defp equipped_item_counts(worn_items) do
    Enum.reduce(worn_items, %{}, fn item, counts ->
      counts = increment_equipped_count(counts, item.nameid)

      case ItemManagement.get_item_by_id(item.nameid) do
        {:ok, %ItemDefinition{} = item_def} ->
          item
          |> in_range_card_ids(item_def)
          |> Enum.reduce(counts, &increment_valid_card_count/2)

        _ ->
          counts
      end
    end)
  end

  defp increment_equipped_count(counts, item_id) when is_integer(item_id) and item_id > 0,
    do: Map.update(counts, item_id, 1, &(&1 + 1))

  defp increment_equipped_count(counts, _item_id), do: counts

  defp increment_valid_card_count(card_id, counts) when is_integer(card_id) and card_id > 0 do
    case ItemManagement.get_item_by_id(card_id) do
      {:ok, %ItemDefinition{type: :card}} -> increment_equipped_count(counts, card_id)
      _ -> counts
    end
  end

  defp increment_valid_card_count(_card_id, counts), do: counts

  defp retain_active_autobonuses(active, previous_registrations, current_registrations) do
    Map.filter(active, fn {key, _generation} ->
      with {:ok, %{source_identity: identity}} when not is_nil(identity) <-
             Map.fetch(previous_registrations, key),
           {:ok, %{source_identity: ^identity}} <- Map.fetch(current_registrations, key) do
        true
      else
        _ -> false
      end
    end)
  end

  defp fold_worn_items(worn_items, inputs) do
    worn_items
    |> Enum.with_index()
    |> Enum.reduce(
      %{
        bonuses: empty_equipment_bonuses(),
        auto_casts: [],
        registrations: %{},
        statuses: %{},
        card_cleanups: %{}
      },
      fn {item, worn_ordinal}, fold -> fold_worn_item(item, worn_ordinal, fold, inputs) end
    )
  end

  defp fold_worn_item(item, worn_ordinal, fold, inputs) do
    case ItemManagement.get_item_by_id(item.nameid) do
      {:ok, %ItemDefinition{} = item_def} ->
        item_inputs = Map.merge(inputs, %{refine: item.refine, ammunition: ammunition?(item)})
        fold = %{fold | bonuses: accumulate_item_bonus(fold.bonuses, item_def, item.refine)}

        [{item_def, nil} | card_sources(item, item_def)]
        |> Enum.reduce({fold, 0}, fn source, {acc, next_slot} ->
          apply_equipment_source(source, item, item_inputs, worn_ordinal, acc, next_slot)
        end)
        |> elem(0)

      _ ->
        fold
    end
  end

  defp ammunition?(item), do: :ammo in EquipLocation.bitmask_to_location_atoms(item.equip)

  defp apply_equipment_source(
         {%ItemDefinition{} = source_def, card_slot},
         item,
         inputs,
         worn_ordinal,
         fold,
         next_slot
       ) do
    result = evaluate_equip_script(source_def.on_equip, inputs)
    {next_slot, lexical_registrations} = isolate_autobonuses(source_def.on_equip || [], next_slot)

    registrations =
      install_lexical_autobonuses(
        lexical_registrations,
        fold.registrations,
        autobonus_source_identity(source_def.id, card_slot),
        source_def.id,
        item,
        inputs,
        worn_ordinal
      )

    card_cleanups =
      install_card_cleanup(
        fold.card_cleanups,
        source_def,
        card_slot,
        item,
        inputs,
        worn_ordinal
      )

    auto_casts = source_auto_casts(result.auto_casts, item, card_slot, source_def.id)

    {%{
       fold
       | bonuses: merge_equip_modifiers(fold.bonuses, result.modifiers),
         auto_casts: fold.auto_casts ++ auto_casts,
         registrations: registrations,
         statuses: install_equip_statuses(fold.statuses, result.effects),
         card_cleanups: card_cleanups
     }, next_slot}
  end

  defp install_card_cleanup(cleanups, _source_def, nil, _item, _inputs, _worn_ordinal),
    do: cleanups

  defp install_card_cleanup(
         cleanups,
         %ItemDefinition{on_unequip: nil},
         _card_slot,
         _item,
         _inputs,
         _worn_ordinal
       ),
       do: cleanups

  defp install_card_cleanup(
         cleanups,
         %ItemDefinition{on_unequip: program},
         card_slot,
         item,
         inputs,
         worn_ordinal
       ) do
    row_id = card_source_row_id!(item)

    cleanup = %{
      source_order: {worn_ordinal, card_slot},
      effects: EquipScript.evaluate(program, inputs).effects
    }

    Map.put(cleanups, {row_id, card_slot}, cleanup)
  end

  defp card_source_row_id!(%{id: id}) when is_integer(id) and id > 0, do: id

  defp card_source_row_id!(item) do
    raise ArgumentError,
          "worn host with card cleanup requires a persistent positive row id, " <>
            "got: #{inspect(item.id)} for item #{inspect(item.nameid)}"
  end

  defp card_sources(item, %ItemDefinition{} = item_def) do
    item
    |> in_range_card_ids(item_def)
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {0, _slot} -> []
      {card_id, slot} -> resolve_card(card_id, slot)
    end)
  end

  defp in_range_card_ids(item, %ItemDefinition{slots: slots}) do
    [:card0, :card1, :card2, :card3]
    |> Enum.take(bounded_card_slots(slots))
    |> Enum.map(&Map.fetch!(item, &1))
  end

  defp bounded_card_slots(slots), do: slots |> max(0) |> min(4)

  defp resolve_card(card_id, slot) do
    case ItemManagement.get_item_by_id(card_id) do
      {:ok, %ItemDefinition{type: :card} = card_def} -> [{card_def, slot}]
      _ -> []
    end
  end

  defp autobonus_source_identity(item_id, nil), do: {:host, item_id}
  defp autobonus_source_identity(item_id, card_slot), do: {:card, card_slot, item_id}

  defp install_lexical_autobonuses(
         [],
         registrations,
         _source_identity,
         _source_item_id,
         _item,
         _inputs,
         _worn_ordinal
       ),
       do: registrations

  defp install_lexical_autobonuses(
         slots,
         registrations,
         source_identity,
         source_item_id,
         item,
         inputs,
         worn_ordinal
       ) do
    row_id = registration_row_id!(item)

    Enum.reduce(slots, registrations, fn slot, acc ->
      install_autobonus_slot(
        acc,
        slot,
        row_id,
        source_identity,
        source_item_id,
        item,
        inputs,
        worn_ordinal
      )
    end)
  end

  defp install_autobonus_slot(
         registrations,
         {lexical_slot, isolated_program},
         row_id,
         source_identity,
         source_item_id,
         item,
         inputs,
         worn_ordinal
       ) do
    case EquipScript.evaluate(isolated_program, inputs).autobonuses do
      [] ->
        registrations

      [autobonus] ->
        primary = EquipScript.evaluate(autobonus.primary, inputs)
        secondary = EquipScript.evaluate(autobonus.secondary, inputs)

        registration =
          Map.merge(autobonus, %{
            item_id: source_item_id,
            source_identity: source_identity,
            refine: item.refine,
            source_order: {worn_ordinal, lexical_slot},
            primary_effects: primary.effects,
            secondary_effects: secondary.effects
          })

        Map.put(registrations, {row_id, lexical_slot}, registration)
    end
  end

  defp isolate_autobonuses(program, next_slot) do
    Enum.reduce(program, {next_slot, []}, fn
      {:autobonus, _spec, _rate, _duration} = autobonus, {slot, registrations} ->
        {slot + 1, registrations ++ [{slot, [autobonus]}]}

      {:if, condition, then_branch, else_branch}, {slot, registrations} ->
        {after_then, then_registrations} = isolate_autobonuses(then_branch, slot)
        {after_else, else_registrations} = isolate_autobonuses(else_branch, after_then)

        wrapped_then =
          Enum.map(then_registrations, fn {index, branch} ->
            {index, [{:if, condition, branch, []}]}
          end)

        wrapped_else =
          Enum.map(else_registrations, fn {index, branch} ->
            {index, [{:if, condition, [], branch}]}
          end)

        {after_else, registrations ++ wrapped_then ++ wrapped_else}

      _instruction, acc ->
        acc
    end)
  end

  defp registration_row_id!(%{id: id}) when is_integer(id) and id > 0, do: id

  defp registration_row_id!(item) do
    raise ArgumentError,
          "worn item with autobonus registrations requires a persistent positive row id, " <>
            "got: #{inspect(item.id)} for item #{inspect(item.nameid)}"
  end

  defp install_equip_statuses(statuses, effects) do
    Enum.reduce(effects, statuses, fn
      {:status_start, status, duration, value}, acc -> Map.put(acc, status, {duration, value})
      _effect, acc -> acc
    end)
  end

  defp empty_equipment_bonuses do
    %{
      atk: 0,
      def: 0,
      matk: 0,
      wmatk_min: 0,
      wmatk_max: 0,
      aspd_rate: 100,
      patk: 0,
      smatk: 0,
      res: 0,
      mres: 0,
      overrefine_band: 0,
      refine_def: 0
    }
  end

  defp finalize_equipment_bonuses(bonuses) do
    bonuses
    |> Map.update!(:def, &(&1 + div(bonuses.refine_def + 50, 100)))
    |> Map.delete(:refine_def)
  end

  # Script keys (`:str`, `:hit`, `:critical`, ...) are not pre-seeded in the
  # accumulator, so each bonus is merged with `Map.update/4`; downstream readers
  # all use `Map.get(..., 0)`. Numeric bonuses sum except for non-stackable
  # destinations, while constant-valued destinations use last-source-wins.

  defp evaluate_equip_script(nil, inputs), do: EquipScript.evaluate([], inputs)
  defp evaluate_equip_script(program, inputs), do: EquipScript.evaluate(program, inputs)

  defp equip_script_inputs(progression, stat_params, refine) do
    %{
      refine: refine,
      base_level: progression.base_level,
      job_level: progression.job_level,
      learned_skills: progression.learned_skills,
      stats: stat_params,
      job_id: progression.job_id
    }
  end

  defp merge_equip_modifiers(acc, modifiers) do
    Enum.reduce(modifiers, acc, fn {key, value}, acc -> merge_equip_bonus(acc, key, value) end)
  end

  defp merge_equip_bonus(acc, {:granted_skill, _} = key, level),
    do: Map.update(acc, key, level, &max(&1, level))

  defp merge_equip_bonus(acc, :get_zeny, {rate, _bonus_amount} = bonus) do
    case Map.get(acc, :get_zeny, {0, 0}) do
      {current_rate, _current_amount} when rate > current_rate -> Map.put(acc, :get_zeny, bonus)
      _current -> acc
    end
  end

  defp merge_equip_bonus(acc, key, value) when is_number(value) do
    cond do
      BonusKeys.overwrite_destination?(key) -> Map.put(acc, key, value)
      BonusKeys.bitwise_destination?(key) -> Map.update(acc, key, value, &Bitwise.bor(&1, value))
      BonusKeys.max_destination?(key) -> Map.update(acc, key, value, &max(&1, value))
      BonusKeys.min_destination?(key) -> Map.update(acc, key, min(0, value), &min(&1, value))
      BonusKeys.capped_rate_destination?(key) -> accumulate_capped_rate(acc, key, value)
      true -> Map.update(acc, key, value, &(&1 + value))
    end
  end

  defp merge_equip_bonus(acc, key, value), do: Map.put(acc, key, value)

  defp accumulate_capped_rate(acc, key, value),
    do: Map.put(acc, key, BonusKeys.accumulate_capped_rate(Map.get(acc, key), value))

  # Splits the folded equipment accumulator into its numeric bonus map (stored on
  # `modifiers.equipment`) and the granted-skills map. `{:granted_skill, id}` is
  # the reserved channel the `on_equip` `skill` command folds into with `max`
  # semantics; these keys never reach the numeric bonus readers.
  @spec split_granted_skills(map()) :: {map(), %{integer() => non_neg_integer()}}
  defp split_granted_skills(accumulator) do
    {granted_pairs, bonus_pairs} =
      Enum.split_with(accumulator, fn
        {{:granted_skill, _id}, _level} -> true
        _ -> false
      end)

    granted = Map.new(granted_pairs, fn {{:granted_skill, id}, level} -> {id, level} end)
    {Map.new(bonus_pairs), granted}
  end

  # Weapon MATK variance is weapon MATK times weapon level divided by ten.
  defp accumulate_item_bonus(
         acc,
         %ItemDefinition{weapon_level: level, magic_attack: matk} = item,
         refine
       )
       when not is_nil(level) and matk > 0 do
    variance = div(matk * level, 10)

    acc = %{
      acc
      | atk: acc.atk + item.attack,
        def: acc.def + item.defense,
        wmatk_min: acc.wmatk_min + (matk - variance),
        wmatk_max: acc.wmatk_max + (matk + variance)
    }

    apply_refine_bonus(acc, item, refine)
  end

  defp accumulate_item_bonus(acc, %ItemDefinition{} = item, refine) do
    acc = %{
      acc
      | atk: acc.atk + item.attack,
        def: acc.def + item.defense,
        matk: acc.matk + item.magic_attack
    }

    apply_refine_bonus(acc, item, refine)
  end

  defp apply_refine_bonus(acc, _item_def, refine) when refine <= 0, do: acc

  defp apply_refine_bonus(
         acc,
         %ItemDefinition{type: :weapon, weapon_level: item_level} = item,
         refine
       ) do
    case RefineDatabase.level_info(:weapon, item_level, refine) do
      nil ->
        acc

      %{bonus: bonus, randombonus_max: randombonus_max} ->
        acc
        |> Map.put(:atk, acc.atk + div(bonus, 100))
        |> apply_weapon_matk_refine(item.subtype, bonus)
        |> Map.update!(:overrefine_band, &(&1 + div(randombonus_max, 100)))
        |> apply_weapon_rider(item_level, refine)
    end
  end

  defp apply_refine_bonus(acc, %ItemDefinition{type: :armor, armor_level: item_level}, refine) do
    case RefineDatabase.level_info(:armor, item_level, refine) do
      nil ->
        acc

      %{bonus: bonus} ->
        acc
        |> Map.update!(:refine_def, &(&1 + bonus))
        |> apply_armor_rider(item_level, refine)
    end
  end

  defp apply_refine_bonus(acc, %ItemDefinition{}, _refine), do: acc

  # ponytail: enchantgrade multiplication is deferred until grade bonuses exist;
  # refine bonuses are applied unmultiplied for now.
  defp apply_weapon_matk_refine(acc, :bow, _bonus), do: acc

  defp apply_weapon_matk_refine(acc, _subtype, bonus) do
    matk_bonus = div(bonus, 100)
    %{acc | wmatk_min: acc.wmatk_min + matk_bonus, wmatk_max: acc.wmatk_max + matk_bonus}
  end

  defp apply_weapon_rider(acc, 5, refine) do
    %{acc | patk: acc.patk + refine * 2, smatk: acc.smatk + refine * 2}
  end

  defp apply_weapon_rider(acc, _item_level, _refine), do: acc

  defp apply_armor_rider(acc, 2, refine) do
    %{acc | res: acc.res + refine * 2, mres: acc.mres + refine * 2}
  end

  defp apply_armor_rider(acc, _item_level, _refine), do: acc
end
