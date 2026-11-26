defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.RuneDevice195195 do
  @moduledoc """
  Runs the yellow key number puzzle.

  ## Behavior

  - Awards the yellow key and reveals a quest message when eligible.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tha_t04",
        x: 195,
        y: 195,
        dir: 0,
        sprite: 111,
        name: "Rune Device",
        scope: :shared,
        unique_name: "Rune Device#tt2",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    if count_item(ctx, 7422) == 0 and count_item(ctx, 7427) == 0 do
      specialeffect(ctx, :level99_4)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7422) == 0 and count_item(ctx, 7427) == 0 do
      ctx
      |> mes("^3355FFYou find a screen")
      |> mes("with three tiny panels and")
      |> mes("a numeric keypad underneath.")
      |> mes("As you press one of the")
      |> mes("number keys, you hear a")
      |> mes("beep as the screen activates.^000000")
      |> next()
      |> mes("[Screen]")
      |> mes("Please enter a 3 digit")
      |> mes("number. Do not use a")
      |> mes("single number more than")
      |> mes("once or use the number 0.")
      |> next()
      |> guess(secret_number(), 0)
    else
      ctx |> mes("You've acquired everything you need from this rune device.") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp secret_number do
    a = Enum.random(1..9)
    b = Enum.random(1..9)
    c = Enum.random(1..9)

    if a != b and a != c and b != c, do: {a, b, c}, else: secret_number()
  end

  defp guess(ctx, secret, retries) do
    {ctx, number} = input(ctx, :int)

    cond do
      number < 100 or number > 999 ->
        ctx
        |> mes("[Screen]")
        |> mes("Number input")
        |> mes("requirement has")
        |> mes("not been fulfilled.")
        |> mes("Please enter a")
        |> mes("3 digit number.")
        |> close()

      true ->
        digits = {div(number, 100), div(rem(number, 100), 10), rem(number, 10)}
        check_guess(ctx, secret, retries, digits)
    end
  end

  defp check_guess(ctx, secret, retries, {a, b, c} = digits) do
    cond do
      b == 0 or c == 0 ->
        guess(ctx, secret, retries)

      a == b or a == c or b == c ->
        ctx
        |> mes("[Screen]")
        |> mes("Violation of number")
        |> mes("input parameter. The")
        |> mes("number 0 has been input,")
        |> mes("or a number has been")
        |> mes("input more than once.")
        |> next()
        |> guess(secret, retries)

      true ->
        evaluate_guess(ctx, secret, retries + 1, digits)
    end
  end

  defp evaluate_guess(ctx, {x, y, z} = secret, retries, {a, b, c}) do
    ctx =
      ctx
      |> mes("[Screen]")
      |> mes("You have input...")
      |> mes("^0000ff#{a}^000000, ^0000ff#{b}^000000, ^0000ff#{c}^000000")
      |> mes(" ")
      |> mes("Calculating Results...")
      |> mes("Please wait a moment...")
      |> next()

    strikes = Enum.count([{x, a}, {y, b}, {z, c}], fn {left, right} -> left == right end)
    balls = Enum.count([{x, [b, c]}, {y, [a, c]}, {z, [a, b]}], fn {n, others} -> n in others end)

    if strikes == 3 do
      yellow_key(ctx)
    else
      ctx =
        ctx
        |> mes("[Screen]")
        |> mes("*Beeeeep*")
        |> mes("Unauthorized")
        |> mes("numerical sequence.")
        |> next()
        |> mes("[Screen]")
        |> mes("Correct number")
        |> mes("in correct place")
        |> mes("in sequence total: ^FF0000#{strikes}^000000")
        |> mes(" ")
        |> mes("Correct number total: ^FF0000#{balls}^000000")
        |> next()

      if retries > 4 do
        ctx
        |> mes("[Screen]")
        |> mes("Correct number")
        |> mes("authorization")
        |> mes("sequence was...")
        |> mes("^ff0000#{x}^000000, ^ff0000#{y}^000000, ^ff0000#{z}^000000")
        |> mes("Authorization number")
        |> mes("will change upon retry.")
        |> close()
      else
        guess(ctx, secret, retries)
      end
    end
  end

  defp yellow_key(ctx) do
    ctx =
      ctx
      |> mes("[Screen]")
      |> mes("Input number accepted.")
      |> mes("Access authorized.")
      |> next()
      |> mes("^3355FFAfter the screen displays")
      |> mes("the access authorization")
      |> mes("notice, magical power condenses")
      |> mes("and appears on the screen's")
      |> mes("surface. An object forms...^000000")
      |> next()
      |> mes("^4d4dffThe powerful Yellow Key appears.^000000")
      |> give_item(7422, 1)

    if get_char_var(ctx, :thana_tower, 0) != 5 do
      close(ctx)
    else
      key_vision(ctx)
    end
  end

  defp key_vision(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^4d4dffA fierce feeling passes through your head.")
      |> mes("You seen an illusion of light, like when you acquired the first key.^000000")
      |> next()
      |> select(["Ignore it.", "Concentrate on it."])

    case choice do
      1 -> ctx |> mes("You decide to ignore it.") |> close()
      2 -> key_message(ctx)
      _ -> ctx
    end
  end

  defp key_message(ctx) do
    ctx
    |> mes("You focus on the light.")
    |> mes("Some letters begin to appear...")
    |> next()
    |> mes("^b22222Have you found the second key?")
    |> mes("I wish to tell you where the seal is, but I won't unveil it so easily.")
    |> mes("Here's a hint. Go to the eagle on the 5th floor.")
    |> next()
    |> mes("^b22222The reason I came here is...")
    |> mes("to find someone.")
    |> mes("We human beings can't understand this...")
    |> next()
    |> mes("^b22222When I found her in Juperos, I couldn't relax.")
    |> mes("The giant men staying with her in deep side of cave")
    |> mes("made me rush through my investigation...")
    |> next()
    |> mes(
      "^b22222After confirming her existence, I became blindly obsessed with finding traces of her."
    )
    |> mes("'Her', you ask? She is shaped like a woman...")
    |> next()
    |> mes("^b22222I followed her traces without knowing that she existed 10 years earlier.")
    |> mes("Then I came upon this place.")
    |> next()
    |> mes("^b22222This tower set up for...^000000")
    |> next()
    |> mes("It suddenly shakes, then disappears.")
    |> set_char_var(:thana_tower, 6)
    |> changequest(7049, 7050)
    |> specialeffect2(:comboattack1)
    |> close()
  end
end
