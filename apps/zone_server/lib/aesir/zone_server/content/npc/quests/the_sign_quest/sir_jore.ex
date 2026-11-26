defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.SirJore do
  @moduledoc """
  Researches the secret of life and tests visitors seeking Sobbing Starlight.

  ## Behavior

  - Meets visitors in the evening and requests materials for his research.
  - Sends qualified visitors to investigate the Stone of Sage and rewards their answer.
  - Is preoccupied during the day and sleeps at night.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 155,
        y: 101,
        dir: 3,
        sprite: 805,
        name: "Sir Jore",
        scope: :shared,
        unique_name: "Sir Jore#sign",
        trigger: {7, 7}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    cond do
      gettime(ctx, 3) > 16 and gettime(ctx, 3) < 22 -> evening(ctx)
      gettime(ctx, 3) > 6 and gettime(ctx, 3) < 17 -> daytime(ctx)
      true -> ctx |> mes("[Sir Jore]") |> mes("...z...z...Z") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp evening(ctx) do
    cond do
      get_char_var(ctx, :sign_q, 0) == 15 -> first_meeting(ctx)
      get_char_var(ctx, :sign_q, 0) == 16 -> research_materials(ctx)
      get_char_var(ctx, :sign_q, 0) == 17 -> investigation_reminder(ctx)
      get_char_var(ctx, :sign_q, 0) < 15 -> research_intro(ctx)
      get_char_var(ctx, :sign_q, 0) == 19 -> investigation_answer(ctx)
      get_char_var(ctx, :sign_q, 0) == 20 -> next_test(ctx)
      true -> busy(ctx)
    end
  end

  defp first_meeting(ctx) do
    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Excuse me...")
      |> next()
      |> emotion(:huk)
      |> mes("^313FFF*Clink*^000000")
      |> next()
      |> mes("[Sir Jore]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> emotion(:profusely_sweat)
      |> mes("[Sir Jore]")
      |> mes("...")
      |> mes("......")
      |> mes("...No!")
      |> mes("Look what")
      |> mes("you made me do!")
      |> next()
      |> emotion(:cry)
      |> mes("[Sir Jore]")
      |> mes("I've been fiddling")
      |> mes("with this sample for")
      |> mes("five hours. And now")
      |> mes("it's ruined! ^333333*Sob*^000000")
      |> next()
      |> emotion(:cry)
      |> mes("[Sir Jore]")
      |> mes("^333333*Sob*^000000")
      |> mes("I came to this town")
      |> mes("so I could focus on")
      |> mes("my research without")
      |> mes("any interruptions. So")
      |> mes("why are you here?")
      |> next()
      |> select(["Daewoon sent me.", "Oops, sorry. Later~"])

    case choice do
      1 -> accept_visitor(ctx)
      2 -> ruined_sample(ctx)
      _ -> ctx
    end
  end

  defp accept_visitor(ctx) do
    ctx =
      ctx
      |> emotion(:sweat)
      |> mes("[Sir Jore]")
      |> mes("O-oh!")
      |> mes("That's right.")
      |> mes("You're here to be")
      |> mes("tested for the piece")
      |> mes("of the Sobbing Starlight.")
      |> next()
      |> emotion(:profusely_sweat)
      |> mes("[Sir Jore]")
      |> mes("So...")
      |> mes("Er. Then, what...")
      |> mes("W-what's your name?")
      |> next()

    {ctx, _} =
      select(ctx, String.split(Rathena.concat(char_name(ctx, 0), ", thanks."), ":"))

    ctx
    |> mes("[Sir Jore]")
    |> mes("N-nice to meet you.")
    |> mes("My name is Jore. Just")
    |> mes("a normal person who loves")
    |> mes("research. S-sorry if I seem")
    |> mes("a little nervous! I'm actually")
    |> mes("quite... shy around people.")
    |> next()
    |> mes("[Sir Jore]")
    |> mes("Oh no...!")
    |> mes("If you were able to")
    |> mes("find me, there will be")
    |> mes("others! When would I get")
    |> mes("the time to do my research?!")
    |> mes("N-no! I h-h-hate people!!")
    |> next()
    |> mes("[Sir Jore]")
    |> mes("Still, I did promise")
    |> mes("M-M-Metz and he is my")
    |> mes("friend. So I must accept")
    |> mes("some guests. Even if hundreds")
    |> mes("of them knock on my door...")
    |> next()
    |> mes("[Sir Jore]")
    |> mes("But first of all,")
    |> mes("I'm going to need")
    |> mes("a new research sample.")
    |> mes("I think it's only fair that")
    |> mes("you get it for me since you")
    |> mes("made me ruin the last one.")
    |> next()
    |> mes("[Sir Jore]")
    |> mes("N-now, d-don't worry.")
    |> mes("The items are actually")
    |> mes("quite easy to get. It's")
    |> mes("five hours part that's")
    |> mes("hard. Now, let's see...")
    |> next()
    |> set_char_var(:sign_q, 16)
    |> mes("[Sir Jore]")
    |> mes("Just bring me")
    |> mes("10 Empty Test Tubes,")
    |> mes("10 Green Herbs and")
    |> mes("2 Yggdrasil Leafs.")
    |> next()
    |> mes("[Sir Jore]")
    |> mes("You see, l-lately I've")
    |> mes("been studying Biology. ")
    |> mes("I think the secret to life")
    |> mes("can be found in the Leaf of")
    |> mes("Yggdrasil. They can be used")
    |> mes("to revive the dead, after all.")
    |> next()
    |> emotion(:sweat)
    |> mes("[Sir Jore]")
    |> mes("Oh, and make sure to")
    |> mes("bring those things to me")
    |> mes("me before I go to bed at")
    |> mes("precisely 10:00 PM PST.")
    |> mes("I do have a regular sleeping")
    |> mes("schedule, you know.")
    |> close()
  end

  defp ruined_sample(ctx) do
    ctx
    |> emotion(:cry)
    |> mes("[Sir Jore]")
    |> mes("I spent five hours")
    |> mes("observing the changes")
    |> mes("in that research sample.")
    |> mes("All of that hard work lost!")
    |> mes("^333333*Wah~!*^000000")
    |> close()
  end

  defp research_materials(ctx) do
    if count_item(ctx, 1092) > 9 and count_item(ctx, 610) > 1 and count_item(ctx, 511) > 9 do
      assign_investigation(ctx)
    else
      missing_materials(ctx)
    end
  end

  defp assign_investigation(ctx) do
    ctx =
      ctx
      |> delitem(1092, 10)
      |> delitem(610, 2)
      |> delitem(511, 10)
      |> set_char_var(:sign_q, 17)
      |> emotion(:thanks)
      |> mes("[Sir Jore]")
      |> mes("Ah! Th-thank you for")
      |> mes("bringing what I need.")
      |> mes("Now I can continue my")
      |> mes("research. Oh, and see if")
      |> mes("you're worthy of obtaining")
      |> mes("the Sobbing Starlight.")
      |> next()
      |> mes("[Sir Jore]")
      |> mes("Now, for your assignment.")
      |> mes("Have you ever heard about")
      |> mes("the ^CE3131Stone of Sage^000000? Rumors about")

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat(
          "it have been spreading around, but no one has confirmed the truth about it, ",
          char_name(ctx, 0)
        ),
        "."
      )
    )
    |> next()
    |> mes("[Sir Jore]")
    |> mes("Although I have no clue")
    |> mes("what the Stone of S-S-age")
    |> mes("may actually be, I have a gut")
    |> mes("feeling that I need it to bring")
    |> mes("my Biology research to the next step. This is how you'll help me.")
    |> next()
    |> set_char_var(:sign_q, 17)
    |> mes("[Sir Jore]")
    |> mes("I need you to investigate")
    |> mes("this Stone of Sage by finding")
    |> mes("a father and daughter who were")
    |> mes(
      "famous for being great Alchemists. They vanished deep into a forest, but I believe they know something."
    )
    |> close()
  end

  defp missing_materials(ctx) do
    ctx
    |> mes("[Sir Jore]")
    |> mes("Please bring m-me")
    |> mes("10 Empty Test Tube,")
    |> mes("10 Green Herb and")
    |> mes("2 Leaf of Yggdrasil")
    |> mes("so that I can make a")
    |> mes("new research sample.")
    |> close()
  end

  defp investigation_reminder(ctx) do
    ctx
    |> mes("[Sir Jore]")
    |> mes("I want you to find two")
    |> mes("Alchemists, a father and")
    |> mes("daughter, who have gone into")
    |> mes("seclusion deep in some forest")
    |> mes("so that I can learn more about")
    |> mes("the Stone of Sage.")
    |> next()
    |> mes("[Sir Jore]")
    |> mes("Of course, this will")
    |> mes("possibly further my")
    |> mes("research, but it's also")
    |> mes("how I'll judge whether or")
    |> mes("not you're qualified for my")
    |> mes("piece of the Sobbing Starlight.")
    |> close()
  end

  defp research_intro(ctx) do
    ctx
    |> mes("[Sir Jore]")
    |> mes("The mystery of life.")
    |> mes("The desire to discover its")
    |> mes("secrets drives me through")
    |> mes("all the research and sacrifice.")
    |> next()
    |> mes("[Sir Jore]")
    |> mes("I-I'm not that confident in")
    |> mes(
      "my abilities, but I do believe that everything in this world is created by certain rules. Still, would I be punished by God for trying to create life he did not intend?"
    )
    |> next()
    |> mes("[Sir Jore]")
    |> mes("But I can't stop now.")
    |> mes("One of these days, someone")
    |> mes("will reveal the secret of life.")
    |> mes("Why not me? That knowledge")
    |> mes("would make humans greater")
    |> mes("than any other race...")
    |> close()
  end

  defp investigation_answer(ctx) do
    ctx =
      ctx
      |> mes("[Sir Jore]")
      |> mes("Ah, you've returned.")
      |> mes("So, did you learn what")
      |> mes("exactly is the Stone of Sage?")
      |> next()

    {ctx, answer} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Well, I'm not sure,")
      |> mes("but I was told that it's")
      |> mes("red and can cure people.")
      |> mes("But it might be something")
      |> mes("we're already familiar with.")
      |> next()
      |> mes("[Sir Jore]")
      |> mes("That's all...?")
      |> mes("Maybe it was nothing")
      |> mes("but a rumor after all.")
      |> mes("A-anyway, please tell me")
      |> mes("what you think it might be.")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", answer)

    if Rathena.truthy?(Rathena.compare(get_local(ctx, :"input$", ""), "red gemstone")) do
      reward_answer(ctx)
    else
      misunderstood_answer(ctx)
    end
  end

  defp reward_answer(ctx) do
    ctx =
      ctx
      |> mes("[Sir Jore]")
      |> mes("What...! Huh.")
      |> mes("Perhaps I should just")
      |> mes("forget about the Stone of")
      |> mes("Sage and just research.")
      |> mes("Still, I'm so ashamed of")
      |> mes("relying on a rumor...")
      |> next()
      |> set_char_var(:sign_q, 20)
      |> give_item(7177, 1)
      |> mes("[Sir Jore]")
      |> mes("Thank you very much")
      |> mes("for helping me. Now I can")
      |> mes("go back to my studies and")
      |> mes("hope that nobody bothers me.")
      |> mes("But that'll never happen.")
      |> mes("^333333*Sigh...*^000000")
      |> next()
      |> mes("[Sir Jore]")
      |> mes("W-well, you've earned this")
      |> mes("piece of the Sobbing Starlight.")
      |> mes(
        "For the next piece, you must visit ^0063FFLady Jesqurienne^000000 in Geffen, the city of magic. Since she travels often, she's probably in the Inn."
      )
      |> next()
      |> mes("[Sir Jore]")
      |> mes("O-o-okay then.")
      |> mes("Good luck getting")
      |> mes("all the pieces of ")
      |> mes("Sobbing Starlight,")

    ctx
    |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), ". Farewell~"))
    |> close()
  end

  defp misunderstood_answer(ctx) do
    ctx
    |> mes("[Sir Jore]")
    |> mes("Err...?")
    |> mes("I don't think")
    |> mes("I quite understood")
    |> mes("you. What did you say?")
    |> close()
  end

  defp next_test(ctx) do
    ctx
    |> mes("[Sir Jore]")
    |> mes("Now you must visit")
    |> mes("^0063FFLady Jesqurienne^000000 in")
    |> mes("Geffen. Good luck")
    |> mes("passing her test.")
    |> close()
  end

  defp busy(ctx) do
    ctx
    |> mes("[Sir Jore]")
    |> mes("H-how is this supposed")
    |> mes("to work? Like this? No!")
    |> mes("No, that's not right!")
    |> mes("Think, Jore, think...")
    |> mes("What's the answer?!")
    |> close()
  end

  defp daytime(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou find a tense man")
      |> mes("holding test tubes between")
      |> mes("his fingers, standing in a pile")
      |> mes("of books. He seems to be in")
      |> mes("agony for some reason.")
      |> next()
      |> select(["Speak to him.", "Ignore him."])

    case choice do
      1 -> speak_to_him(ctx)
      2 -> leave_him(ctx)
      _ -> ctx
    end
  end

  defp speak_to_him(ctx) do
    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Excuse me...")
      |> next()
      |> mes("[Sir Jore]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("^3355FFToo preoccupied with")
      |> mes("his thoughts, this strange")
      |> mes("man is unable to hear you.^000000")
      |> next()
      |> select(["Try again.", "Ignore him."])

    case choice do
      1 -> speak_again(ctx)
      2 -> leave_him(ctx)
      _ -> ctx
    end
  end

  defp speak_again(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("EXCUSE ME!")
    |> next()
    |> mes("[Sir Jore]")
    |> mes("...!")
    |> mes("Oh, h-h-hello.")
    |> mes("Sorry, but I'm kind of")
    |> mes("busy right now. Yes, yes,")
    |> mes("would you come back at")
    |> mes("precisely 5:00 PM PST?")
    |> next()
    |> mes("[Sir Jore]")
    |> mes("Let's see...")
    |> mes("Now if I recalibrated")
    |> mes("the faust exhaust, then")
    |> mes("the bioneutron analyzer")
    |> mes("would need to be adjusted")
    |> mes("for cytoplasmic balance...")
    |> close()
  end

  defp leave_him(ctx) do
    ctx
    |> mes("^3355FFYou decide to leave")
    |> mes("him alone and let him")
    |> mes("continue mumbling to")
    |> mes("himself and playing")
    |> mes("with his test tubes.^000000")
    |> close()
  end

  def ev_ontouch(ctx) do
    if Rathena.truthy?(:rand.uniform(2) - 1) do
      ctx |> emotion(:aha) |> specialeffect(:pharmacy_ok)
    else
      ctx |> emotion(:huk) |> specialeffect(:pharmacy_fail)
    end
  end
end
