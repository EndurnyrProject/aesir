defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.MoroccVillager do
  @moduledoc """
  A Morocc villager helps find Igor.

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
        map: "morocc",
        x: 165,
        y: 82,
        dir: 0,
        sprite: 48,
        name: "Morocc Villager",
        scope: :shared,
        unique_name: "Morocc Villager#rus25"
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
      hair < 4 ->
        greeting(ctx)

      hair == 4 ->
        if getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 do
          missing_shoes(ctx)
        else
          find_igor(ctx)
        end

      hair > 4 and hair < 7 ->
        clue(ctx)

      true ->
        later_greeting(ctx)
    end
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Morocc Villager]")
    |> mes(
      "Huh, more and more adventurers are settling here recently, so it's hard to tell who is a villager or an adventurer."
    )
    |> next()
    |> mes("[Morocc Villager]")
    |> mes("But natives, like me, can tell the difference.")
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
      |> mes("[Morocc Villager]")
      |> mes(
        "Huh, more and more adventurers are settling here recently, so it's hard to tell who is a villager or an adventurer."
      )
      |> next()
      |> mes("[Morocc Villager]")
      |> mes("But natives, like me, can tell the difference.")
      |> next()
      |> mes("[Morocc Villager]")
      |> mes(
        "As I was saying, I like this village. The desert is hot and Kafra staff is even hotter!!! *hack* *cough*!!"
      )
      |> next()
      |> mes("[Morocc Villager]")
      |> mes(
        "Ah, but don't get me wrong! I'm not coughing because of the Kafra Staffers. It's uhh the heat, it's getting to me... ya..."
      )
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("................................")
      |> mes("The hell you talking about..? I'm looking for someone.")
      |> next()
      |> mes("[Morocc Villager]")
      |> mes(
        "I see so many adventurers around here, how can I remember everybody? Got any descriptions of this someone..? Or traits..? anything to help me remember."
      )
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Hmm... I don't know how he looks like but he is from a land called Moscovia.")
    |> next()
    |> mes("[Morocc Villager]")
    |> mes(
      "Ah, are you talking about a guy that's always sad and dresses funny? I figured his accent wasn't from around here..."
    )
    |> next()
    |> mes("[Morocc Villager]")
    |> mes(
      "He was here a coupla days ago but he left to see the Pyramid. I never saw him after that. I said it would be dangerous but he went anyways."
    )
    |> next()
    |> mes("[Morocc Villager]")
    |> mes(
      "Yep that's gotta be who you're looking for. I can see his gloomy face right now... that poor sad man."
    )
    |> set_char_var(:rhea_rus_hair, 5)
    |> close()
  end

  defp clue(ctx) do
    ctx
    |> mes("[Morocc Villager]")
    |> mes(
      "He was here a coupla days ago but he left to see the Pyramid. I never saw him after that. I said it would be dangerous but he went anyways."
    )
    |> next()
    |> mes("[Morocc Villager]")
    |> mes(
      "Yep that's gotta be who you're looking for. I can see his gloomy face right now... that poor sad man."
    )
    |> close()
  end

  defp later_greeting(ctx) do
    ctx
    |> mes("[Morocc Villager]")
    |> mes(
      "Many travellers in the village and I feel fun to see them. Even though I am here, I feel like that I travel all around the world?"
    )
    |> close()
  end
end
