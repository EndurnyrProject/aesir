defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.VolStudy1Veinswarp do
  @moduledoc """
  Transfers investigators within the volcano camp.

  ## Behavior

  - Warps players at the appropriate investigation stages.

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
        map: "thor_camp",
        x: 141,
        y: 62,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "VeinsWarp",
        hidden_name: "vol_study1",
        trigger: {3, 3}
      },
      %{
        map: "thor_camp",
        x: 172,
        y: 72,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#vol_study2",
        trigger: {3, 3}
      },
      %{
        map: "thor_camp",
        x: 172,
        y: 38,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#vol_study3",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    if (get_char_var(ctx, :aru_vol, 0) > 13 and get_char_var(ctx, :aru_vol, 0) < 17) or
         get_char_var(ctx, :aru_vol, 0) == 19 do
      warp(ctx, "thor_camp", 156, 67)
    else
      ctx
    end
  end
end
