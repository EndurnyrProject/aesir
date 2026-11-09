defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Moscovia.Soldier do
  @moduledoc """
  Palace guard in Moscovia who hushes anyone loud near the Csar.

  ## Behavior

  - Warns the player to keep quiet.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/moscovia.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_in",
        x: 118,
        y: 66,
        dir: 5,
        sprite: 966,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#mosk02"
      },
      %{
        map: "mosk_in",
        x: 133,
        y: 110,
        dir: 3,
        sprite: 966,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#mosk03"
      },
      %{
        map: "mosk_in",
        x: 133,
        y: 73,
        dir: 3,
        sprite: 966,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#mosk04"
      },
      %{
        map: "mosk_in",
        x: 113,
        y: 124,
        dir: 5,
        sprite: 966,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#mosk05"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes("Please be silent or the Csar will be angry.")
    |> close()
  end
end
