defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.KnightSkills.Knight78354 do
  @moduledoc """
  Zabi, a Knight in Prontera who only pretends to train, met during the Charge Attack skill
  quest.

  ## Behavior

  - At quest steps 3 and 4, confides his plan to coast to a pension, advancing step 3 to 4.
  - Otherwise grunts through his training exercises.

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
        x: 78,
        y: 354,
        dir: 3,
        sprite: 734,
        name: "Knight",
        scope: :shared,
        unique_name: "Knight#zabii"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :KNGT_SK, 0) in [3, 4] do
      confide(ctx)
    else
      grunt(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp confide(ctx) do
    ctx =
      ctx
      |> mes("[Zabi]")
      |> mes("I guess we're more like")
      |> mes("government employees")
      |> mes("than actual Knights. We're")
      |> mes("overpaid, and don't really")
      |> mes("have to do anything other")
      |> mes("than pretend to train.")
      |> next()
      |> mes("[Zabi]")
      |> mes("Me? I plan on milking")
      |> mes("the system for all it's")
      |> mes("worth. Work here a few")
      |> mes("years, then live the rest")
      |> mes("of my life on a fat pension.")
      |> mes("Yeah, that's gonna be great.")
      |> next()
      |> mes("[Zabi]")
      |> mes("Whoa-whoa-whoa,")
      |> mes("the Grand Master's")
      |> mes("looking this way! Quit")
      |> mes("talkin' to me and let me")
      |> mes("grunt like I've got a hernia.")
      |> mes("Hooooo-AH! BWAH! HAI-YAH!")

    ctx
    |> advance_from(get_char_var(ctx, :KNGT_SK, 0))
    |> close()
  end

  defp advance_from(ctx, 3), do: set_char_var(ctx, :KNGT_SK, 4)
  defp advance_from(ctx, _step), do: ctx

  defp grunt(ctx) do
    ctx
    |> mes("[A Knight]")
    |> mes("Hooooo-AH!")
    |> mes("BWAH! HAI-YAH!")
    |> mes("Oh man, I can barely")
    |> mes("breathe from all of this")
    |> mes("arduous training. Ugh,")
    |> mes("so incredibly enervated...")
    |> close()
  end
end
