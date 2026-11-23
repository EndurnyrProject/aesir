defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests132.Ep13WarpW0 do
  @moduledoc """
  Returns players to the previous dungeon floor on touch.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nyd_dun02",
        x: 143,
        y: 269,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_s2",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 143,
        y: 263,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_s4",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 146,
        y: 269,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_12",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 146,
        y: 260,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_15",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 149,
        y: 266,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_23",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 152,
        y: 267,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_32",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 152,
        y: 261,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_34",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 155,
        y: 260,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_44",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 158,
        y: 266,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_51",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 158,
        y: 260,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_53",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 158,
        y: 257,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_54",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 161,
        y: 258,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_63",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 164,
        y: 252,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_74",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "nyd_dun02",
        x: 173,
        y: 242,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_e4",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    warp(ctx, "nyd_dun01", 214, 68)
  end
end
