defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.RekenberEmployee do
  @moduledoc """
  Shares Rekenber Employee's remarks with visitors to Lighthalzen.

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
        x: 159,
        y: 222,
        dir: 1,
        sprite: 109,
        name: "Rekenber Employee",
        scope: :shared,
        unique_name: "Rekenber Employee#li"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Benatuth]")
    |> mes("Down there, the repairman")
    |> mes("is just finishing maintenance")
    |> mes("on our chairman's private")
    |> mes("Airship. Can you imagine")
    |> mes("having one of those of your")
    |> mes("very own to fly around in?")
    |> next()
    |> mes("[Benatuth]")
    |> mes("Yeah, the chairman of")
    |> mes("the Rekenber Corporation...")
    |> mes("He's a really powerful person.")
    |> mes("It's almost scary what he can")
    |> mes("do with his money, you know?")
    |> close()
  end
end
