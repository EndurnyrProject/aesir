defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests131.PromotionalstaffIzlude do
  @moduledoc """
  Izlude's promotional staff, who runs the strength test that gates the Ash-Vacuum
  expedition for an adventurer sent by the Prontera recruiter.

  ## Behavior

  - Congratulates a player who is done (step 8 or above) and sends them to the palace.
  - At step 7, fails a player under base level 70 (advancing quest 10063 to 10064 keeps the
    step) and passes a player at 70 or above, advancing quest 10063/10062 to 10064 and
    setting `ep13_ryu` to 8.
  - At step 6, runs the level test and either completes it (quest 10062 to 10064, step 8) or
    sends the player back to step 7 with quest 10062 to 10063.
  - Falls back to the shared promotional staff pitch for everyone else.

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
        map: "izlude",
        x: 102,
        y: 171,
        dir: 6,
        sprite: 100,
        name: "Promotional Staff",
        scope: :renewal,
        unique_name: "Promotional Staff#iz"
      },
      %{
        map: "izlude_a",
        x: 102,
        y: 171,
        dir: 6,
        sprite: 100,
        name: "Promotional Staff",
        scope: :renewal,
        unique_name: "Promotional Staff#iz_a"
      },
      %{
        map: "izlude_b",
        x: 102,
        y: 171,
        dir: 6,
        sprite: 100,
        name: "Promotional Staff",
        scope: :renewal,
        unique_name: "Promotional Staff#iz_b"
      },
      %{
        map: "izlude_c",
        x: 102,
        y: 171,
        dir: 6,
        sprite: 100,
        name: "Promotional Staff",
        scope: :renewal,
        unique_name: "Promotional Staff#iz_c"
      },
      %{
        map: "izlude_d",
        x: 102,
        y: 171,
        dir: 6,
        sprite: 100,
        name: "Promotional Staff",
        scope: :renewal,
        unique_name: "Promotional Staff#iz_d"
      },
      %{
        map: "izlude",
        x: 99,
        y: 136,
        dir: 5,
        sprite: 100,
        name: "Promotional Staff",
        scope: :pre_renewal,
        unique_name: "Promotional Staff#iz"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.PromotionalStaff
  alias Aesir.ZoneServer.Script.Ctx

  @passing_level 70

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_ryu, 0) do
      step when step > 8 ->
        farewell(ctx)

      8 ->
        test_done(ctx)

      7 ->
        test_strength(ctx)

      6 ->
        first_test(ctx)

      _step ->
        {ctx, _} = PromotionalStaff.call(ctx, [])
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("I bless you for your future! May it be full of happiness!")
    |> close()
  end

  defp test_done(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("The test is done!")
    |> mes("If you have any other business, go to the palace.")
    |> close()
  end

  # A player who came back from the level-up errand: below level 70 the reference sends them
  # away without touching the step, at 70 or above it passes them.
  defp test_strength(ctx) do
    if base_level(ctx) < @passing_level do
      too_weak(ctx)
    else
      stronger_now(ctx)
    end
  end

  defp too_weak(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("You don't look that strong.")
    |> mes("Nothing but skin and bones!")
    |> mes("Not reliable.")
    |> mes("You should level up more before")
    |> mes("considering this adventure.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("I don't need adventurers who are")
    |> mes("body-builders... but at least")
    |> mes("someone not so little!!")
    |> close()
  end

  defp stronger_now(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("Wow! You are considerably")
    |> mes("stronger than before!")
    |> mes("Let me see...")
    |> mes("You look different!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Um...")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Ok, it's done!")
    |> mes("You seemed a sore weak of a soul,")
    |> mes("but now, you're quite stronger than")
    |> mes("before. Great! You will do!!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("We have quite high expectations to meet.")
    |> mes("Though the new place is dangerous,")
    |> mes("no need to check thoroughly")
    |> mes("anymore.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("It's not a hell-hole!")
    |> mes("Ukk!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Anyway, just go back to the")
    |> mes("Recruiter. I will forward to him")
    |> mes("that you passed all the steps. Good")
    |> mes("job, friend!")
    |> next()
    |> changequest(10063, 10064)
    |> set_char_var(:ep13_ryu, 8)
    |> mes("[Promotional Staff]")
    |> mes("Bless all of your heart,")
    |> mes("for your great future!")
    |> close()
  end

  defp first_test(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Promotional Staff]")
      |> mes("We are recruiting adventurers")
      |> mes("who are quite strong and curious.")
      |> next()
      |> mes("[Promotional Staff]")
      |> mes("Hey, you're a knowledgeable adventurer. Are you interested in my story?")
      |> next()
      |> select(["I have something for you."])

    ctx =
      ctx
      |> mes("[Promotional Staff]")
      |> mes(
        "Um, you're the one sent to be tested, correct? You are in the right place. I'm the Promotional Staff in Izlude."
      )
      |> next()
      |> mes("[Promotional Staff]")
      |> mes("I guess you're qualified enough to go... I think no more testing is needed.")
      |> next()
      |> mes("[Promotional Staff]")
      |> mes("Let me see...")
      |> next()

    if base_level(ctx) > 69 do
      passed(ctx)
    else
      failed(ctx)
    end
  end

  defp passed(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("I think you're good enough!")
    |> mes("No more testing!!")
    |> mes("Ok! You pass!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("We have quite high expectations to meet.")
    |> mes("Though the new place is dangerous,")
    |> mes("no need to check thoroughly right now.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("It's not a hell-hole!")
    |> mes("Ukk...")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Anyway, just go back to the recruiter.")
    |> mes("I will forward to him that you passed all the steps.")
    |> mes("Good job, friend!")
    |> next()
    |> changequest(10062, 10064)
    |> set_char_var(:ep13_ryu, 8)
    |> mes("[Promotional Staff]")
    |> mes("May Freya bless you,")
    |> mes("for your great future!")
    |> close()
  end

  defp failed(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("Hmm...")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("You don't look that strong.")
    |> mes("Nothing but skin and bones!")
    |> mes("Not reliable.")
    |> mes("I can't let you pass.")
    |> next()
    |> changequest(10062, 10063)
    |> set_char_var(:ep13_ryu, 7)
    |> mes("[Promotional Staff]")
    |> mes("Please level up a little more. I")
    |> mes("can't accept that you're strong")
    |> mes("enough. Sorry.")
    |> close()
  end
end
