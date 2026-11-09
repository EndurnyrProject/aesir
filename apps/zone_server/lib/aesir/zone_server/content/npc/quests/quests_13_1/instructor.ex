defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Instructor do
  @moduledoc """
  Instructor Lugen guides expedition recruits, assigns camp deliveries, and asks after his friend Otto.

  ## Behavior

  - Refuses overburdened players and waits for Marian's introduction before offering registration;
    declining allows reconsideration, including the repeated instructor heading on rejoining.
  - Assigns barracks after registration and gives a Chocolate Pie, then sends the player to Marian
    for supplies with another pie before any deliveries are completed.
  - Requires at least three, two, then one Supply Boxes while directing deliveries to Jan, Gerard, and
    Alberto; missing supplies send the player back to Marian without advancing the quest.
  - After the deliveries, shares his worries about Otto on one in three visits. Helping starts
    a letter errand; merely listening lets the player offer help again on a later visit.
  - Replaces a lost outgoing letter. Taking Otto's reply completes the errand, consumes the reply,
    and rewards an Old Violet Box, five Chocolate Pies, and mode-dependent experience.
  - Greets returning players at step 100; unmatched quest steps use his busy greeting.

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
        map: "mid_camp",
        x: 261,
        y: 284,
        dir: 4,
        sprite: 405,
        name: "Instructor",
        scope: :shared,
        unique_name: "Instructor#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @weight_check_item 1201
  @chocolate_pie 12_322
  @supplies 6045
  @lugens_letter 6043
  @ottos_letter 6044
  @old_violet_box 617

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{@weight_check_item, 1}]) == 0 ->
        overloaded(ctx)

      get_char_var(ctx, :ep13_newbs, 0) < 1 ->
        awaits_reinforcements(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 1 ->
        invites_to_register(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 2 ->
        invites_again(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 3 ->
        awaits_registration(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 4 ->
        assigns_barracks(ctx)

      get_char_var(ctx, :ep13_newbs, 0) > 4 and get_char_var(ctx, :ep13_newbs, 0) < 12 ->
        asks_about_barrack_mates(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 12 ->
        assigns_supply_deliveries(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 13 ->
        asks_for_marian(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 14 ->
        checks_supplies_for_jan(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 15 ->
        awaits_jan_delivery(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 16 ->
        assigns_gerard_delivery(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 17 ->
        awaits_gerard_delivery(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 18 ->
        assigns_alberto_delivery(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 19 ->
        awaits_alberto_delivery(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 20 ->
        thanks_for_deliveries(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 21 ->
        shares_worries(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 22 ->
        offers_help_again(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 23 ->
        awaits_otto_letter_delivery(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 24 ->
        receives_otto_reply(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 100 ->
        welcomes_back(ctx)

      true ->
        too_busy(ctx)
    end
  end

  defp overloaded(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("You are carrying too much weight.")
    |> mes("Please try again after losing some weight.")
    |> close()
  end

  defp awaits_reinforcements(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("Huuu, no time to rest.")
    |> mes("When re-enforcements come.")
    |> close()
  end

  defp invites_to_register(ctx) do
    ctx =
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("Huuu, no time to rest.")
      |> mes("When re-enforcements come.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Excuse me.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Hi!")
      |> mes("What brings you here?")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Marian sent me to here.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Ah!")
      |> mes("Are you from the motherland?")
      |> mes("I am Lugen Jednic from.")
      |> mes("the federal survey team,")
      |> mes("in charge of educating.")
      |> mes("new employees.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("To join the team,")
      |> mes("you simply need to register.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Once you register, you")
      |> mes("will be provided with")
      |> mes("ccommodations and food.")
      |> mes("There will be plenty of")
      |> mes("missions for you.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Will you join the survey team?")
      |> next()
      |> select(["Yes.", "No."])

    case choice do
      1 -> explains_registration(ctx)
      2 -> declines_registration(ctx)
      _ -> ctx
    end
  end

  defp invites_again(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("Ah, you came back.")
      |> mes("I have been waiting for you.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Will ou join the survey team?")
      |> next()
      |> select(["Yes.", "No."])

    case choice do
      1 -> agrees_to_register(ctx)
      2 -> declines_again(ctx)
      _ -> ctx
    end
  end

  defp awaits_registration(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("To register, Go to the")
    |> mes("big building in the center")
    |> mes("and talk to the receptionist.")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("When you finish the")
    |> mes("registration, come back")
    |> mes("to me and I will assign")
    |> mes("your accomodations.")
    |> close()
  end

  defp assigns_barracks(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("I got a call from the receptionist.")
    |> mes("Now take your nameplate and go")
    |> mes("to your accomodations down")
    |> mes("in the barracks.")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("So take some rest and I will")
    |> mes("see you tomorrow morning.")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("You need to share the barracks")
    |> mes("with others, so make sure to")
    |> mes("talk with them while you're there.")
    |> set_char_var(:ep13_newbs, 5)
    |> give_item(@chocolate_pie, 1)
    |> completequest(11_086)
    |> close()
  end

  defp asks_about_barrack_mates(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("You need to share the barracks")
    |> mes("with others, so make sure to")
    |> mes("talk with them while you're there.")
    |> close()
  end

  defp assigns_supply_deliveries(ctx) do
    ctx =
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("How was your stay here?")
      |> mes("It is cold. Warm yourself")
      |> mes("and try not to catch a cold.")
      |> next()
      |> mes("[Instructor Lugen]")

    ctx
    |> mes("And I have a request of you, #{char_name(ctx, 0)}.")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("It is to distribute supplies")
    |> mes("from the motherland,")
    |> mes("It's not very difficult.")
    |> mes("Just think of it as a way")
    |> mes("to meet people here.")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("Anyway, Go to Marian,")
    |> mes("whom you met when")
    |> mes("you first came here and")
    |> mes("get the supplies from her.")
    |> set_char_var(:ep13_newbs, 13)
    |> give_item(@chocolate_pie, 1)
    |> setquest(11_091)
    |> close()
  end

  defp asks_for_marian(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("Anyway, Go to Marian,")
    |> mes("whom you met when")
    |> mes("you first came here and")
    |> mes("get the supplies from her.")
    |> close()
  end

  defp checks_supplies_for_jan(ctx) do
    if count_item(ctx, @supplies) > 2 do
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("Did you receive the supplies?")
      |> mes("Can you show them to me, please?")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Hmm...")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Ok, then, please deliver")
      |> mes("them to their receivers.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("The first box should be sent to")
      |> mes("Jan, northwest of the camp.")
      |> mes("She may be around the fence.")
      |> set_char_var(:ep13_newbs, 15)
      |> changequest(11_092, 11_093)
      |> close()
    else
      missing_supplies(ctx)
    end
  end

  defp awaits_jan_delivery(ctx) do
    if count_item(ctx, @supplies) > 2 do
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("The first box should be sent to")
      |> mes("Jan, northwest of the camp.")
      |> mes("She may be around the fence.")
      |> close()
    else
      missing_supplies(ctx)
    end
  end

  defp assigns_gerard_delivery(ctx) do
    ctx =
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("So, did you get the")
      |> mes("supplies to Jan?")
      |> mes("She was waiting")
      |> mes("for it a month ago.")
      |> mes("Thanks so much.")
      |> next()

    if count_item(ctx, @supplies) > 1 do
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("Next, this box is for Gerard.")
      |> mes("He is investigating across the")
      |> mes("west bridge outside the camp.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Freya be with you.")
      |> set_char_var(:ep13_newbs, 17)
      |> changequest(11_094, 11_095)
      |> close()
    else
      missing_supplies(ctx)
    end
  end

  defp awaits_gerard_delivery(ctx) do
    if count_item(ctx, @supplies) > 1 do
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("Next, this box is for Gerard.")
      |> mes("He is investigating across the")
      |> mes("west bridge outside the camp.")
      |> close()
    else
      missing_supplies(ctx)
    end
  end

  defp assigns_alberto_delivery(ctx) do
    ctx =
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("Well done.")
      |> mes("Is Gerard well?")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("I've been worrying")
      |> mes("about him since he")
      |> mes("disappeared after")
      |> mes("going out for the")
      |> mes("investigation.")
      |> next()

    if count_item(ctx, @supplies) > 0 do
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("And the last box is for")
      |> mes("Alberto at the entrance")
      |> mes("of the eastern field.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Perhaps, he ordered")
      |> mes("the heavy coat.")
      |> mes("It's freezing there so")
      |> mes("you'd better hurry.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Please deliver it to him.")
      |> set_char_var(:ep13_newbs, 19)
      |> changequest(11_096, 11_097)
      |> close()
    else
      missing_supplies(ctx)
    end
  end

  defp awaits_alberto_delivery(ctx) do
    if count_item(ctx, @supplies) > 0 do
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("And the last box is for")
      |> mes("Alberto at the entrance")
      |> mes("of the eastern field.")
      |> close()
    else
      missing_supplies(ctx)
    end
  end

  defp thanks_for_deliveries(ctx) do
    ctx = ctx |> mes("[Instructor Lugen]") |> mes("It was really good to request")

    ctx
    |> mes("you, #{char_name(ctx, 0)}.")
    |> mes("Your work has been")
    |> mes("a great help to us.")
    |> mes("I really appreciate it.")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("You must be tired now,")
    |> mes("please take care of yourself.")
    |> mes("I have more things")
    |> mes("to do now, ha...")
    |> emotion(:hng)
    |> set_char_var(:ep13_newbs, 21)
    |> completequest(11_098)
    |> close()
  end

  defp shares_worries(ctx) do
    if Enum.random(1..3) == 2 do
      describes_worries(ctx)
    else
      sighs(ctx)
    end
  end

  defp describes_worries(ctx) do
    ctx =
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("There must be no")
      |> mes("time to rest for me.")
      |> mes("Huu...~")
      |> emotion(:hng)
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What is wrong with you?")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Ah, nothing...")
      |> mes("I'm just talking to myself.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I've never seen you sigh.")
      |> mes("If you have something")
      |> mes("to say please tell me.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("It's just a personal thing...")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Tell me.")
      |> mes("I think I can help you.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("I-I'm, sorry to tell you but...")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("I came here together")
      |> mes("with my friend but we")
      |> mes("aren't allowed to leave,")
      |> mes("so I don't know how he is.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("It was rumored that")
      |> mes("he's gotten worse so")
      |> mes("I'm worried about him.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("But, I'm so busy working")
      |> mes("and it makes me...")
      |> mes("*sigh*")
      |> next()
      |> select(["Help.", "Just listen."])

    case choice do
      1 -> offers_to_deliver_letter(ctx)
      2 -> listens_to_worries(ctx)
      _ -> ctx
    end
  end

  defp sighs(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("There must be no")
    |> mes("time to rest for me.")
    |> mes("Huu...~")
    |> emotion(:hng)
    |> close()
  end

  defp offers_help_again(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("There must be no")
      |> mes("time to rest for me.")
      |> mes("Huu...~")
      |> emotion(:hng)
      |> next()
      |> select(["Help him.", "Just pass."])

    case choice do
      1 -> insists_on_helping(ctx)
      2 -> passes_by(ctx)
      _ -> ctx
    end
  end

  defp awaits_otto_letter_delivery(ctx) do
    if count_item(ctx, @lugens_letter) < 1 do
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("Ah, did you lose the letter?")
      |> mes("That's ok. It's no big deal.")
      |> mes("I'll write it again.")
      |> give_item(@lugens_letter, 1)
      |> close()
    else
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("My friend, Otto, is working")
      |> mes("on the barrier in the west.")
      |> mes("Please give it to him.")
      |> close()
    end
  end

  defp receives_otto_reply(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Instructor! I met Otto!")
      |> mes("He is doing very well~")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("Phew, it's really good to hear.")
      |> mes("I was so worried about him")
      |> mes("being sick and far away")
      |> mes("from his homeland.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I have a letter from him, too.")
      |> next()

    if count_item(ctx, @ottos_letter) < 1 do
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Huh, ehh..?!?!")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("......")
      |> close()
    else
      ctx =
        ctx
        |> mes("[Instructor Lugen]")
        |> mes("I am far away from my home")
        |> mes("the feeling that family and")
        |> mes("friends give to me are really important.")
        |> next()
        |> mes("[Instructor Lugen]")
        |> mes("I don't know how to thank you.")
        |> next()

      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Hehe, don't mention it.")
        |> mes("And Otto said that he")
        |> mes("would come to see you.")

      ctx =
        ctx
        |> emotion(:shy, playerattached(ctx))
        |> next()
        |> mes("[Instructor Lugen]")
        |> mes("Did he?")
        |> mes("It's been so long")
        |> mes("since we last met.")
        |> next()
        |> mes("[Instructor Lugen]")
        |> mes("And this is for you.")
        |> delitem(@ottos_letter, 1)
        |> set_char_var(:ep13_newbs, 100)
        |> give_item(@old_violet_box, 1)
        |> give_item(@chocolate_pie, 5)

      ctx =
        if Rathena.truthy?(checkre(ctx, 3)) do
          getexp(ctx, 100_000, 10_000)
        else
          getexp(ctx, 1_000_000, 100_000)
        end

      ctx
      |> completequest(11_100)
      |> close()
    end
  end

  defp welcomes_back(ctx) do
    ctx =
      ctx
      |> mes("[Instructor Lugen]")
      |> mes("Thanks for doing that.")
      |> mes("My friend wrote me that he")
      |> mes("would have some spare time.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("It is good to see you,")

    ctx =
      ctx
      |> mes("#{char_name(ctx, 0)},")
      |> mes("enjoy yourself here.")
      |> mes("If you have any troubles,")
      |> mes("come to see me.")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("I so happy that I've")
      |> mes("met a person like")

    ctx
    |> mes("you, #{char_name(ctx, 0)}.")
    |> close()
  end

  defp too_busy(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("It seems that I nave no time to rest this week.")
    |> close()
  end

  defp missing_supplies(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("It seems that they")
    |> mes("are not enough.")
    |> mes("Can you check them")
    |> mes("with Marian, please?")
    |> close()
  end

  defp explains_registration(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("Registration is simple.")
    |> mes("Go to the big building.")
    |> mes("in the center and talk")
    |> mes("to the receptionist.")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("When you finish the")
    |> mes("registration, come back")
    |> mes("to me and I will assign")
    |> mes("your accomodations.")
    |> set_char_var(:ep13_newbs, 3)
    |> changequest(11_084, 11_085)
    |> close()
  end

  defp declines_registration(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("You don't want to join?")
    |> mes("If you change your mind, come back later.")
    |> set_char_var(:ep13_newbs, 2)
    |> close()
  end

  defp agrees_to_register(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I will register...")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("[Instructor Lugen]")
    |> mes("Registration is simple.")
    |> mes("Go to the big building.")
    |> mes("in the center and talk")
    |> mes("to the receptionist.")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("When you finish the")
    |> mes("registration, come back")
    |> mes("to me and I will assign")
    |> mes("your accomodations.")
    |> set_char_var(:ep13_newbs, 3)
    |> changequest(11_084, 11_085)
    |> close()
  end

  defp declines_again(ctx) do
    ctx
    |> mes("[Instructor Lugen]")
    |> mes("You don't want to join?")
    |> mes("If you change your mind, come back later.")
    |> close()
  end

  defp offers_to_deliver_letter(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I will help with your problem!")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("No, it is ok.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Don't say no!")
      |> mes("It's not a problem at all!")
      |> mes("So, I'll go to him for you")
      |> mes("and see if he is ok, alright?!")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("......")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hey, I really want to help~")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("......")
      |> mes("I really appreciate that.")
      |> mes("If so, can you please")
      |> mes("deliver this letter to him?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("You can count on me!!")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("My friend, Otto, is working")
    |> mes("on the barrier in the west.")
    |> mes("Please give it to him.")
    |> set_char_var(:ep13_newbs, 23)
    |> give_item(@lugens_letter, 1)
    |> setquest(11_099)
    |> close()
  end

  defp listens_to_worries(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Ah, ya work is tough.")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("Yes.. I really appreciate your listening to me.")
    |> mes("It makes me feel better.")
    |> set_char_var(:ep13_newbs, 22)
    |> close()
  end

  defp insists_on_helping(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("May I help you?")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("No, it's ok.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Don't say no!")
      |> mes("It is not difficult at all!")
      |> mes("So, I'm supposed to go to him and see if he's ok, right?")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("......")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hey, I really want to help~")
      |> next()
      |> mes("[Instructor Lugen]")
      |> mes("......")
      |> mes("I really appreciate that.")
      |> mes("If so, can you please deliver this letter to him?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("You believe me!!")
    |> next()
    |> mes("[Instructor Lugen]")
    |> mes("My friend, Otto, is working on the barrier in the west.")
    |> mes("Please give it to him.")
    |> set_char_var(:ep13_newbs, 23)
    |> give_item(@lugens_letter, 1)
    |> setquest(11_099)
    |> close()
  end

  defp passes_by(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Hmm...")
    |> close()
  end
end
