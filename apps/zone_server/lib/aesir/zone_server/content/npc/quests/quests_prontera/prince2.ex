defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Prince2 do
  @moduledoc """
  The second prince’s body provides a clue to the Geoborg family curse.

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
        x: 21,
        y: 111,
        dir: 5,
        sprite: 887,
        name: "",
        scope: :shared,
        unique_name: "#prince2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :prt_curse, 0)

    cond do
      stage == 20 -> examine_prince(ctx)
      stage == 33 or stage in 42..50 or stage == 52 -> test_solution(ctx)
      true -> describe_body(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp examine_prince(ctx) do
    ctx =
      ctx
      |> mes("[Father Bamph]")
      |> mes("This is the body of the")
      |> mes("second prince. The curse")
      |> mes("is only supposed to kill")
      |> mes("the firstborn prince, but")
      |> mes("all three princes of this")
      |> mes("generation were killed...")
      |> next()
      |> mes("[Father Bamph]")
      |> mes("Despite our great efforts")
      |> mes("to exorcise this powerful")
      |> mes("curse, we all failed. Those")
      |> mes("involved have begun to believe")
      |> mes("that Odin may have abandoned us... ")

    ctx =
      ctx
      |> emotion(:huk, playerattached(ctx))
      |> next()
      |> mes("^3355FFYou examine the body of")
      |> mes("the second prince and notice")
      |> mes("that the scale marks on his")
      |> mes("skin are fainter, and slightly")
      |> mes("different in color, than the")
      |> mes("marks on the first prince.^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Father Bamph...!")
    |> mes("Look, these marks are")
    |> mes("different on the second")
    |> mes("prince than on the first")
    |> mes("prince! See? They're different")
    |> mes("in darkness and coloration.")
    |> next()
    |> mes("[Father Bamph]")
    |> mes("Goodness, you're right!")
    |> mes("How did we overlook this?")
    |> mes("Hm, this supports the idea")
    |> mes("that a conspiracy may be")
    |> mes("involved. Let's go check")
    |> mes("the body of the third prince.")
    |> set_char_var(:prt_curse, 21)
    |> close()
  end

  defp test_solution(ctx) do
    ctx
    |> specialeffect(:poisonattack)
    |> specialeffect(:poisonhit)
    |> specialeffect(:bubble)
    |> mes("^3355FFYou poured a little of the")
    |> mes("solution made from Green")
    |> mes("Potion and Yellow Gemstone")
    |> mes("on the body's scale marks. The")
    |> mes("scale marks grow fainter and")
    |> mes("the solution bubbles on contact. ")
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
