defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster22 do
  @moduledoc """
  Second guard wave of Juperos security checkpoint 1-4.

  ## Behavior

  - Taunts the intruders over a few seconds, then spawns 10 Security Guards.
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
  @guard_event "Monster2#1-4::OnMyMobDead"
  @guards [
    {1675, {104, 161}},
    {1669, {108, 161}},
    {1675, {111, 161}},
    {1669, {112, 161}},
    {1675, {115, 161}},
    {1669, {104, 154}},
    {1675, {108, 154}},
    {1669, {111, 154}},
    {1675, {112, 154}},
    {1669, {115, 154}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster2#1-4")

  def on_event("OnDisable", ctx) do
    ctx |> killmonster("jupe_area1", "Monster2#1-4::OnMyMobDead") |> disablenpc("Monster2#1-4")
  end

  def on_event("OnEnable", ctx), do: ctx |> enablenpc("Monster2#1-4") |> initnpctimer()

  def on_event("OnTimer2000", ctx) do
    mapannounce(ctx, "jupe_area1", "I can never rest in peace...", 1, "0xFF0000")
  end

  def on_event("OnTimer4000", ctx) do
    mapannounce(
      ctx,
      "jupe_area1",
      "I'll wait forever or until someone can put me out of my misery...",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer6000", ctx) do
    ctx
    |> mapannounce("jupe_area1", "I will be waiting for you!", 1, "0xFF0000")
    |> set_npc_var("MyMobs", 10)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> set_server_temp_var("JupreArea1InUse", 0)
    |> mapannounce("jupe_area1", "It's funny... Isn't it?", 1, "0xFF0000")
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> enablenpc("#hole#1-4") |> donpcevent("Monster2#1-4::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> mapannounce("jupe_area1", "It's funny... Isn't it?", 1, "0xFF0000")
      |> disablenpc("Monster2#1-4")
      |> enablenpc("#hole#1-4")
      |> set_server_temp_var("JupreArea1InUse", 0)
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
