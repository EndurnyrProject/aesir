defmodule Aesir.ZoneServer.Unit.Player.Stats.Modifiers do
  @moduledoc """
  The per-source stat modifier maps carried by `Aesir.ZoneServer.Unit.Player.Stats`.

  Defined outside the `Stats` module so `%Modifiers{}` can serve as the struct
  default for `stats.modifiers` — a nested module's struct cannot be used as a
  field default within the module that defines it.
  """

  defstruct equipment: %{},
            status_effects: %{},
            job_bonuses: %{},
            passive: %{},
            statuses_active?: false

  @type t() :: %__MODULE__{
          equipment: map(),
          status_effects: map(),
          job_bonuses: map(),
          passive: map(),
          statuses_active?: boolean()
        }
end

defmodule Aesir.ZoneServer.Unit.Player.Stats do
  @moduledoc """
  Player statistics management for individual character sessions.

  Extends the base Unit.Stats with player-specific features like equipment,
  experience tracking, and various modifier systems. Manages character stats
  with a three-tier architecture:
  - Database Layer: Persistent base stats from Character model
  - Calculation Layer: Runtime stat calculations with modifiers
  - Display Layer: Client synchronization via StatusParams

  This module is designed to work closely with PlayerSession and PlayerState for
  real-time stat calculations and client synchronization.
  """

  import Bitwise

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.JobManagement.TraitJobs
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Stats

  @riding_option_bit Option.id(:riding)
  @novice_high_job_id 4001
  @ranged_weapons [:bow, :musical, :whip, :revolver, :rifle, :gatling, :shotgun, :grenade]

  defmodule PlayerProgression do
    @moduledoc false

    defstruct base_level: nil,
              job_level: nil,
              base_exp: nil,
              job_exp: nil,
              job_id: nil,
              skill_point: nil,
              status_point: nil,
              trait_point: 0,
              learned_skills: %{}

    @type t() :: %__MODULE__{
            base_level: non_neg_integer() | nil,
            job_level: non_neg_integer() | nil,
            base_exp: non_neg_integer() | nil,
            job_exp: non_neg_integer() | nil,
            job_id: non_neg_integer() | nil,
            skill_point: non_neg_integer() | nil,
            status_point: non_neg_integer() | nil,
            trait_point: non_neg_integer(),
            learned_skills: %{integer() => non_neg_integer()}
          }
  end

  defmodule Equipment do
    @moduledoc false

    defstruct [
      :head_top,
      :head_mid,
      :head_low,
      :armor,
      :right_hand,
      :left_hand,
      :garment,
      :shoes,
      :right_accessory,
      :left_accessory,
      :ammo
    ]

    @typedoc """
    Worn equipment derived from the equipped inventory items, keyed by equip
    location. Each populated field holds the item id worn at that location; an
    empty slot is `nil`. This is rebuilt from the inventory whenever equipment
    changes.

    This structure answers "what is worn where" for look and weapon-type
    resolution only. Per-item metadata (refine, cards, forged data) deliberately
    lives on `worn_items` instead, which is the stat and bonus reduction.
    """
    @type t() :: %__MODULE__{
            head_top: non_neg_integer() | nil,
            head_mid: non_neg_integer() | nil,
            head_low: non_neg_integer() | nil,
            armor: non_neg_integer() | nil,
            right_hand: non_neg_integer() | nil,
            left_hand: non_neg_integer() | nil,
            garment: non_neg_integer() | nil,
            shoes: non_neg_integer() | nil,
            right_accessory: non_neg_integer() | nil,
            left_accessory: non_neg_integer() | nil,
            ammo: non_neg_integer() | nil
          }
  end

  @typedoc "Stable identity of one autobonus registration within an inventory row."
  @type autobonus_key :: {pos_integer(), non_neg_integer()}

  @typedoc "An evaluated autobonus registration derived from a worn item."
  @type autobonus_registration :: %{
          item_id: pos_integer(),
          refine: non_neg_integer(),
          source_order: {non_neg_integer(), non_neg_integer()},
          trigger: :attack | :when_hit | {:on_skill, pos_integer()},
          rate: pos_integer(),
          duration_ms: pos_integer(),
          battle_flag: non_neg_integer(),
          primary: EquipScript.program(),
          secondary: EquipScript.program(),
          primary_effects: [EquipScript.effect()],
          secondary_effects: [EquipScript.effect()]
        }

  @typedoc "A direct status desired by at least one currently worn item."
  @type equip_status :: {pos_integer() | :infinite, integer()}

  @typedoc """
  Cached inventory identity and metadata used by equipment refolds.

  A nullable row id is retained only for compatibility with legacy callers. Any
  row whose equipment program contains an autobonus must have a positive id.
  """
  @type worn_item :: %{
          id: pos_integer() | nil,
          nameid: integer(),
          refine: non_neg_integer(),
          equip: non_neg_integer(),
          card0: integer(),
          card1: integer(),
          card2: integer(),
          card3: integer(),
          craft: map() | nil
        }

  defstruct base_stats: nil,
            # Common stats from Unit.Stats
            derived_stats: nil,
            combat_stats: nil,
            current_state: nil,

            # Player-specific fields
            progression: nil,
            equipment: nil,
            modifiers: %Modifiers{},

            # Minimal identity of worn inventory rows (id, nameid, refine, cards, craft), cached by
            # `apply_equipment_modifiers/2` so a recompute without an equipped-items
            # list can still re-evaluate the on_equip programs - their level inputs
            # (BaseLevel/JobLevel) change without any equipment change.
            worn_items: [],

            # Derived proc registrations, live generations, and direct status
            # requirements. Rebuilt or pruned by the deterministic equipment fold.
            equip_autobonuses: %{},
            active_autobonuses: %{},
            equip_statuses: %{},
            right_hand: nil,
            left_hand: nil,

            # Skills granted by worn equipment (`skill <id>,<lv>` in an `on_equip`
            # script), as `%{skill_id => level}`. Rebuilt alongside `modifiers.equipment`
            # on every recompute; read by the skill-list view and player cast authority
            # so an equip-granted skill is castable while worn.
            granted_skills: %{},

            # Denormalized copy of the `:riding` bit of `PlayerState.option`, the
            # single writer's authoritative in-memory value. `MountHandler` keeps this
            # field in sync with the option bit before triggering the status-driven
            # recalc that mount/dismount goes through, so `calculate_combat_stats/1`
            # (which only ever sees a `Stats` struct, never `PlayerState`) can gate
            # mounted passive bonuses (e.g. `KnSpearmastery`) without threading the
            # option bit through every `calculate_stats/3` call site.
            riding: false

  @typedoc """
  Player-specific stats structure extending the base unit stats.

  Includes all common unit stats plus player-specific fields:
  - Equipment tracking
  - Experience and job progression
  - Multiple modifier sources
  """
  @type t() :: %__MODULE__{
          base_stats: Stats.BaseStats.t() | nil,
          derived_stats: Stats.DerivedStats.t() | nil,
          combat_stats: Stats.CombatStats.t() | nil,
          current_state: Stats.CurrentState.t() | nil,
          progression: PlayerProgression.t() | nil,
          equipment: Equipment.t() | nil,
          modifiers: Modifiers.t(),
          worn_items: [worn_item()],
          equip_autobonuses: %{autobonus_key() => autobonus_registration()},
          active_autobonuses: %{autobonus_key() => pos_integer()},
          equip_statuses: %{atom() => equip_status()},
          right_hand: WeaponHand.t() | nil,
          left_hand: WeaponHand.t() | nil,
          granted_skills: %{integer() => non_neg_integer()},
          riding: boolean()
        }

  @doc """
  Creates a Stats struct from a Character model.
  """
  @spec from_character(map()) :: t()
  def from_character(%Character{} = character) do
    base_stats = %Stats.BaseStats{
      str: character.str,
      agi: character.agi,
      vit: character.vit,
      int: character.int,
      dex: character.dex,
      luk: character.luk,
      pow: character.pow,
      sta: character.sta,
      wis: character.wis,
      spl: character.spl,
      con: character.con,
      crt: character.crt
    }

    progression = %PlayerProgression{
      base_level: character.base_level,
      job_level: character.job_level,
      base_exp: character.base_exp,
      job_exp: character.job_exp,
      job_id: character.class || 0,
      skill_point: character.skill_point,
      status_point: character.status_point,
      trait_point: character.trait_point,
      learned_skills: Learned.from_character(character.learned_skills)
    }

    current_state = %Stats.CurrentState{
      hp: character.hp,
      sp: character.sp,
      ap: character.ap
    }

    stats = %__MODULE__{
      base_stats: base_stats,
      progression: progression,
      current_state: current_state,
      equipment: %Equipment{},
      modifiers: %Modifiers{
        equipment: %{},
        status_effects: %{},
        job_bonuses: %{},
        passive: %{}
      },
      riding: riding?(character.option)
    }

    calculate_stats(stats)
  end

  defp riding?(option) when is_integer(option), do: (option &&& @riding_option_bit) != 0
  defp riding?(_option), do: false

  @doc """
  Converts player stats to formula map format for status effect calculations.
  """
  @spec to_formula_map(t()) :: map()
  def to_formula_map(%__MODULE__{} = stats) do
    %{
      # Base stats
      str: stats.base_stats.str,
      agi: stats.base_stats.agi,
      vit: stats.base_stats.vit,
      int: stats.base_stats.int,
      dex: stats.base_stats.dex,
      luk: stats.base_stats.luk,
      # Trait stats
      pow: stats.base_stats.pow,
      sta: stats.base_stats.sta,
      wis: stats.base_stats.wis,
      spl: stats.base_stats.spl,
      con: stats.base_stats.con,
      crt: stats.base_stats.crt,
      # HP/SP
      max_hp: stats.derived_stats.max_hp,
      max_sp: stats.derived_stats.max_sp,
      hp: stats.current_state.hp,
      sp: stats.current_state.sp,
      # Level - use base_level from progression
      level: stats.progression.base_level,
      base_level: stats.progression.base_level,
      job_level: stats.progression.job_level,
      # Combat stats
      atk: stats.combat_stats.atk,
      matk: stats.combat_stats.matk,
      matk_min: stats.combat_stats.matk_min,
      matk_max: stats.combat_stats.matk_max,
      heal_matk_min: stats.combat_stats.heal_matk_min,
      heal_matk_max: stats.combat_stats.heal_matk_max,
      def: stats.combat_stats.def,
      mdef: stats.combat_stats.mdef,
      hit: stats.combat_stats.hit,
      flee: stats.combat_stats.flee,
      critical: stats.combat_stats.critical,
      hplus: stats.combat_stats.hplus,
      heal_power: get_equipment_modifier(stats, :heal_power),
      aspd: stats.derived_stats.aspd
    }
  end

  @doc """
  Calculates all stats from base values and modifiers.

  ## Parameters
  - stats: The Stats struct to calculate
  - player_id: Optional player ID for status effect retrieval
  - equipped_items: Optional list or index-keyed map of equipped inventory items
  """
  @spec calculate_stats(
          t(),
          integer() | nil,
          [InventoryItem.t()] | %{optional(any()) => InventoryItem.t()} | nil
        ) :: t()
  def calculate_stats(%__MODULE__{} = stats, player_id \\ nil, equipped_items \\ nil) do
    stats
    |> apply_job_bonuses()
    |> apply_equipment_modifiers(equipped_items)
    |> apply_status_effects(player_id)
    |> apply_passive_modifiers()
    |> calculate_derived_stats()
    |> calculate_combat_stats()
  end

  @doc """
  Aggregates the STR/DEX/INT/HIT/range bonuses from learned passive skills into
  `modifiers.passive`.

  Runs before `calculate_derived_stats/1` so the passive stat bonuses feed every
  stat derived from them (HIT, ASPD, ATK, MATK, max SP) just like a real stat
  point spent on the attribute.
  """
  @spec apply_passive_modifiers(t()) :: t()
  def apply_passive_modifiers(%__MODULE__{} = stats) do
    passive = %{
      str: Passives.str_bonus(stats),
      dex: Passives.dex_bonus(stats),
      int: Passives.int_bonus(stats),
      hit: Passives.hit_bonus(stats),
      range: Passives.range_bonus(stats),
      max_weight_bonus: Passives.max_weight_bonus(stats),
      max_sp_rate: Passives.max_sp_rate_bonus(stats)
    }

    %{stats | modifiers: Map.put(stats.modifiers, :passive, passive)}
  end

  @doc """
  Applies job-specific stat bonuses based on job level and class.
  """
  @spec apply_job_bonuses(t()) :: t()
  def apply_job_bonuses(%__MODULE__{} = stats) do
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

  @doc """
  Applies equipment modifiers to stats from the equipped inventory items.

  When `equipped_items` is a list or index-keyed map of `InventoryItem`s, this
  rebuilds the worn `Equipment` struct (so weapon-type/shield-dependent
  calculations such as ASPD see the correct gear), caches item instance metadata
  in `worn_items`,
  and folds the flat `item_db` bonuses plus each item's structured `on_equip`
  result into modifiers, proc registrations, and desired direct statuses.
  Surviving active proc generations re-evaluate their primary programs through
  the same equipment merge rules. When `nil`, the fold reruns
  from the cached `worn_items` instead - equipment cannot have changed, but the
  program level inputs (`BaseLevel`/`JobLevel`) follow the current progression,
  so a level-up recompute refreshes level-gated bonuses without threading the
  inventory through every call site. An empty cache has nothing to refold, so
  that case preserves legacy modifier state while clearing derived equipment
  proc and direct-status runtime maps.
  """
  @spec apply_equipment_modifiers(
          t(),
          [InventoryItem.t()] | %{optional(any()) => InventoryItem.t()} | nil
        ) :: t()
  def apply_equipment_modifiers(stats, equipped_items \\ nil)

  def apply_equipment_modifiers(%__MODULE__{worn_items: []} = stats, nil) do
    %{stats | equip_autobonuses: %{}, active_autobonuses: %{}, equip_statuses: %{}}
  end

  def apply_equipment_modifiers(%__MODULE__{} = stats, nil) do
    stats
    |> fold_equipment(stats.worn_items)
    |> put_weapon_hands(stats.worn_items)
  end

  def apply_equipment_modifiers(%__MODULE__{} = stats, equipped_items)
      when is_list(equipped_items) or is_map(equipped_items) do
    worn_items =
      equipped_items
      |> normalize_items()
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
    |> Map.put(:equipment, equipment_from_inventory(equipped_items))
    |> Map.put(:worn_items, worn_items)
    |> fold_equipment(worn_items)
    |> put_weapon_hands(worn_items)
  end

  defp fold_equipment(stats, worn_items) do
    fold = equipment_fold_result(stats, worn_items)
    {equipment_bonuses, granted_skills} = split_granted_skills(fold.bonuses)

    %{
      stats
      | equip_autobonuses: fold.registrations,
        active_autobonuses: fold.active,
        equip_statuses: fold.statuses,
        granted_skills: granted_skills,
        modifiers: %{stats.modifiers | equipment: equipment_bonuses}
    }
  end

  defp equipment_fold_result(stats, worn_items) do
    inputs = equip_script_inputs(stats.progression, equip_stat_params(stats), 0)
    fold = fold_worn_items(worn_items, inputs)
    active = Map.take(stats.active_autobonuses, Map.keys(fold.registrations))

    bonuses =
      active
      |> Enum.sort_by(fn {key, _generation} -> fold.registrations[key].source_order end)
      |> Enum.reduce(fold.bonuses, fn {key, _generation}, acc ->
        registration = Map.fetch!(fold.registrations, key)
        active_inputs = %{inputs | refine: registration.refine}
        result = EquipScript.evaluate(registration.primary, active_inputs)
        merge_equip_modifiers(acc, result.modifiers)
      end)
      |> finalize_equipment_bonuses()

    Map.put(fold, :active, active) |> Map.put(:bonuses, bonuses)
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
  Builds the worn `Equipment` struct from a list (or indexed map) of equipped
  inventory items.

  Each item's `equip` bitmask is decoded into location atoms via
  `EquipLocation.bitmask_to_location_atoms/1` and a map carrying its `nameid`
  and card slots is placed at each resulting location. A two-handed weapon
  (right + left hand) lands in both hand slots so weapon-type resolution reads
  it from `right_hand`.
  """
  @spec equipment_from_inventory([InventoryItem.t()] | %{optional(any()) => InventoryItem.t()}) ::
          Equipment.t()
  def equipment_from_inventory(equipped_items) do
    equipped_items
    |> normalize_items()
    |> Enum.reduce(%Equipment{}, &place_item/2)
  end

  defp place_item(%InventoryItem{equip: equip, nameid: nameid}, equipment) do
    equip
    |> EquipLocation.bitmask_to_location_atoms()
    |> Enum.reduce(equipment, fn location, acc -> put_location(acc, location, nameid) end)
  end

  defp put_location(equipment, location, nameid) do
    if Map.has_key?(equipment, location),
      do: Map.put(equipment, location, nameid),
      else: equipment
  end

  @doc """
  Returns the equipped weapon type atom (the right-hand item's `subtype`), or
  `:fist` when no weapon is worn or the item cannot be resolved.
  """
  @spec weapon_type(Equipment.t()) :: atom()
  def weapon_type(%Equipment{right_hand: nil}), do: :fist

  def weapon_type(%Equipment{right_hand: nameid}) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %ItemDefinition{subtype: subtype}} when is_atom(subtype) and not is_nil(subtype) ->
        subtype

      _ ->
        :fist
    end
  end

  @doc """
  Returns true when a shield is worn: a left-hand item that is not itself a
  weapon (a two-hander occupies the left hand but is a weapon, not a shield).
  """
  @spec shield?(Equipment.t()) :: boolean()
  def shield?(%Equipment{left_hand: nil}), do: false

  def shield?(%Equipment{left_hand: nameid}) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %ItemDefinition{type: type}} -> type != :weapon
      _ -> false
    end
  end

  @doc """
  Returns `:ok` when a shield is worn, `{:error, :requires_shield}` otherwise.

  The shared cast gate for the shield-only skills. Player-only: a mob caster has
  no equipment, so each shield skill skips this check on its mob validation path.
  """
  @spec validate_shield(Equipment.t()) :: :ok | {:error, :requires_shield}
  def validate_shield(%Equipment{} = equipment) do
    if shield?(equipment), do: :ok, else: {:error, :requires_shield}
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
  @spec shield_defense_contribution(t()) :: %{def: non_neg_integer(), mdef: non_neg_integer()}
  def shield_defense_contribution(%__MODULE__{equipment: %Equipment{} = equipment} = stats) do
    if shield?(equipment) do
      without_shield = Enum.reject(stats.worn_items, &worn_in_slot?(&1, :left_hand))
      full = equipment_fold_result(stats, stats.worn_items).bonuses
      reduced = equipment_fold_result(stats, without_shield).bonuses

      %{
        def: max(scaled_equipment_def(full) - scaled_equipment_def(reduced), 0),
        mdef: max(Map.get(full, :mdef, 0) - Map.get(reduced, :mdef, 0), 0)
      }
    else
      %{def: 0, mdef: 0}
    end
  end

  def shield_defense_contribution(%__MODULE__{}), do: %{def: 0, mdef: 0}

  @doc """
  Returns `{weight, refine}` for the equipped left-hand shield, or `nil` when no
  shield is worn.

  `weight` is the shield's item-DB weight in raw units (ten times the in-game
  weight); the shield damage base divides it by ten. `refine` is read from the
  equipped inventory row, since refinement is per-instance and absent from the
  item definition. `inventory` is any enumerable of `InventoryItem`s (e.g. the
  player's inventory values).
  """
  @spec shield_stats(Equipment.t(), Enumerable.t()) ::
          {non_neg_integer(), non_neg_integer()} | nil
  def shield_stats(%Equipment{left_hand: nil}, _inventory), do: nil

  def shield_stats(%Equipment{left_hand: nameid} = equipment, inventory) do
    if shield?(equipment) do
      {shield_weight(nameid), left_hand_refine(inventory)}
    else
      nil
    end
  end

  defp shield_weight(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %ItemDefinition{weight: weight}} -> weight
      _ -> 0
    end
  end

  defp left_hand_refine(inventory) do
    Enum.find_value(inventory, 0, fn %InventoryItem{equip: equip, refine: refine} ->
      if :left_hand in EquipLocation.bitmask_to_location_atoms(equip), do: refine
    end)
  end

  @doc """
  Returns the client view (sprite) id of the equipped weapon, or `0` when bare-handed.
  """
  @spec weapon_view(Equipment.t()) :: non_neg_integer()
  def weapon_view(%Equipment{right_hand: nil}), do: 0

  def weapon_view(%Equipment{right_hand: nameid} = equipment) do
    # A weapon's sprite is its weapon-class view (dagger, one-handed sword, ...),
    # derived from the item subtype. Item DBs only set an explicit `view` for
    # weapons with a unique sprite (e.g. collection weapons); prefer that when
    # present, otherwise fall back to the class so ordinary weapons still render.
    case view_of(nameid) do
      0 -> WeaponTypes.get_weapon_id(weapon_type(equipment))
      view -> view
    end
  end

  @doc """
  Returns the client view (sprite) id of the equipped shield, or `0` when none
  or when the left-hand item is itself a weapon (two-hander occupying both hands).
  """
  @spec shield_view(Equipment.t()) :: non_neg_integer()
  def shield_view(%Equipment{left_hand: left_hand} = equipment) do
    if shield?(equipment), do: view_of(left_hand), else: 0
  end

  @doc """
  Returns the client view (sprite) id of the equipped head-top item, or `0` when none.
  """
  @spec head_top_view(Equipment.t()) :: non_neg_integer()
  def head_top_view(%Equipment{head_top: nil}), do: 0
  def head_top_view(%Equipment{head_top: nameid}), do: view_of(nameid)

  @doc """
  Returns the client view (sprite) id of the equipped head-mid item, or `0` when none.
  """
  @spec head_mid_view(Equipment.t()) :: non_neg_integer()
  def head_mid_view(%Equipment{head_mid: nil}), do: 0
  def head_mid_view(%Equipment{head_mid: nameid}), do: view_of(nameid)

  @doc """
  Returns the client view (sprite) id of the equipped head-low (head-bottom) item, or `0` when none.
  """
  @spec head_bottom_view(Equipment.t()) :: non_neg_integer()
  def head_bottom_view(%Equipment{head_low: nil}), do: 0
  def head_bottom_view(%Equipment{head_low: nameid}), do: view_of(nameid)

  @doc """
  Returns the client view (sprite) id of the equipped garment (robe), or `0` when none.
  """
  @spec robe_view(Equipment.t()) :: non_neg_integer()
  def robe_view(%Equipment{garment: nil}), do: 0
  def robe_view(%Equipment{garment: nameid}), do: view_of(nameid)

  defp normalize_items(items) when is_list(items), do: items

  defp normalize_items(items) when is_map(items) do
    items
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  defp view_of(nil), do: 0

  defp view_of(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %ItemDefinition{view: view}} -> view
      _ -> 0
    end
  end

  @doc """
  Applies temporary status effect modifiers.
  Fetches active status effects for the player and applies their stat modifiers.

  ## Parameters
  - stats: The Stats struct to update
  - player_id: The player ID to get status effects for

  ## Returns
  Updated Stats struct with status effect modifiers applied
  """
  @spec apply_status_effects(t(), integer() | nil) :: t()
  def apply_status_effects(%__MODULE__{} = stats, player_id) when is_integer(player_id) do
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
  @spec apply_status_effects(t(), any()) :: t()
  def apply_status_effects(%__MODULE__{} = stats, _player_id) do
    # Without a valid player_id, we can't get status effects, so return unchanged
    stats
  end

  # Backwards compatibility for the original function signature
  @spec apply_status_effects(t()) :: t()
  def apply_status_effects(%__MODULE__{} = stats) do
    # Without a player_id, we can't get status effects, so return unchanged
    stats
  end

  @doc "Calculates mode-specific derived stats from prepared job and modifier inputs."
  @spec calculate_derived_stats(t()) :: t()
  def calculate_derived_stats(%__MODULE__{} = stats) do
    effective_vit = get_effective_stat(stats, :vit)
    effective_int = get_effective_stat(stats, :int)
    base_level = stats.progression.base_level

    case AvailableJobs.job_id_to_name(stats.progression.job_id) do
      {:ok, job_name} ->
        # Get all job-related stats
        job_stats = get_job_stats_for_level(job_name, base_level)

        # Calculate HP/SP with modifiers
        transcendent? = transcendent_job?(stats.progression.job_id)

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

        derived_stats = %Stats.DerivedStats{
          max_hp: max_hp,
          max_sp: max_sp,
          aspd: aspd,
          max_ap: max_ap
        }

        %{stats | derived_stats: derived_stats}
        |> clamp_current_to_max(
          max_hp,
          get_status_modifier(stats, :max_hp_rate),
          max_sp,
          get_status_modifier(stats, :max_sp_rate)
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
         %__MODULE__{current_state: %{hp: hp, sp: sp} = current} = stats,
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

  defp clamp_ap(%__MODULE__{current_state: %{ap: ap} = current} = stats, max_ap)
       when is_integer(ap) do
    %{stats | current_state: %{current | ap: min(ap, max_ap)}}
  end

  defp clamp_ap(stats, _max_ap), do: stats

  @doc "Calculates combat-related stats under the active ruleset."
  @spec calculate_combat_stats(t()) :: t()
  def calculate_combat_stats(%__MODULE__{} = stats) do
    alias Aesir.ZoneServer.Unit.Player.CombatCalculations, as: PlayerCombatCalc

    formulas = Mechanics.player_formulas()
    values = formula_values(stats)

    critical_basis =
      formulas.critical(%{luk: values.luk, raw_luk: stats.base_stats.luk})

    base_atk =
      values
      |> formulas.base_atk(equipped_weapon_type(stats) in @ranged_weapons)
      |> apply_rate(get_equipment_modifier(stats, :atk_rate))

    %{min: base_matk_min, max: base_matk_max} = formulas.base_matk(values)
    base_def = formulas.base_def(values)
    skill_passive_atk = Passives.atk_bonus(stats)
    passive_atk = skill_passive_atk + forged_star_damage(stats.worn_items)
    passive_critical = Passives.critical_bonus(stats)

    flat_critical =
      get_status_modifier(stats, :critical) + get_equipment_modifier(stats, :critical)

    {critical, critical_rate} =
      calculate_critical(
        critical_basis,
        passive_critical,
        flat_critical,
        get_status_modifier(stats, :critical_rate),
        stats.right_hand
      )

    trait_slots = calculate_trait_slots(stats, formulas, values)

    flat_matk = get_status_modifier(stats, :matk) + get_equipment_modifier(stats, :matk)
    wmatk_min = Map.get(stats.modifiers.equipment, :wmatk_min, 0)
    wmatk_max = Map.get(stats.modifiers.equipment, :wmatk_max, 0)
    matk_rate = get_equipment_modifier(stats, :matk_rate)
    matk_min = apply_rate(base_matk_min + wmatk_min + flat_matk, matk_rate)
    matk_max = apply_rate(base_matk_max + wmatk_max + flat_matk, matk_rate)

    # Heal MATK excludes flat item and status MATK while retaining weapon variance.
    heal_matk_min = base_matk_min + wmatk_min
    heal_matk_max = base_matk_max + wmatk_max

    hit =
      stats
      |> PlayerCombatCalc.calculate_hit()
      |> apply_rate(get_equipment_modifier(stats, :hit_rate))
      |> max(0)

    combat_stats = %Stats.CombatStats{
      hit: hit,
      flee: PlayerCombatCalc.calculate_flee(stats),
      critical: critical,
      critical_rate: critical_rate,
      perfect_dodge: PlayerCombatCalc.calculate_perfect_dodge(stats),
      atk:
        base_atk + get_status_modifier(stats, :atk) + get_equipment_modifier(stats, :atk) +
          skill_passive_atk,
      matk_min: matk_min,
      matk_max: matk_max,
      matk: matk_max,
      heal_matk_min: heal_matk_min,
      heal_matk_max: heal_matk_max,
      def:
        base_def + get_status_modifier(stats, :def) +
          scaled_equipment_def(stats.modifiers.equipment),
      mdef: get_status_modifier(stats, :mdef) + get_equipment_modifier(stats, :mdef),
      soft_mdef: formulas.soft_mdef(values),
      passive_atk: passive_atk,
      hit_rate_bonus_pct: Passives.hit_rate_bonus_pct(stats),
      patk: trait_slots.patk,
      smatk: trait_slots.smatk,
      res: trait_slots.res,
      mres: trait_slots.mres,
      hplus: trait_slots.hplus,
      crate: trait_slots.crate,
      overrefine_band: get_equipment_modifier(stats, :overrefine_band),
      ignore_size_penalty: get_status_flag(stats, :ignore_size_penalty),
      max_weapon_damage: get_status_flag(stats, :max_weapon_damage)
    }

    %{stats | combat_stats: combat_stats}
  end

  @spec scaled_equipment_def(map()) :: integer()
  defp scaled_equipment_def(equipment_modifiers) do
    raw_def = Map.get(equipment_modifiers, :def, 0)
    rate = max(0, 100 + Map.get(equipment_modifiers, :def_rate, 0))
    div(raw_def * rate, 100)
  end

  defp calculate_critical(
         %{strategy: :display_first} = basis,
         passive_critical,
         flat_critical,
         critical_rate,
         right_hand
       ) do
    critical =
      trunc(
        (basis.display_base + div(passive_critical, 10) + flat_critical) *
          (100 + critical_rate) / 100
      )
      |> apply_katar_critical(right_hand)

    roll_rate = basis.roll_rate + (critical - basis.roll_display_base) * 10
    {critical, roll_rate}
  end

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
      patk: get_status_modifier(stats, :patk) + get_equipment_modifier(stats, :patk),
      smatk: get_status_modifier(stats, :smatk) + get_equipment_modifier(stats, :smatk),
      res: get_status_modifier(stats, :res) + get_equipment_modifier(stats, :res),
      mres: get_status_modifier(stats, :mres) + get_equipment_modifier(stats, :mres),
      hplus: get_status_modifier(stats, :hplus) + get_equipment_modifier(stats, :hplus),
      crate: get_status_modifier(stats, :crit_rate) + get_equipment_modifier(stats, :crit_rate)
    }

    formulas.trait_slots(values, bonuses)
  end

  defp formula_values(stats) do
    %{
      str: get_effective_stat(stats, :str),
      agi: get_effective_stat(stats, :agi),
      vit: get_effective_stat(stats, :vit),
      int: get_effective_stat(stats, :int),
      dex: get_effective_stat(stats, :dex),
      luk: get_effective_stat(stats, :luk),
      pow: get_effective_stat(stats, :pow),
      sta: get_effective_stat(stats, :sta),
      wis: get_effective_stat(stats, :wis),
      spl: get_effective_stat(stats, :spl),
      con: get_effective_stat(stats, :con),
      crt: get_effective_stat(stats, :crt),
      base_level: stats.progression.base_level
    }
  end

  defp equipped_weapon_type(%__MODULE__{right_hand: %WeaponHand{subtype: subtype}}), do: subtype
  defp equipped_weapon_type(%__MODULE__{equipment: equipment}), do: weapon_type(equipment)

  @doc """
  Gets the effective value of a stat including all modifiers.
  """
  @spec get_effective_stat(t(), atom()) :: integer()
  def get_effective_stat(%__MODULE__{} = stats, stat_name)
      when stat_name in [
             :str,
             :agi,
             :vit,
             :int,
             :dex,
             :luk,
             :pow,
             :sta,
             :wis,
             :spl,
             :con,
             :crt
           ] do
    base_value = Map.get(stats.base_stats, stat_name, 0)

    job_bonus = Map.get(stats.modifiers.job_bonuses, stat_name, 0)
    equipment_bonus = Map.get(stats.modifiers.equipment, stat_name, 0)
    status_bonus = Map.get(stats.modifiers.status_effects, stat_name, 0)
    passive_bonus = stats.modifiers |> Map.get(:passive, %{}) |> Map.get(stat_name, 0)

    base_value + job_bonus + equipment_bonus + status_bonus + passive_bonus +
      all_stats_bonus(stats, stat_name)
  end

  # `bonus bAllStats,n` grants n to each of the six primary stats only; the
  # trait stats (POW/STA/WIS/SPL/CON/CRT) have their own `bAllTraitStats`.
  @primary_stats [:str, :agi, :vit, :int, :dex, :luk]

  defp all_stats_bonus(%__MODULE__{} = stats, stat_name) when stat_name in @primary_stats do
    get_equipment_modifier(stats, :all_stats)
  end

  defp all_stats_bonus(%__MODULE__{}, _stat_name), do: 0

  defp equipment_primary_stat_bonus(stats, stat_name) do
    get_equipment_modifier(stats, stat_name) + get_equipment_modifier(stats, :all_stats)
  end

  @doc """
  Gets all status effect modifiers for a specific stat or property.
  This is useful for applying specific types of modifiers from status effects.

  ## Parameters
  - stats: The Stats struct
  - modifier_key: The modifier to look up (e.g., :hit, :flee, :aspd_rate)

  ## Returns
  The combined value of all modifiers for the given key, or 0 if none exist
  """
  @spec get_status_modifier(t(), atom()) :: number()
  def get_status_modifier(%__MODULE__{} = stats, modifier_key) do
    Map.get(stats.modifiers.status_effects, modifier_key, 0)
  end

  @doc """
  Gets a boolean status-effect flag (e.g. `:ignore_size_penalty`), defaulting to
  `false` when no active status contributes it.

  Status modifiers are not all numeric: a few statuses contribute `true` as a
  switch rather than a magnitude, so those keys must be read through this
  accessor instead of `get_status_modifier/2`.
  """
  @spec get_status_flag(t(), atom()) :: boolean()
  def get_status_flag(%__MODULE__{} = stats, modifier_key) do
    Map.get(stats.modifiers.status_effects, modifier_key, false) == true
  end

  @doc """
  Gets the combined equipment modifier for a given key, or 0 if none exist. The
  key is a flat atom (e.g. `:atk`, `:def`, `:matk`) or a parameterized tuple
  (e.g. `{:add_item_heal, item_id}`).
  """
  @spec get_equipment_modifier(t(), atom() | {atom(), term()}) :: number()
  def get_equipment_modifier(%__MODULE__{} = stats, modifier_key) do
    Map.get(stats.modifiers.equipment, modifier_key, 0)
  end

  @doc """
  Gets the combined percentage bonus applied to HP recovery from consumable items.
  """
  @spec get_item_heal_rate(t()) :: number()
  def get_item_heal_rate(%__MODULE__{} = stats) do
    get_equipment_modifier(stats, :item_heal_rate) + get_status_modifier(stats, :item_heal_rate)
  end

  @doc """
  Checks if the player has a specific status flag set by status effects.
  This is used for boolean properties like 'endure' or 'hiding'.

  ## Parameters
  - stats: The Stats struct
  - flag: The flag to check for (e.g., :endure, :hiding)

  ## Returns
  Boolean indicating whether the flag is set
  """
  @spec has_status_flag?(t(), atom()) :: boolean()
  def has_status_flag?(%__MODULE__{} = stats, flag) do
    Map.get(stats.modifiers.status_effects, flag, false)
  end

  @doc "Calculates ASPD under the active ruleset."
  @spec calculate_aspd(t()) :: integer()
  def calculate_aspd(%__MODULE__{} = stats) do
    weapon_atom = equipped_weapon_type(stats)

    case AvailableJobs.job_id_to_name(stats.progression.job_id) do
      {:ok, job_name} ->
        weapon_delay = get_weapon_aspd(job_name, weapon_atom)

        weapon_delay =
          if shield?(stats.equipment) do
            apply_shield_penalty(weapon_delay, job_name)
          else
            weapon_delay
          end

        inputs = %{
          agi: get_effective_stat(stats, :agi),
          dex: get_effective_stat(stats, :dex),
          weapon_delay: weapon_delay,
          left_weapon_delay: left_weapon_delay(stats, job_name),
          ranged?: weapon_atom in @ranged_weapons,
          flat_bonus:
            get_status_modifier(stats, :aspd) + get_equipment_modifier(stats, :aspd) +
              Passives.aspd_bonus(stats),
          rate_bonus: aspd_percent_bonus(stats),
          penalty_rate: get_status_modifier(stats, :aspd_penalty_rate)
        }

        Mechanics.player_formulas().aspd(inputs)

      err ->
        raise "Failed to get job name for ASPD calculation: #{inspect(err)}"
    end
  end

  defp left_weapon_delay(
         %__MODULE__{right_hand: %WeaponHand{}, left_hand: %WeaponHand{subtype: subtype}},
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
      equipment_rate: get_equipment_modifier(stats, :max_hp_rate),
      modifier_rate: get_status_modifier(stats, :max_hp_rate),
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
      equipment_rate: get_equipment_modifier(stats, :max_sp_rate),
      modifier_rate:
        get_status_modifier(stats, :max_sp_rate) + stats.modifiers.passive.max_sp_rate,
      transcendent?: transcendent?
    })
  end

  defp transcendent_job?(job_id),
    do: JobLineage.descendant_or_self?(job_id, @novice_high_job_id)

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
  defp aspd_percent_bonus(%__MODULE__{modifiers: modifiers}) do
    equipment_percent = Map.get(modifiers.equipment, :aspd_rate, 100) - 100
    status_percent = Map.get(modifiers.status_effects, :aspd_rate, 0)

    equipment_percent + status_percent
  end

  defp get_hp_bonus_flat(%__MODULE__{} = stats),
    do: get_equipment_modifier(stats, :max_hp) + Passives.max_hp_bonus(stats)

  defp get_sp_bonus_flat(%__MODULE__{} = stats), do: get_equipment_modifier(stats, :max_sp)

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

  @spec equip_stat_params(t()) :: %{atom() => integer()}
  defp equip_stat_params(%__MODULE__{base_stats: base, modifiers: %Modifiers{job_bonuses: job}})
       when not is_nil(base) do
    Map.new(@stat_param_keys, fn stat ->
      {stat, Map.get(base, stat, 0) + Map.get(job, stat, 0)}
    end)
  end

  defp equip_stat_params(%__MODULE__{}), do: %{}

  defp fold_worn_items(worn_items, inputs) do
    worn_items
    |> Enum.with_index()
    |> Enum.reduce(
      %{bonuses: empty_equipment_bonuses(), registrations: %{}, statuses: %{}},
      fn {item, worn_ordinal}, fold -> fold_worn_item(item, worn_ordinal, fold, inputs) end
    )
  end

  defp fold_worn_item(item, worn_ordinal, fold, inputs) do
    case ItemManagement.get_item_by_id(item.nameid) do
      {:ok, %ItemDefinition{} = item_def} ->
        item_inputs = %{inputs | refine: item.refine}
        result = evaluate_equip_script(item_def.on_equip, item_inputs)

        %{
          bonuses:
            fold.bonuses
            |> accumulate_item_bonus(item_def, item.refine)
            |> merge_equip_modifiers(result.modifiers),
          registrations:
            install_autobonuses(
              fold.registrations,
              item_def.on_equip,
              item,
              item_inputs,
              worn_ordinal
            ),
          statuses: install_equip_statuses(fold.statuses, result.effects)
        }

      _ ->
        fold
    end
  end

  defp install_autobonuses(registrations, nil, _item, _inputs, _worn_ordinal),
    do: registrations

  defp install_autobonuses(registrations, program, item, inputs, worn_ordinal) do
    {_next_slot, lexical_registrations} = isolate_autobonuses(program, 0)

    install_lexical_autobonuses(
      lexical_registrations,
      registrations,
      item,
      inputs,
      worn_ordinal
    )
  end

  defp install_lexical_autobonuses([], registrations, _item, _inputs, _worn_ordinal),
    do: registrations

  defp install_lexical_autobonuses(slots, registrations, item, inputs, worn_ordinal) do
    row_id = registration_row_id!(item)

    Enum.reduce(slots, registrations, fn slot, acc ->
      install_autobonus_slot(acc, slot, row_id, item, inputs, worn_ordinal)
    end)
  end

  defp install_autobonus_slot(
         registrations,
         {lexical_slot, isolated_program},
         row_id,
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
            item_id: item.nameid,
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
      true -> Map.update(acc, key, value, &(&1 + value))
    end
  end

  defp merge_equip_bonus(acc, key, value), do: Map.put(acc, key, value)

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

  @doc """
  The skills granted by the wearer's currently worn equipment (the `on_equip`
  `skill` command), as `%{skill_id => level}`. Empty when nothing worn grants a
  skill.
  """
  @spec granted_skills(t()) :: %{integer() => non_neg_integer()}
  def granted_skills(%__MODULE__{granted_skills: granted}) when is_map(granted), do: granted
  def granted_skills(%__MODULE__{}), do: %{}

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
