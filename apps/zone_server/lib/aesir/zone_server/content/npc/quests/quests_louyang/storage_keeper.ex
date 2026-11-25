defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.StorageKeeper do
  @moduledoc """
  Oversees the storage room during the doctor's errand.

  ## Behavior

  - Asks the visitor to retrieve a randomly selected document or find medicine themselves.
  - Reminds the visitor of the requested document and exchanges it for medicine.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in02",
        x: 201,
        y: 166,
        dir: 4,
        sprite: 819,
        name: "Storage Keeper",
        scope: :shared,
        unique_name: "Storage Keeper#lou"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("^3355FF * Wait a moment!! *")
      |> mes(
        "Currently you're over weight, so you cannot receive more items into your inventory. Please store some of your items into Kafra Storage and try again.^000000"
      )
      |> close()
    else
      converse(ctx, get_char_var(ctx, :ch_par, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp converse(ctx, progress) when progress < 3 do
    ctx
    |> mes("[Jiang Xiayou]")
    |> mes("^666666*Yawn...*^000000")
    |> mes("This is boring...")
    |> mes(
      "So boring, it's ridiculous. I don't wanna waste any more time here, I've got important things to do..."
    )
    |> close()
  end

  defp converse(ctx, 3) do
    {ctx, choice} =
      ctx
      |> mes("[Jiang Xiayou]")
      |> mes("Huh?")
      |> mes("What, what are you doing here?")
      |> mes("If you don't need anything, you better get a move on.")
      |> next()
      |> select(["Sorry about that.", "It's hot, isn't it?", "I'm on an errand for the doctor."])

    case choice do
      1 ->
        ctx
        |> mes("[Jiang Xiayou]")
        |> mes("That's right!")
        |> mes(
          "You don't mess with a person in this hot weather! Now, go away. Can't you see I'm busy!"
        )
        |> close()

      2 ->
        ctx
        |> mes("[Jiang Xiayou]")
        |> mes("You don't have to")
        |> mes("ask me that. I can feel")
        |> mes("it for myself! Now, I got")
        |> mes("a bunch of things to take")
        |> mes("care of, so quit bugging me.")
        |> mes("Damn, it's hot!")
        |> close()

      3 ->
        request_help(ctx)

      _ ->
        ctx
    end
  end

  defp converse(ctx, 4) do
    ctx
    |> mes("[Jiang Xiayou]")
    |> mes("Hah...")
    |> mes(
      "Sorry pal, you'll have to find the medicines on your own. A man's life is at stake, so I guess you oughta get a move on."
    )
    |> close()
  end

  defp converse(ctx, progress) when progress < 9 do
    ctx
    |> mes("[Jiang Xiayou]")
    |> mes("Huh?")
    |> mes("Haven't you gone")
    |> mes("to City Hall yet?")
    |> mes("Whaaaat a lazy ass.")
    |> next()
    |> mes("[Jiang Xiayou]")
    |> mes(
      "Shouldn't you hurry to get that medicine to the doc? We're talking a man's life at stake, that mean anything to you?"
    )
    |> document_reminder(progress)
  end

  defp converse(ctx, 9) do
    ctx
    |> mes("[Jiang Xiayou]")
    |> mes("Hmm...")
    |> mes("You're lucky.")
    |> mes("Alright, go ahead.")
    |> mes("Still, things have")
    |> mes("become complicated...")
    |> close()
  end

  defp converse(ctx, 10), do: idle(ctx)

  defp converse(ctx, progress) when progress < 15 do
    ctx
    |> mes("[Jiang Xiayou]")
    |> mes("Huh?")
    |> mes("Haven't you gone to City Hall yet? Whaaaaat a lazy ass.")
    |> next()
    |> mes("[Jiang Xiayou]")
    |> mes(
      "If I were you, I'd hurry so I could get that medicine to the doc. A man's life is at stake here, that's gotta mean something to you!"
    )
    |> document_reminder(progress)
  end

  defp converse(ctx, 15) do
    {ctx, _} =
      ctx
      |> mes("[Jiang Xiayou]")
      |> mes("You finally brought it! Haha,")
      |> mes("I just got everything you need, too. Let me see...")
      |> mes("Yup, this is it!")
      |> mes("Good, good...")
      |> next()
      |> mes("^3355FF*Rummage rummage*")
      |> mes("......^000000")
      |> next()
      |> select(["Excuse me."])

    ctx
    |> mes("[Jiang Xiayou]")
    |> mes("Huh?")
    |> mes("Ah....")
    |> mes("Haha...")
    |> mes("Sorry about")
    |> mes("that. Hahaha~")
    |> next()
    |> mes("[Jiang Xiayou]")
    |> mes("Ah! Here you go. Even if it was kind of annoying to do, I guess")
    |> mes("we gotta help each other, right? Alright then, I'll see ya around.")
    |> set_char_var(:ch_par, 16)
    |> changequest(11055, 11056)
    |> give_item(7252, 1)
    |> close()
  end

  defp converse(ctx, _progress), do: idle(ctx)

  defp request_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jiang Xiayou]")
      |> mes("Oh yeah?")
      |> mes("Well, why didn't you")
      |> mes("say so? Let's see.")
      |> mes("Hmmm...")
      |> next()
      |> emotion(:surprise)
      |> next()
      |> mes("[Jiang Xiayou]")
      |> mes("Actually, could you help me")
      |> mes(
        "out first? Don't worry, it's not so hard but it's pretty important for me. Once you help me out, I'll"
      )
      |> mes("get you what you need.")
      |> next()
      |> select(["Um, what is it?", "Sorry, I'm busy."])

    if choice == 1 do
      assign_document(ctx)
    else
      ctx
      |> mes("[Jiang Xiayou]")
      |> mes("Bah~!")
      |> mes("Forget it, then!")
      |> next()
      |> mes("[Jiang Xiayou]")
      |> mes(
        "The medicines you're looking for might be around here, so look around. If it weren't for the doctor, I wouldn't even let you hang around, you know that?"
      )
      |> emotion(:hng)
      |> set_char_var(:ch_par, 4)
      |> changequest(11045, 11050)
      |> close()
    end
  end

  defp assign_document(ctx) do
    ctx =
      ctx
      |> mes("[Jiang Xiayou]")
      |> mes("Cool, thanks. I have to go get")
      |> mes("some official documents from")
      |> mes(
        "City Hall, but I can't leave this storage area since no one can take over my shift."
      )
      |> next()
      |> mes("[Jiang Xiayou]")
      |> mes("So I want you to go get the documents from City Hall for me.")
      |> mes("I don't think it'll take much of your time.")
      |> next()
      |> mes("[Jiang Xiayou]")
      |> mes("Just go East from here")
      |> mes(
        "and look for the building that looks sort of like it was made in gauge form. That's City Hall."
      )
      |> next()
      |> mes("[Jiang Xiayou]")
      |> mes(
        "I don't get why the government spent so much money making that building, but anyway, I hope you can do that for me."
      )
      |> next()
      |> mes("[Jiang Xiayou]")
      |> mes("Oh, I almost forgot.")
      |> mes("You have to ask for a specific type of document, so let me tell you right now.")
      |> next()
      |> mes("[Jiang Xiayou]")
      |> mes("This is important,")
      |> mes("So don't forget this.")
      |> set_local(:paper_j, Enum.random(10..13))

    ctx
    |> assign_selected_document(get_local(ctx, :paper_j, 0))
    |> next()
    |> mes("[Jiang Xiayou]")
    |> mes("If you don't specify the")
    |> mes("documents you need, they won't give you anything. So be careful and don't forget!")
    |> close()
  end

  defp assign_selected_document(ctx, 10) do
    ctx
    |> mes(
      "When the guy asks what you need, you tell him: '^ff0000Residence Transfer Application^000000.' Just like that."
    )
    |> set_char_var(:ch_par, 5)
    |> changequest(11045, 11046)
  end

  defp assign_selected_document(ctx, 11) do
    ctx
    |> mes(
      "When the guy asks what you need, you tell him: '^ff0000Summer SAT Class Application^000000.' Got it?"
    )
    |> set_char_var(:ch_par, 6)
    |> changequest(11045, 11047)
  end

  defp assign_selected_document(ctx, 12) do
    ctx
    |> mes(
      "When the guy asks what you need, you tell him: '^ff0000Sandy Dust Phenomenon Report^000000.' Easy, right?"
    )
    |> set_char_var(:ch_par, 7)
    |> changequest(11045, 11048)
  end

  defp assign_selected_document(ctx, 13) do
    ctx
    |> mes(
      "When the guy asks what you need, you tell him: '^ff0000Communication Proposal^000000.' Just like that?"
    )
    |> set_char_var(:ch_par, 8)
    |> changequest(11045, 11049)
  end

  defp document_reminder(ctx, progress) do
    ctx =
      ctx
      |> next()
      |> mes("[Jiang Xiayou]")
      |> mes("I guess you're")
      |> mes("the forgetful type...")
      |> mes("When the guy asks what")
      |> mes("you need, you tell him:")

    ctx
    |> remind_document(progress)
    |> next()
    |> mes("[Jiang Xiayou]")
    |> mes("Just like that.")
    |> mes("Now, go to it, tiger.")
    |> close()
  end

  defp remind_document(ctx, progress) when progress in [5, 11],
    do: mes(ctx, "'^ff0000Residence Transfer Application^000000.'")

  defp remind_document(ctx, progress) when progress in [6, 12],
    do: mes(ctx, "'^ff0000Summer SAT Class Application^000000.'")

  defp remind_document(ctx, 7), do: mes(ctx, "'^ff0000Sandy Dust Phenomenon Report^000000'.")
  defp remind_document(ctx, 8), do: mes(ctx, "^ff0000Communication Proposal^000000.'")
  defp remind_document(ctx, 13), do: mes(ctx, "'^ff0000Sandy Dust Phenomenon Report^000000.'")
  defp remind_document(ctx, 14), do: mes(ctx, "'^ff0000Communication Proposal^000000.'")
  defp remind_document(ctx, _progress), do: ctx

  defp idle(ctx) do
    ctx
    |> mes("[Jiang Xiayou]")
    |> mes("^666666*Yawn~*^000000 I really hope the")
    |> mes(
      "weather gets better. Man, now why did I have to think about the heat? Now I'm all depressed..."
    )
    |> next()
    |> mes("[Jiang Xiayou]")
    |> mes("Huh. I guess I should")
    |> mes("take care of these things")
    |> mes("as soon as I can...")
    |> close()
  end
end
