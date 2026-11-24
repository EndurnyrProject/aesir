defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster12 do
  @moduledoc """
  First guard wave of Juperos security checkpoint 1-4.

  ## Behavior

  - Spawns 8 Security Guards when the alarm releases it.
  - Defeating every guard calls the second wave (Monster2#1-4).
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
    spawn: [%{name: "Monster1", unique_name: "Monster1#1-4"}]

  @guard_name "Security Guard"
  @guard_event "Monster1#1-4::OnMyMobDead"
  @guards [
    {1669, {92, 154}},
    {1675, {96, 154}},
    {1669, {100, 154}},
    {1675, {104, 154}},
    {1669, {92, 161}},
    {1675, {96, 161}},
    {1669, {100, 161}},
    {1675, {104, 161}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster1#1-4")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Monster1#1-4") |> killmonster("jupe_area1", "Monster1#1-4::OnMyMobDead")
  end

  def on_event("OnEnable", ctx) do
    ctx
    |> initnpctimer()
    |> enablenpc("Monster1#1-4")
    |> set_npc_var("MyMobs", 8)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> mapannounce("jupe_area1", "Zzzzt...Zzzzt....", 1, "0xFF0000")
    |> set_server_temp_var("JupreArea1InUse", 0)
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> stopnpctimer() |> enablenpc("#hole#1-4") |> donpcevent("Monster1#1-4::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> donpcevent("Monster2#1-4::OnEnable")
      |> disablenpc("Monster1#1-4")
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
