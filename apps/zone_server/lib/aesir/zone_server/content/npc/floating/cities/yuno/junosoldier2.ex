defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Yuno.Junosoldier2 do
  @moduledoc """
  Juno soldier who warns travelers about the Geographer.

  ## Behavior

  - Explains the flower-like monster's long reach and how its name was earned.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf
    - massdriller
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/yuno.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 165,
        y: 283,
        dir: 4,
        sprite: 852,
        name: "Juno Soldier",
        scope: :renewal,
        unique_name: "Juno Soldier#2juno"
      },
      %{
        map: "yuno",
        x: 165,
        y: 283,
        dir: 4,
        sprite: 105,
        name: "Juno Soldier",
        scope: :pre_renewal,
        unique_name: "Juno Soldier#2juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Juno Soldier]")
    |> mes("Welcome to Juno, the city of noble-mindedness.")
    |> next()
    |> mes("[Juno Soldier]")
    |> mes("Geographer...")
    |> mes("That monster looks like a flower blooming from the ground.")
    |> next()
    |> mes("[Juno Soldier]")
    |> mes(
      "Strangely, it can extend its body a long distance. Even if you're far away from it, it can still pose a threat."
    )
    |> next()
    |> mes("[Juno Soldier]")
    |> mes(
      "The name of this monster originated from a story about a poor geographer who, unfortunately, was eaten by this monster while he was immersed in his studies."
    )
    |> close()
  end
end
