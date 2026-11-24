defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster10 do
  @moduledoc """
  First guard wave of Juperos security checkpoint 1-2.

  ## Behavior

  - Spawns 8 High Guards when the alarm releases it.
  - Defeating every guard calls the second wave (Monster2#1-2).
  - After five minutes the wave times out: the area is released, the crest device
    reopens and the remaining guards are removed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  @guard_name "High Guard"
  @guard_event "Monster1#1-2::OnMyMobDead"
  @guards [
    {1669, {30, 176}},
    {1675, {31, 176}},
    {1669, {32, 176}},
    {1675, {33, 176}},
    {1669, {34, 176}},
    {1675, {35, 176}},
    {1669, {36, 176}},
    {1675, {37, 176}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster1#1-2")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Monster1#1-2") |> killmonster("jupe_area1", "Monster1#1-2::OnMyMobDead")
  end

  def on_event("OnEnable", ctx) do
    ctx
    |> initnpctimer()
    |> enablenpc("Monster1#1-2")
    |> set_npc_var("MyMobs", 8)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> mapannounce("jupe_area1", "I can't believe how cowardly you really are...", 1, "0xFF0000")
    |> set_server_temp_var("JupreArea1InUse", 0)
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> enablenpc("#hole#1-2") |> stopnpctimer() |> donpcevent("Monster1#1-2::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> donpcevent("Monster2#1-2::OnEnable")
      |> disablenpc("Monster1#1-2")
      |> stopnpctimer()
    else
      ctx
    end
  end

  @impl true
  def on_talk(ctx), do: on_event("OnInit", ctx)

  defp summon_guards(ctx) do
    Enum.reduce(@guards, ctx, fn {mob_id, at}, ctx ->
      summon_mob(ctx,
        mob_id: mob_id,
        map: "jupe_area1",
        at: at,
        name: @guard_name,
        event: @guard_event
      )
    end)
  end
end
