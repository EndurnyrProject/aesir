defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Maid4 do
  @moduledoc """
  Reassures visitors about Master Daewoon’s servants.

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
        sprite: 111,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#e2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Chamberlain]")
    |> mes("Please refrain")
    |> mes("from attacking")
    |> mes("the servants.")
    |> next()
    |> mes("[Chamberlain]")
    |> mes("Although you may recognize")
    |> mes("us as monsters, we have")
    |> mes("all been properly hired and")
    |> mes("faithfully serve our master,")
    |> mes("Daewoon. So there's no")
    |> mes("need to feel uneasy.")
    |> close()
  end
end
