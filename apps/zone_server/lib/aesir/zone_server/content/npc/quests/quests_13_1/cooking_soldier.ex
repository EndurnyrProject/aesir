defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.CookingSoldier do
  @moduledoc """
  Alix, a soldier in the expedition camp who boasts about his chocolate pie.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 159,
        y: 282,
        dir: 4,
        sprite: 886,
        name: "Cooking Soldier",
        scope: :shared,
        unique_name: "Cooking Soldier#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Alix]")
    |> mes("Huu, I made this and")
    |> mes("this is really great.")
    |> mes("When I am back")
    |> mes("to the motherland,")
    |> mes("I will open a shop for it!!")
    |> next()
    |> mes("[Alix]")
    |> mes("Have you had it?")
    |> mes("My chocolate pie!!!")
    |> mes("This food is a real miracle!!")
    |> close()
  end
end
