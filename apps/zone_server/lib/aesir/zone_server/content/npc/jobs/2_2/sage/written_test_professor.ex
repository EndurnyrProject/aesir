defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Sage.WrittenTestProfessor do
  @moduledoc """
  Claytos Verdo, the Sage academy professor who administers the written entrance test.

  ## Behavior

  - Greets non-Mages with class-specific small talk.
  - Gives enrolled candidates one of three random 20-question tests worth 5 points per
    correct answer.
  - Passes candidates who score at least 80 points and sends them to the practical
    examination; failing candidates may retake the test.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Unknown Translator
    - Darkchild
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in03",
        x: 105,
        y: 177,
        dir: 5,
        sprite: 754,
        name: "Written Test Professor",
        scope: :shared,
        unique_name: "Written Test Professor#s"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @question_sets [
    [
      {"1. Choose an item that the Gift merchant in Prontera does not sell.",
       ["China", "Red Frame", "Bouquet", "Glass Bead"], 3},
      {"2. Choose a city where you cannot purchase a Stiletto.",
       ["Prontera", "Morocc", "Geffen", "Lutie"], 1},
      {"3. Choose the closest city to Turtle Island.",
       ["Al De Baran", "Alberta", "Comodo", "Izlude"], 2},
      {"4. Choose the monster that is a different type than the others.",
       ["Raggler", "Pest", "Frilldora", "Aster"], 4},
      {"5. Choose the monster that has a different attribute than the others.",
       ["Mantis", "Metaller", "Rocker", "Horn"], 2},
      {"6. Choose the monster that is different sized than the others.",
       ["Raydric", "Raydric Archer", "Wanderer", "Dark Frame"], 1},
      {"7. Choose the monster which doesn't drop 'Alcohol'.",
       ["Horong", "Plankton", "Poison Spore", "Toad"], 3},
      {"8. Choose the NPC that is irrelevant to the Knight job change quest.",
       ["Sir Siracuse", "Thomas Servantes", "Sir Windsor", "Lady Amy"], 2},
      {"9. Choose the NPC that is not a citizen of Prontera.",
       ["Tono", "Pina", "YuPi", "Hollgrehenn"], 2},
      {"10. Choose the right name for the Kafra lady who wears glasses.",
       ["Pavianne", "Roxie", "Leilah", "Curly Sue"], 3},
      {"11. How much SP is spent to use lvl 7 Thunderstorm?", ["49", "59", "69", "74"], 2},
      {"12. Choose the right amount of damage reduction and SP consumption of the Energy Coat skill when the caster's remaining SP is 50%.",
       ["Damage -24% SP1.5%", "Damage -24% SP2%", "Damage -18% SP1.5%", "Damage -18% SP2%"], 4},
      {"13. Choose the property that is irrelevant to 'Bolt' type skills for the Mage class.",
       ["Water", "Earth", "Fire", "Wind"], 2},
      {"14. Choose the right chance and attack strength for lvl 7 Double Attack, the Thief skill.",
       ["35% / 120%", "35% / 140%", "40% / 120%", "40% / 140%"], 2},
      {"15. Choose the skill that is irrelevant to learning Magnus Exorcismus, the Priest skill.",
       ["Divine Protection", "Heal", "Ruwach", "Aqua Benedicta"], 1},
      {"16. Choose the correct defense and ability of the Bunny Band.",
       ["1 / LUK +2", "1 / LUK +5", "2 / LUK +2", "2 / LUK +5"], 3},
      {"17. Choose the class that cannot equip Padded Armor.",
       ["Swordman", "Merchant", "Thief", "Archer"], 4},
      {"18. Choose the item that cures all abnormal status and restores full HP and SP at the same time.",
       ["Royal Jelly", "Yggdrasil Seed", "Yggdrasilberry", "Mastella Fruit"], 3},
      {"19. Who rules the Rune-Midgarts kingdom right now?",
       ["Tristun the 3rd", "Tristram the 3rd", "Tristar the 3rd", "Trast the 3rd"], 2},
      {"20. Choose the god of Crusaders.", ["Odin", "Loki", "Thor", "Venadin"], 1}
    ],
    [
      {"1. Choose the jewel that the Morocc Jewel Merchant does not sell.",
       ["Topaz", "Garnet", "Diamond", "Sapphire"], 2},
      {"2. Choose the city where users cannot purchase Monster's Feed from an NPC.",
       ["Prontera", "Morocc", "Al De Baran", "Alberta"], 3},
      {"3. Choose the closest city to the Maze.", ["Prontera", "Morocc", "Geffen", "Payon"], 1},
      {"4. Choose the monster that is a different type than the others.",
       ["Muka", "Drops", "Plankton", "Penomena"], 4},
      {"5. Choose the monster with the different attribute.",
       ["Dokebi", "Isis", "Giearth", "Deviruchi"], 3},
      {"6. Choose the monster that is different in size.",
       ["Thiefbug (Aggressive)", "Horn", "Metaller", "Argos"], 4},
      {"7. Choose the monster which does not drop 'Yggdrasil Leaf'.",
       ["Marduk", "Baphomet Jr.", "Angeling", "Wanderer"], 1},
      {"8. Choose the NPC that is irrelevant to the Priest job change quest.",
       ["Paul", "Sir Windsor", "Peter S. Alberto", "Cecilia"], 2},
      {"9. Choose the NPC that is not a citizen of Morocc.",
       ["Syvia", "Akira", "Antonio", "Dmitrii"], 3},
      {"10. Choose the Kafra lady who has gorgeous blue hair.",
       ["Pavianne", "Roxie", "Leilah", "Curly Sue"], 1},
      {"11. Choose the skill that is irrelevant to learning Fire Wall, the Mage skill.",
       ["lvl 4 Fire Bolt", "lvl 4 Napalm Beat", "lvl 5 Fire Ball", "lvl 1 Sight"], 2},
      {"12. How much SP can be restored when learning SP recovery at lvl 6 (without being affected by INT)?",
       ["14", "16", "18", "21"], 3},
      {"13. How many INT points does a Mage receive as a bonus at job lvl 33?",
       ["7", "6", "5", "4"], 4},
      {"14. Choose the correct SP consumption and the skill duration for Improve Concentration lvl 5 (Archer skill).",
       ["45 / 80 sec", "50 / 80 sec", "45 / 90 sec", "50 / 90 sec"], 1},
      {"15. Choose the skill that is irrelevant to learning Maximize Power, the Blacksmith skill.",
       ["Hilt Binding", "Skin Tempering", "Hammer Fall", "Weapon Perfection"], 2},
      {"16. What is the correct defense rate and ability of Cute Ribbon?",
       ["0 / SP +20", "0 / SP +30", "1 / SP +20", "1 / SP +30"], 3},
      {"17. Choose the class that cannot equip Saint Robe.",
       ["Swordman", "Merchant", "Thief", "Acolyte"], 3},
      {"18. Choose the abnormal status that cannot be cured by Green Potion.",
       ["Silence", "Chaos", "Blind", "Curse"], 4},
      {"19. Choose the correct name for the ancient kingdom that disappeared somewhere in Geffen.",
       ["Geffayon", "Geffenia", "Gefenn", "Jaffen"], 2},
      {"20. Choose the correct name for the tree that has become the root of this world.",
       ["Yggdrasil", "Iggdrassil", "Mastella", "Dead Branch"], 1}
    ],
    [
      {"1. Choose the item that the Magical Tool merchant in Geffen does not sell.",
       ["Mantle", "Wand", "Circlet", "Silver Robe"], 1},
      {"2. Choose the city where users cannot purchase Blade from an NPC.",
       ["Prontera", "Izlude", "Al De Baran", "Payon"], 3},
      {"3. Choose the closest city to Glast Heim.", ["Prontera", "Geffen", "Morocc", "Payon"], 2},
      {"4. Choose the monster that is a different type than the others.",
       ["Aster", "Marc", "Marse", "Marin"], 4},
      {"5. Choose the monster that has a different attribute.",
       ["Baby Desert Wolf", "Smokie", "Picky", "Choco"], 2},
      {"6. Choose the monster that is different sized.",
       ["Drake", "Wraith", "Evil Druid", "Khalitzburg"], 1},
      {"7. Choose the monster that does not drop 'Phracon'.",
       ["Pupa", "Peco Peco Egg", "Savage Bebe", "Baby Desert Wolf"], 2},
      {"8. Choose the NPC that is irrelevant to the Blacksmith job change quest.",
       ["Altiregen", "Geschupenschte", "Barcadi", "Baisulist"], 3},
      {"9. Choose the NPC that is not a citizen of Al De Baran.",
       ["RS125", "GOD-POING", "Stromme", "Chemirre"], 2},
      {"10. Choose the Kafra lady who is the youngest among the staff.",
       ["Pavianne", "Roxie", "Leilah", "Curly Sue"], 4},
      {"11. Choose the correct SP consumption and the number of evasions when using Safety Wall lvl 6.",
       ["SP 40, 6 times", "SP 35, 6 times", "SP 40, 7 times", "SP 35, 7 times"], 3},
      {"12. Choose the correct amount of magic attack for Napalm Beat lvl 6.",
       ["MATK * 1.2", "MATK * 1.3", "MATK * 1.4", "MATK * 1.5"], 2},
      {"13. Choose the catalyst stone for Mage Solution no. 4 that is used for the Mage job change quest.",
       ["Blue Gemstone", "Red Gemstone", "Yellow Gemstone", "1 carat Diamond"], 4},
      {"14. Choose the correct attack strength and SP consumption for Bash lvl 6, the Swordman skill.",
       ["250% / 8", "280% / 8", "280% / 15", "310% / 15"], 3},
      {"15. Choose the skill that is irrelevant to learning Claymore Trap, the Hunter skill.",
       ["Remove Trap", "Land Mine", "Ankle Snare", "Flasher"], 1},
      {"16. Choose the correct defense and ability of Wedding Veil.",
       ["0 / MDEF +3", "0 / MDEF +5", "1 / MDEF +3", "1 / MDEF +5"], 2},
      {"17. Choose the class that cannot equip Coat.",
       ["Swordman", "Merchant", "Thief", "Novice"], 4},
      {"18. Choose the item that is not an ingredient for Blue Dyestuffs.",
       ["Alcohol", "Detrimindexta", "Karvodailnirol", "Blue Herb"], 3},
      {"19. When the world was created by the god Odin, what did he use for the material?",
       ["The heart of Ymir", "The nail of Ymir", "The tooth of Ymir", "The memento of Ymir"], 1},
      {"20. Choose the metal that has rumored to bring fortune and fame to a person with the destiny.",
       ["Empelium Gold", "Emperium", "Emperor", "Phracon"], 2}
    ]
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Claytos Verdo]")

    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:mage) do
      ctx |> greet_non_mage() |> close()
    else
      talk_to_candidate(ctx, get_char_var(ctx, :SAGE_Q, 0))
    end
  end

  defp greet_non_mage(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:sage) ->
        ctx
        |> mes("Eh? What? Why are you back here?")
        |> mes("Do you want to enter the school again?")
        |> next()
        |> mes("[Claytos Verdo]")
        |> mes(
          "Now, I understand how you feel. Since you graduated, you have become a Sage. A Sage...until the end of your days."
        )
        |> mes(
          "So, be strong and independent. Try to explore some places where nobody else has ventured to go."
        )
        |> next()
        |> mes("[Claytos Verdo]")
        |> mes("Don't forget to record everything you've experienced.")
        |> mes("You must share your knowledge with others by taking excellent notes.")

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) ->
        ctx
        |> mes("What are you doing here, kid?")
        |> mes("This is a Magic Academy, not a day care center.")
        |> next()
        |> mes("[Claytos Verdo]")
        |> mes("Go outside and play with the Porings. That's your job.")
        |> mes("Go out, chop chop!!")

      Rathena.job_id(class(ctx)) == Rathena.job_id(:wizard) ->
        ctx
        |> mes("Well...look who came crawling back. Magic addict.")
        |> mes("Yeah yeah, so it's not so bad to be devoted to magic.")
        |> next()
        |> mes("[Claytos Verdo]")
        |> mes("But I hope you remember, no one can live alone.")
        |> mes(
          "Although you're strong enough for solo play, you must cooperate and help other people. That's what a Wizard shoud stand for."
        )

      true ->
        ctx
        |> mes(
          "Hmm... I understand that you want to enter our prestigious academy, but since you chose to live as a different class,"
        )
        |> mes("I don't think you can become a Sage.")
        |> next()
        |> mes("[Claytos Verdo]")
        |> mes(
          "So, don't go around regretting why you chose a job other than Sage. You'd better go out and hunt, leveling up your current job."
        )
    end
  end

  defp talk_to_candidate(ctx, 0) do
    ctx
    |> mes("What, do you want to be a Sage?")
    |> mes("I can tell by your eyes, hungering for wisdom.")
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes("Of course, if you want to be a Sage, you must first enter the academy.")
    |> mes("Apply for enrollment, and then come again.")
    |> close()
  end

  defp talk_to_candidate(ctx, quest) when quest in [1, 2, 3] do
    ctx
    |> mes("Hah! You didn't even finish the application process!?")
    |> mes("I see...did Metheus tell you something?")
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes("Do your best. It'll be a good experience for you.")
    |> mes("Come again when you finish the application.")
    |> close()
  end

  defp talk_to_candidate(ctx, 4) do
    ctx =
      ctx
      |> mes("Welcome to the Schweicherbil Magic Academy.")
      |> mes("You applied for this test already, didn't you?")
      |> next()
      |> mes("[Claytos Verdo]")

    ctx
    |> mes("Let's see, your name is #{char_name(ctx, 0)}...")
    |> mes("Okay, let's get started!")
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes(
      "The test that I am going to give you will test your knowledge on all of the academic subjects in the world."
    )
    |> mes(
      "I will give you 20 questions, with each question being worth 5 points. When you earn a grade of 80 points, you will pass the test."
    )
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes("Okay, there's no need to wait. Let's start right away")
    |> mes("Oh, and if you don't answer immediately, the test will be cancelled.")
    |> give_written_test()
  end

  defp talk_to_candidate(ctx, 5) do
    ctx
    |> mes("Welcome back.")
    |> mes("So, did you study harder this time?")
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes(
      "You will take the written test under the same conditions as the test you took before. I'll give you 20 questions."
    )
    |> mes(
      "Each correct answer will give you 5 points. When your score reaches 80 points, you pass the test."
    )
    |> next()
    |> set_char_var(:sage_m2, Enum.random(1..3))
    |> mes("[Claytos Verdo]")
    |> mes("Okay, there's no need to wait.")
    |> mes("Answer immediately, or I'll fail you again.")
    |> set_char_var(:SAGE_Q, 5)
    |> give_written_test()
  end

  defp talk_to_candidate(ctx, 6) do
    ctx
    |> mes("What else do you want?! Do you want to take this test again?")
    |> mes("You've already passed!")
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes("Go visit Professor Hermes for the practical examination.")
    |> mes("Move!")
    |> close()
  end

  defp talk_to_candidate(ctx, 15) do
    ctx
    |> mes("Heh heh, It seems you're done with your dissertation.")
    |> mes("But I'm not the person handling that part of the test.")
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes("submit your thesis to Dean Kayron.")
    |> mes("He will decide whether you are qualified to graduate or not.")
    |> close()
  end

  defp talk_to_candidate(ctx, _quest) do
    ctx
    |> mes("I'm too busy to take care of written tests.")
    |> mes("Come back later, and I'll spare some time to talk.")
    |> close()
  end

  defp give_written_test(ctx) do
    ctx = next(ctx)
    questions = Enum.at(@question_sets, Enum.random(1..3) - 1)

    {ctx, score} =
      Enum.reduce(questions, {ctx, 0}, fn {prompt, options, answer}, {ctx, score} ->
        {ctx, choice} = ctx |> mes(prompt) |> next() |> select(options)
        {ctx, grade_answer(ctx, score, choice == answer)}
      end)

    ctx
    |> mes("[Claytos Verdo]")
    |> announce_grading()
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes("Let's see...")
    |> mes("Hmm... hmm...")
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes("You got #{score} points.")
    |> announce_result(score)
    |> close()
  end

  defp grade_answer(%Ctx{status: {:error, _}}, score, _correct?), do: score
  defp grade_answer(_ctx, score, true), do: score + 5
  defp grade_answer(_ctx, score, false), do: score

  defp announce_grading(ctx) do
    if get_char_var(ctx, :SAGE_Q, 0) == 4 do
      ctx
      |> mes("Well, you answered all 20 of the questions.")
      |> mes("Okay, let me check your answers and add up your score.")
    else
      ctx
      |> mes("Well, we finished all 20 questions.")
      |> mes("Now, let's check how many points you got.")
    end
  end

  defp announce_result(ctx, 100) do
    ctx =
      if get_char_var(ctx, :SAGE_Q, 0) == 4 do
        mes(ctx, "Excellent! You seem fully qualified to become a Sage!")
      else
        mes(ctx, "Excellent! You must have studed really hard for this test!")
      end

    ctx
    |> set_char_var(:SAGE_Q, 6)
    |> changequest(2041, 2046)
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes("You have passed the written test.")
    |> mes("Go visit Professor Hermes for the practical examination.")
  end

  defp announce_result(ctx, score) when score >= 80 do
    ctx
    |> set_char_var(:SAGE_Q, 6)
    |> changequest(2041, 2046)
    |> mes(
      "Yeah, not bad. I assume that you will at least understand what you're going to learn in class."
    )
    |> next()
    |> mes("[Claytos Verdo]")
    |> mes("You passed the written test.")
    |> mes("Go visit Professor Hermes for the practical examination.")
  end

  defp announce_result(ctx, _score) do
    if get_char_var(ctx, :SAGE_Q, 0) == 4 do
      ctx
      |> set_char_var(:SAGE_Q, 5)
      |> mes("Oh well...what a shame: You failed.")
      |> next()
      |> mes("[Claytos Verdo]")
      |> mes("But I'll give you another chance to take the written test,")
      |> mes("Go study harder and come back later.")
    else
      ctx
      |> mes("Oh what a shame: You failed.")
      |> next()
      |> mes("[Claytos Verdo]")
      |> mes("But I'll give you another chance,")
      |> mes("Go study even harder and come back.")
    end
  end
end
