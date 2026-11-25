defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Box do
  @moduledoc """
  A box with shaped holes holds the laboratory permit.

  ## Behavior

  - Fits three puzzle objects into the box and retrieves the permit.

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
        x: 248,
        y: 193,
        dir: 0,
        sprite: 111,
        name: "Box",
        scope: :shared,
        unique_name: "Box#cube1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    oval = get_char_var(ctx, :lhz_secret01, 0)
    cube = get_char_var(ctx, :lhz_secret02, 0)
    polygon = get_char_var(ctx, :lhz_secret03, 0)

    cond do
      oval < 9 and cube < 4 and polygon < 3 -> unopened_box(ctx)
      oval != 10 or cube != 5 or polygon != 4 -> choose_hole(ctx)
      get_char_var(ctx, :lhz_sincube, 0) != 10 -> open_box(ctx)
      true -> empty_box(ctx)
    end
  end

  defp describe_box(ctx) do
    ctx
    |> mes("^3355FFYou find a box with")
    |> mes("three distinctively")
    |> mes("shaped holes.^000000")
    |> next()
  end

  defp unopened_box(ctx) do
    {ctx, _} = ctx |> describe_box() |> select(["Oval Hole", "Cubic Hole", "Polygon Hole"])
    nothing_happens(ctx)
  end

  defp choose_hole(ctx) do
    {ctx, choice} = ctx |> describe_box() |> select(["Oval Hole", "Cube Hole", "Polygon Hole"])

    case choice do
      1 -> oval_hole(ctx)
      2 -> cube_hole(ctx)
      3 -> polygon_hole(ctx)
      _ -> ctx
    end
  end

  defp oval_hole(ctx) do
    case get_char_var(ctx, :lhz_secret01, 0) do
      9 ->
        insert_oval(ctx)

      10 ->
        ctx
        |> mes("^3355FFThe Oval shaped hole")
        |> mes("already has an Oval in it.")
        |> mes("Besides, it's not you have")
        |> mes("any Ovals to spare, anyway.^000000")
        |> close()

      _ ->
        nothing_happens(ctx)
    end
  end

  defp insert_oval(ctx) do
    {ctx, answer} = input(ctx, :string)
    ctx = set_local(ctx, :"input$", answer)

    if get_local(ctx, :"input$", "") == "Oval" do
      ctx
      |> mes("^3355FFYou insert the Oval")
      |> mes("into the Oval shaped")
      |> mes("hole where it fits perfectly.^000000")
      |> set_char_var(:lhz_secret01, 10)
      |> close()
    else
      ctx |> mes("^3355FFNothing happened.^000000") |> close()
    end
  end

  defp cube_hole(ctx) do
    case get_char_var(ctx, :lhz_secret02, 0) do
      4 ->
        insert_cube(ctx)

      5 ->
        ctx
        |> mes("^3355FFYou already placed")
        |> mes("a Cube into the hole.")
        |> mes("You could take it back")
        |> mes("out and put it in again,")
        |> mes("but that would just be")
        |> mes("a total waste of time.^000000")
        |> close()

      _ ->
        nothing_happens(ctx)
    end
  end

  defp insert_cube(ctx) do
    {ctx, answer} = input(ctx, :string)
    ctx = set_local(ctx, :"input$", answer)

    if get_local(ctx, :"input$", "") == "Cube" do
      ctx
      |> mes("^3355FFYou insert the Cube")
      |> mes("into the Cubic hole")
      |> mes("and it clicks into place.")
      |> mes("Your formal Kindergarten")
      |> mes("training is finally justified.^000000")
      |> set_char_var(:lhz_secret02, 5)
      |> close()
    else
      ctx |> mes("^3355FFNothing happened.^000000") |> close()
    end
  end

  defp polygon_hole(ctx) do
    case get_char_var(ctx, :lhz_secret03, 0) do
      3 ->
        insert_polygon(ctx)

      4 ->
        ctx
        |> mes("^3355FFThe Polygon is already")
        |> mes("inserted into the hole.")
        |> mes("Trust that this is as much")
        |> mes("as this Polygon can do for you.^000000")
        |> close()

      _ ->
        nothing_happens(ctx)
    end
  end

  defp insert_polygon(ctx) do
    {ctx, answer} = input(ctx, :string)
    ctx = set_local(ctx, :"input$", answer)

    if get_local(ctx, :"input$", "") == "Polygon" do
      ctx
      |> mes("^3355FFFortunately, the")
      |> mes("nondescript Polygon")
      |> mes("that you have is exactly")
      |> mes("the same shape as this")
      |> mes("nondescript Polygonal hole.")
      |> mes("The Polygon fits perfectly,")
      |> mes("almost as if it were destiny.^000000")
      |> set_char_var(:lhz_secret03, 4)
      |> close()
    else
      ctx |> mes("^3355FFNothing happened.^000000") |> close()
    end
  end

  defp nothing_happens(ctx) do
    {ctx, answer} = input(ctx, :string)
    ctx |> set_local(:"input$", answer) |> mes("^3355FFNothing happened.^000000") |> close()
  end

  defp open_box(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou find a box with")
      |> mes("three distinctively")
      |> mes("shaped holes that")
      |> mes("are now filled with the")
      |> mes("objects you've inserted.^000000")
      |> next()
      |> select(["Open the box.", "Cancel"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("^3355FFYou open the box")
        |> mes("and find that there's")
        |> mes("a small card labeled")
        |> mes("''Laboratory Permit'' inside.")
        |> mes("You pocket this ^000000Laboratory")
        |> mes("Permit^3355FF, knowing that you")
        |> mes("will be needing it later.")
        |> set_char_var(:lhz_sincube, 10)
        |> give_item(2657, 1)
      else
        ctx
      end

    close(ctx)
  end

  defp empty_box(ctx) do
    ctx
    |> mes("^3355FFYou find the open box")
    |> mes("which used to contain")
    |> mes("the ^000000Laboratory Permit^3355FF.")
    |> mes("This box is no longer")
    |> mes("useful to you now, but")
    |> mes("once upon a time, its")
    |> mes("mysteries were a challenge.^000000")
    |> close()
  end
end
