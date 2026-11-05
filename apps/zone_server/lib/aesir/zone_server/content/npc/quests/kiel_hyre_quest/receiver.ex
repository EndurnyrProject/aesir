defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Receiver do
  @moduledoc """
  Kiehl’s receiver challenges intruders with two guardian robots.

  ## Behavior

  - Summons the guardians only while none remain and advances the quest when first challenged at
    the required stage.
  - Drops a key when the last linked guardian dies.

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
        x: 17,
        y: 39,
        dir: 0,
        sprite: 111,
        name: "Receiver",
        scope: :shared,
        unique_name: "Receiver#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnMyMobDead", ctx) do
    if mobcount(ctx, "kh_kiehl01", "Receiver#kh::OnMyMobDead") < 1 do
      makeitem(ctx, 7506, 1, "this", 19, 36)
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if mobcount(ctx, "kh_kiehl01", "Receiver#kh::OnMyMobDead") < 1 do
      ctx
      |> mes("^333333*BBBZZZ*^000000")
      |> challenge_intruder()
      |> close()
      |> summon_mob(
        mob_id: 1739,
        map: "kh_kiehl01",
        at: {16, 32},
        event: "Receiver#kh::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1740,
        map: "kh_kiehl01",
        at: {18, 31},
        event: "Receiver#kh::OnMyMobDead"
      )
    else
      ctx
    end
  end

  defp challenge_intruder(ctx) do
    if get_char_var(ctx, :KielHyreQuest, 0) == 74 do
      ctx
      |> next()
      |> mes("[????]")
      |> mes("^333333*Bzzzz...*")
      |> mes("I've never seen you")
      |> mes("before. Did Father send")
      |> mes("you to kill me? We'll just")
      |> mes("see about that! Go ahead,")
      |> mes("try to find me, adventurer.^000000.")
      |> set_char_var(:KielHyreQuest, 76)
    else
      ctx
    end
  end
end
