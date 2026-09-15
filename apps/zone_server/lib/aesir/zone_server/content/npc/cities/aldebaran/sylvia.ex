defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.Sylvia do
  @moduledoc """
  Explains how Magnifiers appraise unidentified equipment.

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
        x: 60,
        y: 70,
        dir: 4,
        sprite: 69,
        name: "Sylvia",
        scope: :shared,
        unique_name: "Sylvia#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sylvia]")
      |> mes(
        "I came all the way here from Prontera because I heard the Kafra Main Office was somewhere here in Al De Baran."
      )
      |> next()
      |> mes("[Sylvia]")
      |> mes(
        "It shouldn't be that hard to find, but I'm awful at following directions. I always get lost, no matter how hard I try!"
      )
      |> next()
      |> mes("[Sylvia]")
      |> mes(
        "If that wasn't bad enough, I left my Magnifiers back in Prontera, so now I have to find someone to help me with these weapons I've got to appraise!"
      )
      |> next()
      |> select(["Appraise?", "That's very nice."])

    if choice == 1 do
      ctx
      |> mes("[Sylvia]")
      |> mes("Equipment that is dropped by monsters can't be equipped right away.")
      |> next()
      |> mes("[Sylvia]")
      |> mes(
        "If you right-click the equippable item in the Item Inventory, you'll see that it is Unidentified and that Appraisal is needed. What to do?"
      )
      |> next()
      |> mes("[Sylvia]")
      |> mes("Well, in that case, you've gotta use ^3355FF Magnifier^000000!")
      |> next()
      |> mes("[Sylvia]")
      |> mes(
        "Even without a Blacksmith, Alchemist or Merchant in your party, you can appraise your equipment! Of course, a Magnifier is consumed each time you use one..."
      )
      |> close()
    else
      ctx
      |> mes("[Sylvia]")
      |> mes("Hey...")
      |> mes("Was that a hint of sarcasm in your voice when you said that?")
      |> close()
    end
  end
end
