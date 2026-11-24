defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster1 do
  @moduledoc """
  First guard wave of Juperos security checkpoint 1-1.

  ## Behavior

  - Spawns 8 Security Guards when the alarm releases it.
  - Defeating every guard calls the second wave (Monster2#1-1).
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

  @guard_name "Security Guard"
  @guard_event "Monster1#1-1::OnMyMobDead"
  @guards [
    {1675, {30, 263}},
    {1669, {30, 262}},
    {1675, {30, 261}},
    {1669, {30, 260}},
    {1675, {30, 259}},
    {1669, {30, 258}},
    {1675, {30, 257}},
    {1669, {30, 256}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster1#1-1")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Monster1#1-1") |> killmonster("jupe_area1", "Monster1#1-1::OnMyMobDead")
  end

  def on_event("OnEnable", ctx) do
    ctx
    |> enablenpc("Monster1#1-1")
    |> initnpctimer()
    |> set_npc_var("MyMobs", 8)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> mapannounce("jupe_area1", "Do you realize this is a hallucination?", 1, "0xFF0000")
    |> set_server_temp_var("JupreArea1InUse", 0)
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> enablenpc("#hole#1-1") |> stopnpctimer() |> donpcevent("Monster1#1-1::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> donpcevent("Monster2#1-1::OnEnable")
      |> disablenpc("Monster1#1-1")
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
