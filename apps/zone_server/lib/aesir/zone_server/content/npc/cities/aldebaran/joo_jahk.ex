defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.JooJahk do
  @moduledoc """
  Shares travel advice about monster properties and Al De Baran’s canal water.

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
        x: 180,
        y: 46,
        dir: 4,
        sprite: 88,
        name: "Joo Jahk",
        scope: :shared,
        unique_name: "Joo Jahk#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Joo Jahk]")
      |> mes("I'm a tourist")
      |> mes("from Payon,")
      |> mes("the City of Forests.")
      |> next()
      |> mes("[Joo Jahk]")
      |> mes(
        "The tempature here in Al De Baran is very cool, probably because of the waterways. Do you think the water in the canals is drinkable?"
      )
      |> next()
      |> mes("[Joo Jahk]")
      |> mes(
        "Well, it's too late for me, since I already drank some. Still, I'm a little worried..."
      )
      |> next()
      |> select(["Continue.", "End conversation."])

    if choice == 1 do
      ctx
      |> mes("[Joo Jahk]")
      |> mes(
        "On one of my travels around Midgard, I've heard from a really high level Mage that physical attacks, or magic with Neutral Property, won't damage Spiritual Property monsters."
      )
      |> next()
      |> mes("[Joo Jahk]")
      |> mes(
        "Maybe that advice will come in handy, now that you know that. Always remember the importance of the Properties of your skills and weapons when battling monsters."
      )
      |> close()
    else
      ctx
      |> mes("[Joo Jahk]")
      |> mes(
        "On the other hand, the water I drank did taste pretty good. Hopefully it didn't have anything too weird in it..."
      )
      |> close()
    end
  end
end
