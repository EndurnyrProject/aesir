defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Zhed do
  @moduledoc """
  Zhed appears during the Peace for Arunafeltz quest.

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
        x: 98,
        y: 93,
        dir: 7,
        sprite: 932,
        name: "Zhed",
        scope: :shared,
        unique_name: "Zhed#em_sky"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
