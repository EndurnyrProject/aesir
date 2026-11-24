defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster23 do
  @moduledoc """
  Second guard wave of Juperos security checkpoint 2-1.

  ## Behavior

  - Taunts the intruders over a few seconds, then spawns 8 Security Guards.
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
  @guard_event "Monster2#2-1::OnMyMobDead"
  @guards [
    {1675, {126, 236}},
    {1669, {127, 236}},
    {1675, {128, 236}},
    {1669, {129, 236}},
    {1675, {130, 236}},
    {1669, {131, 236}},
    {1675, {132, 236}},
    {1669, {133, 236}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster2#2-1")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Monster2#2-1") |> killmonster("jupe_area2", "Monster2#2-1::OnMyMobDead")
  end

  def on_event("OnEnable", ctx), do: ctx |> enablenpc("Monster2#2-1") |> initnpctimer()

  def on_event("OnTimer2000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "How about now?", 1, "0xFF0000")
    |> soundeffectall("jupe_warning.wav", 0, "jupe_area2")
    |> soundeffectall("jupe_warning.wav", 0, "jupe_area2")
  end

  def on_event("OnTimer4000", ctx) do
    mapannounce(ctx, "jupe_area2", "Let me see...", 1, "0xFF0000")
  end

  def on_event("OnTimer7000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "Just how strong you are!", 1, "0xFF0000")
    |> soundeffectall("jupe_warning.wav", 0, "jupe_area2")
    |> soundeffectall("jupe_warning.wav", 0, "jupe_area2")
    |> set_npc_var("MyMobs", 8)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "Bwahaha! You're only good at running away!", 1, "0xFF0000")
    |> set_server_temp_var("JupreArea2InUse", 0)
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> enablenpc("#hole#2-1") |> stopnpctimer() |> donpcevent("Monster2#2-1::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> mapannounce("jupe_area2", "Zzzzt. Zzzzt..... ", 1, "0xFF0000")
      |> disablenpc("Monster2#2-1")
      |> enablenpc("#hole#2-1")
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
