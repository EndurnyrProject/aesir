defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Marian do
  @moduledoc """
  Marian, the camp's supply clerk, who hands out the supply boxes and the escort to
  Instructor Lugen.

  ## Behavior

  - Turns away a player who would be carrying too much, or whose weight reserve is under 1,000.
  - Before the first step, a player who is already past the expedition start is asked whether
    this is their first visit; either answer sets `ep13_newbs` to 1, grants a Chocolate Pie and
    starts quest 11084. A player who is not that far along is told she is busy.
  - On step 1 points at Instructor Lugen, on steps 2 to 12 welcomes the player back, and on step
    13 hands over three Supply Boxes plus a Chocolate Pie, advancing quest 11091 to 11092.
  - On steps 14 to 19 reissues a lost Supply Box while the player holds fewer than the current
    errand needs (3, 2 or 1), and otherwise sends them to work.
  - Beyond that she chats about the motherland's supplies.

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
        x: 222,
        y: 283,
        dir: 4,
        sprite: 727,
        name: "Marian",
        scope: :shared,
        unique_name: "Marian#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @supply_box 6045
  @gift 12322

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 or get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 1000 ->
        overburdened(ctx)

      get_char_var(ctx, :ep13_newbs, 0) < 1 ->
        first_visit(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 1 ->
        go_to_lugen(ctx)

      get_char_var(ctx, :ep13_newbs, 0) < 13 ->
        welcome_back(ctx)

      get_char_var(ctx, :ep13_newbs, 0) == 13 ->
        hand_over_supplies(ctx)

      get_char_var(ctx, :ep13_newbs, 0) < 20 ->
        supply_box_check(ctx)

      true ->
        busy_chatter(ctx)
    end
  end

  defp overburdened(ctx) do
    ctx
    |> mes("[Marian]")
    |> mes("You have too many items~")
    |> mes("Drop some and come back to me.")
    |> close()
  end

  defp first_visit(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) > 99 or get_char_var(ctx, :ep13_start, 0) > 99 do
      stranger_menu(ctx)
    else
      busy_now(ctx)
    end
  end

  defp stranger_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Marian]")
      |> mes("You must be a stranger here.")
      |> mes("Is this your first visit here?")
      |> next()
      |> select(["Yes.", "No."])

    case choice do
      1 -> first_time_here(ctx)
      2 -> not_from_around(ctx)
      _ -> ctx
    end
  end

  defp first_time_here(ctx) do
    ctx
    |> mes("[Marian]")
    |> mes("As expected~")
    |> mes("I'm not lying, but usually")
    |> mes("I never forget a face.")
    |> emotion(:throb)
    |> next()
    |> mes("[Marian]")
    |> mes("Well, anyway...")
    |> mes("If this is your first time here,")
    |> mes("you'd better see ^0000FFInstructor Lugen^000000.")
    |> mes("He can help you adjust")
    |> mes("to these surroundings.")
    |> next()
    |> mes("[Marian]")
    |> mes("Go to the right to find")
    |> mes("^0000FFInstructor Lugen^000000.")
    |> start_the_quest()
  end

  defp not_from_around(ctx) do
    ctx
    |> mes("[Marian]")
    |> mes("Well~ It is weird~")
    |> next()
    |> mes(" - ransacking - ")
    |> mes(" - flap - ")
    |> next()
    |> mes("[Marian]")
    |> mes("Hmm, you're not")
    |> mes("from around here.")
    |> next()
    |> mes("[Marian]")
    |> mes("Go to the right along this way")
    |> mes("and you'll find ^0000FFInstructor Lugen^000000.")
    |> mes("Talk to him, first.")
    |> start_the_quest()
  end

  defp start_the_quest(ctx) do
    ctx
    |> set_char_var(:ep13_newbs, 1)
    |> give_item(@gift, 1)
    |> setquest(11084)
    |> close()
  end

  defp busy_now(ctx) do
    ctx
    |> mes("[Marian]")
    |> mes("......")
    |> mes("I'm sorry but,")
    |> mes("I'm a bit busy now...")
    |> close()
  end

  defp go_to_lugen(ctx) do
    ctx
    |> mes("[Marian]")
    |> mes("Go to the right to see ^0000FFInstructor Lugen^000000.")
    |> emotion(:throb)
    |> close()
  end

  defp welcome_back(ctx) do
    ctx
    |> mes("[Marian]")
    |> mes("Wow, good to see you again.")
    |> mes("Do you feel comfortable around here?")
    |> emotion(:throb)
    |> close()
  end

  defp hand_over_supplies(ctx) do
    ctx =
      ctx
      |> mes("[Marian]")
      |> mes("Hey, how are you?")
      |> mes("What brings you here?")
      |> emotion(:throb)
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("The instructor sent me.")
      |> mes("He told me to get supplies from the motherland.")
      |> next()
      |> mes("[Marian]")
      |> mes("Ah, you must be talking about~?")
      |> mes("Let me see~~")
      |> next()
      |> mes("[Marian]")
      |> mes("This and that~~")
      |> next()
      |> mes("[Marian]")
      |> mes("Hmm, not this one.")
      |> next()

    ctx
    |> mes("[Marian]")
    |> mes("Ah, I got it!")
    |> mes("Here they are!")
    |> mes("And this is for you.")
    |> mes("Go, go~~")
    |> set_char_var(:ep13_newbs, 14)
    |> give_item(@supply_box, 3)
    |> give_item(@gift, 1)
    |> changequest(11091, 11092)
    |> close()
  end

  defp supply_box_check(ctx) do
    step = get_char_var(ctx, :ep13_newbs, 0)

    needed =
      cond do
        step < 16 -> 3
        step < 18 -> 2
        true -> 1
      end

    if count_item(ctx, @supply_box) < needed do
      reissued_box(ctx)
    else
      do_your_job(ctx)
    end
  end

  defp reissued_box(ctx) do
    ctx
    |> mes("[Marian]")
    |> mes("Ha! You misplaced the Supply Box?!")
    |> mes("What the~~?")
    |> emotion(:huk)
    |> next()
    |> mes("[Marian]")
    |> mes("Ok, I have spares.")
    |> mes("Let me give one to you.")
    |> mes("Don't misplace this one, ok?!")
    |> give_item(@supply_box, 1)
    |> close()
  end

  defp do_your_job(ctx) do
    ctx
    |> mes("[Marian]")
    |> mes("Do your job, man~")
    |> mes("And please say hello")
    |> mes("to the instructor.")
    |> emotion(:throb)
    |> close()
  end

  defp busy_chatter(ctx) do
    ctx
    |> mes("[Marian]")
    |> mes("Hey~")
    |> mes("How have you been recently?")
    |> mes("I am busy all the time...")
    |> emotion(:cry)
    |> next()
    |> mes("[Marian]")
    |> mes("The supplies from the motherland are...")
    |> mes("Ah...")
    |> mes("Nothing, do not care...")
    |> mes("Hohoho...")
    |> emotion(:huk)
    |> close()
  end
end
