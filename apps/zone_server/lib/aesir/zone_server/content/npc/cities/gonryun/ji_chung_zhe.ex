defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.JiChungZhe do
  @moduledoc """
  Reveals a worried tea brewer's search for an unusual ingredient as a quest progresses.

  ## Behavior

  - Remains worried during the early Nakha quest stages.
  - At stage three, explains his hope of brewing tea with a snake.
  - Says nothing for any other quest value.

  ## Credits

  - Original from rAthena, authors and Contributors
    - x[tsk]
    - KarLaeda

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gon_in",
        x: 73,
        y: 82,
        dir: 5,
        sprite: 778,
        name: "Ji Chung Zhe",
        scope: :shared,
        unique_name: "Ji Chung Zhe#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :nakha, 0) do
      stage when stage >= 0 and stage <= 2 -> express_worry(ctx)
      3 -> discuss_snake_tea(ctx)
      _ -> ctx
    end
  end

  defp express_worry(ctx) do
    ctx
    |> mes("[Ji Chung Zhe]")
    |> mes("............")
    |> next()
    |> mes("[Ji Chung Zhe]")
    |> mes("puuuuu....This sure is")
    |> mes("something to worry about.")
    |> close()
  end

  defp discuss_snake_tea(ctx) do
    ctx
    |> mes("[Ji Chung Zhe]")
    |> mes("I am Ji Chung Zhe, a renown brewer")
    |> mes("of teas. Everyday, I put all my")
    |> mes("efforts in making scrumptious, delicious tea.")
    |> next()
    |> mes("[Ji Chung Zhe]")
    |> mes("*Sigh* But lately, the tea I've")
    |> mes("been making hasn't been that")
    |> mes("great... If I only had some special ingredients...")
    |> next()
    |> mes("[Ji Chung Zhe]")
    |> mes("I've been told that if you use")
    |> mes("a snake, you can concoct a truly")
    |> mes("extraordinary beverage~")
    |> mes("But...where can I find one")
    |> mes("and how can I catch one?")
    |> mes("Hmm...")
    |> close()
  end
end
