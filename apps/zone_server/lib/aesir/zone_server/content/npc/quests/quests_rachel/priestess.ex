defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Priestess do
  @moduledoc """
  A priestess greets visitors to the pope’s chamber.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temsky",
        x: 104,
        y: 99,
        dir: 4,
        sprite: 920,
        name: "Priestess",
        scope: :shared,
        unique_name: "Priestess#1rachel"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx |> mes("[Priestess]") |> mes("May Freya be with you.") |> close()
  end
end
