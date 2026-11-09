defmodule Aesir.ZoneServer.Content.Npc.Quests.ObbQuest.Jacob do
  @moduledoc """
  Jacob asks adventurers to help calm Tommy before sharing a lead about Elder Creek.

  ## Behavior

  - Accepts the introduction from Pandger Mayer and requests a No Recipient.
  - Responds to the adventurer reassuring or upsetting Tommy about catching a Munak.
  - Shares his family story and eventually directs the adventurer to Elder Creek.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celesta
    - Lupus
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/obb_quest.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 105,
        y: 62,
        dir: 4,
        sprite: 50,
        name: "Jacob",
        scope: :shared,
        unique_name: "Jacob#thai"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :thai_head, 0) do
      6 -> meet_jacob(ctx)
      7 -> bring_no_recipient(ctx)
      8 -> seek_forgiveness(ctx)
      9 -> hear_family_story(ctx)
      10 -> ask_about_sage(ctx)
      11 -> recall_sage(ctx)
      stage when stage > 11 -> family_aftermath(ctx)
      _ -> idle_family(ctx)
    end
  end

  defp meet_jacob(ctx) do
    {ctx, introduction} =
      ctx
      |> mes("[Tommy]")
      |> mes("Wahhhh~~~!!")
      |> mes("Dad~~ let me have a Munak~~~!")
      |> mes("Waaahhhh!")
      |> next()
      |> mes("[Tommy]")
      |> mes("I want Munak, Munakkkk~~!!")
      |> mes("Other people have a Munak, why can't I~~?")
      |> next()
      |> mes("[Tommy]")
      |> mes("Munak Munak Munak Munak~~~!")
      |> next()
      |> mes("[Jacob]")
      |> mes("Er...Ummm...")
      |> next()
      |> mes("[Tommy]")
      |> mes("Munak Munak Munak Munak~~~!")
      |> next()
      |> mes("[Jacob]")
      |> mes("Tommy, daddy is kind of busy right now...")
      |> next()
      |> mes("[Tommy]")
      |> mes("Munak Munak Munak Munak~~~!")
      |> next()
      |> mes("[Jacob]")
      |> mes("*Sigh*...alright...alright. If you want it that bad...")
      |> next()
      |> mes("[Jacob]")
      |> mes("Gosh...being a dad is not an easy")
      |> mes("thing to do...Hmmm? Do you have any business with me?")
      |> mes(" ")
      |> mes("[Tommy]")
      |> mes("^FF0000Munak Munak Munak Munak!!^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", introduction)

    if get_local(ctx, :"input$", "") != "Pandger Mayer introduced you" do
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("#{get_local(ctx, :"input$", "")}")
      |> next()
      |> mes("[Jacob]")
      |> mes("....Sorry, what did you say? I have no idea what you're talking about.")
      |> close()
    else
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Pandger Mayer introduced you.")
      |> next()
      |> mes("[Jacob]")
      |> mes("Oh, you mean that guy in love?")
      |> mes("Last time I saw him, he was")
      |> mes("leaving to find cookies somewhere...")
      |> next()
      |> mes("[Jacob]")
      |> mes("There is only one reason he could have mentioned my name to you...")
      |> mes(" ")
      |> mes(" ")
      |> mes("[Tommy]")
      |> mes("^FF0000Munak Munak Munak Munak!!^000000")
      |> next()
      |> mes("[Jacob]")
      |> mes("......")
      |> mes("*Sigh* For now, I have a favor to")
      |> mes("ask of you. Could you bring me")
      |> mes("^0000FF1 No Recipient^000000?")
      |> set_char_var(:thai_head, 7)
      |> next()
      |> mes("[Jacob]")
      |> mes("I need this kid to calm down first...")
      |> mes(" ")
      |> mes(" ")
      |> mes("[Tommy]")
      |> mes("^FF0000Munak Munak Munak Munak!!^000000")
      |> close()
    end
  end

  defp bring_no_recipient(ctx) do
    if count_item(ctx, 636) > 0 do
      calm_tommy(ctx)
    else
      ctx
      |> mes("[Tommy]")
      |> mes("^FF0000Munak Munak Munak Munak!!^000000")
      |> next()
      |> mes("[Jacob]")
      |> mes("*Sigh*...that's my boy. Please get me a No Recipient as soon as you can!")
      |> close()
    end
  end

  defp seek_forgiveness(ctx) do
    if Enum.random(1..1000) == 792 do
      ctx
      |> mes("[Tommy]")
      |> mes("^FF0000Munak Munak Munak Munak!!^000000")
      |> next()
      |> mes("[Jacob]")
      |> mes("....*Sigh* Okay.")
      |> mes("I will give you a chance")
      |> mes("to make up for your mistake.")
      |> mes("Please get me a No Recipient as soon as you can.")
      |> set_char_var(:thai_head, 7)
      |> close()
    else
      ctx
      |> mes("[Jacob]")
      |> mes("....I don't want to talk to YOU")
      |> mes("anymore. Get outta here~!")
      |> mes("It's your fault my little")
      |> mes("boy thinks I'm a big liar!")
      |> close()
    end
  end

  defp hear_family_story(ctx) do
    ctx =
      ctx
      |> mes("[Jacob]")
      |> mes("*Phew* Now I can leave him alone.")
      |> mes("Kids nowadays are so impatient...I am worried about my son.")
      |> next()
      |> mes("[Jacob]")
      |> mes("However, I can't do anything")
      |> mes("about his temper...I think")
      |> mes("he's just too young to know")
      |> mes("what he's doing.")
      |> next()
      |> mes("[Jacob]")
      |> mes("I'm having a hard time trying to")
      |> mes("be a good parent, and I'm")
      |> mes("beginning to appreciate my")
      |> mes("own parents' efforts to raise me.")
      |> next()
      |> mes("[Jacob]")
      |> mes("Respect your parents while they're")
      |> mes("still alive. It's too late to be")
      |> mes("sorry after you've lost them.")
      |> next()
      |> mes("[Jacob]")
      |> mes("I was a wild kid as well...my")
      |> mes("parents had a hard time raising")
      |> mes("me. I'm ashamed of what I've done")
      |> mes("when I was young...")
      |> next()
      |> mes("[Jacob]")
      |> mes("Those days, my parents couldn't")
      |> mes("afford to feed me three meals a")
      |> mes("day. And there were many")
      |> mes("creditors that always came")
      |> mes("to our house early")
      |> mes("early in the morning.")
      |> next()
      |> mes("[Jacob]")
      |> mes("Have you every heard about")
      |> mes("distraint-papers? As soon")
      |> mes("as those creditors put that")
      |> mes("distraint-paper on any of my")
      |> mes("things,it would no longer be")
      |> mes("mine.")
      |> next()
      |> mes("[Jacob]")
      |> mes("I hated my parents for not providing me with a sweet home,")
      |> mes("and I became rebellious.")
      |> mes("But, no matter how bad I was,")
      |> mes("Even in those difficult circumstances...")
      |> next()
      |> mes("[Jacob]")
      |> mes("They never gave up on me.")
      |> mes("Later, they told me that I was their one and only hope...")
      |> mes("even though I was more of a burden than anything else at the moment.")
      |> next()
      |> mes("[Tommy]")
      |> mes("Daddy, do you realize you've told")
      |> mes("that story hundreds of times already? *Piff~*")
      |> mes("Stop it already~")
      |> next()
      |> mes("^3355FFTommy was jumping and running")
      |> mes("around like a crazy rabbit and")
      |> mes("eventually bumped against me.^000000")
      |> next()
      |> mes("[Jacob]")
      |> mes("...Tommy, respect your dad.")
      |> mes("This is the story of your father's life.")
      |> next()
      |> mes("[Jacob]")
      |> mes("A.aa.aand.!!!")
      |> next()
      |> mes("[Jacob]")
      |> mes("How many times have I told you")
      |> mes("to behave in front of other people?!")
      |> next()
      |> mes("[Jacob]")

    ctx =
      if sex(ctx) == 1 do
        mes(ctx, "Say you're sorry to him!")
      else
        mes(ctx, "Say you're sorry to her!")
      end

    ctx
    |> next()
    |> mes("[Tommy]")
    |> mes("*Piff~*")
    |> next()
    |> mes("[Jacob]")
    |> mes("I don't hear it~!!")
    |> next()
    |> mes("[Tommy]")
    |> mes("...I'm sorry...*bows head*")
    |> set_char_var(:thai_head, 10)
    |> close()
  end

  defp ask_about_sage(ctx) do
    ctx = set_local(ctx, :rem, Enum.random(1..11))

    cond do
      get_local(ctx, :rem, 0) == 1 ->
        ctx
        |> mes("[Jacob]")
        |> mes("Ah~ yes! Didn't you say Pandger Mayer introduced me to you?")
        |> mes("He wouldn't introduce me to just anyone. Oh, you must be")
        |> mes("...an adventurer.")
        |> next()
        |> mes("[Jacob]")
        |> mes("Right.")
        |> mes("I have something to tell you.")
        |> next()
        |> mes("[Jacob]")
        |> mes("When you go west from Morocc, and")
        |> mes("pass through a cave, you will")
        |> mes("arrive at a town called Comodo.")
        |> next()
        |> mes("[Jacob]")
        |> mes("When you get there, you will see an old man named ^0000FFElder Creek^000000.")
        |> mes("As a Sage, he has gained the respect of many.")
        |> next()
        |> mes("[Jacob]")
        |> mes("People say that many adventurers")
        |> mes("are visiting this man for some")
        |> mes("reason. Why don't you go talk to him and see if he has some wisdom for you?")
        |> set_char_var(:thai_head, 11)
        |> close()

      get_local(ctx, :rem, 0) > 1 and get_local(ctx, :remrem, 0) < 7 ->
        ctx =
          ctx
          |> mes("[Jacob]")
          |> mes("Respect your parents when they're")
          |> mes("still alive. It's too late to be sorry after you've lost them.")
          |> next()

        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("(Hmmm...I just know that there's more that this guy can tell me...)")
        |> close()

      true ->
        ctx =
          ctx
          |> mes("[Jacob]")
          |> mes("When you have a kid,")
          |> mes("don't forget to teach them")
          |> mes("this one thing:")
          |> next()
          |> mes("[Jacob]")
          |> mes("'^0000FFBe good to other people.^000000'")
          |> mes("'^0000FFTry to be in someone else's shoes before judging that person.^000000'")
          |> mes("Do you understand?")
          |> next()

        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("(There's more this guy can tell me, I just know it...)")
        |> close()
    end
  end

  defp recall_sage(ctx) do
    ctx
    |> mes("[Jacob]")
    |> mes("Now, why don't you visit the Sage?")
    |> mes("And I thank you for your kindness.")
    |> next()
    |> mes("[Jacob]")
    |> mes("He's in Comodo, if you didn't")
    |> mes("catch that. An adventurer like you should be able to get there with no problem.")
    |> close()
  end

  defp family_aftermath(ctx) do
    ctx
    |> mes("[Jacob]")
    |> mes("Thank you for the favour you did")
    |> mes("for me...although we couldn't")
    |> mes("catch a Munak in the end...")
    |> next()
    |> mes("[Jacob]")
    |> mes("It seems he learned something")
    |> mes("through the experience.")
    |> mes("He no longer demands something")
    |> mes("I cannot do for him, or")
    |> mes("misbehaves.")
    |> next()
    |> mes("[Jacob]")
    |> mes("That was another favor you did for me, even if you didn't mean to. Thank you.")
    |> close()
  end

  defp idle_family(ctx) do
    ctx
    |> mes("[Jacob]")
    |> mes("*Yawns*....")
    |> mes("Today is such a boring day~.")
    |> mes("I guess I'd better go take a walk")
    |> mes("with my son. Do you want to walk with me?")
    |> next()
    |> mes("[Jacob's son]")
    |> mes("I'm happy to hear that, daddy~")
    |> close()
  end

  defp calm_tommy(ctx) do
    ctx =
      ctx
      |> delitem(636, 1)
      |> mes("[Tommy]")
      |> mes("^FF0000Munak Munak Munak Munak!!^000000")
      |> next()
      |> mes("[Jacob]")
      |> mes("Oh, thank you so much...")
      |> mes("Let me calm this kid down")
      |> mes("first. Sorry my little boy is being so loud.")
      |> next()
      |> mes("[Jacob]")
      |> mes("Tommy, Tommy?")
      |> next()
      |> mes("[Tommy]")
      |> mes("^FF0000Moo^9F0000naah^5F0000ahhh^3F0000ahhh^000000kkk!!..Err?")
      |> mes("What's this, Daddy?")
      |> next()
      |> mes("[Jacob]")
      |> mes("This is called No Recipient~")
      |> mes("With this, I can get you a Munak~")
      |> next()
      |> mes("[Tommy]")
      |> mes("Are you serious, Daddy?!")
      |> next()
      |> mes("[Jacob]")
      |> mes("Yes, I am~")
      |> mes("Have you ever heard me lie?")
      |> next()
      |> mes("[Tommy]")
      |> mes(".......")
      |> mes("I know you always lie to Mommy.")
      |> next()
      |> mes("[Jacob]")
      |> mes("..........")
      |> mes("No no no no no...that's not")
      |> mes("considered lying, Tommy.")
      |> mes("I am just trying to make it sound better to Mommy~")
      |> next()
      |> mes("[Tommy]")
      |> mes(".......")
      |> next()
      |> mes("^3355FFHe looks at his father in")
      |> mes("doubt. Kids are too smart")
      |> mes("to lie to nowadays...^000000")
      |> next()
      |> mes("[Tommy]")

    ctx =
      if sex(ctx) == 1 do
        mes(ctx, "So, mister, do you think my Daddy can catch a Munak with this?")
      else
        mes(ctx, "So, lady, do you think my Daddy can catch a Munak with this?")
      end

    {ctx, answer} = ctx |> next() |> select(["Yes.", "...not sure.", "No, ^FF0000never^000000."])
    answer_tommy(ctx, answer)
  end

  defp clarify_munak(ctx) do
    ctx = mes(ctx, "[Tommy]")

    ctx =
      if sex(ctx) == 1 do
        mes(ctx, "So tell me, mister. Did he lie to me, then?")
      else
        mes(ctx, "So tell me, lady. Did he lie to me, then?")
      end

    {ctx, certainty} =
      ctx
      |> next()
      |> mes("[Jacob]")
      |> mes("Wait...wait, Tommy, that's not true...")
      |> mes("(^0000FFGosh, why are you doing this to me, help me already!!^000000)")
      |> next()
      |> mes("[Tommy]")
      |> mes("Can we catch a Munak with this or")
      |> mes("not, huh? Tell meeeeehhhh~~~!")
      |> next()
      |> select(["Yes, we can.", "No, we can't."])

    settle_doubt(ctx, certainty)
  end

  defp answer_tommy(ctx, 1) do
    ctx
    |> mes("[Tommy]")
    |> mes("Heh!! I knew my Daddy")
    |> mes("wouldn't tell me a lie!! Thank you!!")
    |> next()
    |> mes("[Jacob]")
    |> mes("(...*Phew!* Thank you~)")
    |> set_char_var(:thai_head, 9)
    |> close()
  end

  defp answer_tommy(ctx, 2) do
    clarify_munak(ctx)
  end

  defp answer_tommy(ctx, 3) do
    ctx
    |> set_char_var(:thai_head, 8)
    |> mes("[Tommy]")
    |> mes("I knew it!! Daddy, you're a liar!!")
    |> next()
    |> mes("[Tommy]")
    |> mes("I hate you...I hate you!!!")
    |> mes("I wish Baphomet will take you somewhere and eat you!!")
    |> next()
    |> mes("[Jacob]")
    |> mes("Shoot...Tommy, Tommy...")
    |> mes("Listen to me....")
    |> next()
    |> mes("[Tommy]")
    |> mes("I don't wanna listen to you!!!")
    |> mes("I hate yoooooouhhhh!!")
    |> next()
    |> mes("[Jacob]")
    |> mes("....You.")
    |> next()
    |> mes("[Jacob]")
    |> mes("I don't want to see")
    |> mes("your ugly face any more.")
    |> mes("Leave!")
    |> mes("How could you do this to me, huh?")
    |> next()
    |> mes("[Tommy]")
    |> mes("I hate yoooooouhhhh!!")
    |> mes("[Jacob]")
    |> mes("Tommy...Tommy, please...")
    |> mes("Will you let me explain...?")
    |> set_char_var(:thai_head, 8)
    |> close()
  end

  defp answer_tommy(ctx, _) do
    ctx
  end

  defp settle_doubt(ctx, 1) do
    ctx
    |> mes("[Tommy]")
    |> mes("Heh heh! I knew it!")
    |> mes("Thank you~!!!")
    |> next()
    |> mes("[Tommy]")
    |> mes("Now I can have a Munak!")
    |> next()
    |> mes("[Jacob]")
    |> mes("(...*Phew* Thank you~)")
    |> set_char_var(:thai_head, 9)
    |> close()
  end

  defp settle_doubt(ctx, 2) do
    ctx
    |> set_char_var(:thai_head, 8)
    |> mes("[Tommy]")
    |> mes("I knew it!! Daddy, you're a liar!!")
    |> next()
    |> mes("[Tommy]")
    |> mes("I hate you...I hate you!!!")
    |> mes("I wish Baphomet would take you somewhere and eat you!!")
    |> next()
    |> mes("[Jacob]")
    |> mes("Shoot...Tommy, Tommy...")
    |> mes("Listen to me....")
    |> next()
    |> mes("[Tommy]")
    |> mes("I don't wanna listen to you!!!")
    |> mes("I hate yoooooouhhhh!!")
    |> next()
    |> mes("[Jacob]")
    |> mes("....You.")
    |> next()
    |> mes("[Jacob]")
    |> mes("I don't want to see your ugly face")
    |> mes("around here any more...")
    |> mes("Leave~!")
    |> mes("How could you do this to me, huh?")
    |> next()
    |> mes("[Tommy]")
    |> mes("I hate yoooooouhhhh!!")
    |> mes(" ")
    |> mes(" ")
    |> mes("[Jacob]")
    |> mes("Tommy...Tommy please...")
    |> mes("Will you let me explain...?")
    |> set_char_var(:thai_head, 8)
    |> close()
  end

  defp settle_doubt(ctx, _) do
    ctx
  end
end
