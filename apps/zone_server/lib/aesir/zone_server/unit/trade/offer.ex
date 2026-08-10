defmodule Aesir.ZoneServer.Unit.Trade.Offer do
  @moduledoc """
  A player's item and zeny offer in a trade.
  """

  alias Aesir.Commons.Models.InventoryItem

  @max_offer_slots 10

  @type entry :: %{
          row_id: integer(),
          amount: pos_integer(),
          snapshot: InventoryItem.t()
        }

  @type t() :: %__MODULE__{
          entries: [entry()],
          zeny: non_neg_integer()
        }

  defstruct entries: [], zeny: 0

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec add(t(), InventoryItem.t(), integer()) ::
          {:ok, t()} | {:error, :offer_full | :duplicate_item | :invalid_amount}
  def add(%__MODULE__{} = offer, %InventoryItem{} = snapshot, amount)
      when is_integer(amount) and amount >= 1 do
    cond do
      Enum.any?(offer.entries, &(&1.row_id == snapshot.id)) ->
        {:error, :duplicate_item}

      length(offer.entries) == @max_offer_slots ->
        {:error, :offer_full}

      true ->
        entry = %{row_id: snapshot.id, amount: amount, snapshot: snapshot}
        {:ok, %{offer | entries: offer.entries ++ [entry]}}
    end
  end

  def add(%__MODULE__{}, %InventoryItem{}, _amount), do: {:error, :invalid_amount}

  @spec remove(t(), integer()) :: {:ok, t()} | {:error, :not_found}
  def remove(%__MODULE__{} = offer, row_id) do
    entries = Enum.reject(offer.entries, &(&1.row_id == row_id))

    if length(entries) == length(offer.entries) do
      {:error, :not_found}
    else
      {:ok, %{offer | entries: entries}}
    end
  end

  @spec set_zeny(t(), integer()) :: {:ok, t()} | {:error, :invalid_amount}
  def set_zeny(%__MODULE__{} = offer, zeny) when is_integer(zeny) and zeny >= 0 do
    {:ok, %{offer | zeny: zeny}}
  end

  def set_zeny(%__MODULE__{}, _zeny), do: {:error, :invalid_amount}
end
