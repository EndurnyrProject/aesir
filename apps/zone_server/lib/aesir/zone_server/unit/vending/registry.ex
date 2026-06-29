defmodule Aesir.ZoneServer.Unit.Vending.Registry do
  @moduledoc """
  Mutable ETS registry of open vending shops, keyed by the vendor's `unit_id`.

  Shops are dynamic and short-lived (they end on disconnect, movement, or when
  the last item sells), so unlike the boot-time NPC registry this lives in a
  mutable ETS table rather than `:persistent_term`. The table is created at
  zone-server boot by `Aesir.ZoneServer.EtsTable` (alongside the other zone
  runtime tables); the seller session is the sole writer of its own entry while
  browse/board rendering read it without a session hit.

  Entries are stored as `{unit_id, {owner_pid, shop}}`. The `shop` value is
  opaque to this module: it is whatever map the vending handler stores.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Unit.SpatialIndex

  @type unit_id :: integer()
  @type shop :: map()

  @doc """
  Inserts or replaces the shop for `unit_id`, recording the owning session pid.
  """
  @spec put(unit_id(), pid(), shop()) :: :ok
  def put(unit_id, owner_pid, shop) do
    :ets.insert(table_for(:vending_registry), {unit_id, {owner_pid, shop}})
    :ok
  end

  @doc """
  Removes the shop for `unit_id`.
  """
  @spec remove(unit_id()) :: :ok
  def remove(unit_id) do
    :ets.delete(table_for(:vending_registry), unit_id)
    :ok
  end

  @doc """
  Gets the shop for `unit_id`, or `:error` when no shop is open for it.
  """
  @spec get(unit_id()) :: {:ok, shop()} | :error
  def get(unit_id) do
    case :ets.lookup(table_for(:vending_registry), unit_id) do
      [{^unit_id, {_owner_pid, shop}}] -> {:ok, shop}
      [] -> :error
    end
  end

  @doc """
  Lists open shops whose vendor is within `range` (Manhattan distance) of the
  point `{x, y}` on `map_name`.

  Vendor positions are resolved through `SpatialIndex.get_unit_position/2`; a
  shop whose vendor has no position or sits on another map is excluded. Returns
  `{unit_id, shop}` tuples.
  """
  @spec list_near(String.t(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          [{unit_id(), shop()}]
  def list_near(map_name, x, y, range) do
    table_for(:vending_registry)
    |> :ets.tab2list()
    |> Enum.filter(fn {unit_id, _entry} -> in_range?(unit_id, map_name, x, y, range) end)
    |> Enum.map(fn {unit_id, {_owner_pid, shop}} -> {unit_id, shop} end)
  end

  defp in_range?(unit_id, map_name, x, y, range) do
    case SpatialIndex.get_unit_position(:player, unit_id) do
      {:ok, {ux, uy, ^map_name}} -> abs(ux - x) + abs(uy - y) <= range
      _ -> false
    end
  end
end
