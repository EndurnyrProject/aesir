defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Sopheap do
  @moduledoc """
  Shares Sopheap's remarks with visitors to Lighthalzen.

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
        x: 32,
        y: 99,
        dir: 3,
        sprite: 863,
        name: "Sopheap",
        scope: :shared,
        unique_name: "Sopheap#zen1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Sopheap]")
    |> mes("Oh, you youngsters.")
    |> mes("Always traveling around")
    |> mes("and having adventures and")
    |> mes("fighting monsters. I certainly")
    |> mes("had my fill of excitement back")
    |> mes("when I was your age, long ago.")
    |> next()
    |> mes("[Sopheap]")
    |> mes("Sure, I miss doing all")
    |> mes("of that, but now I'm content")
    |> mes("with just relaxing and resting.")
    |> mes("Still, there are a lot of old folk who refuse to sit still like this~")
    |> close()
  end
end
