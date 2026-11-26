defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Monograph do
  @moduledoc """
  Sir Jore's research monograph, which scolds whoever reads it.

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
        map: "aldeba_in",
        x: 139,
        y: 103,
        dir: 5,
        sprite: 111,
        name: "Monograph",
        scope: :shared,
        unique_name: "Monograph#sign"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Sir Jore]")
    |> mes("Uwah~!")
    |> mes("Stop reading my")
    |> mes("research monograph!")
    |> mes("Put that back now!")
    |> close()
  end
end
