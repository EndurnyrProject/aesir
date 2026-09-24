defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Blacksmith.Guildsman20127 do
  @moduledoc """
  Geschupenschte, the Blacksmith who gives applicants the merchant quiz and the forging and
  delivery test of the Blacksmith job quest.

  ## Behavior

  - Quizzes Merchant applicants with one of two random ten-question sets; only a perfect
    score passes.
  - Assigns one of five random material orders, then forges the matching weapon from the
    collected materials and sends the applicant to deliver it.
  - Accepts the delivery receipt to finish the test, or restarts the order when the receipt
    is missing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - Komurka
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - L0ne_W0lf
    - Yommy
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 201,
        y: 27,
        dir: 3,
        sprite: 63,
        name: "Guildsman",
        scope: :shared,
        unique_name: "Guildsman#alberta"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @materials %{
    4 => [{999, 1}, {930, 1}, {717, 2}, {1610, 1}],
    5 => [{1001, 2}, {932, 1}, {912, 1}, {1219, 1}],
    6 => [{1003, 1}, {935, 2}, {990, 2}, {1119, 1}],
    7 => [{1002, 1}, {2212, 1}, {717, 2}, {1713, 1}],
    8 => [{998, 1}, {511, 1}, {919, 2}, {1122, 1}]
  }

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Geschupenschte]")
      |> mes("Hello there!")
      |> mes("I'm ^8E6B23Geschupenschte^000000,")
      |> mes("a Blacksmith by trade.")
      |> mes("Nice to meet you!")
      |> next()

    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:merchant) do
      ctx =
        ctx
        |> mes("[Geschupenschte]")
        |> mes("Oh ho ho!")
        |> mes("You're a Merchant!")
        |> mes("Excellent! I was")
        |> mes("in need of some help!")
        |> next()

      quest_progress(ctx, get_char_var(ctx, :BSMITH_Q, 0))
    else
      ctx
      |> mes("[Geschupenschte]")
      |> mes("Being")
      |> mes("a Blacksmith")
      |> mes("is truly great!")
      |> mes("Don't you think so?")
      |> mes("Mwahahahahah!!")
      |> close()
    end
  end

  defp quest_progress(ctx, 0) do
    ctx
    |> mes("[Geschupenschte]")
    |> mes("But, of course,")
    |> mes("I wouldn't bother you")
    |> mes("if you're busy. Go along")
    |> mes("your way if you must~")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("After all...")
    |> mes("I should know")
    |> mes("how it's like")
    |> mes("to be busy~")
    |> close()
  end

  defp quest_progress(ctx, 1) do
    {ctx, selection} =
      ctx
      |> mes("[Geschupenschte]")
      |> mes(
        "Am I correct in assuming you are the help sent by the Blacksmith Guild? There aren't many trustyworthy people I can hire to help me, so I'm always"
      )
      |> mes("short on help.")
      |> next()
      |> mes("[Geschupenschte]")
      |> mes("Hmm, in any case,")
      |> mes(
        "you are the help that was sent, right? Okay, I have some work for you that must be handled"
      )
      |> mes("right away!")
      |> next()
      |> mes("[Geschupenschte]")
      |> mes(
        "Some time ago, I had a boy working for me who had no experience and bought the wrong supplies! It was terrible..."
      )
      |> next()
      |> mes("[Geschupenschte]")
      |> mes(
        "Anyone would hate to lose money through a foolish mistake like that. However, I have a slightly more difficult job for you."
      )
      |> next()
      |> mes("[Geschupenschte]")
      |> mes(
        "However, I want to make sure that you have some basic knowledge as a Merchant. I'd like to ask you some questions, if that's okay."
      )
      |> next()
      |> select(["Yes.", "Um, can I have some time to prepare?"])

    if selection != 2 do
      take_quiz(ctx)
    else
      ctx
      |> mes("[Geschupenschte]")
      |> mes(
        "Ah, of course I don't mind if you came back a little later. Being prepared prevents disasters"
      )
      |> mes("later, after all. No harm in")
      |> mes("being careful~")
      |> close()
    end
  end

  defp quest_progress(ctx, 2) do
    ctx
    |> mes("[Geschupenschte]")
    |> mes("So, have you")
    |> mes("studied a little")
    |> mes("more this time?")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes(
      "I admit that it's pretty unreasonable to expect anyone to get a perfect score the first time around, so I'll give you"
    )
    |> mes("a little break...")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("You can miss")
    |> mes("one problem!")
    |> mes("Alright, let's start")
    |> mes("with the questions~")
    |> next()
    |> take_quiz()
  end

  defp quest_progress(ctx, 3), do: assign_order(ctx)

  defp quest_progress(ctx, step) when step > 3 and step < 9, do: check_materials(ctx, step)

  defp quest_progress(ctx, step) when step > 8 and step < 14 do
    ctx
    |> mes("[Geschupenschte]")
    |> mes("What are you")
    |> mes("still doing here?")
    |> mes("Hurry and deliver")
    |> mes("the package~!")
    |> mes("Did you forget")
    |> mes("where to go?")
    |> next()
    |> mes("[Geschupenschte]")
    |> delivery_directions(step)
    |> close()
  end

  defp quest_progress(ctx, 14), do: ask_for_receipt(ctx)

  defp quest_progress(ctx, 15) do
    ctx
    |> mes("[Geschupenschte]")
    |> mes("Thank you")
    |> mes("very much")
    |> mes("your help.")
    |> mes("Return to Einbroch")
    |> mes("and see ^8E6B23Altiregen^000000!")
    |> close()
  end

  defp quest_progress(ctx, _step) do
    ctx
    |> mes("[Geschupenschte]")
    |> mes("Hmm...?")
    |> mes("You already finished")
    |> mes("your test here with me!")
    |> mes("And surprisingly, I don't")
    |> mes("need any more help, today.")
    |> close()
  end

  defp take_quiz(ctx) do
    {ctx, score} =
      if Rathena.truthy?(:rand.uniform(2) - 1) do
        first_quiz(ctx)
      else
        second_quiz(ctx)
      end

    ctx
    |> mes("[Geschupenschte]")
    |> mes("Umm. You did a good job!")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Let's see...your score is...#{score} points.")
    |> grade_quiz(score)
  end

  defp first_quiz(ctx) do
    {ctx, answer1} =
      ask(
        ctx,
        [
          "1. Which one of the following regions is matched incorrectly",
          "with its specialty item?"
        ],
        [
          "Morocc - Thief Clothes",
          "Alberta - Two Hand Axe",
          "Comodo - Berserk Potion",
          "Alberta - Swordmace"
        ]
      )

    {ctx, answer2} =
      ask(
        ctx,
        ["2. What status can", "be inflicted with the", "^8E6B23Hammer Fall^000000 skill?"],
        ["Stun", "Blind", "Silence", "Sleep"]
      )

    {ctx, answer3} =
      ask(
        ctx,
        ["3. Which one of the following skills cannot be performed", "by a Merchant?"],
        ["Vending", "Discount", "Overcharge", "Increase AGI"]
      )

    {ctx, answer4} =
      ask(
        ctx,
        ["4. Where can you find a store", "that sells Blue Gemstones?"],
        ["Alberta", "Morocc", "Geffen", "Prontera"]
      )

    {ctx, answer5} =
      ask(
        ctx,
        ["5. Where is the", "Tool Dealer", "located in Geffen?"],
        [
          "8 o'clock direction from the town square",
          "11 o'clock direction from the town square",
          "6 o'clock direction from the town square",
          "5 o'clock direction from the town square"
        ]
      )

    {ctx, answer6} =
      ask(
        ctx,
        ["6. Which weapon", "cannot be used", "by a Merchant?"],
        ["Stiletto", "Ring Pommel Saber", "Chain", "Bible"]
      )

    {ctx, answer7} =
      ask(
        ctx,
        ["7. Which one of the following", "has the highest defense rate?"],
        ["Panties", "Mink Coat", "Wooden Mail", "Silk Robe"]
      )

    {ctx, answer8} =
      ask(
        ctx,
        ["8. For Level 3 weapons,", "what is the ^8E6B23Safe^000000 limit", "for upgrading?"],
        ["up to + 3", "up to + 4", "up to + 5", "up to + 6"]
      )

    {ctx, answer9} =
      ctx
      |> mes("9. What item")
      |> mes("can be made using")
      |> mes("the ^8E6B23Trunks^000000 item?")
      |> next()
      |> select(["Sakkat", "Ghost Bandana", "Majestic Goat", "Antler"])

    {ctx, _answer10} =
      ask(
        ctx,
        ["10. The most important", "part of being a Merchant is...?"],
        ["Credit", "Integrity", "Money", "Rhetoric"]
      )

    score =
      points(answer1, 4) + points(answer2, 1) + points(answer3, 4) + points(answer4, 3) +
        points(answer5, 1) + points(answer6, 4) + points(answer7, 2) + points(answer8, 3) +
        points(answer9, 1) + 10

    {ctx, score}
  end

  defp second_quiz(ctx) do
    {ctx, answer1} =
      ask(
        ctx,
        [
          "1. Among the following cities, which one is not correctly matched with its specialty?"
        ],
        [
          "Al De Baran - Yggdrasil Leaf",
          "Alberta - Hammer",
          "Comodo - Berserk Potion",
          "Al De Baran - Hammer"
        ]
      )

    {ctx, answer2} =
      ask(
        ctx,
        ["2. How much Zeny", "is one Jellopy worth?"],
        ["1 Zeny", "2 Zeny", "3 Zeny", "4 Zeny"]
      )

    {ctx, answer3} =
      ask(
        ctx,
        ["3. What is required", "for a Merchant to use", "the ^8E6B23Vending^000000 Skill?"],
        [
          "Must have a Cart.",
          "Must have items to sell.",
          "Must be wielding a weapon.",
          "Must be wearing armor."
        ]
      )

    {ctx, answer4} =
      ask(
        ctx,
        ["4. Where can you", "change your Job to", "become a Merchant?"],
        ["Alberta", "Morocc", "Geffen", "Prontera"]
      )

    {ctx, answer5} =
      ask(
        ctx,
        ["5. Where is the", "Weapons Dealer", "located in Morocc?"],
        [
          "7 o'clock from the town's center",
          "11 o'clock from the town's center",
          "6 o'clock from the town's center",
          "5 o'clock from the town's center"
        ]
      )

    {ctx, answer6} =
      ask(
        ctx,
        ["6. What weapon", "can a Merchant", "not use?"],
        ["Main Gauche", "Claymore", "Chain", "Two handed Axe"]
      )

    {ctx, answer7} =
      ask(
        ctx,
        ["7. Which one of the following", "has the highest defense rate?"],
        ["Panties", "Mink Coat", "Wooden Mail", "Silk Robe"]
      )

    {ctx, answer8} =
      ask(
        ctx,
        ["8. For Level 3 weapons,", "what is the ^8E6B23Safe^000000 limit", "for upgrading?"],
        ["up to + 3", "up to + 4", "up to + 5", "up to + 6"]
      )

    {ctx, answer9} =
      ask(
        ctx,
        ["9. What monster does", "NOT drop Iron Ore?"],
        ["Chon Chon", "Steel Chon Chon", "Zerom", "Anolian"]
      )

    {ctx, _answer10} =
      ask(
        ctx,
        ["10. What is most", "important to a Merchant?"],
        ["Rhetoric", "Credit", "Money", "Experience"]
      )

    score =
      points(answer1, 4) + points(answer2, 3) + points(answer3, 1) + points(answer4, 1) +
        points(answer5, 4) + points(answer6, 2) + points(answer7, 2) + points(answer8, 3) +
        points(answer9, 4) + 10

    {ctx, score}
  end

  defp ask(ctx, lines, options) do
    lines
    |> Enum.reduce(mes(ctx, "[Geschupenschte]"), &mes(&2, &1))
    |> next()
    |> select(options)
  end

  defp points(answer, correct), do: if(answer == correct, do: 10, else: 0)

  defp grade_quiz(ctx, 100) do
    ctx = set_char_var(ctx, :BSMITH_Q, 3)

    ctx =
      if checkquest(ctx, 2001) != -1 do
        changequest(ctx, 2001, 2002)
      else
        changequest(ctx, 2000, 2002)
      end

    ctx
    |> mes("Oh ho ho~")
    |> mes("You'll have")
    |> mes("no problem")
    |> mes("with this score!")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("I will entrust you with a job!")
    |> mes("Give me a little time to make the necessary arrangements.")
    |> mes("When you get back, I'll be ready!")
    |> close()
  end

  defp grade_quiz(ctx, _score) do
    ctx = set_char_var(ctx, :BSMITH_Q, 2)

    ctx =
      if checkquest(ctx, 2001) == -1 do
        changequest(ctx, 2000, 2001)
      else
        ctx
      end

    ctx = ctx |> mes(".............") |> next() |> mes("[Geschupenschte]")

    if get_char_var(ctx, :BSMITH_Q, 0) == 2 do
      ctx
      |> mes("How do I say this?")
      |> mes("How did you fail again?!")
      |> mes(
        "If you plan to perform your duties in this manner, I can't trust you with any kind of job..."
      )
      |> close()
    else
      ctx
      |> mes("Hmm...")
      |> mes(
        "It pains me to say this, but it seems you need to study a little more. You can never be"
      )
      |> mes("a Blacksmith with")
      |> mes("this score!")
      |> close()
    end
  end

  defp assign_order(ctx) do
    ctx =
      ctx
      |> mes("[Geschupenschte]")
      |> mes("Hmm...")
      |> mes("Now, where were")
      |> mes("those order request forms...")
      |> next()
      |> mes("^3355FF*Shuffling of Papers*")
      |> mes("*Rustling of Papers*^000000")
      |> next()
      |> mes("[Geschupenschte]")
      |> mes("Oh! Here it is!")
      |> mes("This is order that")
      |> mes("has been delayed")
      |> mes("the most...")
      |> mes("Heh heh~")
      |> next()
      |> mes("[Geschupenschte]")
      |> mes("Well, to make")
      |> mes("this you will need...")
      |> next()

    {order_step, order_quest} =
      case Enum.random(1..5) do
        1 -> {4, 2003}
        2 -> {5, 2004}
        3 -> {6, 2005}
        4 -> {7, 2006}
        _ -> {8, 2007}
      end

    ctx
    |> changequest(2002, order_quest)
    |> set_char_var(:BSMITH_Q, order_step)
    |> mes("[Geschupenschte]")
    |> list_materials(Map.fetch!(@materials, order_step))
    |> mes("you can buy from")
    |> mes("an NPC shop.")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes(
      "Collecting these items will be your test. Coincidentally, it's also a bit of a good way for me to save money. I'll repeat what you'll need to bring back to me..."
    )
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Okay~")
    |> mes("Good luck")
    |> mes("on your first job!")
    |> close()
  end

  defp list_materials(ctx, [{item1, n1}, {item2, n2}, {item3, n3}, {weapon, n4}]) do
    ctx
    |> mes("^8E6B23#{n1} #{Rathena.getitemname(item1)}^000000,")
    |> mes("^8E6B23#{n2} #{Rathena.getitemname(item2)}^000000,")
    |> mes("^8E6B23#{n3} #{Rathena.getitemname(item3)}^000000, and")
    |> mes("^8E6B23#{n4} #{Rathena.getitemname(weapon)}^000000, the kind")
  end

  defp check_materials(ctx, step) do
    materials = Map.fetch!(@materials, step)

    ctx =
      ctx
      |> mes("[Geschupenschte]")
      |> mes("Ah, you're back!")
      |> mes("Did you bring")
      |> mes("everything that")
      |> mes("I requested?")
      |> next()

    if Enum.all?(materials, fn {item, amount} -> count_item(ctx, item) >= amount end) do
      confirm_materials(ctx, materials, step + 5)
    else
      ctx
      |> mes("[Geschupenschte]")
      |> mes("You still haven't")
      |> mes("brought all the items.")
      |> mes("Do you need to be reminded")
      |> mes("or something? Bring me...")
      |> next()
      |> mes("[Geschupenschte]")
      |> list_materials(materials)
      |> mes("you can buy from")
      |> mes("an NPC shop.")
      |> next()
      |> mes("[Geschupenschte]")
      |> mes("Now, be sure to have")
      |> mes("everything I need when")
      |> mes("you come back. Remember,")
      |> mes("this is a test! You can't")
      |> mes("be a Blacksmith if you")
      |> mes("slack off!")
      |> close()
    end
  end

  defp confirm_materials(ctx, materials, delivery_step) do
    {weapon, _count} = List.last(materials)
    weapon_name = Rathena.getitemname(weapon)

    {ctx, choice} =
      ctx
      |> mes("[Geschupenschte]")
      |> mes("Wait...")
      |> mes("Didn't I tell you")
      |> mes("to get 3 Steel?")
      |> next()
      |> mes("[Geschupenschte]")
      |> mes("Oh, I guess it was")
      |> mes("two after all. Let's see...")
      |> mes("Yeah, you got everything!")
      |> mes("Now, just give me a second.")
      |> next()
      |> mes("[Geschupenschte]")
      |> mes(
        "Oh, you should make sure that you are not carrying ^FF0000more than one #{weapon_name}^000000, you should really only have an #{weapon_name} that you bought from an NPC shop in your inventory."
      )
      |> next()
      |> select(["Oh, could you give me a second?", "Oh, I brought what you asked for."])

    if choice == 1 do
      ctx
      |> mes("[Geschupenschte]")
      |> mes("Hmmm, it would be")
      |> mes("a good idea to put the")
      |> mes("rest of your items")
      |> mes("in Kafra Storage.")
      |> close()
    else
      forge_weapon(ctx, materials, delivery_step)
    end
  end

  defp forge_weapon(ctx, materials, delivery_step) do
    ctx =
      ctx
      |> mes("[Geschupenschte]")
      |> mes("Okay.")
      |> mes("Great~!!")
      |> next()
      |> mes("[Geschupenschte]")
      |> mes("^3355FF*Clang...!*^000000")
      |> next()
      |> mes("[Geschupenschte]")
      |> mes("^3355FF*Crash Crash!*^000000")
      |> next()

    ctx =
      materials
      |> Enum.reduce(ctx, fn {item, amount}, ctx -> delitem(ctx, item, amount) end)
      |> set_char_var(:BSMITH_Q, delivery_step)
      |> mes("[Geschupenschte]")
      |> mes("Wooooo~~~")
      |> mes("All done...")

    ctx
    |> hand_over_weapon(get_char_var(ctx, :BSMITH_Q, 0))
    |> mes("and don't forget")
    |> mes("the receipt!")
    |> close()
  end

  defp hand_over_weapon(ctx, 9) do
    ctx
    |> mes(
      "Okay, now take this to ^8E6B23Baisulist^000000 in Geffen of Rune-Midgarts Kingdom. Simply deliver it and bring me the receipt."
    )
    |> give_item(1610, 1)
    |> advance_quest(2003, 2008)
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Hmm...?")
    |> mes("What's that look for?")
    |> mes("This is not a normal")
    |> mes("Arc Wand! Look closely")
    |> mes("at the handle...")
    |> next()
    |> mes("^3355FFThe handle reads:")
    |> mes("'Super Arc Wand")
    |> mes("of Geschupenschte")
    |> mes("Mark 2.' It does seem")
    |> mes("to have a completely")
    |> mes("different feel.^000000")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Anyway, take this")
    |> mes("to ^8E6B23Baisulist^000000 in Geffen of Rune-Midgarts Kingdom,")
  end

  defp hand_over_weapon(ctx, 10) do
    ctx
    |> mes(
      "Okay, now take this to ^8E6B23Wickebine^000000 in Morocc of Rune-Midgarts Kingdom. Simply deliver it and bring me the receipt."
    )
    |> give_item(1219, 1)
    |> advance_quest(2004, 2009)
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Hmm...?")
    |> mes("What's that look for?")
    |> mes("This is not a normal")
    |> mes("Gladius! Look closely")
    |> mes("at the handle...")
    |> next()
    |> mes("^3355FFThe handle reads:")
    |> mes("'Super Gladius")
    |> mes("of Geschupenschte")
    |> mes("Mark 2.' It does seem")
    |> mes("to have a completely")
    |> mes("different feel.^000000")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Anyway, take this")
    |> mes("to ^8E6B23Wickebine^000000 in Morocc of Rune-Midgarts Kingdom,")
  end

  defp hand_over_weapon(ctx, 11) do
    ctx
    |> mes(
      "Okay, now take this to ^8E6B23Krongast^000000 in Lighthalzen. Simply deliver it and bring me the receipt."
    )
    |> give_item(1119, 1)
    |> advance_quest(2005, 2010)
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Hmm...?")
    |> mes("What's that look for?")
    |> mes("This is not a normal")
    |> mes("Tsurugi! Look closely")
    |> mes("at the blade...")
    |> next()
    |> mes("^3355FFThe blade reads:")
    |> mes("'Fine-edged")
    |> mes("Geschupenschte")
    |> mes("Tsurugi Special.'")
    |> mes("It does seem to feel")
    |> mes("completely different")
    |> mes("than normal Tsurugis...^000000")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Anyway, take this")
    |> mes("to ^8E6B23Krongast^000000 in Lighthalzen")
  end

  defp hand_over_weapon(ctx, 12) do
    ctx
    |> mes(
      "Okay, now take this to ^8E6B23Talpiz^000000 in Payon of Rune-Midgarts Kingdom. Simply deliver this and bring me the receipt."
    )
    |> give_item(1713, 1)
    |> advance_quest(2006, 2011)
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Hmm...?")
    |> mes("What's that look for?")
    |> mes("This is not a normal")
    |> mes("Arbalest! Look closely")
    |> mes("at the bow...")
    |> next()
    |> mes("^3355FFThe bow reads:")
    |> mes("Geschupenschte")
    |> mes("Arbalest Luxury Edition.")
    |> mes("It does seem more luxurious")
    |> mes("than regular Arbalests.^000000")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Anyway, take this")
    |> mes("to ^8E6B23Talpiz^000000 in Payon of Rune-Midgarts Kindgom,")
  end

  defp hand_over_weapon(ctx, 13) do
    ctx
    |> mes(
      "Okay, now take this to ^8E6B23Bismarc^000000 in Hugel. Simply deliver this and bring back the receipt."
    )
    |> give_item(1122, 1)
    |> advance_quest(2007, 2012)
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Hmm...?")
    |> mes("What's that look for?")
    |> mes("This is not a normal")
    |> mes("Ring Pommel Saber!")
    |> mes("Look closely at")
    |> mes("the handle...")
    |> next()
    |> mes("^3355FFThe handle reads:")
    |> mes("'Green Herbal")
    |> mes("Ring Pommel Saber")
    |> mes("of Geschupenschte")
    |> mes("Mark 2.' It does seem")
    |> mes("to have a completely")
    |> mes("different feel.^000000")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes(
      "The power of Green Herbs, which is imbued in this sword, can be very useful! You can save someone from slowly dying of poison by stabbing them quickly with this weapon!"
    )
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Anyway, take this")
    |> mes("to ^8E6B23Bismarc^000000 in Hugel")
  end

  defp hand_over_weapon(ctx, _step), do: ctx

  defp advance_quest(ctx, from, to) do
    if checkquest(ctx, from) != -1 do
      changequest(ctx, from, to)
    else
      ctx
    end
  end

  defp delivery_directions(ctx, 9) do
    ctx
    |> mes("In Geffen, at the")
    |> mes(
      "11 o'clock direction from the town center, you will find ^8E6B23Baisulist^000000. And don't forget the receipt."
    )
  end

  defp delivery_directions(ctx, 10) do
    ctx
    |> mes("Find the Swordmace")
    |> mes("dealer ^8E6B23Wickebine^000000 in Morocc. And don't forget the receipt.")
  end

  defp delivery_directions(ctx, 11) do
    mes(
      ctx,
      "In Lighthalzen, 6 o'clock direction from the town center, you will find ^8E6B23Krongast^000000 near the weapon shop. And don't forget the receipt."
    )
  end

  defp delivery_directions(ctx, 12) do
    mes(
      ctx,
      "In Payon, at the 5 o'clock direction from the town center, you will find ^8E6B23Talpiz^000000. And don't forget the receipt."
    )
  end

  defp delivery_directions(ctx, _step) do
    mes(
      ctx,
      "In Hugel, at the 1 o'clock direction from the town center, you will find ^8E6B23Bismarc^000000 near the airship. And don't forget the receipt."
    )
  end

  defp ask_for_receipt(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Geschupenschte]")
      |> mes("Hmmm...?")
      |> mes("Have you")
      |> mes("completed")
      |> mes("the delivery?")
      |> mes("Let's see that receipt~")
      |> next()
      |> select(["Yes sir, here it is.", "Receipt? I, uh, have it somewhere."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Geschupenschte]")
        |> mes("Return when you")
        |> mes("find the receipt~")
        |> mes("You didn't forget")
        |> mes("to receive a receipt.")
        |> mes("Right...?")
        |> close()

      count_item(ctx, 1073) > 0 ->
        accept_receipt(ctx)

      true ->
        ctx
        |> set_char_var(:BSMITH_Q, 3)
        |> mes("[Geschupenschte]")
        |> mes("You mean...")
        |> mes("You didn't get")
        |> mes("a receipt?")
        |> mes("What...?")
        |> next()
        |> mes("[Geschupenschte]")
        |> mes("A receipt is")
        |> mes("a Merchant's best friend!")
        |> mes("It's necessary to your job!")
        |> mes("You'll have to start your")
        |> mes("test all over again!")
        |> close()
    end
  end

  defp accept_receipt(ctx) do
    ctx = ctx |> set_char_var(:BSMITH_Q, 15) |> delitem(1073, 1)

    delivery_quest =
      Enum.find([2008, 2009, 2010, 2011], 2012, &(checkquest(ctx, &1) != -1))

    ctx
    |> changequest(delivery_quest, 2013)
    |> mes("[Geschupenschte]")
    |> mes("Oh ho ho~")
    |> mes("Great!")
    |> mes("You're truly")
    |> mes("a great Merchant!")
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("Good job!")
    |> mes(
      "Return to ^8E6B23Altiregen^000000 in Einbroch, the guy you first met when you applied for the Blacksmith job."
    )
    |> next()
    |> mes("[Geschupenschte]")
    |> mes("I have faith that you")
    |> mes("will be a great Blacksmith!")
    |> close()
  end
end
