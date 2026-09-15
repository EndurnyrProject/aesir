defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Aanos do
  @moduledoc """
  Shares his excitement about the view from the domestic airship.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "airplane",
        x: 72,
        y: 34,
        dir: 6,
        sprite: 702,
        name: "Aanos",
        scope: :shared,
        unique_name: "Aanos#01airplane"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Aanos]")
    |> mes("Oh wooow~")
    |> mes("The sky looks")
    |> mes("so different and")
    |> mes("pretty from up there!")
    |> close()
  end
end
