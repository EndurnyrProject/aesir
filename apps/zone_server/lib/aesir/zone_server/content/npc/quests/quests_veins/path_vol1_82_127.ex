defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.PathVol182127 do
  @moduledoc """
  Redirects investigators through a temple passage.

  ## Behavior

  - Moves the player when the investigation reaches the required stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temin",
        x: 82,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "path_vol1",
        scope: :shared,
        unique_name: "path_vol1#3",
        trigger: {5, 1}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_vol, 0) == 5 do
      warp(ctx, "ra_temin", 84, 124)
    else
      ctx
    end
  end
end
