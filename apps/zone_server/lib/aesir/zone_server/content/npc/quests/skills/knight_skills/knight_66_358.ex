defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.KnightSkills.Knight66358 do
  @moduledoc """
  Gatack, a self-described weak Knight training in Prontera who drops a hint during the Charge
  Attack skill quest.

  ## Behavior

  - At quest step 7, complains about Essofeit and reveals the Candy Canes and Witherless Roses
    he expects Knights to hunt.
  - Otherwise grumbles about how rough Knight training is.

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
        x: 66,
        y: 358,
        dir: 5,
        sprite: 733,
        name: "Knight",
        scope: :shared,
        unique_name: "Knight#gattack"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Gatack]")

    if get_char_var(ctx, :KNGT_SK, 0) == 7 do
      complain_about_essofeit(ctx)
    else
      grumble(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp complain_about_essofeit(ctx) do
    ctx
    |> mes("Wait, where's")
    |> mes("Essofeit? He can't")
    |> mes("just skip daily training,")
    |> mes("even if he has the distinction")
    |> mes("of killing countless ^FF0000Mystcases^000000")
    |> mes("and ^FF0000Obeaunes^000000 in his time.")
    |> next()
    |> mes("[Gatack]")
    |> mes("Gosh, I'm sick and tired of")
    |> mes("him talking about Knighthood.")
    |> mes("Essofeit insists that all Knights, even complete rookies, should be")
    |> mes("able to obtain 5 Candy Canes and 3 Witherless Roses from hunting.")
    |> next()
    |> mes("[Gatack]")
    |> mes("Hell, I just hate to hear")
    |> mes("his preaching about his great")
    |> mes("experiences fighting monsters.")
    |> mes("But now Essofeit just researches stuff inside the building and")
    |> mes("doesn't do much else...")
    |> close()
  end

  defp grumble(ctx) do
    ctx
    |> mes("Man, Knight training")
    |> mes("is pretty rough. Don't")
    |> mes("they know that I'm far")
    |> mes("too delicate for all this")
    |> mes("strenuous activity?")
    |> next()
    |> mes("[Gatack]")
    |> mes("Ah well, if I ever go")
    |> mes("down in battle, I won't")
    |> mes("be too surprised, seeing")
    |> mes("as I'm one of the weakest")
    |> mes("guys here. But when it happens,")
    |> mes("I'll be too busy looking good.")
    |> close()
  end
end
