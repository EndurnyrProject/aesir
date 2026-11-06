defmodule Aesir.ZoneServer.Content.Npc.Floating.Junosoldier5 do
  @moduledoc """
  Juno soldier who marvels at the size of a Large Jellopy.

  ## Behavior

  - Wonders at how large and shiny a jellopy can grow.

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
        x: 150,
        y: 228,
        dir: 4,
        sprite: 852,
        name: "Juno Soldier",
        scope: :renewal,
        unique_name: "Juno Soldier#5juno"
      },
      %{
        map: "yuno",
        x: 150,
        y: 228,
        dir: 4,
        sprite: 105,
        name: "Juno Soldier",
        scope: :pre_renewal,
        unique_name: "Juno Soldier#5juno"
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
    |> mes("Have you ever")
    |> mes("seen a Large Jellopy?")
    |> mes("Those things are huuuge!")
    |> next()
    |> mes("[Juno Soldier]")
    |> mes("It's hard to believe")
    |> mes("that such a large and")
    |> mes("shining jellopy even exists!")
    |> close()
  end
end
