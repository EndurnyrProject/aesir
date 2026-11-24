defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.UnknownStuff do
  @moduledoc """
  An unfamiliar object is attached to a machine.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 266,
        y: 27,
        dir: 3,
        sprite: 111,
        name: "Unknown Stuff",
        scope: :shared,
        unique_name: "Unknown Stuff#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThere's something")
    |> mes("attached to a huge")
    |> mes("machine with many cords")
    |> mes("and folds of barbed wire.^000000")
    |> close()
  end
end
