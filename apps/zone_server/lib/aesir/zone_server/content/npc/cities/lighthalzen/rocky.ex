defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Rocky do
  @moduledoc """
  Responds with one of two random dog sounds.

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
        x: 100,
        y: 18,
        dir: 3,
        sprite: 81,
        name: "Rocky",
        scope: :shared,
        unique_name: "Rocky#li_house"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if Enum.random(1..2) == 1 do
      ctx |> mes("[Rocky]") |> mes("Woof woof!") |> close()
    else
      ctx |> mes("[Rocky]") |> mes("Grrrrrrr...") |> close()
    end
  end
end
