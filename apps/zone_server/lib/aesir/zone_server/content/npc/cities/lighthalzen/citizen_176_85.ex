defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Citizen17685 do
  @moduledoc """
  Shares Dique's fondness for relaxing at pubs after work.

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
        x: 176,
        y: 85,
        dir: 5,
        sprite: 869,
        name: "Citizen",
        scope: :shared,
        unique_name: "Citizen#amano04"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Dique]")
    |> mes("One of the things I look")
    |> mes("forward to during my day")
    |> mes("is the drink I enjoy right")
    |> mes("after work. It's the most")
    |> mes("relaxing thing in the world.")
    |> next()
    |> mes("[Dique]")
    |> mes("Of course, there's")
    |> mes("more to life than just")
    |> mes("hanging out in pubs and")
    |> mes("bars. The thing is, in my")
    |> mes("case, pubs and bars are")
    |> mes("all I happen to need~")
    |> close()
  end
end
