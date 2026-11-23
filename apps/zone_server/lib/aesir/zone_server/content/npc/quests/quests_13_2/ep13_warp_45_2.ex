defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Ep13Warp452 do
  @moduledoc """
  Controls a Yggdrasil dungeon puzzle trigger.

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
        x: 155,
        y: 257,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_45_2",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    ev_ondisable(ctx)
  end

  def ev_ondisable(ctx) do
    disablenpc(ctx, "ep13_warp_45_2")
  end

  def ev_onenable(ctx) do
    enablenpc(ctx, "ep13_warp_45_2")
  end

  def ev_ontouch(ctx) do
    ctx
    |> donpcevent("ep13_warp_46::OnEnable")
    |> donpcevent("ep13_warp_55::OnEnable")
    |> donpcevent("ep13_warp_56::OnEnable")
    |> donpcevent("ep13_warp_65::OnEnable")
    |> donpcevent("ep13_warp_65_2::OnEnable")
    |> donpcevent("ep13_warp_45_2::OnDisable")
  end
end
