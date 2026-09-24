defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Sage.BiologyProfessor do
  @moduledoc """
  Lucius Celsus, the Sage academy biology professor who teaches about fish and insect
  monsters and hands the candidate a ready-made thesis.

  ## Behavior

  - Greets non-Mages with class-specific small talk.
  - Assigns one of three random fish-monster item sets, then quizzes the candidate about
    water-property monsters once the items are brought.
  - Assigns one of four random insect-monster item sets and lectures on insects once they
    are brought, then asks for thesis materials.
  - Consumes the thesis materials, has the candidate copy his thesis, grants the
    dissertation, and advances the quest.

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
        x: 32,
        y: 102,
        dir: 1,
        sprite: 755,
        name: "Biology Professor",
        scope: :shared,
        unique_name: "Biology Professor#sa"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Lucius Celsus]")

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
        |> mes("What is your business with me?")
        |> mes("You must make a reservation a week in advance if you have any questions.")
        |> next()
        |> mes("[Lucius Celsus]")
        |> mes("You don't know how busy person I am...don't you?")
        |> mes("If you're a Sage, you're supposed to know about me by now.")
        |> next()
        |> mes("[Lucius Celsus]")
        |> mes("You have too much time on your hands. Go explore some dungeons.")
        |> mes("I think it will be more helpful than wasting your time on me.")

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) ->
        ctx
        |> mes("What brings you to me, kid?")
        |> next()
        |> mes("[Lucius Celsus]")
        |> mes("You'd better go out and play with your pals. ")
        |> mes("This is not a place where you can fool around.")

      true ->
        ctx
        |> mes("Hmm? What brings you to me? Are you interested in watching monsters?")
        |> next()
        |> mes("[Lucius Celsus]")
        |> mes("You're allowed to watch. However, do not disturb them by making any fuss.")
        |> mes("And keep your hands off, some of these guys are way too dangerous to touch.")
        |> next()
        |> mes("[Lucius Celsus]")
        |> mes("By the way, if you catch any rare monsters in future, let me know.")
        |> mes("I am willing to purchase those at any cost.")
    end
  end

  defp talk_to_candidate(ctx, 11) do
    step = get_char_var(ctx, :SAGE_Q2, 0)

    cond do
      step == 0 -> introduce_class(ctx)
      step >= 1 and step <= 3 -> check_fish_items(ctx, fish_items(step))
      step >= 4 and step <= 7 -> check_insect_items(ctx, insect_items(step))
      true -> ctx |> mes("Zzz...Zzz...") |> close()
    end
  end

  defp talk_to_candidate(ctx, 12) do
    if count_item(ctx, 916) > 0 and count_item(ctx, 919) > 0 and count_item(ctx, 1019) > 0 and
         count_item(ctx, 1024) > 0 and count_item(ctx, 713) > 0 do
      write_thesis(ctx)
    else
      ctx
      |> mes("What, are you sure that you're ready? No, I don't think so.")
      |> mes("Oh well... listen carefully this time.")
      |> next()
      |> mes("[Lucius Celsus]")
      |> mes("^3355FF1 Feather of Birds^000000 which will be used as a pen,")
      |> mes("^3355FF1 Animal Skin^000000 which will be used as paper,")
      |> mes("^3355FF1 Trunk^000000 which will be used to bind a book,")
      |> mes("^3355FF1 Squid Ink^000000 which will be used as ink,")
      |> mes("^3355FF1 Empty Bottle^000000 which will be used for holding squid ink.")
      |> next()
      |> mes("[Lucius Celsus]")
      |> mes("You have been doing fine, I guess you can do this without a problem.")
      |> mes("Go get them. Hurry up.")
      |> close()
    end
  end

  defp talk_to_candidate(ctx, 15) do
    ctx
    |> mes("What are you doing here, Go show your thesis to the dean!")
    |> mes("Don't wasn't any more time here.")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("It seems you have too much time on your hands. Okay, I will assign you some tasks.")
    |> mes("Hahaha, did you say no? Alright then, fine. Scram.")
    |> close()
  end

  defp talk_to_candidate(ctx, _quest) do
    ctx
    |> mes(
      "Wah~! My brain is gonna blow up soon! Why must I have to prepare all of these things?!"
    )
    |> mes("Who are you?! Don't disturb me, I'm busy!!")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("If you just want to watch monsters here, fine with me...")
    |> mes("Just don't ask me any questions.")
    |> close()
  end

  defp fish_items(1), do: [962, 1052, 1023]
  defp fish_items(2), do: [960, 966, 950]
  defp fish_items(3), do: [1050, 960, 963]

  defp insect_items(4), do: [1025, 935, 928]
  defp insect_items(5), do: [947, 946, 1057]
  defp insect_items(6), do: [1031, 955, 1013]
  defp insect_items(7), do: [1025, 1031, 943]

  defp introduce_class(ctx) do
    ctx =
      ctx
      |> mes("Welcome to my class, did you earn good results in the practical exam?")
      |> mes("My name is Lucius Celsus, the expert of Biology.")
      |> next()
      |> mes("[Lucius Celsus]")
      |> mes(
        "Huh...how rude of you! You're expected to introduce yourself to me as soon as I greet you!"
      )
      |> mes("What is your name, young one?")
      |> next()

    {ctx, _} = select(ctx, String.split(to_string(char_name(ctx, 0)), ":"))

    {ctx, choice} =
      ctx
      |> mes("[Lucius Celsus]")
      |> mes("A fine name. It's nice to meet you.")
      |> mes("So, are you aware of the subject you're studying?")
      |> next()
      |> mes("[Lucius Celsus]")
      |> mes("As you know, your topic of study is monsters.")
      |> mes("How many times have you fought with monsters?")
      |> next()
      |> select(["Well, I can't even count.", "A few times, I guess..."])

    ctx =
      if choice == 1 do
        ctx
        |> mes("[Lucius Celsus]")
        |> mes("Oh shut up, you brat. Don't be so sure about yourself.")
        |> mes(
          "Even if you have much experience with monsters, you will have a hard time comprehending my lecture."
        )
      else
        ctx
      end

    ctx =
      ctx
      |> mes("[Lucius Celsus]")
      |> mes("Yes, that's what I guessed about you. You're just book smart.")
      |> mes(
        "However, I am sure you will encounter most of the monsters mentioned in my lecture."
      )
      |> next()
      |> set_char_var(:sage_m4, Enum.random(1..3))
      |> mes("[Lucius Celsus]")
      |> mes("Let's get started.")
      |> mes("Make sure you're ready for the practical examination during my lecture.")
      |> next()

    ctx
    |> assign_fish_set(get_char_var(ctx, :sage_m4, 0))
    |> dismiss_until_items_brought()
  end

  defp assign_fish_set(ctx, 1) do
    ctx
    |> set_char_var(:SAGE_Q2, 1)
    |> changequest(2048, 2053)
    |> mes("[Lucius Celsus]")
    |> mes("Go bring the following items to me.")
    |> mes("5 ^3355FFTentacle^000000,")
    |> mes("5 ^3355FFSingle Cell^000000,")
    |> mes("5 ^3355FFFish Tail^000000.")
  end

  defp assign_fish_set(ctx, 2) do
    ctx
    |> set_char_var(:SAGE_Q2, 2)
    |> changequest(2048, 2054)
    |> mes("[Lucius Celsus]")
    |> mes("Go bring the following items to me.")
    |> mes("5 ^3355FFNipper^000000,")
    |> mes("5 ^3355FFClam Flesh^000000,")
    |> mes("5 ^3355FFHeart of Mermaid^000000.")
  end

  defp assign_fish_set(ctx, _roll) do
    ctx
    |> set_char_var(:SAGE_Q2, 3)
    |> changequest(2048, 2054)
    |> mes("[Lucius Celsus]")
    |> mes("Go bring following items to me.")
    |> mes("5 ^3355FFTendon^000000,")
    |> mes("5 ^3355FFNipper^000000,")
    |> mes("5 ^3355FFSharp Scale^000000.")
  end

  defp dismiss_until_items_brought(ctx) do
    ctx
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("I will proceed with the class when you bring those to me.")
    |> mes("Have fun.")
    |> close()
  end

  defp has_items?(ctx, [first, second, third]) do
    count_item(ctx, first) > 4 and count_item(ctx, second) > 4 and count_item(ctx, third) > 4
  end

  defp remind_items(ctx, [first, second, third]) do
    ctx
    |> mes("5 ^3355FF#{Rathena.getitemname(first)}^000000,")
    |> mes("5 ^3355FF#{Rathena.getitemname(second)}^000000,")
    |> mes("5 ^3355FF#{Rathena.getitemname(third)}^000000,")
    |> close()
  end

  defp check_fish_items(ctx, items) do
    if has_items?(ctx, items) do
      quiz_on_fish(ctx)
    else
      ctx
      |> mes("What, you already forgot what I told you just a minute before?")
      |> mes("What a nusance... listen carefully this time.")
      |> next()
      |> mes("[Lucius Celsus]")
      |> remind_items(items)
    end
  end

  defp quiz_on_fish(ctx) do
    {ctx, similarity} =
      ctx
      |> mes("You showed great effort to gather all of those.")
      |> mes("Well, I am not sure if you gathered them by yourself or bought them from shops...")
      |> next()
      |> mes("[Lucius Celsus]")
      |> mes("Somehow the monsters that drop those items have something in common.")
      |> mes("Can you tell me what that similarity is?")
      |> next()
      |> select([
        "They possess water property.",
        "They are fishes.",
        "They are aggressive.",
        "Um...they monsters."
      ])

    {ctx, spell} =
      ctx
      |> answer_fish_similarity(similarity)
      |> next()
      |> mes("[Lucius Celsus]")
      |> mes("Not all fish class monsters possess water property, but most of them do.")
      |> mes("So which kind of magic would work best on most fish class monsters?")
      |> next()
      |> select(["Lightening Bolt.", "Fire Bolt.", "Thunder Storm.", "Frost Diver."])

    ctx
    |> answer_fish_spell(spell)
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes(
      "By the way, although some monsters such as Penomena or Aster are considered to be fish class monsters, "
    )
    |> mes("they have a different property than the others. You'd better be careful with them.")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("Okay, let me teach you about insect monsters.")
    |> mes("Let's see... hmm... hmm...")
    |> next()
    |> assign_insect_set(Enum.random(1..4))
    |> dismiss_until_items_brought()
  end

  defp answer_fish_similarity(ctx, choice) when choice in [1, 2] do
    ctx
    |> mes("[Lucius Celsus]")
    |> mes("Yes, they possess water property and at the same time they are fishes.")
    |> mes(
      "Most fish class monsters live underwater, so they are attributed with the water property."
    )
  end

  defp answer_fish_similarity(ctx, 3) do
    ctx
    |> set_char_var(:sage_m4, 4)
    |> mes("[Lucius Celsus]")
    |> mes("...I didn't know Phens were aggressive nowadays?")
    |> mes("Or do Marina and Plankton team up to start a fight with you?")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes(
      "All the monsters from which you obtained these items are not agressive... get a grip."
    )
    |> mes("They are all fishes and possess water property.")
  end

  defp answer_fish_similarity(ctx, 4) do
    ctx
    |> set_char_var(:sage_m4, 4)
    |> mes("[Lucius Celsus]")
    |> mes(
      "What...! What are you here for!? You are here to study about specific monsters, microcephalic moron!"
    )
    |> mes("Sigh...they are all fishes and possess water property.")
  end

  defp answer_fish_similarity(ctx, _choice), do: ctx

  defp answer_fish_spell(ctx, 1) do
    ctx
    |> mes("[Lucius Celsus]")
    |> mes(
      "That's right, Lightening Bolt, which possesses the wind property, works best on water property monsters."
    )
    |> mes("Although you might want to be careful of monsters that recognize magic casting.")
  end

  defp answer_fish_spell(ctx, 2) do
    ctx
    |> set_char_var(:sage_m4, 4)
    |> mes("[Lucius Celsus]")
    |> mes("What? Fire Bolt! Fire cannot beat water, you imbecile!")
    |> mes(
      "Most fishes are attributed with the water property. Therefore, they are weak to wind property magic spells. Don't you get it?"
    )
  end

  defp answer_fish_spell(ctx, 3) do
    ctx
    |> mes("[Lucius Celsus]")
    |> mes("Yeah, Thunder Storm spell is fine... it's a wind property spell.")
    |> mes("However, you will be in trouble if you use the spell in a poorly chosen spot.")
  end

  defp answer_fish_spell(ctx, 4) do
    ctx
    |> set_char_var(:sage_m4, 4)
    |> mes("[Lucius Celsus]")
    |> mes(
      "I can't fathom such stupidity! This question asks you to choose a property that counters water! Don't you get it?"
    )
    |> mes(
      "Logically, any magic spell possessing the water property cannot overcome the water atrribute monsters!"
    )
  end

  defp answer_fish_spell(ctx, _choice), do: ctx

  defp assign_insect_set(ctx, 1) do
    ctx
    |> set_char_var(:SAGE_Q2, 4)
    |> advance_fish_quest(2056)
    |> mes("5 ^3355FFCobweb^000000,")
    |> mes("5 ^3355FFShell^000000,")
    |> mes("5 ^3355FFInsect Feeler^000000.")
  end

  defp assign_insect_set(ctx, 2) do
    ctx
    |> set_char_var(:SAGE_Q2, 5)
    |> advance_fish_quest(2057)
    |> mes("5 ^3355FFHorn^000000,")
    |> mes("5 ^3355FFSnail's Shell^000000,")
    |> mes("5 ^3355FFMoth Dust^000000.")
  end

  defp assign_insect_set(ctx, 3) do
    ctx
    |> set_char_var(:SAGE_Q2, 6)
    |> advance_fish_quest(2058)
    |> mes("5 ^3355FFMantis Scythe^000000,")
    |> mes("5 ^3355FFWorm Peeling^000000,")
    |> mes("5 ^3355FFRainbow Shell^000000.")
  end

  defp assign_insect_set(ctx, 4) do
    ctx
    |> set_char_var(:SAGE_Q2, 7)
    |> advance_fish_quest(2059)
    |> mes("5 ^3355FFCobweb^000000,")
    |> mes("5 ^3355FFMantis Scythe^000000,")
    |> mes("5 ^3355FFSolid Shell^000000.")
  end

  defp assign_insect_set(ctx, _roll), do: ctx

  defp advance_fish_quest(ctx, insect_quest) do
    cond do
      checkquest(ctx, 2053) != -1 -> changequest(ctx, 2053, insect_quest)
      checkquest(ctx, 2054) != -1 -> changequest(ctx, 2054, insect_quest)
      true -> changequest(ctx, 2055, insect_quest)
    end
  end

  defp check_insect_items(ctx, items) do
    if has_items?(ctx, items) do
      lecture_on_insects(ctx)
    else
      ctx
      |> mes("What, you already forgot what I told you?")
      |> mes("What a nuisance...listen carefully this time.")
      |> next()
      |> mes("[Lucius Celsus]")
      |> remind_items(items)
    end
  end

  defp lecture_on_insects(ctx) do
    ctx
    |> mes("Well done. So, did you watch insects while gathering those items?")
    |> mes("Oh well, I believe you did a good job with the task.")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("Insect class monsters do not share the same property most of the time, ")
    |> mes("You must think twice before you cast a magic spell on an insect.")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("It's remarkable that insects can detect hidden objects.")
    |> mes(
      "Therefore, any hiding skill such as the Hiding skill or Cloaking skill will not work on insect monsters."
    )
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("Some insects form a group and live together.")
    |> mes("They are controlled by the head of the group...")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("For instance, Maya the queen ant...")
    |> mes("Mistress, the queen of hornets,")
    |> mes("or Golden Thiefbug, the king of thiefbugs...")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("You cannot beat those boss monsters alone, ")
    |> mes("you'd better form a party if you want to fight with them.")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("That's the end of my class...it's time for you to write a thesis.")
    |> mes("Bring me following items for writing the thesis.")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("^3355FF1 Feather of Birds^000000 which will be used as a pen,")
    |> mes("^3355FF1 Animal Skin^000000 which will be used as paper,")
    |> mes("^3355FF1 Trunk^000000 which will be used to bind a book,")
    |> mes("^3355FF1 Squid Ink^000000 which will be used as ink,")
    |> mes("^3355FF1 Empty Bottle^000000 which will be used for holding squid ink.")
    |> next()
    |> set_char_var(:SAGE_Q2, 0)
    |> set_char_var(:SAGE_Q, 12)
    |> advance_insect_quest()
    |> mes("[Lucius Celsus]")
    |> mes("I will help you in writing the thesis when you bring all of those items.")
    |> mes("You're almost there. Isn't learning easy?")
    |> close()
  end

  defp advance_insect_quest(ctx) do
    cond do
      checkquest(ctx, 2056) != -1 -> changequest(ctx, 2056, 2051)
      checkquest(ctx, 2057) != -1 -> changequest(ctx, 2057, 2051)
      checkquest(ctx, 2058) != -1 -> changequest(ctx, 2058, 2051)
      true -> changequest(ctx, 2059, 2051)
    end
  end

  defp write_thesis(ctx) do
    ctx
    |> delitem(916, 1)
    |> delitem(919, 1)
    |> delitem(1019, 1)
    |> delitem(1024, 1)
    |> delitem(713, 1)
    |> mes("Hmph. Lucky brat brought all of the items.")
    |> mes("Well, I don't expect you to write an outrageously great thesis though...")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("Well, if you really want to write it by yourself, I can let you handle it but...")
    |> mes("I will give you a work of staggering genius. Just make a copy of it under your name.")
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("You got a problem with that? Tough, that's my style.")
    |> mes("Just do what I say.")
    |> next()
    |> mes("..........")
    |> next()
    |> mes("....................")
    |> next()
    |> mes(".................................")
    |> next()
    |> copy_line(".....Monsters vary by physical appearance,")
    |> mes(".....Monsters vary by physical appearance,")
    |> copy_line("...and possess various elemental properties.")
    |> mes("...and possess various elemental properties.")
    |> copy_line("You must be aware of each monster's properties,")
    |> mes("You must be aware of each monster's properties,")
    |> copy_line("...and be aware that certain spells work differently on different monsters.")
    |> mes("...and be aware that certain spells work differently on different monsters.")
    |> copy_line("You must be especially careful of holy property and shadow property monsters.")
    |> mes("You must be especially careful of holy property and shadow property monsters.")
    |> copy_line("These monsters are most dangerous, though occasionally cute.")
    |> mes("These monsters are most dangerous.")
    |> next()
    |> mes("..........")
    |> next()
    |> mes("....................")
    |> next()
    |> mes(".................................")
    |> next()
    |> set_char_var(:SAGE_Q, 15)
    |> changequest(2051, 2052)
    |> mes("[Lucius Celsus]")
    |> mes("Are you done? Okay, then it's over.")
    |> mes("You won't be able to write another thesis again, handle this with care.")
    |> give_item(1550, 1)
    |> next()
    |> mes("[Lucius Celsus]")
    |> mes("Show this masterpiece to the dean.")
    |> mes("Then, he will let you graduate from the academy. See you.")
    |> close()
  end

  defp copy_line(ctx, line) do
    {ctx, _} = select(ctx, [line])
    ctx
  end
end
