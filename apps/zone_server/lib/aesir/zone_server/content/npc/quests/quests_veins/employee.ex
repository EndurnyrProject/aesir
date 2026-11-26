defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Employee do
  @moduledoc """
  An employee serves guests at the banquet.

  ## Behavior

  - Changes dialogue with the investigation's progress and sometimes identifies guests.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 166,
        y: 282,
        dir: 4,
        sprite: 904,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#sch"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :que_sch, 0)

    cond do
      progress < 15 ->
        ctx
        |> mes("[Employee]")
        |> mes("We've been so busy lately!")
        |> mes("It's just one party reservation")
        |> mes("after another! When will I be")
        |> mes("able to just take a break?")
        |> close()

      progress < 17 and Enum.random(1..3) == 2 ->
        ctx
        |> mes("[Employee]")
        |> mes("Hi, how may I help you?")
        |> mes("Tonight, most of customers")
        |> mes("are high ranking government")
        |> mes("officials or public figures.")
        |> mes("That man over there is the")
        |> mes("Rekenber P.R. executive.")
        |> next()
        |> mes("[Employee]")
        |> mes("That priest over there is")
        |> mes("actually a diplomat from")
        |> mes("Arunafeltz on business.")
        |> mes("These are some very")
        |> mes("important people!")
        |> close()

      progress < 17 ->
        ctx
        |> mes("[Employee]")
        |> mes("How can I help you?")
        |> mes("Oh, would you like another")
        |> mes("drink? There you go! Please")
        |> mes("enjoy the dinner party~")
        |> close()

      true ->
        ctx
        |> mes("[Employee]")
        |> mes("Oh, the mess left after")
        |> mes("a banquet is the biggest")
        |> mes("part of my job. It's tough")
        |> mes("work, but it needs to get done.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
