defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Kid253133 do
  @moduledoc """
  Shares a child's observations about life in Veins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 253,
        y: 133,
        dir: 3,
        sprite: 944,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#ve2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("Gosh, where could she")
    |> mes("be hiding? I hate being")
    |> mes("it... There's so many places")
    |> mes("to hide around here. There")
    |> mes("must be someplace I haven't")
    |> mes("checked yet... Let's see...")
    |> close()
  end
end
