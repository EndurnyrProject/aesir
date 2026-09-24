defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesVeins.VeinsGuide do
  @moduledoc """
  Veins guide who directs visitors to the town's facilities.

  ## Behavior

  - Describes local destinations and optionally marks their locations on the mini-map.
  - Clears location marks on request and explains how to use the mini-map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "veins",
        x: 210,
        y: 345,
        dir: 5,
        sprite: 934,
        name: "Veins Guide",
        scope: :pre_renewal,
        unique_name: "ve_guide"
      },
      %{
        map: "veins",
        x: 189,
        y: 101,
        dir: 5,
        sprite: 934,
        name: "Veins Guide",
        scope: :pre_renewal,
        unique_name: "Veins Guide#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"Temple",
     [
       "Our temple is located north,",
       "and always crowded with sincere followers of Goddess Freya."
     ], [{196, 258, 1, 0xFF0000}]},
    {"Inn",
     [
       "You can rest your fatigue of the journey in the Inn.",
       "The left building next to me is the Inn of Veins."
     ], [{128, 266, 2, 0xFF00FF}]},
    {"Weapon Shop",
     [
       "Yes, you should protect yourself from danger on your own.",
       "Purchase high quality weapons at affordable prices.",
       "The Veins Weapon Shop is located to the West."
     ], [{150, 175, 3, 0x99FFFF}]},
    {"Tool Shop",
     [
       "Have you packed enough necessities  for your adventure?",
       "If not, I suggest you check what the Veins in the Center can offer you."
     ], [{230, 161, 4, 0x0000FF}]},
    {"Airship", ["Please be aware that Veins only operates cargo airships."],
     [{273, 285, 5, 0x00FF00}]},
    {"Tavern",
     [
       "If you'd like to make friends with",
       "the townspeople, I suggest you",
       "go have a drink at the tavern to",
       "the west."
     ], [{150, 217, 6, 0x00FF00}]},
    {"Geological Research Institute",
     [
       "Are you interested in studying geology?",
       "Then you'd better go check out the",
       "Geological Research Institute on",
       "the 2nd floor of the weapon shop."
     ], [{150, 175, 7, 0x00FF00}]}
  ]

  @location_count length(@locations)
  @location_menu Enum.map(@locations, &elem(&1, 0)) ++ ["Cancel"]

  @cleared_marks [
    {196, 258, 1, 0xFF0000},
    {128, 266, 2, 0xFF00FF},
    {150, 175, 3, 0x99FFFF},
    {230, 161, 4, 0x0000FF},
    {273, 285, 5, 0x00FF00},
    {150, 217, 6, 0x00FF00},
    {150, 175, 7, 0x00FF00}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Veins Guide]")
    |> mes("Desert City Veins welcomes adventurers seeking shelter from harsh sandstorms.")
    |> mes(
      "If this is the first time for you to use the guide services, why don't you check the..."
    )
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
          |> mes("[Veins Guide]")
          |> mes("I can tell you any building location as long as it is in Veins.")
          |> mes("So where do you want to go?")
          |> offer_marks(marking?)

        ctx |> city_guide(marking?, guide_opened?) |> main_menu(marking?, true)

      2 ->
        ctx |> clear_marks() |> main_menu(marking?, guide_opened?)

      3 ->
        ctx |> explain_mini_map() |> main_menu(marking?, guide_opened?)

      4 ->
        ctx
        |> mes("[Veins Guide]")
        |> mes("Enjoy your stay in Veins.")
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
    {ctx, choice} = select(ctx, @location_menu)

    case choice do
      choice when choice in 1..@location_count ->
        {_label, lines, marks} = Enum.at(@locations, choice - 1)
        ctx |> describe(lines) |> mark(marking?, marks) |> city_guide(marking?, true)

      choice when choice == @location_count + 1 ->
        ctx
        |> mes("[Veins Guide]")
        |> mes("If you like to get rid of all the location marks on your Mini-Map,")
        |> mes("just ask me again, and choose 'Remove Marks from Mini-Map' menu.")

      _ ->
        city_guide(ctx, marking?, true)
    end
  end

  defp describe(ctx, lines), do: Enum.reduce(lines, mes(ctx, "[Veins Guide]"), &mes(&2, &1))

  defp mark(ctx, false, _marks), do: ctx

  defp mark(ctx, true, marks) do
    Enum.reduce(marks, ctx, fn {x, y, id, color}, ctx -> viewpoint(ctx, 1, x, y, id, color) end)
  end

  defp clear_marks(ctx) do
    Enum.reduce(@cleared_marks, ctx, fn {x, y, id, color}, ctx ->
      viewpoint(ctx, 2, x, y, id, color)
    end)
    |> mes("[Veins Guide]")
    |> mes("Okay, they are gone now. If you have more locations to ask, just let me know.")
    |> mes("Enjoy your stay in Veins.")
  end

  defp explain_mini_map(ctx) do
    ctx
    |> mes("[Veins Guide]")
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
  end
end
