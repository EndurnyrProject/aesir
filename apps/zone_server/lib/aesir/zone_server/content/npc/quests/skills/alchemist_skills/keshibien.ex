defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Keshibien do
  @moduledoc """
  A Lighthalzen Alchemist who teaches the Call Homunculus lesson of the Bioethics quest.

  ## Behavior

  - At Bioethics step 5, explains Call Homunculus and its creation materials, then advances the
    quest to step 6.
  - Past that step, points the Alchemist to Broncher.
  - Otherwise greets visitors from Rune-Midgarts.

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
        x: 204,
        y: 138,
        dir: 5,
        sprite: 750,
        name: "Keshibien",
        scope: :shared,
        unique_name: "Keshibien#qsk_al"
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

  defp bioethics_step(ctx, bioeth) when bioeth > 5, do: already_taught(ctx)
  defp bioethics_step(ctx, 5), do: teach_call_homunculus(ctx)
  defp bioethics_step(ctx, _bioeth), do: greeting(ctx)

  defp already_taught(ctx) do
    ctx
    |> mes("[Keshibien]")
    |> mes("I hope that you")
    |> mes("can make good use")
    |> mes("of what I've taught you.")
    |> mes("I'm glad that I was able")
    |> mes("to contribute something to")
    |> mes("your learning of Alchemy.")
    |> next()
    |> mes("[Keshibien]")
    |> mes("Now, the only person qualified")
    |> mes("to teach you the Homunculus")
    |> mes("Resurrection skill is Brocher.")
    |> mes("He's... He's a character, but")
    |> mes("he's also a great teacher.")
    |> next()
    |> mes("[Keshibien]")
    |> mes("Now...")
    |> mes("Where could he be?")
    |> mes("I know he likes to drink,")
    |> mes("so maybe you can find him")
    |> mes("some place where they serve")
    |> mes("alcohol in Lighthalzen?")
    |> close()
  end

  defp teach_call_homunculus(ctx) do
    ctx
    |> mes("[Keshibien]")
    |> mes("Oh! You must be the")
    |> mes("one Skrajjad told me")
    |> mes("about. So you've come")
    |> mes("so I can teach you the")
    |> mes("Call Homunculus skill?")
    |> next()
    |> mes("[Keshibien]")
    |> mes("First of all, it's always")
    |> mes("a pleasure to meet another")
    |> mes("colleague. I'm Keshibien, and")
    |> mes("although I'm an expert on this")
    |> mes("particular skill, overall I'm just a run of the mill Alchemist.")
    |> next()
    |> mes("[Keshibien]")
    |> mes("Anyway, the Call Homunculus")
    |> mes("skill requires knowledge of the")
    |> mes("Vaporize skill and is mastered")
    |> mes("at Skill Level 1. This skill allows you to summon a Homunculus.")
    |> mes("Pretty simple so far, right?")
    |> next()
    |> mes("[Keshibien]")
    |> mes("Now, you can summon a")
    |> mes("vaporized Homunculus if")
    |> mes("you happen to have one.")
    |> mes("Otherwise, you can just")
    |> mes("create one through using")
    |> mes("this skill and these items...")
    |> next()
    |> mes("[Keshibien]")
    |> mes("^FF00001 Embryo^000000,")
    |> mes("^FF00001 Glass Tube^000000,")
    |> mes("^FF00001 Seed of Life^000000 and")
    |> mes("^FF00001 Morning Dew of Yggdrasil^000000.")
    |> next()
    |> mes("[Keshibien]")
    |> mes("Well, that's all the")
    |> mes("technical information")
    |> mes("I have to share with you.")
    |> mes("Always remember to treat")
    |> mes("your Homunculus well. Eh,")
    |> mes("once you summon one, anyway.")
    |> next()
    |> mes("[Keshibien]")
    |> mes("But before you can do")
    |> mes("that, you need to learn")
    |> mes("the techniques that only")
    |> mes("Kellasus can teach you.")
    |> mes("For now, go to ^FF0000Broncher^000000")
    |> mes("and learn from him, okay?")
    |> next()
    |> mes("[Keshibien]")
    |> mes("Broncher happens")
    |> mes("to specialize in the")
    |> mes("Homunculus Resurrection")
    |> mes("skill. You should be able to")
    |> mes("find him somewhere in town,")
    |> mes("though I'm unsure where...")
    |> next()
    |> set_char_var(:bioeth, 6)
    |> mes("[Keshibien]")
    |> mes("Anyway, it was really")
    |> mes("nice to meet you. Hopefully,")
    |> mes("you'll be able to learn how")
    |> mes("to fully use a Homunculus")
    |> mes("someday soon. Still, you'll")
    |> mes("need to convince Kellasus...")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Keshibien]")
    |> mes("Hello there~")
    |> mes("You must be from")
    |> mes("Rune-Midgarts, right?")
    |> mes("It's nice to meet you.")
    |> next()
    |> mes("[Keshibien]")
    |> mes("I hear that the")
    |> mes("Alchemists from")
    |> mes("over there are pretty")
    |> mes("skilled. I wonder if I'll")
    |> mes("ever get the chance to")
    |> mes("collaborate with any of them...")
    |> close()
  end
end
