defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsNameless.StrangemachineIzlude do
  @moduledoc """
  A strange machine can be repaired and used to restore a bond of debt.

  ## Behavior

  - Guides the player through repairing the machine and restoring the bond.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "", scope: :shared, unique_name: "StrangeMachine_izlude"},
      %{
        map: "izlude_in",
        x: 58,
        y: 90,
        dir: 1,
        sprite: 111,
        name: "Strange Machine",
        scope: :renewal,
        unique_name: "Strange Machine"
      },
      %{
        map: "izlude_in",
        x: 113,
        y: 66,
        dir: 0,
        sprite: 111,
        name: "Strange Machine",
        scope: :pre_renewal,
        unique_name: "Strange Machine"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 200}]) == 0 ->
        ctx
        |> mes("[Dorian]")
        |> mes("Ugh, just like a member")
        |> mes("of the working class:")
        |> mes("hoarding all your items")
        |> mes("like a packrat? Have the")
        |> mes("decency to relocate your")
        |> mes("goods to Kafra Storage, please.")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 10 ->
        ctx
        |> set_local(:bolt_rand, Enum.random(2..5))
        |> mes("^3355FFThis must be Dorian's")
        |> mes("Mystic Dryer de Elegance.")
        |> mes("What do you want to do?^000000")
        |> next()
        |> repair_machine()

      get_char_var(ctx, :diamond_edq, 0) == 12 ->
        ctx
        |> mes("[Dorian]")
        |> mes("It sounds like you're")
        |> mes("done fixing my Mystic")
        |> mes("Dryer de Elegance.")
        |> mes("Why don't you come")
        |> mes("back so I can explain")
        |> mes("how you can use it?")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 13 and count_item(ctx, 7722) < 1 ->
        restore_bond(ctx)

      get_char_var(ctx, :diamond_edq, 0) == 13 and count_item(ctx, 7722) > 0 ->
        ctx
        |> mes("You already used this")
        |> mes("machine to restore the")
        |> mes("bond of debt. There's no")
        |> mes("need to mess around")
        |> mes("with it any longer.")
        |> close()

      true ->
        ctx
        |> mes("[Dorian]")
        |> mes("Who are you?")
        |> mes("Don't you dare lay")
        |> mes("a hand on my precious")
        |> mes("masterpiece inventions! ")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp restore_bond(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou lift the main")
      |> mes("operational switch,")
      |> mes("turning on a light and")
      |> mes("opening a convenient")
      |> mes("slot. You insert the")
      |> mes("wet bond of debt.^000000")
      |> next()
      |> mes("^3355FFThe engine's pistons")
      |> mes("and cylinders churn")
      |> mes("with a lively din, and")
      |> mes("when the heater stops,")
      |> mes("the slot reopens.^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("So this is the original")
    |> mes("bond of debt that Muff")
    |> mes("lost? It looks... Perfect!")
    |> changequest(3108, 3109)
    |> give_item(7722, 1)
    |> close()
  end

  defp repair_machine(ctx) do
    {ctx, choice} =
      ctx
      |> set_local(:switch_sound, Enum.random(1..4))
      |> select([
        "Check the Machine",
        "Replace the Engine",
        "Tighten the Screw",
        "Press a Switch"
      ])

    case choice do
      1 -> ctx |> check_machine() |> repair_machine()
      2 -> ctx |> replace_engine() |> repair_machine()
      3 -> continue_repair(tighten_screw(ctx))
      4 -> continue_repair(press_switch(ctx))
      _ -> ctx
    end
  end

  defp continue_repair({:continue, ctx}), do: repair_machine(ctx)
  defp continue_repair({:done, ctx}), do: ctx

  defp check_machine(ctx) do
    if get_local(ctx, :hit_status, 0) == 0 do
      ctx
      |> mes("^3355FFThere's no power")
      |> mes("in this behemoth")
      |> mes("of a machine.^000000")
      |> next()
    else
      ctx
    end
  end

  defp replace_engine(ctx) do
    cond do
      get_local(ctx, :engine, 0) == 0 ->
        ctx =
          ctx
          |> mes("^3355FFYou replace the rough")
          |> mes("ruby in the ruby engine")
          |> mes("with a new rough ruby.")
          |> mes("It clicks into place")
          |> mes("inside the engine core.^000000")
          |> next()

        set_local(ctx, :engine, get_local(ctx, :engine, 0) + 1)

      get_local(ctx, :engine, 0) > 0 ->
        ctx
        |> mes("^3355FFThe ruby in the")
        |> mes("engine has already")
        |> mes("been replaced.^000000")
        |> next()

      true ->
        ctx
    end
  end

  defp tighten_screw(ctx) do
    cond do
      get_local(ctx, :engine, 0) < 1 ->
        ctx =
          ctx
          |> mes("^3355FFYou probably need")
          |> mes("to replace the ruby")
          |> mes("in the engine first.^000000")
          |> next()

        {:continue, ctx}

      get_local(ctx, :engine, 0) == 1 and
          get_local(ctx, :bolt, 0) < get_local(ctx, :bolt_rand, 0) ->
        ctx =
          ctx
          |> mes("^3355FF*Krrrr-Krrrrr*^000000")
          |> mes("^3355FF*Krrrr-Krrrrr*^000000")
          |> next()

        {:continue, set_local(ctx, :bolt, get_local(ctx, :bolt, 0) + 1)}

      get_local(ctx, :engine, 0) == 1 and
          get_local(ctx, :bolt, 0) == get_local(ctx, :bolt_rand, 0) ->
        ctx =
          ctx
          |> mes("^3355FF*Krrrr-Krrrrr*^000000")
          |> mes("^0000FF*Click*^000000")
          |> next()

        ctx = set_local(ctx, :bolt, get_local(ctx, :bolt, 0) + 1)
        {:continue, set_local(ctx, :bolt_suc, get_local(ctx, :bolt_suc, 0) + 1)}

      get_local(ctx, :engine, 0) == 1 and
          get_local(ctx, :bolt, 0) > get_local(ctx, :bolt_rand, 0) ->
        ctx =
          ctx
          |> mes("^3355FF*Krrrr-Krrrrr*^000000")
          |> mes("^3355FF*KrrICK-ICK-ICK-KOOM*^000000")
          |> next()
          |> mes("^3355FFYou tightened the")
          |> mes("screw too tightly!")
          |> mes("The joint is broken...")
          |> mes("You should go back")
          |> mes("to Dorian for help.^000000")
          |> changequest(3105, 3106)
          |> set_char_var(:diamond_edq, 11)
          |> close()

        {:done, ctx}

      true ->
        ctx =
          ctx
          |> mes("^3355FFSomething must have")
          |> mes("gone wrong. You'd be")
          |> mes("better off starting")
          |> mes("from the beginning...^000000")
          |> close()

        {:done, ctx}
    end
  end

  defp press_switch(ctx) do
    cond do
      get_local(ctx, :engine, 0) < 1 and get_local(ctx, :bolt_suc, 0) < 1 ->
        ctx =
          ctx
          |> mes("^3355FFYou need to replace")
          |> mes("the engine's ruby and")
          |> mes("tighten the main screw")
          |> mes("before you mess with")
          |> mes("these switches.^000000")
          |> next()

        {:continue, ctx}

      get_local(ctx, :engine, 0) == 1 and get_local(ctx, :bolt_suc, 0) < 1 ->
        ctx =
          ctx
          |> mes("^3355FFYou need to tighten")
          |> mes("the scren before you can")
          |> mes("start the engine safely.")
          |> next()

        {:continue, ctx}

      get_local(ctx, :red, 0) >= 1 and get_local(ctx, :blue, 0) >= 1 and
        get_local(ctx, :yellow, 0) >= 1 and get_local(ctx, :green, 0) >= 1 ->
        ctx =
          ctx
          |> mes("^3355FFThe Mystic Dryer de")
          |> mes("Elegance started with")
          |> mes("a mighty buzz, and the")
          |> mes("sound lowers to a calm")
          |> mes("hum as it stabilizes.")
          |> mes("It looks like you fixed it!^000000")
          |> next()
          |> mes("^3355FFYou should tell Dorian")
          |> mes("first so that you can")
          |> mes("use this machine.^000000")
          |> changequest(3105, 3107)
          |> set_char_var(:diamond_edq, 12)
          |> close()

        {:done, ctx}

      get_local(ctx, :engine, 0) == 1 and get_local(ctx, :bolt_suc, 0) == 1 ->
        choose_switch(ctx, get_local(ctx, :switch_sound, 0))

      true ->
        {:continue, ctx}
    end
  end

  defp choose_switch(ctx, sound) do
    ctx = switch_prompt(ctx, sound)

    {ctx, choice} =
      select(ctx, ["Red Switch", "Blue Switch", "Yellow Switch", "Green Switch"])

    {color, success_sound} =
      case sound do
        1 -> {:red, "^3355FF*Buzzz Buzzz*^000000"}
        2 -> {:blue, "^3355FF*Purrr Purr*^000000"}
        3 -> {:yellow, "^3355FF*Bzzzz Bzzzz*^000000"}
        4 -> {:green, "^3355FFPzzzzz Pzzzz*^000000"}
      end

    if choice == sound and get_local(ctx, color, 0) >= 0 do
      ctx =
        ctx
        |> mes(success_sound)
        |> mes("^3355FF*Clang...!*^000000")
        |> next()
        |> mes("^3355FFThe machine's")
        |> mes("vibrations have")
        |> mes("grown stronger.")
        |> mes("It looks like you")
        |> mes("chose the right switch.^000000")
        |> next()

      {:continue, set_local(ctx, color, get_local(ctx, color, 0) + 1)}
    else
      ctx =
        ctx
        |> mes("^3355FF*Whiz Whiz*^000000")
        |> mes("^3355FF*Whiz Whiz*^000000")
        |> next()
        |> mes("^3355FFThe machine made some")
        |> mes("violent, erratic sounds,")
        |> mes("and vibrated violently")
        |> mes("before coming to a sudden")
        |> mes("stop. That was the wrong")
        |> mes("switch. You'd better ask Dorian...")
        |> changequest(3105, 3106)
        |> set_char_var(:diamond_edq, 11)
        |> close()

      {:done, ctx}
    end
  end

  defp switch_prompt(ctx, 1) do
    ctx
    |> mes("^3355FF*Buzz Buzz*^000000")
    |> mes("^3355FF*Buzz Buzz*^000000")
    |> mes("^3355FFThe machine is")
    |> mes("vibrating weakly.")
    |> mes("Which switch do")
    |> mes("you want to press?^000000")
    |> next()
  end

  defp switch_prompt(ctx, 2) do
    ctx
    |> mes("^3355FF*Purr Purr*^000000")
    |> mes("^3355FF*Purr Purr*^000000")
    |> mes("^3355FFThe machine is vibrating")
    |> mes("a little bit more strongly.")
    |> mes("Which switch will")
    |> mes("you try now?^000000")
    |> next()
  end

  defp switch_prompt(ctx, 3) do
    ctx
    |> mes("^3355FF*Bzzz Bzzz*")
    |> mes("*Bzzz Bzzz*")
    |> mes("The machine's vibrations")
    |> mes("are a bit more stable now.")
    |> mes("Which switch will you try?^000000")
    |> next()
  end

  defp switch_prompt(ctx, 4) do
    ctx
    |> next()
    |> mes("^3355FF*Pzzzz Pzzz*")
    |> mes("*Pzzzz Pzzz*")
    |> mes("The machine is vibrating")
    |> mes("fairly strongly now. Which")
    |> mes("switch will you try?^000000")
    |> next()
  end
end
