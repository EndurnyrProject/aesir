defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.PrayingMan do
  @moduledoc """
  Hermite Charles prays in the Prontera church and holds the next clue of the Brisingamen Seal
  quest.

  ## Behavior

  - Before the Brisingamen seal phase opens, or after it has been broken, he only prays.
  - Handed Kaili's letter, he tells his story and asks the player to learn what happened to
    Lowen; refusing leaves him waiting, and at the declined stage he may offer the story again
    at random.
  - Corrects a player who found the wrong Crusader, and moves the quest on when told of Lowen's
    death.
  - Told that Lowen became an Einherjar, he reveals where the relic was taken and the quest
    advances.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 113,
        y: 103,
        dir: 1,
        sprite: 798,
        name: "Praying Man",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        ctx
        |> mes("[Praying Man]")
        |> mes("Let everyone live a life")
        |> mes("of happiness. Let there be")
        |> mes("peace in the world...")
        |> next()
        |> mes("[Praying Man]")
        |> mes("May I hit it rich with this")
        |> mes("Old Blue Box that I spend this")
        |> mes("month's paycheck on...")
        |> close()

      get_server_var(ctx, "God3", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        ctx
        |> mes("[Praying Man]")
        |> mes("Now is the time to reflect upon the past to prepare for the future.")
        |> next()
        |> mes("[Praying Man]")
        |> mes(
          "It is in stillness that we find the wisdom to know which steps we must take to move forward. Let's pray."
        )
        |> close()

      true ->
        talk(ctx, get_char_var(ctx, :god_brising, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk(ctx, stage) when stage > 34 do
    ctx
    |> mes(
      "^3355FFHermite Charles continues to fervently pray. His eyes are closed and his hands are clasped to his chest. There seems to be an air of faint sadness about him.^000000"
    )
    |> close()
  end

  defp talk(ctx, 34) do
    ctx
    |> mes("[Hermite Charles]")
    |> mes("What did you just say?")
    |> mes("Did she really become an")
    |> mes("Einherjar? That's the greatest honor for any warrior...")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("She must")
    |> mes("be so happy.")
    |> mes("I guess in the end,")
    |> mes("I never really had")
    |> mes("any place in her heart.")
    |> mes("Lowen...")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("But I know one thing")
    |> mes(
      "for sure. She should have blamed me for what happened. Why did she take everything upon herself?"
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes(
      "I guess she just saw me as a little brother. She obviously didn't take me very seriously."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("Haha... Hahaha...")
    |> mes("Now I feel better!")
    |> mes("So, what did you say?")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("Yes, right.")
    |> mes("Please tell Enrico this.")
    |> mes(
      "The object he's interested in was given by His Majesty to a guild that possessed a castle."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes(
      "It can never be made through just human technology. But I guess that His Majesty will let scholars study it and let men possess it if they prove capable."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("I wasn't powerful enough to")
    |> mes(
      "earn it. Frankly, I stole it. But soon I began to fear its presense and my heart would pound with trepidation when I saw it."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("One day, I think it actually possessed me and I ended up")
    |> mes("going on a journey. I'm not really sure exactly where though...")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes(
      "All I remember was that I was in Lutie, the town of snow. I went over a bridge to a hill to the West..."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("But once I arrived there, I was seized with this feeling of terror I can't explain.")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("I ended up running away.")
    |> mes(
      "That's why I gave it to Mr. Enrico. You can laugh at me for being a coward if you want."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("You know everything now.")
    |> mes("Please leave me alone.")
    |> mes("^333333*Sigh...*^000000")
    |> set_char_var(:god_brising, 35)
    |> close()
  end

  defp talk(ctx, stage) when stage > 19 do
    ctx
    |> mes("[Hermite Charles]")
    |> mes("I'll be waiting.")
    |> mes(
      "For some reason, I believe you'll be able to find some sort of clue about what happened these past"
    )
    |> mes("two years one of these days.")
    |> close()
  end

  defp talk(ctx, 12) do
    ctx
    |> mes("[Hermite Charles]")
    |> mes("Lohen Phelicia?")
    |> mes("The person I asked you to find is Lowen, not Lohen. Lowen Ellenen.")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("I'm sorry")
    |> mes("for the trouble,")
    |> mes("but I think you")
    |> mes("better try again.")
    |> set_char_var(:god_brising, 10)
    |> close()
  end

  defp talk(ctx, 11) do
    ctx
    |> mes("[Hermite Charles]")
    |> mes("Yes...")
    |> mes("Lowen is no")
    |> mes("longer with us.")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes(
      "I've heard different rumors, but she definitely passed away. I was even at her funeral."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("The last time I saw her alive")
    |> mes(
      "was in Geffen. Two years after that, I saw her buried in her grave. Didn't I tell you this?"
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes(
      "I wanted you to find out what happened in those two years before she died. I wanted to know what led to her death."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("What the hell")
    |> mes("killed her?!")
    |> mes("Don't you understand")
    |> mes("the way I feel?")
    |> set_char_var(:god_brising, 20)
    |> close()
  end

  defp talk(ctx, 10) do
    ctx
    |> mes("[Hermite Charles]")
    |> mes(
      "Lowen was a Crusader, a knight in the service of holiness preparing for the Holy War."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("I always expected her to")
    |> mes(
      "become a Knight in the Prontera Chivalry, but suddenly she changed her mind and became a Crusader."
    )
    |> mes("I saw her for the last time in Geffen.")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("I beg you...")
    |> mes("Please learn")
    |> mes("anything you can")
    |> mes("about what happened")
    |> mes("to Lowen.")
    |> close()
  end

  defp talk(ctx, 5) do
    if Enum.random(1..4) == 1 do
      {ctx, choice} =
        ctx
        |> mes("[Hermite Charles]")
        |> mes("You're still here.")
        |> mes("Does that mean you")
        |> mes("want to hear my")
        |> mes("story after all?")
        |> next()
        |> select(["Yes, I would like to.", "No, thanks."])

      answer_story_offer(ctx, choice)
    else
      ctx
      |> mes("[Hermite Charles]")
      |> mes("...")
      |> mes("^333333*Sob...*^000000")
      |> mes("I'm sorry.")
      |> mes("I'm so sorry, Lowen.")
      |> mes("It was all my fault...")
      |> close()
    end
  end

  defp talk(ctx, 4) do
    ctx
    |> mes("[Hermite Charles]")
    |> mes("What do you")
    |> mes("want from me?")
    |> mes("Were you sent by")
    |> mes("the Rogue Guild?")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("Tell them")
    |> mes("I quit already.")
    |> mes("Leave me alone!")
    |> next()
    |> offer_letter()
  end

  defp talk(ctx, 3) do
    ctx =
      ctx
      |> mes("[Sad-looking Man]")
      |> mes("...")
      |> mes("^333333*Sob...*^000000")
      |> mes("I am so")
      |> mes("sorry, Lowen.")
      |> mes("It's all fault...")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Excuse me.")
    |> mes("I am looking")
    |> mes("for someone named...")
    |> mes("Hermite?")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("Hm...?")
    |> mes("Hermite? That's me.")
    |> mes("But if you don't mind,")
    |> mes("I want to be alone...")
    |> next()
    |> offer_letter()
  end

  defp talk(ctx, _stage) do
    ctx
    |> mes("[Sad-looking Man]")
    |> mes("...")
    |> mes("^333333*Sob...*")
    |> mes("Lowen...")
    |> mes("I'm so sorry.")
    |> mes("It's all my fault.")
    |> mes("Please be okay...")
    |> close()
  end

  defp offer_letter(ctx) do
    case select(ctx, ["Leave him alone.", "Give him Kaili's Letter."]) do
      {ctx, 1} ->
        ctx
        |> mes(
          "^3355FFYou're not sure why he's so upset, but it doesn't seem to be the best time to try to speak with him. Perhaps later would be better...^000000"
        )
        |> set_char_var(:god_brising, 4)
        |> close()

      {ctx, 2} ->
        {ctx, choice} =
          ctx
          |> mes("[Hermite Charles]")
          |> mes("Huh...")
          |> mes("Enrico Kaili.")
          |> mes("Yeah, I remember")
          |> mes("him. So what..?")
          |> next()
          |> mes("^3355FFHermite nonchalantly")
          |> mes("tosses the letter back to you.^000000")
          |> next()
          |> mes("[Hermite Charles]")
          |> mes("...")
          |> mes("^333333*Sigh...*^000000")
          |> next()
          |> mes("[Hermite Charles]")
          |> mes("You...")
          |> mes("Would you like to")
          |> mes("listen to my story?")
          |> next()
          |> select(["Sure!", "I'm busy, actually."])

        answer_story_offer(ctx, choice)

      {ctx, _} ->
        ctx
    end
  end

  defp answer_story_offer(ctx, 1), do: tell_story(ctx)

  defp answer_story_offer(ctx, 2) do
    ctx
    |> mes("[Hermite Charles]")
    |> mes("I misunderstood you.")
    |> mes(
      "I should have realized that people never really listen unless it's of some benefit to them."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("I won't waste any more of")
    |> mes("your time. I'll accept Kaili's letter and wait until I find someone who'll listen to")
    |> mes("my story and help me.")
    |> set_char_var(:god_brising, 5)
    |> close()
  end

  defp answer_story_offer(ctx, _choice), do: ctx

  defp tell_story(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hermite Charles]")
      |> mes("Thank you...")
      |> mes("Perhaps you're doing this")
      |> mes("merely out of consideration,")
      |> mes("but I still appreciate your kindness. The story I will")
      |> mes("tell you is very old.")
      |> next()
      |> mes("[Hermite Charles]")
      |> mes("Long ago, there was a little boy who never knew his parents. Just")
      |> mes("to survive, he became a Thief and eventually joined the Rogue Guild.")
      |> next()
      |> mes("[Hermite Charles]")
      |> mes(
        "Without any goals or dreams, his life was pretty aimless. He pretty much only lived so that he could see tomorrow."
      )
      |> next()
      |> mes("[Hermite Charles]")
      |> mes(
        "However, the little boy met someone who was full of hope and kindess. He admired her and she became his reason for living."
      )
      |> next()
      |> mes("[Hermite Charles]")
      |> mes(
        "She will never know that the little boy loved her more than anything else. Unlike the boy, her dream was devote her life to God."
      )
      |> next()
      |> mes("[Hermite Charles]")
      |> mes(
        "Although he never understood that, he knew that he would be happy to just be near her, watching from a distance."
      )
      |> next()
      |> mes("[Hermite Charles]")
      |> mes("But one day, because of one fatal mistake, he lost her and she never came back.")
      |> next()
      |> mes("[Hermite Charles]")
      |> mes("Ever since, that boy has been coming to the Sanctuary everyday")
      |> mes("to pray for her safety, even into adulthood.")
      |> next()
      |> mes("[Hermite Charles]")
      |> mes("...")
      |> mes("^333333*Sob*^000000")
      |> mes("Please find")
      |> mes("her for me.")
      |> mes("Find Lowen.")
      |> next()
      |> mes("[Hermite Charles]")
      |> mes(
        "I know that Enrico has sent you. I'm guessing he needs something from me. Am I wrong?"
      )
      |> next()
      |> mes("[Hermite Charles]")
      |> mes(
        "I'll do whatever you want if you do what I want you to do. It's simple: find out anything you can about Lowen."
      )
      |> next()
      |> mes("[Hermite Charles]")
      |> mes(
        "It's doesn't matter how insignificant the clues may be, anything will do. I want to know everything related to her!"
      )
      |> next()
      |> select(["Uhhhhh...", "Sorry, I can't.", "When was the last time you saw her?"])

    answer_request(ctx, choice)
  end

  defp answer_request(ctx, 1) do
    {ctx, choice} =
      ctx
      |> mes("[Hermite Charles]")
      |> mes("Please consider my")
      |> mes("proposal. If you can")
      |> mes("find Lowen for me, I'll")
      |> mes("give you what you want.")
      |> next()
      |> mes("[Hermite Charles]")
      |> mes("Please, I beg you.")
      |> mes(
        "You are a strong and well-experienced adventurer. Isn't this a simple thing for you to do?"
      )
      |> next()
      |> mes("[Hermite Charles]")
      |> mes(
        "If you've ever dearly loved someone, then you'd know how desperate I am. Please find Lowen for me. Please..."
      )
      |> next()
      |> select(["...Alright.", "I'm sorry, I don't think I can do it."])

    answer_plea(ctx, choice)
  end

  defp answer_request(ctx, 2) do
    ctx
    |> mes("[Hermite Charles]")
    |> mes("You don't understand!")
    |> mes(
      "If I weren't this much of a coward, I would already have gone out to find out what I could for myself."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes(
      "I'm not afraid of monsters or dying. It's the fact that she might hate me now. That's what I fear: Lowen's reproach."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes(
      "All I can do for her is just earnestly pray. I had no idea it'd be so horrible not to be able to see her anymore..."
    )
    |> set_char_var(:god_brising, 9)
    |> close()
  end

  defp answer_request(ctx, 3) do
    ctx
    |> mes("[Hermite Charles]")
    |> mes("The last time")
    |> mes("I saw her was deep")
    |> mes("inside the Geffen Dungeon.")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes(
      "Although it was created by humans, that dungeon is now cursed and inhabited with horrific monsters."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes(
      "I'm guessing the Crusaders saw that it was necessary to exterminate the monsters there to keep it from getting even worse."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("Lowen accompanied")
    |> mes("a group of other Crusaders")
    |> mes("for the good of the people,")
    |> mes("but I haven't heard anything")
    |> mes("about her since...")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("That was the last time...")
    |> mes("Please find out anything")
    |> mes("you can. I beg you...")
    |> set_char_var(:god_brising, 10)
    |> close()
  end

  defp answer_request(ctx, _choice), do: ctx

  defp answer_plea(ctx, 1) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Alright.")
    |> mes("I'll try my best to find her. Would you tell me more about Lowen?")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("She is a Crusader.")
    |> mes("The last time I saw her was")
    |> mes("deep inside Geffen Dungeon.")
    |> next()
    |> mes("[Hermite Charles]")
    |> mes(
      "Long ago, some Crusaders entered the Geffen Dungeon on a monster subjugation expedition."
    )
    |> next()
    |> mes("[Hermite Charles]")
    |> mes("Please find")
    |> mes("anything that")
    |> mes("you can. I beg")
    |> mes("of you...")
    |> set_char_var(:god_brising, 10)
    |> close()
  end

  defp answer_plea(ctx, 2) do
    ctx
    |> mes("[Hermite Charles]")
    |> mes("^333333*Sigh*^000000")
    |> mes("I understand.")
    |> mes("But if you don't help me, then Kaili won't get the help he needs...")
    |> set_char_var(:god_brising, 9)
    |> close()
  end

  defp answer_plea(ctx, _choice), do: ctx
end
