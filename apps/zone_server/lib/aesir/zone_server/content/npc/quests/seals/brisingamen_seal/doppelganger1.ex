defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Doppelganger1 do
  @moduledoc """
  Silent Doppelganger actor that the Brisingamen seal scene shows, hides and emotes
  through; talking to it does nothing.

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
        x: 173,
        y: 58,
        dir: 4,
        sprite: 739,
        name: "",
        scope: :shared,
        unique_name: "#doppelganger1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
