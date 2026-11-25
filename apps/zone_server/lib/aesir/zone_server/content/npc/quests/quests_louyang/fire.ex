defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Fire do
  @moduledoc """
  An invisible firecracker effect target.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_fild01",
        x: 225,
        y: 350,
        dir: 0,
        sprite: 139,
        name: " ",
        scope: :shared,
        unique_name: " #fire"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
