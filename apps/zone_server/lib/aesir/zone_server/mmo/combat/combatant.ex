defmodule Aesir.ZoneServer.Mmo.Combat.Combatant do
  @moduledoc """
  Standardized combatant structure for combat operations.

  This module defines the unified data structure used by all combat systems,
  replacing the ad-hoc maps previously used for player and mob combat.
  It provides type safety and a clear contract for combat operations.

  ## Benefits

  - Type safety through struct definition
  - Clear documentation of required fields
  - Consistent interface for all unit types
  - Easier testing and debugging
  - Better IDE support

  ## Usage

      # Create combatant from player state
      player_combatant = Combat.Unit.to_combatant(player_state)
      
      # Create combatant from mob state  
      mob_combatant = Combat.Unit.to_combatant(mob_state)
      
      # Both can be used interchangeably in combat functions
      DamageCalculator.calculate_damage(player_combatant, mob_combatant)
  """

  @typedoc """
  Standardized combatant structure containing all data needed for combat calculations.

  Fields are organized into logical groups:
  - Identity: unit_id, unit_type, social_root, reward_root
  - Stats: base_stats, combat_stats (physical atk/def plus magic matk/mdef/soft_mdef), progression
  - Combat modifiers: element, race, size, weapon
  - Timing: attack_range, attack_delay_ms
  - Positioning: position, map_name
  """
  @enforce_keys [
    :unit_id,
    :unit_type,
    :base_stats,
    :combat_stats,
    :progression,
    :element,
    :race,
    :size,
    :weapon,
    :attack_range,
    :attack_delay_ms
  ]
  defstruct [
    # Unit identification
    unit_id: nil,
    unit_type: nil,
    social_root: nil,
    reward_root: nil,
    party_id: 0,
    guild_id: 0,

    # Base stats (STR, AGI, VIT, INT, DEX, LUK)
    base_stats: nil,

    # Combat-derived stats (physical: atk/def, magic: matk/mdef/soft_mdef)
    combat_stats: nil,

    # Character progression
    progression: nil,

    # Element data (for damage calculation)
    element: nil,

    # Race data (for modifier calculation)
    race: nil,

    # Size data (for modifier calculation)
    size: nil,

    # Weapon information
    weapon: nil,

    # Attack range for combat distance calculations
    attack_range: nil,

    # Attack cadence in milliseconds: the delay the combat loop uses to gate
    # attacks. Sent to the client as ZC_NOTIFY_ACT src_speed so the swing
    # animation duration matches real attack speed.
    attack_delay_ms: nil,

    # Position data (optional for some combat operations)
    position: nil,

    # Map context (optional)
    map_name: nil,

    # Passive skill levels precomputed at combatant-build time (0 for mobs).
    divine_protection_level: 0,
    demon_bane_level: 0,
    beast_bane_level: 0,
    dragonology_level: 0,
    faith_level: 0,
    skin_temper_level: 0,

    # Mob-class axis for bAddClass/bSubClass-style equipment bonuses. Players
    # are always :normal; mobs are :boss when tagged with the :boss mode.
    class: :normal,

    # Whether the attacker is mounted (Peco-Peco). Feeds the mounted-spear
    # size-modifier override; always false for mobs.
    riding: false,

    # Folded equipment bonus map (players: `stats.modifiers.equipment`;
    # mobs: empty, since mobs carry no equipment).
    equip_modifiers: %{}
  ]

  @type t() :: %__MODULE__{
          unit_id: integer(),
          unit_type: :player | :mob | :homunculus | :skill_unit,
          social_root: Aesir.ZoneServer.Unit.Ref.t() | nil,
          reward_root: {:player, pos_integer()} | nil,
          party_id: non_neg_integer(),
          guild_id: non_neg_integer(),
          base_stats: %{
            str: integer(),
            agi: integer(),
            vit: integer(),
            int: integer(),
            dex: integer(),
            luk: integer()
          },
          combat_stats: %{
            atk: integer(),
            def: integer(),
            hit: integer(),
            flee: integer(),
            perfect_dodge: integer(),
            matk: integer(),
            matk_min: integer(),
            matk_max: integer(),
            mdef: integer(),
            soft_mdef: integer()
          },
          progression: %{
            base_level: integer(),
            job_level: integer()
          },
          element: tuple() | atom(),
          race: atom(),
          size: atom(),
          weapon: %{
            type: atom(),
            element: atom(),
            size: atom()
          },
          attack_range: integer(),
          attack_delay_ms: integer(),
          position: {integer(), integer()} | nil,
          map_name: String.t() | nil,
          divine_protection_level: integer(),
          demon_bane_level: integer(),
          beast_bane_level: integer(),
          dragonology_level: integer(),
          faith_level: integer(),
          skin_temper_level: integer(),
          class: :normal | :boss,
          riding: boolean(),
          equip_modifiers: map()
        }

  @doc """
  Creates a new combatant struct with validation.

  Validates that all required fields are present and have correct types.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    combatant = attrs |> with_roots() |> then(&struct(__MODULE__, &1))

    if valid_roots?(combatant) do
      {:ok, combatant}
    else
      {:error, "Invalid combatant relationship roots"}
    end
  rescue
    e in ArgumentError ->
      {:error, "Invalid combatant data: #{Exception.message(e)}"}
  end

  @doc """
  Creates a new combatant struct, raising on invalid data.
  """
  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, combatant} -> combatant
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Validates that a combatant struct has all required fields for combat.
  """
  @spec validate_for_combat(t()) :: :ok | {:error, String.t()}
  def validate_for_combat(%__MODULE__{} = combatant) do
    cond do
      combatant.unit_id <= 0 ->
        {:error, "Invalid unit_id: must be positive integer"}

      combatant.unit_type not in [:player, :mob, :homunculus, :skill_unit] ->
        {:error, "Invalid unit_type"}

      not is_map(combatant.base_stats) ->
        {:error, "Invalid base_stats: must be map"}

      not is_map(combatant.combat_stats) ->
        {:error, "Invalid combat_stats: must be map"}

      combatant.progression.base_level <= 0 ->
        {:error, "Invalid base_level: must be positive integer"}

      true ->
        :ok
    end
  end

  @doc """
  Gets the unit identifier for this combatant.

  This is a convenience function that provides a unified way to get
  the unit ID regardless of the combatant's internal structure.
  """
  @spec get_unit_id(t()) :: integer()
  def get_unit_id(%__MODULE__{unit_id: unit_id}), do: unit_id

  @doc """
  Gets the unit type for this combatant.
  """
  @spec get_unit_type(t()) :: :player | :mob | :homunculus | :skill_unit
  def get_unit_type(%__MODULE__{unit_type: unit_type}), do: unit_type

  @doc """
  Checks if this combatant is a player.
  """
  @spec player?(t()) :: boolean()
  def player?(%__MODULE__{unit_type: :player}), do: true
  def player?(_), do: false

  @doc """
  Checks if this combatant is a mob.
  """
  @spec mob?(t()) :: boolean()
  def mob?(%__MODULE__{unit_type: :mob}), do: true
  def mob?(_), do: false

  defp with_roots(%{unit_type: :player, unit_id: unit_id} = attrs) do
    attrs
    |> Map.put_new(:social_root, {:player, unit_id})
    |> Map.put_new(:reward_root, {:player, unit_id})
  end

  defp with_roots(%{unit_type: :mob, unit_id: unit_id} = attrs) do
    attrs
    |> Map.put_new(:social_root, {:mob, unit_id})
    |> Map.put_new(:reward_root, nil)
  end

  defp with_roots(attrs), do: attrs

  defp valid_roots?(%__MODULE__{
         unit_type: :player,
         unit_id: unit_id,
         social_root: {:player, unit_id},
         reward_root: {:player, unit_id}
       })
       when is_integer(unit_id) and unit_id > 0,
       do: true

  defp valid_roots?(%__MODULE__{
         unit_type: :mob,
         unit_id: unit_id,
         social_root: {:mob, unit_id},
         reward_root: nil
       })
       when is_integer(unit_id) and unit_id > 0,
       do: true

  defp valid_roots?(%__MODULE__{
         unit_type: :homunculus,
         unit_id: unit_id,
         social_root: {:player, owner_id},
         reward_root: {:player, owner_id}
       })
       when is_integer(unit_id) and unit_id > 0 and is_integer(owner_id) and owner_id > 0,
       do: true

  defp valid_roots?(%__MODULE__{unit_type: :skill_unit}), do: true
  defp valid_roots?(%__MODULE__{}), do: false
end
