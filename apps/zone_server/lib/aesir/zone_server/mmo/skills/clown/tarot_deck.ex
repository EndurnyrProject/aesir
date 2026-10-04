defmodule Aesir.ZoneServer.Mmo.Skills.Clown.TarotDeck do
  @moduledoc """
  Weighted fourteen-card Tarot deck, identical in renewal and pre-renewal.

  The public roll and draw boundaries let tests pin success rolls and card
  choices without replacing any card's effect logic.
  """

  @typedoc "A card drawn from the official weighted deck."
  @type card() ::
          :fool
          | :magician
          | :high_priestess
          | :chariot
          | :strength
          | :lovers
          | :wheel_of_fortune
          | :hanged_man
          | :death
          | :temperance
          | :devil
          | :tower
          | :star
          | :sun

  @cards [
    {10, :fool},
    {20, :magician},
    {30, :high_priestess},
    {37, :chariot},
    {47, :strength},
    {62, :lovers},
    {63, :wheel_of_fortune},
    {69, :hanged_man},
    {74, :death},
    {82, :temperance},
    {83, :devil},
    {85, :tower},
    {90, :star},
    {100, :sun}
  ]

  @doc "Rolls uniformly from one through `n`."
  @spec roll(pos_integer()) :: pos_integer()
  def roll(n), do: :rand.uniform(n)

  @doc "Draws a card using cumulative percentage weights."
  @spec draw() :: card()
  def draw do
    value = __MODULE__.roll(100)
    Enum.find_value(@cards, fn {upper, card} -> if value <= upper, do: card end)
  end
end
