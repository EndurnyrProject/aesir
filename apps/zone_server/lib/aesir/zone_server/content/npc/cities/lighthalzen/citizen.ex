defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Citizen do
  @moduledoc """
  Shares Hachi's enthusiasm for bars, rum, and meeting women.

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
        x: 271,
        y: 281,
        dir: 2,
        sprite: 47,
        name: "Citizen",
        scope: :shared,
        unique_name: "Citizen#amano09"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hachi]")
    |> mes("Oh yeah. I love-love-love")
    |> mes("bars. If I don't come here")
    |> mes("for the booze, then I'm here")
    |> mes("for all these beautiful ladies.")
    |> next()
    |> mes("[Hachi]")
    |> mes("Weird. It's the very first")
    |> mes("time I've tried this place's")
    |> mes("rum, but doesn't it taste like")
    |> mes("pure sexiness to you? Huh...")
    |> mes("Oh well, back to schmoozin'")
    |> mes("with all the hot chicks~")
    |> close()
  end
end
