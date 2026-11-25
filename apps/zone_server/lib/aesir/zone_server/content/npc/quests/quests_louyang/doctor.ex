defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Doctor do
  @moduledoc """
  Guides adventurers through the doctor's medicine errands.

  ## Behavior

  - Introduces pressure points and requests medicine from eligible adventurers.
  - Offers rewards for delivering medicine and gathering further supplies.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in02",
        x: 265,
        y: 69,
        dir: 5,
        sprite: 814,
        name: "Doctor",
        scope: :shared,
        unique_name: "Doctor#lyang"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        overweight(ctx)

      true ->
        quest_dialogue(ctx, get_char_var(ctx, :ch_par, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp quest_dialogue(ctx, 0), do: introduction(ctx)

  defp quest_dialogue(ctx, 1) do
    if base_level(ctx) < 40, do: strength_advice(ctx), else: offer_errand(ctx)
  end

  defp quest_dialogue(ctx, stage) when stage < 4, do: awaiting_medicine(ctx)
  defp quest_dialogue(ctx, 4), do: prescribing_advice(ctx)
  defp quest_dialogue(ctx, stage) when stage < 9, do: patient_wait(ctx)
  defp quest_dialogue(ctx, 9), do: medicine_delivery(ctx, :first)
  defp quest_dialogue(ctx, 10), do: strength_advice(ctx)
  defp quest_dialogue(ctx, stage) when stage < 15, do: gathering_thanks(ctx, "Ah...")
  defp quest_dialogue(ctx, 15), do: gathering_thanks(ctx, "Ah....")
  defp quest_dialogue(ctx, 16), do: medicine_delivery(ctx, :later)
  defp quest_dialogue(ctx, 17), do: supply_delivery(ctx)
  defp quest_dialogue(ctx, _stage), do: health_advice(ctx)

  defp overweight(ctx) do
    ctx
    |> mes(
      "^3355FFWait a minute! Right now, you're over weight, so you cannot receive more items. Please store some of your things in Kafra Storage and try again.^000000"
    )
    |> close()
  end

  defp introduction(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes(
      "There are many pressure points on the human body. Ever since ancient times, it has been believed that each pressure point was limited"
    )
    |> mes("to its role and functions.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "However, as I studied and experimented with every pressure point, I came to the conclusion that the use of pressure points, depending on the circumstances,"
    )
    |> mes("can produce different results.")
    |> emotion(:surprise)
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "Few pressure points tend to show the same symptoms, regardless of the problem. Most of the time, the effects of pressure points will differ depending on the body's health or the time of day."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "For instance, the pressure point located on the upper side of navel is the most vulnerable point."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "If pressed the wrong way, it can cause death. But between 5:15 am and 7:15 am, it's just a weak point."
    )
    |> set_char_var(:ch_par, 1)
    |> close()
  end

  defp strength_advice(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("Being strong as a person is not defined as mere physical strength.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Factors such as intelligence, experience and knowledge are")
    |> mes("also considered when judging one's strength.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Let's say you're very strong and given the most powerful weapon.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "If you don't know how to use the weapon's power, you will not be strong... You will be weak."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("When the tools or weapons")
    |> mes("overwhelm your capabilities,")
    |> mes("the worst situations result.")
    |> close()
  end

  defp offer_errand(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hua Tuo]")
      |> mes("Hmmm...")
      |> mes("I'm in trouble...")
      |> next()
      |> mes("[Hua Tuo]")
      |> mes("I cannot do anything without my medicine. But one my patients")
      |> mes("needs immediate treatment and")
      |> mes("I can't leave the office...")
      |> emotion(:profusely_sweat)
      |> next()
      |> select(["I can help you.", "What a shame!"])

    if choice == 1, do: confirm_errand(ctx), else: decline_errand(ctx)
  end

  defp confirm_errand(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hua Tuo]")
      |> mes("Huh...?")
      |> mes("Are...")
      |> mes("Are you serious?")
      |> next()
      |> mes("[Hua Tuo]")
      |> mes(
        "This won't take much effort, but it may be too much to ask this of you, especially since we have just met."
      )
      |> next()
      |> select(["If you feel burdened...", "I don't mind, I'd be glad to help."])

    if choice == 1, do: defer_errand(ctx), else: accept_errand(ctx)
  end

  defp defer_errand(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("Thank you so")
    |> mes("much for saying that.")
    |> mes("I feel very uncomfortable asking a favor of someone I have only just met.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("However, I will ask you")
    |> mes("if we meet another time.")
    |> mes("Now, if you'll excuse me...")
    |> emotion(:thanks)
    |> close()
  end

  defp accept_errand(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("Hmm, I see.")
    |> mes("Well then, let me")
    |> mes("ask a favor of you.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("As you heard earlier, I need")
    |> mes(
      "a special medicine to treat this patient. However, I'm running out of the medicine I need."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "I will need you to get it for me since I cannot leave the patients that are waiting for me right now."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("^666666*Sigh*^000000")
    |> mes("Misfortunes always seem")
    |> mes(
      "to occur one after another, don't they? My staff is currently too busy doing other errands."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Please visit the")
    |> mes("Tool Shop in town and bring me")
    |> mes(
      "the medicine that I need. Master will understand if you tell him you've been sent by me."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("I am sorry for causing you")
    |> mes(
      "so much trouble, but if you'll excuse me, I have other patients waiting. Please hurry back with"
    )
    |> mes("the medicine!")
    |> set_char_var(:ch_par, 2)
    |> setquest(11044)
    |> close()
  end

  defp decline_errand(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes(
      "^666666*Sigh*^000000 For some reason, I never seem to have enough medicine in stock. Is there no one I can ask to help me?"
    )
    |> close()
  end

  defp awaiting_medicine(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("You haven't gotten")
    |> mes("the medicine yet...?")
    |> mes("I hope you can get it")
    |> mes("as soon as you can...")
    |> close()
  end

  defp prescribing_advice(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("In order to prescribe medicine")
    |> mes("and apply acupuncture suited to")
    |> mes("a patient, I must first consider many different factors related to health.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "I must be especially careful if the patient is in critical condition or is exhibiting unusual symptoms."
    )
    |> close()
  end

  defp patient_wait(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("Umm.....")
    |> mes("Is that so...?")
    |> mes("I can understand if you")
    |> mes("take your time to bring the item. There's no need to rush.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Everybody has their own")
    |> mes("worries, and I understand if your own problems must take priority.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Still, it's good")
    |> mes("to put yourself in someone")
    |> mes("else's shoes sometimes.")
    |> close()
  end

  defp medicine_delivery(ctx, visit) do
    if count_item(ctx, 7252) < 1 do
      missing_medicine(ctx, visit)
    else
      request_more_medicine(ctx, visit)
    end
  end

  defp missing_first_medicine(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("Umm.....")
    |> mes("Is that so...?")
    |> mes("I can understand if you")
    |> mes("take your time in bringing what I need. There's no rush.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Everybody has their own")
    |> mes("worries, and I understand if your own problems must take priority.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Still, it's good")
    |> mes("to put yourself in someone")
    |> mes("else's shoes sometimes.")
    |> close()
  end

  defp missing_later_medicine(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("Umm.....")
    |> mes("Is that so...?")
    |> mes("I understand even")
    |> mes("if you can't bring")
    |> mes("the medicine right away.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("It's okay for now,")
    |> mes("so don't rush yourself.")
    |> mes(
      "Everybody has their own problems, so I can understand if your own troubles must take priority."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "Still, it's good to see that you're understanding of the troubles other people are having."
    )
    |> close()
  end

  defp missing_medicine(ctx, :first), do: missing_first_medicine(ctx)
  defp missing_medicine(ctx, :later), do: missing_later_medicine(ctx)

  defp request_more_medicine(ctx, :first) do
    {ctx, choice} =
      ctx
      |> mes("[Hua Tuo]")
      |> mes("Ah...")
      |> mes("You've finally")
      |> mes("brought it to me!")
      |> mes("Thank you so much,")
      |> mes("I feel much more relieved...")
      |> next()
      |> mes("[Hua Tuo]")
      |> mes("I apologize")
      |> mes("in advance,")
      |> mes("but may I ask")
      |> mes("another favor of you?")
      |> next()
      |> mes("[Hua Tuo]")
      |> mes("I am asking you once more")
      |> mes(
        "as now I see that you are trustworthy. Of course, I will compensate you for your trouble."
      )
      |> next()
      |> select(["I'm sorry, I can't help you.", "No problem."])

    if choice == 1, do: first_reward(ctx), else: first_supply_request(ctx)
  end

  defp request_more_medicine(ctx, :later) do
    {ctx, choice} =
      ctx
      |> mes("[Hua Tuo]")
      |> mes("Ah, finally...")
      |> mes(
        "You've brought what I need. Thank you so much, it's such a relief to have this medicine onhand again."
      )
      |> next()
      |> mes("[Hua Tuo]")
      |> mes("I apologize in advance,")
      |> mes("but may I ask you another favor?")
      |> mes(
        "I am asking for your help once more, since I know I can depend on you. Of course, I will compensate you for your trouble."
      )
      |> next()
      |> select(["I'm sorry...", "No problem."])

    if choice == 1, do: later_reward(ctx), else: later_supply_request(ctx)
  end

  defp first_reward(ctx) do
    ctx =
      ctx
      |> mes("[Hua Tuo]")
      |> mes("Alright....")
      |> mes("I understand.")
      |> mes("But let me thank you")
      |> mes("for helping me out.")
      |> mes("Please take this...")
      |> next()
      |> mes("[Hua Tuo]")
      |> mes("This medicine is not that")
      |> mes(
        "great, but it's an old family secret. I hope it will be useful to you if you find yourself in great danger."
      )
      |> delitem(7252, 1)
      |> set_char_var(:ch_par, 10)
      |> completequest(11056)
      |> give_item(679, 2)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)), do: 1000, else: 10000),
      0
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Well then,")
    |> mes("I will see")
    |> mes("you around.")
    |> mes("Once again, thank")
    |> mes("you for your help.")
    |> close()
  end

  defp first_supply_request(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("Thank you,")
    |> mes("thank you so much!")
    |> mes(
      "I just ran out of some other medicines again, and I hope that you can assist me once more."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("I hope that I am not causing")
    |> mes("you too much trouble. Um, so the medicines I'll need are...")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "^0000ff2 Leopard Claw^000000 which strengthen bones, ^0000ff10 Solid Peach^000000 which strengthens muscle, ^0000ff5 Poisonous Toad Skin^000000 which replenishes the skin..."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "^0000ff20 Brown Root^000000 which regulates the heart, ^0000ff10 Sprout^000000 which eases the abdomen and ^0000ff5 Honey Pot^000000 which provides nutrition."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("I hope you were")
    |> mes("able to memorize all")
    |> mes("of that. Once again, that's...")
    |> next()
    |> list_supplies()
    |> set_char_var(:ch_par, 17)
    |> changequest(11056, 11057)
    |> close()
  end

  defp later_reward(ctx) do
    ctx =
      ctx
      |> mes("[Hua Tuo]")
      |> mes("Alright....")
      |> mes("I understand.")
      |> mes("But thank you for")
      |> mes("helping me out.")
      |> mes("Please take this...")
      |> next()
      |> mes("[Hua Tuo]")
      |> mes("It's not much, but this medicine")
      |> mes(
        "is an old family secret. I hope that it will be of use to you in dangerous situations."
      )
      |> delitem(7252, 1)
      |> set_char_var(:ch_par, 10)
      |> completequest(11056)
      |> give_item(679, 2)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)),
        do: 1000,
        else: 10000
      ),
      0
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Well then, I will see you around. Once again, I'd like to thank you for your help.")
    |> close()
  end

  defp later_supply_request(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("Thank you, thank you so much!")
    |> mes(
      "I've just run out of other medicines that my patients will be needing. I don't need too much, but you would be doing me a great favor."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "The medicines I need are ^0000ff2 Leopard Claw^000000 which supports the bones, ^0000ff10 Solid Peach^000000 which strengthens the muscle, ^0000ff5 Poisonous Toad Skin^000000 which replenishes the skin..."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "^0000ff20 Brown Root^000000 which regulates the heart, ^0000ff10 Sprout^000000 which eases the abdomen and ^0000ff5 Honey Pot^000000 which provides nutrition."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("I hope you've")
    |> mes("memorized it all.")
    |> mes("Once again, that's...")
    |> next()
    |> list_supplies()
    |> set_char_var(:ch_par, 17)
    |> close()
  end

  defp gathering_thanks(ctx, greeting) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes(greeting)
    |> mes(
      "Did you just say you're going to gather all the items soon? Oh, thank you for your kindness."
    )
    |> mes("I appreciate your effort")
    |> mes("on my behalf.")
    |> close()
  end

  defp supply_delivery(ctx) do
    if count_item(ctx, 7172) > 1 and count_item(ctx, 7164) > 9 and
         count_item(ctx, 7155) > 4 and count_item(ctx, 7188) > 19 and
         count_item(ctx, 7193) > 9 and count_item(ctx, 7121) > 4 do
      complete_delivery(ctx)
    else
      missing_supplies(ctx)
    end
  end

  defp complete_delivery(ctx) do
    ctx =
      ctx
      |> mes("[Hua Tuo]")
      |> mes("Hm? Ah, you have returned.")
      |> mes(
        "Sorry, I was taking care of my other patients. Have you already gathered the medicines I'll need?"
      )
      |> next()
      |> mes("[Hua Tuo]")
      |> mes("Let's see...")
      |> mes("Oh, you've brought them all.")
      |> mes("Thank you so much for your")
      |> mes("generous help. It's such a relief to have these medicines available again...")
      |> next()
      |> mes("[Hua Tuo]")
      |> mes(
        "Please take this as a token of my appreciation. It's not much, but this medicine is an old family secret. I hope it will be helpful to you in dangerous situations."
      )
      |> delitem(7172, 2)
      |> delitem(7164, 10)
      |> delitem(7155, 5)
      |> delitem(7188, 20)
      |> delitem(7193, 10)
      |> delitem(7121, 5)
      |> delitem(7252, 1)
      |> set_char_var(:ch_par, 18)
      |> completequest(11057)
      |> give_item(679, 5)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)),
        do: 10000,
        else: 30000
      ),
      0
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "However, please remember not to take more than the recommended dosage for the pills I have given you. Even medicine, in the wrong doses, can become poison to the body."
    )
    |> close()
  end

  defp missing_supplies(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("Hmm...")
    |> mes(
      "Unfortunately, you haven't collected everything that I need yet. Once again, please gather..."
    )
    |> next()
    |> list_supplies()
    |> close()
  end

  defp list_supplies(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("^3355FF2 Leopard Claw^000000,")
    |> mes("^3355FF10 Solid Peach^000000,")
    |> mes("^3355FF5 Poisonous Toad Skin^000000,")
    |> mes("^3355FF20 Brown Root^000000,")
    |> mes("^3355FF10 Sprout^000000 and")
    |> mes("^3355FF5 Honey Pot^000000.")
  end

  defp health_advice(ctx) do
    ctx
    |> mes("[Hua Tuo]")
    |> mes("Your health is affected by")
    |> mes("many factors. Nutricious food and medicine alone cannot guarantee")
    |> mes("a healthy lifestyle.")
    |> next()
    |> mes("[Hua Tuo]")
    |> mes(
      "Seemingly little things like your everyday mood and behavior, your thoughts and words also contribute to states of illness or well-being."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Everyone needs time to quiet")
    |> mes(
      "their thoughts and relax. If you can maintain a calm mood throughout your daily life, your body will greatly benefit."
    )
    |> next()
    |> mes("[Hua Tuo]")
    |> mes("Hahaha...")
    |> mes("I hope you enjoy")
    |> mes("your visit here")
    |> mes("in Luoyang.")
    |> close()
  end
end
