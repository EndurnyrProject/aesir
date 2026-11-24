defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Sculpture do
  @moduledoc """
  Describes a familiar sculpture.

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
      %{map: "juperos_01", x: 79, y: 92, dir: 4, sprite: 844, name: "Sculpture", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    ctx |> mes("^3355FFIt's a sculpture that") |> mes("looks familiar to you.^000000") |> close()
  end
end
