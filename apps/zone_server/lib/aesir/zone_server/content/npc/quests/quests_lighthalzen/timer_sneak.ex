defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.TimerSneak do
  @moduledoc """
  Controls the time limit for searching the archive.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 177,
        y: 44,
        dir: 0,
        sprite: 111,
        name: "Timer_Sneak",
        scope: :shared,
        trigger: {8, 12}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnter", ctx), do: ev_onenter(ctx)
  def on_event("OnTimer180000", ctx), do: ev_ontimer180000(ctx)
  def on_event("OnTimer190000", ctx), do: ev_ontimer190000(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    warp(ctx, "lhz_in01", 191, 49)
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Timer_Sneak")
  end

  def ev_onenter(ctx) do
    ctx |> stopnpctimer() |> initnpctimer()
  end

  def ev_ontimer180000(ctx) do
    enablenpc(ctx, "Timer_Sneak")
  end

  def ev_ontimer190000(ctx) do
    ctx |> stopnpctimer() |> disablenpc("Timer_Sneak")
  end
end
