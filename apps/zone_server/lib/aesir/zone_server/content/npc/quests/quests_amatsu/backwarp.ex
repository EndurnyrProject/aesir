defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Backwarp do
  @moduledoc """
  Hidden return warp that sends players in the event arena back to Amatsu.

  ## Behavior

  - Starts disabled; the Timer enables it briefly after the fight's time runs out.
  - Touching it warps the player back to Amatsu.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_test",
        x: 50,
        y: 100,
        dir: 0,
        sprite: -1,
        name: "backwarp",
        scope: :shared,
        unique_name: "backwarp#ama",
        trigger: {25, 25}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "backwarp#ama")
  def on_event("OnTouch_", ctx), do: warp(ctx, "amatsu", 115, 95)

  @impl true
  def on_talk(ctx), do: disablenpc(ctx, "backwarp#ama")
end
