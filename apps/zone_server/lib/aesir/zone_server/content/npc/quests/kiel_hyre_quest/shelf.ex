defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Shelf do
  @moduledoc """
  The mansion shelf holds a portrait of Allysia in a locked box.

  ## Behavior

  - Checks inventory capacity before allowing investigation of the shelf.
  - Awards the portrait from the first box during the relevant quest stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_rossi",
        x: 92,
        y: 40,
        dir: 0,
        sprite: 111,
        name: "Shelf",
        scope: :shared,
        unique_name: "Shelf#khr"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7500, 1}]) == 0 ->
        ctx
        |> mes("^3355FFJust a second...")
        |> mes("You're carrying too")
        |> mes("many items with you")
        |> mes("right now, so you'll")
        |> mes("need to free up more")
        |> mes("Inventory space first...^000000")
        |> close()

      get_char_var(ctx, :KielHyreQuest, 0) < 58 ->
        ctx
        |> mes("^3355FFThere's nothing here")
        |> mes("of importance to you.^000000")
        |> close()

      get_char_var(ctx, :KielHyreQuest, 0) < 60 ->
        inspect_shelf(ctx)

      true ->
        ctx
        |> mes("^3355FFYou've found a woman's")
        |> mes("portrait in one of the")
        |> mes("boxes on this shelf.")
        |> mes("This box is now empty.^000000")
        |> close()
    end
  end

  defp inspect_shelf(ctx) do
    if count_item(ctx, 7500) < 1 do
      {ctx, choice} =
        ctx
        |> mes("^3355FFThere are locked")
        |> mes("boxes on these bookshelves.")
        |> mes("Perhaps if you used this")
        |> mes("mansions's Master Key, you")
        |> mes("might be able to open them.^000000")
        |> next()
        |> select(["Use Key", "Pass"])

      case choice do
        1 -> choose_box(ctx)
        2 -> empty_box(ctx)
        _ -> ctx
      end
    else
      ctx
      |> mes("^3355FFYou've found a woman's")
      |> mes("portrait in one of the")
      |> mes("boxes on this shelf.^000000")
      |> close()
    end
  end

  defp choose_box(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFWhich box do you")
      |> mes("want to try to open?^000000")
      |> next()
      |> select(["First Box", "Second Box"])

    case choice do
      1 -> take_portrait(ctx)
      2 -> empty_box(ctx)
      _ -> ctx
    end
  end

  defp take_portrait(ctx) do
    ctx
    |> mes("^3355FFYou use the Master Key to")
    |> mes("unlock the box, and obtain")
    |> mes("a portait of a woman that")
    |> mes("looks just like Kiel Hyre's")
    |> mes("assistant, Allysia.^000000")
    |> next()
    |> cutin("kh_ellisia_port", 2)
    |> mes("^3355FFThe message, ''To my love,")
    |> mes("Allysia. From James.'' is")
    |> mes("written on the back.^000000")
    |> give_item(7500, 1)
    |> close()
    |> cutin("", 255)
  end

  defp empty_box(ctx) do
    ctx |> mes("^3355FFThis box is empty.^000000") |> close()
  end
end
