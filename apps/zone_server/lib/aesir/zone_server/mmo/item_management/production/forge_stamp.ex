defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.ForgeStamp do
  @moduledoc """
  Encodes and decodes forged weapon metadata in inventory card slots.
  """

  import Bitwise

  @forge_marker 0x00FF

  @type element :: :neutral | :water | :earth | :fire | :wind
  @type stamp :: %{card0: integer(), card1: integer(), card2: integer(), card3: integer()}
  @type metadata :: %{
          element: element(),
          star_damage: non_neg_integer(),
          creator_id: non_neg_integer()
        }

  @doc "Encodes forged weapon metadata into the four inventory card values."
  @spec encode(element(), 0..3, non_neg_integer()) :: stamp()
  def encode(element, crumb_count, character_id)
      when crumb_count in 0..3 and character_id in 0..0xFFFF_FFFF do
    %{
      card0: @forge_marker,
      card1: (crumb_count * 5) <<< 8 ||| element_id(element),
      card2: character_id &&& 0xFFFF,
      card3: character_id >>> 16
    }
  end

  @doc "Decodes forged weapon card values, returning `:error` for invalid metadata."
  @spec decode(term()) :: {:ok, metadata()} | :error
  def decode(%{card0: @forge_marker, card1: card1, card2: low, card3: high})
      when card1 in 0..0xFFFF and low in 0..0xFFFF and high in 0..0xFFFF do
    stored_crumb_value = card1 >>> 8

    with true <- (card1 &&& 0xF0) == 0,
         true <- stored_crumb_value in [0, 5, 10, 15],
         {:ok, element} <- element(card1 &&& 0x0F) do
      {:ok,
       %{
         element: element,
         star_damage: star_damage(stored_crumb_value),
         creator_id: high <<< 16 ||| low
       }}
    else
      _invalid_payload -> :error
    end
  end

  def decode(_item), do: :error

  defp element_id(:neutral), do: 0
  defp element_id(:water), do: 1
  defp element_id(:earth), do: 2
  defp element_id(:fire), do: 3
  defp element_id(:wind), do: 4

  defp element(0), do: {:ok, :neutral}
  defp element(1), do: {:ok, :water}
  defp element(2), do: {:ok, :earth}
  defp element(3), do: {:ok, :fire}
  defp element(4), do: {:ok, :wind}
  defp element(_id), do: :error

  defp star_damage(15) do
    # At three crumbs, the stored value remains 15 while the Renewal combat bonus is 40.
    40
  end

  defp star_damage(stored_crumb_value), do: stored_crumb_value
end
