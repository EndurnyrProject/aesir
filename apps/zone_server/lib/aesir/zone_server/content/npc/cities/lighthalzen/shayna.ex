defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Shayna do
  @moduledoc """
  Shares Shayna's remarks with visitors to Lighthalzen.

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
        map: "lhz_in03",
        x: 26,
        y: 167,
        dir: 5,
        sprite: 850,
        name: "Shayna",
        scope: :shared,
        unique_name: "Shayna#li"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Shayna]")
    |> mes("^333333*Sigh...*^000000")
    |> mes("Oh, you poor")
    |> mes("darling girl...")
    |> close()
  end
end
