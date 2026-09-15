defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Kid206275 do
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
        x: 206,
        y: 275,
        dir: 3,
        sprite: 941,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#ve3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("I really want to look")
    |> mes("inside the temple, but")
    |> mes("it looks so scary from")
    |> mes("the outside! I wonder")
    |> mes("why it's like that?")
    |> close()
  end
end
