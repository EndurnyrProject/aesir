defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.CaveSettler10834 do
  @moduledoc """
  A cave settler whispers upon seeing a human.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cave",
        x: 108,
        y: 34,
        dir: 3,
        sprite: 979,
        name: "Cave Settler",
        scope: :shared,
        unique_name: "Cave Settler#f_cave6"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Cave Settler]")
    |> mes("Hoho, did he really say that yesterday...?")
    |> mes("Wah!")
    |> next()
    |> mes("[Cave Settler]")
    |> mes("It's a human...")
    |> next()
    |> mes("(Whisper)")
    |> mes("(Whisper)")
    |> close()
  end
end
