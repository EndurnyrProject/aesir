defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster13 do
  @moduledoc """
  First guard wave of Juperos security checkpoint 2-1.

  ## Behavior

  - Spawns 8 Security Guards when the alarm releases it.
  - Defeating every guard calls the second wave (Monster2#2-1).
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

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{name: "Monster1", unique_name: "Monster1#2-1"}]

  @guard_name "Security Guard"
  @guard_event "Monster1#2-1::OnMyMobDead"
  @guards [
    {1669, {126, 252}},
    {1675, {127, 252}},
    {1669, {128, 252}},
    {1675, {129, 252}},
    {1669, {130, 252}},
    {1675, {131, 252}},
    {1669, {132, 252}},
    {1675, {133, 252}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster1#2-1")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Monster1#2-1") |> killmonster("jupe_area2", "Monster1#2-1::OnMyMobDead")
  end

  def on_event("OnEnable", ctx) do
    ctx
    |> enablenpc("Monster1#2-1")
    |> initnpctimer()
    |> set_npc_var("MyMobs", 8)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "Do you realize this is a hallucination?", 1, "0xFF0000")
    |> set_server_temp_var("JupreArea2InUse", 0)
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> enablenpc("#hole#2-1") |> stopnpctimer() |> donpcevent("Monster1#2-1::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> donpcevent("Monster2#2-1::OnEnable")
      |> disablenpc("Monster1#2-1")
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
