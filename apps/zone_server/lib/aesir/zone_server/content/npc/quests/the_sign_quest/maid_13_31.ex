defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Maid1331 do
  @moduledoc """
  A silent maid serving Master Daewoon.

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
        map: "payon_in03",
        x: 13,
        y: 31,
        dir: 4,
        sprite: 1416,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#f1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
