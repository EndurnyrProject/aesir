defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.ShopAssistant do
  @moduledoc """
  Shares Shop Assistant's remarks with visitors to Lighthalzen.

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
        x: 267,
        y: 22,
        dir: 1,
        sprite: 91,
        name: "Shop Assistant",
        scope: :shared,
        unique_name: "Shop Assistant#cobo"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Shop Assistant]")
      |> mes("Welcome to our")
      |> mes("store where we offer")
      |> mes("many unique products that")
      |> mes("you can't find anywhere else.")
      |> next()
      |> mes("[Shop Assistant]")
      |> mes("However, shopping is only available to our members. There's an annual")
      |> mes("membership fee that's waived when you spend a certain amount every")
      |> mes("month in our store. If you invite your friends, you'll receive spe--")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("N-no thank you!")
    |> mes("I'm not interested!")
    |> close()
  end
end
