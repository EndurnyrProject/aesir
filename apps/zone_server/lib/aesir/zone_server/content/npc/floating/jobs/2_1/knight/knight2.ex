defmodule Aesir.ZoneServer.Content.Npc.Floating.Jobs.M21.Knight.Knight2 do
  @moduledoc """
  Second trial room controller of the Knight job change quest.

  ## Behavior

  - On enable, stocks the second test room with the Desert Wolf and Anacondaq
    groups (pre-renewal only) plus the Frilldora and Drainliar groups and
    counts them.
  - When the last monster dies, plays Sir Windsor's line, warps the player into
    the third room and starts the next stage.
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
  @on_mob_dead "Knight2::OnMyMobDead"

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Knight2")
  def on_event("OnEnable", ctx), do: start_trial(ctx)

  def on_event("OnDisable", ctx) do
    ctx |> killmonster(@room, @on_mob_dead) |> disablenpc("Knight2")
  end

  def on_event("OnMyMobDead", ctx), do: count_kill(ctx)
  def on_event("OnTimer180000", ctx), do: donpcevent(ctx, "Knight2::OnDisable")

  def on_event("OnTimer181000", ctx) do
    areawarp(ctx, @room, 24, 32, 63, 71, "prt_in", 80, 100)
  end

  def on_event("OnTimer182000", ctx) do
    ctx
    |> stopnpctimer()
    |> donpcevent("Knight2::OnDisable")
    |> donpcevent("Windsor Benedict#knt::OnStart")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp start_trial(ctx) do
    ctx = enablenpc(ctx, "Knight2")

    ctx =
      if Rathena.truthy?(checkre(ctx, 0)) do
        set_npc_var(ctx, "MyMobs", 6)
      else
        ctx
        |> set_npc_var("MyMobs", 12)
        |> summon(1106, {43, 42})
        |> summon(1106, {43, 62})
        |> summon(1030, {60, 68})
        |> summon(1030, {27, 68})
        |> summon(1030, {60, 35})
        |> summon(1030, {27, 35})
      end

    ctx
    |> summon(1119, {53, 52})
    |> summon(1119, {34, 52})
    |> summon(1111, {58, 52})
    |> summon(1111, {58, 52})
    |> summon(1111, {29, 52})
    |> summon(1111, {29, 52})
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
      |> mes("...Hmm.")
      |> next()
      |> mes("[Sir Windsor]")
      |> mes("...One stage left.")
      |> close()
      |> warp(@room, 143, 152)
      |> donpcevent("Knight2::OnDisable")
      |> donpcevent("Knight3::OnEnable")
      |> stopnpctimer()
    else
      ctx
    end
  end
end
