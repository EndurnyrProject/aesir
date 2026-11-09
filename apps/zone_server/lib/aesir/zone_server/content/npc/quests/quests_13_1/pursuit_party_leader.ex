defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.PursuitPartyLeader do
  @moduledoc """
  Echinacea leads the expedition's pursuit of Satan Morocc and assigns the player to assist Mr. Kidd.

  ## Behavior

  - Refuses the conversation when the player carries too many items and restricts new assignments
    to players who have completed the journey to the Ash Vacuum.
  - Assigns and reminds the player to assist Mr. Kidd, then directs them to Defaria for magic advice.
  - Checks the tracing pattern number, takes the Morocc Tracing Logs on success, and sends the
    player to the building manager when the randomly determined tracing results are ready.
  - Concludes the pursuit with mode-dependent experience and an Old Violet Box, then discusses
    the political aftermath and accepts two Nice Sweet Potatoes from Defaria.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_campin",
        x: 68,
        y: 185,
        dir: 3,
        sprite: 803,
        name: "Pursuit Party Leader",
        scope: :shared,
        unique_name: "Pursuit Party Leader#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{714, 3}]) == 0 do
      overloaded(ctx)
    else
      at_step(ctx, get_char_var(ctx, :mao_morocc2, 0))
    end
  end

  defp at_step(ctx, step) do
    cond do
      step == 0 -> offers_assignment(ctx)
      step == 1 -> reminds_to_assist_kidd(ctx)
      step == 2 -> scolds_abandoned_duty(ctx)
      step > 2 and step < 13 -> praises_kidd(ctx)
      step == 13 -> introduces_defaria(ctx)
      step == 14 -> reminds_to_consult_defaria(ctx)
      step > 22 and step < 29 -> checks_tracing_pattern(ctx)
      step == 29 -> awaits_tracing_results(ctx)
      step == 30 -> reminds_to_check_results(ctx)
      step == 31 -> rewards_the_pursuit(ctx)
      step == 100 -> asks_what_is_bothering(ctx)
      step > 100 and step < 106 -> dismisses_from_service(ctx)
      step == 106 -> receives_sweet_potatoes(ctx)
      step > 106 -> looks_to_the_future(ctx)
      true -> encourages_progress(ctx)
    end
  end

  defp overloaded(ctx) do
    ctx
    |> mes("- You cannot proceed with the quest when you're carrying too many items with you. -")
    |> close()
  end

  defp offers_assignment(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) == 100 or get_char_var(ctx, :ep13_start, 0) == 100 do
      assigns_to_kidd(ctx)
    else
      unauthorized(ctx)
    end
  end

  defp assigns_to_kidd(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Echinacea]")
      |> mes("Oh adventurer, you've come at the perfect time.")
      |> mes("Since you and I both know that we can't waste time on idle chitchat,")
      |> mes("I'll cut to the chase.")
      |> next()
      |> mes("[Echinacea]")
      |> mes("Most expeditions come to this area to explore the Ash Vacuum,")
      |> mes("but we've come here for a different reason.")
      |> next()
      |> mes("[Echinacea]")
      |> mes("You know about this space gap that was caused by Satan Morocc, don't you?")
      |> next()
      |> mes("[Echinacea]")
      |> mes("Our job is to pursue Satan Morocc and figure out how this all happened.")
      |> mes(
        "Your job is to assist us, and prove that you can be a good member of our expedition."
      )
      |> next()
      |> mes("[Echinacea]")
      |> mes("... Umm... So, you'll have to.. Let me think which job would be perfect for you.")
      |> mes("Umm.. I remember someone said that he needed assistance...")
      |> next()
      |> select(["Hey, excuse me."])

    ctx =
      ctx
      |> mes("[Echinacea]")
      |> mes("Ah, I know what you can do!")
      |> mes("There's a guy conducting an investigation near the space gap. You can go help him.")
      |> mes("Just do what he asks you to do, alright?")
      |> mes("Now go!")
      |> next()
      |> mes("[Echinacea]")
      |> mes("......")
      |> mes("By the way, adventurer,")
      |> mes("What's your name?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("......")
      |> mes("......")

    ctx =
      ctx
      |> mes("#{char_name(ctx, 0)}...")
      |> mes("......")
      |> next()
      |> mes("[Echinacea]")
      |> mes("Ah, you are")

    ctx = mes(ctx, "#{char_name(ctx, 0)}.")

    ctx =
      ctx
      |> mes("Well, #{char_name(ctx, 0)}, I've just assigned you as Mr. Kidd's assistant.")
      |> mes("Good, everything's done on this end. I just needed to get your name on record.")
      |> next()
      |> mes("[Echinacea]")
      |> mes("What are you still doing here?")

    ctx
    |> mes("#{char_name(ctx, 0)}, your job is to assist Mr. Kidd.")
    |> mes("Please go help him, will you?")
    |> set_char_var(:mao_morocc2, 1)
    |> setquest(7012)
    |> close()
  end

  defp unauthorized(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes("What are you doing here?")
    |> mes("Only authorized personnel can enter this area.")
    |> mes("Go back to the mainland as quickly as possible.")
    |> close()
  end

  defp reminds_to_assist_kidd(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes(
      "Your job is to assist Mr. Kidd who's standing near the space gap, otherwise known as the gate."
    )
    |> mes("Please go help him, okay?")
    |> close()
  end

  defp scolds_abandoned_duty(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes("Why are you back?")
    |> mes("You're irresponsible. How could you abandon such an important duty?")
    |> mes(
      "If you don't want to work, why did you even come here to the Ash Vacuum in the first place?"
    )
    |> next()
    |> mes("[Echinacea]")
    |> mes("Alas! There's no one I can trust!")
    |> mes("You know, when I was working at the palace, I was.. *Blah Blah*...")
    |> next()
    |> mes(
      "- Her rant doesn't seem to be ending any time soon. You'd better go back and help Mr. Kidd, even if your heart's not in it. -"
    )
    |> next()
    |> set_char_var(:mao_morocc2, 3)
    |> changequest(7013, 7014)
    |> next()
    |> mes("[Echinacea]")
    |> mes("Hm? Where are you going? I'm not finished!")
    |> mes("Hey, hey!")
    |> close()
  end

  defp praises_kidd(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes("Mr. Kidd is such a great young man.")
    |> mes(
      "You should be thankful that I've assigned you to help him. Don't be lazy by neglecting your duties."
    )
    |> close()
  end

  defp introduces_defaria(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Echinacea]")
      |> mes("Oh, welcome back!")
      |> mes("I knew you would successfully complete your duties.")
      |> mes("So, tell me; how can I help you?")
      |> next()
      |> mes("[Echinacea]")
      |> mes("A scholar who is familiar with magic?")
      |> mes(
        "What about that old man over there? If you couldn't tell, he comes from a distant country."
      )
      |> mes("Why are you looking for a scholar, anyway?")
      |> next()
      |> mes("[Echinacea]")
      |> mes("Did Mr. Kidd ask you to find one?")
      |> mes("I see. He's probably looking for a solution for the spell scroll.")
      |> mes("Then yes, that old man would be the perfect person to ask.")
      |> next()
      |> mes("[Echinacea]")
      |> mes(
        "He's from Arunafeltz, and has extensive knowledge in magic as well as sacred power."
      )
      |> mes("I'm sure he'll be able to help you.")
      |> next()
      |> select(["Who?"])

    ctx
    |> mes("[Echinacea]")
    |> mes(
      "Do you see an old man over there? He's trying to make a fire with wet firewood to roast a sweet potato."
    )
    |> mes("His name is Mr. ^4d4dffDefaria^000000.")
    |> next()
    |> mes("[Echinacea]")
    |> mes(
      "Why don't you go show it to him? He might be able to help Mr. Kidd with what he is trying to do."
    )
    |> set_char_var(:mao_morocc2, 14)
    |> changequest(7022, 7023)
    |> close()
  end

  defp reminds_to_consult_defaria(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes("If you're seeking advice about the spell scroll, you should go talk to Mr. Defaria.")
    |> mes("I don't practice magic, so I wouldn't know anything about it.")
    |> close()
  end

  defp checks_tracing_pattern(ctx) do
    ctx =
      if get_char_var(ctx, :mao_morocc2, 0) < 26 do
        reads_the_journal(ctx)
      else
        ctx
      end

    {ctx, pattern} =
      ctx
      |> mes("[Echinacea]")
      |> mes("Say, what's the tracing pattern number?")
      |> next()
      |> input(:string)

    step = get_char_var(ctx, :mao_morocc2, 0)
    quest = if step > 25, do: step - 3, else: step
    patterns = ["SDHF92F-SDF", "VWNM94GVWN90", "CM3-TRDFGHE0"]

    ctx = ctx |> mes("[Echinacea]") |> mes("[#{pattern}]")

    if pattern == Enum.at(patterns, quest - 23, "") do
      accepts_tracing_pattern(ctx, quest)
    else
      rejects_tracing_pattern(ctx, quest)
    end
  end

  defp reads_the_journal(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Echinacea]")
      |> mes("Oh, welcome back.")
      |> mes("How can I help you?")
      |> mes("Oh... You've brought the journal..")
      |> next()
      |> mes("[Echinacea]")
      |> mes(".........")
      |> mes("......")
      |> mes("...")
      |> next()
      |> mes("[Echinacea]")
      |> mes("I see...")
      |> mes("...Basically it all comes down to Rayan.")
      |> mes("He's been abducted by Satan Morocc.")
      |> mes("If we find Rayan using this location-tracing spell.")
      |> next()
      |> select(["We'll find Satan Morocc too!"])

    ctx
    |> mes("[Echinacea]")
    |> mes("That's right.")
    |> mes("But it'll work only if Satan Morocc actually abducted Rayan.")
    |> next()
  end

  defp accepts_tracing_pattern(ctx, quest) do
    ctx =
      ctx
      |> mes("...Ah, there it is.")
      |> next()
      |> mes("[Echinacea]")
      |> mes("This location-tracing spell uses a pair of magic stones of the same wavelength...")
      |> mes(
        "We can use the spell with one stone to find the other stone with the matching wavelength."
      )
      |> next()
      |> mes("[Echinacea]")
      |> mes("We'll analyze this pattern number and detect the wavelength.")
      |> mes("It'll take some time before we get the results.")

    ctx =
      if count_item(ctx, 6029) > 0 do
        delitem(ctx, 6029, count_item(ctx, 6029))
      else
        ctx
      end

    ctx
    |> set_char_var(:mao_morocc2, 29)
    |> changequest(7031 + (quest - 23), 7034)
    |> close()
  end

  defp rejects_tracing_pattern(ctx, quest) do
    ctx =
      ctx
      |> mes("It's not working for some reason.")
      |> mes("I can't find a magic stone that has the same wavelength as yours.")
      |> next()
      |> mes("[Echinacea]")
      |> mes("This location-tracing spell uses a pair of magic stones of the same wavelength..")
      |> mes("I can't find a magic stone that has the same wavelength as your pattern number.")
      |> next()
      |> mes("[Echinacea]")
      |> mes("Go check the number again.")

    ctx =
      if get_char_var(ctx, :mao_morocc2, 0) < 26 do
        set_char_var(ctx, :mao_morocc2, quest + 3)
      else
        ctx
      end

    ctx
    |> close()
  end

  defp awaits_tracing_results(ctx) do
    if Enum.random(1..3) == 2 do
      sends_to_check_results(ctx)
    else
      ctx
      |> mes("[Echinacea]")
      |> mes("Tracing magic wavelength is not easy as you think.")
      |> mes("Please be patient: the results will arrive soon enough.")
      |> close()
    end
  end

  defp sends_to_check_results(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes("Welcome, adventurer.")
    |> mes("I hope they've been able to trace the wavelength by now.")
    |> mes("How'd you like to go check the results?")
    |> next()
    |> mes("[Echinacea]")
    |> mes(
      "To the south of this camp, you'll see a building with a mana detector attached to it."
    )
    |> mes("Go ask the building manager about the trace results.")
    |> set_char_var(:mao_morocc2, 30)
    |> changequest(7034, 7035)
    |> close()
  end

  defp reminds_to_check_results(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes("I'm in charge of tracing the wavelength from the Midgard Continent,")
    |> mes("and the south camp is tracing it in this area.")
    |> next()
    |> mes("[Echinacea]")
    |> mes(
      "I asked them to assign top priority to this task, so with any luck, they've finished it by now."
    )
    |> mes("..What are you doing? I said, go ask the building manager about the trace results.")
    |> close()
  end

  defp rewards_the_pursuit(ctx) do
    ctx =
      ctx
      |> mes("[Echinacea]")
      |> mes("How are the results?")
      |> next()
      |> mes("- You told her exactly what you were told by the soldier managing the building. -")
      |> next()
      |> mes("[Echinacea]")
      |> mes("Oh, is that the case? I see.")
      |> mes(
        "That means.. The man called Rayan isn't on the Midgard Continent or in this Ash Vacuum."
      )
      |> next()
      |> mes("[Echinacea]")
      |> mes("He must be somewhere else.")
      |> mes("As I suspected, he must be with Satan Morocc.")
      |> next()
      |> mes("[Echinacea]")
      |> mes("Pursuing Satan Morocc was supposed to be our last resort..")
      |> mes("...I guess we have no choice now..")
      |> next()
      |> mes("[Echinacea]")
      |> mes("...I should log a report entry into this journal.")
      |> mes("Our pursuit of Satan Morocc is at an end for now.")
      |> next()
      |> mes("[Echinacea]")
      |> mes("You did a great job helping us, and went above and beyond my expectations.")
      |> mes("Here, this is a reward for your help.")
      |> next()
      |> mes("[Echinacea]")
      |> mes("Keep up the good work assisting the explorers in this camp.")
      |> set_char_var(:mao_morocc2, 100)

    ctx =
      if Rathena.truthy?(checkre(ctx, 3)) do
        getexp(ctx, 120_000, 20_000)
      else
        getexp(ctx, 1_200_000, 200_000)
      end

    ctx
    |> give_item(617, 1)
    |> completequest(7036)
    |> close()
  end

  defp asks_what_is_bothering(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Echinacea]")
      |> mes("....")
      |> next()
      |> select(["....."])

    {ctx, _} =
      ctx
      |> mes("[Echinacea]")
      |> mes("Hmm..")
      |> next()
      |> select(["... . .."])

    {ctx, choice} =
      ctx
      |> mes("[Echinacea]")
      |> mes("...Grr...!")
      |> mes("What?! What do you want?")
      |> mes("Why do you keep giving me that dirty look?!")
      |> next()
      |> select(["Nothing.", "Something is bothering me..."])

    case choice do
      1 -> annoyed_by_nothing(ctx)
      2 -> reassures_about_politics(ctx)
      _ -> ctx
    end
  end

  defp annoyed_by_nothing(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes("Argh...!")
    |> mes("Are you annoying me on purpose?")
    |> mes("Go and find something else to do!")
    |> next()
    |> mes("[Echinacea]")
    |> mes(
      "I'm stressed out and I've got a headache writing this report. I don't have the time to deal with you right now."
    )
    |> mes("Do you understand?")
    |> close()
  end

  defp reassures_about_politics(ctx) do
    ctx =
      ctx
      |> mes("[Echinacea]")
      |> mes("What is it that worries you?")
      |> mes("Please, I've got enough worries already.")
      |> next()
      |> mes("[Echinacea]")
      |> mes("So, tell me, what is it?")

    ctx
    |> mes("#{char_name(ctx, 0)}, you've done a great job helping us...")
    |> mes("Oh, you must have questions about that last case, is that right?")
    |> next()
    |> mes("[Echinacea]")
    |> mes("...Wait, are you worried because of him?")
    |> mes("...I see, you're worried about him being supported by the country.")
    |> next()
    |> mes("[Echinacea]")
    |> mes("This isn't a good time to disclose the truth. It'll cause more confusion.")
    |> mes(
      "I believe the diplomats and presidents of both countries are responsible for those national matters."
    )
    |> next()
    |> mes("[Echinacea]")
    |> mes("This is out of your hands, adventurer.")
    |> mes("So stop worrying about it. Alright?")
    |> next()
    |> mes("[Echinacea]")
    |> mes("No country wants to start a war, especially when we have a greater common enemy.")
    |> mes("Just focus on what you can do to help us.")
    |> set_char_var(:mao_morocc2, 101)
    |> setquest(7037)
    |> close()
  end

  defp dismisses_from_service(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes("We've stopped pursuing Satan Morocc, so you may go help the other explorers now.")
    |> mes("I've already rewarded you for your services.")
    |> next()
    |> mes("[Echinacea]")
    |> mes("Remember; don't open your mouth about this to anyone.")
    |> close()
  end

  defp receives_sweet_potatoes(ctx) do
    if count_item(ctx, 549) > 1 do
      accepts_sweet_potatoes(ctx)
    else
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Err? I don't have two Nice Sweet Potatoes..")
      |> mes("Where can I get those?")
      |> close()
    end
  end

  defp accepts_sweet_potatoes(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Echinacea]")
      |> mes("What is it? I thought you've been discharged from my service.")
      |> mes("..What are these sweet potatoes?")
      |> mes("Did that old man send these?")
      |> mes("No way..! Are you..?")
      |> next()
      |> select(["That's right."])

    ctx
    |> mes("[Echinacea]")
    |> mes("What do you not understand?")
    |> mes("Nothing good can come out of this if it's released to the public.")
    |> mes("Can't you see?")
    |> next()
    |> mes("[Echinacea]")
    |> mes("Arunafeltz has replaced their leaders with the moderates just recently.")
    |> mes("Shoving the remnants of the radicals in front of them is extremely dangerous.")
    |> next()
    |> mes("[Echinacea]")
    |> mes("We've finally made a truce with them.")
    |> mes(
      "Their sins will not be forgiven, but we won't make a stupid attempt to get revenge and end up shedding more blood!"
    )
    |> next()
    |> mes("[Echinacea]")
    |> mes("Let the politicians do their job.")
    |> mes(
      "I assure you they won't lead us to the worst case scenario. That's what you're worried about, right?"
    )
    |> next()
    |> mes("[Echinacea]")
    |> mes("No, wait.. Do you..?")
    |> mes("Do you want us to wage war against Arunafeltz over this?!")
    |> next()
    |> mes("[Echinacea]")
    |> mes("Let me ask you to forget the past and focus on the present.")
    |> mes("For everyone's sake, please just look toward the future and move forward.")
    |> next()
    |> mes("[Echinacea]")
    |> mes("We won't do anything that you'd morally oppose.")
    |> mes("You believe in peace, don't you?")
    |> mes("Tell him that I'm grateful for these sweet potatoes, anyway..")
    |> delitem(549, 2)
    |> set_char_var(:mao_morocc2, 107)
    |> changequest(7040, 7041)
    |> close()
  end

  defp looks_to_the_future(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes("Let us take care of the rest.")
    |> mes(
      "I'm not suggesting that we should pretend as if the past never happened. All I'm saying is that we should work towards achieving a greater cause."
    )
    |> close()
  end

  defp encourages_progress(ctx) do
    ctx
    |> mes("[Echinacea]")
    |> mes("You're doing a great job.")
    |> mes("I suppose I have an eye for people after all.")
    |> mes("Yes, that must be right.")
    |> mes("Keep up the good work, will you?")
    |> close()
  end
end
