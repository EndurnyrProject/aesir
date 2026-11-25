defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.CaveSettler9143 do
  @moduledoc """
  A cave settler is startled by the player.

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
        x: 91,
        y: 43,
        dir: 3,
        sprite: 870,
        name: "Cave Settler",
        scope: :shared,
        unique_name: "Cave Settler#f_cave1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Cave Settler]")
    |> mes("(Startled)")
    |> next()
    |> mes("[Cave Settler]")
    |> mes("Mumble... Mumble...")
    |> close()
  end
end
