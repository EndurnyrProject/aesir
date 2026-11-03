defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.MonkSkills.ApprenticeMonk do
  @moduledoc """
  Apprentice Monk who teaches Spiritual Bestowment and Excruciating Palm in the Monk skill quest.

  ## Behavior

  - Sends Monks who ask about his skill off to prove their selflessness.
  - Teaches Spiritual Bestowment to Monks who return carrying nothing.
  - Teaches Spiritual Bestowment and Excruciating Palm to Monks whose quest progress was set
    by the other quest Monk.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - Samuray22
    - L0ne_W0lf
    - DracoRPG

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/monk_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_monk",
        x: 270,
        y: 198,
        dir: 3,
        sprite: 753,
        name: "Apprentice Monk",
        scope: :shared,
        unique_name: "Apprentice Monk#qsk_mo"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @spiritual_bestowment 1015
  @excruciating_palm 1016

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:monk) do
      monk_progress(ctx, get_char_var(ctx, :MONK_SK, 0))
    else
      preach(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp monk_progress(ctx, step) do
    cond do
      step == 7 -> ctx |> contemplate() |> close()
      step == 6 and getskilllv(ctx, @spiritual_bestowment) == 0 -> teach_both_skills(ctx)
      step > 2 -> keep_secret(ctx)
      step == 2 and weight(ctx) == 0 -> teach_bestowment(ctx)
      step == 2 -> demand_selflessness(ctx)
      step == 1 -> start_trial(ctx)
      true -> preach(ctx)
    end
  end

  defp contemplate(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("To take the time to")
    |> mes("comtemplate on your most")
    |> mes("important goal, your highest")
    |> mes("priority, is never a waste.")
    |> mes("Never confuse your means")
    |> mes("to the end you wish to achieve.")
  end

  defp teach_both_skills(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("You've forgotten the")
    |> mes("basics behind performing")
    |> mes("Spiritual Bestowment?")
    |> mes("How can this be...?")
    |> next()
    |> mes("[Monk]")
    |> mes("Ah, now I understand.")
    |> mes("You've transcended the")
    |> mes("limitations that used to")
    |> mes("hold you back, and have")
    |> mes("become a Champion. I'm")
    |> mes("sorry for underestimating you.")
    |> next()
    |> mes("[Monk]")
    |> mes("Very well. It will be an honor")
    |> mes("for me to help you relearn the")
    |> mes("Spiritual Bestowment skill. As")
    |> mes("a side effect, you will probably relearn Excruciating Palm as well.")
    |> next()
    |> mes("[Monk]")
    |> mes("Now be still and relax")
    |> mes("as I perform my special")
    |> mes("accupressure treatment that")
    |> mes("will commit these skills to")
    |> mes("your nervous system and ")
    |> mes("motor memory...")
    |> next()
    |> mes("^3355FF*Tap-tap-tap-tap-tap-tap-tap-tap- tap-tap-tap-tap-tap-tap-tap-tap-")
    |> mes("tap-tap-tap-tap-tap-tap-tap-tap- tap-tap-tap-tap-tap-tap-tap-tap-")
    |> mes("tap-tap-tap-tap-tap-tap-tap-tap- tap-tap-tap-tap-tap-tap-tap-tap-")
    |> mes("tap-tap-tap-tap-tap-tap* *POKE*^000000")
    |> set_char_var(:MONK_SK, 7)
    |> skill(@spiritual_bestowment, 1, :permanent)
    |> skill(@excruciating_palm, 1, :permanent)
    |> next()
    |> mes("[Monk]")
    |> mes("It is done. Please")
    |> mes("continue to use these")
    |> mes("special skills to promote")
    |> mes("peace and harmony in this")
    |> mes("world. Farewell, my friend.")
    |> close()
  end

  defp keep_secret(ctx) do
    ctx
    |> contemplate()
    |> next()
    |> mes("[Monk]")
    |> mes("Ah, I have a favor to ask.")
    |> mes("Please do not tell others that")
    |> mes("I have taught you Spiritual")
    |> mes("Bestowment. I don't wish to")
    |> mes("spend my time teaching too")
    |> mes("many people this skill...")
    |> close()
  end

  defp teach_bestowment(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("Ah. Well done. I see")
    |> mes("that you managed to learn")
    |> mes("the most important thing,")
    |> mes("selflessness, on your own.")
    |> mes("Now I trust that you won't")
    |> mes("abuse what I have to teach you.")
    |> next()
    |> mes("[Monk]")
    |> mes("My test may seem too strict,")
    |> mes("but it is impossible to learn")
    |> mes("Spiritual Bestowment without the right discipline. As with all")
    |> mes("things, readiness and preparation precede all forms of realization.")
    |> next()
    |> mes("[Monk]")
    |> mes("Now just relax for a moment.")
    |> mes("I will use accupressure to")
    |> mes("train your nervous system to")
    |> mes("physically memorize the energy")
    |> mes("flow and movements required")
    |> mes("for Spiritual Bestowment.")
    |> next()
    |> mes("^3355FF*Tap... tap*")
    |> mes("*Tap... Tap*")
    |> mes("*Tap tap tap*^000000")
    |> next()
    |> mes("^3355FF*Tap tap tap*")
    |> mes("*Tap tap tap*")
    |> mes("*Tap... Tap tap*^000000")
    |> next()
    |> mes("^3355FF*Tap-tap-tap-tap-tap-tap-tap-tap- tap-tap-tap-tap-tap-tap-tap-tap-")
    |> mes("tap-tap-tap-tap-tap-tap-tap-tap- tap-tap-tap-tap-tap-tap-tap-tap-")
    |> mes("tap-tap-tap-tap-tap-tap-tap-tap- tap-tap-tap-tap-tap-tap-tap-tap-")
    |> mes("tap-tap-tap-tap-tap-tap* *POKE*^000000")
    |> next()
    |> mes("[Monk]")
    |> mes("It is done. You are now")
    |> mes("capable of using Spiritual")
    |> mes("Bestowment. Ah, yes. I've never")
    |> mes("really named this skill, but that is what it is usually called by")
    |> mes("other Monks who have seen it.")
    |> next()
    |> mes("[Monk]")
    |> mes("Remember that this skill has a")
    |> mes("long Cast Time and Skill Delay,")
    |> mes("so use it very carefully. This")
    |> mes("skill will let you give a Spirit Sphere to one of your Party")
    |> mes("Members by consuming 40 SP.")
    |> next()
    |> mes("[Monk]")
    |> mes("You will better understand")
    |> mes("the use of this skill if you")
    |> mes("practice. Keep in mind that")
    |> mes("fighting may be necessary at")
    |> mes("times, but it is a means to an")
    |> mes("end, and not an end in itself.")
    |> set_char_var(:MONK_SK, 3)
    |> skill(@spiritual_bestowment, 1, :permanent)
    |> next()
    |> mes("[Monk]")
    |> mes("Our skills should not be")
    |> mes("used to shed blood. If you")
    |> mes("can transcend conflict, you")
    |> mes("will know that fighting has")
    |> mes("no worth, no value. Peace")
    |> mes("be with you, my friend.")
    |> close()
  end

  defp demand_selflessness(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("Have you learned the")
    |> mes("meaning of selflessness?")
    |> mes("When you abandon greed")
    |> mes("and the desires of the world,")
    |> mes("you will be ready for my teaching.")
    |> close()
  end

  defp start_trial(ctx) do
    ctx
    |> fighting_is_meaningless()
    |> next()
    |> mes("[Monk]")
    |> mes("Hm? To what purpose have")
    |> mes("you come to visit me? Ah, so")
    |> mes("you wish to learn the skill that I have developed. My colleague")
    |> mes("was right: more and more people have been wanting to learn this.")
    |> next()
    |> mes("[Monk]")
    |> mes("Do not misunderstand me.")
    |> mes("It is true that power and")
    |> mes("justice, wisdom and action")
    |> mes("must be balanced. However,")
    |> mes("I have been visited by too many power hungry, bloodthirsty people.")
    |> next()
    |> mes("[Monk]")
    |> mes("In all fairness, I shall")
    |> mes("give you a chance. Prove")
    |> mes("to me that you would use")
    |> mes("the skills I teach you for")
    |> mes("peace and justice. Prove that")
    |> mes("you are free from selfishness.")
    |> set_char_var(:MONK_SK, 2)
    |> close()
  end

  defp preach(ctx) do
    ctx
    |> fighting_is_meaningless()
    |> close()
  end

  defp fighting_is_meaningless(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("Fighting is meaningless.")
    |> mes("Transcend conflict and")
    |> mes("difference through the")
    |> mes("realization that all are")
    |> mes("one. Discipline your mind")
    |> mes("and the truth will be revealed.")
  end
end
