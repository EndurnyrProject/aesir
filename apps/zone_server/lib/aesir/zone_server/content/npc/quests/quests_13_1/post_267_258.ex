defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Post267258 do
  @moduledoc """
  The broken barracks post in the expedition camp that the player repairs with Diego's
  branches and vines.

  ## Behavior

  - Below step 6 the barracks posts are simply broken, and on steps 6 and 7 the player is told
    to fetch the materials first.
  - On step 8 the repair loop runs: attaching a branch or tying with the vines repeats the menu,
    one in five vine attempts fixes the post and offers to knot it, and a perfect knot sets
    `ep13_newbs` to 9 and advances quest 11089 to 11090.
  - Leaving the knot unfastened or cancelling the menu ends the dialog.
  - On any later step the repair is already done.

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
        map: "mid_camp",
        x: 267,
        y: 258,
        dir: 0,
        sprite: 111,
        name: "Post",
        scope: :shared,
        unique_name: "Post#ep13bs2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_newbs, 0) do
      step when step < 6 -> broken(ctx)
      step when step in [6, 7] -> needs_materials(ctx)
      8 -> collapse_warning(ctx)
      _step -> repaired(ctx)
    end
  end

  defp broken(ctx) do
    ctx
    |> mes("- The posts of the -")
    |> mes("- barracks are broken. -")
    |> close()
  end

  defp needs_materials(ctx) do
    ctx
    |> mes("- The posts of the -")
    |> mes("- barracks are broken. -")
    |> mes("- You'd better go out and -")
    |> mes("- find the materials to fix it. -")
    |> close()
  end

  defp collapse_warning(ctx) do
    ctx
    |> mes("- There are broken posts. -")
    |> mes("- Unless they are fixed soon, -")
    |> mes("- the barracks will collapse. -")
    |> next()
    |> repair_menu()
  end

  defp repaired(ctx) do
    ctx
    |> mes("- The post tied by the -")
    |> mes("- vines seems unsteady -")
    |> mes("- but my repair is perfect. -")
    |> close()
  end

  # The reference loops on the repair menu until the post is fixed or the player gives up.
  defp repair_menu(ctx) do
    {ctx, choice} = select(ctx, ["Attach the tree bar.", "Tie it with the vines."])

    case choice do
      1 ->
        ctx
        |> mes("- You attach the tree bar -")
        |> mes("- to the broken post -")
        |> next()
        |> repair_menu()

      2 ->
        tie_with_vines(ctx)

      _cancelled ->
        ctx
    end
  end

  defp tie_with_vines(ctx) do
    if Enum.random(1..5) == 4 do
      knot_it(ctx)
    else
      ctx
      |> mes("- You fix the broken post -")
      |> mes("- with the vines. -")
      |> mes("- It seems that you-")
      |> mes("- need more branches. -")
      |> next()
      |> repair_menu()
    end
  end

  defp knot_it(ctx) do
    {ctx, choice} =
      ctx
      |> mes("- You tie the broken post -")
      |> next()
      |> mes("- It seems that it's fixed -")
      |> next()
      |> mes("[Diego]")
      |> mes("Oh! Now you need to knot it and")
      |> mes("finish it.")
      |> next()
      |> select(["Knot it.", "Leave it."])

    case choice do
      1 -> knot(ctx)
      2 -> leave_it(ctx)
      _cancelled -> ctx
    end
  end

  defp knot(ctx) do
    ctx
    |> mes("- You tie a perfect knot -")
    |> next()
    |> mes("[Diego]")
    |> mes("Ohhh!!!!")
    |> mes("The broken posts are perfectly fixed!")
    |> set_char_var(:ep13_newbs, 9)
    |> changequest(11089, 11090)
    |> close()
  end

  defp leave_it(ctx) do
    ctx
    |> mes("- You decide to leave -")
    |> next()
    |> mes("- The branches slide down. -")
    |> mes("- You failed to fix it. -")
    |> next()
    |> mes("[Diego]")
    |> mes("...")
    |> mes("Why aren't you helping?")
    |> emotion(:cry)
    |> close()
  end
end
