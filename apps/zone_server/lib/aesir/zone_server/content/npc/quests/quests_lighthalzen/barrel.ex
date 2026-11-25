defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Barrel do
  @moduledoc """
  A barrel conceals a keypad and a yellow key.

  ## Behavior

  - Opens the barrel with an axe and solves the keypad to obtain the key.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_cube",
        x: 237,
        y: 183,
        dir: 0,
        sprite: 111,
        name: "Barrel",
        scope: :shared,
        unique_name: "Barrel#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_sincube, 0)

    cond do
      stage < 8 -> unopened_barrel(ctx)
      stage == 8 -> break_barrel(ctx)
      stage == 9 -> keypad(ctx)
      true -> empty_keypad(ctx)
    end
  end

  defp unopened_barrel(ctx) do
    ctx
    |> mes("^3355FFYou have")
    |> mes("found a shabbily")
    |> mes("constructed barrel.^000000")
    |> close()
  end

  defp break_barrel(ctx) do
    {ctx, answer} =
      ctx
      |> mes("^3355FFYou have")
      |> mes("found a shabbily")
      |> mes("constructed barrel.")
      |> mes("You sense that there's")
      |> mes("something inside, but")
      |> mes("you need something to")
      |> mes("smash the barrel open.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", answer)

    ctx =
      if get_local(ctx, :"input$", "") == "Axe" do
        ctx
        |> mes("^3355FFAxe in hand, you lift")
        |> mes("it above your head and")
        |> mes("swing it downwards,")
        |> mes("smashing off the top of")
        |> mes("the barrel. Inside, you find a")
        |> mes("box topped with a metal plate.^000000")
        |> next()
        |> mes("^3355FFThe numbers one")
        |> mes("through nine are")
        |> mes("etched on the surface")
        |> mes("of the metal plate on")
        |> mes("top of the box you found,")
        |> mes("like some kind of keypad...^000000")
        |> set_char_var(:lhz_sincube, 9)
      else
        ctx
        |> mes("^3355FFDoing that probably won't")
        |> mes("break open this keg. You'll")
        |> mes("need to try something else.^000000")
      end

    close(ctx)
  end

  defp keypad(ctx) do
    stage = get_char_var(ctx, :lhz_secret01, 0)

    cond do
      stage < 3 -> unknown_code(ctx)
      stage <= 5 -> enter_code(ctx, stage)
      true -> found_key(ctx)
    end
  end

  defp unknown_code(ctx) do
    ctx
    |> mes("^3355FFYou decide to enter")
    |> mes("some numbers into the")
    |> mes("metallic keypad. Remember,")
    |> mes("you can only enter single")
    |> mes("digit numbers at one time...^000000")
    |> next()
    |> set_local(:i, 0)
    |> read_digits()
    |> mes("^3355FFNothing happened...^000000")
    |> close()
  end

  defp enter_code(ctx, stage) do
    numbers =
      case stage do
        3 -> [4, 3, 2, 9, 1, 6, 8, 2, 7]
        4 -> [3, 6, 4, 1, 2, 8, 7, 1, 5]
        5 -> [4, 9, 3, 7, 6, 2, 8, 6, 6]
      end

    ctx = set_local(ctx, :numbers, numbers)

    ctx =
      ctx
      |> mes("^3355FFYou decide to enter")
      |> mes("some numbers into the")
      |> mes("numberpad etched on the")
      |> mes("metal plate on top of the box")
      |> mes("you found inside the keg.^000000")
      |> next()
      |> set_local(:i, 0)
      |> check_digits()

    ctx =
      if get_local(ctx, :number_line, 0) == 9 do
        ctx
        |> mes("^3355FFThe metal plate slides")
        |> mes("open and you find a key")
        |> mes("Key inside the box. You")
        |> mes("to keep this ^000000Yellow Key^3355FF.^000000")
        |> set_char_var(:lhz_secret01, 6)
      else
        ctx
        |> mes("^3355FFNothing happened.")
        |> mes("It's likely that you did not")
        |> mes("enter the correct numbers.^000000")
      end

    close(ctx)
  end

  defp found_key(ctx) do
    ctx
    |> mes("^3355FFThis is the box with")
    |> mes("the keypad in which you")
    |> mes("found the ^000000Yellow Key^3355FF.")
    |> mes("The box is now empty.^000000")
    |> close()
  end

  defp empty_keypad(ctx) do
    ctx
    |> mes("^3355FFThis is a box")
    |> mes("topped with a metal")
    |> mes("plate that looks like")
    |> mes("a crudely made keypad.^000000")
    |> close()
  end

  defp read_digits(ctx) do
    if get_local(ctx, :i, 0) < 9 do
      {ctx, digit} = input(ctx, :int)
      ctx = set_local(ctx, :input, digit)
      ctx |> set_local(:i, get_local(ctx, :i, 0) + 1) |> read_digits()
    else
      ctx
    end
  end

  defp check_digits(ctx) do
    if get_local(ctx, :i, 0) < 9 do
      {ctx, digit} = input(ctx, :int)
      ctx = set_local(ctx, :input, digit)

      ctx =
        if get_local(ctx, :input, 0) ==
             Enum.at(get_local(ctx, :numbers, []), get_local(ctx, :i, 0), 0) do
          set_local(ctx, :number_line, get_local(ctx, :number_line, 0) + 1)
        else
          ctx
        end

      ctx |> set_local(:i, get_local(ctx, :i, 0) + 1) |> check_digits()
    else
      ctx
    end
  end
end
