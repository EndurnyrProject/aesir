defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier37157 do
  @moduledoc """
  Discusses the soldiers and a suspicious visitor.

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
        x: 37,
        y: 157,
        dir: 4,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Saburo]")
    |> mes("This is the training ground for improving our battle skills.")
    |> mes("Please look around...")
    |> next()
    |> mes("[Saburo]")
    |> mes("By the way, recently I've felt")
    |> mes("like the soldiers have changed")
    |> mes("lately. How do I say it...")
    |> mes("Their faces are gloomy and")
    |> mes("some of them are no longer around.")
    |> mes("Have they gone to Midgard??")
    |> next()
    |> mes("[Saburo]")
    |> mes("In this job, I encounter")
    |> mes("many strangers. But downstairs,")
    |> mes("there's a guest from a distant land who seems suspicious...")
    |> mes("I told my guards to watch him...")
    |> next()
    |> mes("[Saburo]")
    |> mes("Of course, my lord precisely knows everything that's going on.")
    |> mes("Haha, don't take what I said seriously~")
    |> mes("See ya...")
    |> close()
  end
end
