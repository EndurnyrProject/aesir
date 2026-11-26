defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Maid831 do
  @moduledoc """
  A silent maid in a Payon house who does nothing when spoken to.

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
        x: 8,
        y: 31,
        dir: 4,
        sprite: 1416,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#e1"
      }
    ]

  @impl true
  def on_talk(ctx), do: ctx
end
