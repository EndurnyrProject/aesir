defmodule Aesir.ZoneServer.Mmo.Skills.Clown.TarotDeckTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skills.Clown.TarotDeck

  setup :set_mimic_private

  test "each weighted interval includes its upper boundary and the next roll starts the next card" do
    Mimic.copy(TarotDeck)

    for {roll, card} <- [
          {1, :fool},
          {10, :fool},
          {11, :magician},
          {20, :magician},
          {21, :high_priestess},
          {30, :high_priestess},
          {31, :chariot},
          {37, :chariot},
          {38, :strength},
          {47, :strength},
          {48, :lovers},
          {62, :lovers},
          {63, :wheel_of_fortune},
          {64, :hanged_man},
          {69, :hanged_man},
          {70, :death},
          {74, :death},
          {75, :temperance},
          {82, :temperance},
          {83, :devil},
          {84, :tower},
          {85, :tower},
          {86, :star},
          {90, :star},
          {91, :sun},
          {100, :sun}
        ] do
      stub(TarotDeck, :roll, fn 100 -> roll end)
      assert TarotDeck.draw() == card
    end
  end
end
