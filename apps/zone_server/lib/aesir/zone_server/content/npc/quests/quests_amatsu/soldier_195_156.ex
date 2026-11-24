defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier195156 do
  @moduledoc """
  Expresses loyalty to the troubled lord.

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
        x: 195,
        y: 156,
        dir: 4,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama9"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Kyuro]")
    |> mes("This is not good.")
    |> mes("My lord is really kind, but")
    |> mes("recently he is not doing well...")
    |> next()
    |> mes("[Kyuro]")
    |> mes("I've heard about the rumors")
    |> mes("but I trust him. He made")
    |> mes("Amatsu into a great town.")
    |> mes("That is why I'm following")
    |> mes("him as a soldier.")
    |> close()
  end
end
