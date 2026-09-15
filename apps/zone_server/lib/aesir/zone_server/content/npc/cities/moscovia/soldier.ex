defmodule Aesir.ZoneServer.Content.Npc.Cities.Moscovia.Soldier do
  @moduledoc """
  Warns visitors not to trouble Moscovia's ruler.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moscovia",
        x: 253,
        y: 166,
        dir: 4,
        sprite: 966,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#mosk1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes("Our dear Csar Alexsay III is in the palace.")
    |> mes("He rules over Moscovia.")
    |> mes("Please be careful not to cause him any trouble.")
    |> close()
  end
end
