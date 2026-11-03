defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.KnightSkills.GrandMaster do
  @moduledoc """
  Grand Master who oversees the Knights' daily training in Prontera during the Charge Attack
  skill quest.

  ## Behavior

  - At quest steps 2 and 3, tells his men to take it easy, advancing step 2 to 3.
  - Otherwise shouts at the Knights to train harder before calling for a break.

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
      %{map: "prontera", x: 72, y: 352, dir: 7, sprite: 733, name: "Grand Master", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Grand Master]")

    if get_char_var(ctx, :KNGT_SK, 0) in [2, 3] do
      take_it_easy(ctx)
    else
      drill(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp take_it_easy(ctx) do
    ctx =
      ctx
      |> mes("Alright men, you don't")
      |> mes("need to put ^333333that^000000 much effort")
      |> mes("into your training. You have")
      |> mes("to do this everyday, so make")
      |> mes("sure that you don't exhaust")
      |> mes("yourselves unnecessarily.")
      |> next()
      |> mes("[Grand Master]")
      |> mes("The most important thing")
      |> mes("is that you don't injure")
      |> mes("yourselves. Take it easy")
      |> mes("and make sure that you")
      |> mes("don't pull a muscle.")
      |> mes("Um, that's an order!")

    ctx
    |> advance_from(get_char_var(ctx, :KNGT_SK, 0))
    |> close()
  end

  defp advance_from(ctx, 2), do: set_char_var(ctx, :KNGT_SK, 3)
  defp advance_from(ctx, _step), do: ctx

  defp drill(ctx) do
    ctx
    |> mes("Put your backs into it,")
    |> mes("men! I know training can")
    |> mes("be tough, but it'll make")
    |> mes("you harder, better, faster and")
    |> mes("stronger! Prontera's safety is your responsibility, Knights!")
    |> next()
    |> mes("[Grand Master]")
    |> mes("...")
    |> mes("Oh, I'm just kidding around.")
    |> mes("Let's go take a break, guys.")
    |> close()
  end
end
