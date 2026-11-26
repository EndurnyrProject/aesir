defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.BrilliantStatue226230 do
  @moduledoc """
  A brilliant statue conceals a wheel puzzle and the Green Key.

  ## Behavior

  - Requires three keys to access the wheel puzzle and awards the Green Key when aligned.
  - Reveals a vision and advances the quest when the fourth spell is released.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Aligning all wheels now ends the wheel loop and grants the key; the generated module crashed there.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tha_t06",
        x: 226,
        y: 230,
        dir: 0,
        sprite: 111,
        name: "Brilliant Statue",
        scope: :shared,
        unique_name: "Brilliant Statue#tt4",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    if count_item(ctx, 7424) == 0 and count_item(ctx, 7429) == 0 do
      specialeffect(ctx, :level99_4)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7424) == 0 and count_item(ctx, 7429) == 0 do
      investigate(ctx)
    else
      ctx
      |> mes(
        "The spell is already released. You've acquired everything you need from this statue."
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp investigate(ctx) do
    {ctx, choice} =
      ctx
      |> mes("I can feel some magical power from this brilliant statue.")
      |> mes("This must be one of the seals.")
      |> next()
      |> mes("You see a floating round object with a hole in it.")
      |> mes("There're red, yellow, and blue light in a row.")
      |> mes("What will you do?")
      |> next()
      |> select(["Investigate.", "Ignore it."])

    cond do
      choice == 2 ->
        ctx
        |> mes("^3355FFYou don't see the need to")
        |> mes("investigate if nothing seems")
        |> mes("peculiar or out of place...^000000")
        |> close()

      count_item(ctx, 7421) > 0 and count_item(ctx, 7422) > 0 and count_item(ctx, 7423) > 0 ->
        machine(ctx)

      true ->
        ctx |> mes("You don't have the right key for this keyhole.") |> close()
    end
  end

  defp machine(ctx) do
    {ctx, choice} =
      ctx
      |> mes("When you insert the key into the keyhole of the ornament")
      |> mes("and match them by corresponding color, the Stone Statue will snap open.")
      |> mes("You can see small wheels are moving inside.")
      |> next()
      |> select(["Investigate the Machine Chasis", "Investigate the Wheels", "Cancel"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFThe key in your inventory")
        |> mes("does not seem to be affecting")
        |> mes("the machine's chasis. The")
        |> mes("screen mounted on the side")
        |> mes("is still blank and deactivated.^000000")
        |> close()

      2 ->
        wheel_intro(ctx)

      3 ->
        ctx |> mes("You decide to ignore it.") |> close()

      _ ->
        ctx
    end
  end

  defp wheel_intro(ctx) do
    ctx
    |> mes("^3355FFYou touch the wheels and")
    |> mes("find that they are actually")
    |> mes("moving very slowly. You note")
    |> mes("that there are 2 small wheels")
    |> mes("and 3 larger wheels, totaling")
    |> mes("5 wheels on this machine.^000000")
    |> next()
    |> mes("^3355FFThe big wheels are moving")
    |> mes("vertically, up and down, as")
    |> mes("they press against the smaller")
    |> mes("wheels to make them rotate.^000000")
    |> next()
    |> mes("^3355FFJudging from the machine's")
    |> mes("shaking and jittery noises, the")
    |> mes("wheels may be misaligned.")
    |> mes("You might be able to activate")
    |> mes("the machine by properly ")
    |> mes("aligning all the wheels.^000000")
    |> adjust_wheels({0, 0, 0, 0, 0})
    |> finish_wheels()
  end

  defp adjust_wheels(ctx, wheels) do
    {ctx, choice} =
      ctx
      |> next()
      |> mes("^3355FFWhich wheel do")
      |> mes("you want to shift?^000000")
      |> select([
        "1st Small Wheel",
        "2nd Small Wheel",
        "1st Big Wheel",
        "2nd Big Wheel",
        "3rd Big Wheel",
        "Check Current Wheel Configuration",
        "Reset Wheels to Default Configuration"
      ])

    case choice do
      wheel when wheel in 1..5 -> shift_wheel(ctx, wheels, wheel)
      6 -> ctx |> show_wheels(wheels) |> adjust_wheels(wheels)
      7 -> adjust_wheels(ctx, {0, 0, 0, 0, 0})
      _ -> {:halt, ctx}
    end
  end

  defp shift_wheel(ctx, wheels, wheel) do
    options =
      if wheel <= 2,
        do: ["Raise Wheel", "Lower Wheel", "Press Wheel"],
        else: ["Raise Wheel", "Lower Wheel", "Vertically Shift Wheel"]

    {ctx, choice} = select(ctx, options)

    case choice do
      action when action in 1..3 ->
        value =
          elem(
            elem({{2, 1, 3}, {3, 2, 1}, {1, 3, 2}, {2, 3, 1}, {2, 1, 3}}, wheel - 1),
            action - 1
          )

        sound =
          elem(
            {"^00B2EE*Sneeeep*^000000", "^EE0000*Choom*^000000", "^5C246E*Mrreeem*^000000"},
            value - 1
          )

        ctx = mes(ctx, sound)
        wheels = put_elem(wheels, wheel - 1, value)

        if wheels == {value, value, value, value, value},
          do: {:aligned, ctx},
          else: adjust_wheels(ctx, wheels)

      _ ->
        {:halt, ctx}
    end
  end

  defp show_wheels(ctx, wheels) do
    labels = [
      {"1st Small Wheel", {"No Change", "Down", "Up", "Pressed"}},
      {"2nd Small Wheel", {"No Change", "Pressed", "Down", "Up"}},
      {"1st Big Wheel", {"No Change", "Up", "Moved", "Down"}},
      {"2nd Big Wheel", {"No Change", "Moved", "Up", "Down"}},
      {"3rd Big Wheel", {"No Change", "Down", "Up", "Moved"}}
    ]

    labels
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {{label, states}, index}, ctx ->
      mes(ctx, "#{label}: #{elem(states, elem(wheels, index))}")
    end)
  end

  defp finish_wheels({:halt, ctx}), do: ctx
  defp finish_wheels({:aligned, ctx}), do: reward(ctx)

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("As you adjust the wheels,")
      |> mes("they suddenly activate")
      |> mes("with a firm click.")
      |> next()
      |> mes("A part of the ornament in the stone statue starts to spin,")
      |> mes("and a shining light beam climbs up the elegant statue.")
      |> mes("A strong cursed power emerges and emits a dazzling green light.")
      |> specialeffect(:dispell)
      |> specialeffect(:potion6)
      |> next()
      |> mes(
        "^4d4dffAll of a sudden, the Green Key appears and you can feel great power from it.^000000"
      )
      |> give_item(7424, 1)

    if get_char_var(ctx, :thana_tower, 0) != 7 do
      close(ctx)
    else
      hallucination(ctx)
    end
  end

  defp hallucination(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^4d4dffWhen you pick up the key,")
      |> mes("your body trembles")
      |> mes("with an unknown power")
      |> mes("and you see a hallucination with some text.^000000")
      |> next()
      |> select(["Concentrate on it.", "Ignore it."])

    case choice do
      1 ->
        vision(ctx)

      2 ->
        ctx
        |> mes("It was too intense to see the hallucination, so you gave up reading.")
        |> close()

      _ ->
        ctx
    end
  end

  defp vision(ctx) do
    ctx =
      ctx
      |> mes("^b22222...You found 4 keys")
      |> mes("and finally released 4 spells...")
      |> mes("This tower used to be")
      |> mes("a gate to summon demons ages ago.")
      |> mes("And the last visitor was")
      |> mes("the infamous Satan Morocc.")
      |> next()
      |> mes("^b22222As I followed her trail")
      |> mes("I realized that her spells")
      |> mes("were scattered around the tower.")
      |> mes("Then, somehow, it vanished into the ground.")
      |> next()
      |> mes("^b22222The great battle and")
      |> mes("the protracted war...")
      |> mes("But her purpose was...")
      |> mes("that... sealing of the gate...")
      |> mes("so... I tried to seal...")
      |> mes("but it was incomplete...")
      |> mes("the guard of the gate was...^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("It is hard to read.")
    |> next()
    |> mes("^b22222...So I changed the location")
    |> mes("of the coupling spot...")
    |> mes("I mean, push through to the tower")
    |> mes("to tangle it...")
    |> mes("Anyway, I wanted to respect")
    |> mes("her loyalty and block the gate...")
    |> next()
    |> mes("^b22222If I want to... then I have to")
    |> mes("release the last spell...")
    |> mes("He finally came to meet...")
    |> mes("with his pieces...")
    |> mes("...and then...^000000")
    |> next()
    |> mes("The hallucination wobbles")
    |> mes("and fades into the key.")
    |> set_char_var(:thana_tower, 8)
    |> changequest(7051, 7052)
    |> specialeffect2(:beginspell6)
    |> specialeffect2(:spellbreaker)
    |> close()
  end
end
