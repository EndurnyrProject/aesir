defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Koring do
  @moduledoc """
  Kellasus's young son, who idolizes his father.

  ## Behavior

  - For Alchemists at Bioethics quest step 8, and anyone at step 9, recalls how his father fought
    to cure his illness, advancing step 8 to step 9.
  - Otherwise talks about wanting to become an Alchemist.

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
        x: 106,
        y: 34,
        dir: 3,
        sprite: 706,
        name: "Koring",
        scope: :shared,
        unique_name: "Koring#qsk_al"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    bioeth = get_char_var(ctx, :bioeth, 0)

    if (alchemist?(ctx) and bioeth == 8) or bioeth == 9,
      do: illness_story(ctx, bioeth),
      else: greeting(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp alchemist?(ctx), do: Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist)

  defp illness_story(ctx, bioeth) do
    ctx
    |> mes("[Koring]")
    |> mes("My daddy is the bestest")
    |> mes("Alchemist! He's sooooo")
    |> mes("smart, and I never heard")
    |> mes("him be wrong before!")
    |> next()
    |> mes("[Koring]")
    |> mes("Daddy's been thinking")
    |> mes("a lot lately and I don't")
    |> mes("know why. Daddy gets ")
    |> mes("really serious when he's ")
    |> mes("worried about something.")
    |> next()
    |> mes("[Koring]")
    |> mes("He's always trying hard")
    |> mes("to make me happy and to ")
    |> mes("help me when I have problems.")
    |> mes("Like the time I was really sick...")
    |> next()
    |> mes("[Koring]")
    |> mes("Daddy did his best to make")
    |> mes("some medicine to help me, ")
    |> mes("and he looked all over for any")
    |> mes("doctor who could cure me. For")
    |> mes("a while, I was really scared,")
    |> mes("but my Daddy never gave up.")
    |> next()
    |> advance_step(bioeth)
    |> mes("[Koring]")
    |> mes("He might be a little")
    |> mes("grumpy now, but my ")
    |> mes("Daddy is still the best!")
    |> mes("I hope he feels better soon.")
    |> close()
  end

  defp advance_step(ctx, 8), do: set_char_var(ctx, :bioeth, 9)
  defp advance_step(ctx, _bioeth), do: ctx

  defp greeting(ctx) do
    ctx
    |> mes("[Koring]")
    |> mes("How did my Daddy get")
    |> mes("so smart? I wish I could")
    |> mes("learn things as fast as")
    |> mes("him so that I can be an")
    |> mes("Alchemist too when I grow up!")
    |> close()
  end
end
