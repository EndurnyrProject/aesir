defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Tanoue do
  @moduledoc """
  Shares Tanoue's remarks with visitors to Lighthalzen.

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
        x: 229,
        y: 217,
        dir: 3,
        sprite: 863,
        name: "Tanoue",
        scope: :shared,
        unique_name: "Tanoue#zen04"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Tanoue]")
    |> mes("This chair looks")
    |> mes("very nice, but it really")
    |> mes("chills my bottom. Brr...!")
    |> mes("It's a might uncomfortable!")
    |> next()
    |> mes("[Tanoue]")
    |> mes("You know what the")
    |> mes("perfect chair would")
    |> mes("be like? It would be")
    |> mes("plush and have electronic")
    |> mes("massage and heating controls...")
    |> close()
  end
end
