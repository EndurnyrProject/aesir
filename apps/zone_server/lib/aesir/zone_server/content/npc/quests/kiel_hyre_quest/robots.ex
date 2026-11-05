defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Robots do
  @moduledoc """
  The test tube releases robots guarding a metal fragment.

  ## Behavior

  - Summons four robots when none of its previous group remain.
  - Drops a metal fragment after the last robot is defeated.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_kiehl01",
        x: 15,
        y: 179,
        dir: 0,
        sprite: 111,
        name: "Robots",
        scope: :shared,
        unique_name: "Robots#kh1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnMyMobDead", ctx) do
    if mobcount(ctx, "kh_kiehl01", "Robots#kh1::OnMyMobDead") < 1 do
      makeitem(ctx, 7506, 1, "this", 18, 180)
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if mobcount(ctx, "kh_kiehl01", "Robots#kh1::OnMyMobDead") < 1 do
      ctx
      |> mes("^3355FFAs soon as you")
      |> mes("touch the test tube,")
      |> mes("a bunch of robots")
      |> mes("suddenly appeared.^000000.")
      |> close()
      |> summon_mob(
        mob_id: 1740,
        map: "kh_kiehl01",
        at: {18, 181},
        event: "Robots#kh1::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1739,
        map: "kh_kiehl01",
        at: {18, 180},
        event: "Robots#kh1::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1740,
        map: "kh_kiehl01",
        at: {18, 179},
        event: "Robots#kh1::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1739,
        map: "kh_kiehl01",
        at: {18, 178},
        event: "Robots#kh1::OnMyMobDead"
      )
    else
      ctx
    end
  end
end
