defmodule Aesir.ZoneServer.Script.Dsl.Internal do
  @moduledoc false

  # Shared plumbing for the Dsl domain modules. Not part of the script import
  # surface — only `Dsl.*` domain modules may call this. A helper lives here
  # only when two or more domains need it; single-domain helpers stay private
  # in their domain module.

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @doc """
  Routes a state-mutating op through the single-writer session (always a
  cross-process GenServer.call from the interaction, never a self-call), then
  folds the authoritative game_state back into ctx or halts on error. A
  detached ctx has no session to call, so it halts `:no_player` instead.
  """
  @spec apply_op(Ctx.t(), tuple()) :: Ctx.t()
  def apply_op(%Ctx{session_pid: nil} = ctx, _op), do: Ctx.halt(ctx, :no_player)

  def apply_op(%Ctx{session_pid: session_pid} = ctx, op) do
    case PlayerSession.script_apply(session_pid, op) do
      {:ok, game_state} -> %{ctx | game_state: game_state}
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  @doc """
  Raises for a read op called on a detached ctx (no player attached). Reads
  return bare values, not a Ctx, so they cannot carry a `{:error, :no_player}`
  status the way effect ops do; the raise crashes only the calling supervised
  Task, mirroring the script engine's "player not attached" error.
  """
  @spec no_player!(String.t()) :: no_return()
  def no_player!(op) do
    raise ArgumentError, "#{op} requires a player attached to the ctx, but ctx is detached"
  end

  @doc "Clamps `value` into `0..max` (look values, HP/SP deltas)."
  @spec clamp(integer(), non_neg_integer()) :: non_neg_integer()
  def clamp(value, max), do: value |> min(max) |> max(0)

  @doc "Resolves a skill id or catalog name atom to `{:ok, id}` or `{:error, :unknown_skill}`."
  @spec resolve_skill_id(integer() | atom()) :: {:ok, integer()} | {:error, :unknown_skill}
  def resolve_skill_id(skill_id) when is_integer(skill_id), do: {:ok, skill_id}

  def resolve_skill_id(name) when is_atom(name) do
    case Catalog.by_name(name) do
      {:ok, definition} -> {:ok, definition.id}
      :error -> {:error, :unknown_skill}
    end
  end

  @doc """
  Learned level of `skill` (id or catalog name atom) from a game state's
  progression; `0` for an unknown skill or name (the `getskilllv` core, shared
  with consumable-recovery scaling).
  """
  @spec learned_level(struct(), integer() | atom()) :: non_neg_integer()
  def learned_level(gs, skill) do
    case resolve_skill_id(skill) do
      {:ok, skill_id} -> Learned.learned_level(gs.stats.progression.learned_skills, skill_id)
      {:error, _reason} -> 0
    end
  end

  # rAthena `enum equip_index` ordinal -> Aesir equip location. The transpiler
  # resolves `EQI_*` constants to these indices; variables/ints pass through as
  # the same index at runtime.
  @equip_slot_locations %{
    0 => :left_accessory,
    1 => :right_accessory,
    2 => :shoes,
    3 => :garment,
    4 => :head_low,
    5 => :head_mid,
    6 => :head_top,
    7 => :armor,
    8 => :left_hand,
    9 => :right_hand,
    10 => :costume_head_top,
    11 => :costume_head_mid,
    12 => :costume_head_low,
    13 => :costume_garment,
    14 => :ammo,
    15 => :shadow_armor,
    16 => :shadow_weapon,
    17 => :shadow_shield,
    18 => :shadow_shoes,
    19 => :shadow_right_accessory,
    20 => :shadow_left_accessory
  }

  @doc "The Aesir equip location for an rAthena `equip_index` ordinal, or `nil`."
  @spec equip_slot_location(integer()) :: atom() | nil
  def equip_slot_location(slot), do: Map.get(@equip_slot_locations, slot)

  @doc "The item worn at `location`, or `nil`."
  @spec equipped_in_slot(Inventory.t(), atom()) :: InventoryItem.t() | nil
  def equipped_in_slot(inventory, location) do
    inventory
    |> Inventory.equipped_items()
    |> Enum.find_value(fn {_index, %InventoryItem{equip: equip} = item} ->
      if location in EquipLocation.bitmask_to_location_atoms(equip), do: item
    end)
  end

  @doc """
  The item worn in `slot` together with its definition, or `nil` when the
  slot is unknown/empty. Shared by every equip-read buildin.
  """
  @spec fetch_equipped(Ctx.t(), integer()) :: {InventoryItem.t(), ItemDefinition.t()} | nil
  def fetch_equipped(%Ctx{game_state: gs}, slot) do
    with location when not is_nil(location) <- equip_slot_location(slot),
         %InventoryItem{nameid: nameid} = item <- equipped_in_slot(gs.inventory, location),
         {:ok, item_def} <- ItemManagement.get_item_by_id(nameid) do
      {item, item_def}
    else
      _ -> nil
    end
  end

  @doc """
  The `{inventory_index, item}` worn in `slot`, or `nil` when the slot is
  unknown or empty. Used by `delequip` to address the session's row.
  """
  @spec equipped_index(Ctx.t(), integer()) :: {non_neg_integer(), InventoryItem.t()} | nil
  def equipped_index(%Ctx{game_state: gs}, slot) do
    case equip_slot_location(slot) do
      nil -> nil
      location -> find_equipped_entry(gs.inventory, location)
    end
  end

  @doc "The `{inventory_index, item}` worn at `location`, or `nil`."
  @spec find_equipped_entry(Inventory.t(), atom()) ::
          {non_neg_integer(), InventoryItem.t()} | nil
  def find_equipped_entry(inventory, location) do
    Enum.find_value(Inventory.equipped_items(inventory), fn {index,
                                                             %InventoryItem{equip: equip} = item} ->
      if location in EquipLocation.bitmask_to_location_atoms(equip), do: {index, item}
    end)
  end
end
