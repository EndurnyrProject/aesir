defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesEinbroch.Guide6737 do
  @moduledoc """
  Einbech guide who directs visitors to local facilities.

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
        map: "einbech",
        x: 67,
        y: 37,
        dir: 4,
        sprite: 852,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "EinGuide2"
      },
      %{
        map: "einbech",
        x: 48,
        y: 214,
        dir: 4,
        sprite: 852,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#5ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {[
       "[Einbech Guide]",
       "The Train Stations are",
       "located in the northwest",
       "and northeast parts of",
       "Einbech. There, you can",
       "take a train to Einbroch."
     ], {43, 213, 2, 0xFF0000}},
    {[
       "[Einbech Guide]",
       "The Tavern is located",
       "in the southern part of",
       "Einbech. It's a nice place",
       "to relax after a long day."
     ], {142, 112, 3, 0xFF00FF}},
    {[
       "[Einbech Guide]",
       "You can find the Tool",
       "Shop in the center of",
       "Einbech. There, you can",
       "purchase any tools you",
       "might need for your travels."
     ], {176, 136, 4, 0xFF00FF}},
    {[
       "[Einbech Guide]",
       "The Swordman Guild",
       "is located in the eastern",
       "outskirts of Einbech. It's",
       "under construction and they",
       "haven't started accepting",
       "applications."
     ], {250, 110, 5, 0xFF00FF}},
    {[
       "[Einbech Guide]",
       "The Mine, which is",
       "Einbech's major industry,",
       "is located in the northern",
       "part of this town. It's where",
       "we get all our ores, although monsters get in the miners' way."
     ], {138, 251, 6, 0x00FF00}}
  ]

  @location_count length(@locations)
  @location_menu ["Train Station", "Tavern", "Tool Shop", "Swordman Guild", "Mine", "Cancel"]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> cutin("ein_soldier", 2)
    |> mes("[Einbech Guide]")
    |> mes("Welcome to Einbech,")
    |> mes("the Mining Town. We're")
    |> mes("here to assist tourists,")
    |> mes("so if you have any questions,")
    |> mes("please feel free to ask us.")
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
        |> mes("[Einbech Guide]")
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
          |> mes("[Einbech Guide]")
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
        |> viewpoint(2, 43, 213, 2, 0xFF0000)
        |> viewpoint(2, 142, 112, 3, 0xFF00FF)
        |> viewpoint(2, 176, 136, 4, 0xFF00FF)
        |> viewpoint(2, 250, 110, 5, 0xFF00FF)
        |> viewpoint(2, 138, 251, 6, 0x00FF00)
        |> mes("[Einbech Guide]")
        |> mes("Okay, the marks from")
        |> mes("your Mini-Map have been")
        |> mes("removed. If you need any")
        |> mes("guidance around Einbech,")
        |> mes("please let me or one of the")
        |> mes("other Einbech Guides know.")
        |> main_menu(false, guide_opened?)

      3 ->
        ctx
        |> mes("[Einbech Guide]")
        |> mes("Through the technology of")
        |> mes("the Schwarzwald Republic,")
        |> mes("we've upgraded to a digital")
        |> mes("information system that allows")
        |> mes("us to mark locations on your")
        |> mes("Mini-Map for easier navigation.")
        |> next()
        |> mes("[Einbech Guide]")
        |> mes("Your Mini-Map is located")
        |> mes("in the upper right corner")
        |> mes("of the screen. If you can't")
        |> mes("see it, press the Ctrl + Tab")
        |> mes("keys or click the ''Map'' button in your Basic Info Window.")
        |> next()
        |> mes("[Einbech Guide]")
        |> mes("On your Mini-Map,")
        |> mes("click on the ''+'' and ''-''")
        |> mes("symbols to zoom in and")
        |> mes("our of your Mini-Map. We")
        |> mes("hope you enjoy your travels")
        |> mes("here in Einbech, adventurer.")
        |> main_menu(marking?, guide_opened?)

      4 ->
        ctx
        |> mes("[Einbech Guide]")
        |> mes("We hope that you")
        |> mes("enjoy your travels")
        |> mes("here in Einbech.")
        |> close()

      _ ->
        main_menu(ctx, marking?, guide_opened?)
    end
  end
end
