defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests132.Ep13WarpS2 do
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
      %{name: "ep13_warp_s_2"},
      %{
        map: "nyd_dun02",
        x: 149,
        y: 269,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_22",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 149,
        y: 263,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_24",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 155,
        y: 263,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_43",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 155,
        y: 257,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_45",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 161,
        y: 264,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_61",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 161,
        y: 252,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_65",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 167,
        y: 258,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_81",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 167,
        y: 252,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_83",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 167,
        y: 246,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_85",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 173,
        y: 251,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_e1",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 173,
        y: 248,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_e2",
        scope: :shared
      },
      %{
        map: "nyd_dun02",
        x: 173,
        y: 245,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_e3",
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
  def on_event("OnTimer15000", ctx), do: ev_ontimer15000(ctx)
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
    ev_ontimer8000(ctx)
  end

  def ev_ontimer8000(ctx) do
    specialeffect(ctx, :wind)
  end

  def ev_ontimer10000(ctx) do
    ev_ontimer12000(ctx)
  end

  def ev_ontimer12000(ctx) do
    specialeffect(ctx, :steal)
  end

  def ev_ontimer15000(ctx) do
    ctx |> specialeffect(:steal) |> disablenpc()
  end

  def ev_ondisable(ctx) do
    ctx |> specialeffect(:wind) |> disablenpc()
  end
end
