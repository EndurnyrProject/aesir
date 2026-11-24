defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests132.Ep13WarpS0 do
  @moduledoc """
  Controls timed visual effects for the dungeon puzzle.

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
      %{name: "ep13_warp_s_0"},
      %{
        map: "nyd_dun02",
        x: 143,
        y: 272,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_s1",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 143,
        y: 266,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_s3",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 146,
        y: 272,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_11",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 146,
        y: 266,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_13",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 149,
        y: 260,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_25",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 149,
        y: 257,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_26",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 152,
        y: 270,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_31",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 152,
        y: 264,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_33",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 155,
        y: 269,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_41",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 155,
        y: 254,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_46",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 158,
        y: 263,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_52",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 158,
        y: 254,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_55",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 161,
        y: 261,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_62",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 161,
        y: 255,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_64",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 161,
        y: 249,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_66",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 164,
        y: 261,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_71",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 164,
        y: 255,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_73",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 164,
        y: 249,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_75",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 167,
        y: 249,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_84",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 170,
        y: 257,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_91",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 170,
        y: 254,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_92",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 170,
        y: 248,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_94",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 170,
        y: 245,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_95",
        scope: :shared
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer2000", ctx), do: ev_ontimer2000(ctx)
  def on_event("OnTimer4000", ctx), do: ev_ontimer4000(ctx)
  def on_event("OnTimer6000", ctx), do: ev_ontimer6000(ctx)
  def on_event("OnTimer8000", ctx), do: ev_ontimer8000(ctx)
  def on_event("OnTimer10000", ctx), do: ev_ontimer10000(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  @impl true
  def on_talk(ctx) do
    ev_onenable(ctx)
  end

  def ev_onenable(ctx) do
    ctx |> enablenpc() |> initnpctimer() |> ev_ontimer2000()
  end

  def ev_ontimer2000(ctx) do
    ev_ontimer4000(ctx)
  end

  def ev_ontimer4000(ctx) do
    ev_ontimer6000(ctx)
  end

  def ev_ontimer6000(ctx) do
    specialeffect(ctx, :wind)
  end

  def ev_ontimer8000(ctx) do
    specialeffect(ctx, :steal)
  end

  def ev_ontimer10000(ctx) do
    ctx |> specialeffect(:steal) |> disablenpc()
  end

  def ev_ondisable(ctx) do
    ctx |> specialeffect(:wind) |> disablenpc()
  end
end
