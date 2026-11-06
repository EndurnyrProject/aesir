defmodule Aesir.ZoneServer.Content.Npc.PreRe.Other.Resetskill.Hypnotist do
  @moduledoc """
  Hypnotist in Prontera who resets the skills of qualifying first-class adventurers for free.

  ## Behavior

  - Explains the service and lists its two conditions: base level 40 or lower, and a first class
    job (Swordman, Acolyte, Mage, Thief, Archer, Merchant) or a Taekwon, Gunslinger or Ninja.
  - First class jobs must not be transcendent; every applicant must have an empty pushcart and
    zero carried weight before the reset happens.
  - Closes without resetting when a condition fails, and offers the reset repeatedly.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/other/resetskill.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "prontera",
        x: 146,
        y: 232,
        dir: 4,
        sprite: 124,
        name: "Hypnotist",
        scope: :pre_renewal,
        unique_name: "Hypnotist#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @menu ["Skill Reset?", "I want a Skill Reset", "Nothing"]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, answer} =
      ctx
      |> greeting()
      |> next()
      |> conditions()
      |> next()
      |> eligible_jobs()
      |> next()
      |> select(@menu)

    case answer do
      1 -> explain_reset(ctx)
      2 -> confirm_reset(ctx)
      3 -> farewell(ctx)
      _ -> ctx
    end
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Hypnotist]")
    |> mes("Greetings, adventurer.")
    |> mes("I'm a member of the Hypnotist")
    |> mes("Academy sent here to Prontera")
    |> mes("to provide Skill Reset services")
    |> mes("to certain First Class characters for a really good price: free!")
  end

  defp conditions(ctx) do
    ctx
    |> mes("[Hypnotist]")
    |> mes("Although I offer unlimited")
    |> mes("skill resets for now, I have")
    |> mes("two conditions that must be")
    |> mes("fulfilled. First, you must be")
    |> mes("lower than ^FF0000Base Level 40^000000.")
  end

  defp eligible_jobs(ctx) do
    ctx
    |> mes("[Hypnotist]")
    |> mes("Second, you must be a")
    |> mes("^FF0000Swordman, Acolyte, Mage,")
    |> mes("Thief, Archer, Merchant,")
    |> mes("Taekwon Boy, Taekwon Girl, Gunslinger and Ninja^000000")
    |> mes("Job character to qualify.")
    |> mes("Now, do you have any questions?")
  end

  defp explain_reset(ctx) do
    ctx
    |> mes("[Hypnotist]")
    |> mes("Skill Resets allow adventuers")
    |> mes("to redistribute their Skill")
    |> mes("Points if they are unhappy")
    |> mes("with their current skills.")
    |> next()
    |> mes("[Hypnotist]")
    |> mes("Before proceeding with")
    |> mes("a Skill Reset, you must")
    |> mes("reduce all of the weight")
    |> mes("of all carried items on your")
    |> mes("character to 0. You can put")
    |> mes("extra items in Kafra Storage.")
    |> next()
    |> mes("[Hypnotist]")
    |> mes("Ah, it's also important")
    |> mes("to remove your ^FF0000Pushcart^000000")
    |> mes("if you have one equipped.")
    |> mes("Otherwise, hypnosis won't")
    |> mes("work, or will backfire...")
    |> close()
  end

  defp confirm_reset(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Hypnotist]")
      |> mes("Are you sure that you")
      |> mes("want to proceed with")
      |> mes("my ^FF0000Skill Reset^000000 service?")
      |> next()
      |> select(["Yes", "Cancel"])

    if answer == 1 do
      perform_reset(ctx)
    else
      farewell(ctx)
    end
  end

  defp perform_reset(ctx) do
    cond do
      base_level(ctx) > 40 -> too_experienced(ctx)
      not eligible?(ctx) -> ineligible_job(ctx)
      Rathena.truthy?(checkcart(ctx)) -> wearing_pushcart(ctx)
      Rathena.truthy?(weight(ctx)) -> carrying_weight(ctx)
      true -> grant_reset(ctx)
    end
  end

  defp eligible?(ctx) do
    job_id = Rathena.job_id(class(ctx))

    (job_id in 1..6 and upper(ctx) == 0) or
      job_id in [Rathena.job_id(:gunslinger), Rathena.job_id(:ninja), Rathena.job_id(:taekwon)]
  end

  defp too_experienced(ctx) do
    ctx
    |> mes("[Hypnotist]")
    |> mes("I'm sorry, but characters")
    |> mes("with Base Levels higher")
    |> mes("than 40 are ineligible for the")
    |> mes("Skill Reset service I provide.")
    |> close()
  end

  defp wearing_pushcart(ctx) do
    ctx
    |> mes("[Hypnotist]")
    |> mes("Oh! Please remove your")
    |> mes("Pushcart before proceeding")
    |> mes("with the Skill Reset service.")
    |> mes("Thanks for cooperating~")
    |> close()
  end

  defp carrying_weight(ctx) do
    ctx
    |> mes("[Hypnotist]")
    |> mes("If you're here for my Skill")
    |> mes("Reset service, please")
    |> mes("remember that you can't")
    |> mes("reset your skills until the")
    |> mes("^FF0000weight of your carried items in")
    |> mes("your Inventory is reduced to 0^000000.")
    |> next()
    |> mes("[Hypnotist]")
    |> mes("Why don't you place your")
    |> mes("things into the Kafra Storage")
    |> mes("for now? That way, you can")
    |> mes("safely keep all of your goods.")
    |> close()
  end

  defp grant_reset(ctx) do
    ctx
    |> mes("[Hypnotist]")
    |> mes("Thank you for using")
    |> mes("my Skill Redistribution")
    |> mes("services. Oh, and best")
    |> mes("of luck to you on your")
    |> mes("travels, adventurer.")
    |> reset_skills()
    |> close()
  end

  defp ineligible_job(ctx) do
    ctx
    |> mes("[Hypnotist]")
    |> mes("I'm sorry, but your")
    |> mes("Job Class doesn't qualify")
    |> mes("for the Skill Reset service")
    |> mes("that I provide. I can only")
    |> mes("offer Skill Resets to the")
    |> mes("following Jobs...")
    |> next()
    |> mes("[Hypnotist]")
    |> mes("^FF0000Swordman, Acolyte,")
    |> mes("Mage, Thief, Archer,")
    |> mes("Merchant, Taekwon")
    |> mes("Boy, Taekwon Girl, Gunslinger and Ninja^000000.")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Hypnotist]")
    |> mes("Thank you, and good")
    |> mes("luck on your adventures.")
    |> mes("Please travel in safety~")
    |> close()
  end
end
