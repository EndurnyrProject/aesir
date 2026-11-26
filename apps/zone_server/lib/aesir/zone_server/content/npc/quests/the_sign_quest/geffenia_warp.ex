defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.GeffeniaWarp do
  @moduledoc """
  Controls the temporary Geffenia portal.

  ## Behavior

  - Sends entrants to one of four destinations and closes the portal after 45 seconds.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen",
        x: 119,
        y: 55,
        dir: 0,
        sprite: 45,
        name: "Geffenia Warp",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnTimer10000", ctx), do: ev_ontimer10000(ctx)
  def on_event("OnTimer20000", ctx), do: ev_ontimer20000(ctx)
  def on_event("OnTimer30000", ctx), do: ev_ontimer30000(ctx)
  def on_event("OnTimer40000", ctx), do: ev_ontimer40000(ctx)
  def on_event("OnTimer45000", ctx), do: ev_ontimer45000(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Geffenia Warp")
  end

  def ev_ontouch(ctx) do
    ctx = set_local(ctx, :geffenia_warp, Enum.random(1..4))

    case get_local(ctx, :geffenia_warp, 0) do
      1 -> warp(ctx, "gefenia01", 58, 169)
      2 -> warp(ctx, "gefenia02", 116, 115)
      3 -> warp(ctx, "gefenia03", 130, 206)
      4 -> warp(ctx, "gefenia04", 133, 88)
      _ -> warp(ctx, "geffen", 116, 115)
    end
  end

  def ev_onenable(ctx) do
    ctx |> initnpctimer() |> enablenpc("Geffenia Warp") |> specialeffect(:mappillar2)
  end

  def ev_ondisable(ctx) do
    disablenpc(ctx, "Geffenia Warp")
  end

  def ev_ontimer10000(ctx) do
    ev_ontimer20000(ctx)
  end

  def ev_ontimer20000(ctx) do
    ev_ontimer30000(ctx)
  end

  def ev_ontimer30000(ctx) do
    ev_ontimer40000(ctx)
  end

  def ev_ontimer40000(ctx) do
    specialeffect(ctx, :mappillar2)
  end

  def ev_ontimer45000(ctx) do
    ctx
    |> donpcevent("Geffenia Warp::OnDisable")
    |> mapannounce("geffen", "The portal to Geffenia is now closed.", 1, "0x9CFF00")
    |> stopnpctimer()
  end
end
