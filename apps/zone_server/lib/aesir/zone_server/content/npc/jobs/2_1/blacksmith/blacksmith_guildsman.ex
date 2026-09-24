defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Blacksmith.BlacksmithGuildsman do
  @moduledoc """
  Mitehmaeeuh, the guildsman who gives the final smithing quiz of the Blacksmith job quest.

  ## Behavior

  - Asks applicants one of three random five-question quizzes.
  - Awards the Hammer of Blacksmith to applicants scoring above 70 points and sends them
    back to Altiregen.
  - Chats about the guild with everyone else.

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
        x: 24,
        y: 41,
        dir: 5,
        sprite: 726,
        name: "Blacksmith Guildsman",
        scope: :shared,
        unique_name: "Blacksmith Guildsman#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :BSMITH_Q, 0) do
      16 -> offer_quiz(ctx)
      17 -> remind_passed(ctx)
      _ -> chat(ctx)
    end
  end

  defp offer_quiz(ctx) do
    {ctx, choice} =
      ctx
      |> emotion(:scratch)
      |> mes("[Mitehmaeeuh]")
      |> mes("Oh...so you're the one who wants to be a blacksmith?")
      |> mes("Nice, heh heh.")
      |> mes(
        "As you've realized from your past tests, you won't be promoted from Merchant to Blacksmtih immediately."
      )
      |> next()
      |> mes("[Mitehmaeeuh]")
      |> mes(
        "How much do you truly understand about smithing? Are you ready for me to ask you some questions?"
      )
      |> next()
      |> select(["Yes", "No, not yet~"])

    if choice == 1 do
      take_quiz(ctx)
    else
      ctx
      |> mes("[Mitehmaeeuh]")
      |> mes("Okay then.")
      |> mes("Please prepare")
      |> mes("yourself and return")
      |> mes("when you are ready...")
      |> close()
    end
  end

  defp take_quiz(ctx) do
    ctx =
      ctx
      |> mes("[Mitehmaeeuh]")
      |> mes("Alright...")
      |> mes("My test is simple.")
      |> mes("I'll ask five questions.")
      |> mes("If you miss too many,")
      |> mes("you fail. And I won't")
      |> mes("tell you what you missed.")
      |> next()
      |> mes("[Mitehmaeeuh]")
      |> mes("Please listen")
      |> mes("and answer carefully...")
      |> next()

    {ctx, score} = quiz(ctx, Enum.random(1..3))

    ctx =
      ctx
      |> mes("[Mitehmaeeuh]")
      |> mes("Ah...")
      |> mes("You've completed")
      |> mes("the quiz. Let's see...")
      |> next()
      |> mes("[Mitehmaeeuh]")
      |> mes("You earned")
      |> mes("#{score} points...")

    if score > 70 do
      ctx
      |> mes("Very nice!")
      |> mes("Congratulations!")
      |> mes("You just passed!")
      |> next()
      |> mes("[Mitehmaeeuh]")
      |> mes(
        "However, don't let your early success make you overconfident. A Blacksmith's life isn't a picnic. As proof that you have passed the test, I give you this Hammer of Blacksmith."
      )
      |> set_char_var(:BSMITH_Q, 17)
      |> give_item(1005, 1)
      |> changequest(2014, 2015)
      |> next()
      |> mes("[Mitehmaeeuh]")
      |> mes("Take this Hammer")
      |> mes(
        "of Blacksmith and go back to the Altiregen. Okay then? I wish you the best of luck!"
      )
      |> close()
    else
      ctx
      |> mes("You failed! You better study up before coming back here.")
      |> next()
      |> mes("[Mitehmaeeuh]")
      |> mes(
        "With your knowledge, or lack thereof, you'll just end up hurting yourself holding a hammer!"
      )
      |> close()
    end
  end

  defp quiz(ctx, 1) do
    {ctx, answer1} =
      ask(
        ctx,
        ["1. What ability", "is required to learn", "the ^8E6B23Discount^000000 skill?"],
        ["Level 3 Push Cart", "Item Appraisal", "Level 10 Mammonite", "Level 3 Enlarge Weight"]
      )

    {ctx, answer2} =
      ask(
        ctx,
        [
          "2. When you attack",
          "with ^8E6B23Hammerfall^000000,",
          "what status effect can",
          "you inflict on enemies?"
        ],
        ["Stun", "Blindness", "Chaos", "Silence"]
      )

    {ctx, answer3} =
      ask(
        ctx,
        [
          "3. How much Zeny is spent",
          "when attacking with the",
          "mastered Mammonite skill?",
          "(Level 10 Mammonite)"
        ],
        ["900 Zeny", "1000 Zeny", "2000 Zeny", "100,000 Zeny"]
      )

    {ctx, answer4} =
      ask(
        ctx,
        [
          "4. What is the",
          "discount rate when",
          "the ^8E6B23Discount^000000",
          "skill is mastered?"
        ],
        ["21 % ", "22 % ", "23 % ", "24 % "]
      )

    {ctx, answer5} =
      ask(
        ctx,
        [
          "5. What is the maximum",
          "percentage that you can",
          "overcharge items sold to",
          "NPCs after mastering the",
          "^8E6B23Overcharge^000000 skill?"
        ],
        ["21 % ", "22 % ", "23 % ", "24 % "]
      )

    score =
      points(answer1, [4]) + points(answer2, [1]) + points(answer3, [2]) +
        points(answer4, [4]) + points(answer5, [3])

    {ctx, score}
  end

  defp quiz(ctx, 2) do
    {ctx, answer1} =
      ask(
        ctx,
        ["1. Which of the", "following monsters", "drops Steel?"],
        ["Zerom", "Chon Chon", "Skel Worker", "Requiem"]
      )

    {ctx, answer2} =
      ask(
        ctx,
        ["2. Which of the following", "stones can be made from", "Red Bloods?"],
        ["Flame Heart", "Rough Wind", "Great Nature", "Mystic Frozen"]
      )

    {ctx, _answer3} =
      ask(
        ctx,
        ["3. Which of the following", "stones do you have the most", "of in your Kafra Storage?"],
        ["Wind of Verdure", "Red Blood", "Green Live", "Crystal Blue"]
      )

    {ctx, answer4} =
      ask(
        ctx,
        [
          "4. In general,",
          "which of the following",
          "properties receives the",
          "most damage from a Wind",
          "attribute weapon?"
        ],
        ["Fire Property", "Water Property", "Earth Property", "Wind Property"]
      )

    {ctx, answer5} =
      ask(
        ctx,
        ["5. How many Iron Ore", "is required to make", "1 Steel?"],
        ["5 Iron Ore ", "4 Iron Ore", "3 Iron Ore", "6 Iron Ore"]
      )

    score =
      points(answer1, [3]) + points(answer2, [1]) + 20 + points(answer4, [2]) +
        points(answer5, [1])

    {ctx, score}
  end

  defp quiz(ctx, 3) do
    {ctx, answer1} =
      ask(
        ctx,
        ["1. What do you usually", "do when you meet someone", "randomly on the street?"],
        [
          "Ask them what they need.",
          "Have a brief conversation.",
          "Ignore them.",
          "Give items and run away."
        ]
      )

    {ctx, answer2} =
      ask(
        ctx,
        [
          "2. In what village",
          "can you learn the",
          "^8E6B23Crazy Uproar^000000 and",
          "^8E6B23Change Cart^000000 skills?"
        ],
        ["Al De Baran", "Alberta", "Morocc", "Izlude"]
      )

    {ctx, answer3} =
      ask(
        ctx,
        ["3. From the center of Einbroch,", "in which direction is the Blacksmith Guild?"],
        ["11 o'clock", "5 o'clock", "7 o'clock", "12 o'clock"]
      )

    {ctx, answer4} =
      ask(
        ctx,
        ["4. In which town", "can you find the", "most Blacksmiths?"],
        ["Prontera", "Morocc", "Alberta", "Einbroch"]
      )

    {ctx, answer5} =
      ask(
        ctx,
        ["5. Which of the", "following statuses", "affect your skill", "as a Blacksmith?"],
        ["STR ", "DEX", "AGI ", "VIT "]
      )

    score =
      points(answer1, [1, 2]) + points(answer2, [2]) + points(answer3, [2]) +
        points(answer4, [4]) + points(answer5, [2])

    {ctx, score}
  end

  defp ask(ctx, lines, options) do
    lines
    |> Enum.reduce(mes(ctx, "[Mitehmaeeuh]"), &mes(&2, &1))
    |> next()
    |> select(options)
  end

  defp points(answer, correct_answers), do: if(answer in correct_answers, do: 20, else: 0)

  defp remind_passed(ctx) do
    ctx
    |> emotion(:scratch)
    |> mes("[Mitehmaeeuh]")
    |> mes("Yeap, you just passed the Blacksmith job test~")
    |> next()
    |> mes("[Mitehmaeeuh]")
    |> mes("Why don't you go back to Mr.Altiregen?")
    |> next()
    |> mes("[Mitehmaeeuh]")
    |> mes("Don't forget to bring the Hammer of Blacksmith with you!")
    |> next()
    |> mes("[Mitehmaeeuh]")
    |> mes("Oh, also make sure that you have no skill point left before you change your job~")
    |> close()
  end

  defp chat(ctx) do
    ctx
    |> emotion(:scratch)
    |> mes("[Mitehmaeeuh]")
    |> mes("I had to deal with the heat when I was in Morocc,")
    |> mes("and now I have to deal with the smog in this Einbroch!")
    |> next()
    |> mes("[Mitehmaeeuh]")
    |> mes(
      "But, I must admit that this is the perfect place for Blacksmiths because we have an abundance of crafting material supplies as well as highly developed equipment."
    )
    |> next()
    |> mes("[Mitehmaeeuh]")
    |> mes("We, Blacksmiths are trying our best to forge the best of the best weapons.")
    |> next()
    |> mes("[Mitehmaeeuh]")
    |> mes("We pledge our honor on that!")
    |> close()
  end
end
