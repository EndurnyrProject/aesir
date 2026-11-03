defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.MonkSkills.Monk do
  @moduledoc """
  Monk who guides the Monk skill quest and teaches Excruciating Palm.

  ## Behavior

  - Points new Monks to the pacifist monk who teaches Spiritual Bestowment.
  - Asks Monks who learned Spiritual Bestowment for 20 Stems and 3 Shoots as proof
    of strength.
  - Takes the proof, then teaches Excruciating Palm on the following visit.

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
        map: "monk_test",
        x: 316,
        y: 69,
        dir: 5,
        sprite: 823,
        name: "Monk",
        scope: :shared,
        unique_name: "Monk#qsk_mo"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @excruciating_palm 1016
  @stem 905
  @shoot 711

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

  defp monk_progress(ctx, 6) do
    ctx
    |> mes("[Monk]")
    |> mes("How did you convince")
    |> mes("that monk to teach you")
    |> mes("Spiritual Bestowment? It'd")
    |> mes("be nice to popularize both")
    |> mes("of our specialty skills, but the world may not be ready yet.")
    |> close()
  end

  defp monk_progress(ctx, 5), do: teach_palm(ctx)

  defp monk_progress(ctx, 4) do
    if count_item(ctx, @stem) > 19 and count_item(ctx, @shoot) > 2 do
      accept_proof(ctx)
    else
      request_proof(ctx)
    end
  end

  defp monk_progress(ctx, 3), do: explain_palm_trial(ctx)
  defp monk_progress(ctx, 1), do: remind_bestowment(ctx)
  defp monk_progress(ctx, 0), do: introduce_bestowment(ctx)
  defp monk_progress(ctx, _step), do: preach(ctx)

  defp teach_palm(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("To begin, Excruciating Palm")
    |> mes("is performed by taking your")
    |> mes("inner strength and making it")
    |> mes("into outer strength. Then, you")
    |> mes("focus all of that into your palm. You'll explode if you do it wrong.")
    |> next()
    |> mes("[Monk]")
    |> mes("This skill truly causes")
    |> mes("excruciating pain, consuming")
    |> mes("20 SP and even 10 HP. It will")
    |> mes("knock back monsters with the")
    |> mes("chance of stunning them, but only the targeted monster is damaged.")
    |> next()
    |> mes("[Monk]")
    |> mes("If you use this skill on")
    |> mes("other players, it will cause")
    |> mes("a certain amount of damage,")
    |> mes("but it won't knock back other")
    |> mes("players near the original target. Does that make sense?")
    |> next()
    |> mes("[Monk]")
    |> mes("Anyway, keep practicing")
    |> mes("these principles and you'll")
    |> mes("master Excruciating Palm.")
    |> mes("You should definitely be able")
    |> mes("to do it since you've learned")
    |> mes("Spiritual Endowment.")
    |> set_char_var(:MONK_SK, 6)
    |> skill(@excruciating_palm, 1, :permanent)
    |> next()
    |> mes("[Monk]")
    |> mes("Well, we've completed")
    |> mes("the lesson. I hope you")
    |> mes("use your new skills to")
    |> mes("fight for justice and")
    |> mes("combat evil. Goodbye")
    |> mes("for now, my friend.")
    |> close()
  end

  defp accept_proof(ctx) do
    ctx
    |> ask_about_palm()
    |> mes("[Monk]")
    |> mes("Hm. Well, you are strong")
    |> mes("enough to handily defeat a")
    |> mes("good number of Mandragoras.")
    |> mes("All right. You seem to be ready. Come back in a little while so")
    |> mes("that I can finish preparations.")
    |> delitem(@stem, 20)
    |> delitem(@shoot, 3)
    |> set_char_var(:MONK_SK, 5)
    |> close()
  end

  defp request_proof(ctx) do
    ctx
    |> ask_about_palm()
    |> mes("[Monk]")
    |> mes("As I mentioned to you")
    |> mes("before, you must subjugate")
    |> mes("Mandragoras to prove that")
    |> mes("you are qualified, in terms")
    |> mes("of strength and compassion,")
    |> mes("to learn Excruciating Palm.")
    |> next()
    |> mes("[Monk]")
    |> mes("Fight to protect those")
    |> mes("innocents terrorized by")
    |> mes("the aggressive Mandragoras.")
    |> mes("If you bring me ^FF000020 Stems^000000 and")
    |> mes("^FF00003 Shoots^000000, I will be satisfied with this proof of your ability.")
    |> next()
    |> mes("[Monk]")
    |> mes("Do you understand now?")
    |> close()
  end

  defp ask_about_palm(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("What's that...?")
    |> mes("You've learned the")
    |> mes("Spiritual Bestowment")
    |> mes("skill? I assume that you")
    |> mes("wish to learn Excruciating")
    |> mes("Palm next. Am I correct?")
    |> next()
  end

  defp explain_palm_trial(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("Have you come to learn")
    |> mes("Excruciating Palm? If only")
    |> mes("that were possible. There")
    |> mes("are two obstacles we face")
    |> mes("in fulfilling your request.")
    |> next()
    |> mes("[Monk]")
    |> mes("Firstly, you must learn")
    |> mes("the Spiritual Bestowment")
    |> mes("skill beforehand. It will be")
    |> mes("difficult to get that monk")
    |> mes("to teach it to you, if not")
    |> mes("outright impossible.")
    |> next()
    |> mes("[Monk]")
    |> mes("Secondly, you will need")
    |> mes("to pass my little test of")
    |> mes("strength, so that I can be")
    |> mes("use that your body can endure")
    |> mes("the awesome power involved")
    |> mes("in using Excruciating Palm.")
    |> next()
    |> mes("[Monk]")
    |> mes("Mm. I know that Mandragoras")
    |> mes("have been menacing travelers,")
    |> mes("so if you can prove to me that")
    |> mes("you've been hunting them, you")
    |> mes("will prove worthy of learning")
    |> mes("Excruciating Palm.")
    |> next()
    |> mes("[Monk]")
    |> mes("If you can somehow convince")
    |> mes("that monk to teach you how to")
    |> mes("perform Spiritual Bestowment,")
    |> mes("I shall then ask you to bring")
    |> mes("^FF000020 Stems^000000 and ^FF00003 Shoots^000000 from")
    |> mes("hunting Mandragoras.")
    |> next()
    |> mes("[Monk]")
    |> mes("Of course, completing")
    |> mes("my test is meaningless")
    |> mes("if you do not first learn the")
    |> mes("Spiritual Bestowment skill.")
    |> mes("I wish you luck with that...")
    |> set_char_var(:MONK_SK, 4)
    |> close()
  end

  defp remind_bestowment(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("There is a pacifist monk")
    |> mes("living in seclusion that")
    |> mes("can teach the Spiritual")
    |> mes("Bestowment skill. However,")
    |> mes("he is stubborn, and has refused many who wish to learn from him.")
    |> next()
    |> mes("[Monk]")
    |> mes("It would be good if")
    |> mes("you can convince him")
    |> mes("to teach it to you, as it is")
    |> mes("impossible to learn how")
    |> mes("to perform this skill alone.")
    |> mes("It's really quite a pity...")
    |> close()
  end

  defp introduce_bestowment(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("Power without justice will")
    |> mes("not last. Justice without")
    |> mes("power cannot be upheld.")
    |> mes("Power does not equate to")
    |> mes("justice, but true justice can")
    |> mes("be the means to power.")
    |> next()
    |> mes("[Monk]")
    |> mes("Always remember this truth.")
    |> mes("Justice and power, compassion")
    |> mes("and strength, wisdom and action. These are all complements that")
    |> mes("go hand in hand and must always")
    |> mes("be harmoniousy balanced.")
    |> next()
    |> mes("[Monk]")
    |> mes("So it is with some skills.")
    |> mes("I have developed a skill")
    |> mes("that is the pure manifestation")
    |> mes("of power, Excruciating Palm!")
    |> mes("However, it is useless without")
    |> mes("its complement to balance it.")
    |> next()
    |> mes("[Monk]")
    |> mes("The complement to my skill")
    |> mes("is a skill known as Spiritual")
    |> mes("Bestowment, which can only")
    |> mes("be taught by one Monk. However,")
    |> mes("he refuses to teach it to others, believing they are unworthy.")
    |> next()
    |> mes("[Monk]")
    |> mes("Although I've let him know")
    |> mes("that he should popularize his")
    |> mes("teaching of that skill, I must respect his decision. Still, you")
    |> mes("may try talking to him if you wish to try to learn some new skills.")
    |> set_char_var(:MONK_SK, 1)
    |> next()
    |> mes("[Monk]")
    |> mes("To find him, simply seek")
    |> mes("out the monk who always")
    |> mes("preaches the empty meaning")
    |> mes("of fighting. That will be him.")
    |> close()
  end

  defp preach(ctx) do
    ctx
    |> mes("[Monk]")
    |> mes("Power without justice will")
    |> mes("not last. Justice without")
    |> mes("power cannot be upheld.")
    |> mes("Power does not equate to")
    |> mes("justice, but true justice can")
    |> mes("be the means to power.")
    |> close()
  end
end
