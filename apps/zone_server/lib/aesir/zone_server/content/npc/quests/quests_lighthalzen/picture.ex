defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Picture do
  @moduledoc """
  A picture conceals a sequence of numbers.

  ## Behavior

  - Lets the player pry the picture loose and discover a number sequence.
  - Shows the sequence again until it is no longer needed.

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
        x: 234,
        y: 202,
        dir: 0,
        sprite: 111,
        name: "Picture",
        scope: :shared,
        unique_name: "Picture#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :lhz_secret01, 0)

    cond do
      progress < 2 -> inspect_picture(ctx, false)
      progress == 2 -> inspect_picture(ctx, true)
      progress < 6 -> show_numbers(ctx, progress)
      true -> inspect_afterward(ctx)
    end
  end

  defp inspect_picture(ctx, can_pry) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis picture hanging")
      |> mes("on the wall catches")
      |> mes("your attention for some")
      |> mes("inexplicably strange reason.^000000")
      |> next()
      |> select(["Look behind picture.", "Cancel"])

    case choice do
      1 when can_pry ->
        try_prying(ctx)

      1 ->
        ctx
        |> mes("^3355FFYou push and pull")
        |> mes("with all your strength,")
        |> mes("but the picture won't")
        |> mes("budge. If it's too hard")
        |> mes("to move, there must be")
        |> mes("something hidden behind it.^000000")
        |> close()

      _ ->
        close(ctx)
    end
  end

  defp try_prying(ctx) do
    {ctx, input} =
      ctx
      |> mes("^3355FFYou push and pull")
      |> mes("with all your strength,")
      |> mes("but this picture is too")
      |> mes("hard to move with just")
      |> mes("brute strength alone.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", input)

    if get_local(ctx, :"input$", "") == "Jackknife" do
      reveal_numbers(ctx)
    else
      ctx
      |> mes("^3355FFUnfortunately,")
      |> mes("doing that apparently")
      |> mes("wasn't enough to move")
      |> mes("the picture. Perhaps you")
      |> mes("should try something else.^000000")
      |> close()
    end
  end

  defp reveal_numbers(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou take the")
      |> mes("Jackknife, thrust")
      |> mes("it under the picture")
      |> mes("and twist it in order to")
      |> mes("pry the picture off the wall.^000000")
      |> next()
      |> mes("^3355FFBehind the picture, you")
      |> mes("find that the following")
      |> mes("numbers are written:^000000")
      |> mes(" ")
      |> set_local(:number_rand, Enum.random(1..3))

    {numbers, progress} =
      case get_local(ctx, :number_rand, 0) do
        1 -> {"4 3 2 9 1 6 8 2 7", 3}
        2 -> {"3 6 4 1 2 8 7 1 5", 4}
        _ -> {"4 9 3 7 6 2 8 6 6", 5}
      end

    ctx |> mes(numbers) |> set_char_var(:lhz_secret01, progress) |> close()
  end

  defp show_numbers(ctx, progress) do
    ctx =
      ctx
      |> mes("^3355FFThe following numbers")
      |> mes("were written behind the")
      |> mes("picture. If they were hidden,")
      |> mes("these numbers must have")
      |> mes("some kind of importance.^000000")
      |> mes(" ")

    ctx =
      case progress do
        3 -> mes(ctx, "4 3 2 9 1 6 8 2 7")
        4 -> mes(ctx, "3 6 4 1 2 8 7 1 5")
        5 -> mes(ctx, "4 9 3 7 6 2 8 6 6")
        _ -> ctx
      end

    close(ctx)
  end

  defp inspect_afterward(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThere is a picture")
      |> mes("hanging on the wall.^000000")
      |> next()
      |> select(["Look beneath picture.", "Cancel"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("^3355FFThere are some")
        |> mes("numbers behind the")
        |> mes("picture, but now there is")
        |> mes("no need to memorize them.^000000")
      else
        ctx
      end

    close(ctx)
  end
end
