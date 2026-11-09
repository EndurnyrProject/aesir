defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Yuno.Junosoldier3 do
  @moduledoc """
  Juno soldier who warns travelers about the False Angel.

  ## Behavior

  - Describes the fallen angel that lures adventurers in before attacking.

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
        x: 227,
        y: 292,
        dir: 4,
        sprite: 852,
        name: "Juno Soldier",
        scope: :renewal,
        unique_name: "Juno Soldier#3juno"
      },
      %{
        map: "yuno",
        x: 227,
        y: 292,
        dir: 4,
        sprite: 105,
        name: "Juno Soldier",
        scope: :pre_renewal,
        unique_name: "Juno Soldier#3juno"
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
    |> mes(
      "Near Juno, there exists a fallen angel named 'False Angel.' It feigns innocence, pretending to bless adventurers and then stabbing them in the back without any warning."
    )
    |> next()
    |> mes("[Juno Soldier]")
    |> mes("Don't be fooled by its appearance, or you'll find yourself in trouble.")
    |> close()
  end
end
