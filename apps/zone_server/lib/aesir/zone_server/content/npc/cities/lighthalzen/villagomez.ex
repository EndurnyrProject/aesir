defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Villagomez do
  @moduledoc """
  Shares Villagomez's remarks with visitors to Lighthalzen.

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
        map: "lighthalzen",
        x: 77,
        y: 157,
        dir: 5,
        sprite: 866,
        name: "Villagomez",
        scope: :shared,
        unique_name: "Villagomez#li_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Villagomez]")
    |> mes("I just step out to get")
    |> mes("a haircut and now I'm")
    |> mes("lost. Boy oh boy, I hope")
    |> mes("I don't keep my family")
    |> mes("waiting. ^333333*Sigh...*^000000")
    |> close()
  end
end
