defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Maid1 do
  @moduledoc """
  A maid greeting visitors to Master Daewoon.

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
        x: 79,
        y: 22,
        dir: 4,
        sprite: 111,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#b2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Maid]")
    |> mes("Welcome.")
    |> mes("Are you another")
    |> mes("visitor for Master")
    |> mes("Daewoon?")
    |> close()
  end
end
