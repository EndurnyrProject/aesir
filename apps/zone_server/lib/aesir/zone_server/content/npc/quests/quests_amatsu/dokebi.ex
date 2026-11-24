defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Dokebi do
  @moduledoc """
  Controls the easier Dokebi encounter.

  ## Behavior

  - Spawns nine Dokebi and enables the coach when all are defeated.
  - Announces a random message when a Dokebi dies before the last.

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
        y: 15,
        dir: 0,
        sprite: -1,
        name: "Dokebi",
        scope: :shared,
        unique_name: "Dokebi#ez"
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
    disablenpc(ctx, "Dokebi#ez")
  end

  defp ev_onenable(ctx) do
    ctx
    |> enablenpc("Dokebi#ez")
    |> set_npc_var("MyMobs", 9)
    |> summon_mob(mob_id: 1110, map: "ama_test", at: {45, 95}, event: "Dokebi#ez::OnMyMobDead")
    |> summon_mob(mob_id: 1110, map: "ama_test", at: {45, 99}, event: "Dokebi#ez::OnMyMobDead")
    |> summon_mob(mob_id: 1110, map: "ama_test", at: {47, 101}, event: "Dokebi#ez::OnMyMobDead")
    |> summon_mob(mob_id: 1110, map: "ama_test", at: {51, 101}, event: "Dokebi#ez::OnMyMobDead")
    |> summon_mob(mob_id: 1110, map: "ama_test", at: {55, 101}, event: "Dokebi#ez::OnMyMobDead")
    |> summon_mob(mob_id: 1110, map: "ama_test", at: {55, 97}, event: "Dokebi#ez::OnMyMobDead")
    |> summon_mob(mob_id: 1110, map: "ama_test", at: {55, 93}, event: "Dokebi#ez::OnMyMobDead")
    |> summon_mob(mob_id: 1110, map: "ama_test", at: {53, 91}, event: "Dokebi#ez::OnMyMobDead")
    |> summon_mob(mob_id: 1110, map: "ama_test", at: {49, 91}, event: "Dokebi#ez::OnMyMobDead")
  end

  defp ev_onreset(ctx) do
    killmonster(ctx, "ama_test", "Dokebi#ez::OnMyMobDead")
  end

  defp ev_onmymobdead(ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> mapannounce("ama_test", "I...I will be baaaack~~~~!!!", 1)
      |> enablenpc("Coach#ama")
      |> set_char_var(:event_momo, 2)
    else
      ctx = set_local(ctx, :dokebi_tel, Enum.random(1..4))

      case get_local(ctx, :dokebi_tel, 0) do
        1 -> mapannounce(ctx, "ama_test", "!!IT'S A RAID!!!! RUN!!", 1)
        2 -> mapannounce(ctx, "ama_test", " Ow, Ouch!!! ", 1)
        3 -> mapannounce(ctx, "ama_test", " But I didn't even do anything Baaad~!!", 1)
        4 -> mapannounce(ctx, "ama_test", " I'm sorry~~ Waaaaah~~ ", 1)
        _ -> ctx
      end
    end
  end
end
