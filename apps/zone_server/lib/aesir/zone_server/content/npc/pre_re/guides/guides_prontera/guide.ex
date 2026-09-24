defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesProntera.Guide do
  @moduledoc """
  Prontera guard who directs visitors to the city's facilities.

  ## Behavior

  - Describes each facility from a city guide menu and, when the player agrees, marks it on the
    mini-map. The marking offer repeats each time the guide is opened until marks are accepted.
  - Clears every mini-map mark on request.
  - Explains how to use the mini-map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - MasterOfMuppets
    - erKURITA
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
        map: "prontera",
        x: 154,
        y: 187,
        dir: 4,
        sprite: 105,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "PrtGuide"
      },
      %{
        map: "prontera",
        x: 282,
        y: 208,
        dir: 2,
        sprite: 105,
        name: "East Gate-Guide",
        scope: :pre_renewal
      },
      %{
        map: "prontera",
        x: 29,
        y: 200,
        dir: 6,
        sprite: 105,
        name: "West Gate-Guide",
        scope: :pre_renewal
      },
      %{
        map: "prontera",
        x: 160,
        y: 29,
        dir: 0,
        sprite: 105,
        name: "South Gate-Guide",
        scope: :pre_renewal
      },
      %{
        map: "prontera",
        x: 151,
        y: 330,
        dir: 4,
        sprite: 105,
        name: "North Gate-Guide",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"Swordman Association",
     [
       "The Swordman Association,",
       "which handles Job Changes",
       "to the Swordman class, has",
       "moved to Izlude. This facility",
       "is just an empty building now."
     ], [{237, 41, 4, 0x00FF00}]},
    {"^0000FFSanctuary^000000",
     [
       "The Prontera Sanctuary",
       "handles Job Changes to",
       "the Acolyte class, and can",
       "be found in the northeast",
       "corner of Prontera."
     ], [{236, 316, 5, 0xFF0000}]},
    {"Prontera Chivalry",
     [
       "The Prontera Chivralry,",
       "which is responsible for",
       "the safety of our capital, is",
       "in Prontera's northwest corner."
     ], [{46, 345, 6, 0x00FF00}]},
    {"Weapon Shop", ["The Weapon Shop", "is located northeast", "of the central fountain."],
     [{175, 220, 7, 0xFF00FF}]},
    {"Tool Shop", ["The Tool Shop", "is located northwest", "of the central fountain."],
     [{134, 221, 8, 0xFF00FF}]},
    {"Inn",
     [
       "The Inns in Prontera are",
       "located both to the east",
       "and west of Prontera's",
       "central fountain area."
     ], [{204, 191, 9, 0xFF00FF}, {107, 192, 10, 0xFF00FF}]},
    {"Trading Post", ["The Trading Post", "can be found southeast", "from the central fountain."],
     [{179, 184, 11, 0x00FF00}]},
    {"Pub", ["The Pub is located", "southeast of the fountain,", "behind the Trading Post."],
     [{208, 154, 12, 0x00FF00}]},
    {"Library",
     [
       "If you head north from",
       "the central fountain, you'll",
       "find an empty area in which",
       "both branches of the Prontera",
       "Library can be accessed if you",
       "head towards the east or west."
     ], [{120, 267, 13, 0x00FF00}, {192, 267, 14, 0x00FF00}]},
    {"Job Agency", ["The Job Agency is", "just southwest of the", "central fountain area."],
     [{133, 183, 15, 0x00FF00}]},
    {"Prontera Castle",
     [
       "The Prontera Castle is",
       "located at the northern",
       "sector of this city. You can",
       "go to the fields that are north",
       "of Prontera by going through",
       "the castle's rear exit."
     ], [{156, 360, 16, 0x00FF00}]},
    {"City Hall",
     ["The City Hall", "is located in the", "southwest corner", "in our city of Prontera."],
     [{75, 91, 17, 0x01FF01}]}
  ]

  @location_count length(@locations)
  @location_menu Enum.map(@locations, &elem(&1, 0)) ++ ["Cancel"]

  @cleared_marks [
    {237, 41, 4, 0x00FF00},
    {237, 41, 5, 0x0000FF},
    {46, 345, 6, 0x00FF00},
    {175, 220, 7, 0xFF0000},
    {134, 221, 8, 0xFF0000},
    {204, 191, 9, 0xFF0000},
    {107, 192, 10, 0xFF0000},
    {179, 184, 11, 0x00FF00},
    {208, 154, 12, 0x00FF00},
    {120, 267, 13, 0x00FF00},
    {192, 267, 14, 0x00FF00},
    {133, 183, 15, 0x00FF00},
    {156, 360, 16, 0x00FF00},
    {75, 91, 17, 0x00FF00}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> cutin("prt_soldier", 2)
    |> mes("[Prontera Guide]")
    |> mes("Welcome to Prontera,")
    |> mes("the beautiful capital of the")
    |> mes("Rune-Midgarts Kingdom. If")
    |> mes(
      "you have questions or need help finding something in the city, don't hesitate to ask."
    )
    |> main_menu(false, false)
    |> cutin("prt_soldier", 255)
  end

  defp main_menu(ctx, marking?, guide_opened?) do
    {ctx, choice} =
      ctx |> next() |> select(["City Guide.", "Remove Marks from Mini-Map", "Notice", "Cancel"])

    case choice do
      1 ->
        {ctx, marking?} =
          ctx
          |> mes("[Prontera Guide]")
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
        |> mes("[Prontera Guide]")
        |> mes("Well, adventurer...")
        |> mes("I hope your journeys")
        |> mes("through Rune-Midgarts")
        |> mes("are both fun and safe.")
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
        |> mes("[Prontera Guide]")
        |> mes("Please ask me to ''Remove")
        |> mes("Marks from Mini-Map'' if you")
        |> mes("no longer wish to have the")
        |> mes("location marks displayed")
        |> mes("on your Mini-Map.")

      _ ->
        city_guide(ctx, marking?, true)
    end
  end

  defp describe(ctx, lines), do: Enum.reduce(lines, mes(ctx, "[Prontera Guide]"), &mes(&2, &1))

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
    |> mes("[Prontera Guide]")
    |> mes("Advances in sorcery and")
    |> mes("technology have allowed")
    |> mes("us to update our information")
    |> mes("system, enabling up to mark")
    |> mes("locations on your Mini-Map")
    |> mes("for easier navigation.")
    |> next()
    |> mes("[Prontera Guide]")
    |> mes("Your Mini-Map is located")
    |> mes("in the upper right corner")
    |> mes("of the screen. If you can't")
    |> mes("see it, press the Ctrl + Tab")
    |> mes("keys or click the ''Map'' button in your Basic Info Window.")
    |> next()
    |> mes("[Prontera Guide]")
    |> mes("On your Mini-Map,")
    |> mes("click on the ''+'' and ''-''")
    |> mes("symbols to zoom in and")
    |> mes("our of your Mini-Map. We")
    |> mes("hope you enjoy your travels")
    |> mes("here in the city of Prontera.")
  end
end
