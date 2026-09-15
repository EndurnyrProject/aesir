defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.Citizen do
  @moduledoc """
  Offers Freya's blessing and hopes for help finding a girlfriend.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 124,
        y: 132,
        dir: 1,
        sprite: 921,
        name: "Citizen",
        scope: :shared,
        unique_name: "Citizen#1 "
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Citizen]")
    |> mes("May Freya bless")
    |> mes("you, and give you an")
    |> mes("abundance of health,")
    |> mes("wealth, joy, and happiness!")
    |> next()
    |> mes("[Citizen]")
    |> mes("Freya is the goddess of")
    |> mes("love and beauty. Do you")
    |> mes("think that if I pray hard")
    |> mes("enough, she'll help me")
    |> mes("get a really pretty girlfriend?")
    |> close()
  end
end
