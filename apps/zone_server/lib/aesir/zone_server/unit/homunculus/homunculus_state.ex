defmodule Aesir.ZoneServer.Unit.Homunculus.HomunculusState do
  @moduledoc """
  Durable Homunculus gameplay state with its active world snapshot.

  The owning `PlayerSession` keeps this struct in its aggregate state. Runtime
  timer and movement bookkeeping belongs to `Runtime`, not this snapshot.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Ref

  @behaviour Unit

  @type lifecycle :: :active | :rested | :dead
  @type action_state :: :idle | :moving | :attacking | :casting | :dead
  @type race :: :demi_human | :brute | :formless
  @type movement_state :: :standing | :moving

  @living_actions [:idle, :moving, :attacking, :casting]
  @type base_stats :: %{
          str: integer(),
          agi: integer(),
          vit: integer(),
          int: integer(),
          dex: integer(),
          luk: integer()
        }
  @type combat_stats :: %{
          atk: integer(),
          atk_min: integer(),
          atk_max: integer(),
          def: integer(),
          soft_def: integer(),
          hit: integer(),
          flee: integer(),
          perfect_dodge: integer(),
          critical: integer(),
          matk: integer(),
          matk_min: integer(),
          matk_max: integer(),
          mdef: integer(),
          soft_mdef: integer(),
          hp_regen_rate: integer(),
          sp_regen_rate: integer()
        }

  @enforce_keys [:id, :owner_character_id, :class_id, :name]
  defstruct id: nil,
            owner_character_id: nil,
            owner_session_pid: nil,
            class_id: nil,
            name: nil,
            rename_available: true,
            lifecycle: :rested,
            level: 1,
            exp: 0,
            skill_points: 0,
            hp: 0,
            max_hp: 0,
            raw_max_hp: nil,
            sp: 0,
            max_sp: 0,
            raw_max_sp: nil,
            str: 0,
            raw_str: nil,
            agi: 0,
            raw_agi: nil,
            vit: 0,
            raw_vit: nil,
            int: 0,
            raw_int: nil,
            dex: 0,
            raw_dex: nil,
            luk: 0,
            raw_luk: nil,
            hunger: 32,
            intimacy_hundredths: 2_100,
            active_remaining_ms: 1_800_000,
            learned_skills: %{},
            cooldowns: %{},
            ai_config: %{},
            world_gid: nil,
            map_name: nil,
            x: nil,
            y: nil,
            dir: 0,
            action_state: :idle,
            movement_state: :standing,
            standby?: false,
            target: nil,
            casting: nil,
            race: :formless,
            element: {:neutral, 1},
            size: :medium,
            attack_range: 1,
            attack_delay_ms: 500,
            raw_attack_delay_ms: nil,
            combat_stats: %{
              atk: 0,
              atk_min: 0,
              atk_max: 0,
              def: 0,
              soft_def: 0,
              hit: 0,
              flee: 0,
              perfect_dodge: 0,
              critical: 0,
              matk: 0,
              matk_min: 0,
              matk_max: 0,
              mdef: 0,
              soft_mdef: 0,
              hp_regen_rate: 0,
              sp_regen_rate: 0
            }

  @type t() :: %__MODULE__{
          id: pos_integer(),
          owner_character_id: pos_integer(),
          owner_session_pid: pid() | nil,
          class_id: pos_integer(),
          name: String.t(),
          rename_available: boolean(),
          lifecycle: lifecycle(),
          level: pos_integer(),
          exp: non_neg_integer(),
          skill_points: non_neg_integer(),
          hp: non_neg_integer(),
          max_hp: non_neg_integer(),
          raw_max_hp: non_neg_integer() | nil,
          sp: non_neg_integer(),
          max_sp: non_neg_integer(),
          raw_max_sp: non_neg_integer() | nil,
          str: integer(),
          raw_str: integer() | nil,
          agi: integer(),
          raw_agi: integer() | nil,
          vit: integer(),
          raw_vit: integer() | nil,
          int: integer(),
          raw_int: integer() | nil,
          dex: integer(),
          raw_dex: integer() | nil,
          luk: integer(),
          raw_luk: integer() | nil,
          hunger: non_neg_integer(),
          intimacy_hundredths: non_neg_integer(),
          active_remaining_ms: non_neg_integer(),
          learned_skills: %{optional(integer()) => pos_integer()},
          cooldowns: map(),
          ai_config: map(),
          world_gid: pos_integer() | nil,
          map_name: String.t() | nil,
          x: integer() | nil,
          y: integer() | nil,
          dir: 0..7,
          action_state: action_state(),
          movement_state: movement_state(),
          standby?: boolean(),
          target: Ref.t() | nil,
          casting: map() | nil,
          race: race(),
          element: {Unit.entity_element(), pos_integer()},
          size: Unit.entity_size(),
          attack_range: pos_integer(),
          attack_delay_ms: pos_integer(),
          raw_attack_delay_ms: pos_integer() | nil,
          combat_stats: combat_stats()
        }

  @doc "Returns the Homunculus race for status and combat calculations."
  @impl Unit
  @spec get_race(t()) :: Unit.entity_race()
  def get_race(%__MODULE__{race: race}), do: race

  @doc "Returns the Homunculus defensive element and level."
  @impl Unit
  @spec get_element(t()) :: {Unit.entity_element(), integer()}
  def get_element(%__MODULE__{element: element}), do: element

  @doc "Returns whether the Homunculus has boss immunity."
  @impl Unit
  @spec is_boss?(t()) :: boolean()
  def is_boss?(%__MODULE__{}), do: false

  @doc "Returns the Homunculus size for combat calculations."
  @impl Unit
  @spec get_size(t()) :: Unit.entity_size()
  def get_size(%__MODULE__{size: size}), do: size

  @doc "Returns base, resource, and derived combat values for formulas."
  @impl Unit
  @spec get_stats(t()) :: map()
  def get_stats(%__MODULE__{} = state) do
    state
    |> base_stats()
    |> Map.merge(state.combat_stats)
    |> Map.merge(%{
      base_level: state.level,
      job_level: 1,
      hp: state.hp,
      max_hp: state.max_hp,
      sp: state.sp,
      max_sp: state.max_sp
    })
  end

  @doc "Returns the standard entity information map for the active snapshot."
  @impl Unit
  @spec get_entity_info(t()) :: map()
  def get_entity_info(%__MODULE__{} = state) do
    Unit.build_entity_info(__MODULE__, state)
    |> Map.put(:entity_type, :homunculus)
  end

  @doc "Returns the transient world identity for an active Homunculus."
  @impl Unit
  @spec get_unit_id(t()) :: integer()
  def get_unit_id(%__MODULE__{world_gid: world_gid}) when is_integer(world_gid) and world_gid > 0,
    do: world_gid

  @doc "Returns the Homunculus unit type."
  @impl Unit
  @spec get_unit_type(t()) :: :homunculus
  def get_unit_type(%__MODULE__{}), do: :homunculus

  @doc "Returns the owning player session process."
  @impl Unit
  @spec get_process_pid(t()) :: pid() | nil
  def get_process_pid(%__MODULE__{owner_session_pid: pid}), do: pid

  @doc "Returns Homunculus-specific status immunities."
  @impl Unit
  @spec get_custom_immunities(t()) :: [atom()]
  def get_custom_immunities(%__MODULE__{}), do: []

  @doc "Returns whether this is an active, living Homunculus snapshot."
  @impl Unit
  @spec living?(t()) :: boolean()
  def living?(%__MODULE__{lifecycle: :active, action_state: action_state, hp: hp})
      when action_state in @living_actions and is_integer(hp) and hp > 0,
      do: true

  def living?(%__MODULE__{}), do: false

  @doc "Returns whether this is a dead, resurrection-targetable Homunculus."
  @impl Unit
  @spec corpse?(t()) :: boolean()
  def corpse?(%__MODULE__{lifecycle: :dead, action_state: :dead, hp: 0}), do: true
  def corpse?(%__MODULE__{}), do: false

  @doc "Builds the typed combatant view, attributing social and rewards to the owner."
  @impl Unit
  @spec to_combatant(t()) :: Combatant.t()
  def to_combatant(%__MODULE__{} = state) do
    Combatant.new!(%{
      unit_id: get_unit_id(state),
      unit_type: :homunculus,
      social_root: {:player, state.owner_character_id},
      reward_root: {:player, state.owner_character_id},
      base_stats: base_stats(state),
      combat_stats: state.combat_stats,
      max_hp: state.max_hp,
      max_sp: state.max_sp,
      progression: %{base_level: state.level, job_level: 1},
      element: state.element,
      race: state.race,
      size: state.size,
      weapon: %{type: :fist, element: elem(state.element, 0), size: state.size},
      attack_range: state.attack_range,
      attack_delay_ms: state.attack_delay_ms,
      position: {state.x, state.y},
      map_name: state.map_name,
      class: :normal,
      equip_modifiers: %{}
    })
  end

  defp base_stats(%__MODULE__{} = state) do
    Map.take(Map.from_struct(state), [:str, :agi, :vit, :int, :dex, :luk])
  end
end
