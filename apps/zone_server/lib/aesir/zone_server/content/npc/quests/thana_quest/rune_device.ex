defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.RuneDevice do
  @moduledoc """
  Guards the red key behind an energy field.

  ## Behavior

  - Awards the red key and reveals a quest message when eligible.

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
        map: "tha_t03",
        x: 67,
        y: 70,
        dir: 0,
        sprite: 111,
        name: "Rune Device",
        scope: :shared,
        unique_name: "Rune Device#tt1",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    if count_item(ctx, 7421) == 0 and count_item(ctx, 7426) == 0 do
      specialeffect(ctx, :level99_4)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7421) == 0 and count_item(ctx, 7426) == 0 do
      investigate_choice(ctx)
    else
      ctx |> mes("You've acquired everything you need from this rune device.") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp investigate_choice(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFA mysterious field of")
      |> mes("energy seems to surround")
      |> mes("the mechanical device and")
      |> mes("its power prevents you from")
      |> mes("approaching the machine.^000000")
      |> next()
      |> select(["Investigate it.", "I don't care about it."])

    case choice do
      1 -> investigate(ctx)
      2 -> ctx |> mes("^3355FFYou decide to leave") |> mes("the machine alone.^000000") |> close()
      _ -> ctx
    end
  end

  defp investigate(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("This seems mysterious...")
      |> mes("Let me investigate.")
      |> next()
      |> mes(
        "^3355FFAs you follow the magical power, there's something wrapped inside the rune device.^000000"
      )
      |> next()

    cond do
      Rathena.job_id(class(ctx)) == Rathena.job_id(:taekwon) ->
        ctx
        |> mes("^3355FFYou kick the energy")
        |> mes("field with all of your strength. After absorbing the impact, the")
        |> mes("field fizzles out with a soft,")
        |> mes("gentle ''pzzzzzh'' sound.^000000")
        |> next()
        |> red_key()

      getequipweaponlv(ctx, 9) == 4 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("^3355FFWith your ", getequipname(ctx, 9)), " in"))
        |> mes("hand, you smash the energy")
        |> mes("field with all of your strength. After absorbing the impact, the")
        |> mes("field fizzles out with a soft,")
        |> mes("gentle ''pzzzzzh'' sound.^000000")
        |> next()
        |> red_key()

      true ->
        ctx
        |> mes("^3355FFYou smash the energy")
        |> mes("field with your weapon")
        |> mes("using all of your strength,")
        |> mes("but you weren't able to")
        |> mes("break down the barrier.")
        |> mes("You probably need a more")
        |> mes("powerful weapon...^000000")
        |> close()
    end
  end

  defp red_key(ctx) do
    ctx =
      ctx
      |> specialeffect(:brandish2)
      |> mes("After breaking the device, the exterior shatters.")
      |> mes("The energy field begins to disappear,")
      |> mes("and you see that a red object inside was the origin of the magical power.")
      |> next()
      |> mes("- You acquired the powerful Red Key. -")
      |> give_item(7421, 1)

    if get_char_var(ctx, :thana_tower, 0) != 4 do
      close(ctx)
    else
      key_vision(ctx)
    end
  end

  defp key_vision(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^4d4dffOnce you hold the key, a shocking feeling passes through your head.")
      |> mes("You see an illusion of light...^000000")
      |> next()
      |> select(["Ignore it.", "Concentrate on it."])

    case choice do
      1 -> ctx |> mes("^3355FFYou decide to leave") |> mes("the machine alone.^000000") |> close()
      2 -> key_message(ctx)
      _ -> ctx
    end
  end

  defp key_message(ctx) do
    ctx
    |> mes("You focus on the light.")
    |> mes("Some letters begin to appear...")
    |> next()
    |> mes("^b22222I've used the Gate Seal")
    |> mes("technology to seal the gate")
    |> mes("and the charm stones. Although")
    |> mes("the seals are in place, I can't")
    |> mes("stop worrying that they might")
    |> mes("break in the future.")
    |> next()
    |> mes("^b22222I can't relax when a, shall")
    |> mes("I say, particular group covets")
    |> mes("the charm stones and can easily")
    |> mes("break the seals. Since they are")
    |> mes("broken now, are many people hurt?")
    |> next()
    |> mes("^b22222This tower contains strong")
    |> mes("magical powers and much evil. It is")
    |> mes("dangerous by itself, but I sealed it")
    |> mes("because of one man's strong desires...")
    |> next()
    |> mes("^b22222I wouldn't recommend to go futher.")
    |> mes("You would need to challenge that poor")
    |> mes("being, who I've named this tower after.")
    |> mes("His soul still rests here...")
    |> next()
    |> mes("^b22222Nobody believed me, the crazy scientist.")
    |> mes("Though I wanted to keep this a secret, somebody")
    |> mes("must get to know about it. That's way I created")
    |> mes("this rune device, and hid this message.")
    |> next()
    |> mes("^b22222Please show that my experience")
    |> mes("wasn't just an illusion.^000000")
    |> next()
    |> mes("That's all.")
    |> mes("The letters fly away in the form of a red key...")
    |> set_char_var(:thana_tower, 5)
    |> changequest(7048, 7049)
    |> specialeffect2(:comboattack1)
    |> close()
  end
end
