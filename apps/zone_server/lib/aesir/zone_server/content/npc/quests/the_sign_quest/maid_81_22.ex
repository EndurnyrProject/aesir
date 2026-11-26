defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Maid8122 do
  @moduledoc """
  Provides a silent maid decoration in the castle annex.

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
        x: 81,
        y: 22,
        dir: 4,
        sprite: 1170,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#a1"
      }
    ]

  @impl true
  def on_talk(ctx), do: ctx
end
