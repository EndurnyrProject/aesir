defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.NoviceSkills.ChivalryMember do
  @moduledoc """
  Bulma, a young Prontera knight, teaches the Play Dead quest skill to Novices.

  ## Behavior

  - Talks only with Novices and Baby Novices above Job Level 6 who have learned First Aid from
    Nami; reminisces about his novice years with everyone else.
  - Sends the player on a timed run to fetch a Newbie Tag from the castle's east wing.
  - Teaches Play Dead in exchange for the Newbie Tag, or restarts the run when it is missing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - IVBela
    - L0ne_W0lf
    - Masao
    - Zopokx

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "prt_in", x: 73, y: 87, dir: 4, sprite: 65, name: "Chivalry Member", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @play_dead 143
  @newbie_tag 7039

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if eligible?(ctx) do
      ctx
      |> mes("[Bulma]")
      |> mes("Yeah. . . I look great. . .")
      |> mes("I am a knight in the knight's")
      |> mes("guild of Prontera! Kuhahhahhahah !!")
      |> mes("It hasn't been long since I became a")
      |> mes(" knight, but I still look great huh?")
      |> mes("What do you think? ? ?")
      |> next()
      |> quest_step(get_char_var(ctx, :skill_nov, 0))
    else
      reminisce(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp eligible?(ctx) do
    (Rathena.job_id(class(ctx)) == Rathena.job_id(:novice) or
       Rathena.job_id(class(ctx)) == Rathena.job_id(:baby)) and job_level(ctx) > 6 and
      get_char_var(ctx, :skill_nov, 0) in 3..5
  end

  defp quest_step(ctx, 3), do: start_training(ctx)
  defp quest_step(ctx, 4), do: hurry_up(ctx)
  defp quest_step(ctx, 5), do: check_tag(ctx)

  defp start_training(ctx) do
    ctx
    |> mes("[Bulma]")
    |> mes("Hello my young friend -")
    |> mes("You remind me of myself as young")
    |> mes("sword man. . . ")
    |> mes("Kekekkek, Oh I miss those days . .")
    |> mes("Look at me acting like an old man.")
    |> mes("Heh heh Sorry...")
    |> next()
    |> mes("[Bulma]")
    |> mes("I'm still young!!! Aren't I???")
    |> mes("If you just work hard and be patient,")
    |> mes("you will soon receive the job you desire as well.")
    |> mes("It takes patience, but this is")
    |> mes("good life kekkeke")
    |> mes("Hmm, I would like to help you out . .")
    |> next()
    |> mes("[Bulma]")
    |> mes(". . . . . I'm not sure why you are looking")
    |> mes("at me like that. I assure you that this")
    |> mes("might seem a little weird at first, but")
    |> mes("what I tell you will most likely be a great aid to you..")
    |> next()
    |> mes("[Bulma]")
    |> mes("Ha ha... It looks like you are getting")
    |> mes("a bit interested in what I have to say.")
    |> mes("I can teach you a very useful skill!")
    |> mes("This skill is acting like you are dead! '")
    |> mes("No No, it is more than acting, you ")
    |> mes("actually look dead!!! ..")
    |> next()
    |> mes("[Bulma]")
    |> mes("The name of the skill is ^3355FF' Play Dead '^000000")
    |> mes("It is a skill I used as a novice.")
    |> mes("But don't think little of it because")
    |> mes("it is a novice skill. In fact, it takes")
    |> mes("extreme concentration and skill")
    |> mes("to even make this skill pass as believable.")
    |> next()
    |> mes("[Bulma]")
    |> mes("For example,")
    |> mes("What if you are attacked by a strong")
    |> mes("monster and can't survive.")
    |> mes("You must play dead!")
    |> mes("But if the monster was to tickle you,")
    |> mes("could you control yourself?")
    |> next()
    |> mes("[Bulma]")
    |> mes("The skill will help you deal with")
    |> mes("many situations such as this.")
    |> mes("It is truly a skill for the strong minded.")
    |> mes("The goal of the skill is to look")
    |> mes("perfectly dead. . .")
    |> next()
    |> mes("[Bulma]")
    |> mes("I think that's enough explanation.")
    |> mes("I can tell by the look in your eyes")
    |> mes("that you are ready for your training.")
    |> mes("Lets not delay!")
    |> mes("Ok, take this pill first. . .")
    |> mes("Let's see how this goes. . .")
    |> next()
    |> mes("[Bulma]")
    |> mes("Within in 10 minutes, you must")
    |> mes("go to the 2nd floor of the Prontera Castle's")
    |> mes("East wing. ^3355FF' Newbie Tag '^000000 is")
    |> mes("the item you are seeking. ! . .")
    |> next()
    |> mes("^3355FF- *Gulp* (You have swallowed the pill) -^000000")
    |> next()
    |> mes("[Bulma]")
    |> mes("The pill that you have just taken")
    |> mes("will make it difficult for you to breathe. . .")
    |> mes("Kekekk . .AH HA - Just joking !")
    |> mes("It is actually a pill to gives you")
    |> mes("a mental calm so you can be patient.")
    |> mes("I think that nothing is better")
    |> next()
    |> mes("[Bulma]")
    |> mes("training than running.")
    |> mes("Okay? GO! ! ! ! ~~~~~")
    |> mes("If you are late, you have to do it again! !")
    |> mes("Now GO ! GO ! GO !")
    |> mes("Run ~~~~~!!!!")
    |> set_char_var(:skill_nov, 4)
    |> close()
  end

  defp hurry_up(ctx) do
    ctx
    |> mes("[Bulma]")
    |> mes("HEY! what are you doing here ? !")
    |> mes("You must be very irresponsible to be")
    |> mes("here when your time is running out.")
    |> mes("Run Run Run! - - - - -")
    |> next()
    |> mes("[Bulma]")
    |> mes("On the 2nd floor of the east wing!")
    |> mes("It's in the Prontera castle!")
    |> mes("Okayyyyy~~~!! *waves goodbye*")
    |> close()
  end

  defp check_tag(ctx) do
    if count_item(ctx, @newbie_tag) > 0, do: teach(ctx), else: restart(ctx)
  end

  defp teach(ctx) do
    ctx
    |> mes("[Bulma]")
    |> mes("Hey... I see that you have -")
    |> mes("finished your quest! ! ! . .")
    |> mes("If you can endure all this,")
    |> mes("it shouldn't be a problem to use")
    |> mes("this skill. You are a natural!")
    |> next()
    |> mes("[Bulma]")
    |> mes("Now, if you ever feel threatened,")
    |> mes("use this skill as you see fit.")
    |> mes(" ' Play Dead ' ")
    |> mes("Okay okay, See you around ! ! !")
    |> set_char_var(:skill_nov, 6)
    |> delitem(@newbie_tag, 1)
    |> skill(@play_dead, 1, :permanent)
    |> close()
  end

  defp restart(ctx) do
    ctx
    |> mes("[Bulma]")
    |> mes("What? -")
    |> mes("Why haven't you finished your quest?")
    |> mes(" *Tsk* *Tsk* You must have lost the pass . . .")
    |> mes("Such irresponsibility is not acceptable.")
    |> mes("I can't accept you into training until")
    |> mes("I know you are capable. Go and try again.")
    |> next()
    |> mes("[Bulma]")
    |> mes("Don't take me lightly. . .")
    |> mes("If I tell you to come in 10 minutes,")
    |> mes("I expect that of you.")
    |> mes("In order for you to have another chance,")
    |> mes("you must start from the beginning. . .")
    |> mes("Do it right this time ! ! ! !")
    |> set_char_var(:skill_nov, 4)
    |> close()
  end

  defp reminisce(ctx) do
    ctx
    |> mes("[Bulma]")
    |> mes("Yeah... I remember back to long ago !")
    |> mes("Especially those embarrassing Novice years.")
    |> mes("Wow... It is funny to think about those years now.")
    |> mes("Those years were difficult. . .")
    |> mes("Thankfully you can use the First Aid")
    |> mes("skill when you reach novice job level 7.")
    |> next()
    |> mes("[Bulma]")
    |> mes("That saved me many times in the past. . .")
    |> mes("I am sure it will help you much as well.")
    |> mes("Hopefully, it will be something you use well . .")
    |> next()
    |> mes("[Bulma]")
    |> mes("If you have any friends who are novices,")
    |> mes("tell them about me.")
    |> mes("If I can, I will help them out")
    |> mes("as best as I can . . . .")
    |> close()
  end
end
