defmodule Aesir.ZoneServer.Content.Npc.Cities.Hugel.OldNikki do
  @moduledoc """
  Recognizes visitors by their youth and unfamiliar appearance.

  ## Credits

  - Original from rAthena, authors and Contributors
    - vicious_pucca
    - Poki#3
    - erKURITA
    - Munin

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "hugel", x: 169, y: 112, dir: 5, sprite: 892, name: "Old Nikki", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Old Nikki]")
    |> mes("You must not be from")
    |> mes("around here. Ah, you're")
    |> mes("an adventurer, right? Do")
    |> mes("you know how I could tell?")
    |> next()
    |> mes("[Old Nikki]")
    |> mes("It's because everyone")
    |> mes("who's lived here starts")
    |> mes("to look alike after a while.")
    |> mes("And you certainly don't look")
    |> mes("as old as us. Well, have")
    |> mes("a nice day, adventurer~")
    |> close()
  end
end
