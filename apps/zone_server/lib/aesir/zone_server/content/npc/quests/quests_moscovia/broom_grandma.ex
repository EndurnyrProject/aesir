defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.BroomGrandma do
  @moduledoc """
  A Payon broom maker whose brooms were stolen by ghosts.

  ## Behavior

  - At stage 36 she tells of the stolen brooms and advances the quest to stage 37.
  - Until stage 41 she points to the ghost tree inside the Payon dungeon.
  - At stage 46 she lets the player keep the recovered broom.

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
        map: "payon",
        x: 65,
        y: 119,
        dir: 0,
        sprite: 78,
        name: "Broom Grandma",
        scope: :shared,
        unique_name: "Broom Grandma#rus44"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @son_failed "My son went to their place to get back the brooms, but he failed since the ghosts tricked him."

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :rhea_rus_main, 0) do
      36 -> brooms_stolen(ctx)
      stage when stage > 36 and stage < 41 -> ghost_tree_hint(ctx)
      46 -> keep_broom(ctx)
      _ -> greet(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet(ctx) do
    ctx
    |> mes("[Broom Grandma]")
    |> mes("A broom from Payon is the best!")
    |> next()
    |> mes("[Broom Grandma]")
    |> mes("It is so good that even ghosts want only a Payon broom.")
    |> close()
  end

  defp brooms_stolen(ctx) do
    ctx =
      ctx
      |> mes("[Broom Grandma]")
      |> mes("A broom from Payon is best!")
      |> next()
      |> mes("[Broom Grandma]")
      |> mes("It is so good that even ghosts want only a Payon broom.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I want to buy a broom.")
    |> next()
    |> mes("[Broom Grandma]")
    |> mes("Oh, you are a guest. Yes, you need a broom?")
    |> next()
    |> mes("[Broom Grandma]")
    |> mes(
      "But, I have no broom. Ghosts stole all my newly made brooms. I was pleased because they were nice even for ghosts. But..."
    )
    |> next()
    |> mes("[Broom Grandma]")
    |> mes(@son_failed)
    |> next()
    |> mes("[Broom Grandma]")
    |> mes("Ah.. What should I do...")
    |> set_char_var(:rhea_rus_main, 37)
    |> close()
  end

  defp ghost_tree_hint(ctx) do
    ctx
    |> mes("[Broom Grandma]")
    |> mes(
      "There are ghosts inside the dungeon of Payon. There is a tree there where the ghosts is hiding."
    )
    |> next()
    |> mes("[Broom Grandma]")
    |> mes(@son_failed)
    |> next()
    |> mes("[Broom Grandma]")
    |> mes("Ah.. What should I do...")
    |> close()
  end

  defp keep_broom(ctx) do
    ctx
    |> mes("[Broom Grandma]")
    |> mes("Ah, you have taken them back. You are a great adventurer.")
    |> next()
    |> mes("[Broom Grandma]")
    |> mes("You can have that broom. I believe it is its destiny.")
    |> close()
  end
end
