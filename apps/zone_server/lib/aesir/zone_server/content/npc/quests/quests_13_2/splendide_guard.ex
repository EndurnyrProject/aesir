defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.SplendideGuard do
  @moduledoc """
  Arc, the Splendide guard who starts and follows the Two Tribes quest.

  ## Behavior

  - Refuses to talk while the player is too heavy to receive items.
  - Speaks only the Laphine language unless the player wears the Ring of the Ancient
    Wise King after finishing the Otherworld Language quest.
  - Introduces himself, learns the player's name, and asks them to find his missing
    friend Terra, starting quest 7056.
  - Reacts to the news about Terra and the wounded Sapha, sending the player to the
    cave (quest 7058 to 7059).
  - Hands over three Yggdrasilberries to treat the captured Laphine (quest 7062 to 7063).
  - Announces Terra's return and points to her Yai (quest 7070 to 7071).
  - Stops players who walk up to him without the ring or before meeting him.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_2.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_in01",
        x: 32,
        y: 306,
        dir: 3,
        sprite: 447,
        name: "Splendide Guard",
        scope: :shared,
        unique_name: "Splendide Guard#ep13md01",
        trigger: {2, 2}
      }
    ]

  @rhea_ring 2782
  @terra_knots "^4d4dffTerra^000000 has a habit of making a knot out of plants to mark her destination."

  @impl true
  def on_event("OnTouch", ctx) do
    cond do
      is_equipped(ctx, @rhea_ring) != 1 ->
        ctx
        |> mes("[Splendide Guard]")
        |> mes("Tal-!")
        |> mes("AnuDur AmanDana Goth nar!")
        |> mes("Agoltas Me...")
        |> next()
        |> mes("- Looks like we don't understand each other. This could be troublesome... -")
        |> close()

      get_char_var(ctx, :ep13_mdrama, 0) < 1 ->
        ctx
        |> mes("[Splendide Guard]")
        |> mes("Halt.")
        |> mes("This area is restricted unless you have been given permission.")
        |> mes("Especially to outsiders like you.")
        |> close()

      true ->
        ctx
    end
  end

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 2}]) == 0 ->
        ctx
        |> mes("Wait a moment!!")
        |> mes("You have too many items.")
        |> mes("You can't receive this.")
        |> mes("Lighten your weight and")
        |> mes("try again.")
        |> close()

      is_equipped(ctx, @rhea_ring) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 ->
        arc(ctx, get_char_var(ctx, :ep13_mdrama, 0))

      get_char_var(ctx, :ep13_mdrama, 0) > 0 ->
        ctx
        |> mes("[Arc]")
        |> mes("Yur,Dur AnoVa?")
        |> mes("Wha? Dieb OsaDur .. ")
        |> mes("ah..RuffThus NeAsh. man nesAsh OdesAlah ?")
        |> next()
        |> mes("- I can't understand what he's saying... Oh god how frustrating. -")
        |> close()

      true ->
        ctx
        |> mes("[Splendide Guard]")
        |> mes("NeiVil !")
        |> mes("narNoth nesMush.")
        |> mes("AnuDur AmanDana Goth nar!")
        |> next()
        |> mes("- We don't seem to understand eachother. -")
        |> close()
    end
  end

  defp arc(ctx, 0), do: first_meeting(ctx)
  defp arc(ctx, 1), do: ask_favor(ctx)

  defp arc(ctx, 2) do
    ctx
    |> mes("[Arc]")
    |> mes(@terra_knots)
    |> mes(
      "Keep that in mind when searching for her. And don't tell any other Laphine's about her missing."
    )
    |> next()
    |> mes("[Arc]")
    |> mes("You #{char_name(ctx, 0)} are the only one I could ask for help...")
    |> mes("Do me this favor please.")
    |> close()
  end

  defp arc(ctx, stage) when stage in 4..6 do
    ctx
    |> mes("[Arc]")
    |> mes("Did you find anything?")
    |> mes("Have you found any knotted plants?")
    |> mes("Yeah, that's the mark")
    |> mes("that Terra leaves.")
    |> next()
    |> mes("[Arc]")
    |> mes("Keep it up and find her")
    |> mes("for me.")
    |> close()
  end

  defp arc(ctx, 7), do: terra_returned_wounded(ctx)
  defp arc(ctx, 8), do: send_to_cave(ctx)

  defp arc(ctx, stage) when stage in 9..12 do
    ctx
    |> mes("[Arc]")
    |> mes("I'm really sorry for getting you into this mess.....")
    |> mes("...Please, find Terra.")
    |> close()
  end

  defp arc(ctx, 13), do: give_yggdrasilberries(ctx)

  defp arc(ctx, stage) when stage in 14..17 do
    ctx
    |> mes("[Arc]")
    |> mes("There's a huge root of the tree near a swamp at the outskirts of this area.")
    |> mes("That's where the tree of life's root is exposed.")
    |> next()
    |> mes("[Arc]")
    |> mes("You should be able to find some Yggdrasilberries there.")
    |> next()
    |> mes("[Arc]")
    |> mes("You will need at least 6~7 of them...")
    |> mes(".... .. I hope she is safe..")
    |> next()
    |> mes("[Arc]")
    |> mes(
      "As soon as you are done collecting the berries, bring them to the Sapha Village right away!!!"
    )
    |> mes("Terra... please be safe.")
    |> close()
  end

  defp arc(ctx, stage) when stage in 18..24 do
    ctx
    |> mes("[Arc]")
    |> mes("...Oh where is Terra...?")
    |> close()
  end

  defp arc(ctx, 25) do
    ctx
    |> mes("[Arc]")
    |> mes("#{char_name(ctx, 0)}!!")
    |> mes("Terra's back!!!")
    |> mes("She is back in one piece!")
    |> mes(
      "...She hasn't been saying a single word since her return, I told her to rest in Yai..."
    )
    |> next()
    |> mes("[Arc]")
    |> mes("Please come by if you don't mind...")
    |> mes("Terra's Yai.")
    |> mes("Which is her Private Residence... It's located at the Southeast direction from here.")
    |> mes("I would like to hear a detailed account of what happened.")
    |> set_char_var(:ep13_mdrama, 26)
    |> changequest(7070, 7071)
    |> close()
  end

  defp arc(ctx, 26) do
    ctx
    |> mes("[Arc]")
    |> mes("What happened....while she was gone?")
    |> mes("I would like to hear a detailed account fn what happened...")
    |> mes("Please go to Terra's Yai later.")
    |> close()
  end

  defp arc(ctx, stage) when stage > 26 do
    ctx
    |> mes("[Arc]")
    |> mes("I really appreciate what you've done for us.")
    |> mes("But, I'm worried about Terra.")
    |> mes("I hope she can be her old self...")
    |> close()
  end

  defp arc(ctx, _stage) do
    ctx
    |> mes("[Arc]")
    |> mes("Ah~Ah~Stop right there...")
    |> mes("This area is off-limits to unauthorized personnel.")
    |> close()
  end

  defp first_meeting(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Splendide Guard]")
      |> mes("Outsider?")
      |> mes("Outsiders have been coming more frequently.")
      |> next()
      |> mes("[Splendide Guard]")
      |> mes(
        "It seems like our superiors have permitted your entrance, so I won't stop you either."
      )
      |> next()
      |> mes("[Arc]")
      |> mes("My name is Arc.")
      |> mes("By the way, hmm... Can you understand what I'm saying?")
      |> next()
      |> select(["Yes.", "Shake my head"])

    case choice do
      1 ->
        ctx
        |> mes("[Arc]")
        |> mes("What? Did you just say 'Yes'?")
        |> mes("Can't believe we understand eachother!")
        |> mes("When did you learn our language?")
        |> mes("What is your race called?")
        |> next()
        |> mes(
          "- I show my ring to Arc and explain everything including how I ended up here... -"
        )
        |> next()
        |> mes("[Arc]")
        |> mes("So...hmm, That's how it is...")
        |> mes("The source of that huge shock and mysterious explosion...")
        |> next()
        |> mes("[Arc]")
        |> mes("Quite an interesting story.")
        |> mes("That's why you humans were exploring here and there...")
        |> next()
        |> mes("[Arc]")
        |> mes("Now I clearly understand that you are not sent by the giants of Manuk.")
        |> mes("Thank you for telling me these interesting stories.")
        |> set_char_var(:ep13_mdrama, 1)
        |> close()

      2 ->
        ctx
        |> mes("[Arc]")
        |> mes("Oh? Is that so?")
        |> mes("We use different languages as expected...")
        |> mes("That's a bit frustrating.")
        |> close()

      _ ->
        ctx
    end
  end

  defp ask_favor(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Arc]")
      |> mes("By the way, you...")
      |> mes("No, never mind...")
      |> mes("What is your name?")
      |> next()
      |> select(String.split(char_name(ctx, 0), ":"))

    {ctx, choice} =
      ctx
      |> mes("[Arc]")
      |> mes("Ah, right. #{char_name(ctx, 0)}!")
      |> mes("That's a strange pronunciation.")
      |> mes("I might mispronunce it, so please understand...")
      |> next()
      |> mes("[Arc]")
      |> mes("Anyways, I have a favor to ask you. Is it okay?")
      |> next()
      |> select(["What favor?", "Not now."])

    case choice do
      1 ->
        explain_missing_friend(ctx)

      2 ->
        ctx
        |> mes("[Arc]")
        |> mes("Is that so? Of course.")
        |> mes("You were sent here to carry on your own mission...")
        |> close()

      _ ->
        ctx
    end
  end

  defp explain_missing_friend(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Arc]")
      |> mes("Um...Ah..It's...")
      |> mes("A little...complicated...")
      |> next()
      |> mes(
        "- Arc looks around to check if someone else is around. Satisfied you're alone he continues with his story in a low tone. -"
      )
      |> next()
      |> mes("[Arc]")
      |> mes(
        "Frankly, I'm worried about a friend of mine who left without permission saying that she's going to check on your camp. She hasn't come back since then."
      )
      |> next()
      |> mes("[Arc]")
      |> mes(
        "But, I can't leave this post to look for her 'cause I have a duty to guard the research data stored here."
      )
      |> next()
      |> mes("[Arc]")
      |> mes(
        "Since she left without permission, I can't even report to my superiors... that will just end up as a bigger problem."
      )
      |> next()
      |> mes("[Arc]")
      |> mes("The thought of it just worries me...")
      |> mes(
        "As a matter of fact, we are trying not to have any contact with the giants of Manuk so we stay away from each other's territory."
      )
      |> next()
      |> mes("[Arc]")
      |> mes(
        "That camp of yours is located in the area that has been acting as the neutral zone between our two races..."
      )
      |> next()
      |> mes("[Arc]")
      |> mes(
        "If she has gotten close to their side then she might have gone over to the snow fields..."
      )
      |> mes("That will make it even more difficult for us to look for her...")
      |> next()
      |> mes("[Arc]")
      |> mes("The Manuk giants might misunderstand this as provoking them...Couldn't they?")
      |> next()
      |> player_says()
      |> mes("So...the point is, you want me to look for your friend. Right?")
      |> mes("Because you can't do it yourself from all these complicated situations?")
      |> next()
      |> mes("[Arc]")
      |> mes("Exactly!")
      |> mes("You're quite observant.")
      |> next()
      |> select(["Sure, I will do it.", "Sorry, can't help you."])

    case choice do
      1 ->
        ctx
        |> player_says()
        |> mes("But, I'm going to need more information if I'm going to look for her.")
        |> next()
        |> mes("[Arc]")
        |> mes("You don't have to worry about that...")
        |> mes(@terra_knots)
        |> next()
        |> mes("[Arc]")
        |> mes("She does it so that she won't get lost.")
        |> mes("If you find a trail of knotted plants it should lead you to where she is.")
        |> next()
        |> mes("[Arc]")
        |> mes("It can be hard to look for them, but it's better than doing nothing...")
        |> mes("Please, I beg of you.")
        |> next()
        |> mes("[Arc]")
        |> mes("Ah, and please keep this a secret from the other Laphines.")
        |> next()
        |> mes("[Arc]")
        |> mes("Remember #{char_name(ctx, 0)}... you must keep this to yourself...")
        |> mes("Please, find her.")
        |> set_char_var(:ep13_mdrama, 2)
        |> setquest(7056)
        |> close()

      2 ->
        ctx
        |> mes("[Arc]")
        |> mes("It sure was an unreasonable favor...")
        |> mes("You too were sent here to carry on a mission...")
        |> mes("That was thoughtless of me...")
        |> close()

      _ ->
        ctx
    end
  end

  defp terra_returned_wounded(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Arc]")
      |> mes("Ah, Well met!")
      |> mes("What do I do now?!")
      |> next()
      |> select(["What? What happened?"])

    {ctx, _} =
      ctx
      |> mes("- Arc looks like he was thrown into confusion about something. -")
      |> next()
      |> mes("[Arc]")
      |> mes("Terra...")
      |> next()
      |> mes("[Arc]")
      |> mes("Terra came back!!!")
      |> mes("but, she was covered all over with wounds...")
      |> next()
      |> select(["Covered with wounds?"])

    {ctx, _} =
      ctx
      |> mes("[Arc]")
      |> mes("She didn't even get treatment!")
      |> mes("She just took the Bradium with that exhausted body!")
      |> next()
      |> mes("[Arc]")
      |> mes("Didn't even tell me the reason!")
      |> mes("I told her no, but she wouldn't listen to me!")
      |> mes("It happened all of a sudden.")
      |> next()
      |> mes("[Arc]")
      |> mes("#{char_name(ctx, 0)}!")
      |> mes("What shoud I do now?")
      |> mes("What do I have to do?")
      |> mes("Terra left again and she was hurt...")
      |> next()
      |> mes("[Arc]")
      |> mes("And I just stood here...doing nothing.")
      |> next()
      |> select(["You have a strong sense of responsibility."])

    ctx
    |> mes("[Arc]")
    |> mes("......anyways.")
    |> mes("I couldn't either stop her, or follow her...")
    |> mes("What now...?")
    |> mes("Why did she take the Bradium...?")
    |> next()
    |> mes("- You tell Arc about the Giant from the cave. -")
    |> next()
    |> mes("[Arc]")
    |> mes("What? Is that what happened?")
    |> mes("Bradium...is certainly a precious ore for Sapha.")
    |> mes("They use a refined Bradium ore...")
    |> next()
    |> mes("[Arc]")
    |> mes("You said that a Sapha was hurt?")
    |> mes("And its body was already stiff?")
    |> mes("Impossible!")
    |> mes("Terra!!")
    |> next()
    |> mes("- Arc suddenly began gathering up his gear. -")
    |> set_char_var(:ep13_mdrama, 8)
    |> close()
  end

  defp send_to_cave(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Arc]")
      |> mes("Where was that cave where you found that Sapha?")
      |> mes("There was no such cave when we inspected our surrounding areas.")
      |> next()
      |> select(["What are you trying to do?"])

    {ctx, _} =
      ctx
      |> mes("[Arc]")
      |> mes("Can't you see?")
      |> mes(
        "I'm going out to look for Terra. She took the Bradium with her, it has got to be something to do with that Sapha."
      )
      |> next()
      |> select(["Is it okay for you to leave your post?"])

    ctx
    |> mes("[Arc]")
    |> mes("It's.. ...")
    |> mes("...No....")
    |> mes("Shit, then what should I do!!")
    |> next()
    |> player_says()
    |> mes("I will go. I'm the one who knows exactly where that cave is.")
    |> mes("I will go and bring her back.")
    |> mes("If Terra headed for that cave, I should be able to find her.")
    |> next()
    |> player_says()
    |> mes("Let's hear rest of the story from Terra.")
    |> mes("It is important for you to guard this place, isn't it?")
    |> mes("If Terra really took the Bradium without any permission...")
    |> next()
    |> mes("[Arc]")
    |> mes("The higher ups won't just remain still...")
    |> mes("I'm sorry to ask you but...")
    |> mes("Please go and bring her back here...")
    |> set_char_var(:ep13_mdrama, 9)
    |> changequest(7058, 7059)
    |> close()
  end

  defp give_yggdrasilberries(ctx) do
    ctx
    |> mes("[Arc]")
    |> mes("What? A wounded Laphine in the Sapha's village?")
    |> mes("Was it Terra?! Was she captured by those Sapha bastards?!")
    |> next()
    |> player_says()
    |> mes("Calm down. I couldn't check out exactly who the captured Laphine was.")
    |> mes("And they seem to have no intention of harming the Laphine.")
    |> next()
    |> player_says()
    |> mes("Also, they were looking for something that can cure a wounded Laphine...")
    |> mes("If we bring some medicine to them, we might have a chance to see who the Laphine is.")
    |> next()
    |> player_says()
    |> mes(
      "I understand how anxious you feel.. but that is the only way I can think of finding out who it is."
    )
    |> next()
    |> player_says()
    |> mes(
      "I will take some things to treat the wounds with me and if it turns out that the captured Laphine is Terra, I will bring her back."
    )
    |> next()
    |> mes("[Arc]")
    |> mes("..........")
    |> mes("OK, that seems like the best thing we can do for this situation...")
    |> next()
    |> mes("[Arc]")
    |> mes("Do you by any chance know about the 'Yggdrasil'?")
    |> mes("There's nothing better than the Yggdrasilberry to treat wounds...")
    |> mes("Especially for us Laphine...")
    |> next()
    |> mes("[Arc]")
    |> mes("If you have a Yggdrasilberry, you can use it to cure that Laphine...")
    |> mes(
      ".Yggdrasil is the tree of life... its roots are in touch with everything in this world."
    )
    |> next()
    |> mes("[Arc]")
    |> mes("I have...")
    |> mes("...only three Yggdrasilberries...")
    |> next()
    |> mes("[Arc]")
    |> mes("I will give you these but they won't be enough...")
    |> mes(
      "Outside... there is a huge tree... where the root of the Yggdrasil is exposed.... it should be there."
    )
    |> next()
    |> mes("[Arc]")
    |> mes("Sometimes you can find Yggdrasilberries around there.")
    |> mes("Go find few more and bring them with you. Hurry!")
    |> set_char_var(:ep13_mdrama, 14)
    |> give_item(607, 3)
    |> changequest(7062, 7063)
    |> close()
  end

  defp player_says(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")
end
