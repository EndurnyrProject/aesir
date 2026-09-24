defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22e.Soullinker.Kid do
  @moduledoc """
  Maia, disguised as a kid, starts and guides the Soul Linker job quest.

  ## Behavior

  - Soul Linkers and Star Gladiators get a word of encouragement; other non-Taekwon players and
    Taekwon below job level 40 are turned away.
  - Recruits Taekwon of job level 40 or higher and asks for a 3 Carat Diamond, an Immortal
    Heart and a Witherless Rose.
  - Takes the items, then, once all skill points are spent and no other candidate is in the
    ceremony, starts the ceremony timer and sends the candidate into their mind.
  - Lets candidates who already met the spirits re-enter their mind.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celestria
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc_in",
        x: 174,
        y: 30,
        dir: 6,
        sprite: 716,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#link1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: set_npc_var(ctx, "SoulLinkerTest", 0)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    job = Rathena.job_id(class(ctx))

    cond do
      job == Rathena.job_id(:soul_linker) -> wish_soul_linker_luck(ctx)
      job == Rathena.job_id(:star_gladiator) -> greet_star_gladiator(ctx)
      job != Rathena.job_id(:taekwon) -> turn_away(ctx)
      job_level(ctx) < 40 -> encourage_training(ctx)
      job_level(ctx) > 39 -> continue_quest(ctx, get_char_var(ctx, :SOUL_Q, 0))
      true -> ctx
    end
  end

  defp wish_soul_linker_luck(ctx) do
    ctx
    |> mes("[Maia]")
    |> mes("Best of luck in your")
    |> mes("journeys. As you master")
    |> mes("more Soul Linker skills,")
    |> mes("you will be able to draw")
    |> mes("more of the spirits' power")
    |> mes("to endow upon your allies...")
    |> close()
  end

  defp greet_star_gladiator(ctx) do
    ctx = mes(ctx, "[Kid]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx |> mes("Aren't you a warrior") |> mes("of the sun? I'm familiar")
      else
        ctx |> mes("Aren't you a warrior of") |> mes("the moon? I'm familiar")
      end

    ctx
    |> mes("with your ways. After all,")
    |> mes("the basis of both of our")
    |> mes("skills is grounded in the")
    |> mes("Taekwon Do job, right?")
    |> close()
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("Mm? I've got nothing to")
    |> mes("offer you. But if you know")
    |> mes("any well experienced")
    |> mes("practitioners of Taekwon")
    |> mes("Do, they might benefit")
    |> mes("from what I know.")
    |> close()
  end

  defp encourage_training(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("So you're studying")
    |> mes("Taekwon Do. That's good,")
    |> mes("that's very good. Just keep")
    |> mes("refining those skills and")
    |> mes("stick to your training.")
    |> close()
  end

  defp continue_quest(ctx, stage) when stage == 0, do: call_out(ctx)
  defp continue_quest(ctx, stage) when stage == 1, do: check_offerings(ctx)
  defp continue_quest(ctx, stage) when stage == 2, do: begin_ceremony(ctx)
  defp continue_quest(ctx, stage) when stage > 2, do: offer_mind_return(ctx)
  defp continue_quest(ctx, _stage), do: ctx

  defp call_out(ctx) do
    ctx = ctx |> mes("[Kid]") |> mes("...") |> mes("Hey you.") |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Did you call me?")
      |> next()
      |> mes("[Kid]")
      |> mes("Yeah, I called you.")
      |> mes("Now don't make me")
      |> mes("raise my voice, and")
      |> mes("just get over here.")
      |> next()
      |> select(["You're awfully rude for a kid!", "Ignore him."])

    if choice == 1 do
      propose_soul_linker(ctx)
    else
      ctx
      |> mes("[Kid]")
      |> mes("Huh...?")
      |> mes("Wait, where are")
      |> mes("you going? I'm...")
      |> mes("I'm talking to you!")
      |> close()
    end
  end

  defp propose_soul_linker(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kid]")
      |> mes("You're lucky I'm")
      |> mes("taking an interest")
      |> mes("in you! I might look")
      |> mes("like a kid, but I'm over")
      |> mes("three hundred years old!")
      |> emotion(:hng)
      |> next()
      |> mes("[Kid]")
      |> mes("Now listen...")
      |> mes("I know that you're a")
      |> mes("disciple of Taekwon Do.")
      |> mes("It's a respectable art, but")
      |> mes("I've got a proposition for")
      |> mes("you if you want to hear it.")
      |> emotion(:smile)
      |> next()
      |> mes("[Kid]")
      |> mes("I'm looking at you, and I can")
      |> mes("already tell that you're very")
      |> mes("spiritually inclined. You've")
      |> mes("got a lot of potential I don't")
      |> mes("wanna see wasted. Why don't")
      |> mes("you become a ''Soul-Linker?''")
      |> next()
      |> select(["Ha! Silly little boy~", "Soul Linker?"])

    if choice == 1 do
      ctx
      |> mes("[Kid]")
      |> mes("You... You d-don't")
      |> mes("believe me? I'm being")
      |> mes("dead serious. Can you")
      |> mes("forget the fact that I look")
      |> mes("like a little kid for just one")
      |> mes("minute? *Psh* ...Youngsters.")
      |> close()
    else
      explain_soul_linker(ctx)
    end
  end

  defp explain_soul_linker(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kid]")
      |> mes("Soul Linkers communicate")
      |> mes("with spirits of fallen warriors")
      |> mes("that still wish to fight in the")
      |> mes("world of the living. Now, these")
      |> mes("warrior spirits can't fight as")
      |> mes("themselves in our world.")
      |> next()
      |> mes("[Kid]")
      |> mes("However, since you're")
      |> mes("spiritually inclined, these")
      |> mes("spirits are attracted to you.")
      |> mes("With enough training, you can")
      |> mes("temporarily imbue the power of these spirits to your allies.")
      |> next()
      |> mes("[Kid]")
      |> mes("Now, you can't imbue yourself")
      |> mes("with the spirits' power. Also,")
      |> mes("depending on your skills as")
      |> mes("a Soul Linker, you can only")
      |> mes("endow other characters of certain job classes with enchanced power.")
      |> next()
      |> mes("[Kid]")
      |> mes("You'll have to enter")
      |> mes("a wholly different world")
      |> mes("to become a Soul Linker,")
      |> mes("but I know it'll be possible")
      |> mes("for you. So what do you say?")
      |> next()
      |> select(["No. At least, not now...", "Alright. What do I have to do?"])

    if choice == 1 do
      ctx
      |> mes("[Kid]")
      |> mes("Ah, alright. Well,")
      |> mes("if you ever decide to")
      |> mes("become a Soul Linker,")
      |> mes("then please come back")
      |> mes("and talk to me at any time.")
      |> close()
    else
      ctx
      |> set_char_var(:SOUL_Q, 1)
      |> setquest(6005)
      |> mes("[Kid]")
      |> mes("So you want to become")
      |> mes("a Soul Linker? Great!")
      |> mes("Alright, first I need you")
      |> mes("to bring back a few items.")
      |> mes("Don't worry, I'll explain")
      |> mes("why you need them later.")
      |> next()
      |> mes("[Kid]")
      |> mes("Now bring me")
      |> mes("^0000FF1 3 Carat Diamond^000000,")
      |> mes("^0000FF1 Immortal Heart^000000 and")
      |> mes("^0000FF1 Witherless Rose^000000.")
      |> mes("And try not to make me")
      |> mes("wait too long, alright?")
      |> close()
    end
  end

  defp check_offerings(ctx) do
    if Rathena.job_id(class(ctx)) == Rathena.job_id(:taekwon) do
      ask_for_offerings(ctx)
    else
      ctx
      |> set_char_var(:SOUL_Q, 0)
      |> mes("[Kid]")
      |> mes("You've become a warrior")
      |> mes("of the Sun, the Moon and")
      |> mes("the Stars instead? I had no")
      |> mes("idea you had that potential.")
      |> mes("I suppose I can't blame you...")
      |> close()
    end
  end

  defp ask_for_offerings(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kid]")
      |> mes("You're back, eh?")
      |> mes("So did you bring")
      |> mes("^0000FF1 3 Carat Diamond^000000,")
      |> mes("^0000FF1 Immortal Heart^000000 and")
      |> mes("^0000FF1 Witherless Rose^000000.")
      |> mes("like I asked you to?")
      |> next()
      |> select(["There you are.", "No, not yet..."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Kid]")
        |> mes("Mm. That's fine.")
        |> mes("Although I have all")
        |> mes("the time to spare in")
        |> mes("the world, I don't like")
        |> mes("to wait for very long.")
        |> close()

      count_item(ctx, 732) > 0 and count_item(ctx, 929) > 0 and count_item(ctx, 748) > 0 ->
        accept_offerings(ctx)

      true ->
        remind_offerings(ctx)
    end
  end

  defp accept_offerings(ctx) do
    ctx
    |> delitem(732, 1)
    |> delitem(929, 1)
    |> delitem(748, 1)
    |> set_char_var(:SOUL_Q, 2)
    |> changequest(6005, 6006)
    |> mes("[Kid]")
    |> mes("Great, I see that you've")
    |> mes("brought everything. But")
    |> mes("before we begin, let me")
    |> mes("introduce myself. My name")
    |> mes("is Maia, and I've been alive for more than three hundred years.")
    |> next()
    |> mes("[Maia]")
    |> mes("Without giving away too many")
    |> mes("of the details, I've been divinely charged with the duty of finding")
    |> mes("and recruiting more Soul Linkers. That's part of the reason why")
    |> mes("I haven't, you know, passed on.")
    |> next()
    |> mes("[Maia]")
    |> mes("Anyway, I still need to finish")
    |> mes("preparations with the materials")
    |> mes("that you just brought, so would")
    |> mes("you come back in a little bit?")
    |> mes("Then, we'll talk once again.")
    |> close()
  end

  defp remind_offerings(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("Mm...?")
    |> mes("Hey. You forgot")
    |> mes("a few things. Now")
    |> mes("go back and bring")
    |> mes("everything that I ask")
    |> mes("for this time, okay?")
    |> emotion(:hng)
    |> next()
    |> mes("[Kid]")
    |> mes("I know I just told you")
    |> mes("what we need, but I'm")
    |> mes("going to remind you again:")
    |> mes("^0000FF1 3 Carat Diamond^000000,")
    |> mes("^0000FF1 Immortal Heart^000000 and")
    |> mes("^0000FF1 Witherless Rose^000000.")
    |> close()
  end

  defp begin_ceremony(ctx) do
    cond do
      Rathena.truthy?(skill_point(ctx)) ->
        ctx
        |> mes("[Maia]")
        |> mes("You still have some")
        |> mes("unallocated Skill Points.")
        |> mes("Use them all to learn some")
        |> mes("Taekwon Do skills, and then")
        |> mes("return when you're ready.")
        |> close()

      ceremony_in_progress?(ctx) ->
        ask_to_wait_for_ceremony(ctx)

      true ->
        ctx
        |> start_ceremony_timer()
        |> mes("[Maia]")
        |> mes("Great, I've finished")
        |> mes("the preparations. Now")
        |> mes("we'll proceed with the")
        |> mes("ceremony to change")
        |> mes("you into a Soul Linker.")
        |> mes("Now close your eyes...")
        |> close()
        |> warp("job_soul", 30, 30)
    end
  end

  defp offer_mind_return(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Maia]")
      |> mes("Are you ready to")
      |> mes("enter the depths")
      |> mes("of your mind again?")
      |> next()
      |> select(["No", "Yes"])

    cond do
      choice == 1 ->
        ctx
        |> mes("[Maia]")
        |> mes("Well then, come")
        |> mes("back to me when you")
        |> mes("think you are ready.")
        |> mes("Until then, I'll be")
        |> mes("waiting right here.")
        |> close()

      ceremony_in_progress?(ctx) ->
        ask_to_wait_for_ceremony(ctx)

      true ->
        ctx
        |> start_ceremony_timer()
        |> mes("[Maia]")
        |> mes("Alright then, close")
        |> mes("your eyes and relax.")
        |> mes("We'll go back into the")
        |> mes("depths of your mind.")
        |> close()
        |> warp("job_soul", 30, 30)
    end
  end

  defp ceremony_in_progress?(ctx), do: get_npc_var(ctx, "SoulLinkerTest", 0) == 1

  defp start_ceremony_timer(ctx) do
    ctx
    |> donpcevent("Timer#link3::OnEnable")
    |> set_npc_var("SoulLinkerTest", 1)
  end

  defp ask_to_wait_for_ceremony(ctx) do
    ctx
    |> mes("[Maia]")
    |> mes("Right now, someone else")
    |> mes("is completing the ceremony")
    |> mes("to become a Soul Linker.")
    |> mes("Would you please wait until")
    |> mes("it's finished? Then, when I'm")
    |> mes("available, I'll attend to you.")
    |> close()
  end
end
