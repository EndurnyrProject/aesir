defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Tov1 do
  @moduledoc """
  A passage transports visitors out of Curdie’s prison.

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
        map: "que_thor",
        x: 69,
        y: 56,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#tov_1",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    warp(ctx, "thor_v02", 146, 84)
  end
end
