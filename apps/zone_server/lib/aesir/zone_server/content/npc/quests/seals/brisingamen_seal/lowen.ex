defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Lowen do
  @moduledoc """
  Silent Lowen actor that the Brisingamen seal scene shows, hides and casts effects on;
  talking to it does nothing.

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
        y: 54,
        dir: 1,
        sprite: 745,
        name: "",
        scope: :shared,
        unique_name: "#lowen"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
