defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Togii do
  @moduledoc """
  Shares Togii's remarks with visitors to Lighthalzen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in02",
        x: 145,
        y: 177,
        dir: 0,
        sprite: 849,
        name: "Togii",
        scope: :shared,
        unique_name: "Togii#07"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Togii]")
    |> mes("Oooh yeah...")
    |> mes("Goes down smooth.")
    |> mes("Morocc whiskey's the best!")
    |> mes("^333333*Hiccup*^000000 Whoa, this stuff")
    |> mes("really works fast! Heh heh~")
    |> close()
  end
end
