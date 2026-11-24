defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Curator do
  @moduledoc """
  The curator guards the museum bathroom during the ghost quest.

  ## Behavior

  - Refuses entry to low-level adventurers and accepts a coconut during the quest.
  - Lets the adventurer into the bathroom after receiving the coconut.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_in01",
        x: 7,
        y: 181,
        dir: 5,
        sprite: 477,
        name: "Curator",
        scope: :shared,
        unique_name: "Curator#bra"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :brazil_ghost, 0)

    cond do
      base_level(ctx) < 40 ->
        ctx
        |> mes("[Curator]")
        |> mes("I'm sorry but this area is under construction right now.")
        |> close()

      progress > 0 and progress < 7 ->
        request_entry(ctx, count_item(ctx, 11_515) > 0)

      progress > 6 ->
        ctx
        |> mes("[Curator]")
        |> mes("Hey thanks for the Coconut earlier it really helped me cool down.")
        |> close()

      true ->
        ctx
        |> mes("[Curator]")
        |> mes("Is it just me? Or is it hotter than it's ever been today!")
        |> close()
    end
  end

  defp request_entry(ctx, has_coconut) do
    {ctx, _} =
      ctx
      |> mes("[Curator]")
      |> mes("What can I do for you?")
      |> next()
      |> select(["I need to use the bathroom."])

    {ctx, choice} =
      ctx
      |> mes("[Curator]")
      |> mes("Sorry we are remodeling inside right now so, it's closed.")
      |> mes("Please use the other one.")
      |> next()
      |> select(["But I forgot something inside.", "Give up."])

    case choice do
      1 -> discuss_heat(ctx, has_coconut)
      2 -> ctx |> mes("You give up trying to enter.") |> close()
      _ -> ctx
    end
  end

  defp discuss_heat(ctx, has_coconut) do
    {ctx, _} =
      ctx
      |> mes("[Curator]")
      |> mes("That's tooooo bad.")
      |> mes(
        "But my manager ordered me to stop anyone from entering this bathroom so, I should follow his orders."
      )
      |> next()
      |> select(["It's such a hot day!"])

    ctx =
      ctx
      |> mes("[Curator]")
      |> mes("It's always hot in Brasilis but today is ridiculously hot.")
      |> mes("Maybe I need to drink some coconut juice to cool down.")

    if has_coconut do
      ctx
      |> next()
      |> mes("You give a coconut to the Curator.")
      |> next()
      |> mes("[Curator]")
      |> mes("Oh really can I have it?")
      |> mes("Thanks a lot!")
      |> next()
      |> mes("[Curator]")
      |> mes("Pay it forward right?")
      |> mes("Ok I'll let you through this one time.")
      |> next()
      |> mes("The curator looks around calmly then opens the door.")
      |> delitem(11_515, 1)
      |> set_char_var(:brazil_ghost, 2)
      |> close()
      |> warp("bra_in01", 138, 176)
    else
      close(ctx)
    end
  end
end
