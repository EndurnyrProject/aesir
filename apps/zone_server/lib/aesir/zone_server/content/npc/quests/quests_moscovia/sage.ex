defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Sage do
  @moduledoc """
  A sage tells travelers about the mysterious stone.

  ## Behavior

  - Showing him a Poring Card starts the quest and unlocks his warning.

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
        map: "mosk_fild02",
        x: 198,
        y: 252,
        dir: 3,
        sprite: 755,
        name: "Sage",
        scope: :shared,
        unique_name: "Sage#rus01"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(get_char_var(ctx, :rhea_rus_main, 0)) do
      repeat_warning(ctx)
    else
      greet(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sage]")
      |> mes("Ah, a foreigner,")
      |> mes("you're not from")
      |> mes("around here are you?")
      |> mes("It's nice to meet you!")
      |> next()
      |> mes("[Sage]")
      |> mes(
        "I've heard stories of the many adventurers from your lands. But, I haven't been able to talk with them much because they were always busy."
      )
      |> next()
      |> select(["Sorry, but I'm busy.....", "Ok, let's talk."])

    if choice == 1 do
      ctx
      |> mes("[Sage]")
      |> mes("Ah, you are...")
      |> mes("I just wanted to hear about news from other lands...")
      |> next()
      |> mes("[Sage]")
      |> mes("Sorry to bother you. You have a good trip.")
      |> close()
    else
      show_card(ctx)
    end
  end

  defp show_card(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Sage]")
      |> mes(
        "I've heard that interesting creatures inhabit your lands. Could you please tell me about at least one of them?"
      )
      |> next()
      |> select(["Show him a Poring Card"])

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("This is a card of one of the monsters that inhabit the Midgard continent.")
      |> next()

    if Rathena.truthy?(count_item(ctx, 4001)) do
      tell_story(ctx)
    else
      missing_card(ctx)
    end
  end

  defp missing_card(ctx) do
    ctx =
      ctx |> mes("[Sage]") |> mes("...?!") |> mes("What are you talking about?") |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I mean, this card.............")
      |> mes("..................Ehhh?")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Ah.. haha.. where is it?!")
    |> mes("W, wait.. I've got one somewhere!")
    |> close()
  end

  defp tell_story(ctx) do
    ctx =
      ctx
      |> mes("[Sage]")
      |> mes("Hooh, it is.. I can't believe this is real.")
      |> mes("Thank you for showing me this.")
      |> next()
      |> mes("[Sage]")
      |> mes("By the way, do you like this place?")
      |> next()
      |> mes("[Sage]")
      |> mes(
        "Now, that winter has passed and summer is coming the weather is great. And I know that winter comes every year, but I always pray that it won't return again."
      )
      |> next()
      |> mes("[Sage]")
      |> mes(
        "After the passing of winter, the summer weather has made the forest dense and the air so warm. My favorite season will always be summer."
      )
      |> next()
      |> mes("[Sage]")
      |> mes(
        "But, don't forget that you should still be careful. Lots of adventurers were lost in the forst in front of us."
      )
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Have any of the adventurers returned?")
    |> next()
    |> mes("[Sage]")
    |> mes(
      "Only one has come back and told me of a mysterious stone, where the road splits into three, that curses those who touch it so I've been keeping away from it."
    )
    |> next()
    |> mes("[Sage]")
    |> mes(
      "But, don't worry about me. I know my way around here and am not afraid of monsters, haha."
    )
    |> set_char_var(:rhea_rus_main, 1)
    |> close()
  end

  defp repeat_warning(ctx) do
    ctx
    |> mes("[Sage]")
    |> mes(
      "Now, that winter has passed and summer is coming the weather is great. And I know that winter comes every year, but I always pray that it won't return again."
    )
    |> next()
    |> mes("[Sage]")
    |> mes(
      "After the passing of winter, the summer weather has made the forest dense and the air so warm. My favorite season will always be summer."
    )
    |> next()
    |> mes("[Sage]")
    |> mes(
      "But, don't forget that you should still be careful. Lots of adventurers were lost in the forst in front of us."
    )
    |> next()
    |> mes("[Sage]")
    |> mes(
      "Only one has come back and told me of a mysterious stone, where the road splits into three, that curses those who touch it so I've been keeping away from it."
    )
    |> next()
    |> mes("[Sage]")
    |> mes(
      "Me? Haha, don't worry about me. I know my way around here and am not afraid of monsters, haha."
    )
    |> close()
  end
end
