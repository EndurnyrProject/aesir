defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Alchemist.FastidiousAlchemist do
  @moduledoc """
  Raspuchin Gregory interviews Alchemist candidates with a ten-question arithmetic test.

  ## Behavior

  - Mocks Alchemists, Novices, and other non-Merchants.
  - Waves through candidates at Job Level 50 without the test.
  - Gives other candidates one of three random ten-question math tests, allowing one wrong
    answer, or two on a retry.
  - Sends passing candidates on to Darwin and records failures as a retry.

  ## Credits

  - Original from rAthena, authors and Contributors
    - nestor_zulueta
    - Darkchild
    - L0ne_W0lf
    - Kisuka
    - kobra_k88
    - Lupus
    - Vicious

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alde_alche",
        x: 175,
        y: 107,
        dir: 3,
        sprite: 749,
        name: "Fastidious Alchemist",
        scope: :shared,
        unique_name: "Fastidious Alchemist#am"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @first_test [
    {["12 + 23 + 34 + 45 = ?"], 114},
    {["1000 - 36 - 227 - 348 = ?"], 389},
    {["14 * 17 * 3 = ?"], 714},
    {["9765 / 3 / 5 / 7 = ?"], 93},
    {["(47 * 28) - (1376 / 4) = ?"], 972},
    {["(2646 / 7) + (13 * 28) = ?"], 742},
    {[
       "How much do",
       "12 Red Potions,",
       "1 Butterfly Wing",
       "and 5 Fly Wings cost",
       "after a 24 % discount?"
     ], 909},
    {["What is the", "total weight of", "3 Scimiters, 2 Helms", "and 1 Long Coat?"], 450},
    {[
       "What is the",
       "total defense of",
       "a Biretta, Mantle,",
       "Opera Mask, Ribbon,",
       "Muffler, Boots, and",
       "Ear Muffs?"
     ], 20},
    {[
       "If you buy 5 Helms",
       "with a 24 % discount",
       "and sell it at 20",
       "how much profit",
       "do you earn?"
     ], 8800}
  ]

  @second_test [
    {["13 + 25 + 37 + 48 = ?"], 123},
    {["1000 - 58 - 214 - 416 = ?"], 312},
    {["12 * 24 * 3 = ?"], 864},
    {["10530 / 3 / 5 / 2 = ?"], 351},
    {["(35 * 19) - (1792 / 7) = ?"], 409},
    {["(2368 / 8) + (24 * 17) = ?"], 704},
    {["(2646 / 7) + (13 * 28) = ?"], 742},
    {[
       "What is the",
       "total price of",
       "15 Green Potions,",
       "6 Magnifiers and",
       "4 Traps after",
       "a 24 % discount?"
     ], 934},
    {["What is the", "total weight of", "3 Ring Pommel Sabers,", "4 Caps, and 2 Boots?"], 550},
    {[
       "What is the",
       "total defense of",
       "a Buckler, Long Coat,",
       "Gas Mask, Big Ribbon,",
       "Cute Ribbon, Sakkat,",
       "and Glasses?"
     ], 16},
    {[
       "How much profit do you",
       "make if you buy Tights",
       "at a 24 % discount and",
       "sell it at 20 % of",
       "the normal price?"
     ], 8520}
  ]

  @third_test [
    {["12 + 23 + 34 + 45 = ?"], 114},
    {["1000 - 58 - 214 - 416 = ?"], 312},
    {["14 * 17 * 3 = ?"], 714},
    {["10530 / 3 / 5 / 2 = ?"], 351},
    {["(47 * 28) - (1376 / 4) = ?"], 972},
    {["(2646 / 7) + (13 * 28) = ?"], 742},
    {[
       "What is the",
       "total cost of",
       "6 Red Potions,",
       "7 Green Potions,",
       "and 8 Fly Wings",
       "after a 24 % discount?"
     ], 798},
    {["What is the", "total weight of", "2 Ring Pommel Sabers,", "3 Caps, and 3 boots?"], 480},
    {[
       "What is the",
       "total defense of",
       "a Mirror Shield, Mr. Smile, Leather Jacket, Silk Robe, Wedding Veil, Muffler, and Eye Patch?"
     ], 12},
    {[
       "If you buy 4 Padded Armors",
       "at a 24% discount and sell",
       "them at 20% of the original",
       "price, how much profit would",
       "you make from this sale?"
     ], 7680}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Raspuchin Gregory]")

    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:merchant) ->
        talk_to_merchant(ctx, get_char_var(ctx, :ALCH_Q, 0))

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist) ->
        warn_alchemist(ctx)

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) ->
        tease_novice(ctx)

      true ->
        boast_about_potion(ctx)
    end
  end

  defp warn_alchemist(ctx) do
    ctx
    |> mes("Heeheehee")
    |> mes("keheheh~!")
    |> mes("Eh? What do you want?!")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes(
      "You're not here to steal my experimental results or plagiarize my work, are you? How dare you consider intellectual theft!"
    )
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("You're not, are you?")
    |> mes("Well, as a colleague,")
    |> mes("let me just warn you")
    |> mes("that such tricks aren't")
    |> mes("tolerated here in the")
    |> mes("Alchemist Union!")
    |> close()
  end

  defp tease_novice(ctx) do
    ctx
    |> mes("Heeheehee")
    |> mes("keheheh~!")
    |> mes("How cute, you've come")
    |> mes("all this way just to play...")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("I'll let you")
    |> mes("go this time...")
    |> mes("But next time, don't")
    |> mes("expect to leave so easily...")
    |> close()
  end

  defp boast_about_potion(ctx) do
    ctx
    |> mes("What is it?!")
    |> mes("You're curious as")
    |> mes("to what I'm doing?")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("Heehee")
    |> mes("keheheh~!")
    |> mes("Why, I'm busy")
    |> mes("researching,")
    |> mes("of course!")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("Once this")
    |> mes("potion is complete...")
    |> mes("You can use it to take")
    |> mes("over an entire nation!")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("Hee hee hee!")
    |> mes("Something this")
    |> mes("dangerous has to")
    |> mes("be kept a secret!")
    |> mes("Understand?")
    |> close()
  end

  defp talk_to_merchant(ctx, 0) do
    ctx
    |> what_do_you_want()
    |> mes(
      "A Merchant should go and set up shop and vend items. Why are you wandering in a place like this?"
    )
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("Heheheh~!")
    |> mes("Go vend somwhere else!")
    |> mes("And leave me to my")
    |> mes("dark enterprise!")
    |> close()
  end

  defp talk_to_merchant(ctx, step) when step >= 1 and step <= 3 do
    ctx
    |> what_do_you_want()
    |> mes("What...?")
    |> mes("Learn Alchemy?!")
    |> mes("Don't even speak")
    |> mes("such nonsense!")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes(
      "Even if you tried studying for a thousand years, maybe even more, it'd be useless to you! Forget about it and just worry about your store!"
    )
    |> close()
  end

  defp talk_to_merchant(ctx, 4) do
    ctx =
      ctx
      |> what_do_you_want()
      |> mes("What...?")
      |> mes("Join the Union!?")
      |> mes("I don't like it...")
      |> mes("I just don't...!")
      |> next()
      |> mes("[Raspuchin Gregory]")
      |> mes("Nowadays, anyone thinks they can")
      |> mes(
        "be Alchemists just by knowing how to mix a few herbs. That's why my interview is necessary."
      )
      |> next()
      |> mes("[Raspuchin Gregory]")
      |> mes("Heeheehee")
      |> mes("keheheh~!")
      |> mes("I plan on weeding out all the dumb and incompetent, and chase them")
      |> mes("all away! We don't need morons!")
      |> next()

    if job_level(ctx) == 50 do
      skip_interview(ctx)
    else
      ctx
      |> mes("[Raspuchin Gregory]")
      |> mes("Surprised, are you?")
      |> mes("Keheheh~ If you thought")
      |> mes("becoming an Alchemist was")
      |> mes("just a matter of changing")
      |> mes("your clothes, then you're")
      |> mes("sadly mistaken.")
      |> next()
      |> mes("[Raspuchin Gregory]")
      |> mes("Now, try solving")
      |> mes("all these problems.")
      |> mes("Let's see how smart")
      |> mes("really are.")
      |> run_interview()
    end
  end

  defp talk_to_merchant(ctx, 5) do
    ctx
    |> mes("What...?!")
    |> mes("You want to take")
    |> mes("the test again?!")
    |> mes("I thought I told")
    |> mes("you to leave!")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("I don't like it...")
    |> mes("I don't like this!")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("Fine...")
    |> mes("I'll try to overlook your pitiful performance last time and give")
    |> mes("you another chance. Don't screw")
    |> mes("up again, got it?")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("Now then,")
    |> mes("give me all the")
    |> mes("^551A8Bright^000000 answers")
    |> mes("this time.")
    |> run_interview()
  end

  defp talk_to_merchant(ctx, 6) do
    ctx
    |> mes("What are you doing?")
    |> mes("Go and find Darwin now.")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("Keheheheheheheheh~")
    |> mes("Don't think this is the end of it!")
    |> close()
  end

  defp talk_to_merchant(ctx, _step) do
    ctx
    |> mes("Keheheheheheheheh~")
    |> mes("Don't think this is the end of it!")
    |> close()
  end

  defp what_do_you_want(ctx) do
    ctx
    |> mes("Heeheehee")
    |> mes("keheheh~!")
    |> mes("What do you")
    |> mes("want, kid?")
    |> next()
    |> mes("[Raspuchin Gregory]")
  end

  defp skip_interview(ctx) do
    ctx =
      ctx
      |> mes("[Raspuchin Gregory]")
      |> mes("Wait...")
      |> mes("Maybe I've")
      |> mes("misjudged you.")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx
        |> mes("You might be a pretty boy,")
        |> mes("but I can tell you're smart")
        |> mes("from your eyes.")
      else
        ctx
        |> mes("Huh. You're a cutie alright,")
        |> mes("but I can tell you've got brains.")
      end

    ctx
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("You're not just some stupid kid.")
    |> mes(
      "I can tell youve gone through some rough times as a Merchant. Excellent. Keh heh heh~"
    )
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes(
      "Fine, just so we don't insult each other's intelligence, I'll just let you pass the interview."
    )
    |> next()
    |> send_to_darwin()
  end

  defp run_interview(ctx) do
    ctx = next(ctx)

    questions =
      case Enum.random(1..3) do
        1 -> @first_test
        2 -> @second_test
        3 -> @third_test
      end

    {ctx, wrong_answers} = ask_questions(ctx, questions)

    cond do
      wrong_answers == 0 ->
        ctx
        |> mes("[Raspuchin Gregory]")
        |> mes("Ooh...")
        |> mes("Excellent! Great!")
        |> mes("You got them all correct!?")
        |> mes("Keheheh, I have no choice but to acknowledge you...")
        |> next()
        |> send_to_darwin()

      wrong_answers == 1 ->
        ctx
        |> mes("[Raspuchin Gregory]")
        |> mes("You got one wrong!")
        |> mes("But I'll let it slide.")
        |> mes("You pass the interview!")
        |> next()
        |> send_to_darwin()

      wrong_answers == 2 and get_char_var(ctx, :ALCH_Q, 0) == 5 ->
        ctx
        |> mes("[Raspuchin Gregory]")
        |> mes("You've got serious")
        |> mes("weaknesses in math,")
        |> mes("but I'll let you go this time...")
        |> next()
        |> send_to_darwin()

      true ->
        fail_interview(ctx)
    end
  end

  defp ask_questions(ctx, questions) do
    Enum.reduce(questions, {ctx, 0}, fn {lines, answer}, {ctx, wrong_answers} ->
      {ctx, input} =
        lines
        |> Enum.reduce(mes(ctx, "[Raspuchin Gregory]"), &mes(&2, &1))
        |> next()
        |> input(:int)

      if input != answer, do: {ctx, wrong_answers + 1}, else: {ctx, wrong_answers}
    end)
  end

  defp fail_interview(ctx) do
    ctx
    |> set_char_var(:ALCH_Q, 5)
    |> mes("[Raspuchin Gregory]")
    |> mes("Keheheh! Idiot!")
    |> mes("Just listening to your")
    |> mes("answers is making me feel")
    |> mes("stupider! You might as well")
    |> mes("have got them all wrong!")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("How can a person that")
    |> mes("can't even answer all of")
    |> mes("these simple questions think")
    |> mes("of becoming an Alchemist?!")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("Hm...?")
    |> mes("Did you get")
    |> mes("any right?")
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("Fool! Even if you make one little mistake, everything goes wrong")
    |> mes("in Alchemy! Now get out of here!")
    |> mes("You make me sick!")
    |> close()
  end

  defp send_to_darwin(ctx) do
    ctx
    |> mes("[Raspuchin Gregory]")
    |> mes(
      "So hurry up, become an Alchemist, do some good research, and you might turn out to be of some help to me. Hahahahahaha~!"
    )
    |> next()
    |> mes("[Raspuchin Gregory]")
    |> mes("Now go to Darwin!")
    |> mes("He'll teach you how to do the experiments. Just tell him that")
    |> mes("I sent you.")
    |> set_char_var(:ALCH_Q, 6)
    |> changequest(2031, 2032)
    |> close()
  end
end
