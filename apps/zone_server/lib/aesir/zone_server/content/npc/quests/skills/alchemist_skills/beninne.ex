defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Beninne do
  @moduledoc """
  Kellasus's wife, who describes her husband as a stubborn but devoted family man.

  ## Behavior

  - Hints that Kellasus changes his mind once proven wrong, for Alchemists at Bioethics quest
    step 8 and for anyone at step 9.
  - Otherwise talks about being a scientist's wife.

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
        map: "lhz_in03",
        x: 109,
        y: 31,
        dir: 5,
        sprite: 90,
        name: "Beninne",
        scope: :shared,
        unique_name: "Beninne#qsk_al"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    bioeth = get_char_var(ctx, :bioeth, 0)

    if (alchemist?(ctx) and bioeth == 8) or bioeth == 9,
      do: husband_story(ctx),
      else: greeting(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp alchemist?(ctx), do: Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist)

  defp husband_story(ctx) do
    ctx
    |> mes("[Beninne]")
    |> mes("You've met my husband,")
    |> mes("Kellasus? He's either a")
    |> mes("very stubborn or determined")
    |> mes("man, depending on how you")
    |> mes("want to look at it. Once his")
    |> mes("mind's made up, he won't budge!")
    |> next()
    |> mes("[Beninne]")
    |> mes("He's a very good husband")
    |> mes("and father, but I feel like it")
    |> mes("takes the entire world to")
    |> mes("change his mind once he's ")
    |> mes("convinced that he's right")
    |> mes("about something.")
    |> next()
    |> mes("[Beninne]")
    |> mes("Of course, if you manage")
    |> mes("to prove him wrong, he will")
    |> mes("do everything he can to make")
    |> mes("up for it. Kellasus has been")
    |> mes("like that since I first met him.")
    |> next()
    |> mes("[Beninne]")
    |> mes("It feels so nice to")
    |> mes("have someone like that")
    |> mes("to be protective of you.")
    |> mes("Kellasus loves his work,")
    |> mes("but he loves his family even")
    |> mes("more. Amazing, isn't it?")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Beninne]")
    |> mes("Most people think that")
    |> mes("being a scientist's wife")
    |> mes("would be so difficult. I must")
    |> mes("be lucky that my husband is")
    |> mes("such a good family man, even")
    |> mes("though he may be an Alchemist.")
    |> close()
  end
end
