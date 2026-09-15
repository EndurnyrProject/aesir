defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Lowe do
  @moduledoc """
  Warns visitors about strict discipline in the Einbroch factory.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 48,
        y: 220,
        dir: 5,
        sprite: 851,
        name: "Lowe",
        scope: :shared,
        unique_name: "Lowe#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Lowe]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Lowe]")
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("[Lowe]")
    |> mes("Hey. Why are you")
    |> mes("looking at me like")
    |> mes("that? There's no idle")
    |> mes("chatting allowed at work.")
    |> mes("If Canphotii catches")
    |> mes("you, you'll be punished...")
    |> next()
    |> mes("[Lowe]")
    |> mes("Oh wait...")
    |> mes("You don't work here.")
    |> mes("I apologize, that kind")
    |> mes("of reaction's an old")
    |> mes("habit for me, adventurer.")
    |> close()
  end
end
