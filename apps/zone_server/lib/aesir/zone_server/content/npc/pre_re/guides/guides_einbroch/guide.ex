defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesEinbroch.Guide do
  @moduledoc """
  Einbroch guide who directs visitors to local facilities.

  ## Behavior

  - Describes destinations and optionally marks them on the mini-map.
  - Clears marks and explains how to use the mini-map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_dib
    - L0ne_W0lf
    - Lupus
    - erKURITA
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "einbroch",
        x: 72,
        y: 202,
        dir: 4,
        sprite: 852,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "EinGuide"
      },
      %{
        map: "einbroch",
        x: 155,
        y: 43,
        dir: 4,
        sprite: 852,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#2ein"
      },
      %{
        map: "einbroch",
        x: 162,
        y: 317,
        dir: 4,
        sprite: 852,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#3ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {[
       "[Einbroch Guide]",
       "The ^FF0000Airport^000000 is located",
       "in the northwestern part",
       "of the city. There you can",
       "see our city's pride and joy, the Airship. Remember that you must pay admission to board the Airship."
     ], {63, 228, 2, 0xFF0000}},
    {[
       "[Einbroch Guide]",
       "The Train Station is",
       "located in the northeast",
       "part of Einbroch. Trains",
       "running between here",
       "and Einbech run all day",
       "long, everyday."
     ], {236, 279, 3, 0xFF00FF}},
    {[
       "[Einbroch Guide]",
       "The Factory, perhaps the",
       "most important facility in",
       "Einbroch, is located in the",
       "southern part of the city."
     ], {158, 78, 4, 0xFF00FF}},
    {[
       "[Einbroch Guide]",
       "The Plaza, our biggest",
       "shopping district, can be",
       "found just east from the",
       "center of Einbroch."
     ], {232, 190, 5, 0xFF00FF}},
    {[
       "[Einbroch Guide]",
       "The Hotel is east of",
       "the Plaza and offers top",
       "caliber accomodations.",
       "There, you can enjoy your",
       "stay in Einbroch in comfort~"
     ], {260, 201, 6, 0x00FF00}},
    {[
       "[Einbroch Guide]",
       "The Weapon Shop is",
       "located north from the",
       "Plaza. There you can",
       "purchase weapons for",
       "your personal use."
     ], {215, 221, 7, 0x00FF00}},
    {[
       "[Einbroch Guide]",
       "The Laboratory is an",
       "annex of the Factory and",
       "is located in the southwest",
       "sector of Einbroch."
     ], {36, 49, 8, 0x0000FF}},
    {[
       "[Einbroch Guide]",
       "The Blacksmith Guild is",
       "located in the southeast",
       "part of Einbroch. You can",
       "upgrade your equipment",
       "by using their services."
     ], {244, 90, 9, 0x00FF00}},
    {[
       "[Einbroch Guide]",
       "The Einbroch Tower is",
       "located in the center of",
       "the city. From the top of",
       "the tower, you can view",
       "all of Einbroch."
     ], {174, 195, 10, 0xFFFF00}}
  ]

  @location_count length(@locations)
  @location_menu [
    "^FF0000Airport^000000",
    "Train Station",
    "Factory",
    "Plaza",
    "Hotel",
    "Weapon Shop",
    "Laboratory",
    "Blacksmith Guild",
    "Einbroch Tower",
    "Cancel"
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> cutin("ein_soldier", 2)
    |> mes("[Einbroch Guide]")
    |> mes("Welcome")
    |> mes("to Einbroch,")
    |> mes("the City of Steel.")
    |> mes("Please ask me if you")
    |> mes("have any questions.")
    |> main_menu(false, false)
    |> cutin("ein_soldier", 255)
  end

  defp city_guide(ctx, marking?, paged?) do
    ctx = if paged?, do: next(ctx), else: ctx
    {ctx, choice} = select(ctx, @location_menu)

    case choice do
      choice when choice in 1..@location_count ->
        {lines, {x, y, id, color}} = Enum.at(@locations, choice - 1)
        ctx = Enum.reduce(lines, ctx, fn line, ctx -> mes(ctx, line) end)
        ctx = if marking?, do: viewpoint(ctx, 1, x, y, id, color), else: ctx
        city_guide(ctx, marking?, true)

      choice when choice == @location_count + 1 ->
        ctx
        |> mes("[Einbroch Guide]")
        |> mes("Please ask me to ''Remove")
        |> mes("Marks from Mini-Map'' if you")
        |> mes("no longer wish to have the")
        |> mes("location marks displayed")
        |> mes("on your Mini-Map.")

      _ ->
        city_guide(ctx, marking?, true)
    end
  end

  defp main_menu(ctx, marking?, guide_opened?) do
    {ctx, choice} =
      ctx
      |> next()
      |> select(["City Guide.", "Remove Marks from Mini-Map.", "Notice.", "Cancel."])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Einbroch Guide]")
          |> mes("Please select")
          |> mes("a location from")
          |> mes("the following menu.")

        {ctx, marking?} =
          if not marking? do
            {ctx, v2} =
              ctx
              |> mes("Would you like me")
              |> mes("to mark locations")
              |> mes("on your Mini-Map?")
              |> next()
              |> select(["Yes.", "No."])

            {ctx, v2 == 1}
          else
            {ctx, marking?}
          end

        ctx |> city_guide(marking?, guide_opened?) |> main_menu(marking?, true)

      2 ->
        ctx
        |> viewpoint(2, 63, 228, 2, 0xFF0000)
        |> viewpoint(2, 236, 279, 3, 0xFF00FF)
        |> viewpoint(2, 158, 78, 4, 0xFF00FF)
        |> viewpoint(2, 232, 190, 5, 0xFF00FF)
        |> viewpoint(2, 260, 201, 6, 0x00FF00)
        |> viewpoint(2, 215, 221, 7, 0x00FF00)
        |> viewpoint(2, 36, 49, 8, 0x00FF00)
        |> viewpoint(2, 244, 90, 9, 0x00FF00)
        |> viewpoint(2, 174, 195, 10, 0xFFFF00)
        |> mes("[Einbroch Guide]")
        |> mes("Okay, the marks from")
        |> mes("your Mini-Map have been")
        |> mes("removed. If you need any")
        |> mes("guidance around Einbroch,")
        |> mes("please let me or one of the")
        |> mes("other Einbroch Guides know.")
        |> main_menu(false, guide_opened?)

      3 ->
        ctx
        |> mes("[Einbroch Guide]")
        |> mes("Through the technology of")
        |> mes("the Schwarzwald Republic,")
        |> mes("we've upgraded to a digital")
        |> mes("information system that allows")
        |> mes("us to mark locations on your")
        |> mes("Mini-Map for easier navigation.")
        |> next()
        |> mes("[Einbroch Guide]")
        |> mes("Your Mini-Map is located")
        |> mes("in the upper right corner")
        |> mes("of the screen. If you can't")
        |> mes("see it, press the Ctrl + Tab")
        |> mes("keys or click the ''Map'' button in your Basic Info Window.")
        |> next()
        |> mes("[Einbroch Guide]")
        |> mes("On your Mini-Map,")
        |> mes("click on the ''+'' and ''-''")
        |> mes("symbols to zoom in and")
        |> mes("our of your Mini-Map. We")
        |> mes("hope you enjoy your travels")
        |> mes("here in Einbroch, adventurer.")
        |> main_menu(marking?, guide_opened?)

      4 ->
        ctx
        |> mes("[Einbroch Guide]")
        |> mes("We hope that you")
        |> mes("enjoy your travels")
        |> mes("here in Einbroch.")
        |> mes("Oh, and please be")
        |> mes("aware of the Smog Alerts.")
        |> close()

      _ ->
        main_menu(ctx, marking?, guide_opened?)
    end
  end
end
