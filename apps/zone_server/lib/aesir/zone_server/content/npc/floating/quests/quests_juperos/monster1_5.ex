defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.Monster15 do
  @moduledoc """
  First guard wave of Juperos security checkpoint 2-3.

  ## Behavior

  - Spawns 8 Security Guards when the alarm releases it.
  - Defeating every guard calls the second wave (Monster2#2-3).
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
  @guard_event "Monster1#2-3::OnMyMobDead"
  @guards [
    {1675, {126, 89}},
    {1669, {127, 89}},
    {1675, {128, 89}},
    {1669, {129, 89}},
    {1675, {130, 89}},
    {1669, {131, 89}},
    {1675, {132, 89}},
    {1669, {133, 89}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster1#2-3")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Monster1#2-3") |> killmonster("jupe_area2", "Monster1#2-3::OnMyMobDead")
  end

  def on_event("OnEnable", ctx) do
    ctx
    |> initnpctimer()
    |> enablenpc("Monster1#2-3")
    |> set_npc_var("MyMobs", 8)
    |> summon_guards()
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "Zzzzt...Zzzzt....", 1, "0xFF0000")
    |> set_server_temp_var("JupreArea2InUse", 0)
  end

  def on_event("OnTimer300002", ctx) do
    ctx |> donpcevent("Monster1#2-3::OnDisable") |> enablenpc("#hole#2-3")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> donpcevent("Monster2#2-3::OnEnable")
      |> disablenpc("Monster1#2-3")
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
