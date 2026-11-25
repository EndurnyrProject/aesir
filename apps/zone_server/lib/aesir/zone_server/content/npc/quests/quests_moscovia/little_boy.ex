defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.LittleBoy do
  @moduledoc """
  A little boy shares a clue about Ryubaba in exchange for a treat.

  ## Behavior

  - Quest progress and available sweets determine his dialogue and clue.

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
        x: 223,
        y: 210,
        dir: 3,
        sprite: 962,
        name: "Little Boy",
        scope: :shared,
        unique_name: "Little Boy#rus09"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :rhea_rus_main, 0) == 8 do
      case get_char_var(ctx, :rhea_rus_ring, 0) do
        2 -> ask_about_ryubaba(ctx)
        3 -> clue(ctx)
        _ -> greeting(ctx)
      end
    else
      greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_about_ryubaba(ctx) do
    ctx =
      ctx
      |> mes("[Little Boy]")
      |> mes("Hehe, you have done by her?")
      |> next()
      |> mes("[Little Boy]")
      |> mes(
        "Everyone knows her. She is beautiful. My borther told me that he wanted to marry her."
      )
      |> mes("But her temper makes people hesitate.")
      |> next()
      |> mes("[Little Boy]")
      |> mes(
        "I don't like her cause she doesn't give me candies or cookies. Although she is beautiful, her temper is so bad..."
      )
      |> next()

    if Rathena.truthy?(count_item(ctx, 529)) or Rathena.truthy?(count_item(ctx, 538)) do
      offer_treat(ctx)
    else
      ctx |> mes("[Little Boy]") |> mes("I love candy and cookies most.") |> close()
    end
  end

  defp offer_treat(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Little Boy]")
      |> mes("Ah, do you have candies or cookies?")
      |> next()
      |> select(["Give some", "Don't give"])

    if choice == 2 do
      ctx
      |> mes("[Little Boy]")
      |> mes("Hm! Hmph! Pish! !")
      |> mes("You are the same as Sister Ryubaba!")
      |> close()
    else
      accept_treat(ctx)
    end
  end

  defp accept_treat(ctx) do
    ctx =
      ctx
      |> mes("[Little Boy]")
      |> mes("Wow, really?")
      |> mes("That is very kind of you!")
      |> next()
      |> mes("[Little Boy]")
      |> mes("Ah, I will inform you of something!")
      |> next()
      |> mes("[Little Boy]")

    cond do
      Rathena.truthy?(count_item(ctx, 529)) ->
        ctx |> delitem(529, 1) |> share_clue()

      Rathena.truthy?(count_item(ctx, 538)) ->
        ctx |> delitem(538, 1) |> share_clue()

      true ->
        ctx
        |> mes("Sister Ryubaba likes.. eh?")
        |> mes("Don't you have candies or cookies? Don't you want to give them to me?")
        |> close()
    end
  end

  defp share_clue(ctx) do
    ctx
    |> mes(
      "Sister Ryubaba likes presents! Especially flowers such as roses. She believes that they resemble her."
    )
    |> set_char_var(:rhea_rus_ring, 3)
    |> close()
  end

  defp clue(ctx) do
    ctx
    |> mes("[Little Boy]")
    |> mes(
      "Sister Ryubaba likes presents! Especially flowers such as roses. She believes that they resemble her."
    )
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Little Boy]")
    |> mes("I will be an adventer and will marry the most beautiful bride!")
    |> mes("A bride more beautiful than sister Ryubaba!")
    |> close()
  end
end
