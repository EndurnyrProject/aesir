defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesRachel.RachelGuide do
  @moduledoc """
  Rachel guide who directs visitors to local facilities.

  ## Behavior

  - Describes village locations and optionally marks them on the mini-map.
  - Removes location marks and explains how to use the mini-map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "rachel",
        x: 138,
        y: 146,
        dir: 5,
        sprite: 934,
        name: "Rachel Guide",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"Cheshrumnir",
     [
       "Cheshrumnir is a holy ground where pope, the incarnation of goddess Freya stays.",
       "Take the road to the norh to find the building."
     ], {150, 249, 1, 0xFF0000}},
    {"Inn",
     [
       "You can rest your fatigue off the journey in the Inn.",
       "The left building next to me is the Inn of Rachel."
     ], {115, 149, 2, 0xFF00FF}},
    {"Weapon Shop",
     [
       "Do you want to check out the weapons that are sold in Rachel?",
       "The weapon shop is located nearby the western gate."
     ], {42, 87, 3, 0x99FFFF}},
    {"Tool Shop",
     [
       "Rachel tool shop sells the best quality potions.",
       "It's located nearby the western gate."
     ], {83, 78, 4, 0x0000FF}},
    {"Airport", ["The Airport is located outside the eastern gate."], {273, 125, 5, 0x00FF00}}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Rachel Guide]")
    |> mes("Welcome to the capital of")
    |> mes("Arunafeltz, Rachel where a warm")
    |> mes("breath of goddess Freya reaches.")
    |> mes("If this is the first time for you")
    |> mes("to use the guide services, why")
    |> mes("don't you check the \"Notice\" menu first?")
    |> main_menu(false, false)
    |> close()
  end

  defp main_menu(ctx, marking?, guide_opened?) do
    {ctx, choice} =
      ctx |> next() |> select(["Village Guide", "Remove Marks from Mini-Map", "Notice", "Cancel"])

    case choice do
      1 ->
        {ctx, marking?} =
          ctx
          |> mes("[Rachel Guide]")
          |> mes("I can tell you any building location as long as it is in Rachel.")
          |> mes("So where do you want to go?")
          |> offer_marks(marking?)

        ctx |> city_guide(marking?, guide_opened?) |> main_menu(marking?, true)

      2 ->
        ctx
        |> clear_marks()
        |> mes("[Rachel Guide]")
        |> mes("Okay, they are gone now. If you have more locations to ask, just let me know.")
        |> main_menu(marking?, guide_opened?)

      3 ->
        ctx
        |> mes("[Rachel Guide]")
        |> mes("When you are using the ''Village Guide'' menu,")
        |> mes(
          "make sure that building locations will be marked on your mini-map at the upper right side of your screen."
        )
        |> mes(
          "If you cannot see your mini-map, use the short cut key ''ctrl+tab'' or press the ''Map'' button on your basic information windows, okay?"
        )
        |> mes(
          "And you can also zoom out your mini-map by using the ''-'' button in case you cannot view the entire map of the village."
        )
        |> main_menu(marking?, guide_opened?)

      4 ->
        ctx
        |> mes("[Rachel Guide]")
        |> mes("Hope you have a wonderfull journey")
        |> mes("in Arunafeltz.")
        |> close()

      _ ->
        main_menu(ctx, marking?, guide_opened?)
    end
  end

  defp offer_marks(ctx, true), do: {ctx, true}

  defp offer_marks(ctx, false) do
    {ctx, choice} =
      ctx
      |> mes("Would you like me")
      |> mes("to mark locations")
      |> mes("on your Mini-Map?")
      |> next()
      |> select(["Yes", "No"])

    {ctx, choice == 1}
  end

  defp city_guide(ctx, marking?, paged?) do
    ctx = if paged?, do: next(ctx), else: ctx
    {ctx, choice} = select(ctx, Enum.map(@locations, &elem(&1, 0)) ++ ["Cancel"])

    case choice do
      choice when choice in 1..5 ->
        {_name, lines, {x, y, id, color}} = Enum.at(@locations, choice - 1)
        ctx = Enum.reduce(lines, mes(ctx, "[Rachel Guide]"), &mes(&2, &1))
        ctx = if marking?, do: viewpoint(ctx, 1, x, y, id, color), else: ctx
        city_guide(ctx, marking?, true)

      6 ->
        ctx
        |> mes("[Rachel Guide]")
        |> mes("If you like to get rid of all the location marks on your Mini-Map,")
        |> mes("just ask me again, and choose \"Remove Marks from Mini-Map\" menu.")

      _ ->
        city_guide(ctx, marking?, true)
    end
  end

  defp clear_marks(ctx) do
    Enum.reduce(@locations, ctx, fn {_, _, {x, y, id, color}}, ctx ->
      viewpoint(ctx, 2, x, y, id, color)
    end)
  end
end
