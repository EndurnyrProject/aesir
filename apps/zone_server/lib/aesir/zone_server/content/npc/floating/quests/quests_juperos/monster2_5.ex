defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster25 do
  @moduledoc """
  Second guard wave of Juperos security checkpoint 2-3.

  ## Behavior

  - Taunts the intruders over a few seconds, then spawns 16 Security Guards.
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
  @guard_event "Monster2#2-3::OnMyMobDead"
  @guards [
    {1675, {114, 64}},
    {1669, {115, 64}},
    {1675, {116, 64}},
    {1669, {117, 64}},
    {1675, {118, 64}},
    {1669, {119, 64}},
    {1675, {120, 64}},
    {1669, {121, 64}},
    {1675, {114, 62}},
    {1669, {115, 62}},
    {1675, {116, 62}},
    {1669, {117, 62}},
    {1675, {118, 62}},
    {1669, {119, 62}},
    {1675, {120, 62}},
    {1669, {121, 62}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster2#2-3")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Monster2#2-3") |> killmonster("jupe_area2", "Monster2#2-3::OnMyMobDead")
  end

  def on_event("OnEnable", ctx), do: ctx |> initnpctimer() |> enablenpc("Monster2#2-3")

  def on_event("OnTimer2000", ctx) do
    mapannounce(ctx, "jupe_area2", "Why have you come?", 1, "0xFF0000")
  end

  def on_event("OnTimer5000", ctx) do
    mapannounce(
      ctx,
      "jupe_area2",
      "Were you hoping to find something wonderful? Something miraculous?",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer8000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "You're wrong! Welcome to Hell!", 1, "0xFF0000")
    |> set_npc_var("MyMobs", 16)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "Do you still have your courage? Come. Prove it.", 1, "0xFF0000")
    |> set_server_temp_var("JupreArea2InUse", 0)
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> enablenpc("#hole#2-3") |> stopnpctimer() |> donpcevent("Monster2#2-3::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> mapannounce(
        "jupe_area2",
        "Do you still have your courage? Come. Prove it.",
        1,
        "0xFF0000"
      )
      |> disablenpc("Monster2#2-3")
      |> enablenpc("#hole#2-3")
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
