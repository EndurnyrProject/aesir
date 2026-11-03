defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Broncher do
  @moduledoc """
  A drunken Alchemist who teaches the Homunculus Resurrection lesson of the Bioethics quest.

  ## Behavior

  - At Bioethics step 6, explains Homunculus Resurrection and advances the quest to step 7.
  - Past that step, sends the Alchemist back to Kellasus.
  - Otherwise praises his ''Anti-Sobriety'' formula.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - Samuray22
    - L0ne_W0lf
    - DracoRPG
    - Toms
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in02",
        x: 278,
        y: 273,
        dir: 3,
        sprite: 709,
        name: "Broncher",
        scope: :shared,
        unique_name: "Broncher#qsk_al"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if alchemist?(ctx),
      do: bioethics_step(ctx, get_char_var(ctx, :bioeth, 0)),
      else: greeting(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp alchemist?(ctx), do: Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist)

  defp bioethics_step(ctx, bioeth) when bioeth > 6, do: already_taught(ctx)
  defp bioethics_step(ctx, 6), do: teach_homunculus_resurrection(ctx)
  defp bioethics_step(ctx, _bioeth), do: greeting(ctx)

  defp already_taught(ctx) do
    ctx
    |> mes("[Broncher]")
    |> mes("You again? Didn't I already")
    |> mes("teach you the Homunculus")
    |> mes("Resurrection skill? Come")
    |> mes("on, there's nothing else")
    |> mes("I can do for you. Lemme")
    |> mes("enjoy myself here...")
    |> next()
    |> mes("[Broncher]")
    |> mes("If you didn't already,")
    |> mes("go and bother Kellasus")
    |> mes("and get him to teach you the")
    |> mes("basic Homunculus techniques.")
    |> mes("Now go away, you're sobering")
    |> mes("me up! Go on, get outta here!")
    |> close()
  end

  defp teach_homunculus_resurrection(ctx) do
    ctx
    |> mes("[Broncher]")
    |> mes("^333333*Hiccup!*^000000")
    |> mes("Oh man...")
    |> mes("Oh man, this stuff")
    |> mes("is great! Yeah. Yeah,")
    |> mes("this really hits the spot.")
    |> next()
    |> mes("[Brocher]")
    |> mes("Holy crap! Y-you're that")
    |> mes("Alchemist that Skrajjad")
    |> mes("told me to expect! Wha--?")
    |> mes("You already visited Keshibien?")
    |> mes("Crap! I thought you wouldn't")
    |> mes("get here for another... Hour!")
    |> next()
    |> mes("[Broncher]")
    |> mes("Oh, forget sobering.")
    |> mes("I'll just teach you the")
    |> mes("^FF0000Homunculus Resurrection^000000")
    |> mes("skill. It's one of the last")
    |> mes("skills you need to learn")
    |> mes("for Homunculi, anyway.")
    |> next()
    |> mes("[Broncher]")
    |> mes("Yes, you can literally")
    |> mes("bring Homunculi back")
    |> mes("from the dead. Oh, and you")
    |> mes("should know that this skill is")
    |> mes("mastered at Skill Level 5.")
    |> next()
    |> mes("[Broncher]")
    |> mes("To bring your")
    |> mes("Homunculus back from")
    |> mes("the dead, you just push")
    |> mes("this button, the one that's")
    |> mes("labeled, ''Homunculus")
    |> mes("Resurrection.'' Easy, right?")
    |> next()
    |> mes("[Broncher]")
    |> mes("Well, lesson's over.")
    |> mes("You know everything you")
    |> mes("need to know about using")
    |> mes("Homunculus Resurrection.")
    |> mes("But you still need Kellasus")
    |> mes("to teach you the fundamentals.")
    |> set_char_var(:bioeth, 7)
    |> next()
    |> mes("[Broncher]")
    |> mes("Without those basic")
    |> mes("techiques, everything")
    |> mes("you've studied from us")
    |> mes("will be for nothing. So...")
    |> mes("Lots of luck convincing")
    |> mes("Kellasus to teach you.")
    |> next()
    |> mes("[Broncher]")
    |> mes("Now leave alone")
    |> mes("and let me enjoy")
    |> mes("all of this alcohol")
    |> mes("in solitude, alright?")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Broncher]")
    |> mes("^333333*Hiccup~*^000000")
    |> mes("Oh yeah, this is")
    |> mes("the stuff! I call it...")
    |> mes("My ''Anti-Sobriety''")
    |> mes("formula! Can't think")
    |> mes("of a finer thing created...")
    |> close()
  end
end
