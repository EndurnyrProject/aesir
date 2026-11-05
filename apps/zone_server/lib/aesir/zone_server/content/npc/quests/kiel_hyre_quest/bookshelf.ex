defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Bookshelf do
  @moduledoc """
  A concealed safe holds the Grey Box left for Elly.

  ## Behavior

  - Reveals the safe through successive book and steel-surface inspections.
  - Accepts the Cottage Key followed by the Green Keycard, consuming both to award the Grey Box.

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
        map: "kh_vila",
        x: 181,
        y: 138,
        dir: 0,
        sprite: 111,
        name: "Bookshelf",
        scope: :shared,
        unique_name: "Bookshelf#khp1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if (count_item(ctx, 7491) < 1 and count_item(ctx, 7329) >= 1) or count_item(ctx, 7516) >= 1 do
      examine_book(ctx)
    else
      ctx
      |> mes("^3355FFYou've found a")
      |> mes("bookshelf that's")
      |> mes("crammed with books.^000000")
      |> close()
    end
  end

  defp examine_book(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFOne of the books on")
      |> mes("this crammed bookshelf")
      |> mes("is labeled with the note,")
      |> mes("''To Elly.'' It must have been")
      |> mes("left behind by her grandfather.^000000")
      |> next()
      |> select(["Examine Book", "Ignore"])

    case choice do
      1 -> examine_surface(ctx)
      2 -> ignore_book(ctx)
      _ -> ctx
    end
  end

  defp examine_surface(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou skim through the")
      |> mes("book's pages, and don't")
      |> mes("find anything particularly")
      |> mes("interesting. However, you")
      |> mes("notice a steel surface behind the")
      |> mes("shelf as you place the book back.^000000")
      |> next()
      |> select(["Examine the steel surface", "Ignore"])

    case choice do
      1 -> examine_safe(ctx)
      2 -> replace_books(ctx)
      _ -> ctx
    end
  end

  defp examine_safe(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou remove more of the")
      |> mes("shelf's books to reveal")
      |> mes("that the steel surface is")
      |> mes("part of a safe hidden behind")
      |> mes("the bookshelf. There are two")
      |> mes("keyholes on the steel safe.^000000")
      |> next()
      |> select(["Try all your keys", "Cancel"])

    case choice do
      1 -> try_keys(ctx)
      2 -> seek_keys(ctx)
      _ -> ctx
    end
  end

  defp try_keys(ctx) do
    ctx =
      ctx
      |> mes("^3355FFWhich key will")
      |> mes("you insert into")
      |> mes("the first keyhole?^000000")
      |> next()

    cond do
      count_item(ctx, 7329) >= 1 -> try_bronze_key(ctx)
      count_item(ctx, 7516) >= 1 -> choose_first_key(ctx)
      true -> locked_safe(ctx)
    end
  end

  defp try_bronze_key(ctx) do
    {ctx, _} = select(ctx, ["Old Bronze Key", "Cottage Key"])

    {ctx, _} =
      ctx
      |> mes("^3355FFWhich key will")
      |> mes("you insert into")
      |> mes("the second keyhole?^000000")
      |> next()
      |> select(["Old Bronze Key", "Cottage Key"])

    locked_safe(ctx)
  end

  defp choose_first_key(ctx) do
    {ctx, key} = select(ctx, ["Green Keycard", "Cottage Key"])

    case key do
      1 -> ctx |> set_local(:KHFirstKeyhole, 1) |> choose_second_key()
      2 -> ctx |> set_local(:KHFirstKeyhole, 2) |> choose_second_key()
      _ -> ctx
    end
  end

  defp choose_second_key(ctx) do
    {ctx, key} =
      ctx
      |> mes("^3355FFWhich key will")
      |> mes("you insert into")
      |> mes("the second keyhole?^000000")
      |> next()
      |> select(["Green Keycard", "Cottage Key"])

    case key do
      1 -> ctx |> set_local(:KHSecondKeyhole, 1) |> unlock_safe()
      2 -> ctx |> set_local(:KHSecondKeyhole, 2) |> unlock_safe()
      _ -> ctx
    end
  end

  defp unlock_safe(ctx) do
    if get_local(ctx, :KHFirstKeyhole, 0) == 2 and get_local(ctx, :KHSecondKeyhole, 0) == 1 do
      ctx
      |> mes("^3355FFThe safe opens with")
      |> mes("a click, and you see")
      |> mes("a Grey Box inside.")
      |> mes("You take the Grey Box")
      |> mes("with you, hoping that it")
      |> mes("will come in handy later.^000000")
      |> delitem(7489, 1)
      |> delitem(7516, 1)
      |> give_item(7491, 1)
      |> close()
    else
      locked_safe(ctx)
    end
  end

  defp locked_safe(ctx), do: ctx |> mes("^3355FFThe safe won't open.^000000") |> close()

  defp seek_keys(ctx) do
    ctx
    |> mes("^3355FFIt's probably a better")
    |> mes("idea to investigate the")
    |> mes("cottage for the keys that")
    |> mes("will open up this safe...^000000")
    |> close()
  end

  defp replace_books(ctx) do
    ctx
    |> mes("^3355FFYou place the books")
    |> mes("back on the bookshelf.^000000")
    |> close()
  end

  defp ignore_book(ctx) do
    ctx
    |> mes("^3355FFYou can probably")
    |> mes("find better clues")
    |> mes("somewhere else")
    |> mes("around here.^000000")
    |> close()
  end
end
