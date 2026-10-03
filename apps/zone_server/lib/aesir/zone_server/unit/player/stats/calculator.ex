defmodule Aesir.ZoneServer.Unit.Player.Stats.Calculator do
  @moduledoc """
  The player stat recompute pipeline.

  `calculate_stats/3` rebuilds a `Stats` struct from its base values and
  modifier sources in a fixed order: job bonuses, the equipment fold
  (`Stats.EquipmentFold`), active status-effect modifiers, learned passives,
  then the derived (HP/SP/AP/ASPD) and combat stats under the active ruleset
  (`Mechanics.player_formulas/0`). Every step is a pure function over the
  struct except the two reads that fetch the wearer's registry snapshot and
  active statuses.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.JobManagement.TraitJobs
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.EquipmentFold
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Stats, as: UnitStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @ranged_weapons [:bow, :musical, :whip, :revolver, :rifle, :gatling, :shotgun, :grenade]

  @doc """
  Calculates all stats from base values and modifiers.

  ## Parameters
  - stats: The Stats struct to calculate
  - player_id: Optional player ID for status effect retrieval
  - equipped_items: Optional list or index-keyed map of equipped inventory items
  """
  @spec calculate_stats(
          Stats.t(),
          integer() | nil,
          [InventoryItem.t()] | %{optional(any()) => InventoryItem.t()} | nil
        ) :: Stats.t()
  def calculate_stats(stats, player_id \\ nil, equipped_items \\ nil)

  def calculate_stats(%Stats{} = stats, player_id, equipped_items) do
    character_info = character_info(player_id)

    calculate_stats(
      stats,
      player_id,
      equipped_items,
      calculation_map(character_info),
      character_info
    )
  end

  @doc "Calculates all stats with an explicit map context for map transitions."
  @spec calculate_stats(
          Stats.t(),
          integer() | nil,
          [InventoryItem.t()] | %{optional(any()) => InventoryItem.t()} | nil,
          String.t() | nil
        ) :: Stats.t()
  def calculate_stats(%Stats{} = stats, player_id, equipped_items, map_name) do
    calculate_stats(stats, player_id, equipped_items, map_name, character_info(player_id))
  end

  defp calculate_stats(stats, player_id, equipped_items, map_name, character_info) do
    stats
    |> apply_job_bonuses()
    |> EquipmentFold.apply_equipment_modifiers(equipped_items, %{character_info: character_info})
    |> apply_status_effects(player_id)
    |> apply_passive_modifiers()
    |> calculate_derived_stats()
    |> calculate_combat_stats(map_name)
  end

  @doc """
  Aggregates the STR/DEX/INT/HIT/range bonuses from learned passive skills into
  `modifiers.passive`, along with the passive skill SP cost rate and base SP
  regen rate read at cast and regen time.

  Runs before `calculate_derived_stats/1` so the passive stat bonuses feed every
  stat derived from them (HIT, ASPD, ATK, MATK, max SP) just like a real stat
  point spent on the attribute.
  """
  @spec apply_passive_modifiers(Stats.t()) :: Stats.t()
  def apply_passive_modifiers(%Stats{} = stats) do
    passive = %{
      str: Passives.str_bonus(stats),
      dex: Passives.dex_bonus(stats),
      int: Passives.int_bonus(stats),
      hit: Passives.hit_bonus(stats),
      range: Passives.range_bonus(stats),
      max_weight_bonus: Passives.max_weight_bonus(stats),
      max_sp_rate: Passives.max_sp_rate_bonus(stats),
      sp_cost_rate: Passives.sp_cost_rate(stats),
      sp_regen_rate: Passives.sp_regen_rate(stats)
    }

    %{stats | modifiers: Map.put(stats.modifiers, :passive, passive)}
  end

  @doc """
  Applies job-specific stat bonuses based on job level and class.
  """
  @spec apply_job_bonuses(Stats.t()) :: Stats.t()
  def apply_job_bonuses(%Stats{} = stats) do
    job_bonuses =
      with {:ok, job_name} <- AvailableJobs.job_id_to_name(stats.progression.job_id),
           {:ok, bonus_stats} <-
             JobManagement.get_bonus_stats(
               job_name,
               stats.progression.job_level
             ) do
        %{
          str: bonus_stats.str,
          agi: bonus_stats.agi,
          vit: bonus_stats.vit,
          int: bonus_stats.int,
          dex: bonus_stats.dex,
          luk: bonus_stats.luk,
          pow: bonus_stats.pow,
          sta: bonus_stats.sta,
          wis: bonus_stats.wis,
          spl: bonus_stats.spl,
          con: bonus_stats.con,
          crt: bonus_stats.crt
        }
      else
        {:error, :level_out_of_range} ->
          # No bonuses for this level (common for level 1)
          %{}

        err ->
          raise "Failed to get job bonuses: #{inspect(err)}"
      end

    %{stats | modifiers: %{stats.modifiers | job_bonuses: job_bonuses}}
  end

  # NOTE: the wearer's map/party/guild come from its last committed registry
  # snapshot; rAthena does not recompute on those changes either.
  defp character_info(nil), do: nil

  defp character_info(player_id) do
    case UnitRegistry.get_unit(:player, player_id) do
      {:ok, {_module, game_state, _pid}} -> game_state
      {:error, :not_found} -> nil
    end
  end

  defp calculation_map(%{map_name: map_name}), do: map_name
  defp calculation_map(_character_info), do: nil

  @doc """
  Applies temporary status effect modifiers.
  Fetches active status effects for the player and applies their stat modifiers.

  ## Parameters
  - stats: The Stats struct to update
  - player_id: The player ID to get status effects for

  ## Returns
  Updated Stats struct with status effect modifiers applied
  """
  @spec apply_status_effects(Stats.t(), integer() | nil) :: Stats.t()
  def apply_status_effects(%Stats{} = stats, player_id) when is_integer(player_id) do
    # Get all status effect modifiers for this player
    status_modifiers = Interpreter.get_all_modifiers(:player, player_id)

    statuses_active? = StatusStorage.count_unit_statuses(:player, player_id) > 0

    %{
      stats
      | modifiers: %{
          stats.modifiers
          | status_effects: status_modifiers,
            statuses_active?: statuses_active?
        }
    }
  end

  # When player_id is nil or invalid
  @spec apply_status_effects(Stats.t(), any()) :: Stats.t()
  def apply_status_effects(%Stats{} = stats, _player_id) do
    # Without a valid player_id, we can't get status effects, so return unchanged
    stats
  end

  # Backwards compatibility for the original function signature
  @spec apply_status_effects(Stats.t()) :: Stats.t()
  def apply_status_effects(%Stats{} = stats) do
    # Without a player_id, we can't get status effects, so return unchanged
    stats
  end

  @doc "Calculates mode-specific derived stats from prepared job and modifier inputs."
  @spec calculate_derived_stats(Stats.t()) :: Stats.t()
  def calculate_derived_stats(%Stats{} = stats) do
    effective_vit = Stats.get_effective_stat(stats, :vit)
    effective_int = Stats.get_effective_stat(stats, :int)
    base_level = stats.progression.base_level

    case AvailableJobs.job_id_to_name(stats.progression.job_id) do
      {:ok, job_name} ->
        # Get all job-related stats
        job_stats = get_job_stats_for_level(job_name, base_level)

        # Calculate HP/SP with modifiers
        transcendent? = JobLineage.transcendent?(stats.progression.job_id)

        max_hp =
          calculate_max_hp(
            job_stats.base_hp,
            effective_vit,
            job_stats.hp_factor,
            job_stats.hp_increase,
            transcendent?,
            stats
          )

        max_sp =
          calculate_max_sp(
            job_stats.base_sp,
            effective_int,
            job_stats.sp_increase,
            transcendent?,
            stats
          )

        # Calculate ASPD
        aspd = calculate_aspd(stats)

        max_ap = calculate_max_ap(stats.progression.job_id, job_name, base_level)

        derived_stats = %UnitStats.DerivedStats{
          max_hp: max_hp,
          max_sp: max_sp,
          aspd: aspd,
          max_ap: max_ap
        }

        %{stats | derived_stats: derived_stats}
        |> clamp_current_to_max(
          max_hp,
          Stats.get_status_modifier(stats, :max_hp_rate),
          max_sp,
          Stats.get_status_modifier(stats, :max_sp_rate)
        )
        |> clamp_ap(max_ap)

      err ->
        raise "Failed to get job name for derived stats: #{inspect(err)}"
    end
  end

  # A max_hp_rate/max_sp_rate malus (Combat Pill -3%, 2011 RWC -10%) shrinks the
  # max below the current pool, so clamp current HP/SP down to the reduced max.
  # Only negative rates clamp; positive/zero rates never force current below its
  # existing value.
  defp clamp_current_to_max(
         %Stats{current_state: %{hp: hp, sp: sp} = current} = stats,
         max_hp,
         max_hp_rate,
         max_sp,
         max_sp_rate
       )
       when is_integer(hp) and is_integer(sp) do
    new_hp = if max_hp_rate < 0, do: min(hp, max_hp), else: hp
    new_sp = if max_sp_rate < 0, do: min(sp, max_sp), else: sp

    %{stats | current_state: %{current | hp: new_hp, sp: new_sp}}
  end

  defp clamp_current_to_max(stats, _max_hp, _max_hp_rate, _max_sp, _max_sp_rate), do: stats

  # MaxAP (formula row 26): trait jobs read the imported base_ap table at the
  # character's base level; a missing row is data corruption and fails loudly
  # rather than silently becoming 0. Non-trait jobs have no AP pool -> a real 0.
  defp calculate_max_ap(job_id, job_name, base_level) do
    if TraitJobs.trait_job?(job_id) do
      case JobManagement.get_base_ap(job_name, base_level) do
        {:ok, ap} ->
          ap

        {:error, reason} ->
          raise "Missing base AP for trait job #{job_name} at level #{base_level}: #{inspect(reason)}"
      end
    else
      0
    end
  end

  defp clamp_ap(%Stats{current_state: %{ap: ap} = current} = stats, max_ap)
       when is_integer(ap) do
    %{stats | current_state: %{current | ap: min(ap, max_ap)}}
  end

  defp clamp_ap(stats, _max_ap), do: stats

  @doc "Calculates combat-related stats under the active ruleset."
  @spec calculate_combat_stats(Stats.t()) :: Stats.t()
  def calculate_combat_stats(%Stats{} = stats), do: calculate_combat_stats(stats, nil)

  @doc "Calculates combat-related stats under the active ruleset and map context."
  @spec calculate_combat_stats(Stats.t(), String.t() | nil) :: Stats.t()
  def calculate_combat_stats(%Stats{} = stats, map_name) do
    alias Aesir.ZoneServer.Unit.Player.CombatCalculations, as: PlayerCombatCalc

    formulas = Mechanics.player_formulas()
    values = formula_values(stats)

    critical_basis = formulas.critical(values)

    status_atk = formulas.base_atk(values, equipped_weapon_type(stats) in @ranged_weapons)
    base_atk = apply_rate(status_atk, Stats.get_equipment_modifier(stats, :atk_rate))

    %{min: base_matk_min, max: base_matk_max} = formulas.base_matk(values)
    base_def = formulas.base_def(values)
    skill_passive_atk = Passives.atk_bonus(stats)
    passive_atk = skill_passive_atk + forged_star_damage(stats.worn_items)
    passive_critical = Passives.critical_bonus(stats)

    flat_critical =
      Stats.get_status_modifier(stats, :critical) + Stats.get_equipment_modifier(stats, :critical)

    {critical, critical_rate} =
      calculate_critical(
        critical_basis,
        passive_critical,
        flat_critical,
        Stats.get_status_modifier(stats, :critical_rate),
        stats.right_hand
      )

    trait_slots = calculate_trait_slots(stats, formulas, values)

    flat_matk =
      Stats.get_status_modifier(stats, :matk) + Stats.get_equipment_modifier(stats, :matk)

    wmatk_min = Map.get(stats.modifiers.equipment, :wmatk_min, 0)
    wmatk_max = Map.get(stats.modifiers.equipment, :wmatk_max, 0)
    matk_rate = Stats.get_equipment_modifier(stats, :matk_rate)
    matk_min = apply_rate(base_matk_min + wmatk_min + flat_matk, matk_rate)
    matk_max = apply_rate(base_matk_max + wmatk_max + flat_matk, matk_rate)

    # Heal MATK excludes flat item and status MATK while retaining weapon variance.
    heal_matk_min = base_matk_min + wmatk_min
    heal_matk_max = base_matk_max + wmatk_max

    hit =
      stats
      |> PlayerCombatCalc.calculate_hit()
      |> apply_rate(Stats.get_equipment_modifier(stats, :hit_rate))
      |> max(0)

    combat_stats = %UnitStats.CombatStats{
      hit: hit,
      flee: PlayerCombatCalc.calculate_flee(stats, map_name),
      critical: critical,
      critical_rate: critical_rate,
      perfect_dodge: PlayerCombatCalc.calculate_perfect_dodge(stats),
      atk:
        base_atk + Stats.get_status_modifier(stats, :atk) +
          Stats.get_equipment_modifier(stats, :atk) +
          skill_passive_atk,
      physical_attack: %{
        status_atk: status_atk,
        flat_atk:
          Stats.get_status_modifier(stats, :atk) + Stats.get_equipment_modifier(stats, :atk) -
            hand_attack(stats.right_hand) - hand_attack(stats.left_hand),
        mastery_atk: passive_atk,
        str: values.str,
        dex: values.dex
      },
      matk_min: matk_min,
      matk_max: matk_max,
      matk: matk_max,
      heal_matk_min: heal_matk_min,
      heal_matk_max: heal_matk_max,
      def:
        override(
          base_def + Stats.get_status_modifier(stats, :def) +
            EquipmentFold.scaled_equipment_def(stats.modifiers.equipment),
          stats,
          :def_override
        ),
      mdef:
        override(
          Stats.get_status_modifier(stats, :mdef) + Stats.get_equipment_modifier(stats, :mdef),
          stats,
          :mdef_override
        ),
      soft_def: formulas.soft_def(values),
      soft_mdef: formulas.soft_mdef(values),
      passive_atk: passive_atk,
      hit_rate_bonus_pct: Passives.hit_rate_bonus_pct(stats),
      patk: trait_slots.patk,
      smatk: trait_slots.smatk,
      res: trait_slots.res,
      mres: trait_slots.mres,
      hplus: trait_slots.hplus,
      crate: trait_slots.crate,
      overrefine_band: Stats.get_equipment_modifier(stats, :overrefine_band),
      ignore_size_penalty: Stats.get_status_flag(stats, :ignore_size_penalty),
      max_weapon_damage: Stats.get_status_flag(stats, :max_weapon_damage)
    }

    %{stats | combat_stats: combat_stats}
  end

  defp override(value, stats, key), do: Map.get(stats.modifiers.status_effects, key, value)

  defp hand_attack(nil), do: 0
  defp hand_attack(hand), do: hand.base_atk + hand.refine_atk

  defp calculate_critical(
         %{strategy: :exact_tenths, base_rate: base_rate},
         passive_critical,
         flat_critical,
         critical_rate,
         right_hand
       ) do
    roll_rate =
      (base_rate + passive_critical + flat_critical * 10)
      |> apply_critical_rate(critical_rate)
      |> apply_katar_critical(right_hand)

    {div(roll_rate, 10), roll_rate}
  end

  defp apply_critical_rate(critical, rate), do: div(critical * (100 + rate), 100)

  defp apply_katar_critical(critical, %WeaponHand{subtype: :katar}), do: critical * 2
  defp apply_katar_critical(critical, _right_hand), do: critical

  @spec forged_star_damage([map()]) :: non_neg_integer()
  defp forged_star_damage(worn_items) do
    Enum.reduce(worn_items, 0, fn item, damage ->
      with true <- :right_hand in EquipLocation.bitmask_to_location_atoms(item.equip),
           {:ok, %ItemCraft{kind: :forged} = craft} <- ItemCraft.from_map(item.craft) do
        damage + ItemCraft.star_damage(craft)
      else
        _unforged_or_other_slot -> damage
      end
    end)
  end

  defp calculate_trait_slots(stats, formulas, values) do
    bonuses = %{
      patk: Stats.get_status_modifier(stats, :patk) + Stats.get_equipment_modifier(stats, :patk),
      smatk:
        Stats.get_status_modifier(stats, :smatk) + Stats.get_equipment_modifier(stats, :smatk),
      res: Stats.get_status_modifier(stats, :res) + Stats.get_equipment_modifier(stats, :res),
      mres: Stats.get_status_modifier(stats, :mres) + Stats.get_equipment_modifier(stats, :mres),
      hplus:
        Stats.get_status_modifier(stats, :hplus) + Stats.get_equipment_modifier(stats, :hplus),
      crate:
        Stats.get_status_modifier(stats, :crit_rate) +
          Stats.get_equipment_modifier(stats, :crit_rate)
    }

    formulas.trait_slots(values, bonuses)
  end

  defp formula_values(stats) do
    %{
      str: Stats.get_effective_stat(stats, :str),
      agi: Stats.get_effective_stat(stats, :agi),
      vit: Stats.get_effective_stat(stats, :vit),
      int: Stats.get_effective_stat(stats, :int),
      dex: Stats.get_effective_stat(stats, :dex),
      luk: Stats.get_effective_stat(stats, :luk),
      pow: Stats.get_effective_stat(stats, :pow),
      sta: Stats.get_effective_stat(stats, :sta),
      wis: Stats.get_effective_stat(stats, :wis),
      spl: Stats.get_effective_stat(stats, :spl),
      con: Stats.get_effective_stat(stats, :con),
      crt: Stats.get_effective_stat(stats, :crt),
      base_level: stats.progression.base_level
    }
  end

  defp equipped_weapon_type(%Stats{right_hand: %WeaponHand{subtype: subtype}}), do: subtype
  defp equipped_weapon_type(%Stats{equipment: equipment}), do: Stats.weapon_type(equipment)

  defp equipment_primary_stat_bonus(stats, stat_name) do
    Stats.get_equipment_modifier(stats, stat_name) +
      Stats.get_equipment_modifier(stats, :all_stats)
  end

  @doc "Calculates ASPD under the active ruleset."
  @spec calculate_aspd(Stats.t()) :: integer()
  def calculate_aspd(%Stats{} = stats) do
    weapon_atom = equipped_weapon_type(stats)

    case AvailableJobs.job_id_to_name(stats.progression.job_id) do
      {:ok, job_name} ->
        weapon_delay = get_weapon_aspd(job_name, weapon_atom)

        weapon_delay =
          if Stats.shield?(stats.equipment) do
            apply_shield_penalty(weapon_delay, job_name)
          else
            weapon_delay
          end

        inputs = %{
          agi: Stats.get_effective_stat(stats, :agi),
          dex: Stats.get_effective_stat(stats, :dex),
          weapon_delay: weapon_delay,
          left_weapon_delay: left_weapon_delay(stats, job_name),
          ranged?: weapon_atom in @ranged_weapons,
          flat_bonus:
            Stats.get_status_modifier(stats, :aspd) + Stats.get_equipment_modifier(stats, :aspd) +
              Passives.aspd_bonus(stats),
          rate_bonus: aspd_percent_bonus(stats),
          penalty_rate: Stats.get_status_modifier(stats, :aspd_penalty_rate)
        }

        Mechanics.player_formulas().aspd(inputs)

      err ->
        raise "Failed to get job name for ASPD calculation: #{inspect(err)}"
    end
  end

  defp left_weapon_delay(
         %Stats{right_hand: %WeaponHand{}, left_hand: %WeaponHand{subtype: subtype}},
         job_name
       ),
       do: get_weapon_aspd(job_name, subtype)

  defp left_weapon_delay(_stats, _job_name), do: nil

  defp get_job_stats_for_level(job_name, base_level) do
    with {:ok, base_stats} <- JobManagement.get_base_stats_for_level(job_name, base_level),
         {:ok, job} <- JobManagement.get_job_by_name(job_name) do
      %{
        base_hp: base_stats.hp,
        base_sp: base_stats.sp,
        hp_factor: job.hp_factor,
        hp_increase: job.hp_increase,
        sp_increase: job.sp_increase
      }
    else
      _ ->
        raise "Failed to get job stats for level #{base_level} of job #{job_name}"
    end
  end

  defp calculate_max_hp(
         base_hp,
         effective_vit,
         hp_factor,
         hp_increase,
         transcendent?,
         stats
       ) do
    Mechanics.player_formulas().max_hp(%{
      base_hp: base_hp,
      vit: effective_vit,
      equipment_vit: equipment_primary_stat_bonus(stats, :vit),
      hp_factor: hp_factor,
      hp_increase: hp_increase,
      flat_bonus: get_hp_bonus_flat(stats),
      equipment_rate: Stats.get_equipment_modifier(stats, :max_hp_rate),
      modifier_rate: Stats.get_status_modifier(stats, :max_hp_rate),
      transcendent?: transcendent?
    })
  end

  defp calculate_max_sp(base_sp, effective_int, sp_increase, transcendent?, stats) do
    Mechanics.player_formulas().max_sp(%{
      base_sp: base_sp,
      int: effective_int,
      equipment_int: equipment_primary_stat_bonus(stats, :int),
      sp_increase: sp_increase,
      flat_bonus: get_sp_bonus_flat(stats),
      equipment_rate: Stats.get_equipment_modifier(stats, :max_sp_rate),
      modifier_rate:
        Stats.get_status_modifier(stats, :max_sp_rate) + stats.modifiers.passive.max_sp_rate,
      transcendent?: transcendent?
    })
  end

  # Percentage bonuses that accumulate as a delta off 100 (`bAtkRate`,
  # `bMatkRate`). Zero is the common case and must be exact, not a float round-trip.
  @spec apply_rate(integer(), number()) :: integer()
  defp apply_rate(value, 0), do: value
  defp apply_rate(value, rate), do: div(value * (100 + rate), 100)

  defp get_weapon_aspd(job_name, weapon_atom) do
    case JobManagement.get_base_aspd(job_name, weapon_atom) do
      {:ok, aspd} ->
        aspd

      _ ->
        raise "Failed to get base ASPD for job #{job_name} and weapon type #{inspect(weapon_atom)}"
    end
  end

  defp apply_shield_penalty(base_aspd, job_name) do
    case JobManagement.get_base_aspd(job_name, :shield) do
      {:ok, shield_penalty} -> base_aspd + shield_penalty
      _ -> base_aspd
    end
  end

  # Equipment stores :aspd_rate as a full rate (100 = neutral), while status
  # effects store a summable percent delta; both feed the formula's speed channel.
  defp aspd_percent_bonus(%Stats{modifiers: modifiers} = stats) do
    equipment_percent = Map.get(modifiers.equipment, :aspd_rate, 100) - 100
    status_percent = Map.get(modifiers.status_effects, :aspd_rate, 0)

    equipment_percent + status_percent + Passives.aspd_rate_bonus(stats)
  end

  defp get_hp_bonus_flat(%Stats{} = stats),
    do:
      Stats.get_equipment_modifier(stats, :max_hp) + Stats.get_status_modifier(stats, :max_hp) +
        Passives.max_hp_bonus(stats)

  defp get_sp_bonus_flat(%Stats{} = stats), do: Stats.get_equipment_modifier(stats, :max_sp)
end
