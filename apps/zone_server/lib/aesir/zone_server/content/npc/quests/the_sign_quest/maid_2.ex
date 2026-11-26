defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Maid2 do
  @moduledoc """
  Greets visitors to Master Daewoon’s castle annex.

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
        y: 15,
        dir: 1,
        sprite: 111,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#c2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Maid]")
    |> mes("Greetings.")
    |> mes("Welcome to the")
    |> mes("Annex to Payon Castle.")
    |> mes("Have you come here to")
    |> mes("see Master Daewoon?")
    |> close()
  end
end
