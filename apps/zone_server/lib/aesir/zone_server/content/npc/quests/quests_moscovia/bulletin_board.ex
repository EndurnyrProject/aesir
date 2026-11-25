defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.BulletinBoard do
  @moduledoc """
  A bulletin board displays the charabel departure schedule.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moscovia",
        x: 135,
        y: 52,
        dir: 0,
        sprite: 837,
        name: "Bulletin Board",
        scope: :shared,
        unique_name: "Bulletin Board#npc"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Charabel Schedule]")
    |> mes("NOTICE, due to the varying")
    |> mes("tides here in Moscovia,")
    |> mes("the charabel can only")
    |> mes("depart when the tide is low.")
    |> next()
    |> mes("[Charabel Schedule]")
    |> mes("The Charabel can depart")
    |> mes("between the following times:")
    |> mes("^0000FF12:00am PST^000000 to ^0000FF3:00am PST")
    |> mes("^0000FF6:00am PST^000000 to ^0000FF9:00am PST")
    |> mes("^0000FF12:00pm PST^000000 to ^0000FF3:00pm PST")
    |> mes("^0000FF6:00pm PST^000000 to ^0000FF9:00pm PST")
    |> close()
  end
end
