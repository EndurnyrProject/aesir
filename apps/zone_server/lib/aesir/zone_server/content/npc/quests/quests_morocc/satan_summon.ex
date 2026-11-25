defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.SatanSummon do
  @moduledoc """
  The summoning controller manages the Satan Morocc encounter.

  ## Behavior

  - It summons Satan Morocc, handles his defeat, and ends the encounter on timeout.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild21",
        x: 3,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "Satan Summon",
        scope: :shared,
        unique_name: "Satan Summon#edq"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnMyMobDead", ctx), do: ev_onmymobdead(ctx)
  def on_event("OnTimer5400000", ctx), do: ev_ontimer5400000(ctx)
  def on_event("OnTimer5415000", ctx), do: ev_ontimer5415000(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Satan Summon#edq")
  end

  def ev_onenable(ctx) do
    ctx
    |> enablenpc("Satan Summon#edq")
    |> initnpctimer()
    |> summon_mob(
      mob_id: 1916,
      map: "moc_fild21",
      at: {177, 217},
      name: "Satan Morocc",
      event: "Satan Summon#edq::OnMyMobDead"
    )
  end

  def ev_ondisable(ctx) do
    ctx
    |> stopnpctimer()
    |> killmonster("moc_fild21", "Satan Summon#edq::OnMyMobDead")
    |> set_server_temp_var("re_moc", 0)
    |> disablenpc("Satan Summon#edq")
  end

  def ev_onmymobdead(ctx) do
    ctx = set_server_temp_var(ctx, "re_moc", 3)

    ctx
    |> set_server_temp_var("re_moc_time$", gettimestr(ctx, "%H%M%S", 7))
    |> mapannounce(
      "moc_fild21",
      "I'll let live just a little longer. You'll never find me through this time-space gap!",
      1,
      "0xFFFF00"
    )
    |> donpcevent("Time-Space Gap#edq::OnEnable")
    |> donpcevent("Satan Broadcast#edq::OnDisable")
    |> disablenpc("Group of Evil#edq")
    |> stopnpctimer()
    |> killmonster("moc_fild21", "Satan Summon#edq::OnMyMobDead")
    |> disablenpc("Satan Summon#edq")
  end

  def ev_ontimer5400000(ctx) do
    mapannounce(ctx, "moc_fild21", "You weaklings can't even scratch me!", 1, "0xFFFF00")
  end

  def ev_ontimer5415000(ctx) do
    ctx
    |> mapannounce("moc_fild21", "I don't have time for this! Go away!", 1, "0xFFFF00")
    |> donpcevent("Satan Summon#edq::OnDisable")
  end
end
