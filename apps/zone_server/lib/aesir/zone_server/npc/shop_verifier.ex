defmodule Aesir.ZoneServer.Npc.ShopVerifier do
  @moduledoc """
  Boot/test sanity checks for loaded NPC shop placements.

  Unlike NPCs (which routinely sit on walls and decorative cells), a shop must be
  reachable for a player to click it, so the spawn cell **must** be walkable.
  For each shop the following are **fatal** errors:

    * `{:unknown_map, shop}` — the shop's map is not loaded in
      `Aesir.ZoneServer.Map.MapCache` (a typo or a not-yet-imported map).
    * `{:non_walkable_cell, shop}` — the shop's spawn cell is not standable,
      making the vendor unreachable.
    * `{:unknown_item, shop, nameid}` — a buy-list item does not resolve in the
      item DB (a phantom item is a data bug).

  A shop cell that collides with an NPC placement, a warp, or another shop is a
  **non-fatal** warning: the synthetic gids overlap and the entities would shadow
  each other, but boot continues.

  `verify/1` returns `:ok` or the list of fatal errors; `verify!/1` logs the
  collision warnings and then raises `ArgumentError` on any fatal error.
  """

  require Logger

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps

  @type shops :: %{String.t() => [Shop.t()]} | [Shop.t()]
  @type cell :: {String.t(), non_neg_integer(), non_neg_integer()}
  @type error ::
          {:unknown_map, Shop.t()}
          | {:non_walkable_cell, Shop.t()}
          | {:unknown_item, Shop.t(), pos_integer()}

  @doc """
  Verifies the given shops, returning `:ok` or the list of fatal errors.

  Accepts either the per-map index (`Shops.all/0`) or a flat list of shops.
  """
  @spec verify(shops()) :: :ok | {:error, [error()]}
  def verify(shops) do
    case shops |> normalize() |> Enum.flat_map(&shop_errors/1) do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  @doc """
  Boot-time verification: logs a warning for every shop cell that collides with
  an NPC, warp, or another shop, then returns `:ok` or raises `ArgumentError` on
  any fatal error (unknown map, non-walkable cell, unknown item).
  """
  @spec verify!(shops()) :: :ok
  def verify!(shops) do
    list = normalize(shops)
    warn_collisions(list)

    case verify(list) do
      :ok -> :ok
      {:error, errors} -> raise ArgumentError, "invalid NPC shops: #{inspect(errors)}"
    end
  end

  @spec normalize(shops()) :: [Shop.t()]
  defp normalize(shops) when is_map(shops), do: shops |> Map.values() |> List.flatten()
  defp normalize(shops) when is_list(shops), do: shops

  @spec shop_errors(Shop.t()) :: [error()]
  defp shop_errors(%Shop{} = shop), do: cell_errors(shop) ++ item_errors(shop)

  @spec cell_errors(Shop.t()) :: [error()]
  defp cell_errors(%Shop{} = shop) do
    cond do
      not MapCache.exists?(shop.map) -> [{:unknown_map, shop}]
      not MapCache.walkable?(shop.map, shop.x, shop.y) -> [{:non_walkable_cell, shop}]
      true -> []
    end
  end

  @spec item_errors(Shop.t()) :: [error()]
  defp item_errors(%Shop{} = shop) do
    for %{nameid: nameid} <- shop.items,
        match?({:error, _}, ItemManagement.get_item_by_id(nameid)),
        do: {:unknown_item, shop, nameid}
  end

  @spec warn_collisions([Shop.t()]) :: :ok
  defp warn_collisions(shops) do
    (shop_occupants(shops) ++ npc_occupants() ++ warp_occupants())
    |> Enum.group_by(fn {cell, _label} -> cell end, fn {_cell, label} -> label end)
    |> Enum.filter(fn {_cell, labels} -> shop_collision?(labels) end)
    |> Enum.each(fn {cell, labels} ->
      Logger.warning("NPC shop cell #{inspect(cell)} collides with #{inspect(labels)}")
    end)

    :ok
  end

  @spec shop_collision?([term()]) :: boolean()
  defp shop_collision?(labels) do
    length(labels) > 1 and Enum.any?(labels, &match?({:shop, _}, &1))
  end

  @spec shop_occupants([Shop.t()]) :: [{cell(), {:shop, String.t()}}]
  defp shop_occupants(shops) do
    for %Shop{} = shop <- shops, do: {{shop.map, shop.x, shop.y}, {:shop, shop.id}}
  end

  @spec npc_occupants() :: [{cell(), {:npc, module()}}]
  defp npc_occupants do
    for {module, %Placement{} = p} <- NpcRegistry.entries(),
        do: {{p.map, p.x, p.y}, {:npc, module}}
  end

  @spec warp_occupants() :: [{cell(), {:warp, String.t()}}]
  defp warp_occupants do
    for {_map, warps} <- Warps.all(),
        %Warp{} = w <- warps,
        do: {{w.map, w.x, w.y}, {:warp, w.id}}
  end
end
