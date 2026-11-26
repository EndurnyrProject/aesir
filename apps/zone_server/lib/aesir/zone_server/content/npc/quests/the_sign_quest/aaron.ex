defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Aaron do
  @moduledoc """
  Drunken teacher who hosts the Sign quest's Quiz Challenge against Jesqurienne.

  ## Behavior

  - Explains the quiz rules when the player is sent to him and readies the questions.
  - Runs a ten-question quiz, each question drawn at random from a small pool; Jesqurienne
    answers each one with a fixed chance and comments on the running score.
  - Losing to Jesqurienne advances the quest to the lost-quiz step, a tie or a win to the
    won-quiz step.
  - Otherwise flirts with the player, reacting to their sex.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen_in",
        x: 61,
        y: 72,
        dir: 7,
        sprite: 754,
        name: "Aaron",
        scope: :shared,
        unique_name: "Aaron#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @rounds 1..10

  @questions %{
    1 => [
      {["1. Which NPC is", "not relevant to the", "Blacksmith Job Quest?"],
       ["Baisulist", "Wickebine", "Barcardi", "Krongast"], 3},
      {["1. Which item is not", "relevant to the creation", "of a Counteragent?"],
       ["Karvodailnirol", "Detrimindexta", "Alcohol"], {:not, 1}},
      {["1. Choose the", "monster that is", "a different size", "than the others."],
       ["Giant Whisper", "Marine", "Cornutus", "Kobold Archer"], 2}
    ],
    2 => [
      {[
         "[Aaron]",
         "2. Choose the skill",
         "related to the Priest's",
         "B.S. Sacramenti from the",
         "ones displayed in the list."
       ], ["Lex Divina", "Gloria", "Recovery", "Sanctuary"], 2},
      {[
         "[Aaron]",
         "2. Choose the material that",
         "is not related to the creation",
         "of a Condensed White Potion."
       ], ["Medicine Bowl", "Witch Starsand", "Empty Bottle", "Empty Potion Bottle"], 3},
      {[
         "[Aaron]",
         "2. Choose the item that is",
         "necessary for a Blacksmith",
         "to create a Gladius."
       ], ["Sapphire", "Zircon", "Topaz", "Cursed Ruby"], 1}
    ],
    3 => [
      {[
         "[Aaron]",
         "3. Choose the",
         "property that is",
         "unrelated to the",
         "Mage's Bolt type skills."
       ], ["Water", "Earth", "Fire", "Wind"], 2},
      {["[Aaron]", "3. What is the", "Bunny Band's DEF", "and its added ability?"],
       ["1 / LUK +2", "1 / LUK +5", "2 / LUK +2", "2 / LUK +5"], 3},
      {[
         "[Aaron]",
         "3. Choose the prefix or",
         "suffix that is incorrectly",
         "matched with its Monster",
         "Card name."
       ],
       [
         "Hornet Card - Martyr",
         "Requiem - Chaos",
         "Wormtail - Clever",
         "Golem - Immortal"
       ], 4}
    ],
    4 => [
      {[
         "[Aaron]",
         "4. Choose the correct",
         "name of the ruler of the",
         "Rune-Midgarts Kingdom."
       ], ["Tristan lll", "Tristram lll", "Tristar lll", "Trust lll"], 2},
      {["[Aaron]", "4. Choose the monster", "that is a different type", "than the others."],
       ["Penomena", "Hatii", "Pest", "Explosion"], 1}
    ],
    5 => [
      {[
         "[Aaron]",
         "5. Choose the monster",
         "which does not drop the",
         "'Yggdrasil Leaf' item."
       ], ["Marduk", "Baphomet Jr.", "Angeling", "Wanderer"], 1},
      {["[Aaron]", "5. Choose the job class", "that cannot equip Silk Robe."],
       ["Swordman", "Merchant", "Hunter", "Mage"], 3},
      {["[Aaron]", "5. Choose the level", "requirement for entering", "the PvP Room."],
       ["30", "31", "32", "33"], 2}
    ],
    6 => [
      {["[Aaron]", "6. What is the", "correct weight", "for 1 Empty Bottle?"], ["1", "2", "3"],
       2},
      {["[Aaron]", "6. Choose the", "correct DEF for", "the Indian Filet item."],
       ["0", "1", "2", "3"], 4},
      {["[Aaron]", "6. What is the", "city closest to", "Turtle Island?"],
       ["Al De Baran", "Alberta", "Comodo", "Izlude"], 2}
    ],
    7 => [
      {[
         "[Aaron]",
         "7. Fifty-one multiplied",
         "by fifteen, divided by three,",
         "plus five is equal to...?"
       ], ["250", "255", "260", "265"], 3},
      {[
         "[Aaron]",
         "7. Four thousand five hundred sixty divided by four, divided by two, plus three is equal to...?"
       ], ["573", "574", "575", "576"], 1},
      {[
         "[Aaron]",
         "7. Three thousand one hundred",
         "two added to five hundred, plus four, divided by six equals..."
       ], ["600", "601", "602"], 2}
    ],
    8 => [
      {[
         "[Aaron]",
         "8. Choose the building",
         "that is the closest to the",
         "Item Upgrade Place in Juno."
       ], ["Tavern", "Monster Library", "Tool Shop", "Weapon Shop"], 4},
      {[
         "[Aaron]",
         "8. Choose the Hunter's",
         "Trap skill which does not",
         "inflict Property Damage."
       ], ["Claymore Trap", "Freezing Trap", "Shockwave Trap", "Land Mine"], 3}
    ],
    9 => [
      {[
         "[Aaron]",
         "9. Which monster would",
         "receive the most damage",
         "from a Fire Property Dagger?"
       ], ["Dagger Goblin", "Mace Goblin", "Morning Star Goblin", "Hammer Goblin"], 4},
      {[
         "[Aaron]",
         "9. Choose the monster",
         "on which the Mage skill,",
         "''Stone Curse,'' is ineffective. ^FFFFFFaaaaaa aaaaaaa aaaaaa aaaaaaa aaaaaaaaa^000000"
       ], ["Elder Willow", "Evil Druid", "Magnolia", "Marc"], 2}
    ],
    10 => [
      {[
         "[Aaron]",
         "10. Choose the NPC",
         "that looks different",
         "than all the others."
       ],
       [
         "Prontera Hollgrehenn",
         "Prontera Doll Merchant",
         "Izlude Meat Merchant",
         "Morocc Meat Merchant"
       ], 3},
      {[
         "[Aaron]",
         "10. Choose the item",
         "that cannot be equipped",
         "by Novice class characters."
       ], ["Funeral Hat", "Shackles", "Wooden Mail", "Pantie"], 3}
    ]
  }

  @jesqurienne_answers %{
    1 =>
      {9, ["Heh heh...", "The first question", "is always too easy!"],
       ["Huh...?", "How can I not know", "the answer to this?!"]},
    2 =>
      {8, ["Ho ho ho ho~!", "I know the answer.", "Any fool should know", "this. But do you?"],
       [
         "Oh...",
         "I knew the answer",
         "to this just yesterday!",
         "Why can't I think of it now?!"
       ]},
    3 =>
      {8, ["Ah...", "That's another", "point for me!"],
       ["z...z...Z", "W-what? Oh!", "Well, I won't need", "that point anyway..."]},
    4 =>
      {8, ["That counts as", "a question? You're", "being too easy!"],
       ["I know the", "answer! W-why", "can't I think of", "it right now?!"]},
    5 =>
      {9,
       [
         "I didn't have",
         "to think very hard",
         "to know the answer.",
         "Are you still thinking?",
         "I wouldn't think you'd know!"
       ], ["I...", "Hold on,", "I know this one...", "(Oh craaaaaap!)"]},
    6 =>
      {9, ["^333333*Sigh...*^000000", "Simple questions,", "simple answers.", "Did you get it?"],
       ["W-wait...!", "I know the", "answer to this", "one! Just let me", "th-think...!"]},
    7 =>
      {9, ["Math?", "My mind is", "a veritable", "calculator!", "Ho ho ho~!"],
       [
         "What the--?!",
         "Why is all the math",
         "written out in words",
         "instead of the traditional",
         "numerics and symbols?!",
         "A-answer me--!!"
       ]},
    8 =>
      {9, ["Hah hah~!", "That was a", "piece of cake!"],
       ["Grrr...", "Why don't", "I know this one?!"]},
    9 =>
      {9,
       [
         "Ahhh...",
         "I'm just breezing",
         "through this Quiz Challenge!",
         "Aren't you having a hard time?"
       ], ["Huh...?", "I don't understand", "why I don't know this..."]},
    10 =>
      {9, ["As usual, I got", "the last question", "absolutely right~"],
       ["Huh...", "Wh-what was", "the question again?", "Nooo, I missed it!"]}
  }

  @standings %{
    3 =>
      {[
         "Heh heh...",
         "It looks like",
         "I'm beating you!",
         "But you shouldn't",
         "be surprised..."
       ], ["Still, you're", "smarter than", "I thought you'd be..."],
       [
         "W-wait a minute!",
         "H-how could you",
         "have more points",
         "than me?! I better",
         "get serious!"
       ]},
    4 =>
      {[
         "Heh heh~ It looks",
         "like I have the lead.",
         "But that's only natural for",
         "someone as brilliant as me~"
       ],
       [
         "Up till now",
         "you've managed",
         "to keep up with",
         "me. Huh. So you're",
         "not a total idiot..."
       ],
       [
         "Heh heh~ It looks",
         "like I have the lead.",
         "But that's only natural for",
         "someone as brilliant a--",
         "Wait. How do you have",
         "more points than me?!"
       ]},
    5 =>
      {[
         "Oh? What a surprise.",
         "I'm in the lead. I know",
         "the suspense must be",
         "killing you, but I'm pretty",
         "sure who the winner will",
         "be. Me me me meee~"
       ],
       [
         "Are you copying",
         "my answers? Because",
         "there's no way we can",
         "be tied right now..."
       ],
       [
         "I...",
         "I must be more",
         "drunk than I thought",
         "if I'm losing right now..."
       ]},
    6 =>
      {[
         "Oh, look at that.",
         "I have more points",
         "than you. I know, it",
         "must be frustrating",
         "trying to keep up."
       ],
       [
         "Mmm...?",
         "How are you cheating?!",
         "You having the same score",
         "as me must be impossible!"
       ],
       [
         "I don't understand.",
         "You have a higher sco--",
         "I don't-- How can yo--",
         "Why is this happening?"
       ]},
    7 =>
      {[
         "Ah. Did I tell you",
         "I was in the lead",
         "right now? Well, let",
         "me remind you, in case",
         "I forget. Ho ho ho ho~!"
       ],
       [
         "That's it.",
         "I don't understand",
         "how your score is",
         "equal to mine. Are",
         "you getting bonus",
         "points somehow?!"
       ],
       [
         "There's no other",
         "explanation! You've",
         "got to be using some",
         "sort of crib sheet! But",
         "where are you hiding it?"
       ]},
    8 =>
      {[
         "I know, you're wondering",
         "how such an intelligent",
         "person can exist. Well,",
         "I guess my intellect sort",
         "of balances the stupidity",
         "of the rest of the world..."
       ],
       [
         "How can our scores",
         "be equal? No... No...",
         "Think, Jesqurienne...",
         "Time travel isn't possible.",
         "But why would you time travel",
         "for the answers to a quiz?"
       ],
       [
         "I... I don't",
         "get it. H-how are",
         "you w-winning? M-my",
         "whole perception of",
         "reality is starting t-to..."
       ]},
    9 =>
      {[
         "Bwahahaha!",
         "Only one question",
         "left! You have to get",
         "this one right or I'll",
         "call you stupid forever!"
       ],
       [
         "We're tied?!",
         "Oh no... I better",
         "get this last question",
         "right. (And I hope that",
         "you get it wrong!)"
       ], ["I'm losing?!", "And we're at the", "last question already?!"]}
  }

  @impl true
  def on_event("OnSmile", ctx), do: emotion(ctx, :smile)

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Aaron]")

    case get_char_var(ctx, :sign_q, 0) do
      21 -> explain_rules(ctx)
      22 -> run_quiz(ctx)
      _ -> flirt(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp explain_rules(ctx) do
    ctx
    |> say(["Alright, before", "we begin, let me", "tell you the rules..."])
    |> next()
    |> emotion(:profusely_sweat)
    |> say([
      "[Aaron]",
      "I'm going to give you",
      "ten multiple choice questions.",
      "Since this is an impromptu",
      "exhibition bout, I'm going to",
      "use questions that I use",
      "in teaching my class."
    ])
    |> next()
    |> set_char_var(:sign_q, 22)
    |> say([
      "[Aaron]",
      "Alright...",
      "I'm almost finished",
      "compiling the questions.",
      "We're ready to go when",
      "you're ready to begin!"
    ])
    |> close()
  end

  defp run_quiz(ctx) do
    {ctx, user_points, npc_points} = Enum.reduce(@rounds, {ctx, 0, 0}, &play_round/2)

    ctx
    |> say([
      "[Aaron]",
      "Okay, the quiz",
      "is over! Now, I'll",
      "reveal the results",
      "of the competitors..."
    ])
    |> next()
    |> say(["[Aaron]", "Umm...", "#{char_name(ctx, 0)}:", "#{user_points} points!"])
    |> next()
    |> say(["[Aaron]", "Jesqurienne...", "#{npc_points} points!"])
    |> next()
    |> announce_winner(user_points, npc_points)
    |> next()
    |> say([
      "[Aaron]",
      "Thank you",
      "for playing!",
      ".......................",
      "...........................",
      "Alright, back to drinking!"
    ])
    |> close()
  end

  defp play_round(round, {ctx, user_points, npc_points}) do
    {ctx, user_points} = ask_question(ctx, round, user_points)
    ctx = if round == 5, do: set_char_var(ctx, :zis_5, Enum.random(1..10)), else: ctx
    {ctx, npc_points} = jesqurienne_answers(ctx, round, npc_points)
    ctx = ctx |> next() |> after_round(round, user_points, npc_points)
    {ctx, user_points, npc_points}
  end

  defp ask_question(ctx, round, user_points) do
    pool = Map.fetch!(@questions, round)
    {lines, options, answer} = Enum.at(pool, Enum.random(1..length(pool)) - 1)
    {ctx, choice} = ctx |> say(lines) |> next() |> select(options)

    if correct?(choice, answer),
      do: {ctx, user_points + 1},
      else: {ctx, user_points}
  end

  defp correct?(choice, {:not, wrong}), do: choice != wrong
  defp correct?(choice, answer), do: choice == answer

  defp jesqurienne_answers(ctx, round, npc_points) do
    {odds, right_lines, wrong_lines} = Map.fetch!(@jesqurienne_answers, round)

    if Enum.random(1..10) < odds do
      ctx = ctx |> donpcevent("Jesqurienne#sign::OnHo") |> say(["[Jesqurienne]" | right_lines])
      {ctx, npc_points + 1}
    else
      ctx = ctx |> donpcevent("Jesqurienne#sign::OnOmg") |> say(["[Jesqurienne]" | wrong_lines])
      {ctx, npc_points}
    end
  end

  defp after_round(ctx, 3, user_points, npc_points) do
    ctx
    |> say(["[Jesqurienne]", "Let's check our", "scores, shall we?", "................."])
    |> next()
    |> standings(3, user_points, npc_points)
    |> next()
    |> say(["[Aaron]", "^333333*Ahem!*^000000", "Question", "number four!"])
    |> next()
  end

  defp after_round(ctx, round, user_points, npc_points) when round in 4..9 do
    ctx
    |> standings(round, user_points, npc_points)
    |> next()
  end

  defp after_round(ctx, _round, _user_points, _npc_points), do: ctx

  defp standings(ctx, round, user_points, npc_points) do
    {ahead, tied, behind} = Map.fetch!(@standings, round)

    lines =
      cond do
        npc_points > user_points -> ahead
        npc_points == user_points -> tied
        true -> behind
      end

    say(ctx, ["[Jesqurienne]" | lines])
  end

  defp announce_winner(ctx, user_points, npc_points) when npc_points > user_points do
    ctx
    |> set_char_var(:sign_q, 23)
    |> emotion(:kik)
    |> say(["[Jesqurienne]", "Bwahahaha!", "I win! I knew it!", "Ho ho ho ho ho ho~"])
  end

  defp announce_winner(ctx, points, points) do
    ctx
    |> set_char_var(:sign_q, 24)
    |> say([
      "[Jesqurienne]",
      "Tied?! ",
      "Alright, I'm impressed.",
      "I'll admit, you're much",
      "smarter than I thought..."
    ])
  end

  defp announce_winner(ctx, _user_points, _npc_points) do
    ctx
    |> set_char_var(:sign_q, 24)
    |> say(["[Jesqurienne]", "No...!", "I can't...", "Believe this..."])
  end

  defp flirt(ctx) do
    ctx
    |> emotion(:huk)
    |> say([
      "Goodness...!",
      "Either these beer",
      "goggles are on too tight,",
      "or you're the most gorgeous",
      "woman I've seen in my life!"
    ])
    |> next()
    |> react_to_compliment(sex(ctx))
    |> close()
  end

  defp react_to_compliment(ctx, 1) do
    {ctx, _} = select(ctx, ["Um, I'm a dude..."])

    ctx
    |> emotion(:cry)
    |> say([
      "[Aaron]",
      "N-no...!",
      "M-maybe I should",
      "take it easy on the",
      "alcohol. I do have classes",
      "to teach tomorrow anyway..."
    ])
  end

  defp react_to_compliment(ctx, _sex) do
    {ctx, _} = select(ctx, ["Why, thank you~"])

    ctx
    |> emotion(:best)
    |> say([
      "[Aaron]",
      "Ah, yes. Your",
      "sense of style, your",
      "magnificent body. Everything",
      "about you is beautiful! Not just that, but you're also intelligent!"
    ])
    |> next()
    |> emotion(:bigthrob)
    |> say([
      "[Aaron]",
      "I should know!",
      "Not only do I teach",
      "classes, but I'm also",
      "a Quiz Challenge moderater",
      "master in my spare time~",
      "You're truly a jewel..."
    ])
  end

  defp say(ctx, lines), do: Enum.reduce(lines, ctx, &mes(&2, &1))
end
