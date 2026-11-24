defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster26 do
  @moduledoc """
  Second guard wave of Juperos security checkpoint 2-4.

  ## Behavior

  - Taunts the intruders over a few seconds, then spawns 12 Security Guards.
  - Defeating every guard releases the area and reopens the crest device.
  - After five minutes the wave times out the same way and removes the remaining guards.

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
  @guard_event "Monster2#2-4::OnMyMobDead"
  @guards [
    {1675, {63, 161}},
    {1669, {61, 161}},
    {1675, {59, 161}},
    {1669, {57, 161}},
    {1675, {55, 161}},
    {1669, {53, 161}},
    {1675, {53, 154}},
    {1669, {55, 154}},
    {1675, {57, 154}},
    {1669, {59, 154}},
    {1675, {61, 154}},
    {1669, {63, 154}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster2#2-4")

  def on_event("OnDisable", ctx) do
    ctx |> killmonster("jupe_area2", "Monster2#2-4::OnMyMobDead") |> disablenpc("Monster2#2-4")
  end

  def on_event("OnEnable", ctx), do: ctx |> enablenpc("Monster2#2-4") |> initnpctimer()

  def on_event("OnTimer2000", ctx) do
    mapannounce(ctx, "jupe_area2", "I can never rest in peace...", 1, "0xFF0000")
  end

  def on_event("OnTimer4000", ctx) do
    mapannounce(
      ctx,
      "jupe_area2",
      "I'll wait forever or until someone can put me out of my misery...",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer6000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "I will be waiting for you!", 1, "0xFF0000")
    |> set_npc_var("MyMobs", 12)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> set_server_temp_var("JupreArea2InUse", 0)
    |> mapannounce("jupe_area2", "It's funny... Isn't it?", 1, "0xFF0000")
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> enablenpc("#hole#2-4") |> donpcevent("Monster2#2-4::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> mapannounce("jupe_area2", "It's funny... Isn't it?", 1, "0xFF0000")
      |> disablenpc("Monster2#2-4")
      |> enablenpc("#hole#2-4")
      |> set_server_temp_var("JupreArea2InUse", 0)
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
