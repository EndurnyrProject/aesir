defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Waiter do
  @moduledoc """
  A waiter welcomes patrons to Rachel's Palate.

  ## Behavior

  - Seats the player during the investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_in01",
        x: 308,
        y: 59,
        dir: 1,
        sprite: 930,
        name: "Waiter",
        scope: :shared,
        unique_name: "Waiter#pc"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :aru_monas, 0) < 7 do
      ctx =
        ctx
        |> mes("[Waiter]")
        |> mes("Welcome to")
        |> mes("Rachel's Palate, one")
        |> mes("of Rachel's finest and")
        |> mes("most exquisite restraunts.")

      if get_char_var(ctx, :aru_monas, 0) < 6 do
        close(ctx)
      else
        offer_seating(ctx)
      end
    else
      ctx
      |> mes("[Waiter]")
      |> mes("The food in this")
      |> mes("restaurant is the")
      |> mes("best in Rachel--no,")
      |> mes("it is the best in all")
      |> mes("of Arunafeltz!")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp offer_seating(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Waiter]")
      |> mes("What would you like")
      |> mes("to order? Or... If I'm")
      |> mes("not mistaken, you're")
      |> mes("here for something else?")
      |> next()
      |> select(["I'd like to order.", "Yes, I've come for another reason."])

    if choice == 1 do
      {ctx, _} =
        ctx
        |> mes("[Waiter]")
        |> mes("Sure, no problem.")
        |> mes("Did you come alone?")
        |> next()
        |> select(["Yes."])

      ctx =
        ctx
        |> mes("[Waiter]")
        |> mes("Right this way.")
        |> close2()
        |> set_char_var(:aru_monas, 7)

      case Enum.random(1..4) do
        1 -> warp(ctx, "ra_in01", 303, 43)
        2 -> warp(ctx, "ra_in01", 304, 43)
        3 -> warp(ctx, "ra_in01", 304, 39)
        4 -> warp(ctx, "ra_in01", 303, 39)
      end
    else
      ctx
      |> mes("[Waiter]")
      |> mes("Hm, okay. Well, whatever")
      |> mes("it is, I hope you enjoy your")
      |> mes("stay at Rachel's Palate.")
      |> close()
    end
  end
end
