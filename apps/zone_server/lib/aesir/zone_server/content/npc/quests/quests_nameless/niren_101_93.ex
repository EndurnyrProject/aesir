defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Niren10193 do
  @moduledoc """
  Niren stands silently during the temple scene.

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
        x: 101,
        y: 93,
        dir: 1,
        sprite: 915,
        name: "Niren",
        scope: :shared,
        unique_name: "Niren#em_sky"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
