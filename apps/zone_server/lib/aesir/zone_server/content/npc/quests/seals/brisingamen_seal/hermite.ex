defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Hermite do
  @moduledoc """
  Silent hermit actor that stays visible until the Brisingamen seal scene hides it and
  reappears when the scene resets; talking to it does nothing.

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
        x: 124,
        y: 59,
        dir: 7,
        sprite: 798,
        name: "",
        scope: :shared,
        unique_name: "#hermite"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
