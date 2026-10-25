defmodule Aesir.ZoneServer.Unit.Vending.Permissions do
  @moduledoc "Account and item eligibility for vending preparation and listing validation."

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Vending

  @doc "Whether the effective group grants ordinary or unconditional item transfer."
  @spec can_trade?(map()) :: boolean()
  def can_trade?(access),
    do: Map.get(access, :can_trade, false) or Map.get(access, :trade_unconditional, false)

  @doc "Returns a permission result for each raw cart slot without changing its contents."
  @spec eligibility(Vending.cart(), map()) :: %{non_neg_integer() => :ok | {:error, atom()}}
  def eligibility(cart, access) do
    Map.new(cart, fn {index, item} -> {index, check_item(item, access)} end)
  end

  defp check_item(%InventoryItem{} = item, access) do
    with true <- can_trade?(access),
         :ok <- Vending.intrinsic_eligibility(item),
         :ok <- check_bound(item, access),
         {:ok, definition} <- check_catalog_trade(item.nameid, Map.get(access, :level, 0)) do
      check_cards(item, definition, Map.get(access, :level, 0))
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  defp check_catalog_trade(id, level) do
    with {:ok, definition} <- ItemManagement.get_item_by_id(id),
         :ok <- check_definition(definition, level) do
      {:ok, definition}
    else
      {:error, _reason} -> {:error, :item_untradeable}
    end
  end

  defp check_cards(%InventoryItem{card0: marker}, _definition, _level)
       when marker in [0xFE, 0xFF, 0x100],
       do: :ok

  defp check_cards(item, %ItemDefinition{slots: slots}, level) do
    item
    |> InventoryItem.cards()
    |> Enum.take(slots)
    |> Enum.reject(&(&1 == 0))
    |> Enum.reduce_while(:ok, fn id, :ok ->
      case check_catalog_trade(id, level) do
        {:ok, _definition} -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp check_definition(%ItemDefinition{no_trade: false}, _level), do: :ok

  defp check_definition(%ItemDefinition{trade_override: override}, level) do
    if level >= override, do: :ok, else: {:error, :item_untradeable}
  end

  defp check_bound(%InventoryItem{bound: 0}, _access), do: :ok

  defp check_bound(%InventoryItem{}, access) do
    if Map.get(access, :can_trade_bounded, false) or Map.get(access, :trade_unconditional, false),
      do: :ok,
      else: {:error, :item_bound}
  end
end
