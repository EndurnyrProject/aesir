defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Grandma do
  @moduledoc """
  An elderly woman who enjoys the peaceful spring.

  ## Behavior

  - Shares her observations and advances the search for Bruspetti.

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
        map: "rachel",
        x: 266,
        y: 35,
        dir: 3,
        sprite: 918,
        name: "Grandma",
        scope: :shared,
        unique_name: "Grandma#rachel"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :rach_vice, 0)

    cond do
      stage > 21 ->
        ctx
        |> mes("[Grandma]")
        |> mes("When you get to be my")
        |> mes("age, you'll cherish all")
        |> mes("of your memories, even if")
        |> mes("the experience was hurtful")
        |> mes("when it actually happened.")
        |> next()
        |> mes("[Grandma]")
        |> mes("Your memories are part")
        |> mes("of who you are and what")
        |> mes("makes you unique. I can")
        |> mes("appreciate living the life")
        |> mes("that I have, even if it's")
        |> mes("not particularly special.")
        |> close()

      stage == 13 ->
        ctx
        |> mes("[Grandma]")
        |> mes("When you get to be my")
        |> mes("age, you appreciate life")
        |> mes("more and can release your")
        |> mes("regrets more easily. I wasted")
        |> mes("much of my youth in needless")
        |> mes("worry when I could've relaxed.")
        |> close()

      stage == 12 ->
        ctx
        |> mes("[Grandma]")
        |> mes("Oh, back again, eh?")
        |> mes("I guess you must really")
        |> mes("like coming to this place")
        |> mes("too. Hm, that reminds me...")
        |> next()
        |> mes("[Grandma]")
        |> mes("See the edge of the spring?")
        |> mes("The same young man frequently")
        |> mes("comes to that spot, and stares")
        |> mes("into the water, just dripping with sadness. Someone so young")
        |> mes("shouldn't be feeling like that.")
        |> next()
        |> mes("[Grandma]")
        |> mes("You're supposed to come")
        |> mes("here to relax and enjoy")
        |> mes("the surrounding beauty,")
        |> mes("not wallow in your sorrow.")
        |> mes("I guess that boy doesn't")
        |> mes("agree with me on that.")
        |> next()
        |> mes("[Grandma]")
        |> mes("You should be able")
        |> mes("to let go of whatever's")
        |> mes("bothering you, and just")
        |> mes("enjoy life as it is now.")
        |> set_char_var(:rach_vice, 13)
        |> changequest(8116, 8117)
        |> close()

      true ->
        ctx
        |> mes("[Grandma]")
        |> mes("I love this place,")
        |> mes("its beautiful scenary")
        |> mes("and serene atmosphere.")
        |> mes("It's so heavenly peaceful.")
        |> next()
        |> mes("[Grandma]")
        |> mes("It brings my heart joy to see")
        |> mes("young couples can coming")
        |> mes("here and relaxing together.")
        |> mes("Isn't love a grand thing?")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
