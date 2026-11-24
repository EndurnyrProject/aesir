defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BeautifulLady117149 do
  @moduledoc """
  These silent academy attendants have no dialogue.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_school",
        x: 117,
        y: 149,
        dir: 4,
        sprite: 894,
        name: "Beautiful lady",
        scope: :shared,
        unique_name: "BeatifulLadyKHQ2",
        hidden_name: "kh2"
      },
      %{
        map: "kh_school",
        x: 118,
        y: 149,
        dir: 4,
        sprite: 894,
        name: "Beautiful lady",
        scope: :shared,
        unique_name: "Beautiful lady#kh3"
      },
      %{
        map: "kh_school",
        x: 120,
        y: 149,
        dir: 4,
        sprite: 894,
        name: "Beautiful lady",
        scope: :shared,
        unique_name: "Beautiful lady#kh4"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
