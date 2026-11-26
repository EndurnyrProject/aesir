defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Maid5 do
  @moduledoc """
  Serves Master Daewoon a restorative soup.

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
        sprite: 111,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#f2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Chamberlain]")
    |> mes("Master Daewoon~!")
    |> mes("Please try this too!")
    |> mes("It's Tiger Foot Skin soup,")
    |> mes("boiled with nine kinds of")
    |> mes("exotic, potent herbs.")
    |> next()
    |> mes("[Chamberlain]")
    |> mes("It's famous for easing")
    |> mes("sores and fatigure, preventing")
    |> mes("cold and ^333333*Ahem*^000000 enhancing male vigor. Now, open wide, master~")
    |> close()
  end
end
