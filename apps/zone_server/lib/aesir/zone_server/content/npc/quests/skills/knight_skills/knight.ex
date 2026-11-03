defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.KnightSkills.Knight do
  @moduledoc """
  Essofeit, an old-fashioned Knight of the 7th Division who teaches Charge Attack to Knights
  that share his ideals of chivalry.

  ## Behavior

  - Starts the quest for Knights and sends them to tour the 7th Division training grounds.
  - After the tour, laments the state of the Knighthood and asks for proof of strength.
  - Takes 5 Candy Canes and 3 Witherless Roses, then teaches Charge Attack on the next visit.
  - Re-teaches the skill to Lord Knights who lost it on rebirth.
  - Gives everyone else a greeting.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - DracoRPG
    - Samuray22
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 85,
        y: 99,
        dir: 3,
        sprite: 734,
        name: "Knight",
        scope: :shared,
        unique_name: "Knight#kabuto"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @charge_attack 1001
  @candy_cane 530
  @witherless_rose 748

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) do
      knight_quest(ctx, get_char_var(ctx, :KNGT_SK, 0))
    else
      greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp knight_quest(ctx, 10), do: admire_adventurer(ctx)

  defp knight_quest(ctx, 9) do
    if getskilllv(ctx, @charge_attack) == 0,
      do: reteach_lord_knight(ctx),
      else: admire_adventurer(ctx)
  end

  defp knight_quest(ctx, 8), do: teach_charge_attack(ctx)

  defp knight_quest(ctx, 7) do
    if count_item(ctx, @candy_cane) > 4 and count_item(ctx, @witherless_rose) > 2,
      do: ask_for_proof(ctx),
      else: reminisce(ctx)
  end

  defp knight_quest(ctx, 6), do: lament_division(ctx)
  defp knight_quest(ctx, 1), do: suggest_tour(ctx)
  defp knight_quest(ctx, 0), do: start_quest(ctx)
  defp knight_quest(ctx, _step), do: greeting(ctx)

  defp admire_adventurer(ctx) do
    ctx
    |> mes("[Essofeit]")
    |> mes("Ah, it must be grand to")
    |> mes("be an adventuring Knight")
    |> mes("in this world. You must have")
    |> mes("encountered all sorts of")
    |> mes("dangerous monsters and")
    |> mes("fearsome enemies, right?")
    |> next()
    |> mes("[Essofeit]")
    |> mes("I'm almost jealous of")
    |> mes("all the great experiences")
    |> mes("that you must be having.")
    |> mes("Someday, you'll have to tell")
    |> mes("me your own stories of bravery.")
    |> close()
  end

  defp reteach_lord_knight(ctx) do
    ctx
    |> mes("[Essofeit]")
    |> mes("Ah, I see that you've")
    |> mes("made tremendous progress")
    |> mes("in your pursuit of strength.")
    |> mes("Transcendance is no small")
    |> mes("feat, and it is a great honor")
    |> mes("to achieve Lord Knight rank.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("However, I'm aware of the")
    |> mes("drawback of memory erasure.")
    |> mes("Therefore, I assume you're")
    |> mes("here to learn the Charge Attack")
    |> mes("skill once more. It will be my")
    |> mes("pleasure to instruct you again.")
    |> next()
    |> explain_charge_attack()
    |> set_char_var(:KNGT_SK, 10)
    |> skill(@charge_attack, 1, :permanent)
    |> next()
    |> mes("[Essofeit]")
    |> mes("Good luck on your")
    |> mes("adventures, Lord Knight.")
    |> mes("I'm sure you'll make good")
    |> mes("use of the Charge Attack")
    |> mes("and bring pride to the")
    |> mes("Prontera Chivalry.")
    |> close()
  end

  defp teach_charge_attack(ctx) do
    ctx
    |> mes("[Essofeit]")
    |> mes("I've named this skill,")
    |> mes("''Charge Attack.'' It's not")
    |> mes("a fancy name, but it's simple")
    |> mes("and direct enough for you to")
    |> mes("understand how it works.")
    |> mes("Now let me teach it to you...")
    |> next()
    |> explain_charge_attack()
    |> set_char_var(:KNGT_SK, 9)
    |> skill(@charge_attack, 1, :permanent)
    |> next()
    |> mes("[Essofeit]")
    |> mes("I hope you make good")
    |> mes("use of the Charge Attack")
    |> mes("skill. Just like you, I will be")
    |> mes("doing my best to bring honor")
    |> mes("to the Knighthood with my")
    |> mes("strength and courage!")
    |> close()
  end

  defp explain_charge_attack(ctx) do
    ctx
    |> mes("[Essofeit]")
    |> mes("Charge Attack is an active skill that consumes 40 SP to damage")
    |> mes("one target. If you're further from the target, you'll increase the")
    |> mes("skill's damage and the delay")
    |> mes("before damage is inflicted.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("During this delay, you will")
    |> mes("be immobilized. Therefore,")
    |> mes("the cost of increased damage")
    |> mes("is greater risk to yourself.")
    |> mes("For now, it would be best to practice this skill on your own.")
  end

  defp ask_for_proof(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Essofeit]")
      |> mes("The concept of honor")
      |> mes("seems to be lost on today's")
      |> mes("Knights. No longer do they")
      |> mes("appreciate the meaning of")
      |> mes("the word ''chivalry'' or the")
      |> mes("noble pursuit for strength...")
      |> next()
      |> mes("[Essofeit]")
      |> mes("Back in my day, Knights")
      |> mes("were strong enough to get")
      |> mes("at least 5 Candy Canes and")
      |> mes("3 Witherless Roses through")
      |> mes("hunting alone! But Knights")
      |> mes("these days have grown soft...")
      |> next()
      |> select(["Give him Candy Canes and Witherless Roses", "Cancel"])

    if choice == 1, do: hand_over_proof(ctx), else: shameful_recruits(ctx)
  end

  defp hand_over_proof(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("There are still Knights")
    |> mes("out there who believe in")
    |> mes("honorably risking our lives")
    |> mes("to achieve true strength...")
    |> next()
    |> mes("[Essofeit]")
    |> mes("You...")
    |> mes("You really understand.")
    |> mes("You truly know the value")
    |> mes("of hardship. It makes me")
    |> mes("glad to see that a true")
    |> mes("Knight like you still exists.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("Hahaha, finally, I've")
    |> mes("found someone I can call")
    |> mes("a true comrade. We're the")
    |> mes("last of a dying breed if you")
    |> mes("hadn't noticed, my friend. But")
    |> mes("there is hope for Knights...")
    |> next()
    |> mes("[Essofeit]")
    |> mes("It's decided, then.")
    |> mes("As long as we live,")
    |> mes("chivalry will never die!")
    |> mes("Thanks to you, my faith")
    |> mes("in the Knighthood has")
    |> mes("been rekindled.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("In my recognition of you")
    |> mes("as a true Knight, I will teach")
    |> mes("you a special skill that I've")
    |> mes("been researching recently. Why")
    |> mes("don't you come back after I've")
    |> mes("completed the preparations?")
    |> delitem(@candy_cane, 5)
    |> delitem(@witherless_rose, 3)
    |> set_char_var(:KNGT_SK, 8)
    |> close()
  end

  defp shameful_recruits(ctx) do
    ctx
    |> mes("[Essofeit]")
    |> mes("It's shameful...")
    |> mes("Most new recruits into")
    |> mes("the Prontera Chivalry are")
    |> mes("more concerned about their")
    |> mes("pensions than their honor!")
    |> close()
  end

  defp reminisce(ctx) do
    ctx
    |> mes("[Essofeit]")
    |> mes("Maybe I'm romanticizing")
    |> mes("the past, but I don't agree")
    |> mes("with all the bureaucracy")
    |> mes("that is present today in")
    |> mes("the Prontera Chivalry.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("Although, I admit")
    |> mes("that I was a lot happier")
    |> mes("back when honor was all")
    |> mes("you needed. Nowadays, it ")
    |> mes("seems like anyone can be")
    |> mes("a Knight. Er, no offense~")
    |> close()
  end

  defp lament_division(ctx) do
    ctx
    |> mes("[Essofeit]")
    |> mes("So you've seen the Knights")
    |> mes("of the 7th Division for what")
    |> mes("they really are, eh? As a fellow Knight, you may understand my")
    |> mes("feelings of disappointment.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("It's so disheartening...")
    |> mes("I don't why we're Knights")
    |> mes("or what we're training for.")
    |> mes("When I was your age, well,")
    |> mes("I wanted to risk my life and")
    |> mes("achieve true strength.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("But... I'm sure that you")
    |> mes("don't want to hear an old")
    |> mes("man's tall tales. All those")
    |> mes("wonderful battles, that glorious camaraderie forged between")
    |> mes("rivals... It's all in the past.")
    |> next()
    |> set_char_var(:KNGT_SK, 7)
    |> mes("[Essofeit]")
    |> mes("Maybe it's better that")
    |> mes("I forget all about my old")
    |> mes("fashioned ideals. I guess")
    |> mes("times have changed, and that")
    |> mes("my idea of chivalry may be dead.")
    |> close()
  end

  defp suggest_tour(ctx) do
    ctx
    |> mes("[Essofeit]")
    |> mes("Hm, why don't take a")
    |> mes("tour of the 7th Division")
    |> mes("and see the attitude of my")
    |> mes("comrades for yourself? You'll")
    |> mes("see Grand Master Maroujje")
    |> mes("training the recruits outside.")
    |> close()
  end

  defp start_quest(ctx) do
    ctx
    |> mes("[Essofeit]")
    |> mes("Greetings. I am Essofeit")
    |> mes("Lageiya of the 7th Division")
    |> mes("of the Prontera Chivalry.")
    |> mes("As a proud Knight upholding")
    |> mes("the principles of honor and")
    |> mes("chivalry, I am at your service.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("May I ask which division")
    |> mes("you are from? Ah, you're")
    |> mes("a Knight that's been granted")
    |> mes("royal permisson to journey")
    |> mes("as you please. That must be")
    |> mes("great, the freedom you have.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("Sadly, the Division of")
    |> mes("which I am member is too")
    |> mes("bureaucratic. I believe that my")
    |> mes("comrades are more concerned")
    |> mes("with their pensions than with chivalry, or defending the weak.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("Even if we wanted to be")
    |> mes("more active, there are too")
    |> mes("many regulations that hamper")
    |> mes("the good we can do. Over time,")
    |> mes("the situation has grown much worse. But don't take my word...")
    |> next()
    |> mes("[Essofeit]")
    |> mes("Perhaps it will be better")
    |> mes("if you visited the 7th Division")
    |> mes("for yourself and speak to the")
    |> mes("other Knights that are training. Hopefully, you will see what")
    |> mes("I have seen for a long time...")
    |> set_char_var(:KNGT_SK, 1)
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Essofeit]")
    |> mes("Greetings. I am Essofeit")
    |> mes("Lageiya of the 7th Division")
    |> mes("of the Prontera Chivalry.")
    |> mes("As a proud Knight upholding")
    |> mes("the principles of honor and")
    |> mes("chivalry, I am at your service.")
    |> next()
    |> mes("[Essofeit]")
    |> mes("I only wish the others in")
    |> mes("my division would appreciate")
    |> mes("my values, and the true value")
    |> mes("of spilled blood. They may be")
    |> mes("my comrades, but I find it")
    |> mes("difficult to trust them.")
    |> close()
  end
end
