defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.WorriedMother do
  @moduledoc """
  A worried mother seeks her missing daughter.

  ## Behavior

  - Ask the adventurer to find her daughter and explain how to approach Lusalka.

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
        map: "moscovia",
        x: 166,
        y: 145,
        dir: 1,
        sprite: 961,
        name: "Worried Mother",
        scope: :shared,
        unique_name: "Worried Mother#rus19"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rhea_rus_main, 0) < 8 ->
        introduction(ctx) |> close()

      get_char_var(ctx, :rhea_rus_main, 0) == 8 ->
        quest_dialogue(ctx)

      true ->
        forgotten(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp quest_dialogue(ctx) do
    cond do
      get_char_var(ctx, :rhea_rus_hair, 0) < 1 ->
        offer_quest(ctx)

      get_char_var(ctx, :rhea_rus_hair, 0) == 1 ->
        instructions(ctx)

      get_char_var(ctx, :rhea_rus_hair, 0) > 1 and get_char_var(ctx, :rhea_rus_hair, 0) < 9 ->
        reminder(ctx)

      true ->
        forgotten(ctx)
    end
  end

  defp offer_quest(ctx) do
    if getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...Hmm, did I forget to wear something...?")
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes("[Worried Mother]")
        |> mes("Where is she...")
        |> next()
        |> mes("[Worried Mother]")
        |> mes(
          "Have you heard of the bridge who drowned to death just before her wedding and became Lusalka, an aqua nymph?"
        )
        |> next()
        |> mes("[Worried Mother]")
        |> mes(
          "My daughter disappeared some days ago and now i'm really worried. I hope nothing happened to her..."
        )
        |> next()
        |> mes("[Worried Mother]")
        |> mes(
          "Did you go to the marsh in the Moscovia field? Did you see my daughter? I don't care even if she became Lusalka. I just want to know where she is."
        )
        |> next()
        |> select(["Calm her down.", "I will find her."])

      if choice == 1 do
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("She should be ok.")
        |> mes("She will be back soon.")
        |> next()
        |> mes("[Worried Mother]")
        |> mes("Will she? I really hope so.")
        |> close()
      else
        ctx
        |> mes("[Worried Mother]")
        |> mes("Ah, will you?")
        |> next()
        |> mes("[Worried Mother]")
        |> mes(
          "I tried to find her but, I couldn't approach the marsh due to all of the monsters."
        )
        |> next()
        |> mes("[Worried Mother]")
        |> mes("Please, please find my daughter.")
        |> set_char_var(:rhea_rus_hair, 1)
        |> close()
      end
    end
  end

  defp introduction(ctx) do
    ctx
    |> mes("[Worried Mother]")
    |> mes("Where is she...")
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "Have you heard of the bridge who drowned to death just before her wedding and became Lusalka, an aqua nymph?"
    )
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "My daughter disappeared some days ago and now i'm really worried. I hope nothing happened to her..."
    )
  end

  defp instructions(ctx) do
    ctx
    |> mes("[Worried Mother]")
    |> mes("Ah, there are some things that you have to know.")
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "If my daughter has became the water nymph Lusalka you need to listen to what I know about her."
    )
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "Lusalka is a good aqua nymph but is not completely harmless. Her stare will seriously hurt anyone who makes eye contact with her."
    )
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "You must have something to protect yourself from Lusalka. '^0000ffHoly Water^000000' will protect you from Lusalka'a gaze."
    )
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "And Lusalka is nocturnal. You should be able to find her from ^ff00005 pm to 6 am PST^000000."
    )
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "Don't forget. You have to bring '^0000ffHoly Water^000000' with you, and find her from ^ff00005 pm to 6 am PST^000000."
    )
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "I'm not sure where she would be but it has to be somewhere near water. Please, find where my daughter is. I beg of you."
    )
    |> set_char_var(:rhea_rus_hair, 2)
    |> close()
  end

  defp reminder(ctx) do
    ctx
    |> mes("[Worried Mother]")
    |> mes(
      "Lusalka is a good aqua nymph but is not completely harmless. Her stare will seriously hurt anyone who makes eye contact with her."
    )
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "You must have something to protect yourself from Lusalka. '^0000ffHoly Water^000000' will protect you from Lusalka'a gaze."
    )
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "And Lusalka is nocturnal. You should be able to find her from ^ff00005 pm to 6 am PST^000000."
    )
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "Don't forget. You have to bring '^0000ffHoly Water^000000' with you, and find her from ^ff00005 pm to 6 am PST^000000."
    )
    |> next()
    |> mes("[Worried Mother]")
    |> mes(
      "I'm not sure where she would be but it has to be somewhere near water. Please, find where my daughter is. I beg of you."
    )
    |> close()
  end

  defp forgotten(ctx) do
    ctx
    |> mes("[Worried Mother]")
    |> mes("I am able to do nothing recently.")
    |> next()
    |> mes("[Worried Mother]")
    |> mes("It seems that I lost something, but I don't know what it is...")
    |> close()
  end
end
