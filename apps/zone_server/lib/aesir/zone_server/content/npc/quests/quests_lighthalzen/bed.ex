defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Bed do
  @moduledoc """
  A bed hides objects needed for the cube room puzzle.

  ## Behavior

  - Searches for sticks and uses them to retrieve a cube.

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
        x: 247,
        y: 198,
        dir: 0,
        sprite: 111,
        name: "Bed",
        scope: :shared,
        unique_name: "Bed#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_secret02, 0)
    {ctx, choice} = if stage == 3, do: describe_messy_bed(ctx), else: describe_bed(ctx)

    ctx = if choice == 1, do: on_bed(ctx), else: under_bed(ctx, stage)
    close(ctx)
  end

  defp describe_bed(ctx) do
    ctx
    |> mes("^3355FFYou've found a bed")
    |> mes("in which the sheets")
    |> mes("are slovenly arranged.^000000")
    |> next()
    |> select(["On the bed", "Under the bed"])
  end

  defp describe_messy_bed(ctx) do
    ctx
    |> mes("^3355FFYou find a messy")
    |> mes("bed that may be more")
    |> mes("than meets the eye.^000000")
    |> next()
    |> select(["On the bed", "Under the bed"])
  end

  defp on_bed(ctx) do
    ctx
    |> mes("^3355FFNo one's in the bed")
    |> mes("and if you climbed in,")
    |> mes("you'd just be alone. For")
    |> mes("some people, this may")
    |> mes("be an immutable truth.^000000")
  end

  defp under_bed(ctx, 0) do
    ctx
    |> mes("^3355FFUnder the bed, you")
    |> mes("discover a ^000000Short Stick^3355FF")
    |> mes("which you decide to")
    |> mes("keep. You never know")
    |> mes("when certain, seemingly")
    |> mes("useless objects will save you.^000000")
    |> set_char_var(:lhz_secret02, 2)
  end

  defp under_bed(ctx, 1) do
    ctx
    |> mes("^3355FFUnder the bed, you")
    |> mes("discover another Short")
    |> mes("Stick which happens to")
    |> mes("fit perfectly into the other")
    |> mes("Short Stick you found earlier.")
    |> next()
    |> mes("^3355FFYou combine the two")
    |> mes("lesser sticks to create")
    |> mes("a stick that is superior")
    |> mes("to the sum of its parts.")
    |> mes("You are now the proud")
    |> mes("bearer of a ^000000Long Stick^3355FF.^000000")
    |> set_char_var(:lhz_secret02, 3)
  end

  defp under_bed(ctx, stage) when stage in [2, 3] do
    {ctx, answer} = reach_under_bed(ctx)
    ctx = set_local(ctx, :"input$", answer)

    case {stage, get_local(ctx, :"input$", "")} do
      {2, "Short Stick"} -> short_stick(ctx)
      {3, "Long Stick"} -> long_stick(ctx)
      _ -> failed_to_reach(ctx)
    end
  end

  defp under_bed(ctx, _stage) do
    ctx
    |> mes("^3355FFThis is where you")
    |> mes("managed to find some")
    |> mes("sort of strange ^000000Cube^3355FF.^000000")
  end

  defp reach_under_bed(ctx) do
    ctx
    |> mes("^3355FFIn a distant and")
    |> mes("dusty corner beneath")
    |> mes("the bed, you manage to")
    |> mes("spot an object. If only you")
    |> mes("could reach it somehow...^000000")
    |> next()
    |> input(:string)
  end

  defp short_stick(ctx) do
    ctx
    |> mes("^3355FFYou try to reach")
    |> mes("the object by using")
    |> mes("your Short Stick. After")
    |> mes("a few attempts, you had no")
    |> mes("choice but to admit that your")
    |> mes("stick just wasn't long enough.^000000")
  end

  defp long_stick(ctx) do
    ctx
    |> mes("^3355FFWith Long Stick in")
    |> mes("hand, you manage to")
    |> mes("reach the object and drag")
    |> mes("it under the bed towards you.")
    |> mes("You now possess the ^000000Cube^3355FF")
    |> mes("that was under the bed.^000000")
    |> set_char_var(:lhz_secret02, 4)
  end

  defp failed_to_reach(ctx) do
    ctx
    |> mes("^3355FFUnfortunately,")
    |> mes("whatever you used to")
    |> mes("try to reach the object")
    |> mes("didn't work. You'll have")
    |> mes("to think of something else.^000000")
  end
end
