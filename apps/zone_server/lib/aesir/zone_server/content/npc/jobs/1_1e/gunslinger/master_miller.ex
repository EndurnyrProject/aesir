defmodule Aesir.ZoneServer.Content.Npc.Jobs.M11e.Gunslinger.MasterMiller do
  @moduledoc """
  Master Miller, the drillmaster who starts and completes the Gunslinger job quest.

  ## Behavior

  - Sends Novices who meet the job change requirements to Wise Bull Horn with a letter.
  - Comments on the applicant's progress through Wise Bull Horn's tests.
  - Changes voucher holders with no unused skill points to Gunslinger and gives a starter
    weapon: a Gun with Bullets in renewal, or a random Gun in pre-renewal.
  - Turns away baby classes and greets Gunslingers and other classes.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - RockmanEXE
    - Kisuka
    - Lupus
    - CBMaster
    - KarLaeda
    - Playtester
    - ultramage
    - SinSloth
    - L0ne_W0lf
    - Samuray22

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "que_ng", x: 152, y: 167, dir: 3, sprite: 901, name: "Master Miller", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      upper(ctx) == 2 ->
        ctx
        |> mes("[Master Miller]")
        |> mes("Well, aren't you an")
        |> mes("adorable little child~")
        |> mes("Where's your mommy?")
        |> mes("This place is dangerous, so")
        |> mes("please go home soon, okay?")
        |> close()

      Rathena.job_id(class(ctx)) == Rathena.job_id(:novice) ->
        talk_to_novice(ctx)

      Rathena.job_id(class(ctx)) == Rathena.job_id(:gunslinger) ->
        ctx
        |> mes("[Master Miller]")
        |> mes("Oh! Long time, no see,")
        |> mes("friend. How have you been?")
        |> mes("I hope you've been keeping")
        |> mes("you Gun well maintained.")
        |> mes("Take care of it, and it'll take")
        |> mes("care of you. Remember it.")
        |> close()

      true ->
        ctx
        |> mes("[Master Miller]")
        |> mes("If you don't have")
        |> mes("any business with me,")
        |> mes("then please go on your way.")
        |> close()
    end
  end

  defp talk_to_novice(ctx) do
    if can_change_job?(ctx) do
      quest_progress(ctx, get_char_var(ctx, :GUNS_Q, 0))
    else
      ctx
      |> mes("[Master Miller]")
      |> mes("Interested in becoming")
      |> mes("a Gunslinger, eh? You've")
      |> mes("got potential, but you're")
      |> mes("not yet experienced enough.")
      |> mes("Just train yourself a bit more,")
      |> mes("and then come back, you hear?")
      |> close()
    end
  end

  defp quest_progress(ctx, 0), do: offer_application(ctx)

  defp quest_progress(ctx, 1) do
    ctx
    |> mes("[Master Miller]")
    |> mes("Take that letter of")
    |> mes("introduction I've written")
    |> mes("for you to Mr. Wise Bull")
    |> mes("Horn in Payon. He'll test")
    |> mes("you to see if you're really")
    |> mes("Gunslinger material.")
    |> close()
  end

  defp quest_progress(ctx, 2) do
    ctx
    |> mes("[Master Miller]")
    |> mes("Hmm... Wise Bull Horn")
    |> mes("asked you to collect the")
    |> mes("items you need to make the")
    |> mes("voucher? Hm. I guess that's")
    |> mes("part of his qualification test.")
    |> close()
  end

  defp quest_progress(ctx, 3) do
    ctx
    |> mes("[Master Miller]")
    |> mes("Wise Bull Horn asked")
    |> mes("you to bring him some")
    |> mes("Milk? He must really like")
    |> mes("you if he's already asking")
    |> mes("for favors. Good luck, friend.")
    |> close()
  end

  defp quest_progress(ctx, 4) do
    ctx
    |> mes("[Master Miller]")
    |> mes("I expect to hear good")
    |> mes("news from you soon. You")
    |> mes("know, I have no doubt that")
    |> mes("you'll become a Gunslinger.")
    |> close()
  end

  defp quest_progress(ctx, 5) do
    if skill_point(ctx) != 0 do
      ctx
      |> mes("[Master Miller]")
      |> mes("Hey, you have leftover")
      |> mes("Skill Points. You better")
      |> mes("use them all up before you")
      |> mes("come and talk to me again.")
      |> close()
    else
      change_to_gunslinger(ctx)
    end
  end

  defp quest_progress(ctx, _step), do: ctx

  defp offer_application(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Master Miller]")
      |> mes("I'm Miller, a full time")
      |> mes("Gunslinger drillmaster, and")
      |> mes("full time guardian for Lady")
      |> mes("Selena. Now, what do you")
      |> mes("need? If it's not important, then I can't make the time for you.")
      |> next()
      |> select(["Nothing.", "I want to become a Gunslinger."])

    if choice == 1 do
      ctx
      |> mes("[Master Miller]")
      |> mes("Don't waste my time.")
      |> mes("If you do want to become")
      |> mes("a Gunslinger, then come")
      |> mes("back and talk to me.")
      |> close()
    else
      confirm_application(ctx)
    end
  end

  defp confirm_application(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Master Miller]")
      |> mes("Hm. You're pretty young, but")
      |> mes("your eyes tell me that you're")
      |> mes("pretty ambitious. You'll need to pass our interview and educational")
      |> mes("course to become a Gunslinger. Do you want to apply for the job?")
      |> next()
      |> select(["Give me some time to think.", "Sure!"])

    if choice == 1 do
      ctx
      |> mes("[Master Miller]")
      |> mes("Understandable.")
      |> mes("If you do decide that")
      |> mes("you want to become")
      |> mes("a Gunslinger, then let")
      |> mes("me know right away.")
      |> mes("I'll get you started.")
      |> close()
    else
      ctx
      |> mes("[Master Miller]")
      |> mes("Great, great. Alright then,")
      |> mes("let's get you started. Take")
      |> mes("this letter to Mr. Wise Bull")
      |> mes("Horn in Payon. He's a shaman")
      |> mes("that will judge whether or not")
      |> mes("you qualify to be a Gunslinger.")
      |> set_char_var(:GUNS_Q, 1)
      |> setquest(6020)
      |> close()
    end
  end

  defp change_to_gunslinger(ctx) do
    ctx
    |> mes("[Master Miller]")
    |> mes("Oh, you've brought a")
    |> mes("voucher from Wise Bull Horn?")
    |> mes("It's been a while since he's")
    |> mes("given one to anybody, so")
    |> mes("I'm really proud of you!")
    |> next()
    |> mes("[Master Miller]")
    |> mes("If Wise Bull Horn approves,")
    |> mes("then I have no reason to")
    |> mes("reject you. Alright then, I'll")
    |> mes("promote you to a Gunslinger.")
    |> mes("But first, let me explain")
    |> mes("our job in more detail.")
    |> next()
    |> mes("[Master Miller]")
    |> mes("As a Gunslinger, you must")
    |> mes("keep your gun with you at")
    |> mes("all times. The Gunslinger")
    |> mes("Guild keeps track of every Gun")
    |> mes("and Bullet, so you can only get")
    |> mes("them from our guild members.")
    |> next()
    |> mes("[Master Miller]")
    |> mes("Don't worry, Gunslinger")
    |> mes("Guildsmen can be found almost")
    |> mes("anywhere these days. Anyway,")
    |> mes("it has to be this way by order of our guild leader, Lady Selena.")
    |> next()
    |> mes("[Master Miller]")
    |> mes("You might get the chance to")
    |> mes("meet her one of these days.")
    |> mes("Anyway, just now that we have")
    |> mes("to regulate Gun and Bullet sales to keep them away from evil")
    |> mes("or irresponsible folk.")
    |> next()
    |> mes("[Master Miller]")
    |> mes("In any case, it's always")
    |> mes("a pleasure for me to talk")
    |> mes("to another Gunslinger, so")
    |> mes("let's keep in touch. May the")
    |> mes("power of the earth protect")
    |> mes("you in all of your adventures~")
    |> jobchange(:gunslinger)
    |> set_char_var(:GUNS_Q, 6)
    |> completequest(6024)
    |> give_starter_weapon()
    |> close()
  end

  defp give_starter_weapon(ctx) do
    cond do
      Rathena.truthy?(checkre(ctx, 0)) ->
        ctx
        |> give_item(13_180, 1)
        |> give_item(12_149, 2)
        |> give_item(12_151, 1)

      Rathena.truthy?(:rand.uniform(2) - 1) ->
        give_item(ctx, 13_100, 1)

      true ->
        give_item(ctx, 13_150, 1)
    end
  end
end
