defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22a.Creator.Biochemist do
  @moduledoc """
  Advances eligible High Merchants to Biochemist (Creator) and restores lost Bioethics.

  ## Behavior

  - Creators who completed the Bioethics quest but lack the skill can recover it at level 1.
  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or thoughts on earning a place in Valhalla through science.
  - High Merchants above job level 39 whose pending advancement is Creator are offered the job
    change once all their skill points are spent; accepting clears the pending advancement and
    restores Bioethics to those who completed its quest.
  - Everyone else is welcomed to Valhalla.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Nana
    - Lupus
    - Vicious
    - Lemongrass

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "valkyrie",
        x: 53,
        y: 50,
        dir: 3,
        sprite: 122,
        name: "Biochemist",
        scope: :shared,
        unique_name: "Biochemist#Valkyrie"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      lost_bioethics?(ctx) -> offer_memory_restoration(ctx)
      get_char_var(ctx, :ADVJOB, 0) == 0 or upper(ctx) != 1 -> greet_non_candidate(ctx)
      eligible_for_advancement?(ctx) -> offer_advancement(ctx)
      true -> welcome_to_valhalla(ctx)
    end
  end

  defp lost_bioethics?(ctx) do
    Rathena.job_id(class(ctx)) == Rathena.job_id(:creator) and
      get_char_var(ctx, :bioeth, 0) == 13 and getskilllv(ctx, 238) == 0
  end

  defp eligible_for_advancement?(ctx) do
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:creator) and
      Rathena.job_id(class(ctx)) == Rathena.job_id(:merchant_high) and job_level(ctx) > 39
  end

  defp offer_memory_restoration(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Biochemist]")
      |> mes("Ah, have you come to")
      |> mes("retrieve the memories")
      |> mes("lost to you? Yes, you")
      |> mes("must be here for the")
      |> mes("secrets of life that")
      |> mes("were once yours...")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      restore_memories(ctx)
    else
      decline_memory_restoration(ctx)
    end
  end

  defp restore_memories(ctx) do
    ctx
    |> mes("[Biochemist]")
    |> mes("Close your eyes and")
    |> mes("put your mind at rest.")
    |> mes("We will return to your")
    |> mes("past to recollect the")
    |> mes("fragments of your lost")
    |> mes("memories.")
    |> next()
    |> mes("[Biochemist]")
    |> mes("When you open your eyes,")
    |> mes("you will clearly remember")
    |> mes("the secret of life. You will")
    |> mes("also remember the weight of")
    |> mes("responsibility in using these")
    |> mes("secrets for the right ends...")
    |> next()
    |> skill(238, 1, :permanent)
    |> mes("[Biochemist]")
    |> mes("Open your eyes...")
    |> mes("Now that you have")
    |> mes("remembered how to")
    |> mes("create artificial life, I only")
    |> mes("ask that you treat all of your")
    |> mes("creations with respect.")
    |> close()
  end

  defp decline_memory_restoration(ctx) do
    ctx
    |> mes("[Biochemist]")
    |> mes("If you wish to")
    |> mes("retrieve your lost")
    |> mes("memories, please")
    |> mes("come back to me.")
    |> mes("The secret to creating")
    |> mes("life is no trifling thing...")
    |> close()
  end

  defp greet_non_candidate(ctx) do
    if Enum.random(1..10) > 4 do
      congratulate(ctx)
    else
      share_creed(ctx)
    end
  end

  defp congratulate(ctx) do
    ctx
    |> mes("[Biochemist]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[Biochemist]")
    |> mes("It's strange that")
    |> mes("someone like me is here.")
    |> mes("But even someone skilled")
    |> mes("in the ways of science")
    |> mes("can manage to be a hero.")
    |> next()
    |> mes("[Biochemist]")
    |> mes("In this instance,")
    |> mes("it's not necessarily")
    |> mes("the means I've used, but")
    |> mes("the ends for which I've")
    |> mes("fought that earned me")
    |> mes("a place in Valhalla...")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Biochemist]")
      |> mes("Yes...")
      |> mes("It's about time.")
      |> mes("We need more geniuses")
      |> mes("like you on Midgard.")
      |> next()
      |> mes("[Biochemist]")
      |> mes("Would you like to")
      |> mes("become a Biochemist?")
      |> next()
      |> select(["No.", "Yes."])

    cond do
      choice == 1 -> decline_advancement(ctx)
      Rathena.truthy?(skill_point(ctx)) -> request_skill_points_spent(ctx)
      true -> advance(ctx)
    end
  end

  defp decline_advancement(ctx) do
    ctx
    |> mes("[Biochemist]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[Biochemist]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx = jobchange(ctx, :creator)

    ctx =
      if get_char_var(ctx, :bioeth, 0) == 13 do
        skill(ctx, 238, 1, :permanent)
      else
        ctx
      end

    ctx
    |> set_char_var(:ADVJOB, 0)
    |> mes("[Biochemist]")
    |> mes("Congratulations!")
    |> mes("As a Biochemist,")
    |> mes("I hope you use your")
    |> mes("vast knowledge for the")
    |> mes("right purposes.")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[Biochemist]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Biochemist]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
