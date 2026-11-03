defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.KnightSkills.Knight73357 do
  @moduledoc """
  Gon, a Knight training in Prontera who dreams of payday during the Charge Attack skill quest.

  ## Behavior

  - At quest steps 4 and 5, talks about buying his wife a necklace, advancing step 4 to 5.
  - Otherwise explains why the Knight position is a good job.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - DracoRPG
    - Samuray22
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 73,
        y: 357,
        dir: 5,
        sprite: 734,
        name: "Knight",
        scope: :shared,
        unique_name: "Knight#drake"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :KNGT_SK, 0) in [4, 5] do
      payday(ctx)
    else
      good_job(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp payday(ctx) do
    ctx =
      ctx
      |> mes("[Gon]")
      |> mes("What'll I get with")
      |> mes("my next paycheck?")
      |> mes("Ah~ I should get a nice")
      |> mes("necklace for my wife.")
      |> mes("I just know she'll love it!")
      |> next()

    ctx
    |> advance_from(get_char_var(ctx, :KNGT_SK, 0))
    |> mes("[Gon]")
    |> mes("Let's see, how many")
    |> mes("more days until payday?")
    |> mes("One, two... Hmm. For some")
    |> mes("reason it never seems to")
    |> mes("come soon enough, you know?")
    |> close()
  end

  defp advance_from(ctx, 4), do: set_char_var(ctx, :KNGT_SK, 5)
  defp advance_from(ctx, _step), do: ctx

  defp good_job(ctx) do
    ctx
    |> mes("[A Knight]")
    |> mes("Maybe I'm not not so good")
    |> mes("at fighting or defending the")
    |> mes("weak, but this Knight position")
    |> mes("is a pretty good job. Working")
    |> mes("here really lets me save up")
    |> mes("cash to invest in my future.")
    |> next()
    |> mes("[A Knight]")
    |> mes("We may never get to see")
    |> mes("any action, but at least")
    |> mes("I can take some pride")
    |> mes("in being a Knight.")
    |> close()
  end
end
