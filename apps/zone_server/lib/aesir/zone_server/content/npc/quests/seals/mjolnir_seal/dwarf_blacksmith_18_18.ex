defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MjolnirSeal.DwarfBlacksmith1818 do
  @moduledoc """
  Nordri, the dwarf blacksmith of northern Mount Mjolnir, tells a moral tale to players on the
  Mjolnir Seal quest.

  ## Behavior

  - Before the Mjolnir seal phase opens he complains that his Eluniums and Oridecons are gone;
    once the seal is broken he only wonders about the change in the winds.
  - On the first round he is the last of the four dwarves: once the others have told their
    stories, he asks for a Red Potion and in return tells of Thor in Utgard, quizzing the player
    on the three illusions.
  - On the second round he is the first dwarf and tells the story of Alvis instead, quizzing the
    player on Thor's three questions.
  - A wrong answer or a cancelled menu ends the story; another Red Potion is needed to retry.
  - Answering "Excuse me." when he is not the dwarf to visit marks the player as polite, after
    which every dwarf only enjoys the forest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - Samuray22
    - L0ne_W0lf
    - Zephyrus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjolnir_12",
        x: 18,
        y: 18,
        dir: 7,
        sprite: 826,
        name: "Dwarf Blacksmith",
        scope: :shared,
        unique_name: "Dwarf Blacksmith#north"
      }
    ]

  @red_potion 501

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God3", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        ctx
        |> no_eluniums()
        |> mes("Vestri took them all. ^333333*Sigh*^000000 Those were my treasures, you know...")
        |> close()

      get_server_var(ctx, "God4", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        ctx
        |> mes("[Nordri]")
        |> mes("What's happening?")
        |> mes("I sense change in the winds, but what that change may be, I cannot tell.")
        |> next()
        |> mes("[Nordri]")
        |> mes("Should I go into the cave to figure it out? Huh. This is most peculiar.")
        |> close()

      true ->
        talk(ctx, get_char_var(ctx, :god_mjo_0, 0))
    end
  end

  defp talk(ctx, 11) do
    ctx
    |> mes("[Nordri]")
    |> mes("Bwahahah!")
    |> mes(
      "Even the gods know that we Dwarves are the most talented of artisans! Maybe it doesn't seem that way now, but someday we shall return."
    )
    |> close()
  end

  defp talk(ctx, 10) do
    ctx
    |> no_eluniums()
    |> mes("Vestri took them all.")
    |> mes("Don't you understand?")
    |> close()
  end

  defp talk(ctx, 1), do: first_round(ctx)
  defp talk(ctx, 2), do: second_round(ctx)

  defp talk(ctx, 0) do
    ctx
    |> mes("[Nordri]")
    |> mes("I am Nordri,")
    |> mes("Dwarven Blacksmith.")
    |> next()
    |> mes("[Nordri]")
    |> mes(
      "I am in charge of this Northern part of Mount Mjolnir. If you wish to pass, you must first secure my approval!"
    )
    |> next()
    |> mes("[Nordri]")
    |> mes("Ho ho ho...")
    |> mes("Calm down, it")
    |> mes("was only a joke.")
    |> mes("Hahahahaha!")
    |> close()
  end

  defp talk(ctx, _stage), do: ctx |> mes("[Nordri]") |> mes("Zzzz Zzzz Zzzz...") |> close()

  defp first_round(ctx) do
    cond do
      polite?(ctx) ->
        enjoying_forest(ctx)

      get_char_var(ctx, :god_mjo_4, 0) == 2 ->
        on_your_way(ctx)

      Enum.any?([:god_mjo_1, :god_mjo_2, :god_mjo_3], &(get_char_var(ctx, &1, 0) in [0, 1])) ->
        polite_menu(ctx, :god_mjo_4)

      get_char_var(ctx, :god_mjo_4, 0) == 1 ->
        with_red_potion(ctx, &offer_utgard_story/1)

      get_char_var(ctx, :god_mjo_4, 0) == 0 ->
        first_meeting(ctx, :god_mjo_4, &leave_me_alone/1)

      true ->
        ctx |> mes("[Nordri]") |> mes("Zzzz Zzzz...") |> close2()
    end
  end

  defp second_round(ctx) do
    cond do
      polite?(ctx) ->
        enjoying_forest(ctx)

      get_char_var(ctx, :god_mjo_1, 0) == 2 ->
        on_your_way(ctx)

      Enum.any?([:god_mjo_2, :god_mjo_3, :god_mjo_4], &(get_char_var(ctx, &1, 0) != 0)) ->
        polite_menu(ctx, :god_mjo_1)

      get_char_var(ctx, :god_mjo_1, 0) == 1 ->
        with_red_potion(ctx, &offer_alvis_story/1)

      get_char_var(ctx, :god_mjo_1, 0) == 0 ->
        first_meeting(ctx, :god_mjo_1, &you_are_funny/1)

      true ->
        ctx |> mes("[Nordri]") |> mes("Zzzz Zzzz Zzzz...") |> close()
    end
  end

  defp polite?(ctx) do
    Enum.any?([:god_mjo_1, :god_mjo_2, :god_mjo_3, :god_mjo_4], &(get_char_var(ctx, &1, 0) == 3))
  end

  defp no_eluniums(ctx) do
    ctx
    |> mes("[Nordri]")
    |> mes("What...?")
    |> mes("I don't have any")
    |> mes("Eluniums or Oridecons!")
    |> next()
    |> mes("[Nordri]")
  end

  defp enjoying_forest(ctx) do
    ctx
    |> mes("[Nordri]")
    |> mes("Eh heh heh~")
    |> mes(
      "It's nice being in the Mjolnir Forest. To be surrounded by the quiet, peaceful air and not having to worry about anything..."
    )
    |> close()
  end

  defp on_your_way(ctx) do
    ctx
    |> mes("[Nordri]")
    |> mes("Shouldn't you be on your way by now? Eh, it's none of my business.")
    |> next()
    |> mes("[Nordri]")
    |> mes(
      "If you have the Zeny to spare, why don't you buy some snacks for your travels? Perhaps some delicious Bananas, or even some Pumpkins..."
    )
    |> close()
  end

  defp what_business(ctx) do
    ctx
    |> mes("[Nordri]")
    |> mes("What business")
    |> mes("do you have with")
    |> mes("me, human?")
    |> next()
    |> select(["Nothing.", "Excuse me."])
  end

  defp polite_menu(ctx, quest_var) do
    case what_business(ctx) do
      {ctx, 1} ->
        leave_me_alone(ctx)

      {ctx, 2} ->
        ctx
        |> set_char_var(quest_var, 3)
        |> mes("[Nordri]")
        |> mes("Huh.")
        |> mes("That's fine. Still...")
        |> mes("I'm surprised to see")
        |> mes("such a polite human.")
        |> close()

      {ctx, _} ->
        ctx
    end
  end

  defp first_meeting(ctx, quest_var, dismiss) do
    case what_business(ctx) do
      {ctx, 1} ->
        dismiss.(ctx)

      {ctx, 2} ->
        ctx
        |> mes("[Nordri]")
        |> mes(
          "Odd. Recently, too many humans have been interested in meeting with me and my brothers. Still, I cannot say their visits have been unpleasant."
        )
        |> next()
        |> set_char_var(quest_var, 1)
        |> mes("[Nordri]")
        |> mes(
          "I'm a little thirsty. Would you bring me a Red Potion. If you do that for me, I will tell you an important story. Heh heh heh~"
        )
        |> close()

      {ctx, _} ->
        ctx
    end
  end

  defp leave_me_alone(ctx) do
    ctx
    |> mes("[Nordri]")
    |> mes("Huh.")
    |> mes("If that's the case,")
    |> mes("then leave me alone.")
    |> close()
  end

  defp you_are_funny(ctx) do
    ctx |> mes("[Nordri]") |> mes("You're funny, leave me alone.") |> close()
  end

  defp with_red_potion(ctx, offer_story) do
    if count_item(ctx, @red_potion) > 0 do
      ctx |> delitem(@red_potion, 1) |> offer_story.()
    else
      ctx
      |> mes("[Nordri]")
      |> mes("Oooh...")
      |> mes("I'm sooo thirsty!")
      |> next()
      |> mes("[Nordri]")
      |> mes(
        "Hm, didn't I ask you to bring a Red Potion? There's no way I can tell any stories with such a dry throat~"
      )
      |> close()
    end
  end

  defp offer_utgard_story(ctx) do
    ctx
    |> mes("[Nordri]")
    |> mes("Ah, you've brought")
    |> mes("me a Red Potion, just")
    |> mes("like I asked. In return,")
    |> mes("I will tell you an old story.")
    |> mes("I'm sure you'll like it.")
    |> next()
    |> utgard_story()
  end

  defp offer_alvis_story(ctx) do
    ctx
    |> mes("[Nordri]")
    |> mes("Ah, you've brought")
    |> mes("me a Red Potion...?")
    |> mes("In return, I will")
    |> mes("tell you an old story.")
    |> mes("I'm sure you'll like it.")
    |> next()
    |> alvis_story()
  end

  defp utgard_story(ctx) do
    case get_local(ctx, :talk_to, 0) do
      0 ->
        ctx
        |> mes("[Nordri]")
        |> mes("This is a legend about one")
        |> mes("of Thor's journeys into Utgard,")
        |> mes("land of the giants.")
        |> next()
        |> mes("[Nordri]")
        |> mes("There, he made a wager with their king in which he would challenge")
        |> mes("the giants of their land in tests of skill and strength.")
        |> next()
        |> mes("[Nordri]")
        |> mes(
          "The first was an eating contest. Thor ate all of the meat on his table, but his opponent, Utgardaloki, ate his meat, the bones and even the plates."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes("In truth, Thor was tricked, and the opponent that defeated him was not")
        |> mes(
          "actually a giant. Illusion was used to disguise Thor's opponent, but I forget was it was. Do you know?"
        )
        |> next()
        |> select(["Greed", "Sea", "Blaze", "Hog"])
        |> check_answer(3)
        |> continue_story(&utgard_story/1)

      1 ->
        ctx
        |> mes("[Nordri]")
        |> mes(
          "Yes, only a Blaze could have effortlessly consumed meat, bones and plates by burning. Of course!"
        )
        |> mes("I remember now!")
        |> next()
        |> mes("[Nordri]")
        |> mes(
          "The next contest was a race. In that match, Thor's servant, Tialfi competed with the king's servant, Hugi. However, no matter how many matches they had, Hugi would win every time."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes("Once again, illusion magic was")
        |> mes(
          "used to disguise the competitor. Do you know what Tialfi was really racing against?"
        )
        |> next()
        |> select(["Language", "Thoughts", "Turtle", "Wolf"])
        |> check_answer(2)
        |> continue_story(&utgard_story/1)

      2 ->
        ctx
        |> mes("[Nordri]")
        |> mes(
          "Yes, right! Tialfi was racing 'thoughts!' Nothing can move faster than the speed of thought, so it's no wonder Tialfi would always lose."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes(
          "For the final contest, Thor would challenge an old woman in a wrestling match. At first, Thor thought his victory was assured, but he learned that he could not defeat the old crone."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes("Once again, Thor was the victim")
        |> mes(
          "of illusion magic. He didn't realize he wasn't actually wrestling with an old woman. Do you know what his opponent really was?"
        )
        |> next()
        |> select(["Curse", "Earth", "Heart", "Old Age"])
        |> check_answer(4)
        |> continue_story(&utgard_story/1)

      3 ->
        ctx
        |> mes("[Nordri]")
        |> mes(
          "Yes, Thor was wrestling with 'Old Age!' No matter how strong anybody is, you can't fight against aging."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes("After Thor lost every match,")
        |> mes(
          "the king told him the truth about the contests. Thor grew furious, but it was too late. The king and the giants all vanished by then."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes("There are two lessons")
        |> mes(
          "to be learned from this tale. First, don't believe everything you see. Second, never be overconfident of your own power."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes(
          "There will always be someone or something more powerful than you. It is important to always do your best and have an attitude of humility."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes(
          "Try to live as good a life as you can. Remember that you can't have everything that you want. Obssession and irrationality go hand in hand."
        )
        |> next()
        |> set_char_var(:god_mjo_4, 2)
        |> mes("[Nordri]")
        |> mes(
          "Thank you for listening to my long story. If you meet someone with a dangerous obsession, please tell this story of Thor and the illusions of the giant king."
        )
        |> close()

      _ ->
        continue_story(ctx, &utgard_story/1)
    end
  end

  defp alvis_story(ctx) do
    case get_local(ctx, :talk_to, 0) do
      0 ->
        ctx
        |> mes("[Nordri]")
        |> mes(
          "There is a story of a Dwarf named Alvis who contained more knowledge than a library and was braver than Siegfried the warrior."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes("Unfortunately...")
        |> mes("He was too ambitious.")
        |> mes("He fell in love with Thrud, Thor's first daughter, at first sight.")
        |> next()
        |> mes("[Nordri]")
        |> mes(
          "He asked Thor for permission to marry Thrud, but as was expected, Thor refused. Alvis should have given up there, but he didn't."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes(
          "So Thor decided to test his knowledge by asking him some questions. The first question was, 'What is the name of the ground in human terms?' Do you know the answer?"
        )
        |> next()
        |> select(["Ymir's body", "Earth", "Lane", "Universe"])
        |> check_answer(2)
        |> continue_story(&alvis_story/1)

      1 ->
        ctx
        |> mes("[Nordri]")
        |> mes(
          "Yes, that's right, 'Earth.' Alvis was able to also answer Thor's question correctly."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes(
          "Thor then gave Alvis another question. What is the giant's term for the round shell that covers the earth?"
        )
        |> next()
        |> select(["Ymir's Head", "Sky", "Cloud Factory", "High House"])
        |> check_answer(4)
        |> continue_story(&alvis_story/1)

      2 ->
        ctx
        |> mes("[Nordri]")
        |> mes(
          "That's it, 'High House.' Since the giants are so huge, it might have looked that way to them."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes(
          "So Thor gave him another question. What is the term for the ball that rises in the sky at night, as used by the gods?"
        )
        |> next()
        |> select(["Circling Wheel", "Moon", "False Sun", "Fast Stranger"])
        |> check_answer(3)
        |> continue_story(&alvis_story/1)

      3 ->
        ctx
        |> mes("[Nordri]")
        |> mes("Yes! Gods refer to the")
        |> mes("moon as the 'false sun.'")
        |> mes(
          "Although Alvis answered all of Thor's questions, he didn't notice the sun was rising."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes("Yes...")
        |> mes("Thor prolonged his test so that Alvis would be turned to stone")
        |> mes("once the sun rose.")
        |> next()
        |> mes("[Nordri]")
        |> mes("There are two")
        |> mes("things we can learn")
        |> mes(
          "from this story. First, do not covet something to the point of challenging fate or the gods."
        )
        |> next()
        |> mes("[Nordri]")
        |> mes(
          "Secondly, do not have too much pride in yourself. No matter how much ability or talent you may have, you cannot get everything"
        )
        |> mes("you want.")
        |> next()
        |> mes("[Nordri]")
        |> mes("It's most")
        |> mes("important to live a")
        |> mes(
          "good and virtuous life. It's great to achieve your desires, but be aware that some desires are not meant to be fulfilled."
        )
        |> next()
        |> set_char_var(:god_mjo_1, 2)
        |> mes("[Nordri]")
        |> mes(
          "Thank you for listening to my long story. If you meet anyone afflicted with an insatiable desire, please tell him this story of Thor and Alvis, a brave yet very defiant Dwarf."
        )
        |> close()

      _ ->
        continue_story(ctx, &alvis_story/1)
    end
  end

  defp check_answer({ctx, correct}, correct), do: ctx
  defp check_answer({ctx, _wrong}, _correct), do: set_local(ctx, :talk_not, 1)

  defp continue_story(ctx, story) do
    if get_local(ctx, :talk_not, 0) == 1 do
      ctx
      |> mes("[Nordri]")
      |> mes("Huh...?")
      |> mes(
        "I don't think that's right. Let me think, maybe I can remember it. Hopefully, it'll come to me sooner or later..."
      )
      |> next()
      |> mes("[Nordri]")
      |> mes(
        "Shall we talk more of this once again after enjoying another Red Potion? Hahahahaha~"
      )
      |> close()
    else
      ctx
      |> set_local(:talk_to, get_local(ctx, :talk_to, 0) + 1)
      |> story.()
    end
  end
end
