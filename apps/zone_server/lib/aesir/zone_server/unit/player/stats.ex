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
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.TraitJobs
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Stats

  @riding_option_bit Option.id(:riding)

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

  defstruct [
    # Common stats from Unit.Stats
    base_stats: nil,
    derived_stats: nil,
    combat_stats: nil,
    current_state: nil,

    # Player-specific fields
    progression: nil,
    equipment: nil,
    modifiers: %Modifiers{},

    # Minimal identity of the worn items ({nameid, refine, card slots}), cached by
    # `apply_equipment_modifiers/2` so a recompute without an equipped-items
    # list can still re-evaluate the on_equip programs - their level inputs
    # (BaseLevel/JobLevel) change without any equipment change.
    worn_items: [],

    # Denormalized copy of the `:riding` bit of `PlayerState.option`, the
    # single writer's authoritative in-memory value. `MountHandler` keeps this
    # field in sync with the option bit before triggering the status-driven
    # recalc that mount/dismount goes through, so `calculate_combat_stats/1`
    # (which only ever sees a `Stats` struct, never `PlayerState`) can gate
    # mounted passive bonuses (e.g. `KnSpearmastery`) without threading the
    # option bit through every `calculate_stats/3` call site.
    riding: false
  ]

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
          worn_items: [
            %{
              nameid: integer(),
              refine: integer(),
              equip: integer(),
              card0: integer(),
              card1: integer(),
              card2: integer(),
              card3: integer()
            }
          ],
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
  This is the main calculation pipeline following rAthena patterns.

  ## Parameters
  - stats: The Stats struct to calculate
  - player_id: Optional player ID for status effect retrieval
  - equipped_items: Optional list of equipped inventory items
  """
  @spec calculate_stats(t(), integer() | nil, [any()] | nil) :: t()
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
  Aggregates the DEX/INT/HIT/range bonuses from learned passive skills into
  `modifiers.passive`.

  Runs before `calculate_derived_stats/1` so the passive DEX/INT feed every
  DEX/INT-derived stat (HIT, ASPD, MATK, max SP) just like a real stat point,
  matching rAthena (e.g. Owl's Eye).
  """
  @spec apply_passive_modifiers(t()) :: t()
  def apply_passive_modifiers(%__MODULE__{} = stats) do
    passive = %{
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

  When `equipped_items` is a list of `InventoryItem`s, this rebuilds the worn
  `Equipment` struct (so weapon-type/shield-dependent calculations such as
  ASPD see the correct gear), caches the `{nameid, refine, card slots}` maps in
  `worn_items`, and folds the flat `item_db` bonuses plus each item's
  `on_equip` program into `modifiers.equipment`. When `nil`, the fold reruns
  from the cached `worn_items` instead - equipment cannot have changed, but the
  program level inputs (`BaseLevel`/`JobLevel`) follow the current progression,
  so a level-up recompute refreshes level-gated bonuses without threading the
  inventory through every call site. An empty cache has nothing to refold, so
  that case keeps the stats untouched.
  """
  @spec apply_equipment_modifiers(t(), [InventoryItem.t()] | nil) :: t()
  def apply_equipment_modifiers(stats, equipped_items \\ nil)

  def apply_equipment_modifiers(%__MODULE__{worn_items: []} = stats, nil), do: stats

  def apply_equipment_modifiers(%__MODULE__{} = stats, nil) do
    equipment_bonuses = calculate_equipment_bonuses(stats.worn_items, stats.progression)
    %{stats | modifiers: %{stats.modifiers | equipment: equipment_bonuses}}
  end

  def apply_equipment_modifiers(%__MODULE__{} = stats, equipped_items)
      when is_list(equipped_items) do
    worn_items =
      equipped_items
      |> normalize_items()
      |> Enum.map(
        &%{
          nameid: &1.nameid,
          refine: &1.refine,
          equip: &1.equip,
          card0: &1.card0,
          card1: &1.card1,
          card2: &1.card2,
          card3: &1.card3
        }
      )

    equipment_bonuses = calculate_equipment_bonuses(worn_items, stats.progression)

    %{
      stats
      | equipment: equipment_from_inventory(equipped_items),
        worn_items: worn_items,
        modifiers: %{stats.modifiers | equipment: equipment_bonuses}
    }
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
  defp normalize_items(items) when is_map(items), do: Map.values(items)

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

  @doc """
  Calculates derived stats (HP, SP) using rAthena Post-Renewal formulas.

  HP Formula: base_hp[level] * (1.0 + vit * 0.01) + bonuses
  SP Formula: base_sp[level] * (1.0 + int * 0.01) + bonuses
  """
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
        max_hp =
          calculate_max_hp(
            job_stats.base_hp,
            effective_vit,
            job_stats.hp_factor,
            job_stats.hp_increase,
            stats
          )

        max_sp = calculate_max_sp(job_stats.base_sp, effective_int, job_stats.sp_increase, stats)

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

  @doc """
  Calculates combat-related stats (hit, flee, critical, atk, matk, def).
  Uses the new CombatCalculations behavior for consistent calculations.
  """
  @spec calculate_combat_stats(t()) :: t()
  def calculate_combat_stats(%__MODULE__{} = stats) do
    alias Aesir.ZoneServer.Unit.Player.CombatCalculations, as: PlayerCombatCalc

    base_critical = calculate_base_critical(stats)
    base_atk = apply_rate(calculate_base_atk(stats), get_equipment_modifier(stats, :atk_rate))
    base_matk = calculate_base_matk(stats)
    base_def = calculate_base_def(stats)
    passive_atk = Passives.atk_bonus(stats)
    passive_critical = Passives.critical_bonus(stats)
    passive_critical_display = div(passive_critical, 10)

    # Effective trait stats feed the six SP-A combat slots (rows 5-10).
    pow_eff = get_effective_stat(stats, :pow)
    sta_eff = get_effective_stat(stats, :sta)
    wis_eff = get_effective_stat(stats, :wis)
    spl_eff = get_effective_stat(stats, :spl)
    con_eff = get_effective_stat(stats, :con)
    crt_eff = get_effective_stat(stats, :crt)

    flat_matk = get_status_modifier(stats, :matk) + get_equipment_modifier(stats, :matk)
    wmatk_min = Map.get(stats.modifiers.equipment, :wmatk_min, 0)
    wmatk_max = Map.get(stats.modifiers.equipment, :wmatk_max, 0)
    matk_rate = get_equipment_modifier(stats, :matk_rate)
    matk_min = apply_rate(base_matk + wmatk_min + flat_matk, matk_rate)
    matk_max = apply_rate(base_matk + wmatk_max + flat_matk, matk_rate)

    # Heal MATK band excludes flat item/status MATK: rAthena's RE heal
    # (skill.cpp:705-729) uses status_base_matk + weapon variance ONLY.
    heal_matk_min = base_matk + wmatk_min
    heal_matk_max = base_matk + wmatk_max

    combat_stats = %Stats.CombatStats{
      hit: PlayerCombatCalc.calculate_hit(stats),
      flee: PlayerCombatCalc.calculate_flee(stats),
      critical:
        trunc(
          (base_critical + passive_critical_display + get_status_modifier(stats, :critical) +
             get_equipment_modifier(stats, :critical)) *
            (100 + get_status_modifier(stats, :critical_rate)) / 100
        ),
      perfect_dodge: PlayerCombatCalc.calculate_perfect_dodge(stats),
      atk:
        base_atk + get_status_modifier(stats, :atk) + get_equipment_modifier(stats, :atk) +
          passive_atk,
      matk_min: matk_min,
      matk_max: matk_max,
      matk: matk_max,
      heal_matk_min: heal_matk_min,
      heal_matk_max: heal_matk_max,
      def: base_def + get_status_modifier(stats, :def) + get_equipment_modifier(stats, :def),
      mdef: get_status_modifier(stats, :mdef) + get_equipment_modifier(stats, :mdef),
      soft_mdef: calculate_soft_mdef(stats),
      passive_atk: passive_atk,
      patk: combat_modifier(stats, :patk, div(pow_eff, 3) + div(con_eff, 5)),
      smatk: combat_modifier(stats, :smatk, div(spl_eff, 3) + div(con_eff, 5)),
      res: combat_modifier(stats, :res, sta_eff + div(sta_eff, 3) * 5),
      mres: combat_modifier(stats, :mres, wis_eff + div(wis_eff, 3) * 5),
      hplus: combat_modifier(stats, :hplus, crt_eff),
      crate: combat_modifier(stats, :crate, div(crt_eff, 3)),
      overrefine_band: get_equipment_modifier(stats, :overrefine_band)
    }

    %{stats | combat_stats: combat_stats}
  end

  defp calculate_base_critical(%__MODULE__{} = stats) do
    effective_luk = get_effective_stat(stats, :luk)

    # Basic formula: critical = LUK / 3
    trunc(effective_luk / 3)
  end

  defp calculate_base_atk(%__MODULE__{} = stats) do
    effective_str = get_effective_stat(stats, :str)
    effective_pow = get_effective_stat(stats, :pow)

    # Basic formula: atk = STR + base level / 4 (+ 5 * POW, row 1)
    base_level = stats.progression.base_level
    trunc(effective_str + base_level / 4) + 5 * effective_pow
  end

  defp calculate_base_def(%__MODULE__{} = stats) do
    effective_vit = get_effective_stat(stats, :vit)

    # Basic formula: def = VIT/2 + base level / 6
    base_level = stats.progression.base_level
    trunc(effective_vit / 2 + base_level / 6)
  end

  # Verified vs rAthena status_base_matk_min/max for BL_PC (status.cpp:2571/2590):
  # INT + INT/2 + DEX/5 + LUK/3 + level/4 + 5*SPL (row 2). PC min == max (no
  # inherent spread).
  defp calculate_base_matk(%__MODULE__{} = stats) do
    effective_int = get_effective_stat(stats, :int)
    effective_dex = get_effective_stat(stats, :dex)
    effective_luk = get_effective_stat(stats, :luk)
    effective_spl = get_effective_stat(stats, :spl)
    base_level = stats.progression.base_level

    effective_int + div(effective_int, 2) + div(effective_dex, 5) + div(effective_luk, 3) +
      div(base_level, 4) + 5 * effective_spl
  end

  defp calculate_soft_mdef(%__MODULE__{} = stats) do
    effective_int = get_effective_stat(stats, :int)
    effective_dex = get_effective_stat(stats, :dex)
    effective_vit = get_effective_stat(stats, :vit)
    base_level = stats.progression.base_level

    effective_int + div(base_level, 4) + div(effective_dex + effective_vit, 5)
  end

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
  Gets the combined flat equipment modifier for a given key (e.g. `:atk`,
  `:def`, `:matk`), or 0 if none exist.
  """
  @spec get_equipment_modifier(t(), atom()) :: number()
  def get_equipment_modifier(%__MODULE__{} = stats, modifier_key) do
    Map.get(stats.modifiers.equipment, modifier_key, 0)
  end

  # The trait derivation term is summed with the status/equipment modifiers
  # BEFORE the 0..SHRT_MAX clamp, matching rAthena's cap_value over the full
  # sum (status.cpp:2668/2672/2676/2680/2684/2688).
  defp combat_modifier(%__MODULE__{} = stats, modifier_key, trait_term) do
    (get_status_modifier(stats, modifier_key) + get_equipment_modifier(stats, modifier_key) +
       trait_term)
    |> clamp(0, 32_767)
  end

  defp clamp(value, lo, hi), do: value |> max(lo) |> min(hi)

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

  @ranged_weapons [:bow, :musical, :whip, :revolver, :rifle, :gatling, :shotgun, :grenade]

  @doc """
  Calculates ASPD (Attack Speed) following the renewal formula.

  The stat contribution is:
  - Ranged weapons: sqrt(DEX² / 7 + AGI² / 2) / 4
  - Other weapons: sqrt(DEX² / 5 + AGI² / 2) / 4

  added to a base of 196, minus the job's per-weapon delay (plus the shield
  penalty). Flat ASPD bonuses (potions, passive skills) scale with AGI / 200;
  percentage bonuses grant their share of the distance to 195 ASPD:
  max(195 - aspd, 2) * percent / 100.
  """
  @spec calculate_aspd(t()) :: integer()
  def calculate_aspd(%__MODULE__{} = stats) do
    effective_agi = get_effective_stat(stats, :agi)
    effective_dex = get_effective_stat(stats, :dex)
    weapon_atom = weapon_type(stats.equipment)
    has_shield = shield?(stats.equipment)

    case AvailableJobs.job_id_to_name(stats.progression.job_id) do
      {:ok, job_name} ->
        weapon_delay = get_weapon_aspd(job_name, weapon_atom)

        weapon_delay =
          if has_shield do
            apply_shield_penalty(weapon_delay, job_name)
          else
            weapon_delay
          end

        stat_term =
          if weapon_atom in @ranged_weapons do
            effective_dex * effective_dex / 7 + effective_agi * effective_agi / 2
          else
            effective_dex * effective_dex / 5 + effective_agi * effective_agi / 2
          end

        base_aspd = :math.sqrt(stat_term) * 0.25 + 196

        flat_bonus =
          get_status_modifier(stats, :aspd) + get_equipment_modifier(stats, :aspd) +
            Passives.aspd_bonus(stats)

        final_aspd =
          trunc(base_aspd + flat_bonus * effective_agi / 200) - min(weapon_delay, 200)

        final_aspd =
          final_aspd + div(max(195 - final_aspd, 2) * aspd_percent_bonus(stats), 100)

        final_aspd
        |> apply_aspd_penalty(get_status_modifier(stats, :aspd_penalty_rate))
        |> min(193)
        |> max(0)

      err ->
        raise "Failed to get job name for ASPD calculation: #{inspect(err)}"
    end
  end

  defp apply_aspd_penalty(aspd, penalty_rate) do
    200 - div((200 - aspd) * (1_000 + penalty_rate), 1_000)
  end

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

  defp calculate_max_hp(base_hp, effective_vit, hp_factor, hp_increase, stats) do
    # Apply VIT modifier
    hp_with_vit = trunc(base_hp * (1.0 + effective_vit * 0.01))

    # Apply job-specific HP factor if any
    hp_with_factor =
      if hp_factor > 0 do
        trunc(hp_with_vit * (100 + hp_factor) / 100)
      else
        hp_with_vit
      end

    # Apply increases and bonuses
    total_hp = hp_with_factor + hp_increase + get_hp_bonus_flat(stats)

    total_hp
    |> apply_max_rate(
      get_status_modifier(stats, :max_hp_rate) + get_equipment_modifier(stats, :max_hp_rate)
    )
    |> max(1)
  end

  defp calculate_max_sp(base_sp, effective_int, sp_increase, stats) do
    # Apply INT modifier
    sp_with_int = trunc(base_sp * (1.0 + effective_int * 0.01))

    # Apply increases and bonuses
    total_sp = sp_with_int + sp_increase + get_sp_bonus_flat(stats)

    total_sp
    |> apply_max_rate(
      get_status_modifier(stats, :max_sp_rate) + get_equipment_modifier(stats, :max_sp_rate) +
        stats.modifiers.passive.max_sp_rate
    )
    |> max(1)
  end

  @spec apply_max_rate(integer(), number()) :: integer()
  defp apply_max_rate(value, rate), do: trunc(value * (100 + rate) / 100)

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

  # Equipment stores :aspd_rate as a full rate (100 = neutral), status effects
  # as a summable percent delta; both sum into one renewal percent.
  defp aspd_percent_bonus(%__MODULE__{modifiers: modifiers}) do
    equipment_percent = Map.get(modifiers.equipment, :aspd_rate, 100) - 100
    status_percent = Map.get(modifiers.status_effects, :aspd_rate, 0)

    equipment_percent + status_percent
  end

  defp get_hp_bonus_flat(%__MODULE__{} = stats),
    do: get_equipment_modifier(stats, :max_hp) + Passives.max_hp_bonus(stats)

  defp get_sp_bonus_flat(%__MODULE__{} = stats), do: get_equipment_modifier(stats, :max_sp)

  # Sums the flat item_db bonuses (attack -> atk, defense -> def) across the
  # equipped items. Weapon MATK (a magic weapon's `magic_attack`) becomes a
  # renewal variance band (`wmatk_min`/`wmatk_max`) while non-weapon MATK
  # (cards/armor enchants) stays a flat `matk` bonus. Bonus scripts and card
  # effects are intentionally out of scope here; that is the future
  # item-script engine's job. `aspd_rate` defaults to 100 (no modifier).
  #
  # Refined items additionally fold in `RefineDatabase.level_info/3` bonuses
  # (rAthena status.cpp:3955-4096): weapon ATK/MATK, the overrefine band, and
  # the wlv5/armor-lv2 trait riders accumulate alongside the flat bonuses.
  # Armor refine DEF is summed raw into `refine_def` and folded into `def`
  # once, after the reduce, per the rAthena `(refinedef+50)/100` rounding.
  defp calculate_equipment_bonuses(worn_items, progression) do
    bonuses =
      worn_items
      |> Enum.reduce(
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
        },
        fn item, acc ->
          case ItemManagement.get_item_by_id(item.nameid) do
            {:ok, %ItemDefinition{} = item_def} ->
              acc
              |> accumulate_item_bonus(item_def, item.refine)
              |> apply_equip_script(item_def.on_equip, item.refine, progression)

            _ ->
              acc
          end
        end
      )

    bonuses
    |> Map.update!(:def, &(&1 + div(bonuses.refine_def + 50, 100)))
    |> Map.delete(:refine_def)
  end

  # Folds an item's `on_equip` bonus program (evaluated against the item's
  # refine and the wearer's levels) into the equipment accumulator. Script keys
  # (`:str`, `:hit`, `:critical`, ...) are not pre-seeded in the accumulator,
  # so each bonus is merged with `Map.update/4` rather than a struct-style
  # update; downstream readers all use `Map.get(..., 0)`.
  #
  # Numeric bonuses sum, except for the non-stackable destinations
  # (`BonusKeys.max_destination?/1`), where the strongest single item wins.
  # Constant-valued ones (`:atk_ele` from `bonus bAtkEle`) are not summable, so
  # the last equipped item to set one wins.
  defp apply_equip_script(acc, nil, _refine, _progression), do: acc

  defp apply_equip_script(acc, program, refine, progression) do
    inputs = %{
      refine: refine,
      base_level: progression.base_level,
      job_level: progression.job_level
    }

    program
    |> EquipScript.eval(inputs)
    |> Enum.reduce(acc, fn {key, value}, acc -> merge_equip_bonus(acc, key, value) end)
  end

  defp merge_equip_bonus(acc, key, value) when is_number(value) do
    if BonusKeys.max_destination?(key) do
      Map.update(acc, key, value, &max(&1, value))
    else
      Map.update(acc, key, value, &(&1 + value))
    end
  end

  defp merge_equip_bonus(acc, key, value), do: Map.put(acc, key, value)

  # Weapon MATK variance, verified vs rAthena status.cpp:6306-6316:
  # `variance = weapon.matk * weapon.wlv / 10` (integer div), then
  # `matk_min += wMatk - variance; matk_max += wMatk + variance`.
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

  # ponytail: enchantgrade multiplier deferred (roadmap SP-D - no grade-bonus
  # system exists yet). rAthena applies
  # `atk2/matk += (bonus/100 * enchantgrade_bonus)/100` (status.cpp:3961,3980);
  # here the refine bonus is applied unmultiplied.
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
