defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Bowl do
  @moduledoc """
  A boiling pot lets the player prepare Baba Yaga's medicine.

  ## Behavior

  - At the appropriate quest stage, the player mixes ingredients and reports the result.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Corrected `.locker++` to `.@locker++` to match the duplicate ingredient check.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_in",
        x: 221,
        y: 43,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#bowl"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @actions ["Put the materials in it.", "Pour water in it.", "Stir it up.", "It is over!"]
  @ingredients [
    "Powder Of Wing Of Bat",
    "Liquid Of Spawn",
    "Grasshopper's Leg",
    "Starsand Of Witch",
    "Fine Grit"
  ]
  @final_ingredients ["Witched Starsand", "Fine Grit", "Detonator", "Red Blood", "Burning Heart"]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 16 do
      ctx
      |> mes("-It is a very dirty pot.")
      |> mes("Something is boiling")
      |> mes("Baba Yaga might have done something")
      |> mes("with it.")
      |> mes("Well, let's get it started.-")
      |> next()
      |> set_local(:"menu$", @ingredients)
      |> set_local(:"implode$", Enum.join(@ingredients, ":"))
      |> first_stage()
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp first_stage(ctx) do
    if get_local(ctx, :nankai, 0) < 3 do
      {ctx, choice} =
        ctx
        |> mes("-Something is still being boiled in the pot.")
        |> mes("What am I going to do?-")
        |> next()
        |> select(@actions)

      case choice do
        1 ->
          ctx |> first_ingredient() |> next() |> first_stage()

        2 ->
          ctx
          |> specialeffect(:poisonhit)
          |> advance()
          |> mes("-I pour water in the pot a little.")
          |> mes("The liquid has become thin.")
          |> mes("No other remarkable changes")
          |> mes("have happened.-")
          |> next()
          |> first_stage()

        3 ->
          ctx
          |> specialeffect(:poisonhit)
          |> advance()
          |> mes("-I stir it up")
          |> mes("with a stick several times.")
          |> mes("No other remarkable changes")
          |> mes("have happened.-")
          |> next()
          |> first_stage()

        4 ->
          ctx
          |> specialeffect(:poisonattack)
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I will tell Baba Yaga that")
          |> mes("the work has been done.")
          |> set_char_var(:mos_nowinter, 17)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> specialeffect(:bubble)
      |> mes("-The liquid has been changed")
      |> mes("and is now bubbling.")
      |> mes("It seems to have shrunk,")
      |> mes("but not by much.-")
      |> next()
      |> mes("-Anyway, the first step is done")
      |> mes("let's go on the next stage.-")
      |> next()
      |> second_stage()
    end
  end

  defp first_ingredient(ctx) do
    {ctx, choice} = select(ctx, String.split(get_local(ctx, :"implode$", ""), ":"))
    index = choice - 1
    ctx = set_local(ctx, :m, index)
    key = Enum.at([:bat, :mush, :locker], index)

    ctx =
      if key && Rathena.truthy?(get_local(ctx, key, 0)) do
        specialeffect(ctx, :poisonhit)
      else
        ctx = specialeffect(ctx, :smoke)
        ctx = if key, do: increment(ctx, key), else: ctx
        increment(ctx, :maho)
      end

    ctx = if index >= 3, do: specialeffect(ctx, :poisonhit), else: ctx

    ctx
    |> advance()
    |> mes(
      Rathena.concat(
        Rathena.concat("-I put the ", Enum.at(@ingredients, index, "")),
        " in the pot."
      )
    )
    |> mes("Its smell slightly changes.-")
  end

  defp second_stage(ctx) do
    if get_local(ctx, :nankai, 0) < 7 do
      {ctx, choice} = ctx |> mes("-Well, What am I going to do?-") |> next() |> select(@actions)

      case choice do
        1 ->
          ctx |> second_ingredient() |> next() |> second_stage()

        2 ->
          ctx |> second_water() |> advance() |> next() |> second_stage()

        3 ->
          ctx |> stir(4, 20) |> next() |> second_stage()

        4 ->
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I will tell Baba Yaga that")
          |> mes("it has been done.")
          |> set_char_var(:mos_nowinter, 17)
          |> specialeffect(:poisonattack)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("-I am sure that the book told me")
      |> mes("to wait for some time.-")
      |> next()
      |> mes("............")
      |> next()
      |> mes("............")
      |> next()
      |> mes("-The smell of the liquid boiling in")
      |> mes("the pot has changed enough.")
      |> mes("Let's go on to the next stage.-")
      |> next()
      |> set_local(:"menu2$", @final_ingredients)
      |> set_local(:"menu3$", @final_ingredients ++ ["Piece Of Diamond"])
      |> set_local(:"implode2$", Enum.join(@final_ingredients, ":"))
      |> set_local(:"implode3$", Enum.join(@final_ingredients ++ ["Piece Of Diamond"], ":"))
      |> final_stage()
    end
  end

  defp second_ingredient(ctx) do
    ctx = set_local(ctx, :w, 0)
    {ctx, choice} = select(ctx, String.split(Enum.join(get_local(ctx, :"menu$", []), ":"), ":"))
    index = choice - 1
    ctx = set_local(ctx, :m, index)

    ctx =
      if index >= 3 do
        ctx |> second_ingredient_effect(index) |> next()
      else
        specialeffect(ctx, :poisonhit)
      end

    ctx =
      ctx
      |> advance()
      |> mes(
        Rathena.concat(
          Rathena.concat("-I put the ", Enum.at(@ingredients, index, "")),
          " in the pot."
        )
      )

    if index <= 2 do
      mes(ctx, "It's smell drastically changes.-")
    else
      description = if Rathena.truthy?(get_local(ctx, :w, 0)), do: "smell", else: "color"
      mes(ctx, Rathena.concat(Rathena.concat("Its ", description), " slightly changes.-"))
    end
  end

  defp second_ingredient_effect(ctx, index) do
    key =
      case index do
        3 -> :star
        4 -> :sand
        _ -> nil
      end

    if get_local(ctx, :nankai, 0) in [5, 6] do
      if key && Rathena.truthy?(get_local(ctx, key, 0)) do
        specialeffect(ctx, :poisonhit)
      else
        ctx = ctx |> specialeffect(:smoke) |> increment(:maho)
        ctx = if key, do: increment(ctx, key), else: ctx
        set_local(ctx, :w, 1)
      end
    else
      ctx = specialeffect(ctx, :poisonhit)
      if key, do: increment(ctx, key), else: ctx
    end
  end

  defp second_water(ctx) do
    if get_local(ctx, :nankai, 0) == 3 do
      ctx
      |> mes("-I pour water in the pot a little.")
      |> mes("The boiling sounds stronger as if")
      |> mes("something in the cloudy liquid")
      |> mes("has changed.-")
      |> specialeffect(:dragonsmoke)
      |> increment(:maho)
    else
      ctx
      |> specialeffect(:poisonhit)
      |> mes("-I pour water in the pot and, the liquid gets thin.-")
    end
  end

  defp stir(ctx, step, expected) do
    if get_local(ctx, :nankai, 0) == step do
      question =
        if step == 4, do: "How many times should I..?", else: "How many times should I...?"

      {ctx, count} =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Ok, I will stir it up this time.")
        |> mes(question)
        |> next()
        |> input(:int)

      ctx = set_local(ctx, :input, count)

      cond do
        count == expected ->
          ctx =
            ctx
            |> mes("-It must be #{expected} times.-")
            |> next()
            |> specialeffect(:wind)
            |> mes("-Stirring up makes it")

          ctx =
            if step == 4,
              do: ctx |> mes("brighter and") |> mes("its smell gets") |> mes("more bearable."),
              else: mes(ctx, "brighter.-")

          ctx |> increment(:maho) |> advance()

        count == 0 ->
          mes(ctx, "-I won't stir it up.-")

        count > 100 ->
          {first, second} =
            if step == 4,
              do: {"-It won't be able", "to stir so many times."},
              else: {"-It won't be to", "stir so many times."}

          ctx |> mes(first) |> mes(second) |> mes("Let me think again.-")

        true ->
          ctx
          |> mes(Rathena.concat(Rathena.concat("-Yes, it must be ", count), " times.-"))
          |> next()
          |> mes("-I stir it up really hard.")
          |> mes("It is boiled.-")
          |> advance()
      end
    else
      ctx
      |> mes("-Bubble, bubble-")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Something changed?")
      |> advance()
    end
  end

  defp final_stage(ctx) do
    {ctx, choice} = ctx |> mes("-Well, What am I going to do?-") |> next() |> select(@actions)

    case choice do
      1 ->
        ctx |> final_ingredient() |> next() |> final_stage()

      2 ->
        ctx
        |> advance()
        |> mes("-I pour water in the pot a little.")
        |> mes("The smell gets better.-")
        |> next()
        |> final_stage()

      3 ->
        ctx |> stir(7, 15) |> next() |> final_stage()

      4 ->
        ctx =
          ctx
          |> mes("-It seems that the work is over.")
          |> mes("I need to show this to Baba Yaga.-")

        if get_local(ctx, :maho, 0) == 12 do
          ctx |> set_char_var(:mos_nowinter, 18) |> specialeffect(:gaspush) |> close()
        else
          ctx |> specialeffect(:poisonattack) |> set_char_var(:mos_nowinter, 17) |> close()
        end

      _ ->
        ctx
    end
  end

  defp final_ingredient(ctx) do
    ctx = set_local(ctx, :w, 0)

    if get_local(ctx, :nankai, 0) == 11 do
      {ctx, choice} = select(ctx, String.split(get_local(ctx, :"implode3$", ""), ":"))
      index = choice - 1
      ctx = set_local(ctx, :m, index)

      ctx =
        if index == 5,
          do: ctx |> increment(:maho) |> specialeffect(:smoke),
          else: specialeffect(ctx, :poisonhit)

      article = if index == 5, do: "a", else: "the"
      name = Enum.at(get_local(ctx, :"menu3$", []), index, "")

      message =
        Rathena.concat(
          Rathena.concat(Rathena.concat(Rathena.concat("-I put ", article), " "), name),
          " in the pot."
        )

      ctx
      |> advance()
      |> mes(message)
      |> mes(if(index == 5, do: "The solution alters in color.-", else: "The smell gets worse.-"))
    else
      {ctx, choice} = select(ctx, String.split(get_local(ctx, :"implode2$", ""), ":"))
      index = choice - 1
      ctx = set_local(ctx, :m, index)
      step = get_local(ctx, :nankai, 0)

      ctx =
        if {index, step} in [{2, 9}, {3, 8}, {4, 10}],
          do: ctx |> specialeffect(:smoke) |> increment(:maho),
          else: ctx |> specialeffect(:poisonhit) |> set_local(:w, 1)

      ctx = if index <= 1, do: specialeffect(ctx, :poisonhit), else: ctx

      ctx =
        ctx
        |> advance()
        |> mes(
          Rathena.concat(
            Rathena.concat("-I put the ", Enum.at(@final_ingredients, index, "")),
            " in the pot."
          )
        )

      message =
        cond do
          index <= 1 -> "Its smell slightly changes.-"
          Rathena.truthy?(get_local(ctx, :w, 0)) -> "The smell gets worse.-"
          true -> "The smell has been changed a little.-"
        end

      mes(ctx, message)
    end
  end

  defp advance(ctx), do: increment(ctx, :nankai)
  defp increment(ctx, key), do: set_local(ctx, key, get_local(ctx, key, 0) + 1)
end
