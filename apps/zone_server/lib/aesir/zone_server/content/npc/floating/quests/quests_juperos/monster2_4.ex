defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster24 do
  @moduledoc """
  Second guard wave of Juperos security checkpoint 2-2.

  ## Behavior

  - Taunts the intruders over a few seconds, then spawns 13 Security Guards.
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
  @guard_event "Monster2#2-2::OnMyMobDead"
  @guards [
    {1675, {126, 156}},
    {1669, {127, 156}},
    {1675, {128, 156}},
    {1669, {129, 156}},
    {1675, {130, 156}},
    {1669, {131, 156}},
    {1675, {132, 156}},
    {1669, {133, 156}},
    {1675, {133, 156}},
    {1669, {127, 152}},
    {1675, {129, 152}},
    {1669, {130, 152}},
    {1675, {132, 152}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster2#2-2")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Monster2#2-2") |> killmonster("jupe_area2", "Monster2#2-2::OnMyMobDead")
  end

  def on_event("OnEnable", ctx), do: ctx |> enablenpc("Monster2#2-2") |> initnpctimer()

  def on_event("OnTimer2000", ctx) do
    mapannounce(
      ctx,
      "jupe_area2",
      "I was the head of this underground laboratory.",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer4000", ctx) do
    mapannounce(
      ctx,
      "jupe_area2",
      "But that was a long time ago, back when I was merely a human.",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer6000", ctx) do
    ctx
    |> mapannounce(
      "jupe_area2",
      "I was called Vesper Newton. Hahah, they called me a mad man back then.",
      1,
      "0xFF0000"
    )
    |> set_npc_var("MyMobs", 13)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "...Not yet.", 1, "0xFF0000")
    |> set_server_temp_var("JupreArea2InUse", 0)
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> enablenpc("#hole#2-2") |> stopnpctimer() |> donpcevent("Monster2#2-2::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> mapannounce("jupe_area2", "Not yet!", 1, "0xFF0000")
      |> disablenpc("Monster2#2-2")
      |> enablenpc("#hole#2-2")
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
