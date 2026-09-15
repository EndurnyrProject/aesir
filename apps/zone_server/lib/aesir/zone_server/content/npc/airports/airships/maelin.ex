defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Maelin do
  @moduledoc """
  Waits aboard the domestic airship for a nonexistent announcement about Lutie.

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
        x: 65,
        y: 63,
        dir: 4,
        sprite: 714,
        name: "Maelin",
        scope: :shared,
        unique_name: "Maelin#01airplane"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Maelin]")
    |> mes("Um, this Airship is")
    |> mes("to Lutie, isn't it? I've")
    |> mes("waiting so long,")
    |> mes("but I haven't heard any")
    |> mes("broadcast about Lutie.")
    |> close()
  end
end
