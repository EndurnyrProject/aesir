defmodule Aesir.ZoneServer.Content.Npc.Floating.Jobs.M22.Crusader.PatronKnight do
  @moduledoc """
  Bliant Piyord, the purification test of the Crusader job change quest.

  ## Behavior

  - Tells other classes, and Crusaders, what the Chivalry is about, and hints a
    Swordsman at the Job Level 40 requirement of the class.
  - On step 8, explains the battle test and moves quest 3013 to 3014; on step 9,
    asks whether the candidate is ready, and on step 10 welcomes the new
    Crusader.
  - Starting the test requires an equipped Rosary and one Holy Water, which is
    consumed. Declining, or coming without those, keeps the player out of the
    waiting room with an explanation.
  - Sends a player at any other step back to finish the earlier tests.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Black Dragon
    - Shin
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - Lupus
    - yyCC
    - Kisuka
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-2/crusader.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_cas",
        x: 261,
        y: 101,
        dir: 3,
        sprite: 751,
        name: "Patron Knight",
        scope: :renewal
      },
      %{
        map: "prt_castle",
        x: 35,
        y: 151,
        dir: 5,
        sprite: 751,
        name: "Patron Knight",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @rosary 2608
  @holy_water 523

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> mes("[Bliant Piyord]") |> mes("Welcome.")
    job = Rathena.job_id(base_job(ctx))
    quest = get_char_var(ctx, :CRUS_Q, 0)

    cond do
      job != Rathena.job_id(:swordman) -> turn_away(ctx, job)
      quest == 0 -> class_intro(ctx)
      quest in [8, 9] -> battle_test(ctx, quest)
      quest == 10 -> welcome_crusader(ctx)
      true -> pending_lines(ctx)
    end
  end

  defp turn_away(ctx, job) do
    cond do
      job == Rathena.job_id(:crusader) ->
        ctx
        |> mes("How goes")
        |> mes("your training?")
        |> next()
        |> mes("[Bliant Piyord]")
        |> mes(
          "Develop your faith. From faith springs strength and discipline. Day after day, train yourself and become a great Crusader."
        )
        |> close()

      job == Rathena.job_id(:novice) ->
        ctx
        |> mes("We are Crusaders,")
        |> mes("warriors of holiness preparing for the great Holy War that is to come.")
        |> next()
        |> mes("[Bliant Piyord]")
        |> mes("Are you interested")
        |> mes("in becoming a Crusader?")
        |> mes("We are always waiting")
        |> mes("for more capable men and")
        |> mes("women to join our ranks.")
        |> next()
        |> mes("[Bliant Piyord]")
        |> mes(
          "Train as a Swordsman and come to us when you think you are ready. If you have been called by Odin to become a Crusader, that would be even better."
        )
        |> close()

      true ->
        ctx
        |> mes("We are Crusaders,")
        |> mes("warriors of holiness preparing for the great Holy War that is to come.")
        |> next()
        |> mes("[Bliant Piyord]")
        |> mes(
          "Even in these relatively peaceful times, our training is ceaseless. We must be ready for the day with the tides of darkness shall rush against mankind..."
        )
        |> close()
    end
  end

  defp class_intro(ctx) do
    ctx
    |> mes("We are Crusaders,")
    |> mes("warriors of holiness preparing for the great Holy War that is to come.")
    |> next()
    |> mes("[Bliant Piyord]")
    |> mes("Are you interested")
    |> mes("in becoming a Crusader?")
    |> mes("We are always waiting")
    |> mes("for more capable men and")
    |> mes("women to join our ranks.")
    |> next()
    |> mes("[Bliant Piyord]")
    |> mes(
      "To become a Crusader, you must train until you are Job Level 40. For more details, please speak with our leader inside."
    )
    |> next()
    |> mes("[Bliant Piyord]")
    |> mes("May Odin")
    |> mes("be with you...")
    |> close()
  end

  defp battle_test(ctx, quest) do
    ctx = if quest == 8, do: explain_test(ctx), else: ready_question(ctx)

    {ctx, answer} =
      ctx
      |> next()
      |> select(["I would like to begin.", "Give me some time to prepare."])

    if answer == 1, do: begin_test(ctx), else: not_prepared(ctx)
  end

  defp explain_test(ctx) do
    ctx =
      ctx
      |> mes("It's nice")
      |> mes("to meet you.")
      |> mes("It is now time")
      |> mes("for your final test.")
      |> next()
      |> mes("[Bliant Piyord]")
      |> mes(
        "My name is Bliant Piyord and I too, am preparing for the Holy War. It must've been quite a hassle to come all this way."
      )
      |> next()
      |> mes("[Bliant Piyord]")
      |> mes(
        "This test will gauge your skills in battle. Only those with great fighting ability can become Crusaders."
      )
      |> next()
      |> mes("[Bliant Piyord]")
      |> mes("To take the battle test, bring")
      |> mes(
        "1 ^3355FFHoly Water^000000. This will be used to purify you prior to taking the test."
      )

    ctx =
      if checkquest(ctx, 3013) == -1 do
        ctx
      else
        changequest(ctx, 3013, 3014)
      end

    ctx
    |> next()
    |> mes("[Bliant Piyord]")
    |> mes("Well then...")
    |> mes("Shall we")
    |> mes("begin right away?")
    |> mes("Or do you need time")
    |> mes("to prepare yourself?")
  end

  defp ready_question(ctx) do
    ctx
    |> mes("Are you prepared")
    |> mes("for the test now?")
    |> next()
    |> mes("[Bliant Piyord]")
    |> mes("Would you like to begin now, or do you still need time to make preparations?")
  end

  defp begin_test(ctx) do
    cond do
      getequipid(ctx, 0) != @rosary and getequipid(ctx, 1) != @rosary ->
        ctx
        |> mes("[Bliant Piyord]")
        |> mes(
          "Just a second, you do not have a Rosary equipped. As a Crusader, you must always have a Rosary on your person."
        )
        |> next()
        |> mes("[Bliant Piyord]")
        |> mes("Come back and take")
        |> mes("the test after you")
        |> mes("have a Rosary.")
        |> close()

      count_item(ctx, @holy_water) < 1 ->
        ctx
        |> mes("[Bliant Piyord]")
        |> mes("For the battle test, please prepare one ^3355FFHoly water^000000.")
        |> mes("I told you just to purify the candidates.")
        |> next()
        |> mes("[Bliant Piyord]")
        |> mes("Get prepares and come back to here.")
        |> mes("I will wait for you.")
        |> close()

      true ->
        ctx
        |> delitem(@holy_water, 1)
        |> mes("[Bliant Piyord]")
        |> mes("Then, I'll start")
        |> mes("the test. You will")
        |> mes("be purified with the")
        |> mes("Holy Water you prepared.")
        |> next()
        |> mes("[Bliant Piyord]")
        |> mes("...............")
        |> next()
        |> mes("[Bliant Piyord]")
        |> mes("Let's begin.")
        |> mes("Go and enter")
        |> mes("the waiting room.")
        |> mes("Defeat the monsters")
        |> mes("that appear in")
        |> mes("the 4 stages.")
        |> close()
        |> warp("job_cru", 24, 169)
    end
  end

  defp not_prepared(ctx) do
    ctx
    |> mes("[Bliant Piyord]")
    |> mes(
      "Prepare 1 ^3355FFHoly Water^000000 to take the battle test. As I've said, it will be used to purify you prior to taking the test."
    )
    |> next()
    |> mes("[Bliant Piyord]")
    |> mes("Come back and take")
    |> mes("the test after you")
    |> mes("have prepared")
    |> mes("1 Holy Water.")
    |> mes("I shall be")
    |> mes("waiting.")
    |> close()
  end

  defp welcome_crusader(ctx) do
    ctx
    |> mes("Congratulations.")
    |> mes("You have completed")
    |> mes("all the tests to")
    |> mes("become a Crusader.")
    |> next()
    |> mes("[Bliant Piyord]")
    |> mes("Go talk to our")
    |> mes("leader inside.")
    |> mes("We welcome you into")
    |> mes("the ranks of those")
    |> mes("preparing for the")
    |> mes("coming Holy War.")
    |> close()
  end

  defp pending_lines(ctx) do
    ctx
    |> mes("Are you not one of the ones in the process of becoming a Crusader?")
    |> next()
    |> mes("[Bliant Piyord]")
    |> mes("It's not your turn")
    |> mes("to take my test yet.")
    |> mes("Come back after taking")
    |> mes("all the other tests.")
    |> next()
    |> mes("[Bliant Piyord]")
    |> mes("I'll see you soon.")
    |> mes("May Odin's blessings")
    |> mes("be with you.")
    |> close()
  end
end
