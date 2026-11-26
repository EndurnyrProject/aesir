defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Maid do
  @moduledoc """
  A silent maid in Master Metz’s room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 248,
        y: 23,
        dir: 3,
        sprite: 1275,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#sign"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
