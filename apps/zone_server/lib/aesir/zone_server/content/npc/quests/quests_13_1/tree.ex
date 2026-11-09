defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Tree do
  @moduledoc """
  A tree west of the expedition camp that yields the branches Diego needs for his repairs.

  ## Behavior

  - Refuses a player who carries too much to receive an item.
  - On `ep13_newbs` step 6, one time in three a branch is found, and one time in three of those
    it is an Ordinary Branch instead of a decayed one.
  - Says nothing on every other step.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_fild02",
        x: 348,
        y: 76,
        dir: 0,
        sprite: 111,
        name: "Tree",
        scope: :shared,
        unique_name: "ep13tree"
      },
      %{
        map: "spl_fild02",
        x: 232,
        y: 145,
        dir: 0,
        sprite: 111,
        name: "Tree",
        scope: :shared,
        unique_name: "Tree#ep13bs2"
      },
      %{
        map: "spl_fild02",
        x: 380,
        y: 197,
        dir: 0,
        sprite: 111,
        name: "Tree",
        scope: :shared,
        unique_name: "Tree#ep13bs3"
      },
      %{
        map: "spl_fild02",
        x: 304,
        y: 151,
        dir: 0,
        sprite: 111,
        name: "Tree",
        scope: :shared,
        unique_name: "Tree#ep13bs4"
      },
      %{
        map: "spl_fild02",
        x: 183,
        y: 235,
        dir: 0,
        sprite: 111,
        name: "Tree",
        scope: :shared,
        unique_name: "Tree#ep13bs5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @ordinary_branch 6042

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 -> overburdened(ctx)
      get_char_var(ctx, :ep13_newbs, 0) == 6 -> search_tree(ctx)
      true -> ctx
    end
  end

  defp overburdened(ctx) do
    ctx
    |> mes("- Wait a minute !! -")
    |> mes("- Currently you're carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please try again -")
    |> mes("- after you lose some weight. -")
    |> close()
  end

  defp search_tree(ctx) do
    if Enum.random(1..3) == 3 do
      ctx = ctx |> mes("- rustling sound -") |> mes("- You find a branch -") |> next()

      if Enum.random(1..3) == 2 do
        usable_branch(ctx)
      else
        decayed_branch(ctx)
      end
    else
      ctx
      |> mes("- rustling sound -")
      |> mes("- There's nothing useful. -")
      |> close()
    end
  end

  defp usable_branch(ctx) do
    ctx
    |> mes("- Break! -")
    |> mes("- Bomb, bomb~~ -")
    |> mes("- You got the branch. -")
    |> give_item(@ordinary_branch, 1)
    |> close()
  end

  defp decayed_branch(ctx) do
    ctx
    |> mes("- Break! -")
    |> mes("- Bomb, bomb~~ -")
    |> mes("- This branch is decayed. -")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("This is useless.")
    |> mes("I need to find others...")
    |> close()
  end
end
