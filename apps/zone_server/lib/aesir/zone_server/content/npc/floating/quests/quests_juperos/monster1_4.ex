defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster14 do
  @moduledoc """
  First guard wave of Juperos security checkpoint 2-2.

  ## Behavior

  - Spawns 8 High Guards when the alarm releases it.
  - Defeating every guard calls the second wave (Monster2#2-2).
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
  @guard_event "Monster1#2-2::OnMyMobDead"
  @guards [
    {1669, {126, 176}},
    {1675, {127, 176}},
    {1669, {128, 176}},
    {1675, {129, 176}},
    {1669, {130, 176}},
    {1675, {131, 176}},
    {1669, {132, 176}},
    {1675, {133, 176}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster1#2-2")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Monster1#2-2") |> killmonster("jupe_area2", "Monster1#2-2::OnMyMobDead")
  end

  def on_event("OnEnable", ctx) do
    ctx
    |> initnpctimer()
    |> enablenpc("Monster1#2-2")
    |> set_npc_var("MyMobs", 8)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "I can't believe how cowardly you really are...", 1, "0xFF0000")
    |> set_server_temp_var("JupreArea2InUse", 0)
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> enablenpc("#hole#2-2") |> stopnpctimer() |> donpcevent("Monster1#2-2::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> donpcevent("Monster2#2-2::OnEnable")
      |> disablenpc("Monster1#2-2")
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
        map: "jupe_area2",
        at: at,
        name: @guard_name,
        event: @guard_event
      )
    end)
  end
end
