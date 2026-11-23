defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests132.Ep13WarpS1 do
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
      %{
        map: "nyd_dun02",
        x: 146,
        y: 263,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_14",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 149,
        y: 272,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_21",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 152,
        y: 258,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_35",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 155,
        y: 266,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_42",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 158,
        y: 251,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_56",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 164,
        y: 258,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_72",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 164,
        y: 246,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_76",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 167,
        y: 255,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_82",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 170,
        y: 251,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_93",
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
  def on_event("OnTimer12000", ctx), do: ev_ontimer12000(ctx)
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
    ev_ontimer10000(ctx)
  end

  def ev_ontimer10000(ctx) do
    specialeffect(ctx, :steal)
  end

  def ev_ontimer12000(ctx) do
    ctx |> specialeffect(:steal) |> disablenpc()
  end

  def ev_ondisable(ctx) do
    ctx |> specialeffect(:wind) |> disablenpc()
  end
end
