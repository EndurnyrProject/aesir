defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.AmMut do
  @moduledoc """
  Controls the Am Mut encounter.

  ## Behavior

  - Spawns three Am Mut and enables the coach when all are defeated.
  - Announces a random message when an Am Mut dies before the last.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_test",
        x: 34,
        y: 17,
        dir: 0,
        sprite: -1,
        name: "Am Mut",
        scope: :shared,
        unique_name: "Am Mut#ama"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnReset", ctx), do: ev_onreset(ctx)
  def on_event("OnMyMobDead", ctx), do: ev_onmymobdead(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  defp ev_oninit(ctx) do
    disablenpc(ctx, "Am Mut#ama")
  end

  defp ev_onenable(ctx) do
    ctx
    |> enablenpc("Am Mut#ama")
    |> set_npc_var("MyMobs", 3)
    |> summon_mob(mob_id: 1301, map: "ama_test", at: {35, 102}, event: "Am Mut#ama::OnMyMobDead")
    |> summon_mob(mob_id: 1301, map: "ama_test", at: {40, 91}, event: "Am Mut#ama::OnMyMobDead")
    |> summon_mob(mob_id: 1301, map: "ama_test", at: {56, 108}, event: "Am Mut#ama::OnMyMobDead")
  end

  defp ev_onreset(ctx) do
    killmonster(ctx, "ama_test", "Am Mut#ama::OnMyMobDead")
  end

  defp ev_onmymobdead(ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      enablenpc(ctx, "Coach#after")
    else
      ctx = set_local(ctx, :am_mut_tel, Enum.random(1..3))

      case get_local(ctx, :am_mut_tel, 0) do
        1 -> mapannounce(ctx, "ama_test", " Augh!! I, I made mistake...!", 1)
        2 -> mapannounce(ctx, "ama_test", " Ugh...How could I lose?!... ", 1)
        3 -> mapannounce(ctx, "ama_test", " Mommmmy~~!!!", 1)
        _ -> ctx
      end
    end
  end
end
