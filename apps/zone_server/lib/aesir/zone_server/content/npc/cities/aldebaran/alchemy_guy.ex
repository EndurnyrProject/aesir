defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.AlchemyGuy do
  @moduledoc """
  Explains alchemy, its history, and the use of monster cards.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 121,
        y: 231,
        dir: 4,
        sprite: 49,
        name: "Alchemy Guy",
        scope: :shared,
        unique_name: "Alchemy Guy#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Chemirre]")
      |> mes(
        "Alchemists, one of the 2nd Jobs, are able to create items out of several materials using knowledge from the ancient age of Al De Baran."
      )
      |> next()
      |> select([
        "About Alchemy in Payon",
        "Definition of Alchemy",
        ". . . . .",
        "End Conversation"
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Chemirre]")
        |> mes(
          "Most people don't know that there was an oriental form of Alchemy that developed in Payon."
        )
        |> next()
        |> mes("[Chemirre]")
        |> mes(
          "These Payon Alchemists were able to create Gold out of different materials. However, Payon Alchemy never advanced as much as the Alchemy in Al De Baran."
        )
        |> next()
        |> mes("[Chemirre]")
        |> mes(
          "Materials for Alchemy in Payon were scarce and interest in that field eventually waned. Now, you can only study Alchemy here in Al De Baran."
        )
        |> next()
        |> mes("[Chemirre]")
        |> mes(
          "Still, I can't help but wonder what secrets were lost after the Payon art of Alchemy disappeared from the face of the Earth..."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Chemirre]")
        |> mes(
          "Alchemists specialize in chemical research in order to create useful items out of various things."
        )
        |> next()
        |> mes("[Chemirre]")
        |> mes(
          "I also hear that they create all sorts of Potions, and can even summon certain monsters! It seems that their studies have all sorts of nifty applications."
        )
        |> close()

      3 ->
        ctx
        |> mes("[Chemirre]")
        |> mes("You are bored, aren't you?")
        |> mes("Alright then, I will tell you a story about monster cards and item slots.")
        |> mes("As you already know, if you ever have obtained a monster card before,")
        |> next()
        |> mes("[Chemirre]")
        |> mes("you can only insert a monster card to an item")
        |> mes("that satisfies the card's location requirement.")
        |> mes("For instance, let's say, you have obtained a Poring Card.")
        |> next()
        |> mes("[Chemirre]")
        |> mes("When you right click on the card, you will see")
        |> mes("its ability as LUK+2 and Perfect Dodge+1")
        |> mes("and its location as 'Armor'. ")
        |> next()
        |> mes("[Chemirre]")
        |> mes("If you try to insert this card to a dagger with many slots,")
        |> mes("it is not going to work because the card only can be inserted to")
        |> mes("armor items.")
        |> next()
        |> mes("[Chemirre]")
        |> mes("Almost every armor items that are being sold")
        |> mes("in town shops do not have slots on them.")
        |> mes("That means, you can only obtain")
        |> mes("slotted armors by hunting monsters.")
        |> next()
        |> mes("[Chemirre]")
        |> mes("Ah, let me tell you how you can insert a card to an item.")
        |> mes("If you want to insert a card on your equipped armor,")
        |> mes("you must unequip the armor first.")
        |> mes("And then, double click a card that you want to use.")
        |> mes("Then a list of armor, that you can insert the card, will be displayed.")
        |> next()
        |> mes("[Chemirre]")
        |> mes("It is not that complicated, is it?")
        |> close()

      4 ->
        ctx
        |> mes("[Chemirre]")
        |> mes("You can talk about Rune-Midgarts' alchemy")
        |> mes("without talking about the Al De Baran Alchemist Guild!")
        |> mes("Long Live Alchemists!")
        |> close()

      _ ->
        ctx
    end
  end
end
