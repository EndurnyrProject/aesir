defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Ice4f2 do
  @moduledoc """
  Transfers players to the ice cave's fourth floor.

  ## Behavior

  - Starts disabled and warps players when the entrance is enabled.

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
        map: "ice_dun03",
        x: 138,
        y: 148,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#ice_4f_2",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: handle_touch(ctx)
  def on_event("OnInit", ctx), do: handle_init(ctx)
  @impl true
  def on_talk(ctx) do
    handle_touch(ctx)
  end

  defp handle_touch(ctx) do
    warp(ctx, "ice_dun04", 33, 144)
  end

  defp handle_init(ctx) do
    disablenpc(ctx, "#ice_4f_2")
  end
end
