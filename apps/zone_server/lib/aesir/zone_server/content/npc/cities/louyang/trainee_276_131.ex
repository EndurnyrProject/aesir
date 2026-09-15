defmodule Aesir.ZoneServer.Content.Npc.Cities.Louyang.Trainee276131 do
  @moduledoc """
  Voices a martial arts trainee's practice cries.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vidar
    - Mass Zero
    - Dino9021
    - Celest
    - MasterOfMuppets
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "louyang",
        x: 276,
        y: 131,
        dir: 0,
        sprite: 819,
        name: "Trainee",
        scope: :shared,
        unique_name: "Trainee#2lou"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Trainee]")
    |> mes("Tah Tah Tah!")
    |> mes("Taaaaaah~~!!")
    |> mes("Schwooooooo~")
    |> close()
  end
end
