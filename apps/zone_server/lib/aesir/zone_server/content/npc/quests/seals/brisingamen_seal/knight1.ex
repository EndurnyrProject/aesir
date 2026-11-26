defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Knight1 do
  @moduledoc """
  Silent knight actor that the Brisingamen seal scene shows, hides and emotes through;
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
        x: 178,
        y: 49,
        dir: 1,
        sprite: 751,
        name: "",
        scope: :shared,
        unique_name: "#knight1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
