defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.NamelessOne do
  @moduledoc """
  The Anonymous One, an unseen Assassin who gives applicants the written Assassin exam.

  ## Behavior

  - On a first attempt, offers advice about Assassin skills and stats before the exam.
  - Lets applicants who failed before retake the exam or be sent out of the guild.
  - Asks one of three random ten-question sets; more than 80 points passes the exam and
    advances the quest, otherwise the applicant is sent back with advice to ask Khai.
  - Applicants who already passed are only watched.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - Silent
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Zephyrus_cr
    - brianluau
    - Kisuka
    - JayPee
    - Euphy
    - MrAntares
    - Atemo

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @skill_quiz [
    {["1. Choose skill that is not required to learn Grimtooth."],
     [
       "Cloaking level 2",
       "Sonic Blow level 5",
       "Katar Mastery level 4",
       "Right hand Mastery level 2"
     ], [4]},
    {["2. What property does Enchant Poison possess?"], ["Poison", "Earth", "Fire", "Wind"], [1]},
    {["3. How does Level 4 Right Hand Mastery work?"],
     [
       "Recover 80% of damage decrease",
       "Recover 90% of damage decrease",
       "Increase 90% of damage",
       "Increase 108% of damage"
     ], [2]},
    {["4. What is the item required for using Venom Dust?"],
     ["Red Blood", "Blue Gemstone", "Yellow Gemstone", "Red Gemstone"], [4]},
    {["5. Which skill can you learn when you reach Level 5 Enchant Poison?"],
     ["Envenom", "Sonic Blow", "Venom Splasher", "Venom Dust"], [4]},
    {["6. Among the following skills, which allows you to walk while invisible?"],
     ["Hiding", "Back Slide", "Cloaking", "Sand Attack"], [3]},
    {["7. Choose the condition that is unrelated to Venom Splasher."],
     ["Poisoned target.", "Red Gemstone.", "Remaing HP of Target."], [2]},
    {[
       "8. Which monster is weak to a weapon with Vadon card (adds 20% damage on Fire property monster)?"
     ], ["Steel Chonchon", "Deviruchi", "Elder Willow", "Baphomet"], [3]},
    {["9. How much SP does", "Double Attack need?"],
     [
       "15",
       "It's a passive skill, so SP use is 0.",
       "It's passive skill, so SP use is 10.",
       "54"
     ], [2]},
    {["10. What is the best elemental Main Gauche weapon for hunting in Izlude dungeon?"],
     ["Wind Main Gauche", "Ice Main Gauche", "Earth Main Gauche", "Fire Main Gauche"], [1]}
  ]

  @equipment_quiz [
    {["1. Which monster", "drops a slotted Katar?"],
     ["Thief Bug", "Peco Peco", "Desert Wolf", "Hammer Cobolt"], [3]},
    {["2. Which monster", "drops a slotted Jur?"],
     ["Martin", "Desert Wolf", "Marionette", "Myst"], [1]},
    {["3. Which class is allowed to craft elemental weapons?"],
     ["Merchant", "Blacksmith", "Thief", "Priest"], [2]},
    {["4. Choose the weapon which is not in the Katar class."],
     ["Jamadhar", "Jur", "Katar", "Gladius"], [4]},
    {["5. What property do Izlude dungeon monsters posses?"], ["Water", "Fire", "Wind", "Earth"],
     [1]},
    {["6. Which monster", "cannot be a Cute Pet?"],
     ["Poporing", "Roda Frog", "Smokie", "Poison Spore"], [2]},
    {["7. Choose a monster that Fire property Daggers work the best on."],
     ["Dagger Goblin", "Mace Goblin", "Morning Star Goblin", "Hammer Goblin"], [4]},
    {["8. Choose the non-elemental Katar from the following:"],
     [
       "Katar of Raging Blaze",
       "Katar of Dusty Thornbush",
       "Sharpened Legbone of Ghoul",
       "Infiltrator"
     ], [4]},
    {["9. Which is the uncommon monster?"], ["Poring", "Mastering", "Ghostring", "Spore"], [3]},
    {["10. Choose the monster", "that is not Undead."],
     ["Drake", "Megalodon", "Spore", "Khalitzburg"], [3]}
  ]

  @class_quiz [
    {[
       "1. Choose the correct amount of the maximum dodge rate increase from the 'Increase Dodge' skill when at level 10."
     ], ["30", "40", "160", "20"], [1]},
    {["2. Choose a monster which detects hiding/cloaking Thieves and Assassins."],
     ["Worm Tail", "Andre", "Mummy", "Soldier Skeleton"], [2]},
    {["3. Choose a group of weapons that cannot be used by an Assassin at once."],
     [
       "Main Gaughe + Gladius",
       "Stiletto + Main Gauche",
       "Katar + Maingauche",
       "Hammer + Stiletto"
     ], [3]},
    {["4. Choose the town where Thieves can change their jobs."],
     ["Prontera", "Lutie", "Alberta", "Morocc"], [4]},
    {["5. Choose a card that does not affect the AGI stat."],
     [
       "Baphomet Jr. card",
       "Whisper Card",
       "Female Thiefbug card",
       "Male Thiefbug card"
     ], [2]},
    {["6. Choose the correct specialty of the Assassin class."],
     [
       "Excellent singing talent",
       "Excellent reading talent",
       "Excellent dancing talent",
       "Excellent dodge ability"
     ], [4]},
    {["7. Choose the maximum AGI bonus an Assassin can get at job level 50."],
     ["7", "8", "9", "10"], [4]},
    {["8. Choose the item that an Assassin cannot equip."], ["Dagger", "Helm", "Boots", "Brooch"],
     [2]},
    {["9. Choose the job change item for Thief."],
     [
       "Orange Gooey Mushroom",
       "Red Gooey Mushroom",
       "Orange Net Mushroom",
       "Orange Hair Mushroom"
     ], [1, 3]},
    {["10. Choose a card that would typically benefit an Assassin the least."],
     ["Whisper card", "Elder Willow card", "Soldier Skeleton card", "Cobold card"], [2]}
  ]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :ASSIN_Q2, 0) < 5 do
      cond do
        get_char_var(ctx, :ASSIN_Q2, 0) < 3 -> first_attempt(ctx)
        get_char_var(ctx, :ASSIN_Q2, 0) < 5 -> retake_attempt(ctx)
        true -> take_exam(ctx)
      end
    else
      ctx
      |> mes("[The Anonymous One]")
      |> mes("...I will keep watching you.")
      |> close()
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp first_attempt(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[The Anonymous One]")
      |> mes("Welcome, guest.")
      |> mes("Mwahaha, it's useless")
      |> mes("to try to find or see me...")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("I am perfectly hidden!")
      |> mes("To become undetectable can only be done by the greatest Assassins!")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "Aren't you scared that you can't see me? I could kill you at any time and it would be so easy..."
      )
      |> next()
      |> select(["I think I crapped my pants!", "You're all talk. I challenge you!"])

    if choice == 1 do
      ctx
      |> mes("[The Anonymous One]")
      |> mes("Now I see that")
      |> mes("you're nothing")
      |> mes("but a wimp.")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("Bwahahahahahah!")
      |> mes("Stop cowering in fear!")
      |> mes("It's making me laugh!")
      |> close()
    else
      ctx
      |> mes("[The Anonymous One]")
      |> mes("So...")
      |> mes("You wish for")
      |> mes("a challenge?")
      |> mes("From me?!")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "A river of blood follows my every footstep. I am nameless, for the sting of my blades is all anyone needs to know."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "I am here to test your knowledge, as well as your capacity for heartlessness. Those are both necessary to become an Assassin."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("For your challenge, you must")
      |> mes(
        "answer my questions correctly. Very difficult questions that only an Assassin can answer."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("Although I am heartless,")
      |> mes("I am not necessarily cruel. Before we proceed, is there anything you wish to know?")
      |> next()
      |> set_char_var(:ASSIN_Q2, 0)
      |> offer_advice_until_ready()
      |> mes("[The Anonymous One]")
      |> mes(
        "Hmpf. It is now time to test your knowledge. You are not allowed to miss more than one question."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "In other words, if you want to pass this test, you must give me 9 correct answers out of 10 questions. I won't let you know which answer you got wrong..."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("Are you ready?")
      |> mes("Prepare yourself!")
      |> take_exam()
    end
  end

  defp offer_advice_until_ready(ctx) do
    if get_char_var(ctx, :ASSIN_Q2, 0) < 3 do
      {ctx, choice} = select(ctx, ["...Skills?", "...Stats?", "Hmpf, I know it all."])

      ctx
      |> give_advice(choice)
      |> offer_advice_until_ready()
    else
      ctx
    end
  end

  defp give_advice(ctx, 1) do
    ctx
    |> mes("[The Anonymous One]")
    |> mes("Skills...?")
    |> mes(
      "Although skills can have circumstantial applications, I will tell you about the basic concepts."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "First, ^3355FFKatar Mastery^000000. This skill increases the damage of Katar class weapons. The higher the skill level, the more damage is increased."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "^3355FFLeft Hand Mastery^000000 and ^3355FFRight Hand Mastery^000000. Assassins can equip different weapons in each hand when using Dagger class weapons."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "But it is obviously more difficult to handle 2 weapons at a time than using just one. The Left and Right Hand Mastery skills increase the damage when using two Daggers."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "However, if you don't want to use two Daggers, you won't need this skill. You will see how 'Left Hand Mastery' works as soon as you reach 'Right Hand Mastery' Level 2."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "^3355FFSonic Blow^000000 allows you to strike an enemy 8 times at once. This skill only works with Katar weapons because of the speed it requires."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "Of course, the damage is affected by STR and weapon damage. You'll understand how this skill works when you reach Level 4 Katar Mastery."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "^3355FFGrimtooth^000000 allows you to attack enemies while hiding under the ground. As you master it, you'll be able to attack foes from a distance."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes("Since it's a ranged attack, it can be very useful when you're surrounded by enemies.")
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "Because you're required to perfectly hide yourself to use this skill, you must first learn Level 2 Cloaking before you can learn Grimtooth."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "To learn ^3355FFCloaking^000000, you must learn Level 2 Hiding. Then you will be able to move while hiding if you are close to a wall."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "The ^3355FFEnchant Poison^000000 skill allows you to enchant poison on the weapon you're using. This will temporarily give the weapon the Poison property."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "This will also make your attacks poison the enemy by chance. You can also use this skill to enchant the weapons of your party members..."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "^3355FFPoison React^000000 shields the user from attacks with the Poison property, and can be used on other people as well. However, you must learn Level 3 Enchant Poison first."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "^3355FFVenom Dust^000000 consumes a Red Gemstone to contaminate an area with poison. The duration of contamination increases with the level of this skill."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes("You can learn the Venom Dust skill after you learn Level 5 Enchant Poison.")
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "^3355FFVenom Splasher^000000 is a skill that, after it is used on a target, will cause it to explode when its HP is less than a certain amount after three seconds."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "When the target explodes, the enemies in the vicinity are also damaged. This is an essential skill for Assassins. It requires Level 5 Poison React and Level 5 Venom Dust."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes("Now...")
    |> mes("That's all I have to tell you")
    |> mes("about Assassin skills.")
    |> set_char_var(:ASSIN_Q2, 1)
    |> next()
  end

  defp give_advice(ctx, 2) do
    ctx
    |> mes("[The Anonymous One]")
    |> mes("Hmm, Stats...")
    |> mes("For Assassins, Agility, or AGI, is the most important stat.")
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "For the sake of assassination, STR is probably the second most important stat. But that is only my recommendation."
    )
    |> next()
    |> mes("[The Anonymous One]")
    |> mes(
      "I cannot give you better advice than that in regards to Stats. You should research and see which stats suit you, and decide what kind of Assassin you want to be."
    )
    |> set_char_var(:ASSIN_Q2, 2)
    |> next()
  end

  defp give_advice(ctx, 3) do
    ctx =
      if get_char_var(ctx, :ASSIN_Q2, 0) == 0 do
        ctx
        |> mes("[The Anonymous One]")
        |> mes("Know everything do you?!")
        |> mes("I'll be the judge of that!")
        |> next()
      else
        ctx
      end

    set_char_var(ctx, :ASSIN_Q2, 3)
  end

  defp give_advice(ctx, _choice), do: ctx

  defp retake_attempt(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[The Anonymous One]")
      |> mes("Having problems")
      |> mes("passing a simple test?")
      |> mes("You should have")
      |> mes("known better.")
      |> next()
      |> select(["Help me, how do I pass?", "I challenge you again!"])

    if choice == 1 do
      ctx
      |> mes("[The Anonymous One]")
      |> mes(
        "Well, that's a damn good question. But you're banished from the Assassin Guild, so it's no concern of mine..."
      )
      |> close()
      |> warp("moc_fild16", 206, 151)
    else
      ctx
      |> mes("[The Anonymous One]")
      |> mes("So I see...")
      |> mes(
        "Now go, but do not fear. I will be by your side as you learn the outcome of your choice..."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "Now, we shall test you once more! Keep in mind, you must answer 9 questions out of 10 correctly. Remember I am doing you a favor..."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "You must answer 9 questions out of 10 correctly. If you miss more than one question, you can never become an Assassin."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("Okay,")
      |> mes("are you ready?")
      |> mes("Good luck.")
      |> take_exam()
    end
  end

  defp take_exam(ctx) do
    questions =
      case Enum.random(1..3) do
        1 -> @skill_quiz
        2 -> @equipment_quiz
        3 -> @class_quiz
        _ -> []
      end

    {ctx, score} = ctx |> next() |> ask_questions(questions)
    grade_exam(ctx, score)
  end

  defp ask_questions(ctx, questions) do
    Enum.reduce(questions, {ctx, 0}, fn {prompt, options, correct}, {ctx, score} ->
      ctx = mes(ctx, "[The Anonymous One]")
      ctx = Enum.reduce(prompt, ctx, &mes(&2, &1))
      {ctx, choice} = ctx |> next() |> select(options)

      if choice in correct, do: {ctx, score + 10}, else: {ctx, score}
    end)
  end

  defp grade_exam(ctx, score) do
    cond do
      get_char_var(ctx, :ASSIN_Q2, 0) == 3 -> grade_first_attempt(ctx, score)
      get_char_var(ctx, :ASSIN_Q2, 0) == 4 -> grade_retake(ctx, score)
      true -> ctx
    end
  end

  defp grade_first_attempt(ctx, score) do
    ctx =
      ctx
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("Hmpf.")
      |> mes("Somehow, you")
      |> mes("have shown me")
      |> mes("great effort.")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("Let's see...")
      |> mes("You scored")
      |> mes("#{score} percent...")

    if score > 80 do
      ctx
      |> set_char_var(:ASSIN_Q2, 5)
      |> changequest(8002, 8003)
      |> mes("Well done.")
      |> mes("You pass.")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "However, another test awaits you. When you go inside the next area, you will receive your instructions..."
      )
      |> close()
    else
      ctx
      |> set_char_var(:ASSIN_Q2, 4)
      |> mes("That means you fail!")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "How could you expect to be an Assassin with this score? Keep training and come back when you're ready."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("I would ask 'Khai,' the one who processed your application, for advice.")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "You may also use this code: ^880000iro.ragnarokonline.com^000000. Somehow, those words are linked to a vast body of otherworldly knowledge..."
      )
      |> close()
      |> warp("in_moc_16", 19, 76)
    end
  end

  defp grade_retake(ctx, score) do
    ctx =
      ctx
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("You showed")
      |> mes("great effort...")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("Let's see...")
      |> mes("You scored")
      |> mes("#{score} points...")

    if score > 80 do
      ctx
      |> set_char_var(:ASSIN_Q2, 5)
      |> changequest(8002, 8003)
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "You didn't fail this time! But you're not done just yet. You have another test ahead of you. Once you proceed, you will be informed about your next trial."
      )
      |> close()
    else
      ctx
      |> set_char_var(:ASSIN_Q2, 4)
      |> mes("You failed!")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("You're too underqualified. How can you even think about becoming an Assassin?!")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "I'm surprised that you were even able to become a Thief. Go away, and come back only when you know what the hell you're doing."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes("Hmpf, if you really don't have a clue, I will give you a little advice.")
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "Go ask 'Khai,' the guy who takes care of your test application, maybe he will help you."
      )
      |> next()
      |> mes("[The Anonymous One]")
      |> mes(
        "You may also wish to take advantage of the ancient code, ^3355FFiro.ragnarokonline.com^000000. Supposedly, those words are linked to a vast body of otherworldly knowledge..."
      )
      |> close()
      |> warp("in_moc_16", 19, 76)
    end
  end
end
