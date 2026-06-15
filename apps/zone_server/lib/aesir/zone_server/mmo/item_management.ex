defmodule Aesir.ZoneServer.Mmo.ItemManagement do
  @moduledoc """
  Public API for item definition lookups.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  @spec get_item_by_id(integer()) :: {:ok, ItemDefinition.t()} | {:error, :item_not_found}
  def get_item_by_id(id) do
    with :error <- Items.by_id(id), do: {:error, :item_not_found}
  end

  @spec get_item_by_aegis(String.t()) :: {:ok, ItemDefinition.t()} | {:error, :item_not_found}
  def get_item_by_aegis(aegis) do
    with :error <- Items.by_aegis(aegis), do: {:error, :item_not_found}
  end

  @spec get_all_items() :: [ItemDefinition.t()]
  def get_all_items, do: Items.all()
end
