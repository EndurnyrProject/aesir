defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesMorroc.Guide do
  @moduledoc """
  Morocc guide who directs visitors to the town's facilities.

  ## Behavior

  - Describes local destinations and optionally marks their locations on the mini-map.
  - Clears location marks on request and explains how to use the mini-map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Samuray22

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "morocc",
        x: 153,
        y: 286,
        dir: 6,
        sprite: 707,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "MocGuide"
      },
      %{
        map: "morocc",
        x: 54,
        y: 97,
        dir: 0,
        sprite: 707,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#2moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"^FF0000Thief Guild^000000",
     [
       "The Thief Guild is",
       "in charge of all Job",
       "Changes to the Thief",
       "Class. From what I hear,",
       "you can find them inside",
       "the Pyramids nearby..."
     ], [{24, 297, 2, 0xFF0000}]},
    {"Weapon Shop", ["The Weapon Shop", "is in the southeast", "end of Morocc."],
     [{253, 56, 3, 0xFF00FF}]},
    {"Inn",
     [
       "There are Inns",
       "where you can rest",
       "at the southeast and",
       "northeast ends of Morocc."
     ], [{197, 66, 4, 0xFF00FF}, {273, 269, 5, 0xFF00FF}]},
    {"Pub", ["You can find the", "Pub in northeast Morocc."], [{52, 259, 6, 0xFF00FF}]},
    {"Mercenary Guild", ["The Mercenary", "Guild is located", "in East Morocc."],
     [{284, 171, 7, 0x00FF00}]},
    {"Forge", ["The Forge is", "located just", "southwest from", "the center of Morocc."],
     [{47, 47, 7, 0xFF00FF}]}
  ]

  @location_count length(@locations)
  @location_menu Enum.map(@locations, &elem(&1, 0)) ++ ["Cancel"]

  @cleared_marks [
    {237, 41, 2, 0x00FF00},
    {237, 41, 3, 0x0000FF},
    {46, 345, 4, 0x00FF00},
    {175, 220, 5, 0xFF0000},
    {175, 220, 6, 0xFF0000},
    {175, 220, 7, 0xFF0000}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> cutin("moc_soldier", 2)
    |> mes("[Morocc Guide]")
    |> mes("Welcome to Morocc,")
    |> mes("the frontier town of the")
    |> mes("Rune-Midgarts Kingdom.")
    |> mes("Please ask me for help if")
    |> mes("you're having any trouble")
    |> mes("finding anything in town.")
    |> main_menu(false, false)
    |> cutin("moc_soldier", 255)
  end

  defp main_menu(ctx, marking?, guide_opened?) do
    {ctx, choice} =
      ctx |> next() |> select(["City Guide", "Remove Marks from Mini-Map", "Notice", "Cancel"])

    case choice do
      1 ->
        {ctx, marking?} =
          ctx
          |> mes("[Morocc Guide]")
          |> mes("Please select")
          |> mes("a location from")
          |> mes("the following menu.")
          |> offer_marks(marking?)

        ctx |> city_guide(marking?, guide_opened?) |> main_menu(marking?, true)

      2 ->
        ctx |> clear_marks() |> main_menu(false, guide_opened?)

      3 ->
        ctx |> explain_mini_map() |> main_menu(marking?, guide_opened?)

      4 ->
        ctx
        |> mes("[Morocc Guide]")
        |> mes("Alright then,")
        |> mes("try to stay out of")
        |> mes("too much trouble")
        |> mes("out there, adventurer.")
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
      |> select(["Yes.", "No."])

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
        |> mes("[Morocc Guide]")
        |> mes("Please ask me to ''Remove")
        |> mes("Marks from Mini-Map'' if you")
        |> mes("no longer wish to have the")
        |> mes("location marks displayed")
        |> mes("on your Mini-Map.")

      _ ->
        city_guide(ctx, marking?, true)
    end
  end

  defp describe(ctx, lines), do: Enum.reduce(lines, mes(ctx, "[Morocc Guide]"), &mes(&2, &1))

  defp mark(ctx, false, _marks), do: ctx

  defp mark(ctx, true, marks) do
    Enum.reduce(marks, ctx, fn {x, y, id, color}, ctx -> viewpoint(ctx, 1, x, y, id, color) end)
  end

  defp clear_marks(ctx) do
    Enum.reduce(@cleared_marks, ctx, fn {x, y, id, color}, ctx ->
      viewpoint(ctx, 2, x, y, id, color)
    end)
  end

  defp explain_mini_map(ctx) do
    ctx
    |> mes("[Morocc Guide]")
    |> mes("Advances in sorcery and")
    |> mes("technology have allowed")
    |> mes("us to update our information")
    |> mes("system, enabling up to mark")
    |> mes("locations on your Mini-Map")
    |> mes("for easier navigation.")
    |> next()
    |> mes("[Morocc Guide]")
    |> mes("Your Mini-Map is located")
    |> mes("in the upper right corner")
    |> mes("of the screen. If you can't")
    |> mes("see it, press the Ctrl + Tab")
    |> mes("keys or click the ''Map'' button in your Basic Info Window.")
    |> next()
    |> mes("[Morocc Guide]")
    |> mes("On your Mini-Map,")
    |> mes("click on the ''+'' and ''-''")
    |> mes("symbols to zoom in and")
    |> mes("our of your Mini-Map. We")
    |> mes("hope you enjoy your travels")
    |> mes("here in the city of Morocc.")
  end
end
