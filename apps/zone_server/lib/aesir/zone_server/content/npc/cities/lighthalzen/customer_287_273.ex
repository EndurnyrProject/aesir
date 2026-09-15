defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Customer287273 do
  @moduledoc """
  Recommends the hotel's bar for its relaxing atmosphere.

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
        x: 287,
        y: 273,
        dir: 3,
        sprite: 50,
        name: "Customer",
        scope: :shared,
        unique_name: "Customer#amano11"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Terry]")
    |> mes("I'm not big on drinking,")
    |> mes("but the atmosphere in this")
    |> mes("place is really nice. The")
    |> mes("music they play is always")
    |> mes("smooth and relaxing...")
    |> next()
    |> mes("[Terry]")
    |> mes("Yeah, this is a real cozy")
    |> mes("joint. I recommend it to")
    |> mes("all you tourists, actually.")
    |> mes("Now why don't you kick")
    |> mes("back and chill with me?")
    |> close()
  end
end
