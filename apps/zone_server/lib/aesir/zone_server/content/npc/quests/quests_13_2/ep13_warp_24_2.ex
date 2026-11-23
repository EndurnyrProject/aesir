defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Ep13Warp242 do
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
        x: 149,
        y: 263,
        dir: 0,
        sprite: 139,
        name: "ep13_warp_24_2",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  @impl true
  def on_talk(ctx) do
    ev_onenable(ctx)
  end

  def ev_onenable(ctx) do
    enablenpc(ctx, "ep13_warp_24_2")
  end

  def ev_ontouch(ctx) do
    ctx =
      if Rathena.truthy?(:rand.uniform(2) - 1) do
        ctx
        |> donpcevent("ep13_warp_33::OnEnable")
        |> donpcevent("ep13_warp_43::OnEnable")
        |> donpcevent("ep13_warp_43_2::OnEnable")
      else
        ctx
        |> donpcevent("ep13_warp_25::OnEnable")
        |> donpcevent("ep13_warp_26::OnEnable")
        |> donpcevent("ep13_warp_35::OnEnable")
        |> donpcevent("ep13_warp_45::OnEnable")
        |> donpcevent("ep13_warp_45_2::OnEnable")
      end

    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    ev_ondisable(ctx)
  end

  def ev_ondisable(ctx) do
    disablenpc(ctx, "ep13_warp_24_2")
  end
end
