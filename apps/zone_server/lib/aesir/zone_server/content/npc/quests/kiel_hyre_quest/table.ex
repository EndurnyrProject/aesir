defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Table do
  @moduledoc """
  The table holds the Rosimier family portrait needed for the investigation.

  ## Behavior

  - Gives the family portrait when searched during the relevant quest stage without one.
  - Shows an empty drawer when the portrait is already held or the investigation has progressed.

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
        x: 23,
        y: 23,
        dir: 0,
        sprite: 111,
        name: "Table",
        scope: :shared,
        unique_name: "Table#khr2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      checkweight(ctx, [{7499, 1}]) == 0 ->
        ctx
        |> mes("^3355FFJust a second...")
        |> mes("You're carrying too")
        |> mes("many items with you")
        |> mes("right now, so you'll")
        |> mes("need to free up more")
        |> mes("Inventory space first...^000000")
        |> close()

      quest < 58 ->
        ctx
        |> mes("^3355FFThere's nothing here")
        |> mes("of importance to you.^000000")
        |> close()

      quest < 60 ->
        search_drawer(ctx)

      true ->
        ctx
        |> mes("^3355FFThis was the desk in")
        |> mes("which you obtained the")
        |> mes("Rosimier family portrait.")
        |> mes("Its drawers are empty now.^000000")
        |> close()
    end
  end

  defp search_drawer(ctx) do
    ctx =
      if count_item(ctx, 7499) < 1 do
        ctx
        |> cutin("kh_family_port", 1)
        |> mes("^3355FFYou examine the table,")
        |> mes("and find a framed portrait")
        |> mes("inside the open drawer.^000000")
        |> give_item(7499, 1)
      else
        ctx
        |> mes("^3355FFThe open drawer of")
        |> mes("this desk is now empty.^000000")
      end

    ctx |> close() |> cutin("", 255)
  end
end
