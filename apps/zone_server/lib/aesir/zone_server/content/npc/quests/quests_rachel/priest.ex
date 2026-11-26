defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Priest do
  @moduledoc """
  A priest greets visitors to the pope’s chamber.

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
        x: 95,
        y: 99,
        dir: 6,
        sprite: 935,
        name: "Priest",
        scope: :shared,
        unique_name: "Priest#1rachel"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx |> mes("[Priest]") |> mes("May Freya be with you.") |> close()
  end
end
