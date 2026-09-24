defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesLighthalzen.Guide do
  @moduledoc """
  Lighthalzen guide who directs visitors to local facilities.

  ## Behavior

  - Describes destinations and optionally marks them on the mini-map.
  - Clears marks and explains how to use the mini-map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "lighthalzen",
        x: 207,
        y: 310,
        dir: 5,
        sprite: 852,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "LhzGuide"
      },
      %{
        map: "lighthalzen",
        x: 220,
        y: 311,
        dir: 3,
        sprite: 852,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#2lhz"
      },
      %{
        map: "lighthalzen",
        x: 154,
        y: 100,
        dir: 5,
        sprite: 852,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#3lhz"
      },
      %{
        map: "lighthalzen",
        x: 307,
        y: 224,
        dir: 3,
        sprite: 852,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#4lhz"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {[
       "[Lighthalzen Guide]",
       "Rekenber Corporation,",
       "the largest company in",
       "the Schwarzwald Republic,",
       "in located in northwestern",
       "Lighthalzen. You can't miss",
       "the headquarters building."
     ], {102, 247, 2, 0xFF0000}},
    {[
       "[Lighthalzen Guide]",
       "The Train Station is",
       "located in the center of",
       "the city, where we have",
       "a direct railroad to Einbroch."
     ], {233, 164, 3, 0xFF00FF}},
    {[
       "[Lighthalzen Guide]",
       "Our Police Station is just",
       "north of the city's center.",
       "Please don't hesitate to report",
       "any suspicious persons and",
       "activity, or if you have any",
       "problems whatsoever."
     ], {236, 276, 4, 0x99FFFF}},
    {[
       "[Lighthalzen Guide]",
       "The Bank is located",
       "just opposite to the",
       "Lighthalzen Police Station,",
       "which is a pretty good idea",
       "when I think about it, actually. ^FFFFFFspacer^000000"
     ], {198, 257, 5, 0x0000FF}},
    {[
       "[Lighthalzen Guide]",
       "Our Hotel is located in",
       "the middle of the South Plaza.",
       "Due to its quality services and",
       "luxurious accomodations, this",
       "hotel is extremely popular."
     ], {159, 133, 6, 0x00FF00}},
    {[
       "[Lighthalzen Guide]",
       "The Airport is to the far",
       "west of the Central Promenade.",
       "You can travel anywhere within",
       "the Schwarzwald Republic by",
       "riding on one of the Airships."
     ], {267, 75, 7, 0x00FF00}},
    {[
       "[Lighthalzen Guide]",
       "The Merchant Guild can be",
       "found in the southwestern",
       "part of Lighthalzen."
     ], {74, 53, 8, 0xFF99FF}},
    {[
       "[Lighthalzen Guide]",
       "The Jewelry Shop is",
       "located just west of",
       "the South Plaza."
     ], {93, 110, 9, 0xFF9900}},
    {[
       "[Lighthalzen Guide]",
       "The Weapon Shop is",
       "located at the end of",
       "the Central Promenade.",
       "It's at least worth a look",
       "if you're serious about",
       "adventuring around here."
     ], {196, 46, 10, 0x330033}},
    {[
       "[Lighthalzen Guide]",
       "The Department Store is",
       "located in the middle of",
       "Lighthalzen and is the biggest",
       "and most convenient place for",
       "shopping for almost everything."
     ], {199, 163, 11, 0xFFFF00}}
  ]

  @location_count length(@locations)
  @location_menu [
    "^FF0000Rekenber Corporation^000000",
    "Train Station",
    "Police Station",
    "Bank",
    "Hotel",
    "Airport",
    "Merchant Guild",
    "Jewelry Shop",
    "Weapon Shop",
    "Departement Store",
    "Cancel"
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> cutin("ein_soldier", 2)
    |> mes("[Lighthalzen Guide]")
    |> mes("Welcome to Lighthalzen,")
    |> mes("the Corporation City-State.")
    |> mes("If you need any guidance")
    |> mes("around the city, feel free")
    |> mes("to ask me and I'll do my")
    |> mes("very best to help you.")
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
        |> mes("[Lighthalzen Guide]")
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
      ctx |> next() |> select(["City Guide", "Remove Marks from Mini-Map", "Notice.", "Cancel"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Lighthalzen Guide]")
          |> mes("Please be aware that I'm")
          |> mes("in charge of providing info")
          |> mes("regarding the West District")
          |> mes("of Lighthalzen. Now, please")
          |> mes("select the location that you'd")
          |> mes("like to learn more about.")

        {ctx, marking?} =
          if not marking? do
            {ctx, v2} =
              ctx
              |> next()
              |> mes("[Lighthalzen Guide]")
              |> mes("But before that,")
              |> mes("would you like me")
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
        |> viewpoint(2, 102, 247, 2, 0xFF0000)
        |> viewpoint(2, 233, 164, 3, 0xFF00FF)
        |> viewpoint(2, 236, 276, 4, 0x99FFFF)
        |> viewpoint(2, 198, 257, 5, 0x0000FF)
        |> viewpoint(2, 159, 133, 6, 0x00FF00)
        |> viewpoint(2, 267, 75, 7, 0x00FF00)
        |> viewpoint(2, 74, 53, 8, 0xFF99FF)
        |> viewpoint(2, 93, 110, 9, 0xFF9900)
        |> viewpoint(2, 196, 46, 10, 0x330033)
        |> viewpoint(2, 199, 163, 11, 0xFFFF00)
        |> main_menu(false, guide_opened?)

      3 ->
        ctx
        |> mes("[Lighthalzen Guide]")
        |> mes("Advances in sorcery and")
        |> mes("technology have allowed")
        |> mes("us to update our information")
        |> mes("system, enabling up to mark")
        |> mes("locations on your Mini-Map")
        |> mes("for easier navigation.")
        |> next()
        |> mes("[Lighthalzen Guide]")
        |> mes("Your Mini-Map is located")
        |> mes("in the upper right corner")
        |> mes("of the screen. If you can't")
        |> mes("see it, press the Ctrl + Tab")
        |> mes("keys or click the ''Map'' button in your Basic Info Window.")
        |> next()
        |> mes("[Lighthalzen Guide]")
        |> mes("On your Mini-Map,")
        |> mes("click on the ''+'' and ''-''")
        |> mes("symbols to zoom in and")
        |> mes("our of your Mini-Map. We")
        |> mes("hope you enjoy your travels")
        |> mes("here in Lighthalzen.")
        |> main_menu(marking?, guide_opened?)

      4 ->
        ctx
        |> mes("[Lighthalzen Guide]")
        |> mes("Lighthalzen is divided")
        |> mes("into the East and West")
        |> mes("districts by a railroad that")
        |> mes("runs right through the middle.")
        |> mes("There are always guards on")
        |> mes("watch to protect the peace.")
        |> next()
        |> mes("[Lighthalzen Guide]")
        |> mes("Please don't hesitate")
        |> mes("to report any suspicious")
        |> mes("activity or persons to us.")
        |> mes("We hope that you enjoy")
        |> mes("our fair city, adventurer.")
        |> close()

      _ ->
        main_menu(ctx, marking?, guide_opened?)
    end
  end
end
