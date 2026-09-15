defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.Anku do
  @moduledoc """
  Looks for Himuhimu during a game of Hide-and-Seek.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 260,
        y: 175,
        dir: 3,
        sprite: 914,
        name: "Anku",
        scope: :shared,
        unique_name: "Anku#aru"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Anku]")
    |> mes("It's been so long")
    |> mes("already! I can't find")
    |> mes("Himuhimu! Hide-and-Seek")
    |> mes("shouldn't take this long...")
    |> next()
    |> mes("[Anku]")
    |> mes("Oh, I'm already hungry...")
    |> mes("Himuhimu, come out so")
    |> mes("we can go home and eat!")
    |> mes("Himuhimu! I give up!")
    |> mes("H-Himuhimu...?")
    |> close()
  end
end
