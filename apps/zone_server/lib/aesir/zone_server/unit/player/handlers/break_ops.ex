defmodule Aesir.ZoneServer.Unit.Player.Handlers.BreakOps do
  @moduledoc """
  Single-writer owner of equipment break and repair mutations.

  Mirrors `Aesir.ZoneServer.Unit.Player.Handlers.RefineOps`: each entry point
  runs its row write inside one `Aesir.ZoneServer.Unit.Inventory.Persistence.transaction/1`
  and reflects the persisted row back into the `PlayerState` inventory map so
  memory and the database never diverge.

  ## Break

  Breaking an equipped item flags its row broken (`attribute = 1`) and unequips
  it (`equip = 0`) in the same transaction, then recalculates combat stats with
  `Stats.calculate_stats/3` - exactly like `EquipmentHandler.advance/2` does
  after an unequip - because the broken item no longer contributes. The broken
  row is handed back so the caller can name the item in a system message. This
  module does not message the client or emit inventory sync; those are the
  caller's job.

  ## Repair

  Repair clears `attribute` but **never re-equips** (matching rAthena: the player
  re-wears manually and stats return through the normal equip recalc). Because a
  broken row is always unequipped (`equip = 0`), repair normally changes nothing
  the stat calc reads and skips the recalc. Repair of a missing or already-normal
  row is an idempotent no-op success.

  > This skip-recalc-on-repair invariant relies on
  > `Aesir.ZoneServer.Unit.Inventory.equip/4` (which rejects broken items via
  > `validate_not_broken/1`) remaining the sole path that writes a non-zero
  > `equip`. A new force-equip path that bypassed it could persist a
  > broken-but-equipped row and would require repair to recalc.
  """

  import Bitwise

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @typedoc "Why a break was rejected."
  @type reason :: :no_item | term()

  @doc """
  Breaks the item equipped in `slot`.

  Resolves the equipped `InventoryItem` whose `equip` bitmask covers `slot` (a
  location atom such as `:right_hand` or `:armor`), sets its `attribute` to `1`
  and `equip` to `0` in one transaction, recalculates stats from the remaining
  equipped items, and returns the advanced state plus the broken row. Returns
  `{:error, :no_item}` when nothing occupies `slot`, without mutating anything.
  """
  @spec break(PlayerState.t(), atom()) ::
          {:ok, PlayerState.t(), InventoryItem.t()} | {:error, reason()}
  def break(%PlayerState{inventory: inventory} = state, slot) when is_atom(slot) do
    case find_equipped(inventory, EquipLocation.location_bit(slot)) do
      {index, item} -> do_break(state, index, item)
      nil -> {:error, :no_item}
    end
  end

  @doc """
  Clears the broken flag on the row at `index`.

  Idempotent no-op success when the row is missing or already normal. Never
  re-equips: the repaired row keeps `equip = 0`, so no stat recalc is needed.
  """
  @spec repair(PlayerState.t(), non_neg_integer()) ::
          {:ok, PlayerState.t()} | {:error, term()}
  def repair(%PlayerState{inventory: inventory} = state, index) when is_integer(index) do
    case Map.get(inventory, index) do
      %InventoryItem{attribute: 1} = item -> clear_broken(state, index, item)
      _missing_or_normal -> {:ok, state}
    end
  end

  @doc """
  Clears the broken flag on every broken row in one transaction.

  Idempotent no-op success when nothing is broken. Never re-equips.
  """
  @spec repair_all(PlayerState.t()) :: {:ok, PlayerState.t()} | {:error, term()}
  def repair_all(%PlayerState{inventory: inventory} = state) do
    case for {index, %InventoryItem{attribute: 1} = item} <- inventory, do: {index, item} do
      [] -> {:ok, state}
      broken_rows -> do_repair_all(state, broken_rows)
    end
  end

  @spec find_equipped(Inventory.t(), non_neg_integer()) ::
          {non_neg_integer(), InventoryItem.t()} | nil
  defp find_equipped(_inventory, 0), do: nil

  defp find_equipped(inventory, bit) do
    Enum.find_value(Inventory.equipped_items(inventory), fn {index,
                                                             %InventoryItem{equip: equip} = item} ->
      if (equip &&& bit) != 0, do: {index, item}
    end)
  end

  @spec do_break(PlayerState.t(), non_neg_integer(), InventoryItem.t()) ::
          {:ok, PlayerState.t(), InventoryItem.t()} | {:error, term()}
  defp do_break(state, index, item) do
    result =
      Persistence.transaction(fn ->
        Persistence.update_item(item, %{attribute: 1, equip: 0})
      end)

    case result do
      {:ok, broken_row} ->
        inventory = PlayerState.put_item(state.inventory, index, broken_row)
        equipped = Map.values(Inventory.equipped_items(inventory))
        stats = Stats.calculate_stats(state.stats, state.character_id, equipped)
        {:ok, %{state | inventory: inventory, stats: stats}, broken_row}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec clear_broken(PlayerState.t(), non_neg_integer(), InventoryItem.t()) ::
          {:ok, PlayerState.t()} | {:error, term()}
  defp clear_broken(state, index, item) do
    result =
      Persistence.transaction(fn ->
        Persistence.update_item(item, %{attribute: 0})
      end)

    case result do
      {:ok, repaired_row} ->
        {:ok, %{state | inventory: PlayerState.put_item(state.inventory, index, repaired_row)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec do_repair_all(PlayerState.t(), [{non_neg_integer(), InventoryItem.t()}]) ::
          {:ok, PlayerState.t()} | {:error, term()}
  defp do_repair_all(state, broken_rows) do
    result =
      Persistence.transaction(fn ->
        Enum.reduce_while(broken_rows, {:ok, state.inventory}, &repair_row/2)
      end)

    case result do
      {:ok, inventory} -> {:ok, %{state | inventory: inventory}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec repair_row({non_neg_integer(), InventoryItem.t()}, {:ok, Inventory.t()}) ::
          {:cont, {:ok, Inventory.t()}} | {:halt, {:error, term()}}
  defp repair_row({index, item}, {:ok, inventory}) do
    case Persistence.update_item(item, %{attribute: 0}) do
      {:ok, repaired_row} -> {:cont, {:ok, PlayerState.put_item(inventory, index, repaired_row)}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end
end
