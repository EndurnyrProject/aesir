defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Guard do
  @moduledoc """
  Warns visitors to keep clear of a restricted area.

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
        map: "lhz_in01",
        x: 173,
        y: 28,
        dir: 4,
        sprite: 868,
        name: "Guard",
        scope: :shared,
        unique_name: "LhzRekGuard"
      },
      %{
        map: "lhz_in01",
        x: 180,
        y: 28,
        dir: 4,
        sprite: 868,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#03"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("This is a")
    |> mes("restricted area.")
    |> mes("Please keep clear")
    |> mes("if you do not have")
    |> mes("special authorization.")
    |> mes("Thank you for your cooperating.")
    |> close()
  end
end
