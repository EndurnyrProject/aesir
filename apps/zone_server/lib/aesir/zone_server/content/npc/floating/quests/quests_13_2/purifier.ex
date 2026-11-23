defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests132.Purifier do
  @moduledoc """
  Purifies a sprout for the Alfheim quest.

  ## Behavior

  - Exchanges a sprout for a flower and advances the quest.
  - Reminds eligible players when they have no sprout.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "splendide",
        x: 160,
        y: 265,
        dir: 3,
        sprite: 844,
        name: "Purifier",
        scope: :shared,
        unique_name: "Purifier#1"
      },
      %{
        map: "splendide",
        x: 262,
        y: 262,
        dir: 3,
        sprite: 844,
        name: "Purifier",
        scope: :shared,
        unique_name: "Purifier#2"
      },
      %{
        map: "splendide",
        x: 262,
        y: 187,
        dir: 3,
        sprite: 844,
        name: "Purifier",
        scope: :shared,
        unique_name: "Purifier#3"
      },
      %{
        map: "splendide",
        x: 164,
        y: 82,
        dir: 3,
        sprite: 844,
        name: "Purifier",
        scope: :shared,
        unique_name: "Purifier#4"
      },
      %{
        map: "splendide",
        x: 171,
        y: 116,
        dir: 3,
        sprite: 844,
        name: "Purifier",
        scope: :shared,
        unique_name: "Purifier#5"
      },
      %{
        map: "splendide",
        x: 134,
        y: 280,
        dir: 3,
        sprite: 844,
        name: "Purifier",
        scope: :shared,
        unique_name: "Purifier#6"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ep13_2_tre1, 0) != 2 ->
        ctx

      count_item(ctx, 7193) > 0 ->
        ctx
        |> mes("- You put the seed in the")
        |> mes("device and watched it")
        |> mes("as Grenouille told you. -")
        |> next()
        |> mes("- Booowoong -")
        |> specialeffect2(:healsp)
        |> next()
        |> mes("- When the lights gone,")
        |> mes("a big flower of Alfheim was lied")
        |> mes("in your hand, instead of the seed. -")
        |> delitem(7193, 1)
        |> set_char_var(:ep13_2_tre1, 3)
        |> give_item(6079, 1)
        |> close()

      true ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Where are the seeds?")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
