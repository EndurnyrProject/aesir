defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Prince1 do
  @moduledoc """
  The first prince’s body provides a clue to the Geoborg family curse.

  ## Behavior

  - The investigation and poison test change the examination.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 19,
        y: 111,
        dir: 5,
        sprite: 887,
        name: "",
        scope: :shared,
        unique_name: "#prince1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :prt_curse, 0)

    cond do
      stage == 19 -> examine_prince(ctx)
      stage == 33 or stage in 42..50 or stage == 52 -> test_solution(ctx)
      true -> describe_body(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp examine_prince(ctx) do
    ctx
    |> mes("[Father Bamph]")
    |> mes("This is the body of")
    |> mes("the king's first son, the")
    |> mes("crown prince. Just as it has")
    |> mes("happened for generations,")
    |> mes("the curse took the life of")
    |> mes("the first born prince...")
    |> next()
    |> mes("^3355FFBeneath one of the")
    |> mes("prince's sleeves, you")
    |> mes("notice a dark mark. Upon")
    |> mes("pulling up the sleeve, you")
    |> mes("note that the mark resembles")
    |> mes("the scales of a serpent.^000000")
    |> set_char_var(:prt_curse, 20)
    |> close()
  end

  defp test_solution(ctx) do
    ctx
    |> mes("^3355FFYou poured a little bit")
    |> mes("of the solution made from")
    |> mes("Yellow Gemstone and Green")
    |> mes("Potion on the mark on the skin.")
    |> mes("You waited a while, but there was no reaction from the solution.^000000")
    |> close()
  end

  defp describe_body(ctx) do
    ctx
    |> mes("^3355FFIt's the body of a male")
    |> mes("dressed in luxurious robes.")
    |> mes("Although deceased, the color")
    |> mes("of life has not yet left the body. ")
    |> close()
  end
end
