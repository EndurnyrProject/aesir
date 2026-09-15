defmodule Aesir.ZoneServer.Content.Npc.Cities.Ayothaya.Girl do
  @moduledoc """
  Shares one of Lalitha's observations about Ayothaya and its visitors.

  ## Behavior

  - Randomly discusses visitors from Midgard or the dangerous shrine ruins.
  - Uses dialogue emotions while reacting to the player.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayothaya",
        x: 171,
        y: 152,
        dir: 5,
        sprite: 838,
        name: "Girl",
        scope: :shared,
        unique_name: "Girl#Lalitha"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case Enum.random(1..5) do
      roll when roll < 3 -> discuss_midgard(ctx)
      roll when roll < 6 -> discuss_shrine(ctx)
      _ -> ctx |> mes("[Lalitha]") |> mes("Mmm...?") |> mes("What's up?") |> close()
    end
  end

  defp discuss_midgard(ctx) do
    ctx
    |> mes("[Lalitha]")
    |> mes("Hello!")
    |> mes("I don't think")
    |> mes("we've met before.")
    |> next()
    |> mes("[Lalitha]")
    |> mes("You must be")
    |> mes("from Midgard.")
    |> mes("After all, I know every single person living in this village.")
    |> mes("Heh heh~")
    |> next()
    |> mes("[Lalitha]")
    |> mes("Hmm...")
    |> mes("May I ask about the land you")
    |> mes("come from? I'm curious about")
    |> mes("a lot of things in the outside world.")
    |> next()
    |> mes("[Lalitha]")
    |> mes(
      "You know, like the dresses and jewelry that ladies wear in other countries, whether or not the men are good looking, what kind of songs you have, what kind of girls that guys over there like..."
    )
    |> emotion(:question)
    |> next()
    |> player_name()
    |> mes(".........")
    |> next()
    |> mes("[Lalitha]")
    |> mes("..........")
    |> emotion(:sweat)
    |> next()
    |> mes("[Lalitha]")
    |> mes("Okay~!")
    |> mes("Take care and")
    |> mes("enjoy your travels!")
    |> close()
  end

  defp discuss_shrine(ctx) do
    ctx
    |> mes("[Lalitha]")
    |> mes("When you go East from this")
    |> mes("village, you will arrive at the ruins of an old shrine. It is now")
    |> mes("a nest full of fearsome monsters.")
    |> next()
    |> mes("[Lalitha]")
    |> mes("If you plan to venture through these ruins, you better prepare")
    |> mes("as much as you can!")
    |> next()
    |> mes("[Lalitha]")
    |> mes("Ah...")
    |> mes("I wonder where")
    |> mes("my Black Knight is~")
    |> emotion(:throb)
    |> next()
    |> player_name()
    |> mes("Don't you mean...")
    |> mes("Knight in shining armor")
    |> mes("riding a white horse?")
    |> next()
    |> mes("[Lalitha]")
    |> mes("Hmm...?")
    |> mes("Oh, well...")
    |> mes("I'll take them both!")
    |> mes("Hee hee~!")
    |> close()
  end

  defp player_name(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")
end
