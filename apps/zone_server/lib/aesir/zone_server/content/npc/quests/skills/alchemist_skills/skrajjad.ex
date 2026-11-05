defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Skrajjad do
  @moduledoc """
  A Lighthalzen Alchemist who teaches the Vaporize lesson of the Bioethics quest.

  ## Behavior

  - At Bioethics step 4, explains Vaporize and advances the quest to step 5.
  - Past that step, points the Alchemist to Keshibien.
  - Otherwise muses about the breadth of Alchemy.

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
        map: "lhz_in01",
        x: 225,
        y: 122,
        dir: 5,
        sprite: 754,
        name: "Skrajjad",
        scope: :shared,
        unique_name: "Skrajjad#qsk_al"
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

  defp bioethics_step(ctx, bioeth) when bioeth > 4, do: already_taught(ctx)
  defp bioethics_step(ctx, 4), do: teach_vaporize(ctx)
  defp bioethics_step(ctx, _bioeth), do: greeting(ctx)

  defp already_taught(ctx) do
    ctx
    |> mes("[Skrajjad]")
    |> mes("I've taught you everything")
    |> mes("I can about the Homunculi.")
    |> mes("I hope that I've been of some")
    |> mes("help in your quest for knowledge and understanding of our universe.")
    |> next()
    |> mes("[Skrajjad]")
    |> mes("If you haven't already done")
    |> mes("so, please visit Keshibien,")
    |> mes("master of the Call Homunculus")
    |> mes("skill. He's a kind person who's")
    |> mes("always willing to go out of his")
    |> mes("way to help young scientists.")
    |> close()
  end

  defp teach_vaporize(ctx) do
    ctx
    |> mes("[Skrajjad]")
    |> mes("Ah, you're the one")
    |> mes("who had the courage")
    |> mes("to ask Kellasus to teach")
    |> mes("you Alchemy. I must say")
    |> mes("that I admire your attitude,")
    |> mes(reassurance(ctx))
    |> next()
    |> mes("[Skrajjad]")
    |> mes("I understand how you")
    |> mes("must feel after Kellasus")
    |> mes("refused to teach you his")
    |> mes("methods, but that does not")
    |> mes("mean that you'll never learn")
    |> mes("how to create a Homunculus.")
    |> next()
    |> mes("[Skrajjad]")
    |> mes("I believe you'll be able to learn what you desire if you manage to")
    |> mes("train under all of the Homunculus experts. When you show how serious")
    |> mes("you are about this, then Kellasus might change his mind about you.")
    |> next()
    |> mes("[Skrajjad]")
    |> mes("Let give teach you my")
    |> mes("Homunculus specialty,")
    |> mes("the ^FF0000Vaporize^000000 skill. Actually,")
    |> mes("it's useless without Kellasus's")
    |> mes("technique, but it should be a")
    |> mes("good enough starting point.")
    |> next()
    |> mes("[Skrajjad]")
    |> mes("The Vaporize skill")
    |> mes("is an Alchemist skill")
    |> mes("that deals solely with")
    |> mes("Homunculi. Vaporize is")
    |> mes("mastered at Skill Level 1.")
    |> next()
    |> mes("[Skrajjad]")
    |> mes("This skill allows you to")
    |> mes("reduce your Homunculus")
    |> mes("to vapor so that it is in an")
    |> mes("inert chemical state. It's")
    |> mes("very similar to hibernation")
    |> mes("when you think about it.")
    |> next()
    |> mes("[Skrajjad]")
    |> mes("Now, if you want to")
    |> mes("bring back a vaporized")
    |> mes("Homunculus, you will need")
    |> mes("to know the ^FF0000Call Homunculus^000000")
    |> mes("which you can learn from")
    |> mes("Keshibien. Just remember...")
    |> next()
    |> mes("[Skrajjad]")
    |> mes("Homunculi are living")
    |> mes("creatures, so don't go")
    |> mes("and vaporize and recall")
    |> mes("them recklessly. That sort")
    |> mes("of behavior would be inhumane.")
    |> next()
    |> mes("[Skrajjad]")
    |> mes("''Show respect for all life")
    |> mes("forms.'' That's the creed")
    |> mes("for the Homuculus expert.")
    |> mes("Now go and find ^FF0000Keshibien^000000")
    |> mes("so that he can teach you")
    |> mes("the Call Homunculus skill.")
    |> next()
    |> set_char_var(:bioeth, 5)
    |> mes("[Skrajjad]")
    |> mes("Good luck in")
    |> mes("your studies")
    |> mes("and I hope you")
    |> mes("find the answers")
    |> mes("that you are seeking.")
    |> close()
  end

  defp reassurance(ctx) do
    if sex(ctx) == 1,
      do: "young lad. Now, don't worry...",
      else: "young lass. Now, don't worry..."
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Skrajjad]")
    |> mes("Alchemy is wondrous...")
    |> mes("It incorporates every")
    |> mes("science and many other")
    |> mes("fields of knowledge that")
    |> mes("it's not enough to be jack")
    |> mes("of all trades... No...")
    |> next()
    |> mes("[Skrajjad]")
    |> mes("In a sense, you must")
    |> mes("be a master of all trades")
    |> mes("to be proficient in Alchemy.")
    |> mes("But it's incredibly rewarding to those of us who never stop asking")
    |> mes("how and why our world works.")
    |> close()
  end
end
