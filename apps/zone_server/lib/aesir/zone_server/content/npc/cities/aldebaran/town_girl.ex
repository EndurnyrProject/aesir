defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.TownGirl do
  @moduledoc """
  Discusses the Assassin Guild and the value of DEX for fast targets.

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
        x: 146,
        y: 124,
        dir: 4,
        sprite: 101,
        name: "Town Girl",
        scope: :shared,
        unique_name: "Town Girl#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nastasia]")
      |> mes(
        "Somewhere in the world there is an ^3355FFAssassin Guild^000000, where they teach people the subtle art of assassination."
      )
      |> next()
      |> mes("[Nastasia]")
      |> mes("But isn't killing illegal? And do they even collect educational tuition?")
      |> next()
      |> select(["Continue conversation.", "End Conversation."])

    if choice == 1 do
      ctx
      |> mes("[Nastasia]")
      |> mes(
        "Although Assassins benefit from being very quick and having lots of AGI, they should still have some DEX."
      )
      |> next()
      |> mes("[Nastasia]")
      |> mes(
        "DEX is especially important if you want to hit monsters with wings. Those monsters are quick moving and fast in attacking."
      )
      |> next()
      |> mes("[Nastasia]")
      |> mes(
        "In general, if you want to hit monsters that are as fast, or even faster, than you are, you're going to need some DEX."
      )
      |> close()
    else
      ctx
      |> mes("[Nastasia]")
      |> mes(
        "It's usually said that in this world, nothing is free. Still, if you don't have to pay money to learn to be an Assassin..."
      )
      |> close()
    end
  end
end
