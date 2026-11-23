defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.SchwarzwaldMechanic do
  @moduledoc """
  Helps Dorance develop a translator for the Otherworld languages.

  ## Behavior

  - Advances the language quest through research and construction of a translator.
  - Awards the Ring of the Wise King and experience after the timer expires.

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

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 197,
        y: 237,
        dir: 3,
        sprite: 869,
        name: "Schwarzwald Mechanic",
        scope: :shared,
        unique_name: "Schwarzwald Mechanic#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      not Rathena.truthy?(checkweight(ctx, [{2782, 1}])) ->
        ctx
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("It looks like you're carrying too many things.")
        |> mes("Why not put some of your items in storage and come back?")
        |> close()

      get_char_var(ctx, :ep13_1_edq, 0) > 2 or get_char_var(ctx, :ep13_start, 0) == 100 ->
        discuss_translator(ctx, get_char_var(ctx, :ep13_2_rhea, 0))

      true ->
        ctx
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Do you know about the Ring of Ancient Wise King? If you wear that Ring, you could talk to an animal."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "I don't know if it is a legend based on a truth or not... something like that will come in handy."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "By the way, Who are you? This building is under Commander's control. This place is not to be entered freely... Are you acquainted with our Commander?"
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Are you looking for something to do? Perhaps I could use some help... Well, I don't know if you are trustworthy just yet."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "If you are good enough to solve some problems within the expedition camp, and carry out a mission given by Commander... then I think I could trust you."
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_translator(ctx, stage) do
    cond do
      stage < 1 ->
        ctx
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Do you know about the Ring of the Ancient Wise King? If you wear that Ring, you can talk to animals."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "I don't know if it is a legend based on truth or not... but something like that would come in pretty handy."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Outside of the Expedition Camp, There's a race of animals which uses a mysterious language not used in Midgard."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "We don't know if they are friend or foe, but it will be much easier for our research here if we could find out."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "So, the Triple Alliance Research Group is working together to find out. I would like to know how far the ^0000ff Arunafeltz Linguist^000000's decoding process is. Would you go and find out for me?"
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "The ^0000ff Arunafeltz Linguist^000000 should be on the second floor of the Alliance Headquarters."
        )
        |> setquest(8243)
        |> set_char_var(:ep13_2_rhea, 1)
        |> close()

      stage < 7 ->
        ctx
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Outside of the Expedition Camp, There's a race who uses a mysterious language which is not used in Midgard"
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "We don't know if they are friend or foe, one thing for sure is it will be more easier for our research here."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "So, the Triple Alliance Research Group is working together to find out. I would like to know how far the ^0000ff Arunafeltz Linguist^000000's decoding process is. Would you go and find out for me?"
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Go to a big building in center of the Expedition Camp and inside that building, meet ^0000ff Arunafeltz Linguist^000000 and ask him how far his progress is."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "The ^0000ff Arunafeltz Linguist^000000 should be on the second floor of the Alliance Headquarters."
        )
        |> close()

      stage == 7 ->
        ctx
        |> mes("- He's making a grim face at a flooding pile of research documents. -")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Ah, You are here.")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("t seems like you've done much for us. I thank you for that.")
        |> mes("But...Sigh...")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Can you see this? The amount of these research documents?")
        |> mes(
          "It is a good thing that we finally decoded the other world's language... it's just too much."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "We can't always accompany a Linguist for an interpretion... We need to communicate with those other world races in order to explore this world..."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "To store this amount of information will need a super computer the size of this headquarter building and its processing speed will be very very slow."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Sigh... Anyways, If there's any way to store an enormous amount of data, I should be able to make a very-small portable translator."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "I heard that by using a Magical Spell of Rune-Midgarts, you can transpose data to a magical power and lock it into a gem... I'd like some suggestions from the Rune-Midgarts Magician."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Would you be kind to ask them for help?")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("While you are gone, I be here organizing these documents.")
        |> completequest(8248)
        |> setquest(8249)
        |> set_char_var(:ep13_2_rhea, 8)
        |> close()

      stage < 11 ->
        ctx
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "To store this amount of information will need a super computer with a size of this headquarter building. and its processing speed will be very very slow..."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Sigh... Anyways, If there's any way to store an enormous amount of data, I could be able to make a very-small portable translator."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "I heard that by using the Magical Spell of Rune-Midgarts, you could transpose a data to a magical power and lock it into a gem....I'd like to get some suggestion from the Magician of Rune-Midgarts."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Would you be kind to ask them for help?")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("While you are gone, I be here organizing these documents.")
        |> close()

      stage == 11 ->
        {ctx, _} =
          ctx
          |> mes("[Mechanic Engineer Dorance]")
          |> mes("How'd it go?")
          |> next()
          |> select(["Give him the Gem."])

        ctx
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Ah, Looks like you've succeeded.")
        |> mes(
          "Inputting data into a gem with a magical power... It's something you can't do with a technology... It's a bit resentful to admit, but it's magnificent."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Well then, I should be working on making a machine to read the magical data in this Gem so we could use them right away."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Hmm...")
        |> mes("Fortunately, It won't be as hard as we thought.")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "If we transform a magical power wave to an eletric signal and connect it to a human body, then transmit a data to a brain directly. That will allow us to receive and understand a data without any loading process."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("I don't have time to explain everything. I have to start the work right away.")
        |> mes("With all preperation done, allow me about one hour to finish this thing.")
        |> completequest(8252)
        |> setquest(8253)
        |> set_char_var(:ep13_2_rhea, 12)
        |> close()

      stage == 12 ->
        finish_translator(ctx)

      true ->
        ctx
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Thank you for your help.")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("I hope this ring would be a big help for your journey through the other world.")
        |> close()
    end
  end

  defp finish_translator(ctx) do
    ctx = set_local(ctx, :trs_time01, checkquest(ctx, 8253, :playtime))

    if get_local(ctx, :trs_time01, 0) == 2 do
      ctx =
        ctx
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Sigh, What should I do now?!")
        |> next()
        |> mes("- Dorance is walking here and there -")
        |> mes("- in a dither. -")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Is something wrong?!")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("What should I do?! Ain't I REALLY a genius?!")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("I've made it!!!")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Convenient portable size!")
        |> mes("Fashionable and practical design!")
        |> mes("Features the Other World's Words / Idiom / Grammer / Phrases!!")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Have you experienced the loading speed?")
        |> mes("Don't you even mention it if you haven't.")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("That's not all!")
        |> mes("For the Well-Being life, it will buff your strength and intelligence!!!!")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("With all these marvelous features, it's just 39,900 zeny....!!!")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("...Just what are you trying to imitate...")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Important thing is, I've made it!!")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Well, Seeing is believing.")
        |> mes("Take a look.")
        |> next()
        |> mes("- He handed over the small ring. -")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "The name is 'the Ring of Wise King'. I designed it after the Ring used by ancient king to communicate with animals."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Do not just look at it like any other rings. You see this small gem here? This socket which holds a gem and a ring part are precisely crafted, it will transform a magical power wave to electric signal and trasmit it directly to our brain."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Since this electric signal is same as the signal used by our body's nerve system, it will enable us to understand and use the language fluently."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes(
          "Once this translator gets popularized, it'd be just a matter of time for us to advance into the other world. Well, the problem is...we don't have enough quantity yet..."
        )
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Hmm...")
        |> mes("Anyways, now we've got the idea, I will give you this first piece of work.")
        |> next()
        |> mes("[Mechanic Engineer Dorance]")
        |> mes("Thank you for helping us out.")
        |> mes("I hope this ring would be a big help for your journey through the other world.")
        |> completequest(8253)
        |> set_char_var(:ep13_2_rhea, 100)

      ctx =
        if Rathena.truthy?(checkre(ctx, 3)) do
          getexp(ctx, 200_000, 5000)
        else
          getexp(ctx, 1_000_000, 300_000)
        end

      ctx |> give_item(2782, 1) |> close()
    else
      ctx
      |> mes("- He has scattered mechanical parts -")
      |> mes("- all over the room and so wrapped up -")
      |> mes("- in his work -")
      |> next()
      |> mes("- I might get bitten if I bother him -")
      |> mes("- Let's leave him alone -")
      |> close()
    end
  end
end
