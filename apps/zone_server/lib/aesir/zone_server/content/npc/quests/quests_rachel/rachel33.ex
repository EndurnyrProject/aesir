defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Rachel33 do
  @moduledoc """
  A doorway leads to the appropriate version of the pope’s chamber.

  ## Behavior

  - Routes visitors according to their quest progress.

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
        map: "ra_temin",
        x: 275,
        y: 226,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#rachel33",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_em, 0) == 21 do
      warp(ctx, "que_temsky", 99, 11)
    else
      warp(ctx, "ra_temsky", 99, 11)
    end
  end
end
