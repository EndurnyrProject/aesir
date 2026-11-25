defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.BarmutRoom2 do
  @moduledoc """
  An inactive scene prop marks Barmunt’s room.

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
        map: "que_ba",
        x: 263,
        y: 276,
        dir: 3,
        sprite: 755,
        name: "",
        scope: :shared,
        unique_name: "#barmut_room2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
