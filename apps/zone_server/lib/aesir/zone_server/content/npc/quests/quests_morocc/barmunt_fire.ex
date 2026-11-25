defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.BarmuntFire do
  @moduledoc """
  An inactive scene prop marks the fire in Barmunt’s room.

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
        x: 270,
        y: 181,
        dir: 3,
        sprite: 755,
        name: "",
        scope: :shared,
        unique_name: "#barmunt_fire"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
