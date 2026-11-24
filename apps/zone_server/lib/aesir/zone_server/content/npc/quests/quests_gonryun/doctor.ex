defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Doctor do
  @moduledoc """
  Cylrnel, the doctor in Juno, diagnoses Lyroo's illness and brews her medicine in the Broken
  Sword quest.

  ## Behavior

  - Before the quest reaches her, asks the player to come back later; once Lyroo has her
    medicine, explains the disease, Amarhade.
  - On first contact, random small talk may lead her to hear about Lyroo and ask for the exact
    symptoms; otherwise she sends the player away, in one case warping them out to Juno.
  - Asks about four symptoms. With all four right she prescribes 2 Yggdrasil Seeds, 3 Aloes,
    1 Witherless Rose, 10 Witch Starsands, 5 Burning Hearts and 5 Ice Cubics; otherwise a
    weaker recipe of 1 Yggdrasil Seed, 1 Aloe, 5 Witch Starsands, 3 Burning Hearts and 3 Ice
    Cubics.
  - The weaker recipe is consumed and fails, sending the player back to the symptoms; the full
    recipe is consumed for an Aloevera to bring to Lyroo. Missing ingredients repeat the recipe
    and warp the player out to Juno.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - The weaker recipe's gate checked `countitem(1061) > 2` and never checked Burning Hearts,
    although it deletes 5 Witch Starsands and 3 Burning Hearts, so a short player lost the
    Yggdrasil Seed and Aloe and the script ended at the failed `delitem`. It now requires
    `countitem(1061) > 4 && countitem(7097) > 2`, matching what it deletes.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in01",
        x: 99,
        y: 101,
        dir: 4,
        sprite: 744,
        name: "Doctor",
        scope: :shared,
        unique_name: "Doctor#gnbs"
      }
    ]

  @yggdrasil_seed 608
  @aloe 704
  @witherless_rose 748
  @witch_starsand 1061
  @burning_heart 7097
  @ice_cubic 7066
  @aloevera 606

  @temperatures [
    {"Very hot.", "Very hot."},
    {"Very cold.", "Very cold."},
    {"Normal.", "Normal."},
    {"Turns hot and cold repeatedly.", "Turns hot and cold repeatedly"}
  ]
  @perspiration for answer <- [
                      "No sweating at all.",
                      "Sweating all over the body.",
                      "Runny nose.",
                      "No tears, sweats at all."
                    ],
                    do: {answer, answer}
  @physical_conditions for answer <- [
                             "Nothing in particular.",
                             "Becomes paralyzed often.",
                             "Muscles became soft.",
                             "Muscles became hard."
                           ],
                           do: {answer, answer}
  @internal_organs for answer <- [
                         "Stomach hurts like it's been stabbed by a knife.",
                         "Head hurts like it's been smashed by a hammer.",
                         "Heart beats irregularly.",
                         "Has difficulty in breathing."
                       ],
                       do: {answer, answer}

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :b_sword, 0) do
      step when step < 23 -> not_met_yet(ctx)
      23 -> first_meeting(ctx)
      24 -> diagnosis(ctx)
      25 -> weak_medicine(ctx)
      26 -> full_medicine(ctx)
      _ -> after_the_cure(ctx)
    end
  end

  defp not_met_yet(ctx) do
    ctx
    |> mes("[??????]")
    |> mes("I don't believe we've met")
    |> mes("before, but would you mind")
    |> mes("coming back later? I've got a lot of work to do at the moment.")
    |> close()
  end

  defp first_meeting(ctx) do
    ctx =
      ctx
      |> mes("[Cylrnel]")
      |> mes("Hello, can I help you?")
      |> mes("If it's not urgent,")
      |> mes("please come back later.")
      |> next()

    if Enum.random(1..4) == 2 do
      small_talk(ctx)
    else
      ctx
      |> mes("[Cylrnel]")
      |> mes("I'm sorry, but I don't have")
      |> mes("any time for you right now.")
      |> close()
    end
  end

  defp small_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cylrnel]")
      |> mes("Hmm...you look like you")
      |> mes("want to ask me something?")
      |> next()
      |> select(["You're so beautiful.", "Do you like traveling?"])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Cylrnel]")
        |> mes("Err...well, I do, but...")
        |> mes("If you don't have any")
        |> mes("favors to ask, please leave.")
        |> mes("I'm very busy right now.")
        |> close()

      Enum.random(1..4) == 4 ->
        flirting(ctx)

      true ->
        ctx
        |> mes("[Cylrnel]")
        |> mes("Ahahaha..")
        |> mes("You're a funny guy.")
        |> mes("But, that won't")
        |> mes("work on me!")
        |> close()
    end
  end

  defp flirting(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cylrnel]")
      |> mes("...excuse me?")
      |> mes("Ah ha ha~")
      |> mes("You're a funny guy.")
      |> mes("Trying to hit on me?")
      |> mes("Ah ha ha ha.")
      |> next()
      |> select(["Yes, I fell in love at first sight.", "I have a favor to ask."])

    if choice == 1, do: love_at_first_sight(ctx), else: asks_a_favor(ctx)
  end

  defp love_at_first_sight(ctx) do
    if Enum.random(1..3) == 3 do
      {ctx, _} =
        ctx
        |> mes("[Cylrnel]")
        |> mes("HAHAHAHHAHAHAHAH!")
        |> mes("Ah...I'm sorry..")
        |> mes("I haven't seen a guy like you")
        |> mes("for a long time.")
        |> emotion(:smile)
        |> next()
        |> mes("[Cylrnel]")
        |> mes("You make me laugh...")
        |> mes("But guess what?")
        |> mes("I already know you're not")
        |> mes("here to hit on me.")
        |> mes("So what did you really want?")
        |> next()
        |> select(["Well, actually..."])

      ctx
      |> mes("^FF0000You Tell Cylrnel about Lyroo,")
      |> mes("and about the favor for Aumgarl the blacksmith.^000000")
      |> next()
      |> hears_the_story()
    else
      ctx
      |> mes("[Cylrnel]")
      |> mes("Oh brother!")
      |> mes("I never thought someone")
      |> mes("like you could still exist.")
      |> mes("I'm sorry, but you're")
      |> mes("really not my type.")
      |> close()
    end
  end

  defp asks_a_favor(ctx) do
    if Enum.random(1..3) == 3 do
      {ctx, _} =
        ctx
        |> mes("[Cylrnel]")
        |> mes("Is that so?")
        |> mes("well then,")
        |> mes("Let me hear your story.")
        |> next()
        |> select(["Well, it's like this..."])

      ctx
      |> mes("^FF0000You Tell Cylrnel about Lyroo,")
      |> mes("and about the favor of Aumgarl the blacksmith.^000000")
      |> next()
      |> hears_the_story()
    else
      ctx
      |> mes("[Cylrnel]")
      |> mes("Well...")
      |> mes("While I'd like to help,")
      |> mes("You're a stranger, and the")
      |> mes("residents need my help.")
      |> mes("I don't have any extra time")
      |> mes("to help you. Please leave.")
      |> close()
      |> warp("yuno", 246, 143)
    end
  end

  defp hears_the_story(ctx) do
    if Enum.random(1..3) == 2 do
      ctx
      |> mes("[Cylrnel]")
      |> mes("Hmm.....")
      |> mes("So that's what happened...")
      |> mes("Well, I need to know the")
      |> mes("exact symptoms...go and")
      |> mes("find out for me and then")
      |> mes("come back afterwards.")
      |> next()
      |> mes("[Cylrnel]")
      |> mes("Without the exact symptoms, I can't make an accurate diagnosis.")
      |> set_char_var(:b_sword, 24)
      |> close()
    else
      ctx
      |> mes("[Cylrnel]")
      |> mes("Well now...")
      |> mes("That's quite a long story.")
      |> next()
      |> mes("[Cylrnel]")
      |> mes("I have no idea why you're")
      |> mes("trying to help these people,")
      |> mes("so it's a bit hard to believe")
      |> mes("you...")
      |> close()
    end
  end

  defp diagnosis(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cylrnel]")
      |> mes("Oh, you're back...")
      |> mes("Did you figure out the symptoms?")
      |> mes("I wanted to go with you, but")
      |> mes("I've been really busy.")
      |> next()
      |> select(["Not yet...", "Yes, Here."])

    if choice == 1 do
      ctx
      |> mes("[Cylrnel]")
      |> mes("What! Why not!?")
      |> mes("Hurry to her house!")
      |> mes("She's in serious pain!")
      |> mes("Her body could be paralyzed")
      |> mes("at any moment!")
      |> close()
    else
      ctx
      |> mes("[Cylrnel]")
      |> mes("What a relief...")
      |> mes("You're earlier than I thought.")
      |> mes("I'll ask you some questions about")
      |> mes("her condition. Answer correctly.")
      |> next()
      |> mes("[Cylrnel]")
      |> mes("First, how was her body temperature?")
      |> set_char_var(:sick, 0)
      |> next()
      |> asks_the_symptoms()
    end
  end

  defp asks_the_symptoms(ctx) do
    with {:ok, ctx, temperature} <- answer(ctx, @temperatures, 4),
         {:ok, ctx, perspiration} <-
           ctx
           |> asks(["Okay...", "Now, about physiological condition."])
           |> answer(@perspiration, 1),
         {:ok, ctx, condition} <-
           ctx
           |> asks(["Next, tell me about", "her physical condition."])
           |> answer(@physical_conditions, 2),
         {:ok, ctx, organs} <-
           ctx
           |> asks(["How about internal organs?"])
           |> answer(@internal_organs, 3) do
      confirms_the_symptoms(ctx, [temperature, perspiration, condition, organs])
    else
      {:cancelled, ctx} -> ctx
    end
  end

  defp asks(ctx, lines) do
    lines
    |> Enum.reduce(mes(ctx, "[Cylrnel]"), &mes(&2, &1))
    |> next()
  end

  defp answer(ctx, answers, correct) do
    {ctx, choice} = select(ctx, Enum.map(answers, &elem(&1, 0)))

    if choice in 1..length(answers)//1 do
      {_option, symptom} = Enum.at(answers, choice - 1)
      {:ok, ctx, {symptom, choice == correct}}
    else
      {:cancelled, ctx}
    end
  end

  defp confirms_the_symptoms(ctx, answers) do
    [temperature, perspiration, condition, organs] = Enum.map(answers, &elem(&1, 0))

    {ctx, choice} =
      ctx
      |> mes("[Cylrnel]")
      |> mes("Hmm.. alright.")
      |> mes("Let me check this.")
      |> mes("so the symptoms are")
      |> mes("..............")
      |> next()
      |> mes("[Cylrnel]")
      |> mes("^FF0000#{temperature}")
      |> mes(perspiration)
      |> mes(condition)
      |> mes("#{organs}^000000")
      |> mes("right?")
      |> next()
      |> select(["No..not exactly..", "Yes, I am sure."])

    if choice == 1 do
      back_to_her(ctx, "Then go back to her and")
    else
      double_checks(ctx, Enum.all?(answers, &elem(&1, 1)))
    end
  end

  defp double_checks(ctx, all_correct?) do
    {ctx, choice} =
      ctx
      |> mes("[Cylrnel]")
      |> mes("You're sure about this, right?")
      |> mes("If they're the wrong symptoms,")
      |> mes("I can't be responsible.")
      |> next()
      |> select(["Err..let me go and double check.", "I'm sure."])

    if choice == 1 do
      back_to_her(ctx, "Then, go back to her and")
    else
      ctx
      |> mes("[Cylrnel]")
      |> mes("Hmm.....")
      |> mes("Aright. I'll trust you.")
      |> mes("Now, go get these ingredients.")
      |> mes("Get them as fast as possible.")
      |> mes("Alright?")
      |> next()
      |> prescribes(all_correct?)
      |> mes("[Cylrnel]")
      |> mes("Get them as fast as possible.")
      |> mes("There isn't much time for Lyroo.")
      |> close()
    end
  end

  defp back_to_her(ctx, opening) do
    ctx
    |> mes("[Cylrnel]")
    |> mes(opening)
    |> mes("find the exact symptoms")
    |> mes("right away~!!")
    |> close()
  end

  defp prescribes(ctx, true), do: prescribes(ctx, 26, &full_recipe/1)
  defp prescribes(ctx, false), do: prescribes(ctx, 25, &weak_recipe/1)

  defp prescribes(ctx, step, recipe) do
    ctx
    |> recipe.()
    |> set_char_var(:b_sword, step)
    |> next()
    |> mes("[Cylrnel]")
    |> mes("Wrote them down?")
    |> mes("I'll tell you once again.")
    |> mes("We need...")
    |> next()
    |> recipe.()
    |> next()
  end

  defp full_recipe(ctx) do
    ctx
    |> mes("[Cylrnel]")
    |> mes("^FF00002 Yggdrasil Seeds")
    |> mes("3 Aloes")
    |> mes("1 Witherless Rose")
    |> mes("10 Witch Starsands")
    |> mes("5 Burning Hearts")
    |> mes("5 Ice Cubics")
  end

  defp weak_recipe(ctx) do
    ctx
    |> mes("[Cylrnel]")
    |> mes("^FF00001 Yggdrasil Seed")
    |> mes("1 Aloe")
    |> mes("5 Witch Starsands")
    |> mes("3 Burning Hearts")
    |> mes("3 Ice Cubics")
  end

  defp weak_medicine(ctx) do
    if has_weak_ingredients?(ctx) do
      ctx
      |> mes("[Cylrnel]")
      |> mes("Hmm...")
      |> mes("Good, you got them all.")
      |> mes("Let me see now...")
      |> mes(".............")
      |> next()
      |> mixes_the_ingredients()
      |> mes("[Cylrnel]")
      |> mes("............")
      |> mes("What the?!?!")
      |> mes("...")
      |> mes("Hey you...")
      |> mes("You gave me the wrong information!")
      |> delitem(@yggdrasil_seed, 1)
      |> delitem(@aloe, 1)
      |> delitem(@witch_starsand, 5)
      |> delitem(@burning_heart, 3)
      |> delitem(@ice_cubic, 3)
      |> set_char_var(:b_sword, 24)
      |> next()
      |> mes("[Cylrnel]")
      |> mes("I've chosen the ingredients")
      |> mes("according to the symptoms")
      |> mes("you've described...")
      |> mes("But this isn't medicine!!")
      |> mes("Now go and find out her exact symptoms!")
      |> close()
      |> warp("yuno", 246, 143)
    else
      ctx
      |> mes("[Cylrnel]")
      |> mes("...")
      |> mes("Hey~ you don't have all")
      |> mes("the ingredients yet.")
      |> mes("Go get them all right away.")
      |> next()
      |> mes("[Cylrnel]")
      |> mes("^FF00001 Seed of Yggdrasil")
      |> mes("1 Aloe")
      |> mes("5 Witch Starsands")
      |> mes("3 Burning Hearts")
      |> mes("3 Ice Cubics")
      |> next()
      |> mes("[Cylrnel]")
      |> mes("Alright?")
      |> mes("Now, hurry up!")
      |> close()
      |> warp("yuno", 246, 143)
    end
  end

  defp has_weak_ingredients?(ctx) do
    count_item(ctx, @yggdrasil_seed) > 0 and count_item(ctx, @aloe) > 0 and
      count_item(ctx, @witch_starsand) > 4 and count_item(ctx, @burning_heart) > 2 and
      count_item(ctx, @ice_cubic) > 2
  end

  defp full_medicine(ctx) do
    if has_full_ingredients?(ctx) do
      ctx
      |> mes("[Cylrnel]")
      |> mes("Hmm...")
      |> mes("Good, you got them all.")
      |> mes("Let me see..")
      |> mes(".............")
      |> next()
      |> mixes_the_ingredients()
      |> mes("[Cylrnel]")
      |> mes("Here~! It's done...")
      |> mes("I don't think this medicine will")
      |> mes("cure her disease completely.")
      |> mes("However, it will greatly alleviate her pain.")
      |> next()
      |> mes("[Cylrnel]")
      |> mes("It wasn't easy to make this")
      |> mes("medicine. Take care, bring")
      |> mes("this to Lyroo and give her my regards...")
      |> delitem(@yggdrasil_seed, 2)
      |> delitem(@aloe, 3)
      |> delitem(@witherless_rose, 1)
      |> delitem(@witch_starsand, 10)
      |> delitem(@burning_heart, 5)
      |> delitem(@ice_cubic, 5)
      |> set_char_var(:b_sword, 27)
      |> give_item(@aloevera, 1)
      |> close()
    else
      ctx
      |> mes("[Cylrnel]")
      |> mes("...")
      |> mes("Hey~ You don't have all")
      |> mes("the ingredients yet.")
      |> mes("Go get them all right away!")
      |> next()
      |> full_recipe()
      |> next()
      |> mes("[Cylrnel]")
      |> mes("Alright?")
      |> mes("Go get them as fast as possible.")
      |> close()
      |> warp("yuno", 246, 143)
    end
  end

  defp has_full_ingredients?(ctx) do
    count_item(ctx, @yggdrasil_seed) > 1 and count_item(ctx, @aloe) > 2 and
      count_item(ctx, @witherless_rose) > 0 and count_item(ctx, @witch_starsand) > 9 and
      count_item(ctx, @burning_heart) > 4 and count_item(ctx, @ice_cubic) > 4
  end

  defp mixes_the_ingredients(ctx) do
    ctx
    |> mes("^FF0000Cylrnel began to mix")
    |> mes("the ingredients.")
    |> mes("................")
    |> mes(".............")
    |> mes(".........")
    |> mes("......^000000")
    |> next()
  end

  defp after_the_cure(ctx) do
    ctx
    |> mes("[Cylrnel]")
    |> mes("Hey there...")
    |> mes("How is she doing?")
    |> mes("Getting better?")
    |> mes("By taking that medicine,")
    |> mes("she'll recover fast.")
    |> next()
    |> mes("[Cylrnel]")
    |> mes("Tell her to come to me")
    |> mes("sometime to get medical")
    |> mes("treatment. Walking from her")
    |> mes("house to here would be good")
    |> mes("exercise too.")
    |> next()
    |> mes("[Cylrnel]")
    |> mes("The name of her disease is")
    |> mes("called '^FF0000Amarhade^000000'.")
    |> mes("It's a rare, relatively")
    |> mes("unknown illness, so an exact")
    |> mes("treatment hasn't been found yet.")
    |> next()
    |> mes("[Cylrnel]")
    |> mes("But I found a treatment...")
    |> mes("And...it's..a...secret! Haha~!")
    |> emotion(:delight)
    |> close()
  end
end
