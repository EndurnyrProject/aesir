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
  Player statistics for individual character sessions.

  Extends the base `Unit.Stats` with the player-specific layers: progression,
  worn equipment, the per-source modifier maps, equipment proc registrations,
  and resolved weapon hands. This module owns the struct, its construction from
  a `Character`, the `Equipment` queries (weapon type, shield), and the readers
  the rest of the server uses to look a stat up with every modifier applied.

  The recompute pipeline lives in `Stats.Calculator`; the equipment fold that
  feeds it lives in `Stats.EquipmentFold`; sprite views live in `Appearance`.
  """

  import Bitwise

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Stats

  @riding_option_bit Option.id(:riding)

  # `bonus bAllStats,n` grants n to each of the six primary stats only; the
  # trait stats (POW/STA/WIS/SPL/CON/CRT) have their own `bAllTraitStats`.
  @primary_stats [:str, :agi, :vit, :int, :dex, :luk]

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

  @typedoc "Identity of the host or socketed card source that owns an autobonus registration."
  @type autobonus_source_identity :: {:host, pos_integer()} | {:card, 0..3, pos_integer()}

  @typedoc "An evaluated autobonus registration derived from a worn item."
  @type autobonus_registration :: %{
          item_id: pos_integer(),
          source_identity: autobonus_source_identity(),
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

  @typedoc "Stable identity of one card cleanup source within a worn host row."
  @type card_source_key :: {pos_integer(), 0..3}

  @typedoc "Evaluated card cleanup effects and their deterministic worn-source order."
  @type card_cleanup :: %{
          source_order: {non_neg_integer(), 0..3},
          effects: [EquipScript.effect()]
        }

  @typedoc """
  Cached inventory identity and metadata used by equipment refolds.

  A nullable row id is retained only for compatibility with legacy callers. Any
  row contributing an autobonus or card cleanup source must have a positive id.
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

            # Derived proc registrations, live generations, direct status
            # requirements, and card cleanup sources. Rebuilt or pruned by the
            # deterministic equipment fold.
            equip_autobonuses: %{},
            active_autobonuses: %{},
            equip_statuses: %{},
            card_unequip_effects: %{},
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
          card_unequip_effects: %{card_source_key() => card_cleanup()},
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

    Calculator.calculate_stats(stats)
  end

  defp riding?(option) when is_integer(option), do: (option &&& @riding_option_bit) != 0
  defp riding?(_option), do: false

  @doc """
  Converts player stats to formula map format for status effect calculations.
  """
  @spec to_formula_map(t()) :: map()
  def to_formula_map(%__MODULE__{} = stats) do
    total = total_stats(stats)

    %{
      # Base stats
      str: stats.base_stats.str,
      agi: stats.base_stats.agi,
      vit: stats.base_stats.vit,
      int: stats.base_stats.int,
      dex: stats.base_stats.dex,
      luk: stats.base_stats.luk,
      # Fully calculated primary stats, for formulas that must see job, equipment
      # and status contributions rather than the allocated points alone.
      total_stats: total,
      # The same, minus the status layer, for a formula that emits a delta on the
      # very stat it reads: reading its own output back would compound it on
      # every recalculation.
      unbuffed_stats: unbuffed_stats(stats, total),
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
  The player's reach in cells: the equipped weapon's own range plus every
  attack-range bonus their learned passives grant (Vulture's Eye grants one
  cell per level while a bow is wielded).

  Every reach question reads this one value - the basic-attack gate, the
  move-to-attack approach, the combatant snapshot the damage layer sees, and a
  skill declaring the weapon's own range - so a range passive can never apply
  to some of them and not others.
  """
  @spec attack_range(t()) :: non_neg_integer()
  def attack_range(%{equipment: equipment} = stats) do
    range = equipment |> weapon_type() |> WeaponTypes.get_attack_range()

    range + passive_range(stats)
  end

  @spec passive_range(t()) :: integer()
  defp passive_range(%{modifiers: %{passive: passive}}) when is_map(passive),
    do: Map.get(passive, :range, 0)

  defp passive_range(_stats), do: 0

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
      {item_weight(nameid), left_hand_refine(inventory)}
    else
      nil
    end
  end

  @doc "Returns raw item weight and equipped refine for the right-hand weapon, or nil if unarmed."
  @spec right_hand_weapon_stats(Equipment.t(), [InventoryItem.t()]) ::
          {non_neg_integer(), non_neg_integer()} | nil
  def right_hand_weapon_stats(%Equipment{right_hand: nil}, _inventory), do: nil

  def right_hand_weapon_stats(%Equipment{right_hand: nameid}, inventory) do
    refine =
      Enum.find_value(inventory, 0, fn %InventoryItem{
                                         nameid: item_id,
                                         equip: equip,
                                         refine: value
                                       } ->
        if item_id == nameid and :right_hand in EquipLocation.bitmask_to_location_atoms(equip),
          do: value
      end)

    {item_weight(nameid), refine}
  end

  defp item_weight(nameid) do
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

  @doc false
  @spec normalize_items([InventoryItem.t()] | %{optional(any()) => InventoryItem.t()}) ::
          [InventoryItem.t()]
  def normalize_items(items) when is_list(items), do: items

  def normalize_items(items) when is_map(items) do
    items
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  @spec total_stats(t()) :: %{atom() => integer()}
  defp total_stats(%__MODULE__{} = stats),
    do: Map.new(@primary_stats, &{&1, get_effective_stat(stats, &1)})

  @spec unbuffed_stats(t(), %{atom() => integer()}) :: %{atom() => integer()}
  defp unbuffed_stats(%__MODULE__{} = stats, total) do
    Map.new(total, fn {stat_name, value} ->
      {stat_name, value - Map.get(stats.modifiers.status_effects, stat_name, 0)}
    end)
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
  The skills granted by the wearer's currently worn equipment (the `on_equip`
  `skill` command), as `%{skill_id => level}`. Empty when nothing worn grants a
  skill.
  """
  @spec granted_skills(t()) :: %{integer() => non_neg_integer()}
  def granted_skills(%__MODULE__{granted_skills: granted}) when is_map(granted), do: granted
  def granted_skills(%__MODULE__{}), do: %{}
end
