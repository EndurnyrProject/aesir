defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Bookshelf148288 do
  @moduledoc """
  This dusty bookshelf hides a note written by James.

  ## Behavior

  - Checks inventory capacity and gives the missing note during the investigation.

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
        x: 148,
        y: 288,
        dir: 0,
        sprite: 111,
        name: "Bookshelf",
        scope: :shared,
        unique_name: "Bookshelf#khr"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7502, 1}]) == 0 ->
        ctx
        |> mes("^3355FFJust a second...")
        |> mes("You're carrying too")
        |> mes("many items with you")
        |> mes("right now, so you'll")
        |> mes("need to free up more")
        |> mes("Inventory space first...^000000")
        |> close()

      get_char_var(ctx, :KielHyreQuest, 0) >= 58 and
        get_char_var(ctx, :KielHyreQuest, 0) < 60 and count_item(ctx, 7502) < 1 ->
        ctx
        |> mes("^3355FFYou encounter a dusty")
        |> mes("bookshelf filled with")
        |> mes("numerous books. You")
        |> mes("find a folded note between")
        |> mes("the books as you examine them.^000000")
        |> give_item(7502, 1)
        |> close()

      true ->
        ctx
        |> mes("^3355FFYou encounter a dusty")
        |> mes("bookshelf filled with")
        |> mes("numerous books.^000000")
        |> close()
    end
  end
end
