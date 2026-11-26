defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Book do
  @moduledoc """
  Bruspetti's diary, found during the investigation.

  ## Behavior

  - Lets the player take the diary at the appropriate stage of the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_in01",
        x: 255,
        y: 25,
        dir: 0,
        sprite: 111,
        name: "Book",
        scope: :shared,
        unique_name: "Book#ra_in"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :rach_vice, 0)

    cond do
      stage == 15 ->
        ctx
        |> mes("^3355FFThis is where you")
        |> mes("found Bruspetti's diary.")
        |> mes("Perhaps you should take")
        |> mes("it with you the next time")
        |> mes("you talk to Katinshuell.^000000")
        |> close()

      stage == 14 ->
        ctx
        |> set_char_var(:rach_vice, 15)
        |> changequest(8118, 8119)
        |> give_item(7571, 1)
        |> mes("^3355FFThis must be")
        |> mes("Bruspetti's diary!")
        |> mes("You now have permission")
        |> mes("to take it with you so that")
        |> mes("you can figure out if she and")
        |> mes("Katinshuell are connected...^000000")
        |> close()

      stage in [9, 10] ->
        ctx
        |> mes("^3355FFThis must be")
        |> mes("Bruspetti's diary!")
        |> mes("But... reading it")
        |> mes("would make you feel")
        |> mes("like a real creep.")
        |> mes("So don't touch it.^000000")
        |> set_char_var(:rach_vice, 10)
        |> changequest(8113, 8114)
        |> close()

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
