defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier3251 do
  @moduledoc """
  Complains about his worsening cold.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_in02",
        x: 32,
        y: 51,
        dir: 6,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama4"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Shiro]")
    |> mes("*Cough, Cough* What...")
    |> mes("Don't talk to me...")
    |> mes("*Cough, Cough*... Oh, my freakin' neck.")
    |> next()
    |> mes("[Shiro]")
    |> mes("That quack's cold medicine")
    |> mes("is useless! I should never have trusted people from Midgard!")
    |> mes("*Cough, Cough*...")
    |> next()
    |> mes("[Shiro]")
    |> mes("I don't know why but...")
    |> mes("I'm getting worse and worse...")
    |> mes("What kind of cold is this?")
    |> mes("*Cough*... *Cough*...")
    |> close()
  end
end
