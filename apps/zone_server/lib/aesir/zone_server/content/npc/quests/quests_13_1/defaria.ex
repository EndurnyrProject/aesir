defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Defaria do
  @moduledoc """
  Defaria, the Arunafeltz scholar at the expedition camp who unseals Echinacea's spell scroll
  and then trades information about the Dandelions for sweet potatoes and firewood.

  ## Behavior

  - Refuses the conversation while the player carries too many items.
  - `mao_morocc2` below 14 shows him failing to light wet firewood, and 14 takes the sealed
    scroll: agreeing to keep it unofficial (quest 7023 to 7024) advances to 15.
  - 15 collects 30 Holy Waters, 30 Runes of Darkness, 30 Bloody Runes and the Seal Scroll (quest
    7024 to 7025), 16 needs one of three random rolls to hand over the Unsealed Magic Spell (7025
    to 7026), and 17 only tells the player to use it.
  - 101 asks for the group behind the case and, on "Dandelion", either gives in to the old man's
    request for 20 Sweet Potatoes and 30 Logs (quest 7037 to 7038) or takes two slap damage
    blows. 102 takes the goods (step 103).
  - 103 to 107 hand over the Nice Sweet Potatoes (7038 to 7039, 7039 to 7040), tell the history
    of the Dandelions, and finally give five Baked Yams and complete quest 7041.
  - Above 108 he only stands lost in thought, and any other step asks to be left alone.

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
        x: 256,
        y: 272,
        dir: 3,
        sprite: 897,
        name: "Defaria",
        scope: :shared,
        unique_name: "Defaria#moc2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @wet_firewood "Wet Firewood#moc2"
  @holy_water 523
  @rune_of_darkness 7511
  @bloody_rune 7563
  @seal_scroll 6028
  @unsealed_spell 14595
  @sweet_potato 516
  @log 7201
  @nice_sweet_potato 549
  @baked_yam 633

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{714, 1}]) == 0 do
      overloaded(ctx)
    else
      at_step(ctx, get_char_var(ctx, :mao_morocc2, 0))
    end
  end

  defp at_step(ctx, step) do
    cond do
      step < 14 ->
        ctx
        |> lights_the_wood(".....", "- The fire sparked, but then it immediatly blew out. -")
        |> counts_the_attempts()

      step == 14 ->
        takes_the_scroll(ctx)

      step == 15 ->
        collects_the_reagents(ctx)

      step == 16 ->
        unseals_the_scroll(ctx)

      step == 17 ->
        explains_the_spell(ctx)

      step == 101 ->
        asks_about_dandelion(ctx)

      step == 102 ->
        collects_the_firewood(ctx)

      step == 103 ->
        hands_over_the_potatoes(ctx)

      step == 104 ->
        hurries_to_mr_kidd(ctx)

      step == 105 ->
        tells_about_dandelion(ctx)

      step == 106 ->
        hurries_to_echinacea(ctx)

      step == 107 ->
        rewards_the_player(ctx)

      step > 108 ->
        lost_in_thought(ctx)

      true ->
        asks_to_be_left_alone(ctx)
    end
  end

  defp overloaded(ctx) do
    ctx
    |> mes("- You cannot proceed with the quest when you're carrying too many items with you. -")
    |> close()
  end

  defp asks_to_be_left_alone(ctx) do
    ctx
    |> mes("[Defaria]")
    |> mes("Please leave me alone unless you have extremely important business with me.")
    |> mes("I have so many things that I want to do...")
    |> close()
  end

  defp lost_in_thought(ctx) do
    ctx
    |> mes("- Defaria is lost in thought, standing with a poker in one hand")
    |> mes("and a sweet potato in the other. -")
    |> next()
    |> mes(
      "- Sometimes, he looks to the sky, sighs, and then says, 'I'm envious of young people these days ..'"
    )
    |> mes("or something like 'I don't care anymore, no matter what happens.' -")
    |> next()
    |> mes("- It sounds like he's having some pretty deep moments, so let's not disturb him. -")
    |> close()
  end

  defp counts_the_attempts(ctx) do
    ctx
    |> mes("You know, that was my ninety-third attempt to make a fire with wet firewood.")
    |> next()
    |> mes("[Defaria]")
    |> mes("Wait, was that the ninty fourth ot ninety fifth?")
    |> mes("..I've.. I've lost count.")
    |> close()
  end

  # The reference repeats this scene on the first two steps, differing only in the trailing dots,
  # one word of the spark line, and what follows it.
  defp lights_the_wood(ctx, dots, spark) do
    ctx
    |> mes("[Defaria]")
    |> mes("Please step aside.")
    |> mes("I'm experiencing a turning point in my life right now.")
    |> mes(dots)
    |> specialeffect(:beginspell2)
    |> next()
    |> mes(spark)
    |> specialeffect(:firearrow, :area, @wet_firewood)
    |> next()
    |> mes("[Defaria]")
    |> mes("...............")
  end

  defp takes_the_scroll(ctx) do
    ctx =
      ctx
      |> lights_the_wood("......", "- The fire sparked, but then it immediately blew out.-")
      |> mes("Are you also here...............")
      |> mes("to make fun of my stupid attempt to roast these sweet potatoes with wet firewood?")
      |> next()
      |> select(["...No."])
      |> elem(0)

    {ctx, choice} =
      ctx
      |> mes("[Defaria]")
      |> mes("...No? Then what brings you here?")
      |> mes("...Huh?")
      |> mes("A spell scroll? May I see?")
      |> next()
      |> mes("[Defaria]")
      |> mes("...Isn't... Isn't this?!")
      |> mes("...Hmm...")
      |> mes("Eek... So Echinacea referred you to me, huh?")
      |> mes("...Does that means she knows everything...?")
      |> next()
      |> mes("[Defaria]")
      |> mes("...Alright then, I'll tell you.")
      |> mes("As you can see, this scroll is sealed.")
      |> mes("It can only be unsealed by a secret method.")
      |> mes("...And...")
      |> next()
      |> mes("[Defaria]")
      |> mes("...It is from....")
      |> mes("...Arunafeltz?")
      |> mes("The way it's sealed is the same method used by the temple...")
      |> next()
      |> mes("[Defaria]")
      |> mes("I don't know how you've gotten this scroll,")
      |> mes("...but I'll try to help you on behalf of the respectable scholars of Arunafeltz.")
      |> next()
      |> mes("[Defaria]")
      |> mes(
        "But remember; I'm not doing this officially. Please don't make me disgrace my country by helping you. Do you understand what I'm saying?"
      )
      |> next()
      |> select(["Got it.", "No."])

    case choice do
      1 ->
        ctx
        |> mes("[Defaria]")
        |> mes(
          "Good. Then I expect you to help me by gathering the items I need to unseal the scroll:"
        )
        |> mes("^4d4dff30 Holy Waters, Runes of Darkness, and Bloody Runes^000000.")
        |> next()
        |> mes("[Defaria]")
        |> mes("I'll be waiting for your return.")
        |> set_char_var(:mao_morocc2, 15)
        |> changequest(7023, 7024)
        |> close()

      2 ->
        ctx
        |> mes("[Defaria]")
        |> mes(
          "At first, you looked like someone who is reliable and understands the difference between official and private matters."
        )
        |> mes("Your answer just proved me wrong.")
        |> mes("Echinacea must be getting desperate if she's asking people like you for help.")
        |> close()

      _ ->
        ctx
    end
  end

  defp collects_the_reagents(ctx) do
    if count_item(ctx, @holy_water) > 29 and count_item(ctx, @rune_of_darkness) > 29 and
         count_item(ctx, @bloody_rune) > 29 and count_item(ctx, @seal_scroll) > 0 do
      ctx
      |> mes("[Defaria]")
      |> mes("Oh, you've brought everything!")
      |> mes("Good, it wasn't hard, was it?")
      |> mes("Okay, can you come back in a little bit?")
      |> delitem(@holy_water, 30)
      |> delitem(@rune_of_darkness, 30)
      |> delitem(@bloody_rune, 30)
      |> delitem(@seal_scroll, 1)
      |> set_char_var(:mao_morocc2, 16)
      |> changequest(7024, 7025)
      |> close()
    else
      ctx
      |> mes("[Defaria]")
      |> mes("To unseal the scroll,")
      |> mes("I need ^4d4dff30 Holy Waters, Runes of the Darkness, and Bloody Runes^000000.")
      |> mes("Don't forget to bring the spell scroll along with them.")
      |> next()
      |> mes("[Defaria]")
      |> mes("While you're gathering the items, I'll be roasting my sweet potatoes.")
      |> mes("If I could only make this fire work...")
      |> close()
    end
  end

  defp unseals_the_scroll(ctx) do
    if Enum.random(1..3) == 2 do
      ctx =
        ctx
        |> mes("[Defaria]")
        |> mes("Welcome back; you came at the perfect time.")
        |> mes("First, this spell scroll contains a teleportation spell.")
        |> mes("You know what teleportation is, don't you?")
        |> next()
        |> mes("[Defaria]")
        |> mes("You know,")
        |> mes("it's a spell that instantly moves you to a different location.")
        |> mes("That's the spell contained in this scroll.")
        |> next()
        |> mes("[Defaria]")
        |> mes("The only difference is...")
        |> mes("This scroll will teleport you to a specific location.")
        |> mes(
          "Such scrolls are generally used by ^4d4dfforganizations to gather their members^000000."
        )
        |> next()
        |> mes("[Defaria]")
        |> mes("I don't know where this scroll will lead you..")
        |> mes("You'll be the one using this scroll. Am I right?")
        |> mes("Here, please take this.")
        |> next()

      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("'To gather members...?'")
      |> mes("...Right! I remember")
      |> mes("Rayan mentioned a gathering somewhere!")
      |> mes("So this scroll will take me to that meeting?")
      |> next()
      |> mes("[Defaria]")
      |> mes("Um, do you mind? Would you stop talking to yourself and just leave already?")
      |> mes("I'm sorry, but this old man needs some rest, alright?")
      |> set_char_var(:mao_morocc2, 17)
      |> give_item(@unsealed_spell, 1)
      |> changequest(7025, 7026)
      |> close()
    else
      ctx
      |> mes("[Defaria]")
      |> mes("Don't be so impatient.")
      |> mes("You can come back later.")
      |> mes("It'll take some time.")
      |> close()
    end
  end

  defp explains_the_spell(ctx) do
    ctx
    |> mes("[Defaria]")
    |> mes("What are you so worried about?")
    |> mes("You'll see how it works as soon as you use it.")
    |> close()
  end

  defp asks_about_dandelion(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("....")
      |> next()
      |> mes("[Defaria]")
      |> mes("..Huh? What do you want?")
      |> next()
      |> input(:string)

    case answer do
      "Dandelion" -> asks_about_the_group(ctx)
      "Arunafeltz" -> mentions_arunafeltz(ctx)
      _ -> asks_for_clarity(ctx)
    end
  end

  defp asks_about_the_group(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Defaria]")
      |> mes("..I know they're involved in this case, but")
      |> mes("we shouldn't talk about them.")
      |> next()
      |> select(["Just tell me what you know.", "Alright..", ""])

    case choice do
      1 -> presses_for_information(ctx)
      2 -> gives_up_easily(ctx)
      _ -> ctx
    end
  end

  defp presses_for_information(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Defaria]")
      |> mes("Why should I go through all that trouble?")
      |> mes("You can go and ask Echinaea.")
      |> mes("This old man needs some rest, alright?")
      |> next()
      |> select(["I'll do anything for you."])

    {ctx, choice} =
      ctx
      |> mes("[Defaria]")
      |> mes("Anything?")
      |> mes("Are you serious?")
      |> next()
      |> select(["Haha, got you!", "Yes!"])

    case choice do
      1 -> fools_the_old_man(ctx)
      2 -> accepts_the_errand(ctx)
      _ -> ctx
    end
  end

  defp fools_the_old_man(ctx) do
    ctx
    |> mes("[Defaria]")
    |> mes("What th--! How dare you fool an old man!")
    |> mes("You little punk!")
    |> specialeffect2(:hit2)
    |> percent_heal(hp: -10, sp: 0)
    |> next()
    |> mes("[Defaria]")
    |> mes("I may be old,")
    |> mes("but I'm a representative of great Arunafeltz's scholars!")
    |> mes("It's a mistake to trifle with me like that!")
    |> specialeffect2(:hit2)
    |> percent_heal(hp: -10, sp: 0)
    |> next()
    |> mes("[Defaria]")
    |> mes(
      "Did you think I'm stupid just because I was trying to make a fire with wet firewood?!"
    )
    |> mes("..*Pant Pant*.. Phew, even yelling tires me out..")
    |> close()
  end

  defp accepts_the_errand(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Defaria]")
      |> mes("Then...")
      |> mes("...Umm... Can you bring me some Logs?")
      |> mes("...And some sweet potatoes too, if you don't mind.")
      |> next()
      |> select(["Sure thing. How many?"])

    ctx
    |> mes("[Defaria]")
    |> mes("...Let's see...")
    |> mes("I need sweet potatoes for me, Mr. Kidd, and Echi... Umm...")
    |> mes("...And then I need... Yes!")
    |> next()
    |> mes("[Defaria]")
    |> mes("Please bring me ^4d4dff20 Sweet Potatoes and 30 Logs^000000.")
    |> mes("I'll be waiting for your return.")
    |> set_char_var(:mao_morocc2, 102)
    |> changequest(7037, 7038)
    |> close()
  end

  defp gives_up_easily(ctx) do
    ctx
    |> mes("[Defaria]")
    |> mes("You seem to give up really easily.")
    |> mes("I don't blame you. Sometimes giving up is the best decision,")
    |> mes("not to mention that it takes a certain kind of courage.")
    |> next()
    |> mes("[Defaria]")
    |> mes(
      "For example, Tarous that know when to abandon their hopes of getting cheese, you know, the bait in traps, are the hardest ones to catch. You know?"
    )
    |> mes("..Hahaha!")
    |> close()
  end

  defp mentions_arunafeltz(ctx) do
    ctx
    |> mes("[Defaria]")
    |> mes("...Arunafeltz...?")
    |> mes("Yes, I'm from Arunafeltz...")
    |> mes("So what?")
    |> close()
  end

  defp asks_for_clarity(ctx) do
    ctx
    |> mes("[Defaria]")
    |> mes("Be more specific about your question,")
    |> mes("and stop being so ambiguous.")
    |> close()
  end

  defp collects_the_firewood(ctx) do
    if count_item(ctx, @sweet_potato) > 19 and count_item(ctx, @log) > 29 do
      ctx =
        ctx
        |> mes("[Defaria]")
        |> mes("Oh, you've really brought what I wanted!")
        |> mes("Please give them to me..")
        |> mes("No, wait, can you pile them on the firewood over there?")
        |> next()
        |> mes("[Defaria]")
        |> mes("Make it a nice, neat pile, please.")
        |> mes("Oh, you forgot to put the sweet potatoes on top.")
        |> mes("Yes, good. That's perfect.")
        |> next()
        |> mes("[Defaria]")
        |> mes("Hopefully I can make a fire with your nice logs....")
        |> specialeffect(:beginspell2)
        |> next()

      ctx
      |> specialeffect(:firewall, :area, @wet_firewood)
      |> specialeffect(:torch, :area, @wet_firewood)
      |> mes("[Defaria]")
      |> mes("Oh, this is as great as I'd hoped!")
      |> mes("I guess my magic hasn't gotten that rusty after all..")
      |> delitem(@sweet_potato, 20)
      |> delitem(@log, 30)
      |> set_char_var(:mao_morocc2, 103)
      |> close()
    else
      ctx
      |> mes("[Defaria]")
      |> mes("If you want me to do you a favor, then")
      |> mes("you should bring me ^4d4dff20 Sweet Potatoes and 30 Logs^000000 in return.")
      |> close()
    end
  end

  defp hands_over_the_potatoes(ctx) do
    ctx =
      ctx
      |> mes("- Defaria is blowing on a roast sweet potato, peeling off it's skin. -")
      |> next()
      |> select(["Excuse me, sir..."])
      |> elem(0)

    ctx =
      ctx
      |> mes("[Defaria]")
      |> mes("What..?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Didn't you forget something?")
    |> mes("... Dandelion? I wanted you to tell me what you knew.")
    |> mes("I was hoping you'd remember something about Dandelion.")
    |> next()
    |> mes("[Defaria]")
    |> mes("So,")
    |> mes("do you want me to confirm")
    |> mes("if Dandelion is really supported by Arunafeltz?")
    |> next()
    |> mes("[Defaria]")
    |> mes("Umm... I don't know what to say... I don't feel comfortable talking about politics.")
    |> next()
    |> mes("[Defaria]")
    |> mes("...Do you mind delivering these to Mr. Kidd?")
    |> next()
    |> mes("- Defaria has given you 2 Nice Sweet Potatoes. -")
    |> set_char_var(:mao_morocc2, 104)
    |> give_item(@nice_sweet_potato, 2)
    |> changequest(7038, 7039)
    |> close()
  end

  defp hurries_to_mr_kidd(ctx) do
    ctx
    |> mes("[Defaria]")
    |> mes("Um, I just told you to deliver those sweet potatoes to Mr. Kidd.")
    |> close()
  end

  defp tells_about_dandelion(ctx) do
    ctx =
      ctx
      |> mes("[Defaria]")
      |> mes("Say, did he like them?")
      |> mes("Hahaha...")
      |> mes("... ... ")
      |> next()
      |> mes("[Defaria]")
      |> mes("Dandelion was like a ghost.")
      |> mes("There are many different types of people in this world.")
      |> mes("Some people want war while others are against it.")
      |> next()
      |> mes("[Defaria]")
      |> mes("The Dandelions were the former case.")
      |> mes(
        "Those right-ists believed in a distorted patriotism. They thought shedding blood was the only way to make peace."
      )
      |> next()
      |> mes("[Defaria]")
      |> mes("They organized Dandelion,")
      |> mes("and they happened to ally themselves with the warmongers in the government.")
      |> next()
      |> mes("[Defaria]")
      |> mes("That's how they grew so strong.")
      |> mes(
        "At first, their purpose was limited to gathering intel and spying on other countries."
      )
      |> mes("This is just what I think, but the right information can cause chaos in a country.")
      |> next()
      |> select(["Then what..?"])
      |> elem(0)

    {ctx, _} =
      ctx
      |> mes("[Defaria]")
      |> mes("Can't you see it by now? Isn't it obvious?")
      |> mes("Well, if you can't take care of your own problems,")
      |> mes("then you won't be able to handle your enemies.")
      |> next()
      |> select(["So Arunafeltz planned all this!"])

    ctx
    |> mes("[Defaria]")
    |> mes("No, it isn't that simple. The world isn't just black and white, you know?")
    |> mes("Just bring these to Echinacea, will you?")
    |> mes("They're cooked very well.")
    |> next()
    |> mes("- You have received 2 steaming hot Nice Sweet Potatoes. -")
    |> set_char_var(:mao_morocc2, 106)
    |> give_item(@nice_sweet_potato, 2)
    |> changequest(7039, 7040)
    |> close()
  end

  defp hurries_to_echinacea(ctx) do
    ctx
    |> mes("[Defaria]")
    |> mes("I told you to deliver those cooked sweet potatoes to Echinacea.")
    |> mes("Don't eat them, alright?")
    |> close()
  end

  defp rewards_the_player(ctx) do
    ctx
    |> mes("[Defaria]")
    |> mes("Muhahahaha!")
    |> mes("Did Echinacea really say that?")
    |> mes("She's an executive of the Rune-Midgarts army.")
    |> mes("I can tell that what she said came from the bottom of her heart.")
    |> next()
    |> mes("[Defaria]")
    |> mes("I'm relieved that things turned out this way.")
    |> mes("After all, they're the reason why the three countries decided to cooperate.")
    |> mes("Of course, it's too early to say if the cooperation will last long.")
    |> next()
    |> mes("[Defaria]")
    |> mes(
      "I just hope that the three countries will use this chance to form lasting, friendly relationships. Wouldn't that be great for the sake of everyone in the world?"
    )
    |> mes("Hrrm, but I'm not holding my breath for world peace.")
    |> next()
    |> mes("[Defaria]")
    |> mes("I'm just a mere human who can't foresee the future, you know?")
    |> mes("..Hahaha..")
    |> next()
    |> mes("[Defaria]")
    |> mes("Ah, your sweet potatoes are now roasted very well.")
    |> mes("Here, enjoy them.")
    |> mes("Thank you for trying so hard to please this whimsical old man.")
    |> set_char_var(:mao_morocc2, 108)
    |> give_item(@baked_yam, 5)
    |> completequest(7041)
    |> close()
  end
end
