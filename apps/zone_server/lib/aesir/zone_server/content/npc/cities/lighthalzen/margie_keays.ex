defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.MargieKeays do
  @moduledoc """
  Shares Margie Keays' remarks with visitors to Lighthalzen.

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
        x: 65,
        y: 94,
        dir: 5,
        sprite: 863,
        name: "Margie Keays",
        scope: :shared,
        unique_name: "Margie Keays#li_02"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Margie Keays]")
    |> mes("Oh darling, the")
    |> mes("weather is so nice")
    |> mes("and pleasant today.")
    |> mes("I'm really glad we")
    |> mes("decided to go take")
    |> mes("a walk together~")
    |> close()
  end
end
