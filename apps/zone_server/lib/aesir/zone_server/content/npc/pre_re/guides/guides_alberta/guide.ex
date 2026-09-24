defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesAlberta.Guide do
  @moduledoc """
  Alberta guide who directs visitors to the town's facilities.

  ## Behavior

  - Describes local destinations and optionally marks their locations on the mini-map.
  - Clears location marks on request and explains how to use the mini-map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - MasterOfMuppets
    - erKURITA
    - Samuray22

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "alberta",
        x: 23,
        y: 238,
        dir: 4,
        sprite: 105,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "AlbGuide"
      },
      %{
        map: "alberta",
        x: 120,
        y: 60,
        dir: 3,
        sprite: 105,
        name: "Guide",
        scope: :pre_renewal,
        unique_name: "Guide#2alb"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"^FF0000Merchant Guild^000000",
     [
       "The Merchant Guild",
       "handles Job Changes",
       "to the Merchant Class,",
       "and is located in the",
       "southwest corner",
       "of Alberta."
     ], [{33, 41, 2, 0xFF0000}]},
    {"Weapon Shop", ["The Weapon Shop", "can be found in the", "southern end of Alberta."],
     [{117, 37, 3, 0xFF00FF}]},
    {"Tool Shop",
     [
       "The Tool Shop",
       "is kind of close",
       "to the center of",
       "Alberta. It shouldn't",
       "be too hard to find."
     ], [{98, 154, 4, 0xFF00FF}]},
    {"Inn", ["There's an Inn", "at the northern", "end of Alberta", "where you can rest."],
     [{65, 233, 5, 0xFF00FF}]},
    {"Forge",
     [
       "The Forge in Alberta",
       "is in the same building",
       "as the Merchant Guild.",
       "It's to the southwest."
     ], [{35, 41, 6, 0xFF00FF}]}
  ]

  @location_count length(@locations)
  @location_menu Enum.map(@locations, &elem(&1, 0)) ++ ["Cancel"]

  @cleared_marks [
    {237, 41, 2, 0xFF0000},
    {237, 41, 3, 0xFF00FF},
    {46, 345, 4, 0xFF00FF},
    {175, 220, 5, 0xFF00FF},
    {175, 220, 6, 0xFF00FF}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> cutin("prt_soldier", 2)
    |> mes("[Alberta Guide]")
    |> mes("Welcome to Alberta,")
    |> mes("the Port City. Feel free")
    |> mes("to ask me if you're having")
    |> mes("trouble finding anything in")
    |> mes("town, or if you just need")
    |> mes("guidance around the city.")
    |> main_menu(false, false)
    |> cutin("prt_soldier", 255)
  end

  defp main_menu(ctx, marking?, guide_opened?) do
    {ctx, choice} =
      ctx |> next() |> select(["City Guide", "Remove Marks from Mini-Map", "Notice", "Cancel"])

    case choice do
      1 ->
        {ctx, marking?} =
          ctx
          |> mes("[Alberta Guide]")
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
        |> mes("[Alberta Guide]")
        |> mes("Be safe when you")
        |> mes("travel and don't hesitate")
        |> mes("to ask me if you have any")
        |> mes("questions about Alberta.")
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
        |> mes("[Alberta Guide]")
        |> mes("Please ask me to ''Remove")
        |> mes("Marks from Mini-Map'' if you")
        |> mes("no longer wish to have the")
        |> mes("location marks displayed")
        |> mes("on your Mini-Map.")

      _ ->
        city_guide(ctx, marking?, true)
    end
  end

  defp describe(ctx, lines), do: Enum.reduce(lines, mes(ctx, "[Alberta Guide]"), &mes(&2, &1))

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
    |> mes("[Alberta Guide]")
    |> mes("Advances in sorcery and")
    |> mes("technology have allowed")
    |> mes("us to update our information")
    |> mes("system, enabling up to mark")
    |> mes("locations on your Mini-Map")
    |> mes("for easier navigation.")
    |> next()
    |> mes("[Alberta Guide]")
    |> mes("Your Mini-Map is located")
    |> mes("in the upper right corner")
    |> mes("of the screen. If you can't")
    |> mes("see it, press the Ctrl + Tab")
    |> mes("keys or click the ''Map'' button in your Basic Info Window.")
    |> next()
    |> mes("[Alberta Guide]")
    |> mes("On your Mini-Map,")
    |> mes("click on the ''+'' and ''-''")
    |> mes("symbols to zoom in and")
    |> mes("our of your Mini-Map. We")
    |> mes("hope you enjoy your travels")
    |> mes("here in the city of Alberta.")
  end
end
