defmodule Aesir.ZoneServer.Content.Npc.Floating.Knight1 do
  @moduledoc """
  First trial room controller of the Knight job change quest.

  ## Behavior

  - On enable, stocks the first test room with the Dustiness swarm (pre-renewal
    only) plus the Andre, Deniro, Piere and Argos groups and counts them.
  - When the last monster dies, plays Sir Windsor's line, warps the player into
    the second room and starts the next stage.
  - After the three-minute limit it clears the room and warps everyone left in
    it back to the Prontera Chivalry.

  ## Credits

  - Original from rAthena, authors and Contributors
    - PGRO TEAM (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Vali
    - Euphy
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-1/knight.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @room "job_knt"
  @on_mob_dead "Knight1::OnMyMobDead"

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Knight1")
  def on_event("OnEnable", ctx), do: start_trial(ctx)

  def on_event("OnDisable", ctx) do
    ctx |> killmonster(@room, @on_mob_dead) |> disablenpc("Knight1")
  end

  def on_event("OnMyMobDead", ctx), do: count_kill(ctx)
  def on_event("OnTimer180000", ctx), do: donpcevent(ctx, "Knight1::OnDisable")

  def on_event("OnTimer181000", ctx) do
    areawarp(ctx, @room, 24, 126, 63, 165, "prt_in", 80, 100)
  end

  def on_event("OnTimer182000", ctx) do
    ctx
    |> stopnpctimer()
    |> donpcevent("Knight1::OnDisable")
    |> donpcevent("Windsor Benedict#knt::OnStart")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp start_trial(ctx) do
    ctx = enablenpc(ctx, "Knight1")

    ctx =
      if Rathena.truthy?(checkre(ctx, 0)) do
        set_npc_var(ctx, "MyMobs", 8)
      else
        ctx
        |> set_npc_var("MyMobs", 12)
        |> summon(1114, {39, 150})
        |> summon(1114, {47, 150})
        |> summon(1114, {39, 142})
        |> summon(1114, {47, 142})
      end

    ctx
    |> summon(1160, {43, 137})
    |> summon(1095, {43, 137})
    |> summon(1105, {43, 137})
    |> summon(1160, {43, 155})
    |> summon(1095, {43, 155})
    |> summon(1105, {43, 155})
    |> summon(1100, {35, 146})
    |> summon(1100, {52, 146})
    |> initnpctimer()
  end

  defp summon(ctx, mob_id, {x, y}) do
    summon_mob(ctx, mob_id: mob_id, map: @room, at: {x, y}, event: @on_mob_dead)
  end

  defp count_kill(ctx) do
    remaining = get_npc_var(ctx, "MyMobs", 0) - 1
    ctx = set_npc_var(ctx, "MyMobs", remaining)

    if remaining < 1 do
      ctx
      |> mes("[Sir Windsor]")
      |> mes("...")
      |> next()
      |> mes("[Sir Windsor]")
      |> mes("...On to")
      |> mes("the next level.")
      |> close()
      |> warp(@room, 43, 52)
      |> donpcevent("Knight1::OnDisable")
      |> donpcevent("Knight2::OnEnable")
      |> stopnpctimer()
    else
      ctx
    end
  end
end
