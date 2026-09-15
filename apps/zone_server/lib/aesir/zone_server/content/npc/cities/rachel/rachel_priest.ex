defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.RachelPriest do
  @moduledoc """
  Enjoys drinking during work hours in Rachel.

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
      %{map: "rachel", x: 76, y: 77, dir: 3, sprite: 927, name: "Rachel Priest", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Rachel Priest]")
    |> mes("Bwahahaha! Somehow,")
    |> mes("drinks taste much better")
    |> mes("during work hours!")
    |> close()
  end
end
