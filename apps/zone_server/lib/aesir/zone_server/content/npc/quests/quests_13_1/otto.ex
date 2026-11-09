defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Otto do
  @moduledoc """
  Otto, the researcher posted across the rift, who answers the Instructor's letter with one of
  his own.

  ## Behavior

  - Refuses a player who carries too much to receive an item.
  - On step 23 delivers the Instructor's letter: without it Otto only trails off, with it he
    reads it, writes a reply, sets `ep13_newbs` to 24, grants the reply letter and a Chocolate
    Pie, and advances quest 11099 to 11100.
  - On step 24 asks for the reply letter again, rewriting it if the player lost it.
  - Past step 99 recalls the visit, and otherwise muses about the two sides of the rift.

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
        x: 123,
        y: 290,
        dir: 4,
        sprite: 967,
        name: "Otto",
        scope: :shared,
        unique_name: "Otto#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @instructors_letter 6043
  @ottos_letter 6044
  @gift 12322

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 -> overburdened(ctx)
      get_char_var(ctx, :ep13_newbs, 0) == 23 -> deliver_letter(ctx)
      get_char_var(ctx, :ep13_newbs, 0) == 24 -> ask_for_letter(ctx)
      get_char_var(ctx, :ep13_newbs, 0) > 99 -> after_the_visit(ctx)
      true -> field_talk(ctx)
    end
  end

  defp overburdened(ctx) do
    ctx
    |> mes("- Wait a minute !! -")
    |> mes("- Currently you're carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please try again -")
    |> mes("- after you lose some weight. -")
    |> close()
  end

  defp deliver_letter(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Mr. Otto?!")
      |> next()
      |> mes("[Otto]")
      |> mes("Hmm, how can I help you?")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Instructor Lugen sent me!")
      |> mes("He is worrying about you getting worse.")
      |> next()
      |> mes("[Otto]")
      |> mes("Oh, is he...")
      |> mes("It was just a cold.")
      |> mes("It was nothing.")
      |> mes("He's still overprotective..")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("That's good to hear.")
      |> mes("Ah, and he wrote this letter for you.")
      |> next()

    if count_item(ctx, @instructors_letter) < 1 do
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Eh, where is it...")
      |> next()
      |> mes("[Otto]")
      |> mes("......")
      |> close()
    else
      write_reply(ctx)
    end
  end

  defp write_reply(ctx) do
    ctx
    |> mes("[Otto]")
    |> mes("We are not allowed to leave our posts,")
    |> mes("so I am wondering about him, as well.")
    |> next()
    |> mes("[Otto]")
    |> mes("A letter, I never expected this, huhu.")
    |> next()
    |> mes("- Otto is reading the letter -")
    |> mes("- with the smile on his face. -")
    |> next()
    |> mes("[Otto]")
    |> mes("I am sorry but, can you please")
    |> mes("tell him that I am ok now by")
    |> mes("giving him this letter.")
    |> next()
    |> mes("[Otto]")
    |> mes("And I will have a vacation")
    |> mes("in the near future and will")
    |> mes("use that time to visit him.")
    |> delitem(@instructors_letter, 1)
    |> set_char_var(:ep13_newbs, 24)
    |> give_item(@ottos_letter, 1)
    |> give_item(@gift, 1)
    |> changequest(11099, 11100)
    |> close()
  end

  defp ask_for_letter(ctx) do
    if count_item(ctx, @ottos_letter) < 1 do
      ctx
      |> mes("[Otto]")
      |> mes("You lost the letter?")
      |> mes("I'll write it again.")
      |> give_item(@ottos_letter, 1)
      |> close()
    else
      ctx
      |> mes("[Otto]")
      |> mes("I am sorry but, can you please")
      |> mes("tell him that I am ok now by")
      |> mes("giving him this letter.")
      |> next()
      |> mes("[Otto]")
      |> mes("And I will have a vacation")
      |> mes("in the near future and will")
      |> mes("use that time to visit him.")
      |> close()
    end
  end

  defp after_the_visit(ctx) do
    ctx
    |> mes("[Otto]")
    |> mes("Thanks to you,")
    |> mes("I was able to meet")
    |> mes("him some days ago.")
    |> mes("He, wasn't feeling good, either.")
    |> next()
    |> mes("[Otto]")
    |> mes("It seems that I will")
    |> mes("have more free time,")
    |> mes("so I will take that time")
    |> mes("to visit him more often.")
    |> close()
  end

  defp field_talk(ctx) do
    ctx
    |> mes("[Otto]")
    |> mes("This place has a totally different environment on both sides.")
    |> next()
    |> mes("[Otto]")
    |> mes("Is it natural,")
    |> mes("or artificial?")
    |> close()
  end
end
