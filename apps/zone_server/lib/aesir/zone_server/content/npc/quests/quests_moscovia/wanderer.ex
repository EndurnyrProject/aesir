defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Wanderer do
  @moduledoc """
  A wanderer helps find Igor.

  ## Behavior

  - Provides clues during the search for Lusalka's lover.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 228,
        y: 279,
        dir: 3,
        sprite: 968,
        name: "Wanderer",
        scope: :shared,
        unique_name: "Wanderer#rus24"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    main = get_char_var(ctx, :rhea_rus_main, 0)

    cond do
      main < 8 ->
        greeting(ctx)

      main == 8 ->
        quest_dialogue(ctx, get_char_var(ctx, :rhea_rus_hair, 0))

      true ->
        later_greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp quest_dialogue(ctx, hair) do
    cond do
      hair < 3 ->
        greeting(ctx)

      hair == 3 ->
        if getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 do
          missing_shoes(ctx)
        else
          find_igor(ctx)
        end

      hair > 3 and hair < 7 ->
        clue(ctx)

      true ->
        later_greeting(ctx)
    end
  end

  defp greeting(ctx) do
    ctx
    |> mes("[A Wanderer from a strange land]")
    |> mes(
      "Hey, there are so many adventurers around here. I can see why this is the capital of the Rune-Midgarts Kingdom!"
    )
    |> next()
    |> mes("[A Wanderer from a strange land]")
    |> mes(
      "In your free time, come to see me! The weather here is even more favorable than our the best summer back home."
    )
    |> close()
  end

  defp missing_shoes(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...Hmm, did I forget to wear something...?")
    |> close()
  end

  defp find_igor(ctx) do
    ctx =
      ctx
      |> mes("[A Wanderer from a strange land]")
      |> mes(
        "Hey, there are so many adventurers around here. I can see why this is the capital of the Rune-Midgarts Kingdom!"
      )
      |> next()
      |> mes("[A Wanderer from a strange land]")
      |> mes(
        "In your free time, come to see me! The weather here is even more favorable than our the best summer back home."
      )
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Back home?")
      |> mes("Excuse me for asking, but are you from Moscovia?")
      |> next()
      |> mes("[A Wanderer from a strange land]")
      |> mes("Ho, how did you know that?")
      |> mes("Have you been there before?")
      |> next()

    {ctx, name} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ah, yes. I have been there...")
      |> mes("By the way, the important thing is.. are you.....")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", name)

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ah, yes. I have been there...")

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat(
            "By the way, the important thing is.. are you..... ",
            get_local(ctx, :"input$", "")
          ),
          "?"
        )
      )
      |> next()

    if get_local(ctx, :"input$", "") == "Igor" do
      found_igor(ctx)
    else
      ctx
      |> mes("[A Wanderer from a strange land]")
      |> mes("Hmm, no.")
      |> mes("I have never heard that name.")
      |> close()
    end
  end

  defp found_igor(ctx) do
    ctx =
      ctx
      |> mes("[A Wanderer from a strange land]")
      |> mes("Hmm, no. But, that name is familiar.")
      |> next()
      |> mes("[A Wanderer from a strange land]")
      |> mes("Ah, oh yes! How could I forget?")
      |> emotion(:aha)
      |> next()
      |> mes("[A Wanderer from a strange land]")
      |> mes(
        "We came here from Moscovia together. He called himself Igg. I came here with him but parted with him quite a while ago. He was sad because he couldn't forget about his lost lover."
      )
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Ah, yes that must be Igor.")
    |> mes("I am looking for him!")
    |> mes("Do you know where he is now?")
    |> next()
    |> mes("[A Wanderer from a strange land]")
    |> mes("Hmm, I don't know")
    |> mes("exactly where he is.")
    |> mes("Though, he did tell")
    |> mes("me that he wanted")
    |> mes("to travel to a desert.")
    |> set_char_var(:rhea_rus_hair, 4)
    |> close()
  end

  defp clue(ctx) do
    ctx
    |> mes("[A Wanderer from a strange land]")
    |> mes(
      "He called himself Igg. I came here with him but parted with him quite a while ago. He was sad because he couldn't forget about his lost lover."
    )
    |> next()
    |> mes("[A Wanderer from a strange land]")
    |> mes("Hmm, I don't know")
    |> mes("exactly where he is.")
    |> mes("Though, he did tell")
    |> mes("me that he wanted")
    |> mes("to travel to a desert.")
    |> close()
  end

  defp later_greeting(ctx) do
    ctx
    |> mes("[A Wanderer from a strange land]")
    |> mes("Is there anywhere I should go? Where have you been with him?")
    |> next()
    |> mes("[A Wanderer from a strange land]")
    |> mes("Let me know somewhere.")
    |> close()
  end
end
