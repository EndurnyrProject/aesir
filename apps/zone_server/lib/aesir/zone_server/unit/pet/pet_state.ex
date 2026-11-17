defmodule Aesir.ZoneServer.Unit.Pet.PetState do
  @moduledoc """
  A hatched pet's gameplay state with its world snapshot.

  The owning `PlayerSession` keeps this struct in `SessionState.pet`, and only
  `Pet.StateCommit` replaces it. Race, element and size come from the mob
  catalog entry of the pet's class. Timer and movement bookkeeping belongs to
  `Pet.Runtime`. `combat_stats`, `rate_fix` and `loot` are filled by the
  support features.
  """

  alias Aesir.Commons.Models.Pet
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref

  @behaviour Unit

  @default_walk_speed 150

  @type movement_state :: :standing | :moving
  @type action_state :: :idle | :moving | :attacking | :casting

  @enforce_keys [
    :pet_id,
    :owner_char_id,
    :owner_account_id,
    :class_id,
    :name,
    :level,
    :egg_id,
    :intimate,
    :hungry
  ]
  defstruct world_gid: nil,
            pet_id: nil,
            owner_char_id: nil,
            owner_account_id: nil,
            class_id: nil,
            name: nil,
            level: nil,
            egg_id: nil,
            equip: 0,
            intimate: nil,
            hungry: nil,
            rename_flag: 0,
            autofeed: false,
            map_name: nil,
            x: nil,
            y: nil,
            dir: 0,
            walk_speed: @default_walk_speed,
            movement_state: :standing,
            action_state: :idle,
            target: nil,
            combat_stats: nil,
            rate_fix: nil,
            loot: nil

  @type t() :: %__MODULE__{
          world_gid: pos_integer() | nil,
          pet_id: pos_integer(),
          owner_char_id: pos_integer(),
          owner_account_id: pos_integer(),
          class_id: pos_integer(),
          name: String.t(),
          level: pos_integer(),
          egg_id: pos_integer(),
          equip: non_neg_integer(),
          intimate: non_neg_integer(),
          hungry: non_neg_integer(),
          rename_flag: 0 | 1,
          autofeed: boolean(),
          map_name: String.t() | nil,
          x: integer() | nil,
          y: integer() | nil,
          dir: 0..7,
          walk_speed: pos_integer(),
          movement_state: movement_state(),
          action_state: action_state(),
          target: Ref.t() | nil,
          combat_stats: map() | nil,
          rate_fix: integer() | nil,
          loot: map() | nil
        }

  @doc """
  Builds the pet from its persisted row, placed on its owner's cell and facing.

  The walk speed follows `pet_walk_speed`:
  1 the owner's current speed, 2 the default 150, 3 the mob database speed.
  """
  @spec from_row(Pet.t(), PlayerState.t()) :: t()
  def from_row(%Pet{} = row, %PlayerState{} = owner) do
    %__MODULE__{
      pet_id: row.id,
      owner_char_id: owner.character_id,
      owner_account_id: owner.account_id,
      class_id: row.class,
      name: row.name,
      level: row.level,
      egg_id: row.egg_id,
      equip: row.equip,
      intimate: row.intimate,
      hungry: row.hungry,
      rename_flag: row.rename_flag,
      autofeed: row.autofeed,
      map_name: owner.map_name,
      x: owner.x,
      y: owner.y,
      dir: owner.dir,
      walk_speed: base_walk_speed(row.class, owner)
    }
  end

  @doc """
  The pet's normal walk speed for `pet_walk_speed` (`get_pet_walk_speed`):
  1 the owner's current speed, 2 the default 150, 3 the mob database speed.
  """
  @spec base_walk_speed(pos_integer(), PlayerState.t()) :: pos_integer()
  def base_walk_speed(class_id, %PlayerState{} = owner),
    do: walk_speed(Config.pet_walk_speed(), class_id, owner)

  defp walk_speed(2, _class_id, _owner), do: @default_walk_speed
  defp walk_speed(3, class_id, _owner), do: mob!(class_id).walk_speed
  defp walk_speed(_master, _class_id, owner), do: StatusManager.current_walk_speed(owner)

  @doc "Returns the race of the pet's mob class."
  @impl Unit
  @spec get_race(t()) :: Unit.entity_race()
  def get_race(%__MODULE__{class_id: class_id}), do: mob!(class_id).race

  @doc "Returns the element of the pet's mob class."
  @impl Unit
  @spec get_element(t()) :: {Unit.entity_element(), integer()}
  def get_element(%__MODULE__{class_id: class_id}), do: mob!(class_id).element

  @doc "Pets never carry boss protection."
  @impl Unit
  @spec is_boss?(t()) :: boolean()
  def is_boss?(%__MODULE__{}), do: false

  @doc "Returns the size of the pet's mob class."
  @impl Unit
  @spec get_size(t()) :: Unit.entity_size()
  def get_size(%__MODULE__{class_id: class_id}), do: mob!(class_id).size

  @doc "Returns the pet's level as its only formula stat."
  @impl Unit
  @spec get_stats(t()) :: map()
  def get_stats(%__MODULE__{level: level}), do: %{base_level: level}

  @doc "Returns the standard entity information map."
  @impl Unit
  @spec get_entity_info(t()) :: map()
  def get_entity_info(%__MODULE__{} = state), do: Unit.build_entity_info(__MODULE__, state)

  @doc "Returns the transient world identity of a pet in the world."
  @impl Unit
  @spec get_unit_id(t()) :: integer()
  def get_unit_id(%__MODULE__{world_gid: gid}) when is_integer(gid) and gid > 0, do: gid

  @doc "Returns the pet unit type."
  @impl Unit
  @spec get_unit_type(t()) :: :pet
  def get_unit_type(%__MODULE__{}), do: :pet

  @doc "A pet is alive while it is in the world; it has no HP."
  @impl Unit
  @spec living?(t()) :: boolean()
  def living?(%__MODULE__{world_gid: gid}), do: is_integer(gid)

  @doc "A pet never leaves a corpse."
  @impl Unit
  @spec corpse?(t()) :: boolean()
  def corpse?(%__MODULE__{}), do: false

  defp mob!(class_id) do
    {:ok, mob} = Mobs.by_id(class_id)
    mob
  end
end
