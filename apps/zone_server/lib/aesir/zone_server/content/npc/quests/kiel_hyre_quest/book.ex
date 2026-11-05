defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Book do
  @moduledoc """
  The cottage bookshelf conceals a secret passage.

  ## Behavior

  - At the appropriate quest stage, pulling a book has a one-in-ten chance to reveal the passage.

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
        x: 184,
        y: 20,
        dir: 0,
        sprite: 111,
        name: "Book",
        scope: :shared,
        unique_name: "BookKHQ1"
      },
      %{
        map: "kh_vila",
        x: 181,
        y: 20,
        dir: 0,
        sprite: 111,
        name: "Book",
        scope: :shared,
        unique_name: "Book#kh2"
      },
      %{
        map: "kh_vila",
        x: 178,
        y: 20,
        dir: 0,
        sprite: 111,
        name: "Book",
        scope: :shared,
        unique_name: "Book#kh3"
      },
      %{
        map: "kh_vila",
        x: 175,
        y: 19,
        dir: 0,
        sprite: 111,
        name: "Book",
        scope: :shared,
        unique_name: "Book#kh4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :KielHyreQuest, 0) != 26 ->
        ctx
        |> mes("^3355FFThis bookshelf is^000000")
        |> mes("^3355FFcrammed with many^000000")
        |> mes("^3355FFlarge, hardcover books^000000")
        |> close()

      Enum.random(1..10) == 8 ->
        ctx
        |> mes("^3355FFWithout thinking, you")
        |> mes("reach for a book from")
        |> mes("the bookshelf. As you")
        |> mes("pull it towards you, the")
        |> mes("wall slides opens open")
        |> mes("to reveal a secret path.^000000")
        |> set_char_var(:KielHyreQuest, 28)
        |> specialeffect(:readyportal2, :area, "Wall#kh")
        |> close()

      true ->
        ctx
        |> mes("^3355FFThis bookshelf is")
        |> mes("crammed with many")
        |> mes("large, hardcover books.^000000")
        |> close()
    end
  end
end
