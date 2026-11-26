defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Pope do
  @moduledoc """
  The Pope appears during the temple quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_temsky",
        x: 99,
        y: 100,
        dir: 6,
        sprite: 936,
        name: "Pope",
        scope: :shared,
        unique_name: "Pope#rachel2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
