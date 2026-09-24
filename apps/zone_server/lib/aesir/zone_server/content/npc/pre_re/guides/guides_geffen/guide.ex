defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesGeffen.Guide do
  @moduledoc """
  Geffen guide who directs visitors to the city's facilities.

  ## Behavior

  - Describes facilities and optionally marks them on the mini-map.
  - Removes marks on request and explains mini-map controls.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Poki#3
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
        map: "geffen",
        x: 203,
        y: 116,
        dir: 0,
        sprite: 705,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "GefGuide"
      },
      %{
        map: "geffen",
        x: 118,
        y: 62,
        dir: 0,
        sprite: 705,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#2gef"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"^FF0000Magic Acedemy^000000",
     ["The Magic Academy in", "northwest Geffen handles", "Job Changes to the Mage class."],
     {61, 180, 2, 0xFF0000}},
    {"Forge Shop", ["The Forge Shop is", "located just southeast", "from the center of Geffen."],
     {182, 59, 3, 0x00FF00}},
    {"Weapon Shop", ["The Weapon Shop", "can be found northwest", "from the center of Geffen."],
     {99, 140, 4, 0xFF00FF}},
    {"Tool Shop",
     ["You can find the", "Tool Shop by heading", "southwest from the", "center of Geffen."],
     {44, 86, 5, 0xFF00FF}},
    {"Pub", ["The Pub can be", "found northeast", "from the Geffen Tower."],
     {138, 138, 6, 0xFF00FF}},
    {"Inn", ["The Inn can be", "found by traveling", "northeast from the", "center of Geffen."],
     {172, 174, 7, 0xFF00FF}},
    {"Geffen Tower",
     [
       "Geffen Tower is found",
       "in the center of the city.",
       "The Wizard Guild is at the",
       "top, and there's even a dungeon",
       "underneath it. There's many a",
       "mystery surrounding that tower..."
     ], {120, 114, 8, 0x00FF00}}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> cutin("gef_soldier", 2)
    |> mes("[Geffen Guide]")
    |> mes("Welcome to Geffen,")
    |> mes("the City of Magic. If you")
    |> mes("need any guidance around")
    |> mes("the city, feel free to ask me")
    |> mes("and I'll do my best to assist you. ^FFFFFFcobo^000000")
    |> main_menu(false, false)
    |> cutin("gef_soldier", 255)
  end

  defp main_menu(ctx, marking?, guide_opened?) do
    {ctx, choice} =
      ctx |> next() |> select(["City Guide", "Remove Marks from Mini-Map", "Notice.", "Cancel"])

    case choice do
      1 ->
        {ctx, marking?} =
          ctx
          |> mes("[Geffen Guide]")
          |> mes("Please select")
          |> mes("a location from")
          |> mes("the following menu.")
          |> offer_marks(marking?)

        ctx |> city_guide(marking?, guide_opened?) |> main_menu(marking?, true)

      2 ->
        ctx |> clear_marks() |> main_menu(false, guide_opened?)

      3 ->
        ctx |> notice() |> main_menu(marking?, guide_opened?)

      4 ->
        ctx
        |> mes("[Geffen Guide]")
        |> mes("Alright, adventurer.")
        |> mes("I wish you safety on")
        |> mes("your journeys through")
        |> mes("the lands you may travel...")
        |> close()

      _ ->
        main_menu(ctx, marking?, guide_opened?)
    end
  end

  defp offer_marks(ctx, marking?) do
    if get_char_var(ctx, :compass_check, 0) == 0 do
      {ctx, choice} =
        ctx
        |> mes("Would you like me")
        |> mes("to mark locations")
        |> mes("on your Mini-Map?")
        |> next()
        |> select(["Yes", "No"])

      {ctx, marking? or choice == 1}
    else
      {ctx, marking?}
    end
  end

  defp city_guide(ctx, marking?, paged?) do
    ctx = if paged?, do: next(ctx), else: ctx
    {ctx, choice} = select(ctx, Enum.map(@locations, &elem(&1, 0)) ++ ["Cancel"])

    case choice do
      choice when choice in 1..7 ->
        {_label, lines, {x, y, id, color}} = Enum.at(@locations, choice - 1)
        ctx = Enum.reduce(lines, mes(ctx, "[Geffen Guide]"), &mes(&2, &1))
        ctx = if marking?, do: viewpoint(ctx, 1, x, y, id, color), else: ctx
        city_guide(ctx, marking?, true)

      8 ->
        ctx
        |> mes("[Geffen Guide]")
        |> mes("Please ask me to ''Remove")
        |> mes("Marks from Mini-Map'' if you")
        |> mes("no longer wish to have the")
        |> mes("location marks displayed")
        |> mes("on your Mini-Map.")

      _ ->
        city_guide(ctx, marking?, true)
    end
  end

  defp clear_marks(ctx) do
    ctx
    |> viewpoint(2, 237, 41, 2, 0xFF0000)
    |> viewpoint(2, 237, 41, 3, 0x00FF00)
    |> viewpoint(2, 46, 345, 4, 0xFF00FF)
    |> viewpoint(2, 175, 220, 5, 0xFF00FF)
    |> viewpoint(2, 134, 221, 6, 0xFF00FF)
    |> viewpoint(2, 204, 214, 7, 0xFF00FF)
    |> viewpoint(2, 204, 214, 8, 0x00FF00)
  end

  defp notice(ctx) do
    ctx
    |> mes("[Geffen Guide]")
    |> mes("Advances in sorcery and")
    |> mes("technology have allowed")
    |> mes("us to update our information")
    |> mes("system, enabling up to mark")
    |> mes("locations on your Mini-Map")
    |> mes("for easier navigation.")
    |> next()
    |> mes("[Geffen Guide]")
    |> mes("Your Mini-Map is located")
    |> mes("in the upper right corner")
    |> mes("of the screen. If you can't")
    |> mes("see it, press the Ctrl + Tab")
    |> mes("keys or click the ''Map'' button in your Basic Info Window.")
    |> next()
    |> mes("[Geffen Guide]")
    |> mes("On your Mini-Map,")
    |> mes("click on the ''+'' and ''-''")
    |> mes("symbols to zoom in and")
    |> mes("our of your Mini-Map. We")
    |> mes("hope you enjoy your travels")
    |> mes("here in the city of Geffen.")
  end
end
