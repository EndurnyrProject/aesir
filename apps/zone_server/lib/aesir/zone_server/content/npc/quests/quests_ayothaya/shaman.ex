defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Shaman do
  @moduledoc """
  Boonthom guides adventurers through the Ayothaya dungeon and crafts protective holy threads.

  ## Behavior

  - Explains the ruins and requests materials for protective threads.
  - Crafts and replaces threads, including stronger ones for the deeper dungeon.
  - Advances the dungeon quest and receives a message from a fallen friend.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """
  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayo_in01",
        x: 181,
        y: 193,
        dir: 4,
        sprite: 840,
        name: "Shaman",
        scope: :shared,
        unique_name: "Shaman#thai"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @needle_packet 7213
  @spool 7217
  @fabric 1059
  @nine_tails 1022
  @solid_husk 7190
  @holy_water 523
  @yggdrasil_leaf 610
  @holy_thread 7285
  @strong_holy_thread 7287

  @impl true
  def on_talk(ctx) do
    items =
      if Rathena.truthy?(checkre(ctx, 0)),
        do: [@needle_packet, @spool],
        else: [@fabric, @nine_tails]

    ctx = set_local(ctx, :items, items)
    quest(ctx, get_char_var(ctx, :ayodunquest, 0), items)
  end

  defp quest(ctx, 1, items), do: introduction(ctx, items)

  defp quest(ctx, stage, items) when stage in [2, 3] do
    if basic_materials?(ctx, items),
      do: craft_basic(ctx, stage, items),
      else: basic_reminder(ctx, stage, items)
  end

  defp quest(ctx, stage, _items) when stage > 3 and stage < 9 do
    ctx
    |> mes("[Boonthom]")
    |> mes("You finally started seeking the tiger. I hope that you will be safe from harm.")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Feel free to ask")
    |> mes("me for help at anytime.")
    |> close()
  end

  defp quest(ctx, 9, items), do: slate(ctx, items)

  defp quest(ctx, 10, items) do
    if strong_materials?(ctx, items),
      do: craft_strong(ctx, 10, items),
      else: strong_reminder(ctx, 10, items)
  end

  defp quest(ctx, stage, items) when stage == 11 or stage > 12 do
    cond do
      count_item(ctx, @strong_holy_thread) > 0 ->
        protected(ctx, stage)

      strong_materials?(ctx, items) and count_item(ctx, @strong_holy_thread) == 0 ->
        craft_strong(ctx, stage, items)

      true ->
        strong_reminder(ctx, stage, items)
    end
  end

  defp quest(ctx, 12, _items), do: letter(ctx)

  defp quest(ctx, _stage, _items),
    do: ctx |> mes("[Boonthom]") |> mes("Ooooohmmmmm...") |> close()

  defp introduction(ctx, items) do
    {ctx, choice} =
      ctx
      |> mes("[Boonthom]")
      |> mes("You...!")
      |> mes("Isn't it....!")
      |> mes("Oooooohhhhhhh!")
      |> next()
      |> mes("[Boonthom]")
      |> mes("Oh...?")
      |> next()
      |> mes("[Boonthom]")
      |> mes("...")
      |> next()
      |> mes("[Boonthom]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Boonthom]")
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Boonthom]")
      |> mes("Never mind.")
      |> mes("Hah! I've lost my")
      |> mes("train of thought.")
      |> next()
      |> mes("[Boonthom]")
      |> mes(
        "So have you come to me to seek help? I can see the fear in your eyes. Let me gaze into your soul, and see what your fear is for myself. Hmmm..."
      )
      |> next()
      |> mes("[Boonthom]")
      |> mes("...")
      |> next()
      |> mes("[Boonthom]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Boonthom]")
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Boonthom]")
      |> mes("What...!")
      |> mes(
        "I see that you dread the Sa-mhing Tiger! I haven't heard any news of that monster for a long time..."
      )
      |> next()
      |> mes("[Boonthom]")
      |> mes("A long time ago,")
      |> mes("the Sa-mhing Tiger")
      |> mes("really did roam the village")
      |> mes("and ate innocent people.")
      |> next()
      |> mes("[Boonthom]")
      |> mes("However, its terror")
      |> mes("was brought to an end when it")
      |> mes("was finally captured. I was one of those involved in capturing the Sa-mhing Tiger.")
      |> next()
      |> mes("[Boonthom]")
      |> mes(
        "I insisted killing on it, but the other people were too afraid to do so. Instead, the Sa-mhing Tiger"
      )
      |> mes("was locked in a cave inside of the ancient ruins.")
      |> next()
      |> mes("[Boonthom]")
      |> mes(
        "I believe that was at least 10 years ago. Perhaps it's already dead by now. However, no one"
      )
      |> mes("knows how powerful the tiger truly")
      |> mes("is. It may still be alive.")
      |> next()
      |> mes("[Boonthom]")
      |> mes(
        "I don't think we need to worry about it though. It is locked up and there it shall remain."
      )
      |> next()
      |> select(["I want to explore the ancient ruins.", "Locked up! Good! I'm not afraid!"])

    case choice do
      1 -> offer_advice(ctx, items)
      _ -> ctx
    end
  end

  defp offer_advice(ctx, items) do
    {ctx, choice} =
      ctx
      |> mes("[Boonthom]")
      |> mes("You...")
      |> mes("You are strange.")
      |> mes(
        "You want to explore the ancient ruins. Do all adventurers disregard their safety like that?"
      )
      |> next()
      |> mes("[Boonthom]")
      |> mes(
        "It's your choice. But remember, it is very dangerous to go through the path to the center of the building. Usually, I forbid it."
      )
      |> next()
      |> mes("[Boonthom]")
      |> mes("But if you want to go in,")
      |> mes("I can give you some useful tips.")
      |> mes("Would you like to listen?")
      |> next()
      |> select(["If it's that dangerous, I'd rather not try.", "Sure!"])

    if choice == 1 do
      ctx
      |> mes("[Boonthom]")
      |> mes("You made a good decision.")
      |> mes("You'd better be careful if")
      |> mes("you want to stay alive.")
      |> close()
    else
      explain_protection(ctx, items)
    end
  end

  defp explain_protection(ctx, items) do
    ctx =
      ctx
      |> mes("[Boonthom]")
      |> mes("Umm, okay.")
      |> mes("Since you're")
      |> mes("that interested...")
      |> next()
      |> mes("[Boonthom]")
      |> mes(
        "If you wish to enter the ancient building, you must have protection against evil spirits and malice."
      )
      |> next()

    ctx =
      if Rathena.job_id(class(ctx)) == Rathena.job_id(:priest) or
           Rathena.job_id(class(ctx)) == Rathena.job_id(:acolyte) or
           Rathena.job_id(class(ctx)) == Rathena.job_id(:crusader) do
        ctx
        |> mes("[Boonthom]")
        |> mes("Even if you can")
        |> mes("wield the power of")
        |> mes("holiness, you will still need the spiritual security of our land.")
      else
        ctx
        |> mes("[Boonthom]")
        |> mes("There are many ghosts and")
        |> mes(
          "demons within the cave, and they will attack people who do not possess holy power... Like you."
        )
      end

    ctx
    |> next()
    |> mes("[Boonthom]")
    |> mes("I can make you an object")
    |> mes(
      "containing this holy power if you wish. In order to make it, I will need some materials."
    )
    |> next()
    |> mes("[Boonthom]")
    |> basic_items(items, "...")
    |> mes("That's all I need.")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Please come back")
    |> mes("when you prepare all")
    |> mes("the materials.")
    |> set_char_var(:ayodunquest, 2)
    |> changequest(12035, 12036)
    |> close()
  end

  defp basic_materials?(ctx, [first, second]) do
    count_item(ctx, first) > 0 and count_item(ctx, second) > 0 and
      count_item(ctx, @solid_husk) > 0 and count_item(ctx, @holy_water) > 0
  end

  defp strong_materials?(ctx, [first, second]) do
    count_item(ctx, @holy_water) > 1 and count_item(ctx, @yggdrasil_leaf) > 0 and
      count_item(ctx, first) > 1 and count_item(ctx, second) > 1
  end

  defp craft_basic(ctx, 2, [first, second]) do
    ctx
    |> mes("[Boonthom]")
    |> mes("Excellent!")
    |> mes("Now you have brought")
    |> mes("everything I need. Let me make")
    |> mes("the thing for you as promised...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Ooooohmmmmm...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Hmmmmmm...")
    |> mes("Hmmmmmmmmm.")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Pffff pffff...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Here you go.")
    |> mes("Please take these holy threads.")
    |> mes("With this, you will be able to enter the ruins with less worry.")
    |> delitem(first, 1)
    |> delitem(second, 1)
    |> delitem(@solid_husk, 1)
    |> delitem(@holy_water, 1)
    |> set_char_var(:ayodunquest, 3)
    |> changequest(12036, 12037)
    |> give_item(@holy_thread, 1)
    |> next()
    |> mes("[Boonthom]")
    |> mes("Even if you lose this, don't worry. Just bring me the materials, and")
    |> mes("I will make you another one.")
    |> next()
    |> mes("[Boonthom]")
    |> mes("The ancient building consists")
    |> mes(
      "of 2 levels. Before you enter the 2nd underground level, please return to me so that I can tell you how to enter that place."
    )
    |> close()
  end

  defp craft_basic(ctx, 3, [first, second]) do
    ctx
    |> mes("[Boonthom]")
    |> mes(
      "Excellent! Now you have brought everything I need, let me make the thing for you as I promised..."
    )
    |> next()
    |> mes("[Boonthom]")
    |> mes("Ooooohmmmmm...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Hmmmmmm...")
    |> mes("Hmmmmmmmmm.")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Pffff pffff...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Here you go.")
    |> mes("Please take these holy threads.")
    |> mes("With this, you will be able to enter the ruins with less worry.")
    |> delitem(first, 1)
    |> delitem(second, 1)
    |> delitem(@solid_husk, 1)
    |> delitem(@holy_water, 1)
    |> give_item(@holy_thread, 1)
    |> next()
    |> mes("[Boonthom]")
    |> mes(
      "Even if you lose this, don't worry. Just bring me the materials, I can make you another one."
    )
    |> close()
  end

  defp basic_reminder(ctx, 2, items) do
    ctx
    |> mes("[Boonthom]")
    |> mes("Did you forget what materials")
    |> mes("you need to create my object of holy power? Please listen")
    |> mes("carefully this time.")
    |> next()
    |> mes("[Boonthom]")
    |> basic_items(items, ".")
    |> next()
    |> mes("[Boonthom]")
    |> mes("See you later.")
    |> close()
  end

  defp basic_reminder(ctx, 3, items) do
    ctx
    |> mes("[Boonthom]")
    |> mes(
      "If you lose the holy threads, don't worry. I can make some more for you. Just gather the following items."
    )
    |> next()
    |> mes("[Boonthom]")
    |> basic_items(items, ".")
    |> next()
    |> mes("[Boonthom]")
    |> mes("See you later.")
    |> close()
  end

  defp basic_items(ctx, [first, second], ending) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("^3366991 ", Rathena.getitemname(first)), "^000000,"))
    |> mes(Rathena.concat(Rathena.concat("^3366991 ", Rathena.getitemname(second)), "^000000,"))
    |> mes("^3366991 Solid Husk^000000 and")
    |> mes("^3366991 Holy Water^000000" <> ending)
  end

  defp slate(ctx, items) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I copied down this")
    |> mes("message while exploring")
    |> mes("the dungeon. Would you")
    |> mes("take a look at this?")
    |> next()
    |> mes("[Stone Slate]")
    |> mes("^333333Do not enter the")
    |> mes("2nd underground level")
    |> mes("...is danger... You wil...")
    |> mes("...encounter... tiger...^000000")
    |> next()
    |> mes("[Stone Slate]")
    |> mes(
      "^333333You must kill... In order to do... MUST... How to go... the 2nd underground level..."
    )
    |> mes("You need more... Holy power... in order to... Otherwise, it's impossible...^000000")
    |> next()
    |> mes("[Boonthom]")
    |> mes("That was written by one of my comrades who entered the ruins,")
    |> mes("as he regretted letting the tiger live, lest it return.")
    |> next()
    |> mes("[Boonthom]")
    |> mes(
      "If you were able to find this note, you must have strong determination to venture through the ruins."
    )
    |> next()
    |> mes("[Boonthom]")
    |> mes("As you can guess from the")
    |> mes(
      "note, the 2nd underground level is very very dangerous. You will need holy threads that contain even more holy protection."
    )
    |> next()
    |> mes("[Boonthom]")
    |> mes(
      "Now, go and gather some materials so that I can create more powerful holy threads for you."
    )
    |> next()
    |> mes("[Boonthom]")
    |> mes("^3366992 Holy Water^000000,")
    |> mes("^3366991 Yggdrasil Leaf^000000,")
    |> strong_items(items)
    |> set_char_var(:ayodunquest, 10)
    |> changequest(12037, 12038)
    |> next()
    |> mes("[Boonthom]")
    |> mes("Return to me")
    |> mes("once you have")
    |> mes("gathered everything.")
    |> close()
  end

  defp craft_strong(ctx, 10, [first, second]) do
    ctx
    |> mes("[Boonthom]")
    |> mes("Hmm~")
    |> mes("You've brought")
    |> mes("everything. Quite")
    |> mes("the enthusiastic one,")
    |> mes("aren't you?")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Ooooohmmmmm...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Hmmmmmm...")
    |> mes("Hmmmmmmmmm.")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Pffff pffff...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Here you go.")
    |> mes("Please take these holy threads.")
    |> mes("With this, you will be able to enter the ruins with less worry.")
    |> delitem(first, 2)
    |> delitem(second, 2)
    |> delitem(@yggdrasil_leaf, 1)
    |> delitem(@holy_water, 2)
    |> set_char_var(:ayodunquest, 11)
    |> give_item(@strong_holy_thread, 1)
    |> changequest(12038, 12039)
    |> next()
    |> mes("[Boonthom]")
    |> mes("Even if you lose this, don't worry. Just bring me the materials, and")
    |> mes("I will make you another one.")
    |> close()
  end

  defp craft_strong(ctx, 11, [first, second]) do
    ctx
    |> mes("[Boonthom]")
    |> mes("Ooooohmmmmm...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Hmmmmmm...")
    |> mes("Hmmmmmmmmm.")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Pffff pffff...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Here you go.")
    |> mes("Please take these holy threads.")
    |> mes("With this, you will be able to enter the ruins with less worry.")
    |> delitem(first, 2)
    |> delitem(second, 2)
    |> delitem(@yggdrasil_leaf, 1)
    |> delitem(@holy_water, 2)
    |> give_item(@strong_holy_thread, 1)
    |> close()
  end

  defp craft_strong(ctx, _stage, [first, second]) do
    ctx
    |> mes("[Boonthom]")
    |> mes("Lost the")
    |> mes("holy threads")
    |> mes("somehow, did you?")
    |> mes("With the items you")
    |> mes("have, I'll simply")
    |> mes("make more of them.")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Ooooohmmmmm...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Hmmmmmm...")
    |> mes("Hmmmmmmmmm.")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Pffff pffff...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Here you go.")
    |> mes("Please take these holy threads.")
    |> mes("With this, you will be able to enter the ruins with less worry.")
    |> delitem(first, 2)
    |> delitem(second, 2)
    |> delitem(@yggdrasil_leaf, 1)
    |> delitem(@holy_water, 2)
    |> give_item(@strong_holy_thread, 1)
    |> close()
  end

  defp protected(ctx, 11) do
    ctx
    |> mes("[Boonthom]")
    |> mes("Those threads")
    |> mes("will protect you")
    |> mes("from the spiritual")
    |> mes("dangers, but it's up")
    |> mes("to you to defend yourself")
    |> mes("from monster attacks, okay?")
    |> close()
  end

  defp protected(ctx, _stage) do
    ctx
    |> mes("[Boonthom]")
    |> mes("Best of luck on your")
    |> mes("expeditions, brave")
    |> mes("adventurer~")
    |> close()
  end

  defp strong_reminder(ctx, stage, items) do
    ctx =
      ctx
      |> mes("[Boonthom]")
      |> mes("Hmm...?")
      |> mes("Didn't I tell you")
      |> mes("what I need to make")
      |> mes("a more powerful")
      |> mes("holy thread?")
      |> next()
      |> mes("[Boonthom]")
      |> mes("^3366992 Holy Water^000000,")
      |> mes("^3366991 Yggdrasil Leaf^000000,")
      |> strong_items(items)

    if stage == 10 do
      ctx
      |> next()
      |> mes("[Boonthom]")
      |> mes("Return to me")
      |> mes("with those items")
      |> mes("and I will craft")
      |> mes("more powerful holy")
      |> mes("threads for you.")
      |> close()
    else
      close(ctx)
    end
  end

  defp strong_items(ctx, [first, second]) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("^3366992 ", Rathena.getitemname(first)), "^000000 and"))
    |> mes(Rathena.concat(Rathena.concat("^3366992 ", Rathena.getitemname(second)), "^000000."))
  end

  defp letter(ctx) do
    ctx =
      ctx
      |> mes("[Boonthom]")
      |> mes("Huh...!")
      |> mes("You must have seen something.")
      |> mes("I can tell by the gloomy look on your face, and the shadow looming over your soul.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I found")
    |> mes("this old letter")
    |> mes("in the ruins.")
    |> next()
    |> mes("[Old Letter]")
    |> mes(
      "^333333Dear, Boonthom...I was a fool...There is Sa-mhing Tig'...One who ....my remains... Please take...to Boonthom..."
    )
    |> next()
    |> mes("[Boonthom]")
    |> mes("I see...")
    |> mes("Oh, my dear")
    |> mes("old friend...")
    |> next()
    |> mes("[Boonthom]")
    |> mes("Thank you for your trouble.")
    |> mes("My friend left that box for me.")
    |> mes("But I guess he would wish to give that box to the person who found his remains.")
    |> next()
    |> mes("[Boonthom]")
    |> mes(
      "If you wish to explore the building again, but you don't have any holy thread, feel free to ask me at anytime."
    )
    |> set_char_var(:ayodunquest, 13)
    |> completequest(12039)
    |> close()
  end
end
