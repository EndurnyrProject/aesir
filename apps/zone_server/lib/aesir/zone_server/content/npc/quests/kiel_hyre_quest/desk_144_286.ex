defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Desk144286 do
  @moduledoc """
  This desk holds letters about Allysia and James Rosimier.

  ## Behavior

  - Checks inventory capacity before allowing inspection.
  - Offers three drawers during the investigation and gives K.H.’s letter if it is missing.

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
        x: 144,
        y: 286,
        dir: 0,
        sprite: 111,
        name: "Desk",
        scope: :shared,
        unique_name: "Desk#khr3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7501, 1}]) == 0 ->
        ctx
        |> mes("^3355FFJust a second...")
        |> mes("You're carrying too")
        |> mes("many items with you")
        |> mes("right now, so you'll")
        |> mes("need to free up more")
        |> mes("Inventory space first...^000000")
        |> close()

      get_char_var(ctx, :KielHyreQuest, 0) < 58 ->
        ctx |> mes("^3355FFIt's just a desk.^000000") |> close()

      get_char_var(ctx, :KielHyreQuest, 0) < 60 ->
        inspect_drawers(ctx)

      true ->
        ctx
        |> mes("^3355FFThis is the desk where")
        |> mes("you found a letter written")
        |> mes("by K.H., and a note scribbled")
        |> mes("by James Rosimier. Both of")
        |> mes("these are addressed to")
        |> mes("the same woman, Allysia.^000000")
        |> close()
    end
  end

  defp inspect_drawers(ctx) do
    {ctx, drawer} =
      ctx
      |> mes("^3355FFThe desk has")
      |> mes("three drawers.^000000")
      |> next()
      |> select(["First Drawer", "Second Drawer", "Third Drawer", "Cancel"])

    case drawer do
      1 ->
        ctx |> mes("^3355FFThe first drawer is locked.^000000") |> close()

      2 ->
        inspect_letter(ctx)

      3 ->
        ctx
        |> mes("^3355FFThere is a small note")
        |> mes("inside this third drawer.")
        |> mes("It's written by James, and")
        |> mes("mentions that he wants to")
        |> mes("marry Allysia, and that she")
        |> mes("received an engagement ring.^000000")
        |> close()

      4 ->
        ctx |> mes("......") |> mes(".........") |> mes("............") |> close()

      _ ->
        ctx
    end
  end

  defp inspect_letter(ctx) do
    if count_item(ctx, 7501) < 1 do
      ctx
      |> mes("^3355FFThere is a letter inside")
      |> mes("this second drawer. It")
      |> mes("was sent by a person")
      |> mes("with the initials, K.H.,")
      |> mes("and addressed to Allysia.^000000")
      |> give_item(7501, 1)
      |> close()
    else
      ctx |> mes("^3355FFThis drawer is now empty.^000000") |> close()
    end
  end
end
