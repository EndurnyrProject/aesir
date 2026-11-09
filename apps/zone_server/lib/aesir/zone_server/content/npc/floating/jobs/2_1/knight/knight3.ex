defmodule Aesir.ZoneServer.Content.Npc.Floating.Jobs.M21.Knight.Knight3 do
  @moduledoc """
  Third and last trial room controller of the Knight job change quest.

  ## Behavior

  - On enable, stocks the third test room with the Goblin Archer and Steam
    Goblin (pre-renewal only) plus five Goblins and counts them.
  - When the last monster dies, plays Sir Windsor's lines, sets `KNIGHT_Q` to 8,
    advances the knight quest 9006 to 9007 when it is still on the first step,
    and sends the player back to Sir Windsor in the Prontera Chivalry.
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
  @on_mob_dead "Knight3::OnMyMobDead"

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Knight3")
  def on_event("OnEnable", ctx), do: start_trial(ctx)

  def on_event("OnDisable", ctx) do
    ctx |> killmonster(@room, @on_mob_dead) |> disablenpc("Knight3")
  end

  def on_event("OnMyMobDead", ctx), do: count_kill(ctx)
  def on_event("OnTimer180000", ctx), do: donpcevent(ctx, "Knight3::OnDisable")

  def on_event("OnTimer181000", ctx) do
    areawarp(ctx, @room, 124, 132, 163, 171, "prt_in", 80, 100)
  end

  def on_event("OnTimer182000", ctx) do
    ctx
    |> stopnpctimer()
    |> donpcevent("Knight3::OnDisable")
    |> donpcevent("Windsor Benedict#knt::OnStart")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp start_trial(ctx) do
    ctx = enablenpc(ctx, "Knight3")

    ctx =
      if Rathena.truthy?(checkre(ctx, 0)) do
        set_npc_var(ctx, "MyMobs", 5)
      else
        ctx
        |> set_npc_var("MyMobs", 7)
        |> summon(1258, {147, 167})
        |> summon(1280, {136, 158})
      end

    ctx
    |> summon(1122, {136, 152})
    |> summon(1123, {150, 152})
    |> summon(1124, {143, 145})
    |> summon(1125, {143, 167})
    |> summon(1126, {139, 167})
    |> initnpctimer()
  end

  defp summon(ctx, mob_id, {x, y}) do
    summon_mob(ctx, mob_id: mob_id, map: @room, at: {x, y}, event: @on_mob_dead)
  end

  defp count_kill(ctx) do
    remaining = get_npc_var(ctx, "MyMobs", 0) - 1
    ctx = set_npc_var(ctx, "MyMobs", remaining)

    if remaining < 1 do
      ctx =
        ctx
        |> mes("[Sir Windsor]")
        |> mes("...")
        |> next()
        |> mes("[Sir Windsor]")
        |> mes("...Very good.")
        |> next()
        |> mes("[Sir Windsor]")
        |> mes("...Go talk to")
        |> mes("Amy Beatrice now.")
        |> close()
        |> set_char_var(:KNIGHT_Q, 8)

      ctx =
        if checkquest(ctx, 9007) == -1 do
          changequest(ctx, 9006, 9007)
        else
          ctx
        end

      ctx
      |> warp("prt_in", 80, 100)
      |> donpcevent("Knight3::OnDisable")
      |> donpcevent("Windsor Benedict#knt::OnStart")
      |> stopnpctimer()
    else
      ctx
    end
  end
end
