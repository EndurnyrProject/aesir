defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsLighthalzen.Bully2 do
  @moduledoc """
  Thugs attack the second package delivery.

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
    spawn: [%{name: "", scope: :shared, unique_name: "#bully2"}]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnter", ctx), do: ev_onenter(ctx)
  def on_event("OnReset", ctx), do: ev_onreset(ctx)
  def on_event("OnMyMobDead", ctx), do: ev_onmymobdead(ctx)
  def on_event("OnTimer120000", ctx), do: ev_ontimer120000(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "#bully2")
  end

  def ev_onenter(ctx) do
    ctx
    |> enablenpc("#bully2")
    |> initnpctimer()
    |> summon_mob(
      mob_id: 1592,
      map: "airplane_01",
      at: {96, 53},
      name: "Thug",
      event: "#bully2::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1592,
      map: "airplane_01",
      at: {87, 47},
      name: "Thug",
      event: "#bully2::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1592,
      map: "airplane_01",
      at: {97, 43},
      name: "Thug",
      event: "#bully2::OnMyMobDead"
    )
    |> set_npc_var("bullymobs", 3)
  end

  def ev_onreset(ctx) do
    killmonster(ctx, "airplane_01", "#bully2::OnMyMobDead")
  end

  def ev_onmymobdead(ctx) do
    ctx = set_npc_var(ctx, "bullymobs", get_npc_var(ctx, "bullymobs", 0) - 1)

    if get_npc_var(ctx, "bullymobs", 0) < 1 do
      ctx
      |> mes("^3355FFHey-- there's a slit")
      |> mes("in the wrapping on one")
      |> mes("of the packages. It was")
      |> mes("probably ripped a little")
      |> mes("while you were fighting.^000000")
      |> close2()
      |> donpcevent("#bully2::OnInit")
      |> donpcevent("#packidentity::OnEnter")
      |> stopnpctimer()
    else
      ctx
    end
  end

  def ev_ontimer120000(ctx) do
    ctx
    |> donpcevent("#bully2::OnReset")
    |> donpcevent("#bully2::OnInit")
    |> donpcevent("#packidentity::OnEnter")
    |> stopnpctimer()
  end
end
