defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.BronzeStatue9971 do
  @moduledoc """
  Describes a large bronze statue.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
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
        map: "juperos_01",
        x: 99,
        y: 71,
        dir: 4,
        sprite: 844,
        name: "Bronze Statue",
        scope: :shared,
        unique_name: "Bronze Statue#2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFIt's an elaborate")
    |> mes("bronze statue that")
    |> mes("is twice the height of")
    |> mes("a normal human being.^000000")
    |> close()
  end
end
