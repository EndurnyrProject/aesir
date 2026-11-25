defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.OccultAppleTree do
  @moduledoc """
  An occult apple tree challenges adventurers to retrieve apples.

  ## Behavior

  - Advances the cave trial when the apples fall.

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
        map: "mosk_que",
        x: 56,
        y: 202,
        dir: 0,
        sprite: 111,
        name: "Occult Apple Tree",
        scope: :shared,
        unique_name: "Occult Apple Tree#rus29"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rhea_rus_main, 0) != 8 or
          get_char_var(ctx, :rhea_rus_quiz, 0) != 2 ->
        emotion(ctx, :question, playerattached(ctx))

      getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("...Hmm, did I forget to wear something...?")
        |> close()

      true ->
        shake_tree(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp shake_tree(ctx) do
    ctx =
      ctx
      |> mes("- There are Ripe Apples -")
      |> mes("- growing in clusters. -")
      |> mes("- But they are higher than -")
      |> mes("- you expected them to be -")
      |> next()

    if Enum.random(1..5) == 2 do
      ctx
      |> mes("- You hit the tree firmly, -")
      |> mes("- and the apples fall down! -")
      |> next()
      |> mes("- ^0000ff You get 100 Apples !!^000000 -")
      |> announce(
        "Mazroka : You are truly brave. When you get the cookies and apples, come to see me.",
        1,
        8_900_331
      )
      |> set_char_var(:rhea_rus_quiz, 3)
      |> close()
    else
      ctx =
        ctx
        |> mes("- You hit the tree firmly, -")
        |> mes("- worms fall down! -")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Ahhhhhhhh!!!")

      ctx |> emotion(:huk, playerattached(ctx)) |> close()
    end
  end
end
