defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Pevtatin do
  @moduledoc """
  Complains about stressful factory work before returning to his task.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 33,
        y: 275,
        dir: 1,
        sprite: 848,
        name: "Pevtatin",
        scope: :shared,
        unique_name: "Pevtatin#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Pevtatin]")
    |> mes("Good god!")
    |> mes("I'm so stressed!")
    |> mes("It's been nonstop")
    |> mes("since I moved here!")
    |> next()
    |> mes("[Pevtatin]")
    |> mes("The work is tough and")
    |> mes("already the boss hates")
    |> mes("me! I didn't move here")
    |> mes("for this! Still, the pay is")
    |> mes("decent so I guess I should")
    |> mes("endure just a little longer.")
    |> next()
    |> mes("[Pevtatin]")
    |> mes("Here goes...!")
    |> mes("Yo-heave-ho!")
    |> mes("Yo-heave-ho~!")
    |> close()
  end
end
