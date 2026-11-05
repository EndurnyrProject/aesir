defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Drawer do
  @moduledoc """
  The cottage drawer contains a Yellow Keycard.

  ## Behavior

  - Checks carrying capacity and offers the keycard while eligible and not already carrying one.

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
        x: 115,
        y: 186,
        dir: 0,
        sprite: 111,
        name: "Drawer",
        scope: :shared,
        unique_name: "Drawer#khp1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7492, 1}]) == 0 ->
        ctx
        |> mes("^3355FFThere's something inside")
        |> mes("this drawer, but you can't")
        |> mes("take it since you're carrying")
        |> mes("to many items with you. Maybe")
        |> mes("you should pay a visit to your")
        |> mes("trusty Kafra Storage first.^000000")
        |> close()

      count_item(ctx, 7492) < 1 and get_char_var(ctx, :KielHyreQuest, 0) <= 36 ->
        search_drawer(ctx)

      true ->
        ctx
        |> mes("^3355FFThis is where you")
        |> mes("found the Yellow Keycard.")
        |> mes("This drawer is now empty.^000000")
        |> close()
    end
  end

  defp search_drawer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou find an old drawer")
      |> mes("^that has been closed.")
      |> mes("^If you open it, then you")
      |> mes("^might find something")
      |> mes("^inside. Or could it be")
      |> mes("^empty. Who knows?^000000")
      |> next()
      |> select(["Open Drawer", "Ignore"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou obtain a Yellow")
        |> mes("Keycard from inside the")
        |> mes("drawer. Opening that drawer")
        |> mes("turned out to be worthwhile.^000000")
        |> give_item(7492, 1)
        |> close()

      2 ->
        ctx
        |> mes("^3355FFForget opening that")
        |> mes("drawer. I mean, come on,")
        |> mes("what would be the point?^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
