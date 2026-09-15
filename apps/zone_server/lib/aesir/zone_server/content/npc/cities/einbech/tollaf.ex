defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.Tollaf do
  @moduledoc """
  Laments being unable to afford moving away from Einbech.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbech",
        x: 151,
        y: 168,
        dir: 3,
        sprite: 855,
        name: "Tollaf",
        scope: :shared,
        unique_name: "Tollaf#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Tollaf]")
    |> mes("Ah...!")
    |> mes("This is killing me!")
    |> mes("I don't have the money")
    |> mes("to move, but I don't wanna")
    |> mes("live in this town anymore!")
    |> next()
    |> mes("[Tollaf]")
    |> mes("People everywhere else")
    |> mes("live so much better than we")
    |> mes("do, especially those snobs in")
    |> mes("Einbroch! Einbech must be the")
    |> mes("worst town Schwarzwald Republic. No, it's the worst in the world!")
    |> close()
  end
end
