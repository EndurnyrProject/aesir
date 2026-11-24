defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster20 do
  @moduledoc """
  Second guard wave of Juperos security checkpoint 1-2.

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
  @guard_event "Monster2#1-2::OnMyMobDead"
  @guards [
    {1669, {30, 152}},
    {1675, {31, 152}},
    {1669, {32, 152}},
    {1675, {33, 152}},
    {1669, {34, 152}},
    {1675, {35, 152}},
    {1669, {36, 152}},
    {1675, {37, 152}},
    {1669, {30, 150}},
    {1675, {31, 150}},
    {1669, {32, 150}},
    {1675, {33, 150}},
    {1669, {34, 150}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster2#1-2")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Monster2#1-2") |> killmonster("jupe_area1", "Monster2#1-2::OnMyMobDead")
  end

  def on_event("OnEnable", ctx), do: ctx |> enablenpc("Monster2#1-2") |> initnpctimer()

  def on_event("OnTimer2000", ctx) do
    mapannounce(
      ctx,
      "jupe_area1",
      "I was the head of this underground laboratory.",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer4000", ctx) do
    mapannounce(
      ctx,
      "jupe_area1",
      "But that was a long time ago, back when I was merely a human.",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer6000", ctx) do
    ctx
    |> mapannounce(
      "jupe_area1",
      "I was called Vesper Newton. Hahah, they called me a mad man back then.",
      1,
      "0xFF0000"
    )
    |> set_npc_var("MyMobs", 13)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> mapannounce("jupe_area1", "...Not yet.", 1, "0xFF0000")
    |> set_server_temp_var("JupreArea1InUse", 0)
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> enablenpc("#hole#1-2") |> stopnpctimer() |> donpcevent("Monster2#1-2::OnDisable")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> mapannounce("jupe_area1", "Not yet!", 1, "0xFF0000")
      |> disablenpc("Monster2#1-2")
      |> enablenpc("#hole#1-2")
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
