defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Doppelganger2 do
  @moduledoc """
  Silent second Doppelganger actor placed in the Brisingamen seal scene; talking to it
  does nothing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
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
        map: "que_god02",
        x: 175,
        y: 55,
        dir: 4,
        sprite: 739,
        name: "",
        scope: :shared,
        unique_name: "#doppelganger2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
